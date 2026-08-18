file(GLOB_RECURSE observer_sources
    "${WV_REPOSITORY_ROOT}/PortableRuntime/include/*.hpp"
    "${WV_REPOSITORY_ROOT}/PortableRuntime/src/*.cpp"
    "${WV_REPOSITORY_ROOT}/PortableRuntime/src/*.hpp")

set(observer_class_literals
    WVCoefficients
    WVEulerianFields
    WVMooring
    WVLagrangianParticles
    WVTracer)

foreach(source IN LISTS observer_sources)
    if(source MATCHES "/WVObserverAdapter\\.(cpp|hpp)$")
        continue()
    endif()
    file(READ "${source}" contents)
    foreach(class_name IN LISTS observer_class_literals)
        string(FIND "${contents}" "\"${class_name}\"" occurrence)
        if(NOT occurrence EQUAL -1)
            message(FATAL_ERROR
                "${source} duplicates built-in observer class literal ${class_name}; "
                "register it in WVObserverAdapter instead.")
        endif()
    endforeach()
endforeach()

set(retired_dispatch_symbols
    WVObserverKind
    WVObserverStateContract
    WVObserverOutputRule)

foreach(source IN LISTS observer_sources)
    file(READ "${source}" contents)
    foreach(symbol IN LISTS retired_dispatch_symbols)
        string(FIND "${contents}" "${symbol}" occurrence)
        if(NOT occurrence EQUAL -1)
            message(FATAL_ERROR
                "${source} retains retired closed observer dispatch symbol ${symbol}.")
        endif()
    endforeach()
endforeach()
