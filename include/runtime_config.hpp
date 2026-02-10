#pragma once

#include "config.hpp"
#include <string>

namespace coin
{

  struct RuntimeConfig
  {
    // Image processing
    int clahe_clip = Config::CLAHE_CLIP;
    int clahe_grid = Config::CLAHE_GRID;
    int blur_ksize = Config::BLUR_KSIZE;
    int channel_mode = Config::CHANNEL_MODE;

    // Morphology
    int morph_open_size = Config::MORPH_OPEN_SIZE;
    int morph_close_size = Config::MORPH_CLOSE_SIZE;
    int morph_open_iters = Config::MORPH_OPEN_ITERS;
    int morph_close_iters = Config::MORPH_CLOSE_ITERS;
    int bg_dilate_size = Config::BG_DILATE_SIZE;

    // Circle detection
    double hough_dp = Config::HOUGH_DP;
    int hough_min_dist = Config::HOUGH_MIN_DIST;
    double hough_param1 = Config::HOUGH_PARAM1;
    double hough_param2 = Config::HOUGH_PARAM2;
    int min_radius_px = Config::MIN_RADIUS_PX;
    int max_radius_px = Config::MAX_RADIUS_PX;

    // Coin filtering
    double min_contour_area = Config::MIN_CONTOUR_AREA;
    double min_circularity = Config::MIN_CIRCULARITY;
    double diameter_mm_min = Config::DIAMETER_MM_MIN;
    double diameter_mm_max = Config::DIAMETER_MM_MAX;

    // Tracking
    int center_match_px = Config::CENTER_MATCH_PX;
    int diameter_history_len = Config::DIAMETER_HISTORY_LEN;
    int max_frames_missing = Config::MAX_FRAMES_MISSING;

    // Paper detection
    double paper_width_mm = Config::PAPER_WIDTH_MM;
    double paper_height_mm = Config::PAPER_HEIGHT_MM;
    double scale_factor = Config::SCALE_FACTOR;
    int paper_detect_every_n = Config::PAPER_DETECT_EVERY_N_FRAMES;
    int coin_detect_every_n = Config::COIN_DETECT_EVERY_N_FRAMES;

    // Hardware
    int camera_index = 2;
    int camera_width = 1280;
    int camera_height = 720;

    // Display
    int max_display_width_px = Config::MAX_DISPLAY_WIDTH_PX;
    bool show_debug_views = Config::SHOW_DEBUG_VIEWS;
    bool print_timings = Config::PRINT_TIMINGS_DEFAULT;
    bool use_test_videos = Config::USE_TEST_VIDEOS;

    bool load_from_yaml(const std::string &path);
    bool save_to_yaml(const std::string &path) const;
  };

}
