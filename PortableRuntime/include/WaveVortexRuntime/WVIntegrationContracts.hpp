#pragma once

#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <cstddef>

namespace wavevortex::runtime {

// Internal portable model boundary. evaluateRightHandSide() must completely
// overwrite every element of the supplied right-hand-side storage, including
// elements whose mathematical tendency is zero. State constraints are applied
// separately so the numerical integrator contains no forcing-specific rules.
class WVIntegrationSystem {
public:
    virtual ~WVIntegrationSystem() = default;
    virtual WVShape2D stateShape() const noexcept = 0;
    virtual WVKernelStatus evaluateRightHandSide(const WVState& state, WVFlux& rightHandSide) = 0;
    virtual WVKernelStatus enforceStateConstraints(WVMutableCoefficients& coefficients) = 0;
};

// Method-owned continuous extension over one accepted interval. Implementations
// write into caller-owned reusable storage; consumers receive only immutable
// WVState views of that storage.
class WVDenseOutput {
public:
    virtual ~WVDenseOutput() = default;
    virtual double initialTime() const noexcept = 0;
    virtual double finalTime() const noexcept = 0;
    virtual WVShape2D stateShape() const noexcept = 0;
    virtual WVKernelStatus evaluate(double time, WVMutableState& output) const = 0;
};

// Immutable description of the most recent accepted step. endpoint and
// denseOutput remain valid only until the owning integrator is next advanced or
// prepared after restart. A null denseOutput means that the concrete method has
// not yet supplied a continuous extension.
struct WVAcceptedStep {
    struct MethodStatistics {
        std::size_t acceptedStepCount = 0;
        std::size_t rightHandSideEvaluationCount = 0;
        double stepSize = 0.0;
    };

    double initialTime = 0.0;
    double finalTime = 0.0;
    WVState endpoint;
    MethodStatistics methodStatistics;
    const WVDenseOutput* denseOutput = nullptr;
};

// Internal numerical-method boundary. A step mutates only the accepted state;
// interpolated output is produced later from the returned accepted-step view and
// is never eligible to become the next integration state.
class WVTimeIntegrator {
public:
    virtual ~WVTimeIntegrator() = default;
    virtual WVKernelStatus prepareStateAfterRestart(WVMutableState& state) = 0;
    virtual WVKernelStatus step(WVMutableState& state, double stepSize) = 0;
    virtual WVKernelStatus advanceToTime(WVMutableState& state, double finalTime, double stepSize) = 0;
    virtual const WVAcceptedStep* lastAcceptedStep() const noexcept = 0;
    virtual std::size_t persistentBytes() const noexcept = 0;
};

// Ordered requested output times are owned independently of accepted solver
// steps. Future integration drivers query this contract only after a step has
// been accepted; a requested time therefore cannot truncate that step.
class WVOutputSchedule {
public:
    virtual ~WVOutputSchedule() = default;
    virtual WVKernelStatus reset(double initialTime) = 0;
    virtual bool nextTimeInInterval(double initialTime, double finalTime, double& outputTime) const noexcept = 0;
    virtual void consumeNextTime() noexcept = 0;
};

// Output-event boundary. Event state is an immutable non-owning view and may be
// backed by reusable interpolation storage. A sink that needs to retain output
// beyond receive() must make its own copy.
class WVIntegrationOutputSink {
public:
    enum class EventKind { init, interpolated, accepted, done };
    enum class Action { continueIntegration, terminate };

    struct Event {
        EventKind kind = EventKind::accepted;
        WVState state;
    };

    virtual ~WVIntegrationOutputSink() = default;
    virtual WVKernelStatus receive(const Event& event, Action& action) = 0;
};

} // namespace wavevortex::runtime
