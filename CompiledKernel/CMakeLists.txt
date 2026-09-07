cmake_minimum_required(VERSION 3.20)
project(WaveVortexKernel VERSION 0.1.0 LANGUAGES CXX)
find_package(Threads REQUIRED)

add_library(WaveVortexKernel STATIC
    src/WVRetainedHorizontalOperator.cpp
    src/WVPreparedVerticalOperator.cpp
    src/WVTransformStratifiedQGKernel.cpp
    src/WVKernelTypes.cpp
    src/WVTransformBarotropicQGKernel.cpp
    src/WVTransformConstantStratificationKernel.cpp
)
add_library(WaveVortex::Kernel ALIAS WaveVortexKernel)

add_library(WaveVortexReferenceFFT STATIC
    adapters/reference/WVReferenceFFTEngine.cpp
)
add_library(WaveVortex::ReferenceFFT ALIAS WaveVortexReferenceFFT)
target_compile_features(WaveVortexReferenceFFT PUBLIC cxx_std_17)
target_include_directories(WaveVortexReferenceFFT PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/adapters/reference>
)
target_link_libraries(WaveVortexReferenceFFT PUBLIC WaveVortexKernel)
set_target_properties(WaveVortexReferenceFFT PROPERTIES CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON)

target_compile_features(WaveVortexKernel PUBLIC cxx_std_17)
target_include_directories(WaveVortexKernel PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(WaveVortexKernel PUBLIC Threads::Threads)
set_target_properties(WaveVortexKernel PROPERTIES
    CXX_EXTENSIONS OFF
    POSITION_INDEPENDENT_CODE ON
)

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexKernel PRIVATE -Wall -Wextra -Wpedantic -Werror)
    target_compile_options(WaveVortexReferenceFFT PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

# Optional native matrix service; the portable core never includes vendor APIs.
option(WV_ENABLE_ACCELERATE "Enable the Apple Accelerate matrix adapter" ${APPLE})
if(WV_ENABLE_ACCELERATE AND NOT APPLE)
    message(FATAL_ERROR "Accelerate is available only on Apple platforms.")
endif()
add_library(WaveVortexAccelerateMatrix STATIC adapters/accelerate/WVAccelerateMatrixBackend.cpp)
add_library(WaveVortex::AccelerateMatrix ALIAS WaveVortexAccelerateMatrix)
target_compile_features(WaveVortexAccelerateMatrix PUBLIC cxx_std_17)
target_include_directories(WaveVortexAccelerateMatrix PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/adapters/accelerate>)
target_link_libraries(WaveVortexAccelerateMatrix PUBLIC WaveVortex::Kernel)
target_compile_definitions(WaveVortexAccelerateMatrix PRIVATE WV_HAVE_ACCELERATE=$<BOOL:${WV_ENABLE_ACCELERATE}>)
if(WV_ENABLE_ACCELERATE)
    target_link_libraries(WaveVortexAccelerateMatrix PRIVATE "-framework Accelerate")
endif()
set_target_properties(WaveVortexAccelerateMatrix PROPERTIES CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON)
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexAccelerateMatrix PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
