#pragma once

#include <opencv2/core.hpp>
#include <string>
#include <vector>
#include <utility>

namespace coin
{

  class IClassifier
  {
  public:
    virtual ~IClassifier() = default;

    virtual bool load(const std::string &model_path) = 0;
    virtual bool is_loaded() const = 0;
    virtual std::string name() const = 0;

    virtual int predict_single(const cv::Mat &frame_bgr,
                               cv::Point2i center, int radius_px,
                               double diameter_mm, double L, double a, double b) const = 0;

    virtual std::vector<int> predict_batch(const cv::Mat &frame_bgr,
                                           const std::vector<std::pair<cv::Point2i, int>> &centers_radii,
                                           const std::vector<std::tuple<double, double, double, double>> &features) const = 0;
  };

}
