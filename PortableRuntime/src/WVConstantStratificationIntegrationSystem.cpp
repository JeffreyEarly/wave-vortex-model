#include "WaveVortexRuntime/WVConstantStratificationIntegrationSystem.hpp"
#include "WVObserverAdapter.hpp"

#include <algorithm>
#include <chrono>
#include <limits>
#include <new>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

std::size_t blockIndex(const WVIntegrationStateLayout &layout,
                       const std::string &identifier) {
  const auto &blocks = layout.additionalBlocks();
  const auto found = std::find_if(
      blocks.begin(), blocks.end(), [&](const auto &candidate) {
        return candidate.identifier == identifier;
      });
  return found == blocks.end()
             ? std::numeric_limits<std::size_t>::max()
             : static_cast<std::size_t>(found - blocks.begin());
}

class UnifiedErrorPolicy final : public WVIntegrationErrorPolicy {
public:
  UnifiedErrorPolicy(std::unique_ptr<WVIntegrationErrorPolicy> coefficients,
                     const WVIntegrationStateLayout &layout, double scale)
      : coefficients_(std::move(coefficients)) {
    counts_.reserve(3 + layout.additionalBlocks().size());
    tolerances_.reserve(3 + layout.additionalBlocks().size());
    for (std::size_t component = 0; component < 3; ++component) {
      counts_.push_back(coefficients_->elementCount(component));
      tolerances_.push_back(0.0);
    }
    for (const auto &block : layout.additionalBlocks()) {
      counts_.push_back(block.elementCount);
      tolerances_.push_back(block.absoluteTolerance * scale);
    }
  }

  std::size_t componentCount() const noexcept override {
    return counts_.size();
  }
  std::size_t elementCount(std::size_t component) const noexcept override {
    return component < counts_.size() ? counts_[component] : 0;
  }
  double absoluteTolerance(std::size_t component,
                           std::size_t index) const noexcept override {
    if (component < 3)
      return coefficients_->absoluteTolerance(component, index);
    return component < tolerances_.size() ? tolerances_[component] : 0.0;
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this) + coefficients_->persistentBytes() +
           counts_.capacity() * sizeof(std::size_t) +
           tolerances_.capacity() * sizeof(double);
  }

private:
  std::unique_ptr<WVIntegrationErrorPolicy> coefficients_;
  std::vector<std::size_t> counts_;
  std::vector<double> tolerances_;
};

} // namespace

WVKernelStatus WVConstantStratificationIntegrationSystem::create(
    const WVTransformConstantStratificationConfiguration &configuration,
    const WVFrozenForcingSchedule &schedule,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVConstantStratificationIntegrationSystem> &system) {
  return createImpl(configuration, schedule, nullptr, std::move(engine), system);
}

WVKernelStatus WVConstantStratificationIntegrationSystem::create(
    const WVTransformConstantStratificationConfiguration &configuration,
    const WVFrozenForcingSchedule &schedule,
    const WVPortableObserverDescriptor &descriptor,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVConstantStratificationIntegrationSystem> &system) {
  return createImpl(configuration, schedule, &descriptor, std::move(engine),
                    system);
}

WVKernelStatus WVConstantStratificationIntegrationSystem::createImpl(
    const WVTransformConstantStratificationConfiguration &configuration,
    const WVFrozenForcingSchedule &schedule,
    const WVPortableObserverDescriptor *descriptor,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVConstantStratificationIntegrationSystem> &system) {
  system.reset();
  try {
    auto candidate =
        std::unique_ptr<WVConstantStratificationIntegrationSystem>(
            new WVConstantStratificationIntegrationSystem());
    auto status = WVConstantStratificationForcingEngine::create(
        configuration, schedule, std::move(engine), candidate->forcing_);
    if (!status)
      return status;
    const auto coefficientShape =
        candidate->forcing_->kernel().descriptor().spectralShape();
    status = descriptor == nullptr
                 ? WVIntegrationStateLayout::createCoefficientOnly(
                       coefficientShape, candidate->layout_)
                 : WVIntegrationStateLayout::create(
                       coefficientShape, *descriptor, candidate->layout_);
    if (!status)
      return status;

    std::vector<std::size_t> ownerCounts(
        candidate->layout_.additionalBlocks().size(), 0);
    std::vector<WVMovingFieldRequest> velocityRequests;
    std::size_t positionOffset = 0;
    static const std::vector<WVObserverRecord> noObservers;
    const auto &observers =
        descriptor == nullptr ? noObservers : descriptor->observers();
    for (const auto &observer : observers) {
      const auto *definition = detail::observerDefinition(observer.kind);
      if (definition == nullptr)
        return {WVKernelStatusCode::unsupportedOperation,
                "Integration system received an unsupported observer."};
      if (definition->stateContract ==
          WVObserverStateContract::tracerField) {
        const auto block = blockIndex(
            candidate->layout_, observer.stateBlockIdentifiers.front());
        if (block == std::numeric_limits<std::size_t>::max())
          return invalid(
              "Tracer state block is absent from the integration layout.");
        const auto &dimensions =
            candidate->layout_.additionalBlocks()[block].dimensions;
        if (observer.isXYOnly) {
          if (dimensions != std::vector<std::size_t>(
                                {configuration.Nx, configuration.Ny}))
            return {WVKernelStatusCode::invalidShape,
                    "A two-dimensional tracer must have shape [Nx,Ny]."};
          return {WVKernelStatusCode::unsupportedOperation,
                  "Two-dimensional tracer integration requires a future barotropic runtime; the constant-stratification runtime supports three-dimensional tracers only."};
        }
        if (dimensions != std::vector<std::size_t>(
                              {configuration.Nx, configuration.Ny,
                               configuration.Nz}))
          return {WVKernelStatusCode::invalidShape,
                  "A constant-stratification tracer must have shape [Nx,Ny,Nz]."};
        ++ownerCounts[block];
        WVTracer tracer;
        tracer.record_ = observer;
        tracer.stateBlock_ = block;
        candidate->tracers_.push_back(std::move(tracer));
        continue;
      }
      if (definition->stateContract !=
          WVObserverStateContract::particlePosition)
        continue;
      if (observer.isXYOnly && observer.z.size() != observer.x.size())
        return invalid("Constant-stratification XY particles require one fixed "
                       "z coordinate per particle.");
      WVLagrangianParticles particles;
      particles.record_ = observer;
      particles.particleCount_ = observer.x.size();
      particles.positionOffset_ = positionOffset;
      particles.xBlock_ = blockIndex(candidate->layout_,
                                     observer.stateBlockIdentifiers[0]);
      particles.yBlock_ = blockIndex(candidate->layout_,
                                     observer.stateBlockIdentifiers[1]);
      particles.zBlock_ = observer.isXYOnly
                              ? std::numeric_limits<std::size_t>::max()
                              : blockIndex(candidate->layout_,
                                           observer.stateBlockIdentifiers[2]);
      if (particles.xBlock_ == std::numeric_limits<std::size_t>::max() ||
          particles.yBlock_ == std::numeric_limits<std::size_t>::max() ||
          (!observer.isXYOnly &&
           particles.zBlock_ == std::numeric_limits<std::size_t>::max()))
        return invalid("Particle state blocks are absent from the integration "
                       "layout or appear in an incompatible order.");
      ++ownerCounts[particles.xBlock_];
      ++ownerCounts[particles.yBlock_];
      if (!observer.isXYOnly)
        ++ownerCounts[particles.zBlock_];
      const auto addVelocity = [&](const char *field) {
        const auto output = velocityRequests.size();
        velocityRequests.push_back(
            {observer.identifier + '-' + field, field, positionOffset,
             particles.particleCount_, observer.advectionInterpolation});
        return output;
      };
      particles.uOutput_ = addVelocity("u");
      particles.vOutput_ = addVelocity("v");
      particles.wOutput_ = observer.isXYOnly
                               ? std::numeric_limits<std::size_t>::max()
                               : addVelocity("w");
      positionOffset += particles.particleCount_;
      candidate->particles_.push_back(std::move(particles));
    }
    for (std::size_t block = 0; block < ownerCounts.size(); ++block) {
      if (ownerCounts[block] != 1)
        return invalid("Integration state block " +
                       candidate->layout_.additionalBlocks()[block].identifier +
                       " must resolve to exactly one integrated observer.");
    }

    const bool requiresScalarAntialiasPlan = std::any_of(
        candidate->tracers_.begin(), candidate->tracers_.end(),
        [](const auto &tracer) { return tracer.shouldAntialias(); });
    if (requiresScalarAntialiasPlan) {
      status = candidate->forcing_->kernel().prepareScalarAdvection();
      if (!status)
        return status;
    }

    // Coefficient-only integration is the zero-additional-block case. It must
    // not retain the field-evaluation scratch used by observing systems.
    if (!observers.empty()) {
      status = WVFieldEvaluationService::createBorrowing(
          candidate->forcing_->kernel(), candidate->fields_);
      if (!status)
        return status;
      status = candidate->fields_->createMovingPlan(
          velocityRequests, candidate->velocityPlan_);
      if (!status)
        return status;
    }
    candidate->x_.resize(positionOffset);
    candidate->y_.resize(positionOffset);
    candidate->z_.resize(positionOffset);
    candidate->velocityStorage_.resize(velocityRequests.size());
    candidate->velocityViews_.resize(velocityRequests.size());
    for (std::size_t index = 0; index < velocityRequests.size(); ++index) {
      candidate->velocityStorage_[index].resize(
          velocityRequests[index].positionCount);
      candidate->velocityViews_[index] = {
          candidate->velocityStorage_[index].data(),
          candidate->velocityStorage_[index].size()};
    }
    candidate->metrics_.positionCapacityBytes =
        (candidate->x_.capacity() + candidate->y_.capacity() +
         candidate->z_.capacity()) *
        sizeof(double);
    for (const auto &values : candidate->velocityStorage_)
      candidate->metrics_.velocityCapacityBytes +=
          values.capacity() * sizeof(double);
    candidate->metrics_.persistentBytes = candidate->persistentBytes();
    system = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate the constant-stratification particle system."};
  }
}

WVConstantStratificationIntegrationSystem::~WVConstantStratificationIntegrationSystem() =
    default;

WVKernelStatus
WVConstantStratificationIntegrationSystem::evaluateRightHandSide(
    const WVIntegrationState &state, WVIntegrationFlux &rightHandSide) {
  const auto rightHandSideStarted = std::chrono::steady_clock::now();
  if (executing_)
    return {WVKernelStatusCode::reentrantExecution,
            "The constant-stratification integration system is not reentrant."};
  auto status = validateIntegrationState(layout_, state);
  if (!status)
    return status;
  if (rightHandSide.additionalBlockCount != layout_.additionalBlocks().size() ||
      (rightHandSide.additionalBlockCount != 0 &&
       rightHandSide.additionalBlocks == nullptr))
    return {WVKernelStatusCode::invalidShape,
            "Integration RHS storage does not match the frozen layout."};
  executing_ = true;
  struct Guard {
    bool &value;
    ~Guard() { value = false; }
  } guard{executing_};
  const bool needsAdvectionContext = !particles_.empty() || !tracers_.empty();
  WVConstantStratificationRightHandSideContext context;
  auto advectionStorage = needsAdvectionContext
                              ? fields_->advectionFieldStorage()
                              : WVRealFieldBundleView{};
  const auto waveVortexFluxStarted = std::chrono::steady_clock::now();
  status = !needsAdvectionContext
               ? forcing_->nonlinearFlux(state.waveVortex,
                                         rightHandSide.waveVortex)
               : forcing_->evaluateRightHandSideWithContext(
                     state.waveVortex, rightHandSide.waveVortex,
                     advectionStorage, context);
  if (!status)
    return status;
  metrics_.waveVortexFluxSeconds += std::chrono::duration<double>(
      std::chrono::steady_clock::now() - waveVortexFluxStarted).count();
  if (needsAdvectionContext) ++metrics_.sharedRightHandSideContextCount;
  const auto additionalStateClearStarted = std::chrono::steady_clock::now();
  for (std::size_t block = 0; block < rightHandSide.additionalBlockCount;
       ++block) {
    const auto &layout = *rightHandSide.additionalBlocks[block].layout;
    if (layout.scalarType == WVStateScalarType::real64)
      std::fill_n(rightHandSide.additionalBlocks[block].realData,
                  layout.elementCount, 0.0);
    else
      std::fill_n(rightHandSide.additionalBlocks[block].complexData,
                  layout.elementCount, WVComplex64{});
  }
  metrics_.additionalStateClearSeconds += std::chrono::duration<double>(
      std::chrono::steady_clock::now() - additionalStateClearStarted).count();
  for (const auto &particles : particles_) {
    const auto offset = particles.positionOffset_;
    const auto count = particles.particleCount_;
    std::copy_n(state.additionalBlocks[particles.xBlock_].realData, count,
                x_.data() + offset);
    std::copy_n(state.additionalBlocks[particles.yBlock_].realData, count,
                y_.data() + offset);
    if (particles.isXYOnly())
      std::copy(particles.record_.z.begin(), particles.record_.z.end(),
                z_.data() + offset);
    else
      std::copy_n(state.additionalBlocks[particles.zBlock_].realData, count,
                  z_.data() + offset);
  }
  const auto spatial = forcing_->kernel().descriptor().spatialShape();
  const auto tracerStarted = std::chrono::steady_clock::now();
  for (const auto &tracer : tracers_) {
    const auto &input = state.additionalBlocks[tracer.stateBlock_];
    auto &output = rightHandSide.additionalBlocks[tracer.stateBlock_];
    const WVRealVolumeConstView scalar{
        input.realData, {spatial.first, spatial.second, spatial.third}};
    WVRealVolumeView tracerFlux{
        output.realData, {spatial.first, spatial.second, spatial.third}};
    status = forcing_->advectFGridScalar(
        context, scalar, tracer.shouldAntialias(), tracerFlux);
    if (!status)
      return status;
    ++metrics_.tracerEvaluationCount;
    metrics_.tracerValueWriteCount += spatial.elementCount();
    if (tracer.shouldAntialias())
      ++metrics_.antialiasedTracerEvaluationCount;
  }
  metrics_.tracerAdvectionSeconds += std::chrono::duration<double>(
      std::chrono::steady_clock::now() - tracerStarted).count();
  const auto particleStarted = std::chrono::steady_clock::now();
  if (!particles_.empty()) {
    status = fields_->evaluateMovingFromAdvectionFields(
        velocityPlan_, state.waveVortex, context.advectionFields(),
        {x_.data(), y_.data(), z_.data(), x_.size()}, velocityViews_.data(),
        velocityViews_.size());
    if (!status)
      return status;
    ++metrics_.velocityFieldEvaluationCount;
  }
  for (const auto &particles : particles_) {
    const auto count = particles.particleCount_;
    std::copy_n(velocityStorage_[particles.uOutput_].data(), count,
                rightHandSide.additionalBlocks[particles.xBlock_].realData);
    std::copy_n(velocityStorage_[particles.vOutput_].data(), count,
                rightHandSide.additionalBlocks[particles.yBlock_].realData);
    if (!particles.isXYOnly())
      std::copy_n(velocityStorage_[particles.wOutput_].data(), count,
                  rightHandSide.additionalBlocks[particles.zBlock_].realData);
    metrics_.particleValueWriteCount +=
        count * (particles.isXYOnly() ? 2 : 3);
  }
  metrics_.particleAdvectionSeconds += std::chrono::duration<double>(
      std::chrono::steady_clock::now() - particleStarted).count();
  ++metrics_.rightHandSideEvaluationCount;
  metrics_.rightHandSideSeconds += std::chrono::duration<double>(
      std::chrono::steady_clock::now() - rightHandSideStarted).count();
  return WVKernelStatus::ok();
}

WVStateConstraintResult
WVConstantStratificationIntegrationSystem::enforceStateConstraints(
    WVMutableIntegrationState &state) {
  const auto status = validateMutableIntegrationState(layout_, state);
  if (!status)
    return {status, 0, false};
  return forcing_->restoreForcingAmplitudes(state.waveVortex.coefficients);
}

WVKernelStatus
WVConstantStratificationIntegrationSystem::initializeParticleState(
    WVMutableIntegrationState &state) const {
  const auto status = validateMutableIntegrationState(layout_, state);
  if (!status)
    return status;
  for (const auto &particles : particles_) {
    std::copy(particles.record_.x.begin(), particles.record_.x.end(),
              state.additionalBlocks[particles.xBlock_].realData);
    std::copy(particles.record_.y.begin(), particles.record_.y.end(),
              state.additionalBlocks[particles.yBlock_].realData);
    if (!particles.isXYOnly())
      std::copy(particles.record_.z.begin(), particles.record_.z.end(),
                state.additionalBlocks[particles.zBlock_].realData);
  }
  return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationIntegrationSystem::createErrorPolicy(
    double absoluteToleranceScale,
    std::unique_ptr<WVIntegrationErrorPolicy> &policy) const {
  policy.reset();
  std::unique_ptr<WVIntegrationErrorPolicy> coefficients;
  auto status = forcing_->createErrorPolicy(absoluteToleranceScale, coefficients);
  if (!status)
    return status;
  try {
    policy = std::make_unique<UnifiedErrorPolicy>(
        std::move(coefficients), layout_, absoluteToleranceScale);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Integration error-policy allocation failed."};
  }
}

std::size_t
WVConstantStratificationIntegrationSystem::persistentBytes() const noexcept {
  std::size_t bytes = sizeof(*this) + layout_.persistentBytes() +
                      forcing_->persistentBytes() +
                      (fields_ ? fields_->persistentBytes() : 0) +
                      velocityPlan_.persistentBytes() +
                      particles_.capacity() * sizeof(WVLagrangianParticles) +
                      tracers_.capacity() * sizeof(WVTracer) +
                      metrics_.positionCapacityBytes +
                      metrics_.velocityCapacityBytes +
                      velocityViews_.capacity() * sizeof(WVFieldOutputView);
  for (const auto &particles : particles_)
    bytes += particles.record_.identifier.capacity() +
             particles.record_.name.capacity();
  for (const auto &tracer : tracers_)
    bytes += tracer.record_.identifier.capacity() +
             tracer.record_.name.capacity();
  return bytes;
}

} // namespace wavevortex::runtime
