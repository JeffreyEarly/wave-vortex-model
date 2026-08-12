#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cache_root=${ISSUE152_CACHE_ROOT:-/private/tmp/issue152-overnight-cache}
fftwpp_root=$cache_root/fftwpp-source
provider_root=$cache_root/providers/openmp/install
openmp_root=$cache_root/openmp/install
compiler=${CXX:-/usr/bin/clang++}
expected_fftwpp=e685733aba768d77e9234ca02092632f7ccb4c86

test "$(git -C "$fftwpp_root" rev-parse HEAD)" = "$expected_fftwpp"
test -z "$(git -C "$fftwpp_root" status --porcelain)"
test -f "$provider_root/lib/libfftw3_omp.3.dylib"
test -f "$provider_root/lib/libfftw3.3.dylib"
test -f "$provider_root/lib/libwvissue137omp.dylib"
test -f "$openmp_root/include/omp.h"

output=$provider_root/lib/wv_issue152_asymmetric_mimo_reproducer

"$compiler" -std=c++17 -O2 -mcpu=native -pthread -Wall -Wextra -Wpedantic -Werror \
    -Wno-unused-parameter -Wno-deprecated-copy-with-user-provided-copy \
    -Xpreprocessor -fopenmp \
    -I "$fftwpp_root" \
    -I "$fftwpp_root/tests" \
    -I "$provider_root/include" \
    -I "$openmp_root/include" \
    "$repository_root/tools/compiled-kernel/WVIssue152AsymmetricMIMOReproducer.cpp" \
    "$fftwpp_root/tests/direct.cc" \
    "$fftwpp_root/fftw++.cc" \
    "$fftwpp_root/parallel.cc" \
    "$fftwpp_root/convolve.cc" \
    "$provider_root/lib/libfftw3_omp.3.dylib" \
    "$provider_root/lib/libfftw3.3.dylib" \
    "$provider_root/lib/libwvissue137omp.dylib" \
    -Wl,-rpath,"$provider_root/lib" \
    -o "$output"

printf '%s\n' "$output"
