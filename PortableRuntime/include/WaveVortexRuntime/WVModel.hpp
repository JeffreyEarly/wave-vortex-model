#pragma once

#include "WaveVortexRuntime/WVConstantStratificationIntegrationSystem.hpp"
#include "WaveVortexRuntime/WVModelOutputConfiguration.hpp"
#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace wavevortex::runtime {

namespace detail {
class WVModelInternalAccess;
}

enum class WVModelIntegratorKind : std::uint8_t {
  fixedRK4,
  adaptiveRK23,
  adaptiveRK45
};

struct WVModelIntegratorConfiguration {
  WVModelIntegratorKind kind = WVModelIntegratorKind::fixedRK4;
  WVFixedStepRK4Options fixed;
  WVAdaptiveRK23Options adaptive;
  WVAdaptiveRK45Options adaptiveRK45;
};

struct WVModelMetrics {
  std::size_t modelPersistentBytes = 0;
  std::size_t catalogPersistentBytes = 0;
  std::size_t statePersistentBytes = 0;
  std::size_t integrationSystemPersistentBytes = 0;
  std::size_t integratorPersistentBytes = 0;
  std::size_t outputPersistentBytes = 0;
  std::size_t outputConfigurationPersistentBytes = 0;
  std::size_t outputEvaluationPersistentBytes = 0;
  std::size_t outputSinkPersistentBytes = 0;
  WVKernelMetrics kernel;
  WVForcingEngineMetrics forcing;
  WVIntegratedObserverMetrics integratedObservers;
  WVIntegratorMetrics integrator;
  WVOutputDriverMetrics outputDriver;
  WVObserverOutputEvaluationMetrics outputEvaluation;
  WVModelOutputNetCDFMetrics output;
};

struct WVModelOutputDestination {
  std::string fileIdentifier;
  std::string path;
};

struct WVModelOutputRequest {
  WVModelOutputPolicy policy = WVModelOutputPolicy::append;
  std::vector<WVModelOutputDestination> destinations;
  double finalTime = 0.0;
};

// Explicit dynamic state for one WVModel. Canonical coefficients and
// observer-owned state remain separate from immutable model services.
class WVModelState final {
public:
  WVModelState() = default;
  WVModelState(WVModelState &&) noexcept = default;
  WVModelState &operator=(WVModelState &&) noexcept = default;
  WVModelState(const WVModelState &) = delete;
  WVModelState &operator=(const WVModelState &) = delete;

  static WVKernelStatus create(
      WVCheckpoint checkpoint, const WVIntegrationStateLayout &layout,
      WVModelState &state,
      const WVAdditionalStateStorage *restoredAdditionalState = nullptr);

  WVMutableIntegrationState mutableView() noexcept;
  WVIntegrationState constView();
  const WVCheckpoint &checkpoint() const noexcept { return checkpoint_; }
  WVCheckpoint &checkpoint() noexcept { return checkpoint_; }
  std::size_t persistentBytes() const noexcept;

private:
  WVCheckpoint checkpoint_;
  WVAdditionalStateStorage additionalState_;
  std::vector<WVAdditionalStateBlockConstView> constViews_;
};

// Stable source-level façade over the numerical, forcing, integration,
// observer, output, and persistence services.
class WVModel final {
public:
  WVModel();
  ~WVModel();
  WVModel(WVModel &&) noexcept;
  WVModel &operator=(WVModel &&) noexcept;
  WVModel(const WVModel &) = delete;
  WVModel &operator=(const WVModel &) = delete;

  static WVKernelStatus create(
      std::shared_ptr<const WVExtensionCatalog> catalog,
      const WVTransformConstantStratificationConfiguration &configuration,
      const WVFrozenForcingSchedule &forcingSchedule,
      std::unique_ptr<WVFFTEngine> engine,
      const WVModelIntegratorConfiguration &integratorConfiguration,
      WVModel &model);

  // Inspect a complete sibling NetCDF file set, select its latest complete
  // state, reconstruct the authoritative forcing/observer/output graph, and
  // optionally remap destinations by stable output-file identifier.
  static WVKernelStatus createFromModelOutputFiles(
      std::shared_ptr<const WVExtensionCatalog> catalog,
      const std::vector<std::string> &paths,
      const WVModelOutputRequest &outputRequest,
      std::unique_ptr<WVFFTEngine> engine,
      const WVModelIntegratorConfiguration &integratorConfiguration,
      WVModel &model, WVModelState &state);

  // Consume an already inspected graph so callers that perform an explicit
  // preflight do not repeat NetCDF inspection or retain its state twice.
  static WVKernelStatus createFromModelOutputInspection(
      std::shared_ptr<const WVExtensionCatalog> catalog,
      WVModelOutputNetCDFInspection inspection,
      const WVModelOutputRequest &outputRequest,
      std::unique_ptr<WVFFTEngine> engine,
      const WVModelIntegratorConfiguration &integratorConfiguration,
      WVModel &model, WVModelState &state);

  // Validate and compile destination policy before provider construction or
  // runtime-state allocation. The returned configuration owns the sole
  // immutable output graph used by createFromModelOutputInspection().
  static WVKernelStatus prepareModelOutput(
      std::shared_ptr<const WVExtensionCatalog> catalog,
      const WVModelOutputNetCDFInspection &inspection,
      const WVModelOutputRequest &outputRequest,
      WVModelOutputConfiguration &configuration);

  // Consume a configuration produced by prepareModelOutput(). This overload
  // prevents request-mode callers from retaining or rebuilding a second
  // observer/output graph after preflight.
  static WVKernelStatus createFromModelOutputInspection(
      std::shared_ptr<const WVExtensionCatalog> catalog,
      WVModelOutputNetCDFInspection inspection,
      WVModelOutputConfiguration outputConfiguration,
      std::unique_ptr<WVFFTEngine> engine,
      const WVModelIntegratorConfiguration &integratorConfiguration,
      WVModel &model, WVModelState &state);

  static WVKernelStatus create(
      std::shared_ptr<const WVExtensionCatalog> catalog,
      const WVTransformConstantStratificationConfiguration &configuration,
      const WVFrozenForcingSchedule &forcingSchedule,
      const WVPortableObserverDescriptor &observerDescriptor,
      std::unique_ptr<WVFFTEngine> engine,
      const WVModelIntegratorConfiguration &integratorConfiguration,
      WVModel &model);

  WVKernelStatus prepareStateAfterRestart(WVModelState &state);
  WVKernelStatus evaluateRightHandSide(const WVIntegrationState &state,
                                       WVIntegrationFlux &rightHandSide);
  WVKernelStatus step(WVModelState &state, double proposedStepSize);
  WVKernelStatus advanceToTime(WVModelState &state, double finalTime,
                               double initialStepSize);
  WVKernelStatus advanceToTime(WVModelState &state, double finalTime,
                               double initialStepSize,
                               const WVOutputPlan &plan, WVOutputSink &sink);
  WVCheckpointStatus closeOutput() noexcept;
  bool hasOutput() const noexcept;

  const WVIntegrationStateLayout &stateLayout() const noexcept;
  double nextStepSize() const noexcept;
  WVModelIntegratorKind integratorKind() const noexcept;
  const std::string &forcingScheduleIdentifier() const noexcept;
  WVModelMetrics metrics(const WVModelState *state = nullptr) const noexcept;

private:
  friend class detail::WVModelInternalAccess;
  class Impl;
  std::unique_ptr<Impl> impl_;
};

WVFrozenForcingSchedule defaultNonlinearAdvectionSchedule();

} // namespace wavevortex::runtime
