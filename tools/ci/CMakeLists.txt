cmake_minimum_required(VERSION 3.20)
project(WaveVortexCI LANGUAGES CXX)
include(CTest)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
# The contract project owns the core target; PortableRuntime reuses it.
add_subdirectory(../compiled-kernel kernel-contracts)
add_subdirectory(../../PortableRuntime portable-runtime)
