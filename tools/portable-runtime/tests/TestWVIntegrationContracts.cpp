#include "WaveVortexRuntime/WVAdaptiveRK23.hpp"
#include "WaveVortexRuntime/WVFixedStepRK4.hpp"
#include "WaveVortexRuntime/WVIntegrationDriver.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
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

bool exactlyEqual(const std::vector<WVComplex64>& first, const std::vector<WVComplex64>& second) {
    if (first.size() != second.size()) return false;
    for (std::size_t index = 0; index < first.size(); ++index) {
        if (first[index].real != second[index].real || first[index].imag != second[index].imag) return false;
    }
    return true;
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

class UniformErrorPolicy final : public WVIntegrationErrorPolicy {
public:
    UniformErrorPolicy(std::size_t count, double tolerance) : count_(count), tolerance_(tolerance) {}
    std::size_t componentCount() const noexcept override { return 3; }
    std::size_t elementCount(std::size_t component) const noexcept override { return component < 3 ? count_ : 0; }
    double absoluteTolerance(std::size_t component, std::size_t index) const noexcept override {
        return component < 3 && index < count_ ? tolerance_ : std::numeric_limits<double>::quiet_NaN();
    }
    std::size_t persistentBytes() const noexcept override { return 0; }
private:
    std::size_t count_;
    double tolerance_;
};

WVKernelStatus makeUniformPolicy(WVShape2D shape, double scale, std::unique_ptr<WVIntegrationErrorPolicy>& policy) {
    policy = std::make_unique<UniformErrorPolicy>(shape.elementCount(),scale);
    return WVKernelStatus::ok();
}

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

    WVStateConstraintResult enforceStateConstraints(WVMutableCoefficients& coefficients) override {
        const bool modified = coefficients.Ap.data[0].real != fixedAmplitude;
        coefficients.Ap.data[0].real = fixedAmplitude;
        ++constraintCount;
        if (constraintCount == failConstraintAt) return {{WVKernelStatusCode::invalidConfiguration,"injected endpoint-constraint failure"},modified ? 1U : 0U,false};
        return {WVKernelStatus::ok(),modified ? 1U : 0U,false};
    }
    WVKernelStatus createErrorPolicy(double scale, std::unique_ptr<WVIntegrationErrorPolicy>& policy) const override { return makeUniformPolicy(stateShape(),scale,policy); }

    static constexpr double fixedAmplitude = 0.375;
    std::size_t evaluationCount = 0;
    std::size_t constraintCount = 0;
    std::size_t failConstraintAt = 0;
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
    WVKernelStatus reset(double initialTime, double finalTime) override {
        (void)finalTime;
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
        times.push_back(event.state.t);
        retainedValues.push_back(event.state.coefficients.Ap.data[0]);
        action = terminateAtKind == event.kind ? Action::terminate : Action::continueIntegration;
        return WVKernelStatus::ok();
    }
    EventKind terminateAtKind = EventKind::accepted;
    std::vector<EventKind> kinds;
    std::vector<double> times;
    std::vector<WVComplex64> retainedValues;
};

class FailingSink final : public WVIntegrationOutputSink {
public:
    WVKernelStatus receive(const Event& event, Action& action) override {
        action = Action::continueIntegration;
        kinds.push_back(event.kind);
        if (event.kind == EventKind::interpolated) return {WVKernelStatusCode::unsupportedOperation,"injected sink failure"};
        return WVKernelStatus::ok();
    }
    std::vector<EventKind> kinds;
};

class PolynomialSystem final : public WVIntegrationSystem {
public:
    WVShape2D stateShape() const noexcept override { return {1,1}; }
    WVKernelStatus evaluateRightHandSide(const WVState& state, WVFlux& flux) override {
        const double derivative = 1.0+4.0*state.t+9.0*state.t*state.t;
        flux.Fp.data[0] = {derivative,0.0};
        flux.Fm.data[0] = {2.0*derivative,0.0};
        flux.F0.data[0] = {-derivative,0.0};
        ++evaluationCount;
        return WVKernelStatus::ok();
    }
    WVStateConstraintResult enforceStateConstraints(WVMutableCoefficients&) override { return {WVKernelStatus::ok(),0}; }
    WVKernelStatus createErrorPolicy(double scale, std::unique_ptr<WVIntegrationErrorPolicy>& policy) const override { return makeUniformPolicy(stateShape(),scale,policy); }
    std::size_t evaluationCount = 0;
};

class ExponentialSystem final : public WVIntegrationSystem {
public:
    WVShape2D stateShape() const noexcept override { return {1,1}; }
    WVKernelStatus evaluateRightHandSide(const WVState& state, WVFlux& flux) override {
        flux.Fp.data[0] = state.coefficients.Ap.data[0];
        flux.Fm.data[0] = state.coefficients.Am.data[0];
        flux.F0.data[0] = state.coefficients.A0.data[0];
        return WVKernelStatus::ok();
    }
    WVStateConstraintResult enforceStateConstraints(WVMutableCoefficients&) override { return {WVKernelStatus::ok(),0}; }
    WVKernelStatus createErrorPolicy(double scale, std::unique_ptr<WVIntegrationErrorPolicy>& policy) const override { return makeUniformPolicy(stateShape(),scale,policy); }
};

class NonFiniteSystem final : public WVIntegrationSystem {
public:
    WVShape2D stateShape() const noexcept override { return {1,1}; }
    WVKernelStatus evaluateRightHandSide(const WVState&, WVFlux& flux) override {
        const double value = std::numeric_limits<double>::infinity();
        flux.Fp.data[0] = {value,0.0};
        flux.Fm.data[0] = {value,0.0};
        flux.F0.data[0] = {value,0.0};
        return WVKernelStatus::ok();
    }
    WVStateConstraintResult enforceStateConstraints(WVMutableCoefficients&) override { return {WVKernelStatus::ok(),0}; }
    WVKernelStatus createErrorPolicy(double scale, std::unique_ptr<WVIntegrationErrorPolicy>& policy) const override { return makeUniformPolicy(stateShape(),scale,policy); }
};

double polynomial(double time) {
    return time+2.0*time*time+3.0*time*time*time;
}

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
    status = schedule.reset(1.0,2.0);
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

void testRK4DenseOutputPolynomialEndpointsAndStorage() {
    PolynomialSystem system;
    OwnedState owned;
    owned.values.assign(3,WVComplex64{});
    auto state = owned.mutableView();
    WVFixedStepRK4 integrator(system,{true});
    auto status = integrator.prepareStateAfterRestart(state);
    require(static_cast<bool>(status),"dense-output restart preparation failed");
    status = integrator.step(state,0.4);
    require(static_cast<bool>(status),"dense-output RK4 step failed");
    const auto* accepted = integrator.lastAcceptedStep();
    require(accepted != nullptr && accepted->denseOutput != nullptr,"opt-in RK4 did not publish dense output");
    require(system.evaluationCount == 4,"dense-output retention added a right-hand-side evaluation");
    require(integrator.metrics().workspaceCapacityBytes == 12*sizeof(WVComplex64),"dense-output RK4 did not retain exactly 12M complex values");
    require(integrator.metrics().denseHistoryCapacityBytes == 3*sizeof(WVComplex64),"dense-output RK4 history is not exactly 3M complex values");

    OwnedState output;
    output.values.assign(3,WVComplex64{});
    auto outputState = output.mutableView();
    for (const double time : {0.0,0.1,0.25,0.4}) {
        status = accepted->denseOutput->evaluate(time,outputState);
        require(static_cast<bool>(status),"polynomial dense-output evaluation failed");
        require(std::abs(outputState.coefficients.Ap.data[0].real-polynomial(time)) < 2e-15,"polynomial dense output is not exact");
        require(std::abs(outputState.coefficients.Am.data[0].real-2.0*polynomial(time)) < 4e-15,"polynomial dense output Am is not exact");
        require(std::abs(outputState.coefficients.A0.data[0].real+polynomial(time)) < 2e-15,"polynomial dense output A0 is not exact");
    }
    require(integrator.metrics().denseOutputEvaluationCount == 4,"dense-output evaluation count is incorrect");

    auto aliasedOutput = state;
    status = accepted->denseOutput->evaluate(0.2,aliasedOutput);
    require(status.code == WVKernelStatusCode::overlappingArrays,"dense output accepted an alias of the accepted state");
}

double denseExponentialError(double stepSize) {
    ExponentialSystem system;
    OwnedState stateOwner;
    stateOwner.values.assign(3,WVComplex64{1.0,0.0});
    auto state = stateOwner.mutableView();
    WVFixedStepRK4 integrator(system,{true});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"exponential restart preparation failed");
    require(static_cast<bool>(integrator.step(state,stepSize)),"exponential RK4 step failed");
    OwnedState outputOwner;
    outputOwner.values.assign(3,WVComplex64{});
    auto output = outputOwner.mutableView();
    require(static_cast<bool>(integrator.lastAcceptedStep()->denseOutput->evaluate(0.37*stepSize,output)),"exponential dense output failed");
    return std::abs(output.coefficients.Ap.data[0].real-std::exp(0.37*stepSize));
}

void testDenseOutputConvergenceOrder() {
    const double coarse = denseExponentialError(0.4);
    const double medium = denseExponentialError(0.2);
    const double fine = denseExponentialError(0.1);
    require(std::log2(coarse/medium) > 3.8 && std::log2(medium/fine) > 3.8,"RK4 continuous extension did not demonstrate fourth-order convergence");
}

void testOrderedScheduleAndIntegrationDriver() {
    PolynomialSystem system;
    OwnedState stateOwner;
    stateOwner.values.assign(3,WVComplex64{});
    auto state = stateOwner.mutableView();
    WVFixedStepRK4 integrator(system,{true});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"driver restart preparation failed");
    WVIntegrationDriver driver(integrator);
    WVOrderedOutputSchedule schedule({0.0,0.1,0.2,0.35,0.4});
    SinkDouble sink;
    sink.terminateAtKind = WVIntegrationOutputSink::EventKind::done;
    auto status = driver.advanceToTime(state,0.4,0.2,schedule,sink);
    require(static_cast<bool>(status),"integration driver failed");
    const std::vector<WVIntegrationOutputSink::EventKind> expectedKinds{
        WVIntegrationOutputSink::EventKind::init,
        WVIntegrationOutputSink::EventKind::interpolated,
        WVIntegrationOutputSink::EventKind::accepted,
        WVIntegrationOutputSink::EventKind::interpolated,
        WVIntegrationOutputSink::EventKind::accepted,
        WVIntegrationOutputSink::EventKind::done};
    require(sink.kinds == expectedKinds,"integration-driver event sequence is incorrect");
    require(schedule.consumedCount() == schedule.requestCount(),"integration driver did not consume every requested time");
    require(system.evaluationCount == 8,"scheduled output changed the accepted-step right-hand-side count");
    require(state.t == 0.4 && std::abs(state.coefficients.Ap.data[0].real-polynomial(0.4)) < 2e-15,"scheduled output changed the accepted trajectory");
    require(driver.metrics().interpolatedEventCount == 2 && driver.metrics().acceptedEventCount == 2,"integration-driver event metrics are incorrect");
    require(driver.metrics().interpolationBufferCapacityBytes == 3*sizeof(WVComplex64),"driver did not retain exactly one 3M interpolation buffer");
}

void testNoOutputDriverAndValidationAtomicity() {
    PolynomialSystem system;
    OwnedState stateOwner;
    stateOwner.values.assign(3,WVComplex64{});
    auto state = stateOwner.mutableView();
    WVFixedStepRK4 integrator(system);
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"no-output restart preparation failed");
    WVIntegrationDriver driver(integrator);
    WVOrderedOutputSchedule noOutput({});
    SinkDouble sink;
    sink.terminateAtKind = WVIntegrationOutputSink::EventKind::done;
    auto status = driver.advanceToTime(state,0.4,0.2,noOutput,sink);
    require(static_cast<bool>(status),"no-output driver failed");
    require(driver.persistentBytes() == 0 && integrator.persistentBytes() == 9*sizeof(WVComplex64),"no-output execution retained dense-output storage");
    require(sink.kinds == std::vector<WVIntegrationOutputSink::EventKind>({WVIntegrationOutputSink::EventKind::init,WVIntegrationOutputSink::EventKind::done}),"no-output event sequence is incorrect");

    OwnedState invalidOwner;
    invalidOwner.values.assign(3,WVComplex64{});
    auto invalidState = invalidOwner.mutableView();
    WVOrderedOutputSchedule invalidSchedule({0.2,0.1});
    SinkDouble invalidSink;
    status = driver.advanceToTime(invalidState,0.4,0.2,invalidSchedule,invalidSink);
    require(status.code == WVKernelStatusCode::invalidConfiguration,"invalid schedule was accepted");
    require(invalidState.t == 0.0 && invalidSink.kinds.empty(),"invalid schedule mutated state or emitted output before validation");
}

void testInteriorTerminationCarriesAcceptedEndpoint() {
    PolynomialSystem system;
    OwnedState stateOwner;
    stateOwner.values.assign(3,WVComplex64{});
    auto state = stateOwner.mutableView();
    WVFixedStepRK4 integrator(system,{true});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"termination restart preparation failed");
    WVIntegrationDriver driver(integrator);
    WVOrderedOutputSchedule schedule({0.1,0.3});
    SinkDouble sink;
    sink.terminateAtKind = WVIntegrationOutputSink::EventKind::interpolated;
    const auto status = driver.advanceToTime(state,0.4,0.2,schedule,sink);
    require(static_cast<bool>(status),"interior termination failed");
    require(sink.kinds == std::vector<WVIntegrationOutputSink::EventKind>({WVIntegrationOutputSink::EventKind::init,WVIntegrationOutputSink::EventKind::interpolated,WVIntegrationOutputSink::EventKind::done}),"termination event sequence is incorrect");
    require(sink.times.back() == 0.2 && state.t == 0.2,"done event did not carry the actual accepted endpoint");
}

void testInteriorOutputAndSinkFailuresPreserveAcceptedStateWithoutDone() {
    PolynomialSystem noDenseSystem;
    OwnedState noDenseOwner;
    noDenseOwner.values.assign(3,WVComplex64{});
    auto noDenseState = noDenseOwner.mutableView();
    WVFixedStepRK4 noDenseIntegrator(noDenseSystem);
    require(static_cast<bool>(noDenseIntegrator.prepareStateAfterRestart(noDenseState)),"no-dense failure preparation failed");
    WVIntegrationDriver noDenseDriver(noDenseIntegrator);
    WVOrderedOutputSchedule noDenseSchedule({0.1});
    SinkDouble noDenseSink;
    noDenseSink.terminateAtKind = WVIntegrationOutputSink::EventKind::done;
    auto status = noDenseDriver.advanceToTime(noDenseState,0.2,0.2,noDenseSchedule,noDenseSink);
    require(status.code == WVKernelStatusCode::unsupportedOperation,"interior output unexpectedly succeeded without method history");
    require(noDenseState.t == 0.2 && noDenseSink.kinds == std::vector<WVIntegrationOutputSink::EventKind>({WVIntegrationOutputSink::EventKind::init}),"interpolation failure changed the accepted endpoint or emitted done");

    PolynomialSystem failingSystem;
    OwnedState failingOwner;
    failingOwner.values.assign(3,WVComplex64{});
    auto failingState = failingOwner.mutableView();
    WVFixedStepRK4 failingIntegrator(failingSystem,{true});
    require(static_cast<bool>(failingIntegrator.prepareStateAfterRestart(failingState)),"sink-failure preparation failed");
    WVIntegrationDriver failingDriver(failingIntegrator);
    WVOrderedOutputSchedule failingSchedule({0.1});
    FailingSink failingSink;
    status = failingDriver.advanceToTime(failingState,0.2,0.2,failingSchedule,failingSink);
    require(!status && failingState.t == 0.2,"sink failure changed the latest accepted endpoint");
    require(failingSink.kinds == std::vector<WVIntegrationOutputSink::EventKind>({WVIntegrationOutputSink::EventKind::init,WVIntegrationOutputSink::EventKind::interpolated}),"sink failure emitted an unexpected done event");
}

std::filesystem::path temporaryCheckpointPath() {
    return std::filesystem::temp_directory_path()/("wv-output-sink-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count())+".nc");
}

void testTransactionalCheckpointSink() {
#ifdef WV_CHECKPOINT_FIXTURE_DIR
    WVCheckpoint checkpoint;
    const auto readStatus = WVCheckpointReader::read((std::filesystem::path(WV_CHECKPOINT_FIXTURE_DIR)/"forcing-mixed-nonhydrostatic.nc").string(),checkpoint);
    require(static_cast<bool>(readStatus),"checkpoint-sink fixture could not be read");
    const auto destination = temporaryCheckpointPath();
    WVCheckpointOutputSink sink(checkpoint.state.t,destination.string(),checkpoint);
    WVIntegrationOutputSink::Action action;
    const auto event = WVIntegrationOutputSink::Event{WVIntegrationOutputSink::EventKind::accepted,checkpoint.state.view()};
    auto status = sink.receive(event,action);
    require(static_cast<bool>(status) && sink.wroteCheckpoint(),"checkpoint sink did not write its target");
    WVCheckpoint roundTrip;
    require(static_cast<bool>(WVCheckpointReader::read(destination.string(),roundTrip)),"checkpoint sink output is not readable");
    require(roundTrip.state.t == checkpoint.state.t && exactlyEqual(roundTrip.state.coefficients.Ap,checkpoint.state.coefficients.Ap),"checkpoint sink output changed the delivered state");
    std::filesystem::remove(destination);

    WVCheckpointOutputSink failingSink(checkpoint.state.t,(destination/"missing"/"output.nc").string(),checkpoint);
    status = failingSink.receive(event,action);
    require(!status && !failingSink.wroteCheckpoint(),"checkpoint sink reported success after a transactional write failure");
#endif
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
    require(accepted->denseOutput == nullptr,"default RK4 unexpectedly retained dense-output history");
    require(system.evaluationCount == 4 && system.constraintCount == 5,"constraints were not applied at restart, each constructed stage, and the accepted endpoint");

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
    require(metrics.stageStateConstructionElementReads == 18 && metrics.stageStateConstructionElementWrites == 9,"stage-state traffic accounting is not exact");
    require(metrics.stageFluxClearElementWrites == 0 && metrics.weightedFluxClearElementWrites == 0,"RK buffer clears were not eliminated");
    require(metrics.weightedFluxInitializationElementReads == 3 && metrics.weightedFluxInitializationElementWrites == 3,"first-stage weighted-flux initialization is not exact");
    require(metrics.weightedAccumulationElementReads == 18 && metrics.weightedAccumulationElementWrites == 9,"weighted-accumulation accounting is not exact");
    require(metrics.finalStateUpdateElementReads == 6 && metrics.finalStateUpdateElementWrites == 3,"final-state candidate traffic accounting is not exact");
    require(metrics.acceptedStateCommitElementReads == 3 && metrics.acceptedStateCommitElementWrites == 3,"accepted-state commit traffic accounting is not exact");
    require(metrics.workspaceCapacityBytes == 9*sizeof(WVComplex64) && metrics.workspaceLiveBytes == metrics.workspaceCapacityBytes && metrics.workspaceMaximumLiveBytes == metrics.workspaceCapacityBytes,"RK workspace liveness is not exact");
}

void testFailedEndpointConstraintIsAtomic() {
    ContractSystem system;
    system.failConstraintAt = 5;
    OwnedState owned;
    auto state = owned.mutableView();
    WVFixedStepRK4 integrator(system);
    auto status = integrator.prepareStateAfterRestart(state);
    require(static_cast<bool>(status),"atomicity test restart preparation failed");
    const auto originalValues = owned.values;
    const auto originalTime = state.t;
    status = integrator.step(state,0.1);
    require(status.code == WVKernelStatusCode::invalidConfiguration,"endpoint-constraint failure was not propagated");
    require(exactlyEqual(owned.values,originalValues) && state.t == originalTime,"failed endpoint constraint modified the accepted state");
    require(integrator.lastAcceptedStep() == nullptr,"failed endpoint constraint published an accepted step");
}

double adaptiveFixedStepError(double stepSize, double* estimator = nullptr) {
    ExponentialSystem system;
    OwnedState owner;
    owner.values.assign(3,WVComplex64{1.0,0.0});
    auto state = owner.mutableView();
    WVAdaptiveRK23 integrator(system,{100.0,100.0});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"adaptive convergence preparation failed");
    while (state.t < 1.0-1e-15) {
        require(static_cast<bool>(integrator.step(state,std::min(stepSize,1.0-state.t))),"adaptive fixed-step convergence execution failed");
        if (estimator != nullptr && state.t <= stepSize+1e-15) *estimator = integrator.metrics().lastNormalizedError;
    }
    return std::abs(state.coefficients.Ap.data[0].real-std::exp(1.0));
}

void testAdaptiveControllerAndConvergence() {
    WVAdaptiveRK23Controller controller;
    require(static_cast<bool>(controller.validate()),"default adaptive controller is invalid");
    require(controller.stepFactor(0.0,true) == 5.0,"zero adaptive error did not select maximum growth");
    require(controller.stepFactor(std::numeric_limits<double>::infinity(),false) == 0.2,"nonfinite adaptive error did not select minimum shrinkage");
    require(controller.stepFactor(1e-12,false) == 1.0,"rejected adaptive step was permitted to grow");

    double estimatorCoarse = 0.0;
    double estimatorMedium = 0.0;
    const double coarse = adaptiveFixedStepError(0.2,&estimatorCoarse);
    const double medium = adaptiveFixedStepError(0.1,&estimatorMedium);
    const double fine = adaptiveFixedStepError(0.05);
    require(std::log2(coarse/medium) > 2.8 && std::log2(medium/fine) > 2.8,"Bogacki-Shampine accepted solution did not demonstrate third-order convergence");
    require(std::log2(estimatorCoarse/estimatorMedium) > 2.8,"Bogacki-Shampine embedded estimate did not scale at third local-error order");
}

double adaptiveDenseError(double stepSize) {
    ExponentialSystem system;
    OwnedState owner;
    owner.values.assign(3,WVComplex64{1.0,0.0});
    auto state = owner.mutableView();
    WVAdaptiveRK23 integrator(system,{100.0,100.0});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"adaptive dense preparation failed");
    require(static_cast<bool>(integrator.step(state,stepSize)),"adaptive dense step failed");
    OwnedState outputOwner;
    outputOwner.values.assign(3,WVComplex64{});
    auto output = outputOwner.mutableView();
    require(static_cast<bool>(integrator.lastAcceptedStep()->denseOutput->evaluate(0.37*stepSize,output)),"adaptive dense evaluation failed");
    require(integrator.metrics().workspaceCapacityBytes == 15*sizeof(WVComplex64),"adaptive integrator did not retain exactly 15M complex workspace");
    return std::abs(output.coefficients.Ap.data[0].real-std::exp(0.37*stepSize));
}

void testAdaptiveDenseOutputConvergence() {
    const double coarse = adaptiveDenseError(0.4);
    const double medium = adaptiveDenseError(0.2);
    const double fine = adaptiveDenseError(0.1);
    require(std::log2(coarse/medium) > 3.7 && std::log2(medium/fine) > 3.7,"Bogacki-Shampine continuous extension did not demonstrate its expected local order");
}

void testAdaptiveRejectionFSALAndConstraintInvalidation() {
    ExponentialSystem system;
    OwnedState owner;
    owner.values.assign(3,WVComplex64{1.0,0.0});
    auto state = owner.mutableView();
    WVAdaptiveRK23 integrator(system,{1e-8,1e-10});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"adaptive rejection preparation failed");
    require(static_cast<bool>(integrator.step(state,1.0)),"adaptive rejection/retry failed");
    require(integrator.metrics().rejectedStepCount > 0 && integrator.metrics().rejectedInitialDerivativeReuseCount == integrator.metrics().rejectedStepCount,"adaptive retry did not reuse its unchanged initial derivative");
    const auto evaluationsAfterFirst = integrator.metrics().rightHandSideEvaluationCount;
    require(static_cast<bool>(integrator.step(state,integrator.nextStepSize())),"adaptive FSAL follow-up failed");
    require(integrator.metrics().fsalReuseCount == 1 && integrator.metrics().rightHandSideEvaluationCount-evaluationsAfterFirst >= 3,"adaptive accepted-step derivative was not reused through FSAL");

    ContractSystem constrainedSystem;
    OwnedState constrainedOwner;
    auto constrainedState = constrainedOwner.mutableView();
    WVAdaptiveRK23 constrained(constrainedSystem,{10.0,10.0});
    require(static_cast<bool>(constrained.prepareStateAfterRestart(constrainedState)),"constrained adaptive preparation failed");
    require(static_cast<bool>(constrained.step(constrainedState,0.1)),"constrained adaptive step failed");
    require(constrained.metrics().fsalInvalidationCount == 1 && constrained.metrics().constraintModifiedCoefficientCount > 0,"fixed-amplitude restoration did not invalidate FSAL");
}

void testAdaptiveMinimumStepFailureIsAtomic() {
    NonFiniteSystem system;
    OwnedState owner;
    auto state = owner.mutableView();
    const auto original = owner.values;
    WVAdaptiveRK23 integrator(system,{1e-3,1e-6});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"nonfinite adaptive preparation failed");
    const auto status = integrator.step(state,1.0);
    require(status.code == WVKernelStatusCode::numericalFailure,"nonfinite adaptive error did not terminate at the minimum representable step");
    require(state.t == 0.0 && exactlyEqual(owner.values,original),"failed adaptive retries modified the accepted state");
    require(integrator.lastAcceptedStep() == nullptr && integrator.metrics().rejectedStepCount > 0,"failed adaptive retries published an accepted step or omitted rejection metrics");
}

struct AdaptiveDriverResult {
    std::vector<WVComplex64> values;
    std::size_t accepted = 0;
    std::size_t rejected = 0;
};

AdaptiveDriverResult adaptiveDriverRun(std::vector<double> outputTimes) {
    ExponentialSystem system;
    OwnedState owner;
    owner.values.assign(3,WVComplex64{1.0,0.0});
    auto state = owner.mutableView();
    WVAdaptiveRK23 integrator(system,{1e-5,1e-8});
    require(static_cast<bool>(integrator.prepareStateAfterRestart(state)),"adaptive driver preparation failed");
    WVIntegrationDriver driver(integrator);
    WVOrderedOutputSchedule schedule(std::move(outputTimes));
    SinkDouble sink;
    sink.terminateAtKind = WVIntegrationOutputSink::EventKind::done;
    require(static_cast<bool>(driver.advanceToTime(state,1.0,0.2,schedule,sink)),"adaptive integration driver failed");
    return {owner.values,integrator.metrics().acceptedStepCount,integrator.metrics().rejectedStepCount};
}

void testAdaptiveOutputScheduleInvariance() {
    const auto noOutput = adaptiveDriverRun({});
    const auto scheduled = adaptiveDriverRun({0.03,0.11,0.37,0.82,1.0});
    require(exactlyEqual(noOutput.values,scheduled.values),"adaptive requested output changed the accepted trajectory");
    require(noOutput.accepted == scheduled.accepted && noOutput.rejected == scheduled.rejected,"adaptive requested output changed step acceptance");
}

} // namespace

int main() {
    try {
        testPortableContractsAndImmutableOutput();
        testRK4DenseOutputPolynomialEndpointsAndStorage();
        testDenseOutputConvergenceOrder();
        testOrderedScheduleAndIntegrationDriver();
        testNoOutputDriverAndValidationAtomicity();
        testInteriorTerminationCarriesAcceptedEndpoint();
        testInteriorOutputAndSinkFailuresPreserveAcceptedStateWithoutDone();
        testTransactionalCheckpointSink();
        testAcceptedStepLifetimeRestartAndPartialStep();
        testExactRK4TrafficAccounting();
        testFailedEndpointConstraintIsAtomic();
        testAdaptiveControllerAndConvergence();
        testAdaptiveDenseOutputConvergence();
        testAdaptiveRejectionFSALAndConstraintInvalidation();
        testAdaptiveMinimumStepFailureIsAtomic();
        testAdaptiveOutputScheduleInvariance();
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
