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

file(GLOB_RECURSE runtime_production_sources LIST_DIRECTORIES false
    "${WV_REPOSITORY_ROOT}/PortableRuntime/include/*.hpp"
    "${WV_REPOSITORY_ROOT}/PortableRuntime/src/*.cpp"
    "${WV_REPOSITORY_ROOT}/PortableRuntime/src/*.hpp"
    "${WV_REPOSITORY_ROOT}/PortableRuntime/app/*.cpp"
    "${WV_REPOSITORY_ROOT}/PortableRuntime/app/*.hpp")
foreach(source_path IN LISTS runtime_production_sources)
    file(READ "${source_path}" source)
    foreach(token
            WVObserverFactoryRegistry
            WVOutputScheduleFactoryRegistry
            WVForcingFactoryRegistry)
        string(FIND "${source}" "${token}" position)
        if(NOT position EQUAL -1)
            message(FATAL_ERROR
                "Portable runtime restored retired process-global registry ${token}: ${source_path}")
        endif()
    endforeach()
    if(source MATCHES "seal[A-Za-z_]*(Factory)?Registration|sealRegistration")
        message(FATAL_ERROR
            "Portable runtime restored a registration-seal API: ${source_path}")
    endif()
    if(source MATCHES
       "static[ \t\r\n]+std::(map|unordered_map|mutex)[ \t\r\n]*[<A-Za-z_]")
        message(FATAL_ERROR
            "Portable runtime contains process-global mutable registry storage: ${source_path}")
    endif()
endforeach()

file(READ "${WV_REPOSITORY_ROOT}/PortableRuntime/app/WaveVortexRun.cpp" runner)
foreach(token "netcdf.h" "nc_open(" "nc_create(" "nc_def_")
    string(FIND "${runner}" "${token}" position)
    if(NOT position EQUAL -1)
        message(FATAL_ERROR "The standalone CLI bypasses the persistence API with '${token}'.")
    endif()
endforeach()
string(FIND "${runner}" "WVConstantStratificationIntegrationSystem::create" direct_system_create)
if(NOT direct_system_create EQUAL -1)
    message(FATAL_ERROR "The standalone CLI bypasses the WVModel façade.")
endif()

file(READ "${WV_REPOSITORY_ROOT}/CompiledKernel/adapters/native-fftw/wv_compiled_backend_mex.cpp" mex_gateway)
string(FIND "${mex_gateway}" "std::unique_ptr<WVModel>" model_owner)
string(FIND "${mex_gateway}" "std::unique_ptr<WVTransformConstantStratificationKernel>" kernel_owner)
if(model_owner EQUAL -1 OR NOT kernel_owner EQUAL -1)
    message(FATAL_ERROR "The production MEX handle must own WVModel rather than a raw kernel.")
endif()

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

set(catalog_header
    "${WV_REPOSITORY_ROOT}/PortableRuntime/include/WaveVortexRuntime/generated/WVPortableVariableCatalog.hpp")
if(NOT EXISTS "${catalog_header}")
    message(FATAL_ERROR "The generated portable variable catalog is missing.")
endif()

file(READ "${WV_REPOSITORY_ROOT}/PortableRuntime/src/WVFieldEvaluationService.cpp" field_service)
foreach(token "constexpr const char *fieldNames" "request.fieldName ==" "request.fieldName !=")
    string(FIND "${field_service}" "${token}" position)
    if(NOT position EQUAL -1)
        message(FATAL_ERROR "Field evaluation restored runtime name dispatch or duplicate metadata: ${token}")
    endif()
endforeach()

file(READ "${WV_REPOSITORY_ROOT}/PortableRuntime/src/WVObserverOutputEvaluationService.cpp" output_service)
foreach(token "struct FieldMetadata" "linearInitialOnly(const std::string")
    string(FIND "${output_service}" "${token}" position)
    if(NOT position EQUAL -1)
        message(FATAL_ERROR "Observer output restored duplicate variable metadata: ${token}")
    endif()
endforeach()

message(STATUS "Portable runtime architecture policy passed.")
