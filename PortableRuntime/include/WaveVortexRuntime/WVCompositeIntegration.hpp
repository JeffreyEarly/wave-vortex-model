#pragma once

#include "WaveVortexRuntime/WVCompositeState.hpp"
#include "WaveVortexRuntime/WVIntegrationContracts.hpp"

#include <cstddef>
#include <vector>

namespace wavevortex::runtime {

class WVCompositeIntegrationSystem {
public:
  virtual ~WVCompositeIntegrationSystem() = default;
  virtual const WVCompositeStateLayout &stateLayout() const noexcept = 0;
  virtual WVKernelStatus
  evaluateRightHandSide(const WVCompositeState &state,
                        WVCompositeFlux &rightHandSide) = 0;
  virtual WVStateConstraintResult
  enforceStateConstraints(WVMutableCompositeState &state) = 0;
  virtual double
  coefficientAbsoluteTolerance(std::size_t component,
                               std::size_t index) const noexcept = 0;
};

struct WVCompositeAcceptedStep {
  double initialTime = 0.0;
  double finalTime = 0.0;
  WVCompositeState endpoint;
  std::size_t rightHandSideEvaluationCount = 0;
  std::size_t rejectedStepCount = 0;
  double normalizedError = 0.0;
  double nextStepSize = 0.0;
};

struct WVCompositeIntegratorMetrics {
  std::size_t workspaceCapacityBytes = 0;
  std::size_t workspaceMaximumLiveBytes = 0;
  std::size_t rightHandSideEvaluationCount = 0;
  std::size_t acceptedStepCount = 0;
  std::size_t rejectedStepCount = 0;
  std::size_t denseOutputEvaluationCount = 0;
};

class WVCompositeFixedStepRK4 final {
public:
  explicit WVCompositeFixedStepRK4(WVCompositeIntegrationSystem &system,
                                   bool retainDenseOutput = false);
  WVKernelStatus prepareStateAfterRestart(WVMutableCompositeState &state);
  WVKernelStatus step(WVMutableCompositeState &state, double stepSize);
  WVKernelStatus advanceToTime(WVMutableCompositeState &state, double finalTime,
                               double stepSize);
  WVKernelStatus evaluateDenseOutput(double time,
                                     WVMutableCompositeState &output) const;
  const WVCompositeAcceptedStep *lastAcceptedStep() const noexcept {
    return hasAcceptedStep_ ? &acceptedStep_ : nullptr;
  }
  const WVCompositeIntegratorMetrics &metrics() const noexcept {
    return metrics_;
  }

private:
  class Workspace;
  WVKernelStatus ensureWorkspace(const WVMutableCompositeState &state);
  WVCompositeIntegrationSystem &system_;
  bool retainDenseOutput_ = false;
  Workspace *workspace_ = nullptr;
  WVCompositeAcceptedStep acceptedStep_;
  mutable WVCompositeIntegratorMetrics metrics_;
  bool hasAcceptedStep_ = false;
  bool stepping_ = false;

public:
  ~WVCompositeFixedStepRK4();
  WVCompositeFixedStepRK4(const WVCompositeFixedStepRK4 &) = delete;
  WVCompositeFixedStepRK4 &operator=(const WVCompositeFixedStepRK4 &) = delete;
};

struct WVCompositeAdaptiveRK23Options {
  double relativeTolerance = 1e-3;
  double absoluteToleranceScale = 1e-6;
  double safetyFactor = 0.9;
  double minimumStepFactor = 0.2;
  double maximumStepFactor = 5.0;
};

class WVCompositeAdaptiveRK23 final {
public:
  explicit WVCompositeAdaptiveRK23(WVCompositeIntegrationSystem &system,
                                   WVCompositeAdaptiveRK23Options options = {});
  WVKernelStatus prepareStateAfterRestart(WVMutableCompositeState &state);
  WVKernelStatus step(WVMutableCompositeState &state, double proposedStepSize);
  WVKernelStatus advanceToTime(WVMutableCompositeState &state, double finalTime,
                               double initialStepSize);
  WVKernelStatus evaluateDenseOutput(double time,
                                     WVMutableCompositeState &output) const;
  const WVCompositeAcceptedStep *lastAcceptedStep() const noexcept {
    return hasAcceptedStep_ ? &acceptedStep_ : nullptr;
  }
  const WVCompositeIntegratorMetrics &metrics() const noexcept {
    return metrics_;
  }
  double nextStepSize() const noexcept { return nextStepSize_; }

private:
  class Workspace;
  WVKernelStatus ensureWorkspace(const WVMutableCompositeState &state);
  WVCompositeIntegrationSystem &system_;
  WVCompositeAdaptiveRK23Options options_;
  Workspace *workspace_ = nullptr;
  WVCompositeAcceptedStep acceptedStep_;
  mutable WVCompositeIntegratorMetrics metrics_;
  double nextStepSize_ = 0.0;
  bool hasAcceptedStep_ = false;
  bool stepping_ = false;

public:
  ~WVCompositeAdaptiveRK23();
  WVCompositeAdaptiveRK23(const WVCompositeAdaptiveRK23 &) = delete;
  WVCompositeAdaptiveRK23 &operator=(const WVCompositeAdaptiveRK23 &) = delete;
};

} // namespace wavevortex::runtime
