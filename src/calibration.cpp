#include "calibration.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace coin
{

  double pixel_diameter_to_mm(double diameter_px, double ratio_px_to_mm)
  {
    if (ratio_px_to_mm <= 0)
      return 0.0;
    return diameter_px * ratio_px_to_mm;
  }

  int diameter_mm_to_radius_px(double diameter_mm, double ratio_px_to_mm)
  {
    if (ratio_px_to_mm <= 0)
      return 2;
    int r = static_cast<int>((diameter_mm / ratio_px_to_mm) / 2);
    return std::max(2, r);
  }

}
