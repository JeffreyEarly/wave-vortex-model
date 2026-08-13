cmake_minimum_required(VERSION 3.20)
project(WaveVortexPortableRuntime VERSION 0.1.0 LANGUAGES CXX)

include(CTest)
option(WV_RUNTIME_ENABLE_NATIVE_FFTW "Build wave-vortex-run with the pinned native FFTW adapter" OFF)
set(WV_RUNTIME_FFTW_ROOT "" CACHE PATH "Prefix containing the validated FFTW 3.3.11 include and lib folders")

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
    src/WVCheckpointWriter.cpp
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

add_executable(wave-vortex-run app/WaveVortexRun.cpp)
target_compile_features(wave-vortex-run PRIVATE cxx_std_17)
target_link_libraries(wave-vortex-run PRIVATE WaveVortex::PortableRuntime WaveVortex::ReferenceFFT)
execute_process(COMMAND git rev-parse HEAD WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/.. OUTPUT_VARIABLE WV_RUNTIME_SOURCE_COMMIT OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
if(NOT WV_RUNTIME_SOURCE_COMMIT)
    set(WV_RUNTIME_SOURCE_COMMIT "unknown")
endif()
target_compile_definitions(wave-vortex-run PRIVATE WV_RUNTIME_SOURCE_COMMIT="${WV_RUNTIME_SOURCE_COMMIT}")

if(WV_RUNTIME_ENABLE_NATIVE_FFTW)
    if(NOT APPLE OR NOT CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
        message(FATAL_ERROR "The optimized native FFTW runtime provider currently supports Apple silicon only.")
    endif()
    find_path(WV_RUNTIME_FFTW_INCLUDE fftw3.h PATHS ${WV_RUNTIME_FFTW_ROOT}/include NO_DEFAULT_PATH REQUIRED)
    find_library(WV_RUNTIME_FFTW_BASE NAMES fftw3 libfftw3.3 PATHS ${WV_RUNTIME_FFTW_ROOT}/lib NO_DEFAULT_PATH REQUIRED)
    find_library(WV_RUNTIME_FFTW_THREADS NAMES fftw3_threads libfftw3_threads.3 PATHS ${WV_RUNTIME_FFTW_ROOT}/lib NO_DEFAULT_PATH REQUIRED)
    add_library(WaveVortexNativeFFTW STATIC ../CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp)
    target_compile_features(WaveVortexNativeFFTW PUBLIC cxx_std_17)
    target_include_directories(WaveVortexNativeFFTW PUBLIC ../CompiledKernel/adapters/native-fftw ${WV_RUNTIME_FFTW_INCLUDE})
    target_link_libraries(WaveVortexNativeFFTW PUBLIC WaveVortex::Kernel ${WV_RUNTIME_FFTW_THREADS} ${WV_RUNTIME_FFTW_BASE} ${CMAKE_DL_LIBS})
    set_target_properties(WaveVortexNativeFFTW PROPERTIES CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON)
    target_link_libraries(wave-vortex-run PRIVATE WaveVortexNativeFFTW)
    target_compile_definitions(wave-vortex-run PRIVATE WV_RUNTIME_HAS_NATIVE_FFTW=1 WV_RUNTIME_EXPECTED_FFTW_ROOT="${WV_RUNTIME_FFTW_ROOT}")
    set_target_properties(wave-vortex-run PROPERTIES BUILD_RPATH "${WV_RUNTIME_FFTW_ROOT}/lib")
else()
    target_compile_definitions(wave-vortex-run PRIVATE WV_RUNTIME_HAS_NATIVE_FFTW=0 WV_RUNTIME_EXPECTED_FFTW_ROOT="")
endif()

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(WaveVortexPortableRuntime PRIVATE -Wall -Wextra -Wpedantic -Werror)
    target_compile_options(wave-vortex-run PRIVATE -Wall -Wextra -Wpedantic -Werror)
    if(TARGET WaveVortexNativeFFTW)
        target_compile_options(WaveVortexNativeFFTW PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
endif()

if(BUILD_TESTING)
    add_executable(wv_checkpoint_inspect
        ../tools/portable-runtime/WVCheckpointInspect.cpp
    )
    target_compile_features(wv_checkpoint_inspect PRIVATE cxx_std_17)
    target_link_libraries(wv_checkpoint_inspect PRIVATE WaveVortex::Checkpoint)

    add_executable(wv_checkpoint_roundtrip
        ../tools/portable-runtime/WVCheckpointRoundTrip.cpp
    )
    target_compile_features(wv_checkpoint_roundtrip PRIVATE cxx_std_17)
    target_link_libraries(wv_checkpoint_roundtrip PRIVATE WaveVortex::Checkpoint)

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

    add_executable(TestWVCheckpointWriter
        ../tools/portable-runtime/tests/TestWVCheckpointWriter.cpp
        ../tools/compiled-kernel/tests/WVReferenceFFTEngine.cpp
    )
    target_compile_features(TestWVCheckpointWriter PRIVATE cxx_std_17)
    target_include_directories(TestWVCheckpointWriter PRIVATE src ../tools/compiled-kernel/tests)
    target_link_libraries(TestWVCheckpointWriter PRIVATE WaveVortex::Checkpoint ${WAVEVORTEX_NETCDF_TARGET})
    target_compile_definitions(TestWVCheckpointWriter PRIVATE
        WV_CHECKPOINT_FIXTURE_DIR="${CMAKE_CURRENT_LIST_DIR}/../tools/portable-runtime/fixtures"
    )
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(TestWVCheckpointWriter PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    add_test(NAME checkpoint-writer COMMAND TestWVCheckpointWriter)

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

    add_executable(TestWVIntegrationContracts
        ../tools/portable-runtime/tests/TestWVIntegrationContracts.cpp
    )
    target_compile_features(TestWVIntegrationContracts PRIVATE cxx_std_17)
    target_link_libraries(TestWVIntegrationContracts PRIVATE WaveVortex::PortableRuntime)
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(TestWVIntegrationContracts PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    add_test(NAME integration-contracts COMMAND TestWVIntegrationContracts)

    add_executable(TestWaveVortexRun ../tools/portable-runtime/tests/TestWaveVortexRun.cpp)
    target_compile_features(TestWaveVortexRun PRIVATE cxx_std_17)
    target_link_libraries(TestWaveVortexRun PRIVATE WaveVortex::Checkpoint)
    target_compile_definitions(TestWaveVortexRun PRIVATE WV_RUNTIME_RUNNER="$<TARGET_FILE:wave-vortex-run>" WV_RUNTIME_FIXTURE_DIR="${CMAKE_CURRENT_LIST_DIR}/../tools/portable-runtime/fixtures")
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(TestWaveVortexRun PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    add_dependencies(TestWaveVortexRun wave-vortex-run)
    add_test(NAME standalone-runner COMMAND TestWaveVortexRun)
endif()
