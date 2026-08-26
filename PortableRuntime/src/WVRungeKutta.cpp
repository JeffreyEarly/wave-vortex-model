#include "WaveVortexRuntime/WVRungeKutta.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>
#include <new>
#include <string>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVComplex64 scaledSum(WVComplex64 value, WVComplex64 increment,
                      double scale) noexcept {
  return {value.real + scale * increment.real,
          value.imag + scale * increment.imag};
}

double timeTolerance(double first, double second) noexcept {
  return 8.0 * std::numeric_limits<double>::epsilon() *
         std::max({1.0, std::abs(first), std::abs(second)});
}

std::uint64_t hashTolerance(std::uint64_t hash, double value) noexcept {
  std::uint64_t bits = 0;
  static_assert(sizeof(bits) == sizeof(value));
  std::memcpy(&bits, &value, sizeof(bits));
  // Discard inconsequential low mantissa noise so independently evaluated
  // MATLAB and C++ tolerance formulas have one reproducible audit identity.
  // Clearing 20 bits retains approximately 32 bits of significand precision;
  // the production-size formula audit differs by at most 6.3e-16 relatively.
  bits = (bits + UINT64_C(0x80000)) & ~UINT64_C(0xfffff);
  hash ^= bits;
  return hash * UINT64_C(1099511628211);
}

class IntegrationBuffer {
public:
  WVKernelStatus initialize(const WVIntegrationStateLayout &layout) {
    try {
      layout_ = &layout;
      coefficientCount_ = layout.coefficientShape().elementCount();
      complex_.assign(3 * coefficientCount_ + layout.complexElementCount(),
                      WVComplex64{});
      real_.assign(layout.realElementCount(), 0.0);
      mutableBlocks_.clear();
      constBlocks_.clear();
      mutableBlocks_.reserve(layout.additionalBlocks().size());
      constBlocks_.reserve(layout.additionalBlocks().size());
      for (const auto &block : layout.additionalBlocks()) {
        auto *real = block.scalarType == WVStateScalarType::real64
                         ? real_.data() + block.scalarOffset
                         : nullptr;
        auto *complex =
            block.scalarType == WVStateScalarType::complex64
                ? complex_.data() + 3 * coefficientCount_ + block.scalarOffset
                : nullptr;
        mutableBlocks_.push_back({&block, real, complex});
        constBlocks_.push_back({&block, real, complex});
      }
      return WVKernelStatus::ok();
    } catch (const std::bad_alloc &) {
      return {WVKernelStatusCode::allocationFailure,
              "Integration workspace allocation failed."};
    }
  }

  WVMutableIntegrationState mutableState(double t, double t0) noexcept {
    const auto shape = layout_->coefficientShape();
    return {{t,
             t0,
             {{complex_.data(), shape},
              {complex_.data() + coefficientCount_, shape},
              {complex_.data() + 2 * coefficientCount_, shape}}},
            mutableBlocks_.data(),
            mutableBlocks_.size()};
  }
  WVIntegrationState state(double t, double t0) const noexcept {
    const auto shape = layout_->coefficientShape();
    return {{t,
             t0,
             {{complex_.data(), shape},
              {complex_.data() + coefficientCount_, shape},
              {complex_.data() + 2 * coefficientCount_, shape}}},
            constBlocks_.data(),
            constBlocks_.size()};
  }
  WVIntegrationFlux flux() noexcept {
    const auto shape = layout_->coefficientShape();
    return {{{complex_.data(), shape},
             {complex_.data() + coefficientCount_, shape},
             {complex_.data() + 2 * coefficientCount_, shape}},
            mutableBlocks_.data(),
            mutableBlocks_.size()};
  }
  void copyFrom(const WVIntegrationState &source) noexcept {
    const WVComplexConstView coefficients[] = {
        source.waveVortex.coefficients.Ap, source.waveVortex.coefficients.Am,
        source.waveVortex.coefficients.A0};
    for (std::size_t component = 0; component < 3; ++component)
      std::copy_n(coefficients[component].data, coefficientCount_,
                  complex_.data() + component * coefficientCount_);
    for (std::size_t block = 0; block < source.additionalBlockCount; ++block) {
      const auto &layout = *source.additionalBlocks[block].layout;
      if (layout.scalarType == WVStateScalarType::real64)
        std::copy_n(source.additionalBlocks[block].realData,
                    layout.elementCount, real_.data() + layout.scalarOffset);
      else
        std::copy_n(
            source.additionalBlocks[block].complexData, layout.elementCount,
            complex_.data() + 3 * coefficientCount_ + layout.scalarOffset);
    }
  }
  void copyTo(WVMutableIntegrationState &destination) const noexcept {
    WVComplexView coefficients[] = {destination.waveVortex.coefficients.Ap,
                                    destination.waveVortex.coefficients.Am,
                                    destination.waveVortex.coefficients.A0};
    for (std::size_t component = 0; component < 3; ++component)
      std::copy_n(complex_.data() + component * coefficientCount_,
                  coefficientCount_, coefficients[component].data);
    for (std::size_t block = 0; block < destination.additionalBlockCount;
         ++block) {
      const auto &layout = *destination.additionalBlocks[block].layout;
      if (layout.scalarType == WVStateScalarType::real64)
        std::copy_n(real_.data() + layout.scalarOffset, layout.elementCount,
                    destination.additionalBlocks[block].realData);
      else
        std::copy_n(complex_.data() + 3 * coefficientCount_ +
                        layout.scalarOffset,
                    layout.elementCount,
                    destination.additionalBlocks[block].complexData);
    }
  }
  void assign(const IntegrationBuffer &source) noexcept {
    complex_ = source.complex_;
    real_ = source.real_;
  }
  void setAffine(const WVIntegrationState &base, const IntegrationBuffer &increment,
                 double scale) noexcept {
    const WVComplexConstView coefficients[] = {
        base.waveVortex.coefficients.Ap, base.waveVortex.coefficients.Am,
        base.waveVortex.coefficients.A0};
    for (std::size_t component = 0; component < 3; ++component)
      for (std::size_t index = 0; index < coefficientCount_; ++index) {
        const auto flatIndex = component * coefficientCount_ + index;
        complex_[flatIndex] =
            scaledSum(coefficients[component].data[index],
                      increment.complex_[flatIndex], scale);
      }
    for (std::size_t block = 0; block < base.additionalBlockCount; ++block) {
      const auto &layout = *base.additionalBlocks[block].layout;
      if (layout.scalarType == WVStateScalarType::real64) {
        for (std::size_t index = 0; index < layout.elementCount; ++index) {
          const auto flatIndex = layout.scalarOffset + index;
          real_[flatIndex] = base.additionalBlocks[block].realData[index] +
                             scale * increment.real_[flatIndex];
        }
      } else {
        for (std::size_t index = 0; index < layout.elementCount; ++index) {
          const auto flatIndex =
              3 * coefficientCount_ + layout.scalarOffset + index;
          complex_[flatIndex] =
              scaledSum(base.additionalBlocks[block].complexData[index],
                        increment.complex_[flatIndex], scale);
        }
      }
    }
  }
  void addScaled(const IntegrationBuffer &source, double scale) noexcept {
    for (std::size_t i = 0; i < complex_.size(); ++i)
      complex_[i] = scaledSum(complex_[i], source.complex_[i], scale);
    for (std::size_t i = 0; i < real_.size(); ++i)
      real_[i] += scale * source.real_[i];
  }
  void setWeightedCandidate(const WVIntegrationState &base, double h,
                            const IntegrationBuffer &k1, double w1,
                            const IntegrationBuffer &k2, double w2,
                            const IntegrationBuffer &k3, double w3) noexcept {
    copyFrom(base);
    addScaled(k1, h * w1);
    addScaled(k2, h * w2);
    addScaled(k3, h * w3);
  }
  std::size_t capacityBytes() const noexcept {
    return complex_.capacity() * sizeof(WVComplex64) +
           real_.capacity() * sizeof(double) +
           mutableBlocks_.capacity() * sizeof(WVAdditionalStateBlockView) +
           constBlocks_.capacity() * sizeof(WVAdditionalStateBlockConstView);
  }
  std::size_t valueCapacityBytes() const noexcept {
    return complex_.capacity() * sizeof(WVComplex64) +
           real_.capacity() * sizeof(double);
  }
  const std::vector<WVComplex64> &complex() const noexcept { return complex_; }
  const std::vector<double> &real() const noexcept { return real_; }
  std::vector<WVComplex64> &complex() noexcept { return complex_; }
  std::vector<double> &real() noexcept { return real_; }
  std::size_t coefficientCount() const noexcept { return coefficientCount_; }

private:
  const WVIntegrationStateLayout *layout_ = nullptr;
  std::size_t coefficientCount_ = 0;
  std::vector<WVComplex64> complex_;
  std::vector<double> real_;
  std::vector<WVAdditionalStateBlockView> mutableBlocks_;
  std::vector<WVAdditionalStateBlockConstView> constBlocks_;
};

WVKernelStatus constrain(WVIntegrationSystem &system,
                         IntegrationBuffer &buffer, double t, double t0) {
  auto state = buffer.mutableState(t, t0);
  return system.enforceStateConstraints(state).status;
}

WVKernelStatus evaluate(WVIntegrationSystem &system,
                        const IntegrationBuffer &state, double t, double t0,
                        IntegrationBuffer &derivative,
                        WVIntegratorMetrics &metrics) {
  auto flux = derivative.flux();
  const auto status = system.evaluateRightHandSide(state.state(t, t0), flux);
  if (status)
    ++metrics.rightHandSideEvaluationCount;
  return status;
}

void makeExternalViews(const WVMutableIntegrationState &state,
                       std::vector<WVAdditionalStateBlockConstView> &views) {
  views.clear();
  views.reserve(state.additionalBlockCount);
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index)
    views.push_back({state.additionalBlocks[index].layout,
                     state.additionalBlocks[index].realData,
                     state.additionalBlocks[index].complexData});
}

double complexAbsoluteTolerance(const WVIntegrationErrorPolicy &policy,
                                const WVIntegrationStateLayout &layout,
                                const IntegrationBuffer &buffer,
                                std::size_t flatIndex) noexcept {
  const auto coefficientValues = 3 * buffer.coefficientCount();
  if (flatIndex < coefficientValues)
    return policy.absoluteTolerance(flatIndex / buffer.coefficientCount(),
                                    flatIndex % buffer.coefficientCount());
  const auto additionalIndex = flatIndex - coefficientValues;
  std::size_t blockIndex = 0;
  for (const auto &block : layout.additionalBlocks()) {
    if (block.scalarType == WVStateScalarType::complex64 &&
        additionalIndex >= block.scalarOffset &&
        additionalIndex < block.scalarOffset + block.elementCount)
      return policy.absoluteTolerance(3 + blockIndex,
                                      additionalIndex - block.scalarOffset);
    ++blockIndex;
  }
  return 1.0;
}

// Shared adaptive machinery is intentionally compile-time composed with each
// concrete method. Method workspaces supply explicit stage formulas and error
// increments; this driver supplies the method-neutral tolerance, controller,
// retry bookkeeping, and interval behavior without storing state-sized data.
class AdaptiveRungeKuttaDriver {
public:
  template <typename Options>
  static WVKernelStatus validateOptions(const Options &options,
                                        const char *methodName) {
    if (!(options.relativeTolerance > 0.0) ||
        !(options.absoluteToleranceScale > 0.0) ||
        !(options.safetyFactor > 0.0 && options.safetyFactor <= 1.0) ||
        !(options.rejectionFloorFactor > 0.0 &&
          options.rejectionFloorFactor < 1.0) ||
        !(options.maximumStepFactor >= 1.0) ||
        !(options.maximumStepSize > 0.0))
      return {WVKernelStatusCode::invalidConfiguration,
              std::string(methodName) +
                  " integration tolerances and controller limits must be positive."};
    return WVKernelStatus::ok();
  }

  template <typename Options>
  static WVKernelStatus initializeErrorPolicy(
      WVIntegrationSystem &system, const Options &options,
      std::unique_ptr<WVIntegrationErrorPolicy> &errorPolicy,
      std::uint64_t &toleranceHash,
      std::vector<std::uint64_t> &toleranceComponentHashes) {
    auto status = system.createErrorPolicy(options.absoluteToleranceScale,
                                           errorPolicy);
    if (!status)
      return status;
    const auto &layout = system.stateLayout();
    if (!errorPolicy ||
        errorPolicy->componentCount() != 3 + layout.additionalBlocks().size())
      return {WVKernelStatusCode::invalidConfiguration,
              "Adaptive error policy does not match the integration layout."};
    const auto coefficientCount = layout.coefficientShape().elementCount();
    for (std::size_t component = 0; component < 3; ++component)
      if (errorPolicy->elementCount(component) != coefficientCount)
        return {WVKernelStatusCode::invalidShape,
                "Adaptive coefficient tolerance shape does not match the integration layout."};
    for (std::size_t block = 0; block < layout.additionalBlocks().size();
         ++block)
      if (errorPolicy->elementCount(3 + block) !=
          layout.additionalBlocks()[block].elementCount)
        return {WVKernelStatusCode::invalidShape,
                "Adaptive state-block tolerance shape does not match the integration layout."};
    toleranceHash = UINT64_C(1469598103934665603);
    toleranceComponentHashes.assign(errorPolicy->componentCount(),
                                    UINT64_C(1469598103934665603));
    for (std::size_t component = 0;
         component < errorPolicy->componentCount(); ++component)
      for (std::size_t index = 0; index < errorPolicy->elementCount(component);
           ++index) {
        const auto tolerance = errorPolicy->absoluteTolerance(component, index);
        toleranceHash = hashTolerance(toleranceHash, tolerance);
        toleranceComponentHashes[component] =
            hashTolerance(toleranceComponentHashes[component], tolerance);
      }
    return WVKernelStatus::ok();
  }

  template <typename ComplexError, typename RealError>
  static double normalizedError(
      const WVIntegrationErrorPolicy &errorPolicy,
      const WVIntegrationStateLayout &layout,
      const IntegrationBuffer &candidate, const WVIntegrationState &initial,
      double relativeTolerance, ComplexError complexError,
      RealError realError) noexcept {
    double error = 0.0;
    const auto coefficientValues = 3 * candidate.coefficientCount();
    const auto &complexCandidate = candidate.complex();
    for (std::size_t i = 0; i < complexCandidate.size(); ++i) {
      const auto increment = complexError(i);
      const auto absTol =
          complexAbsoluteTolerance(errorPolicy, layout, candidate, i);
      WVComplex64 initialValue{};
      if (i < coefficientValues) {
        const WVComplexConstView coefficients[] = {
            initial.waveVortex.coefficients.Ap,
            initial.waveVortex.coefficients.Am,
            initial.waveVortex.coefficients.A0};
        initialValue = coefficients[i / candidate.coefficientCount()]
                           .data[i % candidate.coefficientCount()];
      } else {
        const auto additionalIndex = i - coefficientValues;
        for (std::size_t block = 0; block < layout.additionalBlocks().size();
             ++block) {
          const auto &metadata = layout.additionalBlocks()[block];
          if (metadata.scalarType == WVStateScalarType::complex64 &&
              additionalIndex >= metadata.scalarOffset &&
              additionalIndex <
                  metadata.scalarOffset + metadata.elementCount) {
            initialValue = initial.additionalBlocks[block].complexData
                [additionalIndex - metadata.scalarOffset];
            break;
          }
        }
      }
      const auto valueScale = std::max(
          absTol, relativeTolerance *
                      std::max(std::hypot(initialValue.real, initialValue.imag),
                               std::hypot(complexCandidate[i].real,
                                          complexCandidate[i].imag)));
      const auto ratio =
          std::hypot(increment.real, increment.imag) / valueScale;
      if (!std::isfinite(ratio))
        return std::numeric_limits<double>::infinity();
      error = std::max(error, ratio);
    }
    const auto &realCandidate = candidate.real();
    std::size_t realOffset = 0;
    std::size_t blockIndex = 0;
    for (const auto &block : layout.additionalBlocks()) {
      if (block.scalarType != WVStateScalarType::real64) {
        ++blockIndex;
        continue;
      }
      for (std::size_t j = 0; j < block.elementCount; ++j) {
        const auto i = realOffset + j;
        const auto scale = std::max(
            errorPolicy.absoluteTolerance(3 + blockIndex, j),
            relativeTolerance *
                std::max(std::abs(initial.additionalBlocks[blockIndex]
                                      .realData[j]),
                         std::abs(realCandidate[i])));
        const auto ratio = std::abs(realError(i)) / scale;
        if (!std::isfinite(ratio))
          return std::numeric_limits<double>::infinity();
        error = std::max(error, ratio);
      }
      realOffset += block.elementCount;
      ++blockIndex;
    }
    return error;
  }

  static double controllerFactor(double error, std::size_t rejectedAttemptCount,
                                 double errorExponent, double safetyFactor,
                                 double rejectionFloorFactor,
                                 double repeatedRejectionFactor,
                                 double maximumStepFactor) noexcept {
    if (std::isfinite(error) && error <= 1.0) {
      if (rejectedAttemptCount != 0)
        return 1.0;
      const auto temp = 1.25 * std::pow(error, errorExponent);
      return temp > 0.2 ? 1.0 / temp : maximumStepFactor;
    }
    if (rejectedAttemptCount == 0)
      return std::max(rejectionFloorFactor,
                      safetyFactor * std::pow(error, -errorExponent));
    return repeatedRejectionFactor;
  }

  template <typename Diagnostic, typename EnsureWorkspace>
  static WVKernelStatus prepareStateAfterRestart(
      WVIntegrationSystem &system, WVMutableIntegrationState &state,
      bool &hasAcceptedStep, bool &fsalAvailable, double &nextStepSize,
      std::vector<Diagnostic> &diagnostics, WVIntegratorMetrics &metrics,
      EnsureWorkspace ensureWorkspace) {
    hasAcceptedStep = false;
    fsalAvailable = false;
    nextStepSize = 0.0;
    diagnostics.clear();
    metrics.diagnosticCapacityBytes =
        diagnostics.capacity() * sizeof(Diagnostic);
    auto status = ensureWorkspace();
    if (!status)
      return status;
    const auto result = system.enforceStateConstraints(state);
    metrics.constraintModifiedCoefficientCount += result.modifiedCoefficientCount;
    return result.status;
  }

  static void recordRejectedAttempt(WVIntegratorMetrics &metrics,
                                    std::size_t &rejectedAttemptCount,
                                    double nextStepSize,
                                    double &stepSize) noexcept {
    ++rejectedAttemptCount;
    ++metrics.rejectedStepCount;
    ++metrics.rejectedInitialDerivativeReuseCount;
    stepSize = nextStepSize;
  }

  template <typename Step, typename NextStepSize>
  static WVKernelStatus advanceToTime(WVMutableIntegrationState &state,
                                      double finalTime, double stepSize,
                                      bool stretchFinalStep,
                                      const char *methodName, Step step,
                                      NextStepSize nextStepSize) {
    if (finalTime < state.waveVortex.t || !std::isfinite(finalTime))
      return {WVKernelStatusCode::invalidConfiguration,
              std::string(methodName) +
                  " cannot advance backward or to a nonfinite time."};
    while (state.waveVortex.t < finalTime) {
      const auto remaining = finalTime - state.waveVortex.t;
      if (remaining <= timeTolerance(state.waveVortex.t, finalTime)) {
        state.waveVortex.t = finalTime;
        break;
      }
      const auto use = stretchFinalStep && 1.1 * stepSize >= remaining
                           ? remaining
                           : std::min(stepSize, remaining);
      const auto status = step(use);
      if (!status)
        return status;
      stepSize = nextStepSize();
    }
    state.waveVortex.t = finalTime;
    return WVKernelStatus::ok();
  }
};

} // namespace

class WVFixedStepRK4::Workspace {
public:
  IntegrationBuffer stage, derivative, weighted, initialDerivative;
  std::vector<WVAdditionalStateBlockConstView> acceptedViews;
  std::size_t capacityBytes() const noexcept {
    return stage.capacityBytes() + derivative.capacityBytes() +
           weighted.capacityBytes() + initialDerivative.capacityBytes();
  }
};

WVFixedStepRK4::WVFixedStepRK4(
    WVIntegrationSystem &system, WVFixedStepRK4Options options)
    : system_(system), options_(options) {}
WVFixedStepRK4::~WVFixedStepRK4() { delete workspace_; }

std::size_t WVFixedStepRK4::persistentBytes() const noexcept {
  return sizeof(*this) +
         (workspace_ == nullptr
              ? 0
              : sizeof(Workspace) + workspace_->capacityBytes() +
                    workspace_->acceptedViews.capacity() *
                        sizeof(WVAdditionalStateBlockConstView));
}

WVKernelStatus
WVFixedStepRK4::ensureWorkspace(const WVMutableIntegrationState &state) {
  auto status = validateMutableIntegrationState(system_.stateLayout(), state);
  if (!status)
    return status;
  if (workspace_ != nullptr)
    return WVKernelStatus::ok();
  try {
    workspace_ = new Workspace;
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "RK4 workspace allocation failed."};
  }
  IntegrationBuffer *buffers[] = {&workspace_->stage, &workspace_->derivative,
                                &workspace_->weighted};
  for (auto *buffer : buffers) {
    status = buffer->initialize(system_.stateLayout());
    if (!status) {
      delete workspace_;
      workspace_ = nullptr;
      return status;
    }
  }
  if (options_.retainDenseOutput) {
    status = workspace_->initialDerivative.initialize(system_.stateLayout());
    if (!status) {
      delete workspace_;
      workspace_ = nullptr;
      return status;
    }
  }
  metrics_.workspaceCapacityBytes = workspace_->capacityBytes();
  metrics_.workspaceMaximumLiveBytes = metrics_.workspaceCapacityBytes;
  metrics_.denseHistoryCapacityBytes = options_.retainDenseOutput
                                           ? workspace_->initialDerivative.capacityBytes()
                                           : 0;
  metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
  return WVKernelStatus::ok();
}

WVKernelStatus WVFixedStepRK4::prepareStateAfterRestart(
    WVMutableIntegrationState &state) {
  hasAcceptedStep_ = false;
  acceptedStateConstrained_ = false;
  nextStepSize_ = 0.0;
  auto status = ensureWorkspace(state);
  if (!status)
    return status;
  const auto result = system_.enforceStateConstraints(state);
  acceptedStateConstrained_ = static_cast<bool>(result);
  metrics_.constraintModifiedCoefficientCount += result.modifiedCoefficientCount;
  return result.status;
}

WVKernelStatus WVFixedStepRK4::step(WVMutableIntegrationState &state,
                                             double h) {
  if (stepping_)
    return {WVKernelStatusCode::reentrantExecution,
            "RK4 stepping is not reentrant."};
  if (!(h > 0.0) || !std::isfinite(h))
    return {WVKernelStatusCode::invalidConfiguration,
            "RK4 step size must be finite and positive."};
  auto status = ensureWorkspace(state);
  if (!status)
    return status;
  stepping_ = true;
  struct Guard {
    bool &value;
    ~Guard() { value = false; }
  } guard{stepping_};
  hasAcceptedStep_ = false;
  std::vector<WVAdditionalStateBlockConstView> stateViews;
  const auto baseView = integrationConstView(state, stateViews);
  const double initialTime = state.waveVortex.t;
  if (acceptedStateConstrained_) {
    auto derivative = workspace_->derivative.flux();
    status = system_.evaluateRightHandSide(baseView, derivative);
  }
  else {
    workspace_->stage.copyFrom(baseView);
    auto initial = workspace_->stage.mutableState(initialTime, state.waveVortex.t0);
    const auto constraint = system_.enforceStateConstraints(initial);
    metrics_.constraintModifiedCoefficientCount += constraint.modifiedCoefficientCount;
    if (!constraint)
      return constraint.status;
    auto derivative = workspace_->derivative.flux();
    status = system_.evaluateRightHandSide(
        workspace_->stage.state(initialTime, state.waveVortex.t0), derivative);
  }
  if (!status)
    return status;
  ++metrics_.rightHandSideEvaluationCount;
  workspace_->weighted.assign(workspace_->derivative);
  metrics_.weightedFluxInitializationElementReads +=
      workspace_->derivative.complex().size();
  metrics_.weightedFluxInitializationElementWrites +=
      workspace_->weighted.complex().size();
  if (options_.retainDenseOutput)
    workspace_->initialDerivative.assign(workspace_->derivative);
  workspace_->stage.setAffine(baseView, workspace_->derivative, 0.5 * h);
  metrics_.stageStateConstructionElementReads +=
      2 * workspace_->stage.complex().size();
  metrics_.stageStateConstructionElementWrites += workspace_->stage.complex().size();
  status = constrain(system_, workspace_->stage, initialTime + 0.5 * h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  status = evaluate(system_, workspace_->stage, initialTime + 0.5 * h,
                    state.waveVortex.t0, workspace_->derivative, metrics_);
  if (!status)
    return status;
  workspace_->weighted.addScaled(workspace_->derivative, 2.0);
  metrics_.weightedAccumulationElementReads +=
      2 * workspace_->derivative.complex().size();
  metrics_.weightedAccumulationElementWrites +=
      workspace_->weighted.complex().size();
  workspace_->stage.setAffine(baseView, workspace_->derivative, 0.5 * h);
  metrics_.stageStateConstructionElementReads +=
      2 * workspace_->stage.complex().size();
  metrics_.stageStateConstructionElementWrites += workspace_->stage.complex().size();
  status = constrain(system_, workspace_->stage, initialTime + 0.5 * h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  status = evaluate(system_, workspace_->stage, initialTime + 0.5 * h,
                    state.waveVortex.t0, workspace_->derivative, metrics_);
  if (!status)
    return status;
  workspace_->weighted.addScaled(workspace_->derivative, 2.0);
  metrics_.weightedAccumulationElementReads +=
      2 * workspace_->derivative.complex().size();
  metrics_.weightedAccumulationElementWrites +=
      workspace_->weighted.complex().size();
  workspace_->stage.setAffine(baseView, workspace_->derivative, h);
  metrics_.stageStateConstructionElementReads +=
      2 * workspace_->stage.complex().size();
  metrics_.stageStateConstructionElementWrites += workspace_->stage.complex().size();
  status = constrain(system_, workspace_->stage, initialTime + h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  status = evaluate(system_, workspace_->stage, initialTime + h,
                    state.waveVortex.t0, workspace_->derivative, metrics_);
  if (!status)
    return status;
  workspace_->weighted.addScaled(workspace_->derivative, 1.0);
  metrics_.weightedAccumulationElementReads +=
      2 * workspace_->derivative.complex().size();
  metrics_.weightedAccumulationElementWrites +=
      workspace_->weighted.complex().size();
  workspace_->stage.setAffine(baseView, workspace_->weighted, h / 6.0);
  metrics_.finalStateUpdateElementReads +=
      2 * workspace_->weighted.complex().size();
  metrics_.finalStateUpdateElementWrites += workspace_->stage.complex().size();
  status = constrain(system_, workspace_->stage, initialTime + h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  if (options_.retainDenseOutput)
    workspace_->weighted.copyFrom(baseView);
  workspace_->stage.copyTo(state);
  metrics_.acceptedStateCommitElementReads += workspace_->stage.complex().size();
  metrics_.acceptedStateCommitElementWrites += workspace_->stage.complex().size();
  state.waveVortex.t = initialTime + h;
  acceptedStateConstrained_ = true;
  makeExternalViews(state, workspace_->acceptedViews);
  acceptedStep_ = {
      initialTime,
      state.waveVortex.t,
      {state.waveVortex.view(), workspace_->acceptedViews.data(),
       workspace_->acceptedViews.size()},
      {metrics_.acceptedStepCount + 1, 0, 4U,
       h, h, h, 0.0},
      options_.retainDenseOutput ? this : nullptr};
  nextStepSize_ = h;
  metrics_.lastStepSize = h;
  metrics_.nextStepSize = h;
  ++metrics_.acceptedStepCount;
  ++metrics_.stepCount;
  hasAcceptedStep_ = true;
  return WVKernelStatus::ok();
}

WVKernelStatus
WVFixedStepRK4::advanceToTime(WVMutableIntegrationState &state,
                                       double finalTime, double h) {
  if (finalTime < state.waveVortex.t || !std::isfinite(finalTime))
    return {WVKernelStatusCode::invalidConfiguration,
            "RK4 cannot advance backward or to a nonfinite time."};
  while (state.waveVortex.t < finalTime) {
    const auto stepSize = std::min(h, finalTime - state.waveVortex.t);
    if (!(stepSize > 0.0))
      break;
    const auto status = step(state, stepSize);
    if (!status)
      return status;
  }
  state.waveVortex.t = finalTime;
  return WVKernelStatus::ok();
}

WVKernelStatus WVFixedStepRK4::evaluateDenseOutput(
    double time, WVMutableIntegrationState &output) const {
  if (!options_.retainDenseOutput || !hasAcceptedStep_)
    return {WVKernelStatusCode::unsupportedOperation,
            "RK4 dense output is unavailable."};
  if (evaluatingDenseOutput_)
    return {WVKernelStatusCode::reentrantExecution,
            "RK4 dense-output evaluation is not reentrant."};
  auto status = validateMutableIntegrationState(system_.stateLayout(), output);
  if (!status)
    return status;
  const auto tolerance =
      timeTolerance(acceptedStep_.initialTime, acceptedStep_.finalTime);
  if (time < acceptedStep_.initialTime - tolerance ||
      time > acceptedStep_.finalTime + tolerance)
    return {WVKernelStatusCode::invalidConfiguration,
            "Dense-output time is outside the accepted interval."};
  evaluatingDenseOutput_ = true;
  struct Guard {
    bool &value;
    ~Guard() { value = false; }
  } guard{evaluatingDenseOutput_};
  const double h = acceptedStep_.finalTime - acceptedStep_.initialTime;
  double theta = h == 0.0 ? 0.0 : (time - acceptedStep_.initialTime) / h;
  theta = std::max(0.0, std::min(1.0, theta));
  const double theta2 = theta * theta, theta3 = theta2 * theta,
               ew = 3 * theta2 - 2 * theta3, iw = 1 - ew,
               isw = h * (theta - 2 * theta2 + theta3),
               esw = h * (theta3 - theta2);
  const auto started = std::chrono::steady_clock::now();
  workspace_->stage.copyFrom(acceptedStep_.endpoint);
  auto &c = workspace_->stage.complex();
  for (std::size_t i = 0; i < c.size(); ++i) {
    const auto a = workspace_->weighted.complex()[i], b = c[i],
               k1 = workspace_->initialDerivative.complex()[i],
               k4 = workspace_->derivative.complex()[i];
    c[i] = {iw * a.real + ew * b.real + isw * k1.real + esw * k4.real,
            iw * a.imag + ew * b.imag + isw * k1.imag + esw * k4.imag};
  }
  auto &r = workspace_->stage.real();
  for (std::size_t i = 0; i < r.size(); ++i) {
    const auto a = workspace_->weighted.real()[i], b = r[i];
    r[i] = iw * a + ew * b + isw * workspace_->initialDerivative.real()[i] +
           esw * workspace_->derivative.real()[i];
  }
  auto mutableStage = workspace_->stage.mutableState(
      time, acceptedStep_.endpoint.waveVortex.t0);
  status = system_.enforceStateConstraints(mutableStage).status;
  if (!status)
    return status;
  workspace_->stage.copyTo(output);
  output.waveVortex.t = time;
  output.waveVortex.t0 = acceptedStep_.endpoint.waveVortex.t0;
  ++metrics_.denseOutputEvaluationCount;
  metrics_.denseOutputElementReads += 4 * c.size();
  metrics_.denseOutputElementWrites += c.size();
  metrics_.denseOutputSeconds +=
      std::chrono::duration<double>(std::chrono::steady_clock::now() - started)
          .count();
  return WVKernelStatus::ok();
}

class WVAdaptiveRK23::Workspace {
public:
  IntegrationBuffer stage, k1, k2, k3, k4;
  std::vector<WVAdditionalStateBlockConstView> baseViews;
  std::vector<WVAdditionalStateBlockConstView> acceptedViews;
  std::size_t capacityBytes() const noexcept {
    return stage.capacityBytes() + k1.capacityBytes() + k2.capacityBytes() +
           k3.capacityBytes() + k4.capacityBytes();
  }
  std::size_t viewCapacityBytes() const noexcept {
    return (baseViews.capacity() + acceptedViews.capacity()) *
           sizeof(WVAdditionalStateBlockConstView);
  }
};

WVAdaptiveRK23::WVAdaptiveRK23(
    WVIntegrationSystem &system,
    WVAdaptiveRK23Options options)
    : system_(system), options_(options) {}
WVAdaptiveRK23::~WVAdaptiveRK23() { delete workspace_; }

std::size_t WVAdaptiveRK23::persistentBytes() const noexcept {
  return sizeof(*this) +
         (workspace_ == nullptr
              ? 0
              : sizeof(Workspace) + workspace_->capacityBytes() +
                    workspace_->viewCapacityBytes()) +
         (errorPolicy_ == nullptr ? 0 : errorPolicy_->persistentBytes()) +
         stepDiagnostics_.capacity() * sizeof(WVAdaptiveRK23StepDiagnostic) +
         toleranceComponentHashes_.capacity() * sizeof(std::uint64_t);
}

WVKernelStatus
WVAdaptiveRK23::ensureWorkspace(const WVMutableIntegrationState &state) {
  auto status = validateMutableIntegrationState(system_.stateLayout(), state);
  if (!status)
    return status;
  status = AdaptiveRungeKuttaDriver::validateOptions(options_, "RK23");
  if (!status)
    return status;
  if (workspace_)
    return WVKernelStatus::ok();
  status = AdaptiveRungeKuttaDriver::initializeErrorPolicy(
      system_, options_, errorPolicy_, toleranceHash_,
      toleranceComponentHashes_);
  if (!status)
    return status;
  try {
    workspace_ = new Workspace;
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "RK23 workspace allocation failed."};
  }
  IntegrationBuffer *buffers[] = {&workspace_->stage, &workspace_->k1,
                                &workspace_->k2,    &workspace_->k3,
                                &workspace_->k4};
  for (auto *b : buffers) {
    status = b->initialize(system_.stateLayout());
    if (!status) {
      delete workspace_;
      workspace_ = nullptr;
      return status;
    }
  }
  try {
    workspace_->baseViews.reserve(
        system_.stateLayout().additionalBlocks().size());
    workspace_->acceptedViews.reserve(
        system_.stateLayout().additionalBlocks().size());
  } catch (const std::bad_alloc &) {
    delete workspace_;
    workspace_ = nullptr;
    return {WVKernelStatusCode::allocationFailure,
            "RK23 state-view workspace allocation failed."};
  }
  metrics_.workspaceCapacityBytes =
      workspace_->capacityBytes() + workspace_->viewCapacityBytes();
  metrics_.workspaceMaximumLiveBytes = metrics_.workspaceCapacityBytes;
  metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
  metrics_.stateCapacityBytes = workspace_->stage.valueCapacityBytes();
  metrics_.workspaceStateEquivalentCount = 5;
  metrics_.denseHistoryCapacityBytes =
      options_.retainDenseOutput
          ? workspace_->k1.valueCapacityBytes() +
                workspace_->k2.valueCapacityBytes() +
                workspace_->k3.valueCapacityBytes() +
                workspace_->k4.valueCapacityBytes()
          : 0;
  metrics_.denseHistoryStateEquivalentCount =
      options_.retainDenseOutput ? 4 : 0;
  metrics_.errorPolicyBytes = errorPolicy_->persistentBytes();
  return WVKernelStatus::ok();
}

WVKernelStatus WVAdaptiveRK23::prepareStateAfterRestart(
    WVMutableIntegrationState &state) {
  return AdaptiveRungeKuttaDriver::prepareStateAfterRestart(
      system_, state, hasAcceptedStep_, fsalAvailable_, nextStepSize_,
      stepDiagnostics_, metrics_, [&]() { return ensureWorkspace(state); });
}

WVKernelStatus WVAdaptiveRK23::step(WVMutableIntegrationState &state,
                                    double proposedStepSize) {
  if (stepping_)
    return {WVKernelStatusCode::reentrantExecution,
            "RK23 stepping is not reentrant."};
  if (!(proposedStepSize > 0.0) || !std::isfinite(proposedStepSize))
    return {WVKernelStatusCode::invalidConfiguration,
            "RK23 step size must be finite and positive."};
  auto status = ensureWorkspace(state);
  if (!status)
    return status;
  stepping_ = true;
  struct Guard {
    bool &v;
    ~Guard() { v = false; }
  } guard{stepping_};
  hasAcceptedStep_ = false;
  const auto baseView = integrationConstView(state, workspace_->baseViews);
  const auto t = state.waveVortex.t, t0 = state.waveVortex.t0;
  double h = std::min(proposedStepSize, options_.maximumStepSize);
  bool initialDerivativeAvailable = false;
  bool reusedFSALDerivative = false;
  if (fsalAvailable_) {
    std::swap(workspace_->k1, workspace_->k4);
    initialDerivativeAvailable = true;
    reusedFSALDerivative = true;
    fsalAvailable_ = false;
    ++metrics_.fsalReuseCount;
  }
  std::size_t rejectedThisStep = 0;
  std::size_t evaluationsThisStep = 0;
  for (;;) {
    if (!std::isfinite(h) || !(t + h > t)) {
      fsalAvailable_ = false;
      return {WVKernelStatusCode::numericalFailure,
              "RK23 cannot advance time with the proposed step."};
    }
    if (!initialDerivativeAvailable) {
      const auto before = metrics_.rightHandSideEvaluationCount;
      auto derivative = workspace_->k1.flux();
      status = system_.evaluateRightHandSide(baseView, derivative);
      if (status)
        ++metrics_.rightHandSideEvaluationCount;
      evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
      if (!status) {
        fsalAvailable_ = false;
        return status;
      }
      initialDerivativeAvailable = true;
    }
    workspace_->stage.setAffine(baseView, workspace_->k1, 0.5 * h);
    status = constrain(system_, workspace_->stage, t + 0.5 * h, t0);
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    auto before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + 0.5 * h, t0,
                      workspace_->k2, metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    workspace_->stage.setAffine(baseView, workspace_->k2, 0.75 * h);
    status = constrain(system_, workspace_->stage, t + 0.75 * h, t0);
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + 0.75 * h, t0,
                      workspace_->k3, metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    workspace_->stage.setWeightedCandidate(
        baseView, h, workspace_->k1, 2.0 / 9.0, workspace_->k2, 1.0 / 3.0,
        workspace_->k3, 4.0 / 9.0);
    auto candidateState = workspace_->stage.mutableState(t + h, t0);
    const auto endpointConstraint = system_.enforceStateConstraints(candidateState);
    metrics_.constraintModifiedCoefficientCount +=
        endpointConstraint.modifiedCoefficientCount;
    if (!endpointConstraint) {
      fsalAvailable_ = false;
      return endpointConstraint.status;
    }
    before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + h, t0, workspace_->k4,
                      metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    const auto complexError = [&](std::size_t i) noexcept {
      return WVComplex64{
          h * ((2.0 / 9.0 - 7.0 / 24.0) * workspace_->k1.complex()[i].real +
               (1.0 / 3.0 - 0.25) * workspace_->k2.complex()[i].real +
               (4.0 / 9.0 - 1.0 / 3.0) * workspace_->k3.complex()[i].real -
               0.125 * workspace_->k4.complex()[i].real),
          h * ((2.0 / 9.0 - 7.0 / 24.0) * workspace_->k1.complex()[i].imag +
               (1.0 / 3.0 - 0.25) * workspace_->k2.complex()[i].imag +
               (4.0 / 9.0 - 1.0 / 3.0) * workspace_->k3.complex()[i].imag -
               0.125 * workspace_->k4.complex()[i].imag)};
    };
    const auto realError = [&](std::size_t i) noexcept {
      return h * ((2.0 / 9.0 - 7.0 / 24.0) * workspace_->k1.real()[i] +
                  (1.0 / 3.0 - 0.25) * workspace_->k2.real()[i] +
                  (4.0 / 9.0 - 1.0 / 3.0) * workspace_->k3.real()[i] -
                  0.125 * workspace_->k4.real()[i]);
    };
    const auto error = AdaptiveRungeKuttaDriver::normalizedError(
        *errorPolicy_, system_.stateLayout(), workspace_->stage, baseView,
        options_.relativeTolerance, complexError, realError);
    const bool accepted = std::isfinite(error) && error <= 1.0;
    const auto factor = AdaptiveRungeKuttaDriver::controllerFactor(
        error, rejectedThisStep, 1.0 / 3.0, options_.safetyFactor,
        options_.rejectionFloorFactor, options_.rejectionFloorFactor,
        options_.maximumStepFactor);
    nextStepSize_ =
        std::min(options_.maximumStepSize, h * factor);
    metrics_.lastProposedStepSize = proposedStepSize;
    metrics_.normalizedError = error;
    metrics_.nextStepSize = nextStepSize_;
    if (accepted) {
      workspace_->stage.copyTo(state);
      state.waveVortex.t = t + h;
      makeExternalViews(state, workspace_->acceptedViews);
      acceptedStep_ = {
          t,
          state.waveVortex.t,
          {state.waveVortex.view(), workspace_->acceptedViews.data(),
           workspace_->acceptedViews.size()},
          {metrics_.acceptedStepCount + 1, rejectedThisStep,
           evaluationsThisStep, h, proposedStepSize, nextStepSize_, error},
          options_.retainDenseOutput ? this : nullptr};
      ++metrics_.acceptedStepCount;
      metrics_.lastAcceptedStepSize = h;
      fsalAvailable_ = endpointConstraint.modifiedCoefficientCount == 0 &&
                       endpointConstraint.fsalCompatible;
      if (!fsalAvailable_)
        ++metrics_.fsalInvalidationCount;
      hasAcceptedStep_ = true;
      if (stepDiagnostics_.size() < options_.maximumRecordedStepDiagnostics)
        stepDiagnostics_.push_back(
            {t, h, error, nextStepSize_, rejectedThisStep,
             evaluationsThisStep, reusedFSALDerivative});
      metrics_.diagnosticCapacityBytes =
          stepDiagnostics_.capacity() * sizeof(WVAdaptiveRK23StepDiagnostic);
      return WVKernelStatus::ok();
    }
    AdaptiveRungeKuttaDriver::recordRejectedAttempt(
        metrics_, rejectedThisStep, nextStepSize_, h);
    if (!(h > 0.0) || t + h == t)
      return {WVKernelStatusCode::numericalFailure,
              "RK23 step size underflowed after rejection."};
  }
}

WVKernelStatus
WVAdaptiveRK23::advanceToTime(WVMutableIntegrationState &state,
                                       double finalTime, double h) {
  return AdaptiveRungeKuttaDriver::advanceToTime(
      state, finalTime, h, false, "RK23",
      [&](double use) { return step(state, use); },
      [&]() { return nextStepSize_; });
}

WVKernelStatus WVAdaptiveRK23::evaluateDenseOutput(
    double time, WVMutableIntegrationState &output) const {
  if (!options_.retainDenseOutput || !hasAcceptedStep_)
    return {WVKernelStatusCode::unsupportedOperation,
            "RK23 dense output is unavailable."};
  if (evaluatingDenseOutput_)
    return {WVKernelStatusCode::reentrantExecution,
            "RK23 dense-output evaluation is not reentrant."};
  auto status = validateMutableIntegrationState(system_.stateLayout(), output);
  if (!status)
    return status;
  const double h = acceptedStep_.finalTime - acceptedStep_.initialTime;
  const auto tol =
      timeTolerance(acceptedStep_.initialTime, acceptedStep_.finalTime);
  if (time < acceptedStep_.initialTime - tol ||
      time > acceptedStep_.finalTime + tol)
    return {WVKernelStatusCode::invalidConfiguration,
            "Dense-output time is outside the accepted interval."};
  evaluatingDenseOutput_ = true;
  struct Guard {
    bool &value;
    ~Guard() { value = false; }
  } guard{evaluatingDenseOutput_};
  double theta = h == 0 ? 0 : (time - acceptedStep_.initialTime) / h;
  if (std::abs(time - acceptedStep_.initialTime) <= tol)
    theta = 0.0;
  if (std::abs(time - acceptedStep_.finalTime) <= tol)
    theta = 1.0;
  theta = std::max(0.0, std::min(1.0, theta));
  const double t2 = theta * theta, t3 = t2 * theta;
  const double weights[] = {
      theta - (4.0 / 3.0) * t2 + (5.0 / 9.0) * t3 - 2.0 / 9.0,
      t2 - (2.0 / 3.0) * t3 - 1.0 / 3.0,
      (4.0 / 3.0) * t2 - (8.0 / 9.0) * t3 - 4.0 / 9.0,
      -t2 + t3};
  const auto started = std::chrono::steady_clock::now();
  workspace_->stage.copyFrom(acceptedStep_.endpoint);
  const IntegrationBuffer *derivatives[] = {&workspace_->k1, &workspace_->k2,
                                          &workspace_->k3, &workspace_->k4};
  auto &complex = workspace_->stage.complex();
  for (std::size_t i = 0; i < complex.size(); ++i) {
    for (std::size_t derivative = 0; derivative < 4; ++derivative) {
      complex[i].real +=
          h * weights[derivative] * derivatives[derivative]->complex()[i].real;
      complex[i].imag +=
          h * weights[derivative] * derivatives[derivative]->complex()[i].imag;
    }
  }
  auto &real = workspace_->stage.real();
  for (std::size_t i = 0; i < real.size(); ++i) {
    for (std::size_t derivative = 0; derivative < 4; ++derivative)
      real[i] += h * weights[derivative] * derivatives[derivative]->real()[i];
  }
  auto stage = workspace_->stage.mutableState(
      time, acceptedStep_.endpoint.waveVortex.t0);
  status = system_.enforceStateConstraints(stage).status;
  if (!status)
    return status;
  workspace_->stage.copyTo(output);
  output.waveVortex.t = time;
  output.waveVortex.t0 = acceptedStep_.endpoint.waveVortex.t0;
  ++metrics_.denseOutputEvaluationCount;
  metrics_.denseOutputElementReads += 5 * (complex.size() + real.size());
  metrics_.denseOutputElementWrites += complex.size() + real.size();
  metrics_.denseOutputSeconds +=
      std::chrono::duration<double>(std::chrono::steady_clock::now() - started)
          .count();
  return WVKernelStatus::ok();
}

namespace {

constexpr WVAdaptiveRKStageBufferLastUse rk23StageBufferLastUse[] = {
    {"stage", "accepted-state commit or dense-output scratch", 4},
    {"k1", "continuous extension or next-step FSAL swap", 4},
    {"k2", "continuous extension", 4},
    {"k3", "continuous extension", 4},
    {"k4", "continuous extension or next-step FSAL swap", 4}};

constexpr WVAdaptiveRKStageBufferLastUse rk45StageBufferLastUse[] = {
    {"stage", "accepted-state commit or dense-output scratch", 7},
    {"k1", "continuous extension or next-step FSAL swap", 7},
    {"k2/k7", "continuous extension or next-step FSAL swap", 7},
    {"k3", "continuous extension", 7},
    {"k4", "continuous extension", 7},
    {"k5", "continuous extension", 7},
    {"k6", "continuous extension", 7}};

} // namespace

const WVAdaptiveRKStageBufferLastUse *
WVAdaptiveRK23::stageBufferLastUseRecords() noexcept {
  return rk23StageBufferLastUse;
}

std::size_t WVAdaptiveRK23::stageBufferLastUseRecordCount() noexcept {
  return sizeof(rk23StageBufferLastUse) / sizeof(rk23StageBufferLastUse[0]);
}

class WVAdaptiveRK45::Workspace {
public:
  IntegrationBuffer stage, k1, k2OrK7, k3, k4, k5, k6;
  std::vector<WVAdditionalStateBlockConstView> baseViews;
  std::vector<WVAdditionalStateBlockConstView> acceptedViews;
  std::size_t capacityBytes() const noexcept {
    return stage.capacityBytes() + k1.capacityBytes() +
           k2OrK7.capacityBytes() + k3.capacityBytes() + k4.capacityBytes() +
           k5.capacityBytes() + k6.capacityBytes();
  }
  std::size_t viewCapacityBytes() const noexcept {
    return (baseViews.capacity() + acceptedViews.capacity()) *
           sizeof(WVAdditionalStateBlockConstView);
  }
};

WVAdaptiveRK45::WVAdaptiveRK45(WVIntegrationSystem &system,
                               WVAdaptiveRK45Options options)
    : system_(system), options_(options) {}

WVAdaptiveRK45::~WVAdaptiveRK45() { delete workspace_; }

std::size_t WVAdaptiveRK45::persistentBytes() const noexcept {
  return sizeof(*this) +
         (workspace_ == nullptr
              ? 0
              : sizeof(Workspace) + workspace_->capacityBytes() +
                    workspace_->viewCapacityBytes()) +
         (errorPolicy_ == nullptr ? 0 : errorPolicy_->persistentBytes()) +
         stepDiagnostics_.capacity() * sizeof(WVAdaptiveRK45StepDiagnostic) +
         toleranceComponentHashes_.capacity() * sizeof(std::uint64_t);
}

WVKernelStatus
WVAdaptiveRK45::ensureWorkspace(const WVMutableIntegrationState &state) {
  auto status = validateMutableIntegrationState(system_.stateLayout(), state);
  if (!status)
    return status;
  status = AdaptiveRungeKuttaDriver::validateOptions(options_, "RK45");
  if (!status)
    return status;
  if (!(options_.repeatedRejectionFactor > 0.0 &&
        options_.repeatedRejectionFactor < 1.0))
    return {WVKernelStatusCode::invalidConfiguration,
            "RK45 repeated-rejection factor must be between zero and one."};
  if (workspace_ != nullptr)
    return WVKernelStatus::ok();
  status = AdaptiveRungeKuttaDriver::initializeErrorPolicy(
      system_, options_, errorPolicy_, toleranceHash_,
      toleranceComponentHashes_);
  if (!status)
    return status;
  try {
    workspace_ = new Workspace;
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "RK45 workspace allocation failed."};
  }
  IntegrationBuffer *buffers[] = {
      &workspace_->stage, &workspace_->k1, &workspace_->k2OrK7,
      &workspace_->k3,    &workspace_->k4, &workspace_->k5,
      &workspace_->k6};
  for (auto *buffer : buffers) {
    status = buffer->initialize(system_.stateLayout());
    if (!status) {
      delete workspace_;
      workspace_ = nullptr;
      return status;
    }
  }
  try {
    workspace_->baseViews.reserve(
        system_.stateLayout().additionalBlocks().size());
    workspace_->acceptedViews.reserve(
        system_.stateLayout().additionalBlocks().size());
  } catch (const std::bad_alloc &) {
    delete workspace_;
    workspace_ = nullptr;
    return {WVKernelStatusCode::allocationFailure,
            "RK45 state-view workspace allocation failed."};
  }
  metrics_.workspaceCapacityBytes =
      workspace_->capacityBytes() + workspace_->viewCapacityBytes();
  metrics_.workspaceMaximumLiveBytes = metrics_.workspaceCapacityBytes;
  metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
  metrics_.stateCapacityBytes = workspace_->stage.valueCapacityBytes();
  metrics_.workspaceStateEquivalentCount = 7;
  metrics_.denseHistoryCapacityBytes =
      options_.retainDenseOutput
          ? workspace_->k1.valueCapacityBytes() +
                workspace_->k2OrK7.valueCapacityBytes() +
                workspace_->k3.valueCapacityBytes() +
                workspace_->k4.valueCapacityBytes() +
                workspace_->k5.valueCapacityBytes() +
                workspace_->k6.valueCapacityBytes()
          : 0;
  metrics_.denseHistoryStateEquivalentCount =
      options_.retainDenseOutput ? 6 : 0;
  metrics_.errorPolicyBytes = errorPolicy_->persistentBytes();
  return WVKernelStatus::ok();
}

WVKernelStatus WVAdaptiveRK45::prepareStateAfterRestart(
    WVMutableIntegrationState &state) {
  return AdaptiveRungeKuttaDriver::prepareStateAfterRestart(
      system_, state, hasAcceptedStep_, fsalAvailable_, nextStepSize_,
      stepDiagnostics_, metrics_, [&]() { return ensureWorkspace(state); });
}

WVKernelStatus WVAdaptiveRK45::step(WVMutableIntegrationState &state,
                                    double proposedStepSize) {
  return stepImplementation(state, proposedStepSize, false);
}

WVKernelStatus WVAdaptiveRK45::stepImplementation(
    WVMutableIntegrationState &state, double proposedStepSize,
    bool allowFinalStepStretch) {
  if (stepping_)
    return {WVKernelStatusCode::reentrantExecution,
            "RK45 stepping is not reentrant."};
  if (!(proposedStepSize > 0.0) || !std::isfinite(proposedStepSize))
    return {WVKernelStatusCode::invalidConfiguration,
            "RK45 step size must be finite and positive."};
  auto status = ensureWorkspace(state);
  if (!status)
    return status;
  stepping_ = true;
  struct Guard {
    bool &value;
    ~Guard() { value = false; }
  } guard{stepping_};
  hasAcceptedStep_ = false;
  const auto baseView = integrationConstView(state, workspace_->baseViews);
  const auto t = state.waveVortex.t;
  const auto t0 = state.waveVortex.t0;
  double h = allowFinalStepStretch
                 ? proposedStepSize
                 : std::min(proposedStepSize, options_.maximumStepSize);
  bool initialDerivativeAvailable = false;
  bool reusedFSALDerivative = false;
  if (fsalAvailable_) {
    std::swap(workspace_->k1, workspace_->k2OrK7);
    initialDerivativeAvailable = true;
    reusedFSALDerivative = true;
    fsalAvailable_ = false;
    ++metrics_.fsalReuseCount;
  }
  std::size_t rejectedThisStep = 0;
  std::size_t evaluationsThisStep = 0;
  for (;;) {
    if (!std::isfinite(h) || !(t + h > t)) {
      fsalAvailable_ = false;
      return {WVKernelStatusCode::numericalFailure,
              "RK45 cannot advance time with the proposed step."};
    }
    if (!initialDerivativeAvailable) {
      const auto before = metrics_.rightHandSideEvaluationCount;
      auto derivative = workspace_->k1.flux();
      status = system_.evaluateRightHandSide(baseView, derivative);
      if (status)
        ++metrics_.rightHandSideEvaluationCount;
      evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
      if (!status) {
        fsalAvailable_ = false;
        return status;
      }
      initialDerivativeAvailable = true;
    }

    workspace_->stage.setAffine(baseView, workspace_->k1, h * (1.0 / 5.0));
    status = constrain(system_, workspace_->stage, t + h * (1.0 / 5.0), t0);
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    auto before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + h * (1.0 / 5.0), t0,
                      workspace_->k2OrK7, metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }

    workspace_->stage.copyFrom(baseView);
    workspace_->stage.addScaled(workspace_->k1, h * (3.0 / 40.0));
    workspace_->stage.addScaled(workspace_->k2OrK7, h * (9.0 / 40.0));
    status = constrain(system_, workspace_->stage, t + h * (3.0 / 10.0), t0);
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + h * (3.0 / 10.0), t0,
                      workspace_->k3, metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }

    workspace_->stage.copyFrom(baseView);
    workspace_->stage.addScaled(workspace_->k1, h * (44.0 / 45.0));
    workspace_->stage.addScaled(workspace_->k2OrK7, h * (-56.0 / 15.0));
    workspace_->stage.addScaled(workspace_->k3, h * (32.0 / 9.0));
    status = constrain(system_, workspace_->stage, t + h * (4.0 / 5.0), t0);
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + h * (4.0 / 5.0), t0,
                      workspace_->k4, metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }

    workspace_->stage.copyFrom(baseView);
    workspace_->stage.addScaled(workspace_->k1, h * (19372.0 / 6561.0));
    workspace_->stage.addScaled(workspace_->k2OrK7,
                                h * (-25360.0 / 2187.0));
    workspace_->stage.addScaled(workspace_->k3, h * (64448.0 / 6561.0));
    workspace_->stage.addScaled(workspace_->k4, h * (-212.0 / 729.0));
    status = constrain(system_, workspace_->stage, t + h * (8.0 / 9.0), t0);
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + h * (8.0 / 9.0), t0,
                      workspace_->k5, metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }

    workspace_->stage.copyFrom(baseView);
    workspace_->stage.addScaled(workspace_->k1, h * (9017.0 / 3168.0));
    workspace_->stage.addScaled(workspace_->k2OrK7, h * (-355.0 / 33.0));
    workspace_->stage.addScaled(workspace_->k3, h * (46732.0 / 5247.0));
    workspace_->stage.addScaled(workspace_->k4, h * (49.0 / 176.0));
    workspace_->stage.addScaled(workspace_->k5, h * (-5103.0 / 18656.0));
    status = constrain(system_, workspace_->stage, t + h, t0);
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }
    before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + h, t0, workspace_->k6,
                      metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }

    workspace_->stage.copyFrom(baseView);
    workspace_->stage.addScaled(workspace_->k1, h * (35.0 / 384.0));
    workspace_->stage.addScaled(workspace_->k3, h * (500.0 / 1113.0));
    workspace_->stage.addScaled(workspace_->k4, h * (125.0 / 192.0));
    workspace_->stage.addScaled(workspace_->k5, h * (-2187.0 / 6784.0));
    workspace_->stage.addScaled(workspace_->k6, h * (11.0 / 84.0));
    auto candidateState = workspace_->stage.mutableState(t + h, t0);
    const auto endpointConstraint =
        system_.enforceStateConstraints(candidateState);
    metrics_.constraintModifiedCoefficientCount +=
        endpointConstraint.modifiedCoefficientCount;
    if (!endpointConstraint) {
      fsalAvailable_ = false;
      return endpointConstraint.status;
    }
    before = metrics_.rightHandSideEvaluationCount;
    status = evaluate(system_, workspace_->stage, t + h, t0,
                      workspace_->k2OrK7, metrics_);
    evaluationsThisStep += metrics_.rightHandSideEvaluationCount - before;
    if (!status) {
      fsalAvailable_ = false;
      return status;
    }

    const auto complexError = [&](std::size_t i) noexcept {
      return WVComplex64{
          h * ((71.0 / 57600.0) * workspace_->k1.complex()[i].real -
               (71.0 / 16695.0) * workspace_->k3.complex()[i].real +
               (71.0 / 1920.0) * workspace_->k4.complex()[i].real -
               (17253.0 / 339200.0) * workspace_->k5.complex()[i].real +
               (22.0 / 525.0) * workspace_->k6.complex()[i].real -
               (1.0 / 40.0) * workspace_->k2OrK7.complex()[i].real),
          h * ((71.0 / 57600.0) * workspace_->k1.complex()[i].imag -
               (71.0 / 16695.0) * workspace_->k3.complex()[i].imag +
               (71.0 / 1920.0) * workspace_->k4.complex()[i].imag -
               (17253.0 / 339200.0) * workspace_->k5.complex()[i].imag +
               (22.0 / 525.0) * workspace_->k6.complex()[i].imag -
               (1.0 / 40.0) * workspace_->k2OrK7.complex()[i].imag)};
    };
    const auto realError = [&](std::size_t i) noexcept {
      return h * ((71.0 / 57600.0) * workspace_->k1.real()[i] -
                  (71.0 / 16695.0) * workspace_->k3.real()[i] +
                  (71.0 / 1920.0) * workspace_->k4.real()[i] -
                  (17253.0 / 339200.0) * workspace_->k5.real()[i] +
                  (22.0 / 525.0) * workspace_->k6.real()[i] -
                  (1.0 / 40.0) * workspace_->k2OrK7.real()[i]);
    };
    const auto error = AdaptiveRungeKuttaDriver::normalizedError(
        *errorPolicy_, system_.stateLayout(), workspace_->stage, baseView,
        options_.relativeTolerance, complexError, realError);
    const auto accepted = std::isfinite(error) && error <= 1.0;
    const auto factor = AdaptiveRungeKuttaDriver::controllerFactor(
        error, rejectedThisStep, 1.0 / 5.0, options_.safetyFactor,
        options_.rejectionFloorFactor, options_.repeatedRejectionFactor,
        options_.maximumStepFactor);
    nextStepSize_ = std::min(options_.maximumStepSize, h * factor);
    metrics_.lastProposedStepSize = proposedStepSize;
    metrics_.normalizedError = error;
    metrics_.nextStepSize = nextStepSize_;
    if (accepted) {
      workspace_->stage.copyTo(state);
      state.waveVortex.t = t + h;
      makeExternalViews(state, workspace_->acceptedViews);
      acceptedStep_ = {
          t,
          state.waveVortex.t,
          {state.waveVortex.view(), workspace_->acceptedViews.data(),
           workspace_->acceptedViews.size()},
          {metrics_.acceptedStepCount + 1, rejectedThisStep,
           evaluationsThisStep, h, proposedStepSize, nextStepSize_, error},
          options_.retainDenseOutput ? this : nullptr};
      ++metrics_.acceptedStepCount;
      ++metrics_.stepCount;
      metrics_.lastStepSize = h;
      metrics_.lastAcceptedStepSize = h;
      fsalAvailable_ = endpointConstraint.modifiedCoefficientCount == 0 &&
                       endpointConstraint.fsalCompatible;
      if (!fsalAvailable_)
        ++metrics_.fsalInvalidationCount;
      hasAcceptedStep_ = true;
      if (stepDiagnostics_.size() < options_.maximumRecordedStepDiagnostics)
        stepDiagnostics_.push_back(
            {t, h, error, nextStepSize_, rejectedThisStep,
             evaluationsThisStep, reusedFSALDerivative});
      metrics_.diagnosticCapacityBytes =
          stepDiagnostics_.capacity() * sizeof(WVAdaptiveRK45StepDiagnostic);
      return WVKernelStatus::ok();
    }
    AdaptiveRungeKuttaDriver::recordRejectedAttempt(
        metrics_, rejectedThisStep, nextStepSize_, h);
    if (!(h > 0.0) || t + h == t)
      return {WVKernelStatusCode::numericalFailure,
              "RK45 step size underflowed after rejection."};
  }
}

WVKernelStatus WVAdaptiveRK45::advanceToTime(
    WVMutableIntegrationState &state, double finalTime, double h) {
  return AdaptiveRungeKuttaDriver::advanceToTime(
      state, finalTime, h, true, "RK45",
      [&](double use) {
        return stepImplementation(
            state, use,
            use > options_.maximumStepSize &&
                use <= 1.1 * options_.maximumStepSize);
      },
      [&]() { return nextStepSize_; });
}

WVKernelStatus WVAdaptiveRK45::evaluateDenseOutput(
    double time, WVMutableIntegrationState &output) const {
  if (!options_.retainDenseOutput || !hasAcceptedStep_)
    return {WVKernelStatusCode::unsupportedOperation,
            "RK45 dense output is unavailable."};
  if (evaluatingDenseOutput_)
    return {WVKernelStatusCode::reentrantExecution,
            "RK45 dense-output evaluation is not reentrant."};
  auto status = validateMutableIntegrationState(system_.stateLayout(), output);
  if (!status)
    return status;
  const double h = acceptedStep_.finalTime - acceptedStep_.initialTime;
  const auto tolerance =
      timeTolerance(acceptedStep_.initialTime, acceptedStep_.finalTime);
  if (time < acceptedStep_.initialTime - tolerance ||
      time > acceptedStep_.finalTime + tolerance)
    return {WVKernelStatusCode::invalidConfiguration,
            "Dense-output time is outside the accepted interval."};
  evaluatingDenseOutput_ = true;
  struct Guard {
    bool &value;
    ~Guard() { value = false; }
  } guard{evaluatingDenseOutput_};
  double theta = h == 0.0 ? 0.0 : (time - acceptedStep_.initialTime) / h;
  if (std::abs(time - acceptedStep_.initialTime) <= tolerance)
    theta = 0.0;
  if (std::abs(time - acceptedStep_.finalTime) <= tolerance)
    theta = 1.0;
  theta = std::max(0.0, std::min(1.0, theta));
  const double theta2 = theta * theta;
  const double weights[] = {
      theta + theta2 * (-183.0 / 64.0 +
                        theta * (37.0 / 12.0 - 145.0 / 128.0 * theta)) -
          35.0 / 384.0,
      theta2 * (1500.0 / 371.0 +
                theta * (-1000.0 / 159.0 + 1000.0 / 371.0 * theta)) -
          500.0 / 1113.0,
      theta2 * (-125.0 / 32.0 +
                theta * (125.0 / 12.0 - 375.0 / 64.0 * theta)) -
          125.0 / 192.0,
      theta2 * (9477.0 / 3392.0 +
                theta * (-729.0 / 106.0 + 25515.0 / 6784.0 * theta)) +
          2187.0 / 6784.0,
      theta2 * (-11.0 / 7.0 +
                theta * (11.0 / 3.0 - 55.0 / 28.0 * theta)) -
          11.0 / 84.0,
      theta2 * (3.0 / 2.0 + theta * (-4.0 + 5.0 / 2.0 * theta))};
  const auto started = std::chrono::steady_clock::now();
  workspace_->stage.copyFrom(acceptedStep_.endpoint);
  const IntegrationBuffer *derivatives[] = {
      &workspace_->k1, &workspace_->k3, &workspace_->k4,
      &workspace_->k5, &workspace_->k6, &workspace_->k2OrK7};
  auto &complex = workspace_->stage.complex();
  for (std::size_t i = 0; i < complex.size(); ++i)
    for (std::size_t derivative = 0; derivative < 6; ++derivative) {
      complex[i].real +=
          h * weights[derivative] * derivatives[derivative]->complex()[i].real;
      complex[i].imag +=
          h * weights[derivative] * derivatives[derivative]->complex()[i].imag;
    }
  auto &real = workspace_->stage.real();
  for (std::size_t i = 0; i < real.size(); ++i)
    for (std::size_t derivative = 0; derivative < 6; ++derivative)
      real[i] += h * weights[derivative] * derivatives[derivative]->real()[i];
  auto stage = workspace_->stage.mutableState(
      time, acceptedStep_.endpoint.waveVortex.t0);
  status = system_.enforceStateConstraints(stage).status;
  if (!status)
    return status;
  workspace_->stage.copyTo(output);
  output.waveVortex.t = time;
  output.waveVortex.t0 = acceptedStep_.endpoint.waveVortex.t0;
  ++metrics_.denseOutputEvaluationCount;
  metrics_.denseOutputElementReads += 7 * (complex.size() + real.size());
  metrics_.denseOutputElementWrites += complex.size() + real.size();
  metrics_.denseOutputSeconds +=
      std::chrono::duration<double>(std::chrono::steady_clock::now() - started)
          .count();
  return WVKernelStatus::ok();
}

double WVAdaptiveRK45::initialTime() const noexcept {
  return hasAcceptedStep_ ? acceptedStep_.initialTime : 0.0;
}

double WVAdaptiveRK45::finalTime() const noexcept {
  return hasAcceptedStep_ ? acceptedStep_.finalTime : 0.0;
}

const WVAcceptedStep *WVAdaptiveRK45::lastAcceptedStep() const noexcept {
  return hasAcceptedStep_ ? &acceptedStep_ : nullptr;
}

const WVIntegratorMetrics &WVAdaptiveRK45::metrics() const noexcept {
  return metrics_;
}

const std::vector<WVAdaptiveRK45StepDiagnostic> &
WVAdaptiveRK45::stepDiagnostics() const noexcept {
  return stepDiagnostics_;
}

std::uint64_t WVAdaptiveRK45::toleranceHash() const noexcept {
  return toleranceHash_;
}

const std::vector<std::uint64_t> &
WVAdaptiveRK45::toleranceComponentHashes() const noexcept {
  return toleranceComponentHashes_;
}

bool WVAdaptiveRK45::stepDiagnosticsComplete() const noexcept {
  return stepDiagnostics_.size() == metrics_.acceptedStepCount;
}

const WVAdaptiveRKStageBufferLastUse *
WVAdaptiveRK45::stageBufferLastUseRecords() noexcept {
  return rk45StageBufferLastUse;
}

std::size_t WVAdaptiveRK45::stageBufferLastUseRecordCount() noexcept {
  return sizeof(rk45StageBufferLastUse) / sizeof(rk45StageBufferLastUse[0]);
}

double WVAdaptiveRK45::nextStepSize() const noexcept { return nextStepSize_; }

} // namespace wavevortex::runtime
