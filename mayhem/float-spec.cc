// Fuzzes the floating-point format-spec parser and formatters: a float/double/long double value plus a
// fuzzed spec inside "{:...}". Complements test/fuzzing/float.cc, which only round-trips "{}" and "{:.50g}".
#include <fmt/format.h>

#include <cstdint>
#include <exception>
#include <string>

#include "fuzzer-common.h"

template <typename T> void format_float(const uint8_t* data, size_t size) {
  auto value = assign_from_buf<T>(data);
  std::string spec = "{:";
  spec.append(as_chars(data + fixed_size), size - fixed_size);
  spec.push_back('}');
  try {
    auto buf = fmt::memory_buffer();
    fmt::format_to(std::back_inserter(buf), fmt::runtime(spec), value);
  } catch (std::exception&) {
  }
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size <= fixed_size + 1) return -1;
  const auto type = data[0] % 3;
  data++;
  size--;
  if (type == 0) format_float<float>(data, size);
  else if (type == 1) format_float<double>(data, size);
  else format_float<long double>(data, size);
  return 0;
}
