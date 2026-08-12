#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
provider_root=${ISSUE154_PTHREAD_PROVIDER_ROOT:-/private/tmp/issue128-native-cache/providers/native-neon-pthreads-d2b85f7a608fbedd/install}
output_root=${ISSUE154_STANDALONE_OUTPUT_ROOT:-/private/tmp/issue154-overnight-cache/standalone-build}
compiler=${CXX:-/usr/bin/clang++}

test -f "$provider_root/include/fftw3.h"
test -f "$provider_root/lib/libfftw3_threads.3.dylib"
test -f "$provider_root/lib/libfftw3.3.dylib"
mkdir -p "$output_root"

common_flags="-std=c++17 -O3 -mcpu=native -pthread -Wall -Wextra -Wpedantic -Werror -DWV_KERNEL_NATIVE_OPTIMIZATION=1 -DWV_KERNEL_COEFFICIENT_WORKERS=1 -DWV_ISSUE154_HAS_PHASE_SHIFT=1"
common_sources="
$repository_root/CompiledKernel/src/WVKernelTypes.cpp
$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp
$repository_root/Benchmarks/compiled-kernel/WVFFTWEngine.cpp
$repository_root/Benchmarks/compiled-kernel/WVFFTWPhaseShiftConvolution.cpp
$repository_root/tools/compiled-kernel/WVIssue128StandaloneBenchmark.cpp
"

# shellcheck disable=SC2086
"$compiler" $common_flags \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/Benchmarks/compiled-kernel" \
    -I "$provider_root/include" \
    $common_sources \
    "$provider_root/lib/libfftw3_threads.3.dylib" \
    "$provider_root/lib/libfftw3.3.dylib" \
    -Wl,-rpath,"$provider_root/lib" \
    -o "$output_root/wv_issue154_pthreads"

printf '%s\n' "$output_root/wv_issue154_pthreads"
