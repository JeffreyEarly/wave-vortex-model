cmake_minimum_required(VERSION 3.20)
project(WaveVortexKernel VERSION 0.1.0 LANGUAGES CXX)

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
set_target_properties(WaveVortexKernel PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

option(WAVEVORTEX_ENABLE_FFTW "Build the optional FFTW engine" OFF)
if(WAVEVORTEX_ENABLE_FFTW)
    find_path(FFTW3_INCLUDE_DIR fftw3.h REQUIRED)
    find_library(FFTW3_LIBRARY NAMES fftw3 mwfftw3 REQUIRED)
    add_library(WaveVortexFFTWEngine STATIC src/WVFFTWEngine.cpp)
    add_library(WaveVortex::FFTWEngine ALIAS WaveVortexFFTWEngine)
    target_compile_features(WaveVortexFFTWEngine PUBLIC cxx_std_17)
    target_include_directories(WaveVortexFFTWEngine PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
        PRIVATE ${FFTW3_INCLUDE_DIR}
    )
    target_link_libraries(WaveVortexFFTWEngine PUBLIC WaveVortex::Kernel PRIVATE ${FFTW3_LIBRARY} ${CMAKE_DL_LIBS})
    set_target_properties(WaveVortexFFTWEngine PROPERTIES CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON)
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(WaveVortexFFTWEngine PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
endif()

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexKernel PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
