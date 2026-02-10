#pragma once

#include "config.hpp"
#include "types.hpp"
#include "classifier_interface.hpp"
#include "corner_stabilizer.hpp"
#include "coin_tracker.hpp"
#include <opencv2/core.hpp>
#include <opencv2/videoio.hpp>
#include <chrono>
#include <memory>
#include <string>
#include <vector>

namespace coin
{

  struct PipelineTimings
  {
    double capture_ms = 0;
    double paper_ms = 0;
    double stabilizer_ms = 0;
    double order_warp_ms = 0;
    double detect_coins_ms = 0;
    double tracker_ms = 0;
    double classify_ms = 0;
    double draw_rest_ms = 0;
    double display_ms = 0;
    double total_frame_ms = 0;
  };

  struct ClassificationCache
  {
    std::vector<int> class_ids;
    double total_eur = 0.0;
    size_t num_entries = 0;
    bool valid = false;

    void invalidate() { valid = false; }
  };

  struct PipelineContext
  {
    CornerStabilizer stabilizer;
    CoinTracker tracker;
    ClassificationCache clf_cache;

    IClassifier *active_classifier = nullptr;
    std::string classifier_display_name;

    cv::Mat dst_corners;
    cv::Mat cached_M;
    cv::Mat warped;
    std::optional<cv::Mat> last_raw_corners;

    int width_px = 0;
    int height_px = 0;
    double ratio_px_to_mm = 0;

    int frame_count = 0;
    int coin_detect_count = 0;

    bool print_timings = false;

    explicit PipelineContext(int stabilizer_window, int w_px, int h_px, double ratio);
  };

  void print_timings(const PipelineTimings &t, int frame_id);

  cv::Mat for_display(const cv::Mat &mat);

  void create_debug_windows();

  void classify_and_draw(PipelineContext &ctx, const cv::Mat &frame,
                         bool reclassify, PipelineTimings *timings);

  void run_coin_detection(PipelineContext &ctx, const cv::Mat &warped,
                          bool skip_detection, PipelineTimings *timings);

  void process_frame(PipelineContext &ctx, const cv::Mat &frame,
                     PipelineTimings *timings);

}
