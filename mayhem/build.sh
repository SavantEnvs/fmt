#!/usr/bin/env bash
# Builds the sanitized libFuzzer harnesses (+ run-once standalone reproducers) and fmt's own gtest suite.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

HARNESSES="chrono-duration chrono-timepoint float named-arg one-arg two-args"
FUZZ_DEFS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION="

# 1) fmt itself, sanitized with DWARF-3. build/ is gitignored upstream.
cmake -S . -B build/fuzz -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=None -DFMT_DOC=OFF -DFMT_TEST=OFF -DFMT_FUZZ=OFF \
  -DCMAKE_CXX_STANDARD=17 -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_CXX_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -O1 $FUZZ_DEFS"
cmake --build build/fuzz -j"$MAYHEM_JOBS"

# 2) harnesses: libFuzzer binary + standalone reproducer (driver compiled as C to keep C linkage).
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o build/standalone_main.o
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o build/lsan_off.o
for h in $HARNESSES; do
  src=test/fuzzing/$h.cc
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -std=c++17 $FUZZ_DEFS -Iinclude -Itest/fuzzing \
    $LIB_FUZZING_ENGINE "$src" build/lsan_off.o build/fuzz/libfmt.a -o "/mayhem/$h-fuzzer"
  $CXX $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -std=c++17 $FUZZ_DEFS -Iinclude -Itest/fuzzing \
    "$src" build/standalone_main.o build/lsan_off.o build/fuzz/libfmt.a -o "/mayhem/$h-fuzzer-standalone"
done

# Extra harness (not upstream's): fuzzed float format spec; upstream float.cc only round-trips two fixed specs.
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -std=c++17 $FUZZ_DEFS -Iinclude -Itest/fuzzing \
  $LIB_FUZZING_ENGINE mayhem/float-spec.cc build/lsan_off.o build/fuzz/libfmt.a -o /mayhem/float-spec-fuzzer
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -std=c++17 $FUZZ_DEFS -Iinclude -Itest/fuzzing \
  mayhem/float-spec.cc build/standalone_main.o build/lsan_off.o build/fuzz/libfmt.a -o /mayhem/float-spec-fuzzer-standalone

# 3) fmt's gtest suite with NORMAL flags (no sanitizers); test.sh only runs it.
cmake -S . -B build/tests -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release -DFMT_DOC=OFF -DFMT_TEST=ON -DFMT_FUZZ=OFF -DFMT_WERROR=OFF \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS" -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS"
cmake --build build/tests -j"$MAYHEM_JOBS"
