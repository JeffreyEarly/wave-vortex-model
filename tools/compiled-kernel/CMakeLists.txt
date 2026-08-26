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
