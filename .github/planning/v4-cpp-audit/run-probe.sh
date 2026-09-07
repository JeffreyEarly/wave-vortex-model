#!/bin/sh
set -eu
# Usage: sh run-probe.sh FFTW_PROVIDER_ROOT NEW_OR_EXISTING_TEMP_BUILD_DIRECTORY
provider_root=$1
build_directory=$2
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$script_directory/../../.." && pwd)
mkdir -p "$build_directory"
"${CXX:-c++}" -std=c++17 -O2 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/CompiledKernel/adapters/native-fftw" \
    -I "$provider_root/include" \
    "$script_directory/probe.cpp" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
    "$repository_root/CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp" \
    -L "$provider_root/lib" -lfftw3_threads -lfftw3 \
    -Wl,-rpath,"$provider_root/lib" -o "$build_directory/v4-cpp-audit-probe"
"$build_directory/v4-cpp-audit-probe"
