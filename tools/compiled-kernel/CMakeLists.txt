cmake_minimum_required(VERSION 3.20)
project(WaveVortexKernelContractTests LANGUAGES CXX)

include(CTest)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../../CompiledKernel ${CMAKE_CURRENT_BINARY_DIR}/kernel)

add_executable(TestWVKernelContract tests/TestWVKernelContract.cpp tests/WVReferenceFFTEngine.cpp)
target_link_libraries(TestWVKernelContract PRIVATE WaveVortex::Kernel)
target_include_directories(TestWVKernelContract PRIVATE ${CMAKE_CURRENT_LIST_DIR}/../../CompiledKernel/src)
target_compile_features(TestWVKernelContract PRIVATE cxx_std_17)
set_target_properties(TestWVKernelContract PROPERTIES CXX_EXTENSIONS OFF)
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(TestWVKernelContract PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME WVKernelContract COMMAND TestWVKernelContract)

add_executable(TestWVBarotropicQGKernel
    tests/TestWVBarotropicQGKernel.cpp
    tests/WVReferenceFFTEngine.cpp)
target_link_libraries(TestWVBarotropicQGKernel PRIVATE WaveVortex::Kernel)
target_include_directories(TestWVBarotropicQGKernel PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/../../CompiledKernel/src)
target_compile_features(TestWVBarotropicQGKernel PRIVATE cxx_std_17)
set_target_properties(TestWVBarotropicQGKernel PROPERTIES CXX_EXTENSIONS OFF)
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(TestWVBarotropicQGKernel PRIVATE
        -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME WVBarotropicQGKernel COMMAND TestWVBarotropicQGKernel)

add_executable(WVBarotropicQGFixtureDump
    WVBarotropicQGFixtureDump.cpp
    tests/WVReferenceFFTEngine.cpp)
target_link_libraries(WVBarotropicQGFixtureDump PRIVATE WaveVortex::Kernel)
target_include_directories(WVBarotropicQGFixtureDump PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/../../CompiledKernel/src
    ${CMAKE_CURRENT_LIST_DIR}/tests)
target_compile_features(WVBarotropicQGFixtureDump PRIVATE cxx_std_17)
set_target_properties(WVBarotropicQGFixtureDump PROPERTIES CXX_EXTENSIONS OFF)
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WVBarotropicQGFixtureDump PRIVATE
        -Wall -Wextra -Wpedantic -Werror)
endif()

add_executable(WVKernelDescriptorDump WVKernelDescriptorDump.cpp)
target_link_libraries(WVKernelDescriptorDump PRIVATE WaveVortex::Kernel)
target_compile_features(WVKernelDescriptorDump PRIVATE cxx_std_17)
set_target_properties(WVKernelDescriptorDump PROPERTIES CXX_EXTENSIONS OFF)
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WVKernelDescriptorDump PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

add_executable(TestWVPreparedModeExecutor tests/TestWVPreparedModeExecutor.cpp tests/WVAllocationProbe.cpp)
target_link_libraries(TestWVPreparedModeExecutor PRIVATE WaveVortex::Kernel)
target_include_directories(TestWVPreparedModeExecutor PRIVATE ../../CompiledKernel/src)
target_compile_features(TestWVPreparedModeExecutor PRIVATE cxx_std_17)
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(TestWVPreparedModeExecutor PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME WVPreparedModeExecutor COMMAND TestWVPreparedModeExecutor)

add_executable(TestWVAllocationProbe tests/TestWVAllocationProbe.cpp tests/WVAllocationProbe.cpp)
target_compile_features(TestWVAllocationProbe PRIVATE cxx_std_17)
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(TestWVAllocationProbe PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME WVAllocationProbe COMMAND TestWVAllocationProbe)

set(WV_KERNEL_FFTW_ROOT "" CACHE PATH "Optional native FFTW prefix for ownership and prepared execution tests")
if(WV_KERNEL_FFTW_ROOT)
    find_path(WV_TEST_FFTW_INCLUDE fftw3.h PATHS ${WV_KERNEL_FFTW_ROOT}/include NO_DEFAULT_PATH REQUIRED)
    find_library(WV_TEST_FFTW_BASE NAMES fftw3 PATHS ${WV_KERNEL_FFTW_ROOT}/lib NO_DEFAULT_PATH REQUIRED)
    find_library(WV_TEST_FFTW_THREADS NAMES fftw3_threads PATHS ${WV_KERNEL_FFTW_ROOT}/lib NO_DEFAULT_PATH REQUIRED)
    add_library(WVTestFFTWFailureAdapter OBJECT ../../CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp)
    target_link_libraries(WVTestFFTWFailureAdapter PRIVATE WaveVortex::Kernel)
    target_include_directories(WVTestFFTWFailureAdapter PRIVATE ${WV_TEST_FFTW_INCLUDE})
    add_executable(TestWVNativeFFTWOwnership tests/TestWVNativeFFTWOwnership.cpp tests/WVAllocationProbe.cpp
        $<TARGET_OBJECTS:WVTestFFTWFailureAdapter>)
    target_compile_features(TestWVNativeFFTWOwnership PRIVATE cxx_std_17)
    target_include_directories(TestWVNativeFFTWOwnership PRIVATE
        ../../CompiledKernel/adapters/native-fftw ${WV_TEST_FFTW_INCLUDE})
    target_link_libraries(TestWVNativeFFTWOwnership PRIVATE WaveVortex::Kernel WaveVortex::ReferenceFFT
        ${WV_TEST_FFTW_THREADS} ${WV_TEST_FFTW_BASE} ${CMAKE_DL_LIBS})
    # Rename only the adapter's FFTW calls; the test forwards to the real library
    # and can fail individual acquisition stages without production test hooks.
    target_compile_definitions(WVTestFFTWFailureAdapter PRIVATE
        fftw_malloc=wv_test_malloc fftw_free=wv_test_free fftw_plan_guru64_dft_r2c=wv_test_r2c
        fftw_plan_guru64_dft_c2r=wv_test_c2r fftw_plan_guru64_r2r=wv_test_r2r fftw_destroy_plan=wv_test_destroy)
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(TestWVNativeFFTWOwnership PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    set_target_properties(TestWVNativeFFTWOwnership PROPERTIES BUILD_RPATH "${WV_KERNEL_FFTW_ROOT}/lib")
    add_test(NAME WVNativeFFTWOwnership COMMAND TestWVNativeFFTWOwnership)
endif()

add_executable(TestWVSpectralOperators tests/TestWVSpectralOperators.cpp tests/WVAllocationProbe.cpp)
target_link_libraries(TestWVSpectralOperators PRIVATE WaveVortex::ReferenceFFT WaveVortex::AccelerateMatrix)
target_compile_features(TestWVSpectralOperators PRIVATE cxx_std_17)
if(WV_KERNEL_FFTW_ROOT)
    target_sources(TestWVSpectralOperators PRIVATE ../../CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp)
    target_include_directories(TestWVSpectralOperators PRIVATE ../../CompiledKernel/adapters/native-fftw ${WV_TEST_FFTW_INCLUDE})
    target_link_libraries(TestWVSpectralOperators PRIVATE ${WV_TEST_FFTW_THREADS} ${WV_TEST_FFTW_BASE} ${CMAKE_DL_LIBS})
    target_compile_definitions(TestWVSpectralOperators PRIVATE WV_TEST_NATIVE_FFTW=1)
    set_target_properties(TestWVSpectralOperators PROPERTIES BUILD_RPATH "${WV_KERNEL_FFTW_ROOT}/lib")
else()
    target_compile_definitions(TestWVSpectralOperators PRIVATE WV_TEST_NATIVE_FFTW=0)
endif()
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(TestWVSpectralOperators PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()
add_test(NAME WVSpectralOperators COMMAND TestWVSpectralOperators)
