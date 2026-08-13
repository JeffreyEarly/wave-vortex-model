#include "WaveVortexRuntime/WVCompositeIntegration.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
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

class CompositeBuffer {
public:
  WVKernelStatus initialize(const WVCompositeStateLayout &layout) {
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
              "Composite integration workspace allocation failed."};
    }
  }

  WVMutableCompositeState mutableState(double t, double t0) noexcept {
    const auto shape = layout_->coefficientShape();
    return {{t,
             t0,
             {{complex_.data(), shape},
              {complex_.data() + coefficientCount_, shape},
              {complex_.data() + 2 * coefficientCount_, shape}}},
            mutableBlocks_.data(),
            mutableBlocks_.size()};
  }
  WVCompositeState state(double t, double t0) const noexcept {
    const auto shape = layout_->coefficientShape();
    return {{t,
             t0,
             {{complex_.data(), shape},
              {complex_.data() + coefficientCount_, shape},
              {complex_.data() + 2 * coefficientCount_, shape}}},
            constBlocks_.data(),
            constBlocks_.size()};
  }
  WVCompositeFlux flux() noexcept {
    const auto shape = layout_->coefficientShape();
    return {{{complex_.data(), shape},
             {complex_.data() + coefficientCount_, shape},
             {complex_.data() + 2 * coefficientCount_, shape}},
            mutableBlocks_.data(),
            mutableBlocks_.size()};
  }
  void copyFrom(const WVCompositeState &source) noexcept {
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
  void copyTo(WVMutableCompositeState &destination) const noexcept {
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
  void assign(const CompositeBuffer &source) noexcept {
    complex_ = source.complex_;
    real_ = source.real_;
  }
  void setAffine(const WVCompositeState &base, const CompositeBuffer &increment,
                 double scale) noexcept {
    copyFrom(base);
    for (std::size_t i = 0; i < complex_.size(); ++i)
      complex_[i] = scaledSum(complex_[i], increment.complex_[i], scale);
    for (std::size_t i = 0; i < real_.size(); ++i)
      real_[i] += scale * increment.real_[i];
  }
  void addScaled(const CompositeBuffer &source, double scale) noexcept {
    for (std::size_t i = 0; i < complex_.size(); ++i)
      complex_[i] = scaledSum(complex_[i], source.complex_[i], scale);
    for (std::size_t i = 0; i < real_.size(); ++i)
      real_[i] += scale * source.real_[i];
  }
  void setWeightedCandidate(const WVCompositeState &base, double h,
                            const CompositeBuffer &k1, double w1,
                            const CompositeBuffer &k2, double w2,
                            const CompositeBuffer &k3, double w3) noexcept {
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
  const std::vector<WVComplex64> &complex() const noexcept { return complex_; }
  const std::vector<double> &real() const noexcept { return real_; }
  std::vector<WVComplex64> &complex() noexcept { return complex_; }
  std::vector<double> &real() noexcept { return real_; }
  std::size_t coefficientCount() const noexcept { return coefficientCount_; }

private:
  const WVCompositeStateLayout *layout_ = nullptr;
  std::size_t coefficientCount_ = 0;
  std::vector<WVComplex64> complex_;
  std::vector<double> real_;
  std::vector<WVAdditionalStateBlockView> mutableBlocks_;
  std::vector<WVAdditionalStateBlockConstView> constBlocks_;
};

WVKernelStatus constrain(WVCompositeIntegrationSystem &system,
                         CompositeBuffer &buffer, double t, double t0) {
  auto state = buffer.mutableState(t, t0);
  return system.enforceStateConstraints(state).status;
}

WVKernelStatus evaluate(WVCompositeIntegrationSystem &system,
                        const CompositeBuffer &state, double t, double t0,
                        CompositeBuffer &derivative,
                        WVCompositeIntegratorMetrics &metrics) {
  auto flux = derivative.flux();
  const auto status = system.evaluateRightHandSide(state.state(t, t0), flux);
  if (status)
    ++metrics.rightHandSideEvaluationCount;
  return status;
}

void makeExternalViews(const WVMutableCompositeState &state,
                       std::vector<WVAdditionalStateBlockConstView> &views) {
  views.clear();
  views.reserve(state.additionalBlockCount);
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index)
    views.push_back({state.additionalBlocks[index].layout,
                     state.additionalBlocks[index].realData,
                     state.additionalBlocks[index].complexData});
}

double complexAbsoluteTolerance(const WVCompositeIntegrationSystem &system,
                                const CompositeBuffer &buffer,
                                std::size_t flatIndex, double scale) noexcept {
  const auto coefficientValues = 3 * buffer.coefficientCount();
  if (flatIndex < coefficientValues)
    return system.coefficientAbsoluteTolerance(
               flatIndex / buffer.coefficientCount(),
               flatIndex % buffer.coefficientCount()) *
           scale;
  const auto additionalIndex = flatIndex - coefficientValues;
  for (const auto &block : system.stateLayout().additionalBlocks()) {
    if (block.scalarType == WVStateScalarType::complex64 &&
        additionalIndex >= block.scalarOffset &&
        additionalIndex < block.scalarOffset + block.elementCount)
      return block.absoluteTolerance * scale;
  }
  return scale;
}

} // namespace

class WVCompositeFixedStepRK4::Workspace {
public:
  CompositeBuffer base, stage, derivative, weighted, initialDerivative,
      finalDerivative;
  std::vector<WVAdditionalStateBlockConstView> acceptedViews;
  std::size_t capacityBytes() const noexcept {
    return base.capacityBytes() + stage.capacityBytes() +
           derivative.capacityBytes() + weighted.capacityBytes() +
           initialDerivative.capacityBytes() + finalDerivative.capacityBytes();
  }
};

WVCompositeFixedStepRK4::WVCompositeFixedStepRK4(
    WVCompositeIntegrationSystem &system, bool retainDenseOutput)
    : system_(system), retainDenseOutput_(retainDenseOutput) {}
WVCompositeFixedStepRK4::~WVCompositeFixedStepRK4() { delete workspace_; }

WVKernelStatus
WVCompositeFixedStepRK4::ensureWorkspace(const WVMutableCompositeState &state) {
  auto status = validateMutableCompositeState(system_.stateLayout(), state);
  if (!status)
    return status;
  if (workspace_ != nullptr)
    return WVKernelStatus::ok();
  try {
    workspace_ = new Workspace;
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Composite RK4 workspace allocation failed."};
  }
  CompositeBuffer *buffers[] = {&workspace_->base, &workspace_->stage,
                                &workspace_->derivative, &workspace_->weighted};
  for (auto *buffer : buffers) {
    status = buffer->initialize(system_.stateLayout());
    if (!status) {
      delete workspace_;
      workspace_ = nullptr;
      return status;
    }
  }
  if (retainDenseOutput_) {
    status = workspace_->initialDerivative.initialize(system_.stateLayout());
    if (status)
      status = workspace_->finalDerivative.initialize(system_.stateLayout());
    if (!status) {
      delete workspace_;
      workspace_ = nullptr;
      return status;
    }
  }
  metrics_.workspaceCapacityBytes = workspace_->capacityBytes();
  metrics_.workspaceMaximumLiveBytes = metrics_.workspaceCapacityBytes;
  return WVKernelStatus::ok();
}

WVKernelStatus WVCompositeFixedStepRK4::prepareStateAfterRestart(
    WVMutableCompositeState &state) {
  hasAcceptedStep_ = false;
  auto status = ensureWorkspace(state);
  if (!status)
    return status;
  return system_.enforceStateConstraints(state).status;
}

WVKernelStatus WVCompositeFixedStepRK4::step(WVMutableCompositeState &state,
                                             double h) {
  if (stepping_)
    return {WVKernelStatusCode::reentrantExecution,
            "Composite RK4 stepping is not reentrant."};
  if (!(h > 0.0) || !std::isfinite(h))
    return {WVKernelStatusCode::invalidConfiguration,
            "Composite RK4 step size must be finite and positive."};
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
  const auto baseView = compositeConstView(state, stateViews);
  const double initialTime = state.waveVortex.t;
  workspace_->base.copyFrom(baseView);
  status = evaluate(system_, workspace_->base, initialTime, state.waveVortex.t0,
                    workspace_->derivative, metrics_);
  if (!status)
    return status;
  workspace_->weighted.assign(workspace_->derivative);
  if (retainDenseOutput_)
    workspace_->initialDerivative.assign(workspace_->derivative);
  workspace_->stage.setAffine(baseView, workspace_->derivative, 0.5 * h);
  status = constrain(system_, workspace_->stage, initialTime + 0.5 * h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  status = evaluate(system_, workspace_->stage, initialTime + 0.5 * h,
                    state.waveVortex.t0, workspace_->derivative, metrics_);
  if (!status)
    return status;
  workspace_->weighted.addScaled(workspace_->derivative, 2.0);
  workspace_->stage.setAffine(baseView, workspace_->derivative, 0.5 * h);
  status = constrain(system_, workspace_->stage, initialTime + 0.5 * h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  status = evaluate(system_, workspace_->stage, initialTime + 0.5 * h,
                    state.waveVortex.t0, workspace_->derivative, metrics_);
  if (!status)
    return status;
  workspace_->weighted.addScaled(workspace_->derivative, 2.0);
  workspace_->stage.setAffine(baseView, workspace_->derivative, h);
  status = constrain(system_, workspace_->stage, initialTime + h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  status = evaluate(system_, workspace_->stage, initialTime + h,
                    state.waveVortex.t0, workspace_->derivative, metrics_);
  if (!status)
    return status;
  workspace_->weighted.addScaled(workspace_->derivative, 1.0);
  workspace_->stage.copyFrom(baseView);
  workspace_->stage.addScaled(workspace_->weighted, h / 6.0);
  status = constrain(system_, workspace_->stage, initialTime + h,
                     state.waveVortex.t0);
  if (!status)
    return status;
  if (retainDenseOutput_) {
    status =
        evaluate(system_, workspace_->stage, initialTime + h,
                 state.waveVortex.t0, workspace_->finalDerivative, metrics_);
    if (!status)
      return status;
  }
  workspace_->stage.copyTo(state);
  state.waveVortex.t = initialTime + h;
  makeExternalViews(state, workspace_->acceptedViews);
  acceptedStep_ = {initialTime,
                   state.waveVortex.t,
                   {state.waveVortex.view(), workspace_->acceptedViews.data(),
                    workspace_->acceptedViews.size()},
                   retainDenseOutput_ ? 5U : 4U,
                   0,
                   0.0,
                   h};
  ++metrics_.acceptedStepCount;
  hasAcceptedStep_ = true;
  return WVKernelStatus::ok();
}

WVKernelStatus
WVCompositeFixedStepRK4::advanceToTime(WVMutableCompositeState &state,
                                       double finalTime, double h) {
  if (finalTime < state.waveVortex.t || !std::isfinite(finalTime))
    return {WVKernelStatusCode::invalidConfiguration,
            "Composite RK4 cannot advance backward or to a nonfinite time."};
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

WVKernelStatus WVCompositeFixedStepRK4::evaluateDenseOutput(
    double time, WVMutableCompositeState &output) const {
  if (!retainDenseOutput_ || !hasAcceptedStep_)
    return {WVKernelStatusCode::unsupportedOperation,
            "Composite RK4 dense output is unavailable."};
  auto status = validateMutableCompositeState(system_.stateLayout(), output);
  if (!status)
    return status;
  const auto tolerance =
      timeTolerance(acceptedStep_.initialTime, acceptedStep_.finalTime);
  if (time < acceptedStep_.initialTime - tolerance ||
      time > acceptedStep_.finalTime + tolerance)
    return {WVKernelStatusCode::invalidConfiguration,
            "Composite dense-output time is outside the accepted interval."};
  const double h = acceptedStep_.finalTime - acceptedStep_.initialTime;
  double theta = h == 0.0 ? 0.0 : (time - acceptedStep_.initialTime) / h;
  theta = std::max(0.0, std::min(1.0, theta));
  const double theta2 = theta * theta, theta3 = theta2 * theta,
               ew = 3 * theta2 - 2 * theta3, iw = 1 - ew,
               isw = h * (theta - 2 * theta2 + theta3),
               esw = h * (theta3 - theta2);
  workspace_->stage.copyFrom(acceptedStep_.endpoint);
  auto &c = workspace_->stage.complex();
  for (std::size_t i = 0; i < c.size(); ++i) {
    const auto a = workspace_->base.complex()[i], b = c[i],
               k1 = workspace_->initialDerivative.complex()[i],
               k4 = workspace_->finalDerivative.complex()[i];
    c[i] = {iw * a.real + ew * b.real + isw * k1.real + esw * k4.real,
            iw * a.imag + ew * b.imag + isw * k1.imag + esw * k4.imag};
  }
  auto &r = workspace_->stage.real();
  for (std::size_t i = 0; i < r.size(); ++i) {
    const auto a = workspace_->base.real()[i], b = r[i];
    r[i] = iw * a + ew * b + isw * workspace_->initialDerivative.real()[i] +
           esw * workspace_->finalDerivative.real()[i];
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
  return WVKernelStatus::ok();
}

class WVCompositeAdaptiveRK23::Workspace {
public:
  CompositeBuffer base, stage, candidate, k1, k2, k3, k4;
  std::vector<WVAdditionalStateBlockConstView> acceptedViews;
  std::size_t capacityBytes() const noexcept {
    return base.capacityBytes() + stage.capacityBytes() +
           candidate.capacityBytes() + k1.capacityBytes() + k2.capacityBytes() +
           k3.capacityBytes() + k4.capacityBytes();
  }
};

WVCompositeAdaptiveRK23::WVCompositeAdaptiveRK23(
    WVCompositeIntegrationSystem &system,
    WVCompositeAdaptiveRK23Options options)
    : system_(system), options_(options) {}
WVCompositeAdaptiveRK23::~WVCompositeAdaptiveRK23() { delete workspace_; }

WVKernelStatus
WVCompositeAdaptiveRK23::ensureWorkspace(const WVMutableCompositeState &state) {
  auto status = validateMutableCompositeState(system_.stateLayout(), state);
  if (!status)
    return status;
  if (!(options_.relativeTolerance > 0.0) ||
      !(options_.absoluteToleranceScale > 0.0))
    return {WVKernelStatusCode::invalidConfiguration,
            "Composite adaptive tolerances must be positive."};
  if (workspace_)
    return WVKernelStatus::ok();
  try {
    workspace_ = new Workspace;
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Composite RK23 workspace allocation failed."};
  }
  CompositeBuffer *buffers[] = {&workspace_->base,      &workspace_->stage,
                                &workspace_->candidate, &workspace_->k1,
                                &workspace_->k2,        &workspace_->k3,
                                &workspace_->k4};
  for (auto *b : buffers) {
    status = b->initialize(system_.stateLayout());
    if (!status) {
      delete workspace_;
      workspace_ = nullptr;
      return status;
    }
  }
  metrics_.workspaceCapacityBytes = workspace_->capacityBytes();
  metrics_.workspaceMaximumLiveBytes = metrics_.workspaceCapacityBytes;
  return WVKernelStatus::ok();
}

WVKernelStatus WVCompositeAdaptiveRK23::prepareStateAfterRestart(
    WVMutableCompositeState &state) {
  hasAcceptedStep_ = false;
  nextStepSize_ = 0.0;
  auto status = ensureWorkspace(state);
  if (!status)
    return status;
  return system_.enforceStateConstraints(state).status;
}

WVKernelStatus WVCompositeAdaptiveRK23::step(WVMutableCompositeState &state,
                                             double h) {
  if (stepping_)
    return {WVKernelStatusCode::reentrantExecution,
            "Composite RK23 stepping is not reentrant."};
  if (!(h > 0.0) || !std::isfinite(h))
    return {WVKernelStatusCode::invalidConfiguration,
            "Composite RK23 step size must be finite and positive."};
  auto status = ensureWorkspace(state);
  if (!status)
    return status;
  stepping_ = true;
  struct Guard {
    bool &v;
    ~Guard() { v = false; }
  } guard{stepping_};
  hasAcceptedStep_ = false;
  std::vector<WVAdditionalStateBlockConstView> views;
  const auto baseView = compositeConstView(state, views);
  workspace_->base.copyFrom(baseView);
  const auto t = state.waveVortex.t, t0 = state.waveVortex.t0;
  status = evaluate(system_, workspace_->base, t, t0, workspace_->k1, metrics_);
  if (!status)
    return status;
  for (;;) {
    workspace_->stage.setAffine(baseView, workspace_->k1, 0.5 * h);
    status = constrain(system_, workspace_->stage, t + 0.5 * h, t0);
    if (!status)
      return status;
    status = evaluate(system_, workspace_->stage, t + 0.5 * h, t0,
                      workspace_->k2, metrics_);
    if (!status)
      return status;
    workspace_->stage.setAffine(baseView, workspace_->k2, 0.75 * h);
    status = constrain(system_, workspace_->stage, t + 0.75 * h, t0);
    if (!status)
      return status;
    status = evaluate(system_, workspace_->stage, t + 0.75 * h, t0,
                      workspace_->k3, metrics_);
    if (!status)
      return status;
    workspace_->candidate.setWeightedCandidate(
        baseView, h, workspace_->k1, 2.0 / 9.0, workspace_->k2, 1.0 / 3.0,
        workspace_->k3, 4.0 / 9.0);
    status = constrain(system_, workspace_->candidate, t + h, t0);
    if (!status)
      return status;
    status = evaluate(system_, workspace_->candidate, t + h, t0, workspace_->k4,
                      metrics_);
    if (!status)
      return status;
    double sum = 0.0;
    std::size_t count = 0;
    const auto &bc = workspace_->base.complex();
    const auto &cc = workspace_->candidate.complex();
    for (std::size_t i = 0; i < bc.size(); ++i) {
      const auto e = WVComplex64{
          h * ((2.0 / 9.0 - 7.0 / 24.0) * workspace_->k1.complex()[i].real +
               (1.0 / 3.0 - 0.25) * workspace_->k2.complex()[i].real +
               (4.0 / 9.0 - 1.0 / 3.0) * workspace_->k3.complex()[i].real -
               0.125 * workspace_->k4.complex()[i].real),
          h * ((2.0 / 9.0 - 7.0 / 24.0) * workspace_->k1.complex()[i].imag +
               (1.0 / 3.0 - 0.25) * workspace_->k2.complex()[i].imag +
               (4.0 / 9.0 - 1.0 / 3.0) * workspace_->k3.complex()[i].imag -
               0.125 * workspace_->k4.complex()[i].imag)};
      const auto absTol = complexAbsoluteTolerance(
          system_, workspace_->base, i, options_.absoluteToleranceScale);
      const auto valueScale =
          absTol + options_.relativeTolerance *
                       std::max(std::hypot(bc[i].real, bc[i].imag),
                                std::hypot(cc[i].real, cc[i].imag));
      sum += (e.real * e.real + e.imag * e.imag) / (valueScale * valueScale);
      count += 2;
    }
    const auto &br = workspace_->base.real();
    const auto &cr = workspace_->candidate.real();
    std::size_t realOffset = 0;
    for (const auto &block : system_.stateLayout().additionalBlocks()) {
      if (block.scalarType != WVStateScalarType::real64)
        continue;
      for (std::size_t j = 0; j < block.elementCount; ++j) {
        const auto i = realOffset + j;
        const double e =
            h * ((2.0 / 9.0 - 7.0 / 24.0) * workspace_->k1.real()[i] +
                 (1.0 / 3.0 - 0.25) * workspace_->k2.real()[i] +
                 (4.0 / 9.0 - 1.0 / 3.0) * workspace_->k3.real()[i] -
                 0.125 * workspace_->k4.real()[i]);
        const auto scale =
            block.absoluteTolerance * options_.absoluteToleranceScale +
            options_.relativeTolerance *
                std::max(std::abs(br[i]), std::abs(cr[i]));
        sum += (e / scale) * (e / scale);
        ++count;
      }
      realOffset += block.elementCount;
    }
    const double error =
        count ? std::sqrt(sum / static_cast<double>(count)) : 0.0;
    const bool accepted = error <= 1.0;
    double factor = error == 0.0
                        ? options_.maximumStepFactor
                        : options_.safetyFactor * std::pow(error, -1.0 / 3.0);
    factor = std::max(options_.minimumStepFactor,
                      std::min(options_.maximumStepFactor, factor));
    nextStepSize_ = h * factor;
    if (accepted) {
      workspace_->candidate.copyTo(state);
      state.waveVortex.t = t + h;
      makeExternalViews(state, workspace_->acceptedViews);
      acceptedStep_ = {t,
                       state.waveVortex.t,
                       {state.waveVortex.view(),
                        workspace_->acceptedViews.data(),
                        workspace_->acceptedViews.size()},
                       metrics_.rightHandSideEvaluationCount,
                       metrics_.rejectedStepCount,
                       error,
                       nextStepSize_};
      ++metrics_.acceptedStepCount;
      hasAcceptedStep_ = true;
      return WVKernelStatus::ok();
    }
    ++metrics_.rejectedStepCount;
    h = nextStepSize_;
    if (!(h > 0.0) || t + h == t)
      return {WVKernelStatusCode::numericalFailure,
              "Composite RK23 step size underflowed after rejection."};
  }
}

WVKernelStatus
WVCompositeAdaptiveRK23::advanceToTime(WVMutableCompositeState &state,
                                       double finalTime, double h) {
  if (finalTime < state.waveVortex.t || !std::isfinite(finalTime))
    return {WVKernelStatusCode::invalidConfiguration,
            "Composite RK23 cannot advance backward or to a nonfinite time."};
  while (state.waveVortex.t < finalTime) {
    const auto use = std::min(h, finalTime - state.waveVortex.t);
    const auto status = step(state, use);
    if (!status)
      return status;
    h = nextStepSize_;
  }
  state.waveVortex.t = finalTime;
  return WVKernelStatus::ok();
}

WVKernelStatus WVCompositeAdaptiveRK23::evaluateDenseOutput(
    double time, WVMutableCompositeState &output) const {
  if (!hasAcceptedStep_)
    return {WVKernelStatusCode::unsupportedOperation,
            "Composite RK23 dense output is unavailable."};
  auto status = validateMutableCompositeState(system_.stateLayout(), output);
  if (!status)
    return status;
  const double h = acceptedStep_.finalTime - acceptedStep_.initialTime;
  const auto tol =
      timeTolerance(acceptedStep_.initialTime, acceptedStep_.finalTime);
  if (time < acceptedStep_.initialTime - tol ||
      time > acceptedStep_.finalTime + tol)
    return {WVKernelStatusCode::invalidConfiguration,
            "Composite dense-output time is outside the accepted interval."};
  double theta = h == 0 ? 0 : (time - acceptedStep_.initialTime) / h;
  theta = std::max(0.0, std::min(1.0, theta));
  const double t2 = theta * theta, t3 = t2 * theta, ew = 3 * t2 - 2 * t3,
               iw = 1 - ew, isw = h * (theta - 2 * t2 + t3),
               esw = h * (t3 - t2);
  workspace_->stage.copyFrom(acceptedStep_.endpoint);
  for (std::size_t i = 0; i < workspace_->stage.complex().size(); ++i) {
    const auto a = workspace_->base.complex()[i],
               b = workspace_->stage.complex()[i],
               k1 = workspace_->k1.complex()[i],
               k4 = workspace_->k4.complex()[i];
    workspace_->stage.complex()[i] = {
        iw * a.real + ew * b.real + isw * k1.real + esw * k4.real,
        iw * a.imag + ew * b.imag + isw * k1.imag + esw * k4.imag};
  }
  for (std::size_t i = 0; i < workspace_->stage.real().size(); ++i) {
    const auto a = workspace_->base.real()[i], b = workspace_->stage.real()[i];
    workspace_->stage.real()[i] = iw * a + ew * b +
                                  isw * workspace_->k1.real()[i] +
                                  esw * workspace_->k4.real()[i];
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
  return WVKernelStatus::ok();
}

} // namespace wavevortex::runtime
