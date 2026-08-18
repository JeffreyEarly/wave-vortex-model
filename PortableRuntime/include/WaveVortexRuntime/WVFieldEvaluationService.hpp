#pragma once

#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"
#include "WaveVortexRuntime/WVObserverContracts.hpp"
#include "WaveVortexRuntime/generated/WVPortableVariableCatalog.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace wavevortex::runtime {

enum class WVFieldSamplingKind : std::uint8_t {
  fullGrid,
  fixedVerticalProfiles,
  positions
};

struct WVFieldSamplingRequest {
  WVFieldSamplingKind kind = WVFieldSamplingKind::fullGrid;
  // Fixed-profile indices use MATLAB's one-based grid-index convention.
  std::vector<std::size_t> xIndices;
  std::vector<std::size_t> yIndices;
  std::vector<double> x;
  std::vector<double> y;
  std::vector<double> z;
  WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
};

struct WVFieldRequest {
  std::string identifier;
  std::string fieldName;
  WVFieldSamplingRequest sampling;
};

struct WVFieldOutputSpecification {
  std::string identifier;
  std::string fieldName;
  WVFieldSamplingKind samplingKind = WVFieldSamplingKind::fullGrid;
  std::vector<std::size_t> dimensions;
  std::size_t elementCount = 0;
};

struct WVFieldOutputView {
  double *data = nullptr;
  std::size_t elementCount = 0;
};

// One field sampled from a caller-supplied moving-position array. Offsets and
// counts refer to the shared coordinate views passed to evaluateMoving().
struct WVMovingFieldRequest {
  std::string identifier;
  std::string fieldName;
  std::size_t positionOffset = 0;
  std::size_t positionCount = 0;
  WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
};

struct WVMovingPositionView {
  const double *x = nullptr;
  const double *y = nullptr;
  const double *z = nullptr;
  std::size_t positionCount = 0;
};

class WVMovingFieldEvaluationPlan final {
public:
  const std::vector<WVFieldOutputSpecification> &outputs() const noexcept {
    return outputs_;
  }
  std::size_t outputCount() const noexcept { return outputs_.size(); }
  std::size_t positionCount() const noexcept { return positionCount_; }
  std::size_t persistentBytes() const noexcept;

private:
  struct ResolvedRequest {
    std::size_t primitiveChannel = 0;
    std::size_t positionOffset = 0;
    std::size_t positionCount = 0;
    WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
    std::size_t outputIndex = 0;
  };
  WVTransformConstantStratificationConfiguration configuration_;
  std::vector<ResolvedRequest> requests_;
  std::vector<WVFieldOutputSpecification> outputs_;
  std::size_t positionCount_ = 0;
  friend class WVFieldEvaluationService;
};

class WVFieldEvaluationPlan final {
public:
  const std::vector<WVFieldOutputSpecification> &outputs() const noexcept {
    return outputs_;
  }
  std::size_t outputCount() const noexcept { return outputs_.size(); }
  std::size_t persistentBytes() const noexcept;

private:
  using Field = WVPortableVariable;
  using NativeRank = WVPortableNaturalRank;

  struct PositionWeights {
    bool outsideInterpolationDomain = false;
    std::array<std::size_t, 2> xLinearIndices{};
    std::array<std::size_t, 2> yLinearIndices{};
    std::array<std::size_t, 2> zLinearIndices{};
    std::array<double, 2> xLinearWeights{};
    std::array<double, 2> yLinearWeights{};
    std::array<double, 2> zLinearWeights{};
    std::vector<double> xSplineWeights;
    std::vector<double> ySplineWeights;
    std::vector<double> zSplineWeights;
    std::size_t persistentBytes() const noexcept;
  };

  struct ResolvedRequest {
    Field field = Field::u;
    NativeRank nativeRank = NativeRank::volume;
    WVFieldSamplingKind samplingKind = WVFieldSamplingKind::fullGrid;
    WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
    std::vector<std::size_t> profileXIndices;
    std::vector<std::size_t> profileYIndices;
    std::vector<PositionWeights> positionWeights;
    std::size_t outputIndex = 0;
    std::size_t persistentBytes() const noexcept;
  };

  WVTransformConstantStratificationConfiguration configuration_;
  std::vector<ResolvedRequest> requests_;
  std::vector<WVFieldOutputSpecification> outputs_;
  std::uint64_t requestedFieldMask_ = 0;
  std::uint64_t dependencyMask_ = 0;

  friend class WVFieldEvaluationService;
};

struct WVFieldEvaluationMetrics {
  std::size_t evaluationCount = 0;
  std::size_t coincidentBatchCount = 0;
  std::size_t lastPlanBytes = 0;
  std::size_t maximumPlanBytes = 0;
  std::size_t servicePersistentBytes = 0;
  std::size_t transformPersistentBytes = 0;
  std::size_t scratchCapacityBytes = 0;
  std::size_t scratchHighWaterBytes = 0;
  std::size_t movingInterpolationWorkspaceBytes = 0;
  std::size_t transformCount = 0;
  std::size_t fftExecutionCount = 0;
  std::size_t primitiveFieldEvaluationCount = 0;
  std::size_t primitiveFieldReuseCount = 0;
  std::size_t fullGridWriteCount = 0;
  std::size_t profileWriteCount = 0;
  std::size_t linearInterpolationCount = 0;
  std::size_t splineInterpolationCount = 0;
  std::size_t outputElementWriteCount = 0;
  std::size_t movingEvaluationCount = 0;
  std::size_t movingPositionCount = 0;
  std::size_t movingPrimitiveTransformCount = 0;
  std::size_t catalogBytes = portableVariableCatalogBytes();
};

class WVFieldEvaluationService final {
public:
  static WVKernelStatus
  create(const WVTransformConstantStratificationConfiguration &configuration,
         std::unique_ptr<WVFFTEngine> engine,
         std::unique_ptr<WVFieldEvaluationService> &service);
  static WVKernelStatus createBorrowing(
      WVTransformConstantStratificationKernel &transform,
      std::unique_ptr<WVFieldEvaluationService> &service);

  WVFieldEvaluationService(const WVFieldEvaluationService &) = delete;
  WVFieldEvaluationService &operator=(const WVFieldEvaluationService &) = delete;
  WVFieldEvaluationService(WVFieldEvaluationService &&) = delete;
  WVFieldEvaluationService &operator=(WVFieldEvaluationService &&) = delete;
  ~WVFieldEvaluationService();

  static std::vector<std::string> supportedFieldNames();
  WVKernelStatus createPlan(const std::vector<WVFieldRequest> &requests,
                            WVFieldEvaluationPlan &plan) const;
  WVKernelStatus evaluate(const WVFieldEvaluationPlan &plan,
                          const WVState &state, WVFieldOutputView *outputs,
                          std::size_t outputCount);
  WVKernelStatus
  createMovingPlan(const std::vector<WVMovingFieldRequest> &requests,
                   WVMovingFieldEvaluationPlan &plan) const;
  WVKernelStatus evaluateMoving(const WVMovingFieldEvaluationPlan &plan,
                                const WVState &state,
                                WVMovingPositionView positions,
                                WVFieldOutputView *outputs,
                                std::size_t outputCount);
  WVKernelStatus evaluateMovingFromAdvectionFields(
      const WVMovingFieldEvaluationPlan &plan, const WVState &state,
      const WVRealFieldBundleConstView &advectionFields,
      WVMovingPositionView positions, WVFieldOutputView *outputs,
      std::size_t outputCount);
  WVRealFieldBundleView advectionFieldStorage() noexcept;

  const WVTransformConstantStratificationConfiguration &
  configuration() const noexcept;
  const WVFieldEvaluationMetrics &metrics() const noexcept { return metrics_; }
  std::size_t persistentBytes() const noexcept;

private:
  WVFieldEvaluationService() = default;
  WVKernelStatus initializeScratch();
  WVKernelStatus evaluateMovingImpl(
      const WVMovingFieldEvaluationPlan &plan, const WVState &state,
      const WVRealFieldBundleConstView *advectionFields,
      WVMovingPositionView positions, WVFieldOutputView *outputs,
      std::size_t outputCount);
  class MovingWorkspace;
  std::unique_ptr<WVTransformConstantStratificationKernel> ownedTransform_;
  WVTransformConstantStratificationKernel *transform_ = nullptr;
  std::unique_ptr<MovingWorkspace> movingWorkspace_;
  std::vector<double> realScratch_;
  std::vector<WVComplex64> complexScratch_;
  WVFieldEvaluationMetrics metrics_;
  bool executing_ = false;
};

} // namespace wavevortex::runtime
