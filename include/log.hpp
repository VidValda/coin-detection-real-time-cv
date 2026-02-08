#pragma once

#include <iostream>
#include <string>
#include <chrono>
#include <iomanip>
#include <sstream>

namespace coin
{
  namespace log
  {

    enum class Level { DEBUG, INFO, WARN, ERROR };

    inline Level &min_level()
    {
      static Level lvl = Level::INFO;
      return lvl;
    }

    inline const char *level_str(Level lvl)
    {
      switch (lvl)
      {
      case Level::DEBUG: return "DEBUG";
      case Level::INFO:  return "INFO ";
      case Level::WARN:  return "WARN ";
      case Level::ERROR: return "ERROR";
      }
      return "?????";
    }

    inline std::string timestamp()
    {
      auto now = std::chrono::system_clock::now();
      auto t = std::chrono::system_clock::to_time_t(now);
      auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                    now.time_since_epoch()) % 1000;
      std::ostringstream oss;
      oss << std::put_time(std::localtime(&t), "%H:%M:%S")
          << '.' << std::setfill('0') << std::setw(3) << ms.count();
      return oss.str();
    }

    inline void log_msg(Level lvl, const std::string &msg)
    {
      if (lvl < min_level())
        return;
      std::ostream &out = (lvl >= Level::WARN) ? std::cerr : std::cout;
      out << "[" << timestamp() << " " << level_str(lvl) << "] " << msg << "\n";
    }

    inline void debug(const std::string &msg) { log_msg(Level::DEBUG, msg); }
    inline void info(const std::string &msg) { log_msg(Level::INFO, msg); }
    inline void warn(const std::string &msg) { log_msg(Level::WARN, msg); }
    inline void error(const std::string &msg) { log_msg(Level::ERROR, msg); }

  }
}
