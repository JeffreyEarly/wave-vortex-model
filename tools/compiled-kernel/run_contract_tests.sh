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
"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    -I "$repository_root/CompiledKernel/include" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
    "$script_directory/tests/WVReferenceFFTEngine.cpp" \
    "$script_directory/tests/TestWVKernelContract.cpp" \
    -o "$build_directory/TestWVKernelContract"
"$build_directory/TestWVKernelContract"

if command -v pkg-config >/dev/null 2>&1; then
    netcdf_cflags=$(pkg-config --cflags netcdf)
    netcdf_libs=$(pkg-config --libs netcdf)
elif command -v nc-config >/dev/null 2>&1; then
    netcdf_cflags=$(nc-config --cflags)
    netcdf_libs=$(nc-config --libs)
else
    echo "The portable checkpoint tests require pkg-config or nc-config for the NetCDF C library." >&2
    exit 2
fi

# The compiler and linker flags are intentionally expanded from the trusted
# NetCDF configuration tool so each emitted flag remains a separate argument.
# shellcheck disable=SC2086
"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    -DWV_CHECKPOINT_FIXTURE_DIR="\"$repository_root/tools/portable-runtime/fixtures\"" \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/PortableRuntime/include" \
    $netcdf_cflags \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/PortableRuntime/src/WVNetCDF.cpp" \
    "$repository_root/PortableRuntime/src/WVCheckpointReader.cpp" \
    "$repository_root/tools/portable-runtime/tests/TestWVCheckpointReader.cpp" \
    $netcdf_libs \
    -o "$build_directory/TestWVCheckpointReader"
"$build_directory/TestWVCheckpointReader"

# shellcheck disable=SC2086
"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    -I "$repository_root/CompiledKernel/include" \
    -I "$repository_root/PortableRuntime/include" \
    $netcdf_cflags \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/PortableRuntime/src/WVNetCDF.cpp" \
    "$repository_root/PortableRuntime/src/WVCheckpointReader.cpp" \
    "$repository_root/tools/portable-runtime/WVCheckpointInspect.cpp" \
    $netcdf_libs \
    -o "$build_directory/wv_checkpoint_inspect"

"$compiler" -std=c++17 -Wall -Wextra -Wpedantic -Werror \
    -I "$repository_root/CompiledKernel/include" \
    "$repository_root/CompiledKernel/src/WVKernelTypes.cpp" \
    "$repository_root/CompiledKernel/src/WVTransformConstantStratificationKernel.cpp" \
    "$script_directory/WVKernelDescriptorDump.cpp" \
    -o "$build_directory/WVKernelDescriptorDump"
