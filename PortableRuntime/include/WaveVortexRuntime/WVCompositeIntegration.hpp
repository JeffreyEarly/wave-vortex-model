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

// Method-owned continuous extension over one accepted composite-state
// interval. Implementations write into caller-owned reusable storage; output
// consumers receive only immutable WVCompositeState views of that storage.
class WVCompositeDenseOutput {
public:
  virtual ~WVCompositeDenseOutput() = default;
  virtual double initialTime() const noexcept = 0;
  virtual double finalTime() const noexcept = 0;
  virtual const WVCompositeStateLayout &stateLayout() const noexcept = 0;
  virtual WVKernelStatus
  evaluateState(double time, WVMutableCompositeState &output) const = 0;
};

struct WVCompositeAcceptedStep {
  double initialTime = 0.0;
  double finalTime = 0.0;
  WVCompositeState endpoint;
  std::size_t rightHandSideEvaluationCount = 0;
  std::size_t rejectedStepCount = 0;
  double normalizedError = 0.0;
  double nextStepSize = 0.0;
  // Valid only until the owning integrator is advanced or prepared again.
  // A null pointer means that this accepted step has no continuous extension.
  const WVCompositeDenseOutput *denseOutput = nullptr;
};

// Method-neutral numerical boundary for composite observing-system state.
// Successful steps mutate only the accepted state. Dense output is evaluated
// later through WVCompositeAcceptedStep and can never become accepted state.
class WVCompositeTimeIntegrator {
public:
  virtual ~WVCompositeTimeIntegrator() = default;
  virtual const WVCompositeStateLayout &stateLayout() const noexcept = 0;
  virtual WVKernelStatus
  prepareStateAfterRestart(WVMutableCompositeState &state) = 0;
  virtual WVKernelStatus step(WVMutableCompositeState &state,
                              double stepSize) = 0;
  virtual WVKernelStatus advanceToTime(WVMutableCompositeState &state,
                                       double finalTime,
                                       double stepSize) = 0;
  virtual const WVCompositeAcceptedStep *lastAcceptedStep() const noexcept = 0;
  virtual double nextStepSize() const noexcept = 0;
  virtual std::size_t persistentBytes() const noexcept = 0;
};

struct WVCompositeIntegratorMetrics {
  std::size_t workspaceCapacityBytes = 0;
  std::size_t workspaceMaximumLiveBytes = 0;
  std::size_t rightHandSideEvaluationCount = 0;
  std::size_t acceptedStepCount = 0;
  std::size_t rejectedStepCount = 0;
  std::size_t denseOutputEvaluationCount = 0;
};

class WVCompositeFixedStepRK4 final : public WVCompositeTimeIntegrator,
                                      public WVCompositeDenseOutput {
public:
  explicit WVCompositeFixedStepRK4(WVCompositeIntegrationSystem &system,
                                   bool retainDenseOutput = false);
  const WVCompositeStateLayout &stateLayout() const noexcept override {
    return system_.stateLayout();
  }
  WVKernelStatus
  prepareStateAfterRestart(WVMutableCompositeState &state) override;
  WVKernelStatus step(WVMutableCompositeState &state,
                      double stepSize) override;
  WVKernelStatus advanceToTime(WVMutableCompositeState &state, double finalTime,
                               double stepSize) override;
  WVKernelStatus evaluateDenseOutput(double time,
                                     WVMutableCompositeState &output) const;
  WVKernelStatus
  evaluateState(double time, WVMutableCompositeState &output) const override {
    return evaluateDenseOutput(time, output);
  }
  double initialTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.initialTime : 0.0;
  }
  double finalTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.finalTime : 0.0;
  }
  const WVCompositeAcceptedStep *lastAcceptedStep() const noexcept override {
    return hasAcceptedStep_ ? &acceptedStep_ : nullptr;
  }
  double nextStepSize() const noexcept override { return nextStepSize_; }
  std::size_t persistentBytes() const noexcept override {
    return metrics_.workspaceCapacityBytes;
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
  double nextStepSize_ = 0.0;
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

class WVCompositeAdaptiveRK23 final : public WVCompositeTimeIntegrator,
                                      public WVCompositeDenseOutput {
public:
  explicit WVCompositeAdaptiveRK23(WVCompositeIntegrationSystem &system,
                                   WVCompositeAdaptiveRK23Options options = {});
  const WVCompositeStateLayout &stateLayout() const noexcept override {
    return system_.stateLayout();
  }
  WVKernelStatus
  prepareStateAfterRestart(WVMutableCompositeState &state) override;
  WVKernelStatus step(WVMutableCompositeState &state,
                      double proposedStepSize) override;
  WVKernelStatus advanceToTime(WVMutableCompositeState &state, double finalTime,
                               double initialStepSize) override;
  WVKernelStatus evaluateDenseOutput(double time,
                                     WVMutableCompositeState &output) const;
  WVKernelStatus
  evaluateState(double time, WVMutableCompositeState &output) const override {
    return evaluateDenseOutput(time, output);
  }
  double initialTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.initialTime : 0.0;
  }
  double finalTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.finalTime : 0.0;
  }
  const WVCompositeAcceptedStep *lastAcceptedStep() const noexcept override {
    return hasAcceptedStep_ ? &acceptedStep_ : nullptr;
  }
  const WVCompositeIntegratorMetrics &metrics() const noexcept {
    return metrics_;
  }
  double nextStepSize() const noexcept override { return nextStepSize_; }
  std::size_t persistentBytes() const noexcept override {
    return metrics_.workspaceCapacityBytes;
  }

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
