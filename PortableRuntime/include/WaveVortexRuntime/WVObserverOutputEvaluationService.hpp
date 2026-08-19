#pragma once

#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"

#include <memory>

namespace wavevortex::runtime {

struct WVObserverOutputEvaluationMetrics {
  std::size_t preparedEventCount = 0;
  std::size_t fieldEvaluationCount = 0;
  std::size_t uniqueFieldOutputCount = 0;
  std::size_t sharedFieldReuseCount = 0;
  std::size_t borrowedCoefficientViewCount = 0;
  std::size_t outputCapacityBytes = 0;
  std::size_t retainedStorageBytes = 0;
  std::size_t routeAwareParticleEvaluationCount = 0;
  std::size_t skippedParticleEvaluationCount = 0;
  std::size_t batchRetainedStorageBytes = 0;
  std::size_t batchMaximumLiveBytes = 0;
  double evaluationSeconds = 0.0;
};

// Evaluates passive MATLAB-compatible observing systems independently of
// NetCDF. Coefficients remain borrowed views of the immutable event state;
// coincident Eulerian and mooring requests share one field-evaluation plan.
class WVObserverOutputEvaluationService final : public WVObserverSampleSource {
public:
  ~WVObserverOutputEvaluationService() override;
  static WVKernelStatus
  create(const WVTransformConstantStratificationConfiguration &configuration,
         bool isDynamicsLinear,
         const WVPortableObserverDescriptor &descriptor,
         std::unique_ptr<WVFFTEngine> engine,
         std::unique_ptr<WVObserverOutputEvaluationService> &service,
         WVFieldEvaluationService *borrowedFieldEvaluationService = nullptr);

  WVKernelStatus specifications(
      const WVObserverRecord &observer,
      std::vector<WVObserverOutputVariableSpecification> &output) override;
  WVKernelStatus observationSchema(
      const WVObserverRecord &observer,
      WVObservationSchema &output) override;
  WVKernelStatus initialObservationBatch(
      const WVObserverRecord &observer,
      WVObservationBatch &output) override;
  WVKernelStatus observationBatch(
      const WVObserverRecord &observer,
      WVObservationBatch &output) override;
  WVKernelStatus preflight(const WVOutputPlan &plan) override;
  WVKernelStatus useFieldEvaluationService(
      WVFieldEvaluationService &fieldEvaluationService);
  WVKernelStatus prepareInitial(const WVState &state) override;
  WVKernelStatus prepare(const WVOutputEvent &event) override;
  WVKernelStatus value(
      const WVObserverRecord &observer,
      const WVObserverOutputVariableSpecification &variable,
      WVObserverOutputValueView &output) override;

  const WVObserverOutputEvaluationMetrics &metrics() const noexcept {
    return metrics_;
  }
  std::size_t persistentBytes() const noexcept;

private:
  WVObserverOutputEvaluationService() = default;
  WVKernelStatus observationBatchForKind(
      const WVObserverRecord &observer, WVObservationBatchKind kind,
      WVObservationBatch &output);
  class Impl;
  std::unique_ptr<Impl> impl_;
  WVObserverOutputEvaluationMetrics metrics_;
};

} // namespace wavevortex::runtime
