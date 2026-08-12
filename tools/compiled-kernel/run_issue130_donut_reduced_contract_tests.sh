#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$script_directory/../.." && pwd)
build_root=${1:?Usage: run_issue130_donut_reduced_contract_tests.sh BUILD_ROOT}

for variant in 0 3 4; do
    build_directory="$build_root/variant-$variant"
    if command -v cmake >/dev/null 2>&1; then
        cmake -S "$script_directory" -B "$build_directory" -DCMAKE_BUILD_TYPE=Release -DWV_KERNEL_ISSUE130_VARIANT="$variant"
        cmake --build "$build_directory" --parallel 18
        ctest --test-dir "$build_directory" --output-on-failure
    else
        mkdir -p "$build_directory"
        compiler=${CXX:-c++}
        "$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror -pthread -DWV_KERNEL_ISSUE130_VARIANT="$variant" \
            -I "$repository_root/CompiledKernel/include" \
            "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
            "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
            "$script_directory/tests/WVReferenceFFTEngine.cpp" \
            "$script_directory/tests/TestWVKernelContract.cpp" \
            -o "$build_directory/TestWVKernelContract"
        "$build_directory/TestWVKernelContract"
    fi
done
