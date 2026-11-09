// Fuzzes fmt::gmtime(time_t) + the std::tm chrono formatter: a time_t plus a fuzzed strftime-style spec
// (%G, %g, %V, ...). Upstream's chrono-timepoint.cc goes through system_clock (nanoseconds), so it never
// reaches years past 2262; fmt::gmtime(time_t) reaches every year glibc's gmtime_r can represent.
#include <fmt/chrono.h>

#include <cstdint>
#include <ctime>
#include <exception>

#include "fuzzer-common.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  constexpr auto N = sizeof(std::int64_t);
  if (size < N) return -1;
  const auto secs = assign_from_buf<std::int64_t>(data);
  data_to_string spec(data + N, size - N);
  try {
    auto tm = fmt::gmtime(static_cast<std::time_t>(secs));
    auto s = fmt::format(fmt::runtime(spec.get()), tm);
  } catch (std::exception&) {
  }
  return 0;
}
