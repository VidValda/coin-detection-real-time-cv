#pragma once

#include <string>

namespace coin
{

void init_data_root(int argc, char **argv);

std::string data_root();

std::string data_path(const char *relative);

inline std::string data_path(const std::string &relative)
{
  return data_path(relative.c_str());
}

}
