#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$script_directory/../.." && pwd)
build_directory=${1:-"$script_directory/build"}

if command -v cmake >/dev/null 2>&1; then
    cmake -S "$script_directory" -B "$build_directory" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$build_directory" --parallel
    ctest --test-dir "$build_directory" --output-on-failure
    exit 0
fi

mkdir -p "$build_directory"
compiler=${CXX:-c++}
"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I "$repository_root/CompiledKernel/include" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
    "$script_directory/tests/WVReferenceFFTEngine.cpp" \
    "$script_directory/tests/TestWVKernelContract.cpp" \
    -o "$build_directory/TestWVKernelContract"
"$build_directory/TestWVKernelContract"

"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I "$repository_root/CompiledKernel/include" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
    "$script_directory/WVKernelDescriptorDump.cpp" \
    -o "$build_directory/WVKernelDescriptorDump"
