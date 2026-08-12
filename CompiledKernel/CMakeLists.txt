cmake_minimum_required(VERSION 3.20)
project(WaveVortexKernel VERSION 0.1.0 LANGUAGES CXX)
find_package(Threads REQUIRED)
set(WV_KERNEL_ISSUE130_VARIANT 0 CACHE STRING "Author-only issue #130 screening variant (0, 2, 3, or 4)")
set_property(CACHE WV_KERNEL_ISSUE130_VARIANT PROPERTY STRINGS 0 2 3 4)
if(NOT WV_KERNEL_ISSUE130_VARIANT MATCHES "^(0|2|3|4)$")
    message(FATAL_ERROR "WV_KERNEL_ISSUE130_VARIANT must be 0, 2, 3, or 4")
endif()
option(WV_KERNEL_ISSUE158_INPLACE_ARENA "Author-only issue #158 in-place arena prototype" OFF)
if(WV_KERNEL_ISSUE158_INPLACE_ARENA AND NOT WV_KERNEL_ISSUE130_VARIANT STREQUAL "3")
    message(FATAL_ERROR "WV_KERNEL_ISSUE158_INPLACE_ARENA requires WV_KERNEL_ISSUE130_VARIANT=3")
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
if(WV_KERNEL_ISSUE158_INPLACE_ARENA)
    target_compile_definitions(WaveVortexKernel PUBLIC WV_KERNEL_ISSUE158_INPLACE_ARENA=1)
endif()
set_target_properties(WaveVortexKernel PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexKernel PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
