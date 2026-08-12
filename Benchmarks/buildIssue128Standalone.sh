#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fftwpp_root=${FFTWPP_SOURCE_ROOT:-/private/tmp/issue128-fftwpp-source}
pthread_root=${ISSUE128_PTHREAD_PROVIDER_ROOT:-/private/tmp/issue128-native-cache/providers/native-neon-pthreads-d2b85f7a608fbedd/install}
openmp_root=${ISSUE128_OPENMP_PROVIDER_ROOT:-/private/tmp/issue128-native-cache/providers/native-neon-openmp-872739bfc5992370/install}
openmp_include=${ISSUE128_OPENMP_INCLUDE:-/private/tmp/issue128-native-cache/openmp/llvm-22.1.8-622d9c27e077dd1a/install/include}
output_root=${ISSUE128_STANDALONE_OUTPUT_ROOT:-/private/tmp/issue128-standalone-build}
compiler=${CXX:-/usr/bin/clang++}

expected_fftwpp=1a185f41800cd0e9d4df4ddf93e16e362d4e2c45
actual_fftwpp=$(git -C "$fftwpp_root" rev-parse HEAD)
test "$actual_fftwpp" = "$expected_fftwpp"
test -f "$pthread_root/lib/libfftw3_threads.3.dylib"
test -f "$openmp_root/lib/libfftw3_omp.3.dylib"
test -f "$openmp_root/lib/libwvissue137omp.dylib"
test -f "$openmp_include/omp.h"
mkdir -p "$output_root"

common_flags="-std=c++17 -O3 -mcpu=native -pthread -Wall -Wextra -Wpedantic -Werror -DWV_KERNEL_NATIVE_OPTIMIZATION=1 -DWV_KERNEL_COEFFICIENT_WORKERS=1"
common_sources="
$repository_root/CompiledKernel/src/WVKernelTypes.cpp
$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp
$repository_root/Benchmarks/compiled-kernel/WVFFTWEngine.cpp
$repository_root/tools/compiled-kernel/WVIssue128StandaloneBenchmark.cpp
"

# shellcheck disable=SC2086
"$compiler" $common_flags \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/Benchmarks/compiled-kernel" \
    -I "$pthread_root/include" \
    $common_sources \
    "$pthread_root/lib/libfftw3_threads.3.dylib" \
    "$pthread_root/lib/libfftw3.3.dylib" \
    -Wl,-rpath,"$pthread_root/lib" \
    -o "$output_root/wv_issue128_pthreads"

# The direct libomp dependency uses @loader_path, so emit this executable
# beside the isolated provider runtime. No MATLAB libraries are linked.
openmp_output="$openmp_root/lib/wv_issue128_openmp"
# shellcheck disable=SC2086
"$compiler" $common_flags -Wno-unused-parameter -Wno-deprecated-copy-with-user-provided-copy -DWV_ISSUE128_HAS_FFTWPP=1 -Xpreprocessor -fopenmp \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/Benchmarks/compiled-kernel" \
    -I "$openmp_root/include" \
    -I "$openmp_include" \
    -I "$fftwpp_root" \
    $common_sources \
    "$repository_root/Benchmarks/compiled-kernel/WVFFTWPlusPlusConvolution.cpp" \
    "$fftwpp_root/fftw++.cc" \
    "$fftwpp_root/parallel.cc" \
    "$fftwpp_root/convolve.cc" \
    "$openmp_root/lib/libfftw3_omp.3.dylib" \
    "$openmp_root/lib/libfftw3.3.dylib" \
    "$openmp_root/lib/libwvissue137omp.dylib" \
    -Wl,-rpath,"$openmp_root/lib" \
    -o "$openmp_output"

printf '%s\n' "$output_root/wv_issue128_pthreads" "$openmp_output"
