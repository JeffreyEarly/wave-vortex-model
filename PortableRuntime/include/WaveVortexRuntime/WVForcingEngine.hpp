#pragma once

#include "WaveVortexRuntime/WVIntegrationContracts.hpp"
#include "WaveVortexKernel/WVForcingSchedule.hpp"
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <memory>
#include <string>
#include <vector>

namespace wavevortex::runtime {

struct WVForcingEngineMetrics {
    std::size_t scheduleBytes = 0;
    std::size_t derivedOperatorBytes = 0;
    std::size_t workspaceCapacityBytes = 0;
    std::size_t workspaceHighWaterBytes = 0;
    std::size_t evaluationCount = 0;
    std::size_t restoredCoefficientCount = 0;
    std::size_t resolvedSpatialCount = 0;
    std::size_t resolvedSpectralCount = 0;
    std::size_t resolvedAmplitudeCount = 0;
    std::size_t accumulatorClearElementWrites = 0;
    std::size_t temporaryFluxClearElementWrites = 0;
    std::size_t kernelOutputInitializationElementWrites = 0;
    std::size_t temporaryAccumulationElementReads = 0;
    std::size_t temporaryAccumulationElementWrites = 0;
    std::size_t outputCopyElementReads = 0;
    std::size_t outputCopyElementWrites = 0;
    std::size_t stateConstraintElementWrites = 0;
    std::size_t workspaceLiveBytes = 0;
    std::size_t workspaceMaximumLiveBytes = 0;
};

// Evaluate a validated, immutable portable forcing schedule around the shared
// constant-stratification numerical kernel. Schedule construction resolves
// stage and priority order; evaluate() performs no forcing dispatch discovery.
class WVConstantStratificationForcingEngine final : public WVIntegrationSystem {
public:
    // Validate the frozen schedule without constructing transforms, plans, or
    // array-sized derived operators and workspaces.
    static WVKernelStatus validateSchedule(
        const WVTransformConstantStratificationConfiguration& configuration,
        const WVFrozenForcingSchedule& schedule,
        WVShape2D coefficientShape);

    static WVKernelStatus create(
        const WVTransformConstantStratificationConfiguration& configuration,
        const WVFrozenForcingSchedule& schedule,
        std::unique_ptr<WVFFTEngine> fftEngine,
        std::unique_ptr<WVConstantStratificationForcingEngine>& forcingEngine);

    ~WVConstantStratificationForcingEngine();
    WVConstantStratificationForcingEngine(const WVConstantStratificationForcingEngine&) = delete;
    WVConstantStratificationForcingEngine& operator=(const WVConstantStratificationForcingEngine&) = delete;

    WVKernelStatus nonlinearFlux(const WVState& state, WVFlux& flux);
    WVKernelStatus restoreForcingAmplitudes(WVMutableCoefficients& coefficients);
    WVShape2D stateShape() const noexcept override { return kernel_->descriptor().spectralShape(); }
    WVKernelStatus evaluateRightHandSide(const WVState& state, WVFlux& rightHandSide) override { return nonlinearFlux(state,rightHandSide); }
    WVKernelStatus enforceStateConstraints(WVMutableCoefficients& coefficients) override { return restoreForcingAmplitudes(coefficients); }

    const WVTransformConstantStratificationKernel& kernel() const noexcept { return *kernel_; }
    WVTransformConstantStratificationKernel& kernel() noexcept { return *kernel_; }
    const WVFrozenForcingSchedule& schedule() const noexcept { return schedule_; }
    const WVForcingEngineMetrics& metrics() const noexcept { return metrics_; }
    const std::string& scheduleIdentifier() const noexcept { return scheduleIdentifier_; }
    std::size_t persistentBytes() const noexcept;

private:
    struct DerivedForcing;
    WVConstantStratificationForcingEngine() = default;

    WVKernelStatus initialize(const WVFrozenForcingSchedule& schedule);
    WVKernelStatus ensurePhysicalFields(const WVState& state, WVRealFieldBundleConstView& fields);
    WVKernelStatus addQuadraticBottomFriction(const WVState& state, const DerivedForcing& forcing, WVFlux& flux);
    WVKernelStatus addAdaptiveDamping(const WVState& state, const DerivedForcing& forcing, WVFlux& flux);
    WVKernelStatus addPseudoTopographicGeneration(const WVState& state, const DerivedForcing& forcing, WVFlux& flux);
    void addBetaPlaneAdvection(const WVState& state, const DerivedForcing& forcing, WVFlux& flux) const;
    void clearEvaluationWorkspace() noexcept;

    std::unique_ptr<WVTransformConstantStratificationKernel> kernel_;
    WVFrozenForcingSchedule schedule_;
    std::vector<DerivedForcing> derivedForcing_;
    std::vector<double> physicalFields_;
    std::vector<double> forcingFields_;
    std::vector<WVComplex64> accumulatedFlux_;
    std::vector<WVComplex64> temporaryFlux_;
    WVForcingEngineMetrics metrics_;
    std::string scheduleIdentifier_;
    bool physicalFieldsValid_ = false;
    bool executing_ = false;
};

} // namespace wavevortex::runtime
