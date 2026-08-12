cmake_minimum_required(VERSION 3.20)
project(WaveVortexKernel VERSION 0.1.0 LANGUAGES CXX)
find_package(Threads REQUIRED)
set(WV_KERNEL_ISSUE130_VARIANT 0 CACHE STRING "Author-only issue #130 screening variant (0, 2, 3, or 4)")
set_property(CACHE WV_KERNEL_ISSUE130_VARIANT PROPERTY STRINGS 0 2 3 4)
if(NOT WV_KERNEL_ISSUE130_VARIANT MATCHES "^(0|2|3|4)$")
    message(FATAL_ERROR "WV_KERNEL_ISSUE130_VARIANT must be 0, 2, 3, or 4")
endif()
set(WV_KERNEL_HORIZONTAL_Z_BATCH 0 CACHE STRING "Author-only horizontal z batch (0, 16, 32, or 64)")
set_property(CACHE WV_KERNEL_HORIZONTAL_Z_BATCH PROPERTY STRINGS 0 16 32 64)
set(WV_KERNEL_VERTICAL_HALF_ROW_BATCH 0 CACHE STRING "Author-only vertical half-row batch (0, 256, 1024, or 4096)")
set_property(CACHE WV_KERNEL_VERTICAL_HALF_ROW_BATCH PROPERTY STRINGS 0 256 1024 4096)
if(NOT WV_KERNEL_HORIZONTAL_Z_BATCH MATCHES "^(0|16|32|64)$")
    message(FATAL_ERROR "WV_KERNEL_HORIZONTAL_Z_BATCH must be 0, 16, 32, or 64")
endif()
if(NOT WV_KERNEL_VERTICAL_HALF_ROW_BATCH MATCHES "^(0|256|1024|4096)$")
    message(FATAL_ERROR "WV_KERNEL_VERTICAL_HALF_ROW_BATCH must be 0, 256, 1024, or 4096")
endif()

add_library(WaveVortexKernel STATIC
    src/WVKernelTypes.cpp
    src/WVTransformConstantStratificationKernel.cpp
)
add_library(WaveVortex::Kernel ALIAS WaveVortexKernel)

target_compile_features(WaveVortexKernel PUBLIC cxx_std_17)
target_include_directories(WaveVortexKernel PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(WaveVortexKernel PUBLIC Threads::Threads)
target_compile_definitions(WaveVortexKernel PUBLIC WV_KERNEL_ISSUE130_VARIANT=${WV_KERNEL_ISSUE130_VARIANT})
target_compile_definitions(WaveVortexKernel PUBLIC WV_KERNEL_HORIZONTAL_Z_BATCH=${WV_KERNEL_HORIZONTAL_Z_BATCH} WV_KERNEL_VERTICAL_HALF_ROW_BATCH=${WV_KERNEL_VERTICAL_HALF_ROW_BATCH})
set_target_properties(WaveVortexKernel PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexKernel PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
