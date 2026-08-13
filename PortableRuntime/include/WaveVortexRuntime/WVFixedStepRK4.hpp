#pragma once

#include "WaveVortexRuntime/WVIntegrationContracts.hpp"

#include <cstddef>
#include <vector>

namespace wavevortex::runtime {

struct WVFixedStepRK4Metrics {
    std::size_t workspaceCapacityBytes = 0;
    std::size_t stepCount = 0;
    std::size_t rightHandSideEvaluationCount = 0;
    double lastStepSize = 0.0;
    std::size_t stageStateConstructionElementReads = 0;
    std::size_t stageStateConstructionElementWrites = 0;
    std::size_t stageFluxClearElementWrites = 0;
    std::size_t weightedFluxClearElementWrites = 0;
    std::size_t weightedFluxInitializationElementReads = 0;
    std::size_t weightedFluxInitializationElementWrites = 0;
    std::size_t weightedAccumulationElementReads = 0;
    std::size_t weightedAccumulationElementWrites = 0;
    std::size_t finalStateUpdateElementReads = 0;
    std::size_t finalStateUpdateElementWrites = 0;
    std::size_t workspaceLiveBytes = 0;
    std::size_t workspaceMaximumLiveBytes = 0;
};

// Deterministic classical fixed-step RK4 for canonical [Nj,Nkl]
// WaveVortex coefficients. Integrator workspace is derived state and is never
// part of a checkpoint.
class WVFixedStepRK4 final : public WVTimeIntegrator {
public:
    explicit WVFixedStepRK4(WVIntegrationSystem& system);

    WVKernelStatus prepareStateAfterRestart(WVMutableState& state) override;
    WVKernelStatus step(WVMutableState& state, double deltaT) override;
    WVKernelStatus advanceToTime(WVMutableState& state, double finalTime, double deltaT) override;

    const WVFixedStepRK4Metrics& metrics() const noexcept { return metrics_; }
    const WVAcceptedStep* lastAcceptedStep() const noexcept override { return hasAcceptedStep_ ? &acceptedStep_ : nullptr; }
    std::size_t persistentBytes() const noexcept override { return metrics_.workspaceCapacityBytes; }

private:
    WVKernelStatus ensureWorkspace(const WVMutableState& state);
    WVKernelStatus evaluateAcceptedState(const WVMutableState& state);
    WVKernelStatus evaluateStage(const WVMutableState& base, double stageTime, double scale, const std::vector<WVComplex64>* increment);
    void setStageFromBase(const WVMutableState& base, double scale, const std::vector<WVComplex64>* increment);
    void accumulateWeightedFlux(double weight);

    WVIntegrationSystem& system_;
    WVShape2D shape_;
    std::vector<WVComplex64> stageState_;
    std::vector<WVComplex64> stageFlux_;
    std::vector<WVComplex64> weightedFlux_;
    WVFixedStepRK4Metrics metrics_;
    WVAcceptedStep acceptedStep_;
    bool hasAcceptedStep_ = false;
    bool acceptedStateConstrained_ = false;
    bool stepping_ = false;
};

} // namespace wavevortex::runtime
