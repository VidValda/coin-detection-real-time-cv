#include "data_path.hpp"
#include <cstdlib>
#include <cstring>
#include <filesystem>

namespace coin
{

static std::string s_data_root = ".";

void init_data_root(int argc, char **argv)
{
  if (argc > 1 && argv[1] && argv[1][0] != '\0')
  {
    s_data_root = argv[1];
    if (s_data_root.back() == '/')
      s_data_root.pop_back();
    return;
  }
  const char *env = std::getenv("COIN_DATA_DIR");
  if (env && env[0] != '\0')
  {
    s_data_root = env;
    if (s_data_root.back() == '/')
      s_data_root.pop_back();
    return;
  }
  s_data_root = ".";
}

std::string data_root()
{
  return s_data_root;
}

std::string data_path(const char *relative)
{
  if (!relative || relative[0] == '\0')
    return s_data_root;
  std::string path;
  if (s_data_root == ".")
    path = relative;
  else
    path = s_data_root + "/" + relative;
  std::error_code ec;
  std::filesystem::path abs = std::filesystem::absolute(path, ec);
  if (!ec)
    return abs.string();
  return path;
}

}
