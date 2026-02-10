#pragma once

#include "classifier_interface.hpp"
#include "config.hpp"
#include "types.hpp"
#include <opencv2/core.hpp>
#include <string>
#include <memory>
#include <utility>
#include <vector>

#ifdef COIN_USE_TORCH
#include <torch/script.h>
#endif

namespace coin
{

  class TorchClassifier : public IClassifier
  {
  public:
    TorchClassifier() = default;
    ~TorchClassifier() override = default;

    bool load(const std::string &model_path) override;
    bool is_loaded() const override { return module_ != nullptr; }
    std::string name() const override { return name_; }
    void set_name(const std::string &n) { name_ = n; }

    int predict_single(const cv::Mat &frame_bgr,
                       cv::Point2i center, int radius_px,
                       double diameter_mm, double L, double a, double b) const override;

    std::vector<int> predict_batch(const cv::Mat &frame_bgr,
                                   const std::vector<std::pair<cv::Point2i, int>> &centers_radii,
                                   const std::vector<std::tuple<double, double, double, double>> &features) const override;

  private:
#ifdef COIN_USE_TORCH
    struct Impl
    {
      torch::jit::script::Module module;
    };
#else
    struct Impl;
#endif
    std::unique_ptr<Impl> module_;
    std::string name_ = "CNN";
  };

}
