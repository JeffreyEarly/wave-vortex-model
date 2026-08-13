#pragma once

#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <cstddef>
#include <limits>
#include <memory>

namespace wavevortex::runtime {

// Method-neutral absolute-error policy. Components are deliberately addressed
// by ordinal rather than by WaveVortex names: the current coefficient adapter
// maps Ap, Am, and A0 to the first three components, while a future composite
// observing-system adapter may expose a different component sequence without
// changing an adaptive Runge--Kutta controller.
class WVIntegrationErrorPolicy {
public:
    virtual ~WVIntegrationErrorPolicy() = default;
    virtual std::size_t componentCount() const noexcept = 0;
    virtual std::size_t elementCount(std::size_t component) const noexcept = 0;
    virtual double absoluteTolerance(std::size_t component, std::size_t index) const noexcept = 0;
    virtual std::size_t persistentBytes() const noexcept = 0;
};

struct WVStateConstraintResult {
    WVKernelStatus status;
    std::size_t modifiedCoefficientCount = 0;
    bool fsalCompatible = true;

    explicit operator bool() const noexcept { return static_cast<bool>(status); }
};

// Internal portable model boundary. evaluateRightHandSide() must completely
// overwrite every element of the supplied right-hand-side storage, including
// elements whose mathematical tendency is zero when evaluation succeeds. On
// failure the right-hand-side storage is unspecified, but the immutable input
// state is unchanged. State constraints are applied separately so the
// numerical integrator contains no forcing-specific rules.
class WVIntegrationSystem {
public:
    virtual ~WVIntegrationSystem() = default;
    virtual WVShape2D stateShape() const noexcept = 0;
    virtual WVKernelStatus evaluateRightHandSide(const WVState& state, WVFlux& rightHandSide) = 0;
    virtual WVStateConstraintResult enforceStateConstraints(WVMutableCoefficients& coefficients) = 0;
    virtual WVKernelStatus createErrorPolicy(double absoluteToleranceScale, std::unique_ptr<WVIntegrationErrorPolicy>& policy) const {
        (void)absoluteToleranceScale;
        policy.reset();
        return {WVKernelStatusCode::unsupportedOperation,"This integration system does not provide adaptive error tolerances."};
    }
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
        std::size_t rejectedStepCount = 0;
        std::size_t rightHandSideEvaluationCount = 0;
        double stepSize = 0.0;
        double proposedStepSize = 0.0;
        double nextStepSize = 0.0;
        double normalizedError = 0.0;
    };

    double initialTime = 0.0;
    double finalTime = 0.0;
    WVState endpoint;
    MethodStatistics methodStatistics;
    const WVDenseOutput* denseOutput = nullptr;
};

// Internal numerical-method boundary. A successful step mutates only the
// accepted state; a failed step leaves the accepted state and time unchanged.
// Interpolated output is produced later from the returned accepted-step view
// and is never eligible to become the next integration state.
class WVTimeIntegrator {
public:
    virtual ~WVTimeIntegrator() = default;
    virtual WVKernelStatus prepareStateAfterRestart(WVMutableState& state) = 0;
    virtual WVKernelStatus step(WVMutableState& state, double stepSize) = 0;
    virtual WVKernelStatus advanceToTime(WVMutableState& state, double finalTime, double stepSize) = 0;
    virtual const WVAcceptedStep* lastAcceptedStep() const noexcept = 0;
    virtual double nextStepSize() const noexcept = 0;
    virtual std::size_t persistentBytes() const noexcept = 0;
};

// Ordered requested output times are owned independently of accepted solver
// steps. Future integration drivers query this contract only after a step has
// been accepted; a requested time therefore cannot truncate that step.
class WVOutputSchedule {
public:
    virtual ~WVOutputSchedule() = default;
    // reset() validates the complete request sequence against the integration
    // interval before any output event is emitted or accepted state is changed.
    virtual WVKernelStatus reset(double initialTime, double finalTime) = 0;
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
