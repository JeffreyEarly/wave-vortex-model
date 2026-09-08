#pragma once

#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexKernel/WVTransformHydrostaticKernel.hpp"

namespace wavevortex::runtime::detail {

// Named transform adapter behind the resolved WVFieldEvaluationService
// boundary. Plans retain only immutable interpolation metadata; the adapter
// owns one volume scratch field and never a full Hermitian spectrum.
class WVStratifiedFieldEvaluationAdapter final {
public:
  ~WVStratifiedFieldEvaluationAdapter();

  static WVKernelStatus create(
      std::shared_ptr<const WVStratifiedModalSource> source,
      std::unique_ptr<WVFFTEngine> engine,
      std::unique_ptr<WVStratifiedFieldEvaluationAdapter> &adapter);
  static WVKernelStatus createBorrowing(
      WVTransformStratifiedQGKernel &kernel,
      std::unique_ptr<WVStratifiedFieldEvaluationAdapter> &adapter);

  static WVKernelStatus createBorrowing(WVTransformHydrostaticKernel&,std::unique_ptr<WVStratifiedFieldEvaluationAdapter>&);

  WVKernelStatus createPlan(const std::vector<WVFieldRequest> &requests,
                            WVFieldEvaluationPlan &plan) const;
  WVKernelStatus evaluate(const WVFieldEvaluationPlan &plan,
                          const WVIntegrationState &state,
                          WVFieldOutputView *outputs,
                          std::size_t outputCount);
  WVKernelStatus createMovingPlan(
      const std::vector<WVMovingFieldRequest> &requests,
      WVMovingFieldEvaluationPlan &plan) const;
  WVKernelStatus evaluateMoving(const WVMovingFieldEvaluationPlan &plan,
                                const WVIntegrationState &state,
                                WVMovingPositionView positions,
                                WVFieldOutputView *outputs,
                                std::size_t outputCount);
  WVKernelStatus evaluateMovingFromAdvectionFields(
      const WVMovingFieldEvaluationPlan &plan,
      const WVIntegrationState &state,
      const WVRealFieldBundleConstView &advectionFields,
      WVMovingPositionView positions, WVFieldOutputView *outputs,
      std::size_t outputCount);
  WVKernelStatus createEventPlan(
      const std::vector<WVEventFieldRequest> &requests,
      WVEventFieldEvaluationPlan &plan);
  WVKernelStatus prepareEventGeometry(
      const WVEventFieldEvaluationPlan &plan,
      const WVEventPositionSetView *positionSets,
      std::size_t positionSetCount,
      WVPreparedFieldGeometry &geometry);
  WVKernelStatus evaluateEventBatch(
      const WVIntegrationState &state,
      const WVEventFieldEvaluationBatchEntry *entries,
      std::size_t entryCount);

  bool isCompatibleWith(const WVIntegrationStateLayout &layout) const noexcept;
  const WVStratifiedModalGeometry &configuration() const noexcept;
  const WVFieldEvaluationMetrics &metrics() const noexcept { return metrics_; }
  std::size_t persistentBytes() const noexcept;

private:
  WVKernelStatus transformField(const WVState&,WVHydrostaticField,WVRealVolumeView);
  WVKernelStatus scalarValue(const WVState&,unsigned,double&);
  struct MovingInterpolationWorkspace;
  WVKernelStatus evaluateMovingImpl(
      const WVMovingFieldEvaluationPlan &plan,
      const WVIntegrationState &state,
      const WVRealFieldBundleConstView *advectionFields,
      WVMovingPositionView positions, WVFieldOutputView *outputs,
      std::size_t outputCount);
  WVStratifiedFieldEvaluationAdapter() = default;
  std::unique_ptr<WVTransformStratifiedQGKernel> ownedKernel_;
  WVTransformStratifiedQGKernel *kernel_ = nullptr;
  std::unique_ptr<WVTransformHydrostaticKernel> ownedHydrostatic_;
  WVTransformHydrostaticKernel* hydrostaticKernel_=nullptr;
  std::vector<double> speedScratch_;
  std::vector<double> fieldScratch_;
  std::unique_ptr<MovingInterpolationWorkspace> movingInterpolation_;
  WVFieldEvaluationMetrics metrics_;
  bool executing_ = false;
};

} // namespace wavevortex::runtime::detail
