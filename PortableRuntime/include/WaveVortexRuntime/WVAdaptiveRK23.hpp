#pragma once

#include "WaveVortexRuntime/WVIntegrationContracts.hpp"

#include <cstddef>
#include <memory>
#include <vector>

namespace wavevortex::runtime {

struct WVAdaptiveRK23Options {
    double relativeTolerance = 1e-3;
    double absoluteToleranceScale = 1e-6;
    double safetyFactor = 0.9;
    double minimumStepFactor = 0.2;
    double maximumStepFactor = 5.0;
};

// Representation-neutral step controller for an order-three accepted method
// with an order-two embedded local-error estimate.
class WVAdaptiveRK23Controller final {
public:
    explicit WVAdaptiveRK23Controller(WVAdaptiveRK23Options options = {});
    WVKernelStatus validate() const noexcept;
    double stepFactor(double normalizedError, bool accepted) const noexcept;
    const WVAdaptiveRK23Options& options() const noexcept { return options_; }

private:
    WVAdaptiveRK23Options options_;
};

struct WVAdaptiveRK23Metrics {
    std::size_t workspaceCapacityBytes = 0;
    std::size_t errorPolicyBytes = 0;
    std::size_t workspaceLiveBytes = 0;
    std::size_t workspaceMaximumLiveBytes = 0;
    std::size_t acceptedStepCount = 0;
    std::size_t rejectedStepCount = 0;
    std::size_t rightHandSideEvaluationCount = 0;
    std::size_t fsalReuseCount = 0;
    std::size_t fsalInvalidationCount = 0;
    std::size_t rejectedInitialDerivativeReuseCount = 0;
    std::size_t constraintModifiedCoefficientCount = 0;
    std::size_t denseOutputEvaluationCount = 0;
    std::size_t denseOutputElementReads = 0;
    std::size_t denseOutputElementWrites = 0;
    double denseOutputSeconds = 0.0;
    double lastNormalizedError = 0.0;
    double lastProposedStepSize = 0.0;
    double lastAcceptedStepSize = 0.0;
    double nextStepSize = 0.0;
};

// Adaptive Bogacki--Shampine RK3(2) for the current WaveVortex coefficient
// adapter. The tableau/controller and error policy contain no forcing or
// constant-stratification formulas; future composite state adapters may reuse
// them without changing the numerical method.
class WVAdaptiveRK23 final : public WVTimeIntegrator, private WVDenseOutput {
public:
    explicit WVAdaptiveRK23(WVIntegrationSystem& system, WVAdaptiveRK23Options options = {});

    WVKernelStatus prepareStateAfterRestart(WVMutableState& state) override;
    WVKernelStatus step(WVMutableState& state, double proposedStepSize) override;
    WVKernelStatus advanceToTime(WVMutableState& state, double finalTime, double initialStepSize) override;

    const WVAdaptiveRK23Metrics& metrics() const noexcept { return metrics_; }
    const WVAcceptedStep* lastAcceptedStep() const noexcept override { return hasAcceptedStep_ ? &acceptedStep_ : nullptr; }
    double nextStepSize() const noexcept override { return metrics_.nextStepSize; }
    std::size_t persistentBytes() const noexcept override { return metrics_.workspaceCapacityBytes+metrics_.errorPolicyBytes; }

private:
    double initialTime() const noexcept override;
    double finalTime() const noexcept override;
    WVShape2D stateShape() const noexcept override;
    WVKernelStatus evaluate(double time, WVMutableState& output) const override;

    WVKernelStatus ensureWorkspace(const WVMutableState& state);
    WVKernelStatus evaluateDerivative(const WVState& state, std::vector<WVComplex64>& destination);
    WVKernelStatus constructAndEvaluateStage(
        const WVMutableState& base,
        double stageTime,
        double stepSize,
        double weight1,
        const std::vector<WVComplex64>* derivative1,
        double weight2,
        const std::vector<WVComplex64>* derivative2,
        double weight3,
        const std::vector<WVComplex64>* derivative3,
        std::vector<WVComplex64>& destination,
        WVStateConstraintResult* constraintResult = nullptr);
    double normalizedError(const WVMutableState& initial, const WVMutableCoefficients& candidate, double stepSize) const noexcept;
    void invalidateAttempt() noexcept;

    WVIntegrationSystem& system_;
    WVAdaptiveRK23Controller controller_;
    WVShape2D shape_;
    std::unique_ptr<WVIntegrationErrorPolicy> errorPolicy_;
    std::vector<WVComplex64> stageState_;
    std::vector<WVComplex64> k1_;
    std::vector<WVComplex64> k2_;
    std::vector<WVComplex64> k3_;
    std::vector<WVComplex64> k4_;
    mutable WVAdaptiveRK23Metrics metrics_;
    WVAcceptedStep acceptedStep_;
    bool hasAcceptedStep_ = false;
    bool fsalAvailable_ = false;
    bool stepping_ = false;
    mutable bool evaluatingDenseOutput_ = false;
};

} // namespace wavevortex::runtime
