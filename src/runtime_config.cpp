#include "runtime_config.hpp"
#include <opencv2/core/persistence.hpp>
#include <iostream>

namespace coin
{

  template <typename T>
  static void read_if_exists(const cv::FileStorage &fs, const char *key, T &out)
  {
    cv::FileNode node = fs[key];
    if (!node.empty())
      node >> out;
  }

  bool RuntimeConfig::load_from_yaml(const std::string &path)
  {
    cv::FileStorage fs(path, cv::FileStorage::READ);
    if (!fs.isOpened())
    {
      std::cerr << "RuntimeConfig: could not open " << path << " (using defaults).\n";
      return false;
    }

    read_if_exists(fs, "clahe_clip", clahe_clip);
    read_if_exists(fs, "clahe_grid", clahe_grid);
    read_if_exists(fs, "blur_ksize", blur_ksize);
    read_if_exists(fs, "channel_mode", channel_mode);

    read_if_exists(fs, "morph_open_size", morph_open_size);
    read_if_exists(fs, "morph_close_size", morph_close_size);
    read_if_exists(fs, "morph_open_iters", morph_open_iters);
    read_if_exists(fs, "morph_close_iters", morph_close_iters);
    read_if_exists(fs, "bg_dilate_size", bg_dilate_size);

    read_if_exists(fs, "hough_dp", hough_dp);
    read_if_exists(fs, "hough_min_dist", hough_min_dist);
    read_if_exists(fs, "hough_param1", hough_param1);
    read_if_exists(fs, "hough_param2", hough_param2);
    read_if_exists(fs, "min_radius_px", min_radius_px);
    read_if_exists(fs, "max_radius_px", max_radius_px);

    read_if_exists(fs, "min_contour_area", min_contour_area);
    read_if_exists(fs, "min_circularity", min_circularity);
    read_if_exists(fs, "diameter_mm_min", diameter_mm_min);
    read_if_exists(fs, "diameter_mm_max", diameter_mm_max);

    read_if_exists(fs, "center_match_px", center_match_px);
    read_if_exists(fs, "diameter_history_len", diameter_history_len);
    read_if_exists(fs, "max_frames_missing", max_frames_missing);

    read_if_exists(fs, "paper_width_mm", paper_width_mm);
    read_if_exists(fs, "paper_height_mm", paper_height_mm);
    read_if_exists(fs, "scale_factor", scale_factor);
    read_if_exists(fs, "paper_detect_every_n", paper_detect_every_n);
    read_if_exists(fs, "coin_detect_every_n", coin_detect_every_n);

    read_if_exists(fs, "camera_index", camera_index);
    read_if_exists(fs, "camera_width", camera_width);
    read_if_exists(fs, "camera_height", camera_height);

    read_if_exists(fs, "max_display_width_px", max_display_width_px);

    int dbg = show_debug_views ? 1 : 0;
    read_if_exists(fs, "show_debug_views", dbg);
    show_debug_views = (dbg != 0);

    int pt = print_timings ? 1 : 0;
    read_if_exists(fs, "print_timings", pt);
    print_timings = (pt != 0);

    int utv = use_test_videos ? 1 : 0;
    read_if_exists(fs, "use_test_videos", utv);
    use_test_videos = (utv != 0);

    fs.release();
    std::cout << "RuntimeConfig: loaded from " << path << "\n";
    return true;
  }

  bool RuntimeConfig::save_to_yaml(const std::string &path) const
  {
    cv::FileStorage fs(path, cv::FileStorage::WRITE);
    if (!fs.isOpened())
      return false;

    fs << "clahe_clip" << clahe_clip;
    fs << "clahe_grid" << clahe_grid;
    fs << "blur_ksize" << blur_ksize;
    fs << "channel_mode" << channel_mode;

    fs << "morph_open_size" << morph_open_size;
    fs << "morph_close_size" << morph_close_size;
    fs << "morph_open_iters" << morph_open_iters;
    fs << "morph_close_iters" << morph_close_iters;
    fs << "bg_dilate_size" << bg_dilate_size;

    fs << "hough_dp" << hough_dp;
    fs << "hough_min_dist" << hough_min_dist;
    fs << "hough_param1" << hough_param1;
    fs << "hough_param2" << hough_param2;
    fs << "min_radius_px" << min_radius_px;
    fs << "max_radius_px" << max_radius_px;

    fs << "min_contour_area" << min_contour_area;
    fs << "min_circularity" << min_circularity;
    fs << "diameter_mm_min" << diameter_mm_min;
    fs << "diameter_mm_max" << diameter_mm_max;

    fs << "center_match_px" << center_match_px;
    fs << "diameter_history_len" << diameter_history_len;
    fs << "max_frames_missing" << max_frames_missing;

    fs << "paper_width_mm" << paper_width_mm;
    fs << "paper_height_mm" << paper_height_mm;
    fs << "scale_factor" << scale_factor;
    fs << "paper_detect_every_n" << paper_detect_every_n;
    fs << "coin_detect_every_n" << coin_detect_every_n;

    fs << "camera_index" << camera_index;
    fs << "camera_width" << camera_width;
    fs << "camera_height" << camera_height;

    fs << "max_display_width_px" << max_display_width_px;
    fs << "show_debug_views" << (show_debug_views ? 1 : 0);
    fs << "print_timings" << (print_timings ? 1 : 0);
    fs << "use_test_videos" << (use_test_videos ? 1 : 0);

    fs.release();
    return true;
  }

}
