#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cache_root=${ISSUE152_CACHE_ROOT:-/private/tmp/issue152-overnight-cache}
fftwpp_root=$cache_root/fftwpp-source
pthread_root=$cache_root/providers/pthreads/install
openmp_root=$cache_root/providers/openmp/install
openmp_include=$cache_root/openmp/install/include
output_root=$cache_root/build
compiler=${CXX:-/usr/bin/clang++}
expected_fftwpp=e685733aba768d77e9234ca02092632f7ccb4c86

test "$(git -C "$fftwpp_root" rev-parse HEAD)" = "$expected_fftwpp"
test -z "$(git -C "$fftwpp_root" status --porcelain)"
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
    -o "$output_root/wv_issue152_pthreads"

openmp_output=$openmp_root/lib/wv_issue152_openmp
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

printf '%s\n' "$output_root/wv_issue152_pthreads" "$openmp_output"
