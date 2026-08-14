#pragma once

#include "WaveVortexRuntime/WVCompositeIntegration.hpp"
#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexRuntime/WVForcingEngine.hpp"

#include <memory>
#include <vector>

namespace wavevortex::runtime {

struct WVIntegratedObserverMetrics {
  std::size_t rightHandSideEvaluationCount = 0;
  std::size_t velocityFieldEvaluationCount = 0;
  std::size_t particleValueWriteCount = 0;
  std::size_t tracerEvaluationCount = 0;
  std::size_t tracerValueWriteCount = 0;
  std::size_t antialiasedTracerEvaluationCount = 0;
  std::size_t positionCapacityBytes = 0;
  std::size_t velocityCapacityBytes = 0;
  std::size_t persistentBytes = 0;
  std::size_t sharedRightHandSideContextCount = 0;
};

using WVLagrangianParticleMetrics = WVIntegratedObserverMetrics;

// Resolved MATLAB-compatible particle component. Accepted x and y state is
// deliberately unwrapped; periodicity is applied only while sampling fields.
class WVLagrangianParticles final {
public:
  const WVObserverRecord &record() const noexcept { return record_; }
  std::size_t particleCount() const noexcept { return particleCount_; }
  bool isXYOnly() const noexcept { return record_.isXYOnly; }
  std::size_t positionOffset() const noexcept { return positionOffset_; }

private:
  WVObserverRecord record_;
  std::size_t xBlock_ = 0;
  std::size_t yBlock_ = 0;
  std::size_t zBlock_ = 0;
  std::size_t particleCount_ = 0;
  std::size_t positionOffset_ = 0;
  std::size_t uOutput_ = 0;
  std::size_t vOutput_ = 0;
  std::size_t wOutput_ = 0;
  friend class WVConstantStratificationCompositeSystem;
};

// Resolved MATLAB-compatible three-dimensional tracer. Its numerical
// differentiation remains owned by the shared constant-stratification kernel.
class WVTracer final {
public:
  const WVObserverRecord &record() const noexcept { return record_; }
  std::size_t stateBlock() const noexcept { return stateBlock_; }
  bool shouldAntialias() const noexcept { return record_.shouldAntialias; }

private:
  WVObserverRecord record_;
  std::size_t stateBlock_ = 0;
  friend class WVConstantStratificationCompositeSystem;
};

// Constant-stratification composite numerical system. The canonical
// WaveVortex coefficient RHS is delegated to the frozen forcing engine while
// integrated observers consume one shared per-RHS evaluation context.
class WVConstantStratificationCompositeSystem final
    : public WVCompositeIntegrationSystem {
public:
  static WVKernelStatus create(
      const WVTransformConstantStratificationConfiguration &configuration,
      const WVFrozenForcingSchedule &schedule,
      const WVPortableObserverDescriptor &descriptor,
      std::unique_ptr<WVFFTEngine> engine,
      double coefficientAbsoluteToleranceScale,
      std::unique_ptr<WVConstantStratificationCompositeSystem> &system);

  ~WVConstantStratificationCompositeSystem() override;
  WVConstantStratificationCompositeSystem(
      const WVConstantStratificationCompositeSystem &) = delete;
  WVConstantStratificationCompositeSystem &operator=(
      const WVConstantStratificationCompositeSystem &) = delete;

  const WVCompositeStateLayout &stateLayout() const noexcept override {
    return layout_;
  }
  WVKernelStatus evaluateRightHandSide(const WVCompositeState &state,
                                       WVCompositeFlux &rightHandSide) override;
  WVStateConstraintResult
  enforceStateConstraints(WVMutableCompositeState &state) override;
  WVKernelStatus
  initializeParticleState(WVMutableCompositeState &state) const;
  double coefficientAbsoluteTolerance(
      std::size_t component, std::size_t index) const noexcept override;

  const std::vector<WVLagrangianParticles> &particles() const noexcept {
    return particles_;
  }
  const std::vector<WVTracer> &tracers() const noexcept { return tracers_; }
  WVFieldEvaluationService &fieldEvaluationService() noexcept {
    return *fields_;
  }
  const WVIntegratedObserverMetrics &metrics() const noexcept {
    return metrics_;
  }
  const WVKernelMetrics &kernelMetrics() const noexcept {
    return forcing_->kernel().metrics();
  }
  std::size_t persistentBytes() const noexcept;

private:
  WVConstantStratificationCompositeSystem() = default;
  WVCompositeStateLayout layout_;
  std::unique_ptr<WVConstantStratificationForcingEngine> forcing_;
  std::unique_ptr<WVIntegrationErrorPolicy> coefficientErrorPolicy_;
  std::unique_ptr<WVFieldEvaluationService> fields_;
  WVMovingFieldEvaluationPlan velocityPlan_;
  std::vector<WVLagrangianParticles> particles_;
  std::vector<WVTracer> tracers_;
  std::vector<double> x_;
  std::vector<double> y_;
  std::vector<double> z_;
  std::vector<std::vector<double>> velocityStorage_;
  std::vector<WVFieldOutputView> velocityViews_;
  WVIntegratedObserverMetrics metrics_;
  bool executing_ = false;
};

} // namespace wavevortex::runtime
