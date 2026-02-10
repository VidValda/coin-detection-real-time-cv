#pragma once

#include "classifier_interface.hpp"
#include <opencv2/core.hpp>
#include <opencv2/ml.hpp>
#include <string>
#include <vector>

namespace coin
{

  class SVMClassifier : public IClassifier
  {
  public:
    bool load(const std::string &model_path) override;
    bool load_with_scaler(const std::string &model_path, const std::string &scaler_path);
    bool load_with_scaler(const std::string &model_path, const std::string &scaler_path, const std::string &model_type);
    bool is_loaded() const override { return model_ != nullptr; }
    std::string name() const override { return name_; }

    int predict(double diameter_mm, double L, double a, double b) const;

    int predict_single(const cv::Mat &frame_bgr,
                       cv::Point2i center, int radius_px,
                       double diameter_mm, double L, double a, double b) const override;

    std::vector<int> predict_batch(const cv::Mat &frame_bgr,
                                   const std::vector<std::pair<cv::Point2i, int>> &centers_radii,
                                   const std::vector<std::tuple<double, double, double, double>> &features) const override;

    void set_name(const std::string &n) { name_ = n; }

  private:
    cv::Ptr<cv::ml::StatModel> model_;
    cv::Mat scaler_mean_;
    cv::Mat scaler_scale_;
    std::string name_ = "SVM";
    std::string scaler_path_;
  };

}
