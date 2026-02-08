#include "pipeline.hpp"
#include "coin_detector.hpp"
#include "calibration.hpp"
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>
#include <iostream>
#include <iomanip>
#include <cmath>
#include <sstream>

namespace coin
{

  using Clock = std::chrono::high_resolution_clock;
  using Ms = std::chrono::duration<double, std::milli>;

  PipelineContext::PipelineContext(int stabilizer_window, int w_px, int h_px, double ratio)
      : stabilizer(stabilizer_window),
        width_px(w_px), height_px(h_px), ratio_px_to_mm(ratio),
        print_timings(Config::PRINT_TIMINGS_DEFAULT)
  {
    dst_corners = (cv::Mat_<float>(4, 2) << 0, 0, w_px - 1, 0, w_px - 1, h_px - 1, 0, h_px - 1);
    warped.create(h_px, w_px, CV_8UC3);
  }

  void print_timings(const PipelineTimings &t, int frame_id)
  {
    std::cerr << std::fixed << std::setprecision(2)
              << "frame " << frame_id
              << " | capture=" << t.capture_ms << " ms"
              << " | paper=" << t.paper_ms << " ms"
              << " | stabilizer=" << t.stabilizer_ms << " ms"
              << " | order+warp=" << t.order_warp_ms << " ms"
              << " | detect_coins=" << t.detect_coins_ms << " ms"
              << " | tracker=" << t.tracker_ms << " ms"
              << " | classify=" << t.classify_ms << " ms"
              << " | draw_rest=" << t.draw_rest_ms << " ms"
              << " | display=" << t.display_ms << " ms"
              << " | TOTAL=" << t.total_frame_ms << " ms"
              << " (" << (1000.0 / std::max(t.total_frame_ms, 0.001)) << " FPS)\n";
  }

  cv::Mat for_display(const cv::Mat &mat)
  {
    if (mat.cols <= Config::MAX_DISPLAY_WIDTH_PX || mat.empty())
      return mat;
    double scale = static_cast<double>(Config::MAX_DISPLAY_WIDTH_PX) / mat.cols;
    cv::Mat out;
    cv::resize(mat, out, cv::Size(), scale, scale, cv::INTER_AREA);
    return out;
  }

  void create_debug_windows()
  {
    if (Config::SHOW_DEBUG_VIEWS)
    {
      cv::namedWindow("Debug: Markers", cv::WINDOW_AUTOSIZE);
      cv::namedWindow("Debug: Segmentation", cv::WINDOW_AUTOSIZE);
      cv::namedWindow("Debug: Binary", cv::WINDOW_AUTOSIZE);
      cv::namedWindow("Debug: Sure FG", cv::WINDOW_AUTOSIZE);
      cv::namedWindow("Debug: Distance", cv::WINDOW_AUTOSIZE);
    }
  }

  void classify_and_draw(PipelineContext &ctx, const cv::Mat &frame,
                         bool reclassify, PipelineTimings *timings)
  {
    auto t_draw_start = Clock::now();
    cv::Mat display;
    frame.copyTo(display);
    auto entries = ctx.tracker.get_stable_entries();

    if (reclassify || !ctx.clf_cache.valid || ctx.clf_cache.num_entries != entries.size())
    {
      ctx.clf_cache.class_ids.resize(entries.size(), 0);
      ctx.clf_cache.total_eur = 0.0;
      ctx.clf_cache.num_entries = entries.size();

      auto t_clf_start = Clock::now();

      if (ctx.active_classifier && ctx.active_classifier->is_loaded() && !entries.empty())
      {
        std::vector<std::pair<cv::Point2i, int>> centers_radii;
        std::vector<std::tuple<double, double, double, double>> features;
        centers_radii.reserve(entries.size());
        features.reserve(entries.size());

        auto coin_features = collect_coin_features(frame, entries, ctx.ratio_px_to_mm);

        for (size_t i = 0; i < entries.size(); ++i)
        {
          centers_radii.emplace_back(entries[i].first,
                                     diameter_mm_to_radius_px(entries[i].second, ctx.ratio_px_to_mm));
          if (i < coin_features.size())
            features.emplace_back(coin_features[i].diameter_mm,
                                  coin_features[i].L, coin_features[i].a, coin_features[i].b);
          else
            features.emplace_back(entries[i].second, 0.0, 0.0, 0.0);
        }

        auto cids = ctx.active_classifier->predict_batch(frame, centers_radii, features);
        for (size_t i = 0; i < entries.size(); ++i)
        {
          int cid = (i < cids.size()) ? (cids[i] % 6) : 0;
          ctx.clf_cache.class_ids[i] = cid;
          ctx.clf_cache.total_eur += Config::CLASS_TO_VALUE_EUR[cid];
        }
      }

      ctx.clf_cache.valid = true;
      if (timings)
        timings->classify_ms = Ms(Clock::now() - t_clf_start).count();
    }

    for (size_t i = 0; i < entries.size(); ++i)
    {
      const auto &e = entries[i];
      int r = diameter_mm_to_radius_px(e.second, ctx.ratio_px_to_mm);
      int cid = (i < ctx.clf_cache.class_ids.size()) ? ctx.clf_cache.class_ids[i] : 0;
      cv::Scalar color(Config::CLUSTER_COLORS_BGR[cid][0],
                       Config::CLUSTER_COLORS_BGR[cid][1],
                       Config::CLUSTER_COLORS_BGR[cid][2]);
      cv::circle(display, e.first, r, color, 4);
      std::string label = std::to_string(static_cast<int>(e.second * 10) / 10.0).substr(0, 4) + "mm";
      cv::putText(display, label, cv::Point(e.first.x - 20, e.first.y - 10),
                  cv::FONT_HERSHEY_SIMPLEX, 1, cv::Scalar(0, 0, 255), 4);
    }

    cv::rectangle(display, cv::Point(10, 10), cv::Point(280, 90), cv::Scalar(0, 0, 0), -1);
    cv::rectangle(display, cv::Point(10, 10), cv::Point(280, 90), cv::Scalar(255, 255, 255), 2);
    cv::putText(display, "Coins: " + std::to_string(entries.size()), cv::Point(20, 40),
                cv::FONT_HERSHEY_SIMPLEX, 0.8, cv::Scalar(255, 255, 255), 2);
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(2) << "Total: " << ctx.clf_cache.total_eur << " EUR";
    cv::putText(display, oss.str(), cv::Point(20, 62), cv::FONT_HERSHEY_SIMPLEX, 0.8, cv::Scalar(255, 255, 255), 2);
    cv::putText(display, "Clf: " + ctx.classifier_display_name, cv::Point(20, 82),
                cv::FONT_HERSHEY_SIMPLEX, 0.6, cv::Scalar(200, 200, 200), 2);

    if (timings)
      timings->draw_rest_ms = Ms(Clock::now() - t_draw_start).count() - timings->classify_ms;

    // FPS overlay
    {
      static int64_t prev_ticks = cv::getTickCount();
      int64_t ticks = cv::getTickCount();
      double fps = cv::getTickFrequency() / std::max(ticks - prev_ticks, int64_t(1));
      prev_ticks = ticks;
      cv::putText(display, "FPS: " + std::to_string(static_cast<int>(std::round(fps))),
                  cv::Point(display.cols - 200, 30), cv::FONT_HERSHEY_SIMPLEX, 0.9, cv::Scalar(0, 255, 0), 2);
    }

    auto t_disp = Clock::now();
    cv::imshow("Anti-Glare Detection", for_display(display));
    if (timings)
      timings->display_ms = Ms(Clock::now() - t_disp).count();
  }

  void run_coin_detection(PipelineContext &ctx, const cv::Mat &warped,
                          bool skip_detection, PipelineTimings *timings)
  {
    if (!skip_detection)
    {
      const double det_scale = Config::COIN_DETECT_SCALE;
      const bool show_debug = Config::SHOW_DEBUG_VIEWS;
      DebugViews debug;
      DebugViews *out_debug = show_debug ? &debug : nullptr;
      std::vector<Detection> detections;

      auto t0 = Clock::now();
      if (det_scale <= 0 || det_scale >= 1.0)
      {
        detections = detect_and_measure_coins(warped, ctx.ratio_px_to_mm, out_debug);
      }
      else
      {
        cv::Mat small;
        cv::resize(warped, small, cv::Size(), det_scale, det_scale, cv::INTER_LINEAR);
        double ratio_small = ctx.ratio_px_to_mm / det_scale;
        detections = detect_and_measure_coins(small, ratio_small, out_debug, det_scale);
        const double inv = 1.0 / det_scale;
        for (auto &d : detections)
        {
          d.center.x = static_cast<int>(std::round(d.center.x * inv));
          d.center.y = static_cast<int>(std::round(d.center.y * inv));
        }
      }
      if (timings)
        timings->detect_coins_ms = Ms(Clock::now() - t0).count();

      t0 = Clock::now();
      ctx.tracker.update(detections);
      if (timings)
        timings->tracker_ms = Ms(Clock::now() - t0).count();

      if (show_debug)
      {
        if (!debug.markers_vis.empty() && debug.markers_vis.total() > 0)
          cv::imshow("Debug: Markers", for_display(debug.markers_vis));
        if (!debug.segmentation.empty() && debug.segmentation.total() > 0)
          cv::imshow("Debug: Segmentation", for_display(debug.segmentation));
        if (!debug.binary.empty() && debug.binary.total() > 0)
          cv::imshow("Debug: Binary", for_display(debug.binary));
        if (!debug.sure_fg.empty() && debug.sure_fg.total() > 0)
          cv::imshow("Debug: Sure FG", for_display(debug.sure_fg));
        if (!debug.dist_vis.empty() && debug.dist_vis.total() > 0)
          cv::imshow("Debug: Distance", for_display(debug.dist_vis));
      }
    }

    classify_and_draw(ctx, warped, !skip_detection, timings);
  }

  void process_frame(PipelineContext &ctx, const cv::Mat &frame, PipelineTimings *timings)
  {
    const int every_n = std::max(1, Config::PAPER_DETECT_EVERY_N_FRAMES);
    std::optional<cv::Mat> raw_corners;
    auto t_paper = Clock::now();
    if (every_n <= 1 || (++ctx.frame_count % every_n) == 1)
    {
      raw_corners = find_paper_corners(frame);
      if (raw_corners.has_value())
        ctx.last_raw_corners = raw_corners;
    }
    else if (ctx.last_raw_corners.has_value())
      raw_corners = ctx.last_raw_corners;
    if (timings)
      timings->paper_ms = Ms(Clock::now() - t_paper).count();

    auto t_stab = Clock::now();
    std::optional<cv::Mat> stable_corners = raw_corners.has_value()
                                                ? ctx.stabilizer.update(&*raw_corners)
                                                : ctx.stabilizer.update(nullptr);
    if (timings)
      timings->stabilizer_ms = Ms(Clock::now() - t_stab).count();

    if (stable_corners.has_value() && !stable_corners->empty() &&
        stable_corners->rows == 4 && stable_corners->cols >= 2)
    {
      cv::Mat rect = order_corners(*stable_corners);
      ctx.cached_M = cv::getPerspectiveTransform(rect, ctx.dst_corners);
    }

    if (!ctx.cached_M.empty())
    {
      double det = cv::determinant(ctx.cached_M);
      if (std::abs(det) > 1e-6)
      {
        auto t_ow = Clock::now();
        cv::warpPerspective(frame, ctx.warped, ctx.cached_M,
                            cv::Size(ctx.width_px, ctx.height_px));
        if (timings)
          timings->order_warp_ms = Ms(Clock::now() - t_ow).count();

        if (!ctx.warped.empty() && ctx.warped.rows > 0 && ctx.warped.cols > 0)
        {
          const int coin_every_n = std::max(1, Config::COIN_DETECT_EVERY_N_FRAMES);
          bool do_detect = (coin_every_n <= 1 || (++ctx.coin_detect_count % coin_every_n) == 1);
          run_coin_detection(ctx, ctx.warped, !do_detect, timings);
        }
      }
    }

    if (raw_corners.has_value())
    {
      cv::Mat frame_mut = const_cast<cv::Mat &>(frame);
      std::vector<std::vector<cv::Point>> contour(1);
      for (int i = 0; i < 4; ++i)
        contour[0].emplace_back(static_cast<int>(raw_corners->at<float>(i, 0)),
                                static_cast<int>(raw_corners->at<float>(i, 1)));
      cv::drawContours(frame_mut, contour, -1, cv::Scalar(0, 255, 0), 2);
    }
  }

}
