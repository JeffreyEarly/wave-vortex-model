#include "WaveVortexRuntime/WVFixedStepRK4.hpp"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

struct OwnedState {
    WVShape2D shape{1,1};
    std::vector<WVComplex64> values{{1.0,0.5},{-0.25,0.75},{0.125,-0.5}};
    double t = 0.0;
    double t0 = -1.0;

    WVMutableState mutableView() {
        const auto count = shape.elementCount();
        return {t,t0,{{values.data(),shape},{values.data()+count,shape},{values.data()+2*count,shape}}};
    }
};

class ContractSystem final : public WVIntegrationSystem {
public:
    WVShape2D stateShape() const noexcept override { return {1,1}; }

    WVKernelStatus evaluateRightHandSide(const WVState& state, WVFlux& rightHandSide) override {
        require(state.coefficients.Ap.data[0].real == fixedAmplitude,"RK4 evaluated an unconstrained stage state");
        rightHandSide.Fp.data[0] = {0.5*state.coefficients.Ap.data[0].real,0.5*state.coefficients.Ap.data[0].imag};
        rightHandSide.Fm.data[0] = {-state.coefficients.Am.data[0].real,-state.coefficients.Am.data[0].imag};
        rightHandSide.F0.data[0] = {2.0*state.coefficients.A0.data[0].real,2.0*state.coefficients.A0.data[0].imag};
        ++evaluationCount;
        return WVKernelStatus::ok();
    }

    WVKernelStatus enforceStateConstraints(WVMutableCoefficients& coefficients) override {
        coefficients.Ap.data[0].real = fixedAmplitude;
        ++constraintCount;
        return WVKernelStatus::ok();
    }

    static constexpr double fixedAmplitude = 0.375;
    std::size_t evaluationCount = 0;
    std::size_t constraintCount = 0;
};

class DenseOutputDouble final : public WVDenseOutput {
public:
    WVShape2D stateShape() const noexcept override { return {1,1}; }
    double initialTime() const noexcept override { return 1.0; }
    double finalTime() const noexcept override { return 2.0; }
    WVKernelStatus evaluate(double time, WVMutableState& output) const override {
        output.t = time;
        output.coefficients.Ap.data[0] = {time,0.0};
        output.coefficients.Am.data[0] = {2.0*time,0.0};
        output.coefficients.A0.data[0] = {3.0*time,0.0};
        return WVKernelStatus::ok();
    }
};

class ScheduleDouble final : public WVOutputSchedule {
public:
    explicit ScheduleDouble(std::vector<double> requestedTimes) : times_(std::move(requestedTimes)) {}
    WVKernelStatus reset(double initialTime) override {
        index_ = static_cast<std::size_t>(std::lower_bound(times_.begin(),times_.end(),initialTime)-times_.begin());
        return std::is_sorted(times_.begin(),times_.end()) ? WVKernelStatus::ok() : WVKernelStatus{WVKernelStatusCode::invalidConfiguration,"Output times must be ordered."};
    }
    bool nextTimeInInterval(double initialTime, double finalTime, double& outputTime) const noexcept override {
        if (index_ == times_.size() || times_[index_] < initialTime || times_[index_] > finalTime) return false;
        outputTime = times_[index_];
        return true;
    }
    void consumeNextTime() noexcept override { if (index_ < times_.size()) ++index_; }
private:
    std::vector<double> times_;
    std::size_t index_ = 0;
};

class SinkDouble final : public WVIntegrationOutputSink {
public:
    WVKernelStatus receive(const Event& event, Action& action) override {
        kinds.push_back(event.kind);
        retainedValues.push_back(event.state.coefficients.Ap.data[0]);
        action = event.kind == EventKind::accepted ? Action::terminate : Action::continueIntegration;
        return WVKernelStatus::ok();
    }
    std::vector<EventKind> kinds;
    std::vector<WVComplex64> retainedValues;
};

void testPortableContractsAndImmutableOutput() {
    static_assert(std::is_same_v<decltype(WVState{}.coefficients.Ap.data),const WVComplex64*>);
    static_assert(!std::is_copy_constructible_v<WVTimeIntegrator>);
    static_assert(sizeof(WVAcceptedStep) < 256);

    DenseOutputDouble denseOutput;
    OwnedState interpolation;
    auto interpolationState = interpolation.mutableView();
    auto status = denseOutput.evaluate(1.5,interpolationState);
    require(static_cast<bool>(status) && interpolationState.t == 1.5,"dense-output test double did not write caller-owned storage");

    ScheduleDouble schedule({1.25,1.5,1.75});
    status = schedule.reset(1.0);
    require(static_cast<bool>(status),"ordered output schedule was rejected");
    double requestedTime = 0.0;
    require(schedule.nextTimeInInterval(1.0,1.6,requestedTime) && requestedTime == 1.25,"schedule did not own the next ordered request independently of a solver step");
    schedule.consumeNextTime();
    require(schedule.nextTimeInInterval(1.0,1.6,requestedTime) && requestedTime == 1.5,"schedule did not advance its own cursor");

    SinkDouble sink;
    WVIntegrationOutputSink::Action action;
    const WVIntegrationOutputSink::Event event{WVIntegrationOutputSink::EventKind::accepted,interpolationState.view()};
    status = sink.receive(event,action);
    require(static_cast<bool>(status) && action == WVIntegrationOutputSink::Action::terminate,"sink did not request clean termination");
    interpolation.values[0] = {99.0,0.0};
    require(sink.retainedValues.front().real == 1.5,"sink failed to copy an immutable reusable-storage view it retained");
}

void testAcceptedStepLifetimeRestartAndPartialStep() {
    ContractSystem system;
    OwnedState owned;
    auto state = owned.mutableView();
    WVFixedStepRK4 concrete(system);
    WVTimeIntegrator& integrator = concrete;
    auto status = integrator.prepareStateAfterRestart(state);
    require(static_cast<bool>(status) && state.coefficients.Ap.data[0].real == ContractSystem::fixedAmplitude,"restart preparation did not restore the exact constraint");
    require(integrator.lastAcceptedStep() == nullptr,"restart preparation exposed a stale accepted step");

    status = integrator.step(state,0.1);
    require(static_cast<bool>(status),"contract-system RK4 step failed");
    const auto* accepted = integrator.lastAcceptedStep();
    require(accepted != nullptr && accepted->initialTime == 0.0 && accepted->finalTime == 0.1,"accepted interval is incorrect");
    require(accepted->endpoint.t == 0.1 && accepted->endpoint.coefficients.Ap.data[0].real == ContractSystem::fixedAmplitude,"accepted endpoint view is incorrect");
    require(accepted->methodStatistics.acceptedStepCount == 1 && accepted->methodStatistics.rightHandSideEvaluationCount == 4 && accepted->methodStatistics.stepSize == 0.1,"accepted method statistics are incorrect");
    require(accepted->denseOutput == nullptr,"RK4 supplied dense-output behavior reserved for issue #184");
    require(system.evaluationCount == 4 && system.constraintCount == 6,"constraints were not applied at restart, every stage, and the accepted endpoint");

    status = integrator.advanceToTime(state,0.325,0.1);
    require(static_cast<bool>(status) && state.t == 0.325,"partial final step did not land exactly on the integration bound");
    accepted = integrator.lastAcceptedStep();
    require(accepted != nullptr && accepted->initialTime > 0.299999999999 && accepted->finalTime == 0.325 && accepted->methodStatistics.stepSize > 0.024999999999,"last accepted step does not describe the final partial interval");
    status = integrator.prepareStateAfterRestart(state);
    require(static_cast<bool>(status) && integrator.lastAcceptedStep() == nullptr,"restart did not invalidate the method-owned accepted-step view");
}

void testExactRK4TrafficAccounting() {
    ContractSystem system;
    OwnedState owned;
    auto state = owned.mutableView();
    WVFixedStepRK4 integrator(system);
    auto status = integrator.prepareStateAfterRestart(state);
    require(static_cast<bool>(status),"traffic test restart preparation failed");
    status = integrator.step(state,0.1);
    require(static_cast<bool>(status),"traffic test step failed");
    const auto& metrics = integrator.metrics();
    require(metrics.stageStateConstructionElementReads == 21 && metrics.stageStateConstructionElementWrites == 12,"stage-state traffic accounting is not exact");
    require(metrics.stageFluxClearElementWrites == 12 && metrics.weightedFluxClearElementWrites == 3,"RK buffer-clear accounting is not exact");
    require(metrics.weightedAccumulationElementReads == 24 && metrics.weightedAccumulationElementWrites == 12,"weighted-accumulation accounting is not exact");
    require(metrics.finalStateUpdateElementReads == 6 && metrics.finalStateUpdateElementWrites == 3,"final-state traffic accounting is not exact");
    require(metrics.workspaceCapacityBytes == 9*sizeof(WVComplex64) && metrics.workspaceLiveBytes == metrics.workspaceCapacityBytes && metrics.workspaceMaximumLiveBytes == metrics.workspaceCapacityBytes,"RK workspace liveness is not exact");
}

} // namespace

int main() {
    try {
        testPortableContractsAndImmutableOutput();
        testAcceptedStepLifetimeRestartAndPartialStep();
        testExactRK4TrafficAccounting();
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
