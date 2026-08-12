cmake_minimum_required(VERSION 3.20)
project(WaveVortexCheckpoint VERSION 0.1.0 LANGUAGES CXX)

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

add_library(WaveVortexCheckpoint STATIC
    src/WVNetCDF.cpp
    src/WVForcingScheduleDecoder.cpp
    src/WVCheckpointReader.cpp
)
add_library(WaveVortex::Checkpoint ALIAS WaveVortexCheckpoint)

target_compile_features(WaveVortexCheckpoint PUBLIC cxx_std_17)
target_include_directories(WaveVortexCheckpoint PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(WaveVortexCheckpoint PUBLIC WaveVortex::Kernel PRIVATE ${WAVEVORTEX_NETCDF_TARGET})
set_target_properties(WaveVortexCheckpoint PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexCheckpoint PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

if(BUILD_TESTING)
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
endif()
