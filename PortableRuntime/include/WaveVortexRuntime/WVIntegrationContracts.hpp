#pragma once

#include "WaveVortexRuntime/WVIntegrationState.hpp"

#include <cstddef>
#include <memory>

namespace wavevortex::runtime {

// Method-neutral absolute-error policy. Components are addressed by the
// integration layout's stable order: Ap, Am, A0, then each additional state
// block. Numerical methods never inspect observer identity.
class WVIntegrationErrorPolicy {
public:
  virtual ~WVIntegrationErrorPolicy() = default;
  virtual std::size_t componentCount() const noexcept = 0;
  virtual std::size_t elementCount(std::size_t component) const noexcept = 0;
  virtual double absoluteTolerance(std::size_t component,
                                   std::size_t index) const noexcept = 0;
  virtual std::size_t persistentBytes() const noexcept = 0;
};

struct WVStateConstraintResult {
  WVKernelStatus status;
  std::size_t modifiedCoefficientCount = 0;
  bool fsalCompatible = true;

  explicit operator bool() const noexcept { return static_cast<bool>(status); }
};

// Model boundary used by every numerical method. A successful RHS evaluation
// completely overwrites every coefficient and additional-state tendency.
class WVIntegrationSystem {
public:
  virtual ~WVIntegrationSystem() = default;
  virtual const WVIntegrationStateLayout &stateLayout() const noexcept = 0;
  virtual WVKernelStatus
  evaluateRightHandSide(const WVIntegrationState &state,
                        WVIntegrationFlux &rightHandSide) = 0;
  virtual WVStateConstraintResult
  enforceStateConstraints(WVMutableIntegrationState &state) = 0;
  virtual WVKernelStatus
  createErrorPolicy(double absoluteToleranceScale,
                    std::unique_ptr<WVIntegrationErrorPolicy> &policy) const = 0;
};

// Method-owned continuous extension over the most recent accepted interval.
class WVDenseOutput {
public:
  virtual ~WVDenseOutput() = default;
  virtual double initialTime() const noexcept = 0;
  virtual double finalTime() const noexcept = 0;
  virtual const WVIntegrationStateLayout &stateLayout() const noexcept = 0;
  virtual WVKernelStatus
  evaluateState(double time, WVMutableIntegrationState &output) const = 0;
};

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
  WVIntegrationState endpoint;
  MethodStatistics methodStatistics;
  // Valid only until the owning integrator advances or is prepared again.
  const WVDenseOutput *denseOutput = nullptr;
};

class WVTimeIntegrator {
public:
  virtual ~WVTimeIntegrator() = default;
  virtual const WVIntegrationStateLayout &stateLayout() const noexcept = 0;
  virtual WVKernelStatus
  prepareStateAfterRestart(WVMutableIntegrationState &state) = 0;
  virtual WVKernelStatus step(WVMutableIntegrationState &state,
                              double stepSize) = 0;
  virtual WVKernelStatus advanceToTime(WVMutableIntegrationState &state,
                                       double finalTime,
                                       double stepSize) = 0;
  virtual const WVAcceptedStep *lastAcceptedStep() const noexcept = 0;
  virtual double nextStepSize() const noexcept = 0;
  virtual std::size_t persistentBytes() const noexcept = 0;
};

} // namespace wavevortex::runtime
