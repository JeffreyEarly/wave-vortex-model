#pragma once

#include "WaveVortexRuntime/WVForcingEngine.hpp"

#include <cstddef>
#include <vector>

namespace wavevortex::runtime {

struct WVFixedStepRK4Metrics {
    std::size_t workspaceCapacityBytes = 0;
    std::size_t stepCount = 0;
    std::size_t rightHandSideEvaluationCount = 0;
    double lastStepSize = 0.0;
};

// Deterministic classical fixed-step RK4 for canonical [Nj,Nkl]
// WaveVortex coefficients. Integrator workspace is derived state and is never
// part of a checkpoint.
class WVFixedStepRK4 final {
public:
    explicit WVFixedStepRK4(WVConstantStratificationForcingEngine& forcingEngine);

    WVKernelStatus prepareStateAfterRestart(WVMutableState& state);
    WVKernelStatus step(WVMutableState& state, double deltaT);
    WVKernelStatus advanceToTime(WVMutableState& state, double finalTime, double deltaT);

    const WVFixedStepRK4Metrics& metrics() const noexcept { return metrics_; }
    std::size_t persistentBytes() const noexcept { return metrics_.workspaceCapacityBytes; }

private:
    WVKernelStatus ensureWorkspace(const WVMutableState& state);
    WVKernelStatus evaluateStage(const WVMutableState& base, double stageTime, double scale, const std::vector<WVComplex64>* increment);
    void setStageFromBase(const WVMutableState& base, double scale, const std::vector<WVComplex64>* increment);
    void accumulateWeightedFlux(double weight);

    WVConstantStratificationForcingEngine& forcingEngine_;
    WVShape2D shape_;
    std::vector<WVComplex64> stageState_;
    std::vector<WVComplex64> stageFlux_;
    std::vector<WVComplex64> weightedFlux_;
    WVFixedStepRK4Metrics metrics_;
    bool stepping_ = false;
};

} // namespace wavevortex::runtime
