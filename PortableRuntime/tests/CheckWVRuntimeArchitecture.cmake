cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED WV_REPOSITORY_ROOT)
    message(FATAL_ERROR "WV_REPOSITORY_ROOT is required.")
endif()

file(GLOB_RECURSE kernel_sources LIST_DIRECTORIES false
    "${WV_REPOSITORY_ROOT}/CompiledKernel/include/WaveVortexKernel/*.hpp"
    "${WV_REPOSITORY_ROOT}/CompiledKernel/src/*.cpp")
set(kernel_forbidden "mex.h" "matrix.h" "matlabdataarray" "netcdf.h"
    "fftw3.h" "accelerate/accelerate.h" "dispatch/dispatch.h")
foreach(source_path IN LISTS kernel_sources)
    file(READ "${source_path}" source)
    string(TOLOWER "${source}" source_lower)
    foreach(token IN LISTS kernel_forbidden)
        string(FIND "${source_lower}" "${token}" position)
        if(NOT position EQUAL -1)
            message(FATAL_ERROR "CompiledKernel source has forbidden dependency '${token}': ${source_path}")
        endif()
    endforeach()
endforeach()

file(READ "${WV_REPOSITORY_ROOT}/PortableRuntime/CMakeLists.txt" runtime_cmake)
string(FIND "${runtime_cmake}" "WaveVortex::Checkpoint" checkpoint_alias)
if(NOT checkpoint_alias EQUAL -1)
    message(FATAL_ERROR "The obsolete WaveVortex::Checkpoint alias was restored.")
endif()

file(READ "${WV_REPOSITORY_ROOT}/PortableRuntime/app/WaveVortexRun.cpp" runner)
foreach(token "netcdf.h" "nc_open(" "nc_create(" "nc_def_")
    string(FIND "${runner}" "${token}" position)
    if(NOT position EQUAL -1)
        message(FATAL_ERROR "The standalone CLI bypasses the persistence API with '${token}'.")
    endif()
endforeach()

set(numerical_sources
    "PortableRuntime/src/WVRungeKutta.cpp"
    "PortableRuntime/src/WVIntegrationState.cpp"
    "PortableRuntime/src/WVForcingEngine.cpp"
    "PortableRuntime/src/WVFieldEvaluationService.cpp")
foreach(relative_path IN LISTS numerical_sources)
    file(READ "${WV_REPOSITORY_ROOT}/${relative_path}" source)
    foreach(token "netcdf.h" "WVCheckpointWriter" "WVModelOutputNetCDF")
        string(FIND "${source}" "${token}" position)
        if(NOT position EQUAL -1)
            message(FATAL_ERROR "Portable numerical source owns persistence behavior: ${relative_path}")
        endif()
    endforeach()
endforeach()

message(STATUS "Portable runtime architecture policy passed.")
