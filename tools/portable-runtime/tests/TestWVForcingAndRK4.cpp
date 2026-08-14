#include "WaveVortexRuntime/WVFixedStepRK4.hpp"
#include "WaveVortexRuntime/WVForcingEngine.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

struct FailureCounter {
    std::size_t executionCount = 0;
    std::size_t failAt = 0;
};

class FailingPlan final : public WVFFTPlan {
public:
    FailingPlan(std::unique_ptr<WVFFTPlan> plan, std::shared_ptr<FailureCounter> counter) : plan_(std::move(plan)), counter_(std::move(counter)) {}
    WVKernelStatus execute(const void* input, void* output) override {
        ++counter_->executionCount;
        if (counter_->executionCount == counter_->failAt) return {WVKernelStatusCode::fftExecutionFailure,"injected portable RK4 execution failure"};
        return plan_->execute(input,output);
    }
    std::size_t persistentBytes() const noexcept override { return plan_->persistentBytes()+sizeof(*this); }
private:
    std::unique_ptr<WVFFTPlan> plan_;
    std::shared_ptr<FailureCounter> counter_;
};

class FailingEngine final : public WVFFTEngine {
public:
    explicit FailingEngine(std::shared_ptr<FailureCounter> counter) : counter_(std::move(counter)) {}
    std::string identifier() const override { return "reference-direct-injected-failure"; }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) override {
        std::unique_ptr<WVFFTPlan> inner;
        auto status = reference_.createPlan(specification,inner);
        if (status) plan = std::make_unique<FailingPlan>(std::move(inner),counter_);
        return status;
    }
private:
    wavevortex::test::WVReferenceFFTEngine reference_;
    std::shared_ptr<FailureCounter> counter_;
};

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

WVTransformConstantStratificationConfiguration configuration(bool hydrostatic) {
    WVTransformConstantStratificationConfiguration value;
    value.Nx = 6; value.Ny = 5; value.Nz = 7; value.Nj = 4;
    value.Lx = 15000.0; value.Ly = 12000.0; value.Lz = 1300.0;
    value.N0 = 5.2e-3; value.rho0 = 1027.0; value.g = 9.80665;
    value.planetaryRadius = 6.3712e6; value.rotationRate = 7.292115e-5; value.latitude = 33.0;
    value.isHydrostatic = hydrostatic; value.shouldAntialias = true;
    return value;
}

WVFrozenForcingEntry entry(WVForcingKind kind, const char* identifier, const char* name, WVForcingStage stage, std::uint8_t priority, WVForcingPayload payload) {
    return {kind,identifier,name,stage,priority,0,"test",std::move(payload)};
}

WVFrozenForcingSchedule nonlinearSchedule() {
    WVFrozenForcingSchedule schedule;
    schedule.entries.push_back(entry(WVForcingKind::nonlinearAdvection,"WVNonlinearAdvection","nonlinear",WVForcingStage::spatial,127,WVNonlinearAdvectionRecord{}));
    return schedule;
}

std::unique_ptr<WVConstantStratificationForcingEngine> createEngine(bool hydrostatic, const WVFrozenForcingSchedule& schedule) {
    std::unique_ptr<WVConstantStratificationForcingEngine> engine;
    const auto status = WVConstantStratificationForcingEngine::create(configuration(hydrostatic),schedule,std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),engine);
    require(static_cast<bool>(status),status.message);
    return engine;
}

struct OwnedState {
    WVShape2D shape;
    std::vector<WVComplex64> values;
    double t = 0.5;
    double t0 = -0.25;

    explicit OwnedState(WVShape2D valueShape) : shape(valueShape), values(3*shape.elementCount()) {
        const auto count = shape.elementCount();
        for (std::size_t index = 0; index < count; ++index) {
            values[index] = {1e-5*std::sin(0.17*static_cast<double>(index+1)),1e-5*std::cos(0.13*static_cast<double>(index+2))};
            values[count+index] = {1e-5*std::cos(0.11*static_cast<double>(index+3)),1e-5*std::sin(0.07*static_cast<double>(index+4))};
            values[2*count+index] = {1e-5*std::sin(0.19*static_cast<double>(index+5)),1e-5*std::cos(0.05*static_cast<double>(index+6))};
        }
    }

    WVMutableState mutableView() {
        const auto count = shape.elementCount();
        return {t,t0,{{values.data(),shape},{values.data()+count,shape},{values.data()+2*count,shape}}};
    }
    WVState view() const {
        const auto count = shape.elementCount();
        return {t,t0,{{values.data(),shape},{values.data()+count,shape},{values.data()+2*count,shape}}};
    }
};

WVFlux fluxView(std::vector<WVComplex64>& values, WVShape2D shape) {
    const auto count = shape.elementCount();
    return {{values.data(),shape},{values.data()+count,shape},{values.data()+2*count,shape}};
}

void requireFinite(const std::vector<WVComplex64>& values, const std::string& message) {
    for (const auto value : values) require(std::isfinite(value.real) && std::isfinite(value.imag),message);
}

bool exactlyEqual(const std::vector<WVComplex64>& first, const std::vector<WVComplex64>& second) {
    if (first.size() != second.size()) return false;
    for (std::size_t index = 0; index < first.size(); ++index) {
        if (first[index].real != second[index].real || first[index].imag != second[index].imag) return false;
    }
    return true;
}

void testNonlinearCompatibility(bool hydrostatic) {
    auto scheduled = createEngine(hydrostatic,nonlinearSchedule());
    std::unique_ptr<WVTransformConstantStratificationKernel> direct;
    auto status = WVTransformConstantStratificationKernel::create(configuration(hydrostatic),std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),direct);
    require(static_cast<bool>(status),"direct kernel construction failed");
    OwnedState state(direct->descriptor().spectralShape());
    const auto count = state.shape.elementCount();
    const WVComplex64 canary{std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::quiet_NaN()};
    std::vector<WVComplex64> scheduledValues(3*count,canary),directValues(3*count,canary);
    auto scheduledFlux = fluxView(scheduledValues,state.shape);
    auto directFlux = fluxView(directValues,state.shape);
    status = scheduled->nonlinearFlux(state.view(),scheduledFlux);
    require(static_cast<bool>(status),"scheduled nonlinear flux failed");
    requireFinite(scheduledValues,"integration-system RHS did not completely overwrite canary output storage");
    status = direct->nonlinearFlux(state.view(),directFlux);
    require(static_cast<bool>(status),"direct nonlinear flux failed");
    double error = 0.0;
    for (std::size_t index = 0; index < scheduledValues.size(); ++index) {
        error = std::max(error,std::abs(scheduledValues[index].real-directValues[index].real));
        error = std::max(error,std::abs(scheduledValues[index].imag-directValues[index].imag));
    }
    require(error <= 1e-13,"nonlinear-only schedule changed the shared kernel result");
}

void testForcingTrafficAccounting() {
    auto engine = createEngine(true,nonlinearSchedule());
    OwnedState owned(engine->kernel().descriptor().spectralShape());
    auto state = owned.mutableView();
    WVFixedStepRK4 integrator(*engine);
    auto status = integrator.prepareStateAfterRestart(state);
    require(static_cast<bool>(status),"traffic-accounting restart preparation failed");
    status = integrator.step(state,0.1);
    require(static_cast<bool>(status),"traffic-accounting step failed");
    const auto& metrics = engine->metrics();
    require(metrics.accumulatorClearElementWrites == 0,"nonlinear-only forcing still clears an accumulator");
    require(metrics.temporaryFluxClearElementWrites == 0 && metrics.kernelOutputInitializationElementWrites == 0,"nonlinear-only forcing still initializes an intermediate output");
    require(metrics.temporaryAccumulationElementReads == 0 && metrics.temporaryAccumulationElementWrites == 0,"nonlinear-only forcing still accumulates through temporary storage");
    require(metrics.outputCopyElementReads == 0 && metrics.outputCopyElementWrites == 0,"nonlinear-only forcing still copies its completed output");
    require(metrics.workspaceCapacityBytes == 0,"nonlinear-only forcing retained array-sized workspace");
    require(metrics.workspaceLiveBytes == 0 && metrics.workspaceMaximumLiveBytes == 0,"nonlinear-only forcing-workspace liveness is not zero");
}

void testFixedAmplitudeAndRK4() {
    WVFixedAmplitudeForcingRecord fixed;
    fixed.ApIndices = {0}; fixed.ApValues = {{0.125,-0.25}};
    fixed.AmIndices = {1}; fixed.AmValues = {{-0.75,0.5}};
    fixed.A0Indices = {2}; fixed.A0Values = {{0.375,0.625}};
    WVFrozenForcingSchedule schedule;
    schedule.entries.push_back(entry(WVForcingKind::fixedAmplitude,"WVFixedAmplitudeForcing","fixed",WVForcingStage::spectralAmplitude,255,fixed));
    auto engine = createEngine(true,schedule);
    OwnedState owned(engine->kernel().descriptor().spectralShape());
    auto state = owned.mutableView();
    WVFixedStepRK4 integrator(*engine);
    auto status = integrator.prepareStateAfterRestart(state);
    require(static_cast<bool>(status),"restart amplitude restoration failed");
    require(state.coefficients.Ap.data[0].real == 0.125 && state.coefficients.Ap.data[0].imag == -0.25,"Ap fixed amplitude was not restored");
    require(state.coefficients.Am.data[1].real == -0.75 && state.coefficients.A0.data[2].imag == 0.625,"fixed amplitudes were not restored");
    status = integrator.advanceToTime(state,0.725,0.1);
    require(static_cast<bool>(status),"fixed-amplitude RK4 integration failed");
    require(state.t == 0.725 && integrator.metrics().stepCount == 3 && integrator.metrics().lastStepSize > 0.024999999999 && integrator.metrics().lastStepSize < 0.025000000001,"partial final RK4 step was not deterministic");
    require(state.coefficients.Ap.data[0].real == 0.125 && state.coefficients.Am.data[1].real == -0.75 && state.coefficients.A0.data[2].imag == 0.625,"RK4 did not preserve fixed amplitudes");
    const auto expectedBytes = 9*state.coefficients.Ap.shape.elementCount()*sizeof(WVComplex64);
    require(integrator.metrics().workspaceCapacityBytes == expectedBytes,"RK4 workspace is not the bounded 9M complex schedule");
}

void testRK4DeterminismRestartAndFailure() {
    auto firstEngine = createEngine(false,nonlinearSchedule());
    auto secondEngine = createEngine(false,nonlinearSchedule());
    OwnedState first(firstEngine->kernel().descriptor().spectralShape());
    OwnedState second(secondEngine->kernel().descriptor().spectralShape());
    auto firstState = first.mutableView();
    auto secondState = second.mutableView();
    WVFixedStepRK4 firstIntegrator(*firstEngine);
    WVFixedStepRK4 secondIntegrator(*secondEngine);
    auto status = firstIntegrator.advanceToTime(firstState,0.7,0.1);
    require(static_cast<bool>(status),"first deterministic integration failed");
    status = secondIntegrator.advanceToTime(secondState,0.6,0.1);
    require(static_cast<bool>(status),"restart prefix integration failed");
    WVFixedStepRK4 restartedIntegrator(*secondEngine);
    status = restartedIntegrator.prepareStateAfterRestart(secondState);
    require(static_cast<bool>(status),"restart preparation failed");
    status = restartedIntegrator.advanceToTime(secondState,0.7,0.1);
    require(static_cast<bool>(status),"restart continuation failed");
    require(firstState.t == secondState.t && exactlyEqual(first.values,second.values),"restart continuation is not bitwise equivalent to uninterrupted fixed-step RK4");

    auto counter = std::make_shared<FailureCounter>();
    counter->failAt = 1;
    std::unique_ptr<WVConstantStratificationForcingEngine> failingEngine;
    status = WVConstantStratificationForcingEngine::create(configuration(true),nonlinearSchedule(),std::make_unique<FailingEngine>(counter),failingEngine);
    require(static_cast<bool>(status),"failing engine construction failed");
    OwnedState failed(failingEngine->kernel().descriptor().spectralShape());
    const auto originalValues = failed.values;
    const auto originalTime = failed.t;
    auto failedState = failed.mutableView();
    WVFixedStepRK4 failingIntegrator(*failingEngine);
    status = failingIntegrator.step(failedState,0.1);
    require(status.code == WVKernelStatusCode::fftExecutionFailure,"RK4 did not preserve the injected RHS failure");
    require(exactlyEqual(failed.values,originalValues) && failedState.t == originalTime,"failed RK4 step modified the caller-owned state");
}

void testSpectralForcing() {
    WVFrozenForcingSchedule schedule;
    schedule.entries.push_back(entry(WVForcingKind::adaptiveDamping,"WVAdaptiveDamping","adaptive",WVForcingStage::spectral,100,WVAdaptiveDampingRecord{}));
    schedule.entries.push_back(entry(WVForcingKind::betaPlanePVAdvection,"WVBetaPlanePVAdvection","beta",WVForcingStage::spectral,110,WVBetaPlanePVAdvectionRecord{}));
    auto engine = createEngine(false,schedule);
    OwnedState state(engine->kernel().descriptor().spectralShape());
    const WVComplex64 canary{std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::quiet_NaN()};
    std::vector<WVComplex64> values(3*state.shape.elementCount(),canary);
    auto flux = fluxView(values,state.shape);
    const auto status = engine->nonlinearFlux(state.view(),flux);
    require(static_cast<bool>(status),"adaptive/beta forcing failed");
    requireFinite(values,"adaptive/beta forcing produced non-finite output");
    require(engine->metrics().resolvedSpectralCount == 2,"spectral forcing dispatch was not resolved at construction");
    const auto expectedWorkspace = 4*configuration(false).Nx*configuration(false).Ny*configuration(false).Nz*sizeof(double);
    require(engine->metrics().workspaceCapacityBytes == expectedWorkspace,"spectral forcing did not allocate only its required physical-field workspace");
}

void testQuadraticAndPseudo(bool hydrostatic) {
    WVPseudoTopographicWaveGenerationRecord pseudo;
    pseudo.topographicShape = {6,5};
    pseudo.topographicHeight.resize(30);
    for (std::size_t index = 0; index < pseudo.topographicHeight.size(); ++index) pseudo.topographicHeight[index] = 10.0*std::sin(0.2*static_cast<double>(index+1));
    pseudo.barotropicVelocityAmplitude = {WVComplex64{0.12,0.01},WVComplex64{-0.04,0.02}};
    pseudo.frequency = 1.405e-4; pseudo.rampDuration = 900.0; pseudo.startTime = -50.0;
    pseudo.maximumForcedHorizontalWavenumber = std::numeric_limits<double>::infinity();
    pseudo.maximumForcedVerticalMode = std::numeric_limits<double>::infinity();
    WVFrozenForcingSchedule schedule;
    schedule.entries.push_back(entry(WVForcingKind::bottomFrictionQuadratic,"WVBottomFrictionQuadratic","drag",WVForcingStage::spatial,128,WVBottomFrictionQuadraticRecord{1.7e-3}));
    schedule.entries.push_back(entry(WVForcingKind::pseudoTopographicWaveGeneration,"WVPseudoTopographicWaveGeneration","topography",WVForcingStage::spectral,127,pseudo));
    auto engine = createEngine(hydrostatic,schedule);
    OwnedState state(engine->kernel().descriptor().spectralShape());
    const WVComplex64 canary{std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::quiet_NaN()};
    std::vector<WVComplex64> values(3*state.shape.elementCount(),canary);
    auto flux = fluxView(values,state.shape);
    const auto status = engine->nonlinearFlux(state.view(),flux);
    require(static_cast<bool>(status),"quadratic/pseudo forcing failed: "+status.message);
    requireFinite(values,"quadratic/pseudo forcing produced non-finite output");
    const auto& value = configuration(hydrostatic);
    const auto R = value.Nx*value.Ny*value.Nz;
    const auto q = hydrostatic ? 3U : 4U;
    require(engine->metrics().workspaceCapacityBytes == (4+q)*R*sizeof(double),"quadratic forcing did not allocate only its required real-field workspace");
}

void testMultipleWholeFluxProducers() {
    auto schedule = nonlinearSchedule();
    schedule.entries.push_back(entry(WVForcingKind::nonlinearAdvection,"WVNonlinearAdvection","nonlinear-second",WVForcingStage::spatial,128,WVNonlinearAdvectionRecord{}));
    auto engine = createEngine(true,schedule);
    auto direct = createEngine(true,nonlinearSchedule());
    OwnedState state(engine->kernel().descriptor().spectralShape());
    const WVComplex64 canary{std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::quiet_NaN()};
    std::vector<WVComplex64> values(3*state.shape.elementCount(),canary),single(values.size(),canary);
    auto flux = fluxView(values,state.shape);
    auto singleFlux = fluxView(single,state.shape);
    auto status = engine->nonlinearFlux(state.view(),flux);
    require(static_cast<bool>(status),"multiple whole-flux producers failed");
    status = direct->nonlinearFlux(state.view(),singleFlux);
    require(static_cast<bool>(status),"single whole-flux control failed");
    for (std::size_t index = 0; index < values.size(); ++index) {
        require(std::abs(values[index].real-2.0*single[index].real) <= 1e-13 && std::abs(values[index].imag-2.0*single[index].imag) <= 1e-13,"temporary whole-flux accumulation changed the result");
    }
    require(engine->metrics().workspaceCapacityBytes == values.size()*sizeof(WVComplex64),"multiple whole-flux producers did not allocate exactly one temporary tendency");
}

void testRightHandSideContextIdentity() {
    auto first = createEngine(true,nonlinearSchedule());
    auto second = createEngine(true,nonlinearSchedule());
    OwnedState state(first->kernel().descriptor().spectralShape());
    std::vector<WVComplex64> values(3*state.shape.elementCount());
    auto flux = fluxView(values,state.shape);
    const auto spatial = first->kernel().descriptor().spatialShape();
    const auto R = spatial.elementCount();
    std::vector<double> fields(3*R),scalar(R,1.0),scalarFlux(R);
    WVRealFieldBundleView fieldView{fields.data(),{spatial.first,spatial.second,spatial.third,3}};
    WVConstantStratificationRightHandSideContext context;
    auto status = first->evaluateRightHandSideWithContext(state.view(),flux,fieldView,context);
    require(static_cast<bool>(status) && context.hasAdvectionFields(),"RHS context was not prepared");
    const WVRealVolumeConstView scalarView{scalar.data(),spatial};
    WVRealVolumeView scalarFluxView{scalarFlux.data(),spatial};
    status = second->advectFGridScalar(context,scalarView,false,scalarFluxView);
    require(status.code == WVKernelStatusCode::invalidConfiguration,"a foreign RHS context was accepted");
    WVConstantStratificationRightHandSideContext replacement;
    status = first->evaluateRightHandSideWithContext(state.view(),flux,fieldView,replacement);
    require(static_cast<bool>(status),"replacement RHS context failed");
    status = first->advectFGridScalar(context,scalarView,false,scalarFluxView);
    require(status.code == WVKernelStatusCode::invalidConfiguration,"a stale RHS context was accepted");
    status = first->advectFGridScalar(replacement,scalarView,false,scalarFluxView);
    require(static_cast<bool>(status),"current RHS context was rejected");
}

void testValidation() {
    auto schedule = nonlinearSchedule();
    schedule.profileVersion = 99;
    std::unique_ptr<WVConstantStratificationForcingEngine> engine;
    auto status = WVConstantStratificationForcingEngine::create(configuration(true),schedule,std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),engine);
    require(status.code == WVKernelStatusCode::unsupportedOperation && !engine,"unsupported schedule profile was accepted");
    schedule = nonlinearSchedule();
    schedule.entries.front().stage = WVForcingStage::spectral;
    status = WVConstantStratificationForcingEngine::create(configuration(true),schedule,std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),engine);
    require(status.code == WVKernelStatusCode::invalidConfiguration && !engine,"wrong forcing stage was accepted");
}

} // namespace

int main() {
    try {
        testNonlinearCompatibility(true);
        testNonlinearCompatibility(false);
        testFixedAmplitudeAndRK4();
        testForcingTrafficAccounting();
        testRK4DeterminismRestartAndFailure();
        testSpectralForcing();
        testQuadraticAndPseudo(true);
        testQuadraticAndPseudo(false);
        testMultipleWholeFluxProducers();
        testRightHandSideContextIdentity();
        testValidation();
        std::cout << "Portable forcing and RK4 tests passed.\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
