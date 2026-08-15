#pragma once

#include "WaveVortexRuntime/WVIntegrationContracts.hpp"

#include <cstddef>
#include <memory>
#include <vector>

namespace wavevortex::runtime {

struct WVIntegratorMetrics {
  std::size_t workspaceCapacityBytes = 0;
  std::size_t workspaceMaximumLiveBytes = 0;
  std::size_t rightHandSideEvaluationCount = 0;
  std::size_t acceptedStepCount = 0;
  std::size_t rejectedStepCount = 0;
  std::size_t denseOutputEvaluationCount = 0;
  std::size_t errorPolicyBytes = 0;
  std::size_t denseHistoryCapacityBytes = 0;
  double lastStepSize = 0.0;
  double lastProposedStepSize = 0.0;
  double lastAcceptedStepSize = 0.0;
  double normalizedError = 0.0;
  double nextStepSize = 0.0;
  std::size_t stepCount = 0;
  std::size_t fsalReuseCount = 0;
  std::size_t fsalInvalidationCount = 0;
  std::size_t rejectedInitialDerivativeReuseCount = 0;
  std::size_t constraintModifiedCoefficientCount = 0;
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
  std::size_t acceptedStateCommitElementReads = 0;
  std::size_t acceptedStateCommitElementWrites = 0;
  std::size_t workspaceLiveBytes = 0;
  std::size_t denseOutputElementReads = 0;
  std::size_t denseOutputElementWrites = 0;
  double denseOutputSeconds = 0.0;
};

using WVFixedStepRK4Metrics = WVIntegratorMetrics;
using WVAdaptiveRK23Metrics = WVIntegratorMetrics;

struct WVFixedStepRK4Options {
  bool retainDenseOutput = false;
};

class WVFixedStepRK4 final : public WVTimeIntegrator,
                                      public WVDenseOutput {
public:
  explicit WVFixedStepRK4(WVIntegrationSystem &system,
                          WVFixedStepRK4Options options = {});
  const WVIntegrationStateLayout &stateLayout() const noexcept override {
    return system_.stateLayout();
  }
  WVKernelStatus
  prepareStateAfterRestart(WVMutableIntegrationState &state) override;
  WVKernelStatus step(WVMutableIntegrationState &state,
                      double stepSize) override;
  WVKernelStatus advanceToTime(WVMutableIntegrationState &state, double finalTime,
                               double stepSize) override;
  WVKernelStatus evaluateDenseOutput(double time,
                                     WVMutableIntegrationState &output) const;
  WVKernelStatus
  evaluateState(double time, WVMutableIntegrationState &output) const override {
    return evaluateDenseOutput(time, output);
  }
  double initialTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.initialTime : 0.0;
  }
  double finalTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.finalTime : 0.0;
  }
  const WVAcceptedStep *lastAcceptedStep() const noexcept override {
    return hasAcceptedStep_ ? &acceptedStep_ : nullptr;
  }
  double nextStepSize() const noexcept override { return nextStepSize_; }
  std::size_t persistentBytes() const noexcept override {
    return metrics_.workspaceCapacityBytes;
  }
  const WVIntegratorMetrics &metrics() const noexcept {
    return metrics_;
  }

private:
  class Workspace;
  WVKernelStatus ensureWorkspace(const WVMutableIntegrationState &state);
  WVIntegrationSystem &system_;
  WVFixedStepRK4Options options_;
  Workspace *workspace_ = nullptr;
  WVAcceptedStep acceptedStep_;
  mutable WVIntegratorMetrics metrics_;
  double nextStepSize_ = 0.0;
  bool hasAcceptedStep_ = false;
  bool acceptedStateConstrained_ = false;
  bool stepping_ = false;
  mutable bool evaluatingDenseOutput_ = false;

public:
  ~WVFixedStepRK4();
  WVFixedStepRK4(const WVFixedStepRK4 &) = delete;
  WVFixedStepRK4 &operator=(const WVFixedStepRK4 &) = delete;
};

struct WVAdaptiveRK23Options {
  double relativeTolerance = 1e-3;
  double absoluteToleranceScale = 1e-6;
  double safetyFactor = 0.9;
  double minimumStepFactor = 0.2;
  double maximumStepFactor = 5.0;
};

class WVAdaptiveRK23 final : public WVTimeIntegrator,
                                      public WVDenseOutput {
public:
  explicit WVAdaptiveRK23(WVIntegrationSystem &system,
                          WVAdaptiveRK23Options options = {});
  const WVIntegrationStateLayout &stateLayout() const noexcept override {
    return system_.stateLayout();
  }
  WVKernelStatus
  prepareStateAfterRestart(WVMutableIntegrationState &state) override;
  WVKernelStatus step(WVMutableIntegrationState &state,
                      double proposedStepSize) override;
  WVKernelStatus advanceToTime(WVMutableIntegrationState &state, double finalTime,
                               double initialStepSize) override;
  WVKernelStatus evaluateDenseOutput(double time,
                                     WVMutableIntegrationState &output) const;
  WVKernelStatus
  evaluateState(double time, WVMutableIntegrationState &output) const override {
    return evaluateDenseOutput(time, output);
  }
  double initialTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.initialTime : 0.0;
  }
  double finalTime() const noexcept override {
    return hasAcceptedStep_ ? acceptedStep_.finalTime : 0.0;
  }
  const WVAcceptedStep *lastAcceptedStep() const noexcept override {
    return hasAcceptedStep_ ? &acceptedStep_ : nullptr;
  }
  const WVIntegratorMetrics &metrics() const noexcept {
    return metrics_;
  }
  double nextStepSize() const noexcept override { return nextStepSize_; }
  std::size_t persistentBytes() const noexcept override {
    return metrics_.workspaceCapacityBytes;
  }

private:
  class Workspace;
  WVKernelStatus ensureWorkspace(const WVMutableIntegrationState &state);
  WVIntegrationSystem &system_;
  WVAdaptiveRK23Options options_;
  std::unique_ptr<WVIntegrationErrorPolicy> errorPolicy_;
  Workspace *workspace_ = nullptr;
  WVAcceptedStep acceptedStep_;
  mutable WVIntegratorMetrics metrics_;
  double nextStepSize_ = 0.0;
  bool hasAcceptedStep_ = false;
  bool fsalAvailable_ = false;
  bool stepping_ = false;
  mutable bool evaluatingDenseOutput_ = false;

public:
  ~WVAdaptiveRK23();
  WVAdaptiveRK23(const WVAdaptiveRK23 &) = delete;
  WVAdaptiveRK23 &operator=(const WVAdaptiveRK23 &) = delete;
};

} // namespace wavevortex::runtime
