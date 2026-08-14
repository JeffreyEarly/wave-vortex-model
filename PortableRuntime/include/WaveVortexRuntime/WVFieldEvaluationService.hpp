#pragma once

#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"
#include "WaveVortexRuntime/WVObserverContracts.hpp"

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

class WVFieldEvaluationPlan final {
public:
  const std::vector<WVFieldOutputSpecification> &outputs() const noexcept {
    return outputs_;
  }
  std::size_t outputCount() const noexcept { return outputs_.size(); }
  std::size_t persistentBytes() const noexcept;

private:
  enum class Field : std::uint8_t {
    u,
    v,
    w,
    eta,
    pi,
    p,
    psi,
    qgpv,
    rhoE,
    rhoTotal,
    rhoBar,
    zetaX,
    zetaY,
    zetaZ,
    ssu,
    ssv,
    ssh,
    energy,
    uvMax,
    wMax,
    count
  };

  enum class NativeRank : std::uint8_t { scalar, vertical, horizontal, volume };

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
  std::size_t transformCount = 0;
  std::size_t fftExecutionCount = 0;
  std::size_t primitiveFieldEvaluationCount = 0;
  std::size_t primitiveFieldReuseCount = 0;
  std::size_t fullGridWriteCount = 0;
  std::size_t profileWriteCount = 0;
  std::size_t linearInterpolationCount = 0;
  std::size_t splineInterpolationCount = 0;
  std::size_t outputElementWriteCount = 0;
};

class WVFieldEvaluationService final {
public:
  static WVKernelStatus
  create(const WVTransformConstantStratificationConfiguration &configuration,
         std::unique_ptr<WVFFTEngine> engine,
         std::unique_ptr<WVFieldEvaluationService> &service);

  WVFieldEvaluationService(const WVFieldEvaluationService &) = delete;
  WVFieldEvaluationService &operator=(const WVFieldEvaluationService &) = delete;
  WVFieldEvaluationService(WVFieldEvaluationService &&) = delete;
  WVFieldEvaluationService &operator=(WVFieldEvaluationService &&) = delete;
  ~WVFieldEvaluationService() = default;

  static std::vector<std::string> supportedFieldNames();
  WVKernelStatus createPlan(const std::vector<WVFieldRequest> &requests,
                            WVFieldEvaluationPlan &plan) const;
  WVKernelStatus evaluate(const WVFieldEvaluationPlan &plan,
                          const WVState &state, WVFieldOutputView *outputs,
                          std::size_t outputCount);

  const WVTransformConstantStratificationConfiguration &
  configuration() const noexcept;
  const WVFieldEvaluationMetrics &metrics() const noexcept { return metrics_; }
  std::size_t persistentBytes() const noexcept;

private:
  WVFieldEvaluationService() = default;
  std::unique_ptr<WVTransformConstantStratificationKernel> transform_;
  std::vector<double> realScratch_;
  std::vector<WVComplex64> complexScratch_;
  WVFieldEvaluationMetrics metrics_;
  bool executing_ = false;
};

} // namespace wavevortex::runtime
