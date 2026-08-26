cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED WV_REPOSITORY_ROOT)
    message(FATAL_ERROR "WV_REPOSITORY_ROOT is required.")
endif()

set(generic_sources
    "PortableRuntime/src/WVRungeKutta.cpp"
    "PortableRuntime/include/WaveVortexRuntime/WVRungeKutta.hpp"
    "PortableRuntime/include/WaveVortexRuntime/WVIntegrationContracts.hpp")
foreach(relative_path IN LISTS generic_sources)
    file(READ "${WV_REPOSITORY_ROOT}/${relative_path}" source)
    foreach(token
            "WVTransformBarotropicQG"
            "WVBarotropicQGIntegrationSystem"
            "coefficients.Ap"
            "coefficients.Am"
            "coefficients.A0")
        string(FIND "${source}" "${token}" position)
        if(NOT position EQUAL -1)
            message(FATAL_ERROR
                "Generic integrator contract contains transform dispatch or legacy coefficient access '${token}': ${relative_path}")
        endif()
    endforeach()
endforeach()

file(READ
    "${WV_REPOSITORY_ROOT}/PortableRuntime/src/WVBarotropicQGIntegrationSystem.cpp"
    system_source)
foreach(required "coefficientFamilyView" "kernel_->nonlinearFlux")
    string(FIND "${system_source}" "${required}" position)
    if(position EQUAL -1)
        message(FATAL_ERROR
            "Barotropic QG system does not remain behind the resolved coefficient-family boundary: ${required}")
    endif()
endforeach()

message(STATUS "Barotropic QG architecture policy passed.")
