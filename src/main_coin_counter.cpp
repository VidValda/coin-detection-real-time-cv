#include "config.hpp"
#include "data_path.hpp"
#include "calibration.hpp"
#include "pipeline.hpp"
#include "svm_classifier.hpp"
#ifdef COIN_USE_TORCH
#include "torch_classifier.hpp"
#endif
#include <opencv2/highgui.hpp>
#include <opencv2/videoio.hpp>
#include <fstream>
#include <iostream>
#include <chrono>

namespace
{
  using Clock = std::chrono::high_resolution_clock;
  using Ms = std::chrono::duration<double, std::milli>;

  int read_default_classifier_index(int max_idx)
  {
    std::ifstream f(coin::data_path(coin::Config::CLASSIFIER_DEFAULT_FILE));
    int idx = 0;
    if (f && (f >> idx) && idx >= 0 && idx <= max_idx)
      return idx;
    return 0;
  }
}

int main(int argc, char **argv)
{
  coin::init_data_root(argc, argv);
  cv::setUseOptimized(true);

  // --- Camera / video source ---
  const char *test_videos[] = {coin::Config::TEST_VIDEO_1, coin::Config::TEST_VIDEO_2};
  const int num_test_videos = 2;
  int current_video_index = -1;

  cv::VideoCapture cap;
  if (coin::Config::USE_TEST_VIDEOS)
  {
    for (int i = 0; i < num_test_videos; ++i)
    {
      cap.open(coin::data_path(test_videos[i]));
      if (cap.isOpened())
      {
        current_video_index = i;
        std::cout << "Using test video: " << test_videos[i] << "\n";
        break;
      }
    }
    if (!cap.isOpened())
    {
      std::cerr << "Could not open test videos.\n";
      return 1;
    }
  }
  else
  {
    int camera_index = 2;
    if (argc > 2)
    {
      try { camera_index = std::stoi(argv[2]); }
      catch (...) {}
    }
    cap.open(camera_index, cv::CAP_V4L2);
    if (!cap.isOpened())
    {
      std::cerr << "Could not open camera (index " << camera_index << "). "
                << "Pass camera index as second argument.\n";
      return 1;
    }
    cap.set(cv::CAP_PROP_FRAME_WIDTH, 1280);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, 720);
  }

  // --- Pipeline context ---
  int width_px = static_cast<int>(coin::Config::PAPER_WIDTH_MM * coin::Config::SCALE_FACTOR);
  int height_px = static_cast<int>(coin::Config::PAPER_HEIGHT_MM * coin::Config::SCALE_FACTOR);
  double ratio_px_to_mm = 1.0 / coin::Config::SCALE_FACTOR;

  coin::PipelineContext ctx(coin::Config::STABILIZER_WINDOW, width_px, height_px, ratio_px_to_mm);

  cv::namedWindow("Coin Counter", cv::WINDOW_AUTOSIZE);
  coin::create_debug_windows();

  std::cout << "Using px-to-mm ratio: " << ratio_px_to_mm << " mm/px (from SCALE_FACTOR).\n";

  // --- Classifiers ---
  coin::SVMClassifier svm_classifiers[4];
#ifdef COIN_USE_TORCH
  coin::TorchClassifier torch_cnn, torch_resnet;
  torch_cnn.set_name("CNN");
  torch_resnet.set_name("ResNet18");
  const int max_classifier_idx = 5;
#else
  const int max_classifier_idx = 3;
#endif

  int classifier_index = read_default_classifier_index(max_classifier_idx);

  auto load_svm_classifier = [&](int idx) -> bool
  {
    if (idx < 0 || idx > 3)
      return false;
    return svm_classifiers[idx].load_with_scaler(
        coin::data_path(coin::Config::CLASSIFIER_MODEL_PATHS[idx]),
        coin::data_path(coin::Config::SVM_SCALER_PATH),
        coin::Config::CLASSIFIER_NAMES[idx]);
  };

  auto ensure_classifier = [&]() -> bool
  {
    if (classifier_index <= 3)
    {
      if (!svm_classifiers[classifier_index].is_loaded())
      {
        if (!load_svm_classifier(classifier_index))
        {
          std::cerr << "Could not load " << coin::Config::CLASSIFIER_NAMES[classifier_index]
                    << ". Falling back to SVM.\n";
          classifier_index = 0;
          if (!load_svm_classifier(0))
          {
            std::cerr << "Could not load SVM. Run train_svm first.\n";
            return false;
          }
        }
      }
      ctx.active_classifier = &svm_classifiers[classifier_index];
    }
#ifdef COIN_USE_TORCH
    else if (classifier_index == 4)
    {
      if (!torch_cnn.is_loaded() && !torch_cnn.load(coin::data_path(coin::Config::COIN_CNN_TRACED_PATH)))
      {
        std::cerr << "Could not load CNN. Run: python export_torchscript.py\n";
        return false;
      }
      ctx.active_classifier = &torch_cnn;
    }
    else if (classifier_index == 5)
    {
      if (!torch_resnet.is_loaded() && !torch_resnet.load(coin::data_path(coin::Config::COIN_RESNET18_TRACED_PATH)))
      {
        std::cerr << "Could not load ResNet18. Run: python export_torchscript.py\n";
        return false;
      }
      ctx.active_classifier = &torch_resnet;
    }
#endif
    ctx.classifier_display_name = coin::Config::CLASSIFIER_NAMES[classifier_index];
    ctx.clf_cache.invalidate();
    return true;
  };

  if (!ensure_classifier())
    return 1;

#ifdef COIN_USE_TORCH
  std::cout << "Classifier: " << coin::Config::CLASSIFIER_NAMES[classifier_index]
            << " (press 1-6 to switch, t=timings, q=quit)\n";
#else
  std::cout << "Classifier: " << coin::Config::CLASSIFIER_NAMES[classifier_index]
            << " (press 1-4 to switch, t=timings, q=quit)\n";
#endif
  std::cout << "Timings: " << (ctx.print_timings ? "ON" : "OFF") << " (press 't' to toggle)\n"
            << std::endl;

  // --- Main loop ---
  while (true)
  {
    auto frame_start = Clock::now();
    coin::PipelineTimings timings = {};

    cv::Mat frame;
    auto t_cap = Clock::now();
    if (!cap.read(frame))
    {
      if (coin::Config::USE_TEST_VIDEOS && current_video_index >= 0 && current_video_index + 1 < num_test_videos)
      {
        cap.release();
        ++current_video_index;
        cap.open(coin::data_path(test_videos[current_video_index]));
        if (cap.isOpened())
        {
          std::cout << "Next test video: " << test_videos[current_video_index] << "\n";
          continue;
        }
      }
      std::cerr << "Camera/video read failed (disconnected or EOF).\n";
      break;
    }
    if (frame.empty())
    {
      std::cerr << "Dropping empty frame.\n";
      continue;
    }
    timings.capture_ms = Ms(Clock::now() - t_cap).count();

    try
    {
      coin::process_frame(ctx, frame, &timings);

      timings.total_frame_ms = Ms(Clock::now() - frame_start).count();
      if (ctx.print_timings)
      {
        if (ctx.frame_count % 60 == 1)
          std::cerr << "frame    | capture | paper | stabilizer | order+warp | detect_coins | tracker | classify | draw_rest | display | TOTAL (ms) | FPS\n";
        coin::print_timings(timings, ctx.frame_count);
      }
    }
    catch (const cv::Exception &e)
    {
      std::cerr << "OpenCV error (frame skipped): " << e.what() << "\n";
    }
    catch (const std::exception &e)
    {
      std::cerr << "Error (frame skipped): " << e.what() << "\n";
    }

    int key = cv::waitKey(1);
    if (key == 'q')
      break;
    if (key == 't')
    {
      ctx.print_timings = !ctx.print_timings;
      std::cout << "Timings: " << (ctx.print_timings ? "ON" : "OFF") << "\n";
    }
#ifdef COIN_USE_TORCH
    if (key >= '1' && key <= '6')
    {
      classifier_index = key - '1';
      if (ensure_classifier())
        std::cout << "Switched to " << coin::Config::CLASSIFIER_NAMES[classifier_index] << "\n";
    }
#else
    if (key >= '1' && key <= '4')
    {
      classifier_index = key - '1';
      if (ensure_classifier())
        std::cout << "Switched to " << coin::Config::CLASSIFIER_NAMES[classifier_index] << "\n";
    }
#endif
  }

  cap.release();
  cv::destroyAllWindows();
  return 0;
}
