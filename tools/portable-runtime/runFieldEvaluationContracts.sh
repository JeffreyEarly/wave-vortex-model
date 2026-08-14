#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH= cd -- "$script_directory/../.." && pwd)
build_directory=${1:-"$repository_root/tools/compiled-kernel/build-portable"}

if command -v cmake >/dev/null 2>&1; then
    cmake -S "$repository_root/PortableRuntime" -B "$build_directory" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$build_directory" --parallel --target TestWVFieldEvaluation wv_field_evaluation_inspect wv_lagrangian_particle_inspect
    ctest --test-dir "$build_directory" --output-on-failure -R '^field-evaluation$'
    printf '%s\n' "$build_directory/wv_field_evaluation_inspect"
    exit 0
fi

mkdir -p "$build_directory"
compiler=${CXX:-c++}
if ! command -v pkg-config >/dev/null 2>&1 || ! pkg-config --exists netcdf; then
    echo "CMake is unavailable and pkg-config could not resolve netCDF." >&2
    exit 2
fi
netcdf_flags=$(pkg-config --cflags --libs netcdf)
common_flags="-std=c++17 -Wall -Wextra -Wpedantic -Werror -pthread"
include_flags="-I$repository_root/CompiledKernel/include -I$repository_root/CompiledKernel/adapters/reference -I$repository_root/PortableRuntime/include -I$repository_root/PortableRuntime/src"
kernel_sources="$repository_root/CompiledKernel/src/WVKernelTypes.cpp $repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp $repository_root/CompiledKernel/adapters/reference/WVReferenceFFTEngine.cpp"
service_source="$repository_root/PortableRuntime/src/WVFieldEvaluationService.cpp"

# Intentional word splitting expands these fixed compiler flag and source lists.
# shellcheck disable=SC2086
"$compiler" $common_flags $include_flags \
    "$repository_root/tools/portable-runtime/tests/TestWVFieldEvaluation.cpp" \
    $service_source $kernel_sources \
    -o "$build_directory/TestWVFieldEvaluation"
"$build_directory/TestWVFieldEvaluation"

# shellcheck disable=SC2086
"$compiler" $common_flags $include_flags $netcdf_flags \
    "$repository_root/tools/portable-runtime/WVFieldEvaluationInspect.cpp" \
    "$repository_root/PortableRuntime/src/WVNetCDF.cpp" \
    "$repository_root/PortableRuntime/src/WVForcingScheduleDecoder.cpp" \
    "$repository_root/PortableRuntime/src/WVCheckpointReader.cpp" \
    $service_source $kernel_sources \
    -o "$build_directory/wv_field_evaluation_inspect"
printf '%s\n' "$build_directory/wv_field_evaluation_inspect"
