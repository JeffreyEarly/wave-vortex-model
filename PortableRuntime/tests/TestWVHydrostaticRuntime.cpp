#include "WaveVortexRuntime/WVHydrostaticForcingEngine.hpp"
#include "WaveVortexRuntime/WVHydrostaticIntegrationSystem.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"
#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WVReferenceFFTEngine.hpp"
#include "WVStratifiedModalTestFixture.hpp"
#include "../../tools/compiled-kernel/tests/WVAllocationProbe.hpp"
#include <iostream>
#include <limits>
#include <array>
#include <cmath>
using namespace wavevortex;
using namespace wavevortex::runtime;
using namespace wavevortex::test_fixture;
namespace {
int injectedFactoryCalls = 0;
WVKernelStatus countingScalarBackend(std::unique_ptr<WVVerticalMatrixBackend> &backend) {
    ++injectedFactoryCalls;
    return WVCreateScalarMatrixBackend(backend);
}

void injectedServices(std::shared_ptr<const WVStratifiedModalRecord> source,
                      std::shared_ptr<const WVExtensionCatalog> catalog,
                      const WVFrozenForcingSchedule &schedule) {
    WVVariableKernelServices services;
    services.matrixBackendFactory = countingScalarBackend;
    services.execution = {WVRetainedHorizontalSchedule::streamingPrunedTile16, 2,
                          true, WVVariableSpectralSchedule::compactSplitFusedViews};

    std::unique_ptr<WVHydrostaticForcingEngine> baseline, injected;
    require(bool(WVHydrostaticForcingEngine::create(
                    source, schedule, catalog,
                    std::make_unique<WVReferenceFFTEngine>(), baseline)),
            "Baseline Hydrostatic injection fixture failed");
    require(bool(WVHydrostaticForcingEngine::create(
                    source, schedule, catalog,
                    std::make_unique<WVReferenceFFTEngine>(), injected,
                    services)),
            "Injected Hydrostatic fixture failed");
    require(injectedFactoryCalls == 4, "Injected backend factory call count differs");
    require(injected->kernel().executionOptions().usesCompactSplitViews(),
            "Injected Hydrostatic execution options were not retained");
    const auto shape = baseline->kernel().spectralShape();
    const auto count = shape.elementCount();
    std::array<std::vector<WVComplex64>, 3> coefficients, referenceFlux, injectedFlux;
    for (auto &values : coefficients) values.resize(count, {.001, -.002});
    WVMutableCoefficients mutableCoefficients{{coefficients[0].data(), shape},
                                               {coefficients[1].data(), shape},
                                               {coefficients[2].data(), shape}};
    require(bool(baseline->kernel().constrainCoefficients(mutableCoefficients)),
            "Hydrostatic injection coefficient constraint failed");
    for (auto &values : referenceFlux) values.resize(count);
    for (auto &values : injectedFlux) values.resize(count);
    WVState state{.37, .11, {{coefficients[0].data(), shape},
                             {coefficients[1].data(), shape},
                             {coefficients[2].data(), shape}}};
    WVFlux reference{{referenceFlux[0].data(), shape}, {referenceFlux[1].data(), shape},
                     {referenceFlux[2].data(), shape}};
    WVFlux actual{{injectedFlux[0].data(), shape}, {injectedFlux[1].data(), shape},
                  {injectedFlux[2].data(), shape}};
    require(bool(baseline->nonlinearFlux(state, reference)), "Baseline Hydrostatic RHS failed");
    require(bool(injected->nonlinearFlux(state, actual)), "Injected Hydrostatic RHS failed");
    for (std::size_t family = 0; family < 3; ++family)
        for (std::size_t i = 0; i < count; ++i) {
            require(std::abs(referenceFlux[family][i].real - injectedFlux[family][i].real) < 1e-12,
                    "Injected Hydrostatic real RHS differs");
            require(std::abs(referenceFlux[family][i].imag - injectedFlux[family][i].imag) < 1e-12,
                    "Injected Hydrostatic imaginary RHS differs");
        }

    std::unique_ptr<WVHydrostaticIntegrationSystem> system;
    injectedFactoryCalls = 0;
    require(bool(WVHydrostaticIntegrationSystem::create(
                    source, schedule, catalog,
                    std::make_unique<WVReferenceFFTEngine>(), system, services)),
            "Injected Hydrostatic integration fixture failed");
    require(injectedFactoryCalls == 4 &&
                system->kernel().executionOptions().usesCompactSplitViews(),
            "Injected Hydrostatic integration services were not forwarded");
    WVPortableObserverRecord record;
    for (const auto &family : system->stateLayout().coefficientFamilies())
        record.stateBlocks.push_back({family.identifier, WVStateScalarType::complex64,
                                      family.spectralDimensions,
                                      WVToleranceKind::coefficientEnergyScaled, 1e-6,
                                      WVStateOwnership::integratorOwned,
                                      WVRestartRequirement::requiredDynamicState});
    WVPortableObserverDescriptor descriptor;
    require(bool(WVPortableObserverDescriptor::create(record, catalog, descriptor)),
            "Hydrostatic injection descriptor creation failed");
    injectedFactoryCalls = 0;
    require(bool(WVHydrostaticIntegrationSystem::create(
                    source, schedule, descriptor, catalog,
                    std::make_unique<WVReferenceFFTEngine>(), system, services)),
            "Injected Hydrostatic descriptor fixture failed");
    require(injectedFactoryCalls == 4 &&
                system->kernel().executionOptions().usesCompactSplitViews(),
            "Injected Hydrostatic descriptor services were not forwarded");
    WVVariableKernelServices rejected;
    rejected.matrixBackendFactory = {};
    auto *old = injected.get();
    require(!WVHydrostaticForcingEngine::create(
                source, schedule, catalog,
                std::make_unique<WVReferenceFFTEngine>(), injected, rejected) &&
                injected.get() == old,
            "Empty Hydrostatic backend factory replaced the existing engine");
}

void contracts(std::shared_ptr<const WVStratifiedModalRecord> source) {
    WVExtensionCatalogBuilder builder; require(bool(addBuiltInExtensions(builder)),"Built-ins failed");
    std::shared_ptr<const WVExtensionCatalog> catalog; require(bool(builder.freeze(catalog)),"Catalog failed");
    WVFrozenForcingSchedule schedule;
    const auto* registration=catalog->forcings().registration("WVNonlinearAdvection",1);
    WVFrozenForcingEntry entry; entry.typeIdentifier=registration->matlabClassName; entry.contractVersion=1; entry.name=registration->defaultName; entry.stage=registration->stage; entry.priority=registration->priority;
    entry.configuration={"wave-vortex-forcing-configuration-v1",1,{}}; schedule.entries.push_back(entry);
    std::unique_ptr<WVHydrostaticForcingEngine> engine;
    auto status=WVHydrostaticForcingEngine::create(source,schedule,catalog,std::make_unique<WVReferenceFFTEngine>(),engine); require(bool(status),status.message.c_str());
    const auto shape=engine->kernel().spectralShape(); const auto volume=engine->kernel().spatialShape();
    const auto S=shape.elementCount(),R=volume.elementCount();
    std::array<std::vector<WVComplex64>,3> a,b;
    for(auto& x:a) x.resize(S,{.001,.002});
    for(auto& x:b) x.resize(S,{17,19});
    WVMutableCoefficients amplitudes{{a[0].data(),shape},{a[1].data(),shape},{a[2].data(),shape}};
    require(bool(engine->kernel().constrainCoefficients(amplitudes)),"Constraint failed");
    WVState state{83,17,{{a[0].data(),shape},{a[1].data(),shape},{a[2].data(),shape}}}; WVFlux flux{{b[0].data(),shape},{b[1].data(),shape},{b[2].data(),shape}};
    auto invalidState=state; invalidState.t=std::numeric_limits<double>::quiet_NaN();
    require(!engine->nonlinearFlux(invalidState,flux),"Invalid time accepted");
    auto invalidFlux=flux; invalidFlux.F0.shape={S,1}; require(!engine->nonlinearFlux(state,invalidFlux),"Invalid shape accepted");
    invalidFlux=flux; invalidFlux.Fm=flux.Fp; require(!engine->nonlinearFlux(state,invalidFlux),"Aliased outputs accepted");
    for(const auto& x:b) for(auto value:x) require(value.real==17 && value.imag==19,"Invalid RHS mutated output");
    // Exact same-family in-place evolution is a core feature, but an RHS must
    // never overwrite the caller's state before applying forcing.
    invalidFlux=flux; invalidFlux.Fp=amplitudes.Ap;
    require(!engine->nonlinearFlux(state,invalidFlux),"RHS aliased caller state");
    std::vector<double> scalar(R,.3),out(R,29),velocities(3*R);
    for(std::size_t i=0;i<R;++i) scalar[i]+=.1*std::sin(.31*i);
    for(std::size_t i=0;i<3*R;++i) velocities[i]=.01*std::cos(.13*i);
    WVRealFieldBundleConstView fields{velocities.data(),{volume.first,volume.second,volume.third,3}};
    auto badFields=fields; badFields.shape.fourth=2;
    require(!engine->kernel().advectScalarWithAdvectionFields({scalar.data(),volume},badFields,false,{out.data(),volume}),"Invalid tracer field shape accepted");
    require(!engine->kernel().advectScalarWithAdvectionFields({scalar.data(),volume},fields,false,{scalar.data(),volume}),"Aliased tracer output accepted");
    for(auto value:out) require(value==29,"Invalid tracer operation mutated output");
    const auto bytes=engine->persistentBytes();
    allocationProbe::calls=0; allocationProbe::counting=true;
    for(int i=0;i<4;++i) {
        require(bool(engine->nonlinearFlux(state,flux)),"Prepared RHS failed");
        require(bool(engine->kernel().advectScalarWithAdvectionFields({scalar.data(),volume},fields,i%2,{out.data(),volume})),"Prepared tracer failed");
        WVRealFieldBundleConstView physical; require(bool(engine->physicalFields(state,physical)),"Physical fields failed");
    }
    allocationProbe::counting=false;
    require(allocationProbe::calls==0 && bytes==engine->persistentBytes(),"Prepared runtime allocated or changed storage");
    std::unique_ptr<WVIntegrationErrorPolicy> policy; require(bool(engine->createErrorPolicy(1e-10,policy)),"Error policy failed");
    require(policy->componentCount()==3 && policy->elementCount(0)==S,"Wrong adaptive families");
    for(std::size_t i=0;i<S;++i) for(std::size_t j=0;j<3;++j) require(policy->absoluteTolerance(j,i)>0 && std::isfinite(policy->absoluteTolerance(j,i)),"Invalid adaptive tolerance");
    const auto* old=engine.get();
    auto bad=schedule; bad.entries[0].typeIdentifier="unknown";
    require(!WVHydrostaticForcingEngine::create(source,bad,catalog,std::make_unique<WVReferenceFFTEngine>(),engine) && engine.get()==old,"Failed setup replaced engine");
    bool succeeded=false;
    for(long fail=0;fail<2048;++fail) {
        auto fft=std::make_unique<WVReferenceFFTEngine>(); allocationProbe::failAfter=fail;
        status=WVHydrostaticForcingEngine::create(source,schedule,catalog,std::move(fft),engine); allocationProbe::failAfter=-1;
        if(status) { succeeded=true; break; }
        require(engine.get()==old,"Failed allocation replaced engine");
    }
    require(succeeded,"Forcing allocation sweep never succeeded");
    std::unique_ptr<WVHydrostaticIntegrationSystem> system;
    status=WVHydrostaticIntegrationSystem::create(source,schedule,catalog,std::make_unique<WVReferenceFFTEngine>(),system); require(bool(status),status.message.c_str());
    require(system->stateLayout().coefficientFamilyCount()==3 && system->stateLayout().transformIdentifier()=="WVTransformHydrostatic","Wrong integration layout");
    injectedServices(source, catalog, schedule);
}
}
int main() {
    try {
        Temporary file; fixture(file.path);
        { File f(file.path); for(const auto* name:{"WVTransform","AnnotatedClass"}) nc(nc_put_att_text(f.id,NC_GLOBAL,name,std::char_traits<char>::length("WVTransformHydrostatic"),"WVTransformHydrostatic")); }
        std::shared_ptr<const WVStratifiedModalRecord> source; auto status=WVStratifiedModalReader::read(file.path.string(),source); require(bool(status),status.message.c_str());
        contracts(source); std::cout<<"Hydrostatic runtime contracts passed\n";
    } catch(const std::exception& e) { allocationProbe::failAfter=-1; allocationProbe::counting=false; std::cerr<<e.what()<<'\n'; return 1; }
}
