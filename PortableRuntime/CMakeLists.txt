cmake_minimum_required(VERSION 3.20)
project(WaveVortexPortableRuntime VERSION 0.1.0 LANGUAGES CXX)

include(CTest)

if(NOT TARGET WaveVortex::Kernel)
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../CompiledKernel ${CMAKE_CURRENT_BINARY_DIR}/kernel)
endif()

find_package(netCDF CONFIG QUIET)
if(TARGET netCDF::netcdf)
    set(WAVEVORTEX_NETCDF_TARGET netCDF::netcdf)
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(NETCDF REQUIRED IMPORTED_TARGET netcdf)
    set(WAVEVORTEX_NETCDF_TARGET PkgConfig::NETCDF)
endif()

add_library(WaveVortexPortableRuntime STATIC
    src/WVNetCDF.cpp
    src/WVForcingScheduleDecoder.cpp
    src/WVCheckpointReader.cpp
    src/WVForcingEngine.cpp
    src/WVFixedStepRK4.cpp
)
add_library(WaveVortex::PortableRuntime ALIAS WaveVortexPortableRuntime)
add_library(WaveVortex::Checkpoint ALIAS WaveVortexPortableRuntime)

target_compile_features(WaveVortexPortableRuntime PUBLIC cxx_std_17)
target_include_directories(WaveVortexPortableRuntime PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(WaveVortexPortableRuntime PUBLIC WaveVortex::Kernel PRIVATE ${WAVEVORTEX_NETCDF_TARGET})
set_target_properties(WaveVortexPortableRuntime PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexPortableRuntime PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

if(BUILD_TESTING)
    add_executable(wv_checkpoint_inspect
        ../tools/portable-runtime/WVCheckpointInspect.cpp
    )
    target_compile_features(wv_checkpoint_inspect PRIVATE cxx_std_17)
    target_link_libraries(wv_checkpoint_inspect PRIVATE WaveVortex::Checkpoint)

    add_executable(wv_portable_forcing_inspect
        ../tools/portable-runtime/WVPortableForcingInspect.cpp
        ../tools/compiled-kernel/tests/WVReferenceFFTEngine.cpp
    )
    target_compile_features(wv_portable_forcing_inspect PRIVATE cxx_std_17)
    target_include_directories(wv_portable_forcing_inspect PRIVATE ../tools/compiled-kernel/tests)
    target_link_libraries(wv_portable_forcing_inspect PRIVATE WaveVortex::Checkpoint)

    add_executable(wv_portable_rk4_inspect
        ../tools/portable-runtime/WVPortableRK4Inspect.cpp
        ../tools/compiled-kernel/tests/WVReferenceFFTEngine.cpp
    )
    target_compile_features(wv_portable_rk4_inspect PRIVATE cxx_std_17)
    target_include_directories(wv_portable_rk4_inspect PRIVATE ../tools/compiled-kernel/tests)
    target_link_libraries(wv_portable_rk4_inspect PRIVATE WaveVortex::Checkpoint)

    add_executable(TestWVCheckpointReader
        ../tools/portable-runtime/tests/TestWVCheckpointReader.cpp
    )
    target_compile_features(TestWVCheckpointReader PRIVATE cxx_std_17)
    target_link_libraries(TestWVCheckpointReader PRIVATE WaveVortex::Checkpoint ${WAVEVORTEX_NETCDF_TARGET})
    target_compile_definitions(TestWVCheckpointReader PRIVATE
        WV_CHECKPOINT_FIXTURE_DIR="${CMAKE_CURRENT_LIST_DIR}/../tools/portable-runtime/fixtures"
    )
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(TestWVCheckpointReader PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    add_test(NAME checkpoint-reader COMMAND TestWVCheckpointReader)

    add_executable(TestWVForcingAndRK4
        ../tools/portable-runtime/tests/TestWVForcingAndRK4.cpp
        ../tools/compiled-kernel/tests/WVReferenceFFTEngine.cpp
    )
    target_compile_features(TestWVForcingAndRK4 PRIVATE cxx_std_17)
    target_include_directories(TestWVForcingAndRK4 PRIVATE ../tools/compiled-kernel/tests)
    target_link_libraries(TestWVForcingAndRK4 PRIVATE WaveVortex::Checkpoint)
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(TestWVForcingAndRK4 PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    add_test(NAME forcing-and-rk4 COMMAND TestWVForcingAndRK4)
endif()
