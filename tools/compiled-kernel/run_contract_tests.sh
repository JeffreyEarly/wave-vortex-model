#!/bin/sh
set -eu

if [ "$(uname -s)" = "Linux" ]; then
    unset LD_LIBRARY_PATH
    unset DYLD_LIBRARY_PATH
fi

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
    -I "$repository_root/CompiledKernel/src" \
    -I "$script_directory/tests" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
    "$script_directory/tests/WVReferenceFFTEngine.cpp" \
    "$script_directory/tests/TestWVKernelContract.cpp" \
    -o "$build_directory/TestWVKernelContract"
"$build_directory/TestWVKernelContract"

"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/CompiledKernel/src" \
    -I "$script_directory/tests" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformBarotropicQGKernel.cpp" \
    "$script_directory/tests/WVReferenceFFTEngine.cpp" \
    "$script_directory/tests/TestWVBarotropicQGKernel.cpp" \
    -o "$build_directory/TestWVBarotropicQGKernel"
"$build_directory/TestWVBarotropicQGKernel"

"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I "$repository_root/CompiledKernel/include" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
    "$script_directory/WVKernelDescriptorDump.cpp" \
    -o "$build_directory/WVKernelDescriptorDump"

"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/CompiledKernel/src" \
    -I "$script_directory/tests" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformBarotropicQGKernel.cpp" \
    "$script_directory/tests/WVReferenceFFTEngine.cpp" \
    "$script_directory/WVBarotropicQGFixtureDump.cpp" \
    -o "$build_directory/WVBarotropicQGFixtureDump"
