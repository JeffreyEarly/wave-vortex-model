#include "WaveVortexRuntime/WVFixedStepRK4.hpp"
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
    std::vector<WVComplex64> scheduledValues(3*count),directValues(3*count);
    auto scheduledFlux = fluxView(scheduledValues,state.shape);
    auto directFlux = fluxView(directValues,state.shape);
    status = scheduled->nonlinearFlux(state.view(),scheduledFlux);
    require(static_cast<bool>(status),"scheduled nonlinear flux failed");
    status = direct->nonlinearFlux(state.view(),directFlux);
    require(static_cast<bool>(status),"direct nonlinear flux failed");
    double error = 0.0;
    for (std::size_t index = 0; index < scheduledValues.size(); ++index) {
        error = std::max(error,std::abs(scheduledValues[index].real-directValues[index].real));
        error = std::max(error,std::abs(scheduledValues[index].imag-directValues[index].imag));
    }
    require(error <= 1e-13,"nonlinear-only schedule changed the shared kernel result");
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
    std::vector<WVComplex64> values(3*state.shape.elementCount());
    auto flux = fluxView(values,state.shape);
    const auto status = engine->nonlinearFlux(state.view(),flux);
    require(static_cast<bool>(status),"adaptive/beta forcing failed");
    requireFinite(values,"adaptive/beta forcing produced non-finite output");
    require(engine->metrics().resolvedSpectralCount == 2,"spectral forcing dispatch was not resolved at construction");
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
    std::vector<WVComplex64> values(3*state.shape.elementCount());
    auto flux = fluxView(values,state.shape);
    const auto status = engine->nonlinearFlux(state.view(),flux);
    require(static_cast<bool>(status),"quadratic/pseudo forcing failed: "+status.message);
    requireFinite(values,"quadratic/pseudo forcing produced non-finite output");
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
        testRK4DeterminismRestartAndFailure();
        testSpectralForcing();
        testQuadraticAndPseudo(true);
        testQuadraticAndPseudo(false);
        testValidation();
        std::cout << "Portable forcing and RK4 tests passed.\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
