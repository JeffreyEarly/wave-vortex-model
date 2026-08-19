#include "WaveVortexRuntime/WVModel.hpp"
#include "WaveVortexRuntime/WVForcingContracts.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <new>
#include <set>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
WVKernelStatus fromCheckpoint(const WVCheckpointStatus &status) {
  if (status)
    return WVKernelStatus::ok();
  return {status.code == WVCheckpointStatusCode::unsupportedObserver
              ? WVKernelStatusCode::unsupportedOperation
              : WVKernelStatusCode::invalidConfiguration,
          status.message +
              (status.location.empty() ? "" : " [" + status.location + "]")};
}

const std::string *remappedDestination(
    const std::vector<WVModelOutputDestination> &destinations,
    const std::string &identifier) {
  const auto found =
      std::find_if(destinations.begin(), destinations.end(),
                   [&](const auto &candidate) {
                     return candidate.fileIdentifier == identifier;
                   });
  return found == destinations.end() ? nullptr : &found->path;
}

WVKernelStatus compileOutputConfiguration(
    const WVModelOutputNetCDFInspection &inspection,
    const WVModelOutputRequest &request,
    WVModelOutputConfiguration &configuration) {
  if (!std::isfinite(request.finalTime) ||
      request.finalTime < inspection.latestRestart.state.t)
    return invalid("The output request final time must be finite and cannot "
                   "precede the selected restart state.");
  std::set<std::string> requestedIdentifiers;
  for (const auto &destination : request.destinations) {
    if (destination.fileIdentifier.empty() || destination.path.empty() ||
        !requestedIdentifiers.insert(destination.fileIdentifier).second)
      return invalid("Output destination remapping requires unique nonempty "
                     "file identifiers and paths.");
  }
  if ((request.policy == WVModelOutputPolicy::create ||
       request.policy == WVModelOutputPolicy::replace ||
       !request.destinations.empty()) &&
      request.destinations.size() != inspection.observerRecord.outputFiles.size())
    return invalid("Output destination remapping requires one destination for "
                   "every output-file identifier.");

  std::vector<WVModelOutputFile> files;
  files.reserve(inspection.observerRecord.outputFiles.size());
  for (const auto &record : inspection.observerRecord.outputFiles) {
    const auto *mapped = remappedDestination(request.destinations,
                                             record.identifier);
    if (mapped == nullptr && !request.destinations.empty())
      return invalid("The output destination map is incomplete.");
    const std::string &path = mapped == nullptr ? record.destination : *mapped;
    WVModelOutputFile file;
    auto status = WVModelOutputFile::create(path, file, record.identifier);
    if (!status)
      return status;
    for (const auto &groupRecord : record.groups) {
      WVModelOutputGroup *group = nullptr;
      status = file.addNewEvenlySpacedOutputGroup(
          groupRecord.name, groupRecord.schedule.outputInterval,
          groupRecord.schedule.initialTime, groupRecord.schedule.finalTime,
          group, groupRecord.identifier);
      if (!status)
        return status;
      for (const auto &observer : groupRecord.observerIdentifiers) {
        status = group->addObservingSystem(observer);
        if (!status)
          return status;
      }
      status = group->containsCompleteCoefficientRestart(
          groupRecord.containsCompleteCoefficientRestart);
      if (!status)
        return status;
      if (request.policy == WVModelOutputPolicy::append) {
        const auto progress = std::find_if(
            inspection.progress.begin(), inspection.progress.end(),
            [&](const auto &candidate) {
              return candidate.fileIdentifier == record.identifier &&
                     candidate.groupIdentifier == groupRecord.identifier;
            });
        if (progress == inspection.progress.end())
          return invalid("The inspected output graph has incomplete committed "
                         "progress.");
        status = group->committedOrdinal(progress->committedOrdinal);
        if (!status)
          return status;
      }
    }
    files.push_back(std::move(file));
  }
  if (requestedIdentifiers.size() != request.destinations.size())
    return invalid("The output destination map is invalid.");
  for (const auto &identifier : requestedIdentifiers) {
    const auto found = std::find_if(
        inspection.observerRecord.outputFiles.begin(),
        inspection.observerRecord.outputFiles.end(), [&](const auto &file) {
          return file.identifier == identifier;
        });
    if (found == inspection.observerRecord.outputFiles.end())
      return invalid("The output destination map contains an unknown file "
                     "identifier.");
  }
  return WVModelOutputConfiguration::build(
      inspection.observerRecord, std::move(files), request.policy,
      inspection.latestRestart.state.t, request.finalTime, configuration);
}
#endif

WVKernelStatus copyAdditionalState(const WVAdditionalStateStorage &source,
                                   WVAdditionalStateStorage &destination) {
  const auto *sourceBlocks = source.constBlocks();
  for (std::size_t destinationIndex = 0;
       destinationIndex < destination.blockCount(); ++destinationIndex) {
    auto &target = destination.mutableBlocks()[destinationIndex];
    const WVAdditionalStateBlockConstView *matching = nullptr;
    for (std::size_t sourceIndex = 0; sourceIndex < source.blockCount();
         ++sourceIndex) {
      if (sourceBlocks[sourceIndex].layout->identifier ==
          target.layout->identifier) {
        matching = sourceBlocks + sourceIndex;
        break;
      }
    }
    if (matching == nullptr ||
        matching->layout->scalarType != target.layout->scalarType ||
        matching->layout->elementCount != target.layout->elementCount)
      return invalid("Restored observer state does not match the model state "
                     "layout.");
    if (target.realData != nullptr)
      std::copy_n(matching->realData, target.layout->elementCount,
                  target.realData);
    else
      std::copy_n(matching->complexData, target.layout->elementCount,
                  target.complexData);
  }
  return WVKernelStatus::ok();
}

} // namespace

WVKernelStatus WVModelState::create(
    WVCheckpoint checkpoint, const WVIntegrationStateLayout &layout,
    WVModelState &state,
    const WVAdditionalStateStorage *restoredAdditionalState) {
  const auto expectedShape = layout.coefficientShape();
  if (checkpoint.state.coefficients.shape.rows != expectedShape.rows ||
      checkpoint.state.coefficients.shape.columns != expectedShape.columns)
    return invalid("Checkpoint coefficients do not match the model state "
                   "layout.");
  const auto count = expectedShape.elementCount();
  if (checkpoint.state.coefficients.Ap.size() != count ||
      checkpoint.state.coefficients.Am.size() != count ||
      checkpoint.state.coefficients.A0.size() != count)
    return invalid("Checkpoint coefficient storage is incomplete.");
  try {
    WVModelState candidate;
    auto status = candidate.additionalState_.initialize(layout);
    if (!status)
      return status;
    if (restoredAdditionalState != nullptr) {
      status = copyAdditionalState(*restoredAdditionalState,
                                   candidate.additionalState_);
      if (!status)
        return status;
    }
    candidate.checkpoint_ = std::move(checkpoint);
    state = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "WVModel state allocation failed."};
  }
}

WVMutableIntegrationState WVModelState::mutableView() noexcept {
  const auto shape = checkpoint_.state.coefficients.shape;
  return {{checkpoint_.state.t,
           checkpoint_.state.t0,
           {{checkpoint_.state.coefficients.Ap.data(), shape},
            {checkpoint_.state.coefficients.Am.data(), shape},
            {checkpoint_.state.coefficients.A0.data(), shape}}},
          additionalState_.mutableBlocks(), additionalState_.blockCount()};
}

WVIntegrationState WVModelState::constView() {
  auto mutableState = mutableView();
  return integrationConstView(mutableState, constViews_);
}

std::size_t WVModelState::persistentBytes() const noexcept {
  return sizeof(*this) +
         (checkpoint_.state.coefficients.Ap.capacity() +
          checkpoint_.state.coefficients.Am.capacity() +
          checkpoint_.state.coefficients.A0.capacity()) *
             sizeof(WVComplex64) +
         additionalState_.capacityBytes() +
         constViews_.capacity() * sizeof(WVAdditionalStateBlockConstView);
}

class WVModel::Impl final {
public:
  WVKernelStatus configureIntegrator(
      const WVModelIntegratorConfiguration &configuration);

  std::unique_ptr<WVConstantStratificationIntegrationSystem> system;
  std::unique_ptr<WVTimeIntegrator> integrator;
  WVModelIntegratorKind integratorKind = WVModelIntegratorKind::fixedRK4;
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  std::unique_ptr<WVModelOutputConfiguration> outputConfiguration;
  std::unique_ptr<WVObserverOutputEvaluationService> outputEvaluation;
  WVModelOutputNetCDFSink outputSink;
  WVModelOutputNetCDFMetrics outputMetrics;
  double outputFinalTime = 0.0;
  bool outputOpen = false;
#endif
  WVOutputDriverMetrics outputDriverMetrics;
};

WVModel::WVModel() : impl_(std::make_unique<Impl>()) {}
WVModel::~WVModel() = default;
WVModel::WVModel(WVModel &&) noexcept = default;
WVModel &WVModel::operator=(WVModel &&) noexcept = default;

WVKernelStatus WVModel::Impl::configureIntegrator(
    const WVModelIntegratorConfiguration &configuration) {
  try {
    if (configuration.kind == WVModelIntegratorKind::adaptiveRK23)
      integrator =
          std::make_unique<WVAdaptiveRK23>(*system,
                                           configuration.adaptive);
    else
      integrator =
          std::make_unique<WVFixedStepRK4>(*system, configuration.fixed);
    integratorKind = configuration.kind;
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "WVModel integrator allocation failed."};
  }
}

WVKernelStatus WVModel::create(
    const WVTransformConstantStratificationConfiguration &configuration,
    const WVFrozenForcingSchedule &forcingSchedule,
    std::unique_ptr<WVFFTEngine> engine,
    const WVModelIntegratorConfiguration &integratorConfiguration,
    WVModel &model) {
  try {
    auto candidate = std::make_unique<Impl>();
    auto status = WVConstantStratificationIntegrationSystem::create(
        configuration, forcingSchedule, std::move(engine), candidate->system);
    if (!status)
      return status;
    status = candidate->configureIntegrator(integratorConfiguration);
    if (!status)
      return status;
    model.impl_ = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "WVModel allocation failed."};
  }
}

WVKernelStatus WVModel::createFromModelOutputFiles(
    const std::vector<std::string> &paths,
    const WVModelOutputRequest &outputRequest,
    std::unique_ptr<WVFFTEngine> engine,
    const WVModelIntegratorConfiguration &integratorConfiguration,
    WVModel &model, WVModelState &state) {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  if (paths.empty())
    return invalid("At least one model-output NetCDF path is required.");
  WVModelOutputNetCDFInspection inspection;
  auto checkpointStatus = WVModelOutputNetCDFSink::inspect(paths, inspection);
  if (!checkpointStatus)
    return fromCheckpoint(checkpointStatus);

  return createFromModelOutputInspection(
      std::move(inspection), outputRequest, std::move(engine),
      integratorConfiguration, model, state);
#else
  (void)paths;
  (void)outputRequest;
  (void)engine;
  (void)integratorConfiguration;
  (void)model;
  (void)state;
  return {WVKernelStatusCode::unsupportedOperation,
          "This adapter does not include model-output persistence."};
#endif
}

WVKernelStatus WVModel::createFromModelOutputInspection(
    WVModelOutputNetCDFInspection inspection,
    const WVModelOutputRequest &outputRequest,
    std::unique_ptr<WVFFTEngine> engine,
    const WVModelIntegratorConfiguration &integratorConfiguration,
    WVModel &model, WVModelState &state) {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT

  WVModelOutputConfiguration outputConfiguration;
  auto status = prepareModelOutput(inspection, outputRequest,
                                   outputConfiguration);
  if (!status)
    return status;
  return createFromModelOutputInspection(
      std::move(inspection), std::move(outputConfiguration),
      std::move(engine), integratorConfiguration, model, state);
#else
  (void)inspection;
  (void)outputRequest;
  (void)engine;
  (void)integratorConfiguration;
  (void)model;
  (void)state;
  return {WVKernelStatusCode::unsupportedOperation,
          "This adapter does not include model-output persistence."};
#endif
}

WVKernelStatus WVModel::prepareModelOutput(
    const WVModelOutputNetCDFInspection &inspection,
    const WVModelOutputRequest &outputRequest,
    WVModelOutputConfiguration &configuration) {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  return compileOutputConfiguration(inspection, outputRequest,
                                    configuration);
#else
  (void)inspection;
  (void)outputRequest;
  (void)configuration;
  return {WVKernelStatusCode::unsupportedOperation,
          "This adapter does not include model-output persistence."};
#endif
}

WVKernelStatus WVModel::createFromModelOutputInspection(
    WVModelOutputNetCDFInspection inspection,
    WVModelOutputConfiguration outputConfiguration,
    std::unique_ptr<WVFFTEngine> engine,
    const WVModelIntegratorConfiguration &integratorConfiguration,
    WVModel &model, WVModelState &state) {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT

  auto forcingSchedule = inspection.latestRestart.forcingSchedule;
  if (inspection.isDynamicsLinear)
    forcingSchedule.entries.clear();
  WVPortableObserverDescriptor descriptor;
  auto status = WVPortableObserverDescriptor::create(
      inspection.observerRecord, descriptor);
  if (!status)
    return status;

  WVModel candidate;
  status = WVModel::create(inspection.latestRestart.configuration,
                           forcingSchedule, descriptor, std::move(engine),
                           integratorConfiguration, candidate);
  if (!status)
    return status;

  WVModelState candidateState;
  status = WVModelState::create(std::move(inspection.latestRestart),
                                candidate.stateLayout(), candidateState,
                                &inspection.additionalState);
  if (!status)
    return status;

  std::unique_ptr<WVObserverOutputEvaluationService> outputEvaluation;
  status = WVObserverOutputEvaluationService::create(
      candidateState.checkpoint().configuration, inspection.isDynamicsLinear,
      descriptor, nullptr, outputEvaluation,
      candidate.impl_->system->fieldEvaluationService());
  if (!status)
    return status;

  WVModelOutputNetCDFConfiguration sinkConfiguration{
      candidateState.checkpoint(), inspection.isDynamicsLinear};
  auto checkpointStatus = outputConfiguration.openNetCDFSink(
      sinkConfiguration, candidate.stateLayout(), outputEvaluation.get(),
      candidate.impl_->outputSink);
  if (!checkpointStatus)
    return fromCheckpoint(checkpointStatus);

  candidate.impl_->outputFinalTime = outputConfiguration.plan().finalTime();
  candidate.impl_->outputOpen = true;
  candidate.impl_->outputEvaluation = std::move(outputEvaluation);
  candidate.impl_->outputConfiguration =
      std::make_unique<WVModelOutputConfiguration>(
          std::move(outputConfiguration));
  state = std::move(candidateState);
  model = std::move(candidate);
  return WVKernelStatus::ok();
#else
  (void)inspection;
  (void)outputConfiguration;
  (void)engine;
  (void)integratorConfiguration;
  (void)model;
  (void)state;
  return {WVKernelStatusCode::unsupportedOperation,
          "This adapter does not include model-output persistence."};
#endif
}

WVKernelStatus WVModel::create(
    const WVTransformConstantStratificationConfiguration &configuration,
    const WVFrozenForcingSchedule &forcingSchedule,
    const WVPortableObserverDescriptor &observerDescriptor,
    std::unique_ptr<WVFFTEngine> engine,
    const WVModelIntegratorConfiguration &integratorConfiguration,
    WVModel &model) {
  try {
    auto candidate = std::make_unique<Impl>();
    auto status = WVConstantStratificationIntegrationSystem::create(
        configuration, forcingSchedule, observerDescriptor, std::move(engine),
        candidate->system);
    if (!status)
      return status;
    status = candidate->configureIntegrator(integratorConfiguration);
    if (!status)
      return status;
    model.impl_ = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "WVModel allocation failed."};
  }
}

WVKernelStatus WVModel::prepareStateAfterRestart(WVModelState &state) {
  auto view = state.mutableView();
  return impl_->integrator->prepareStateAfterRestart(view);
}

WVKernelStatus WVModel::evaluateRightHandSide(
    const WVIntegrationState &state, WVIntegrationFlux &rightHandSide) {
  return impl_->system->evaluateRightHandSide(state, rightHandSide);
}

WVKernelStatus WVModel::step(WVModelState &state, double proposedStepSize) {
  auto view = state.mutableView();
  const auto status = impl_->integrator->step(view, proposedStepSize);
  if (status) {
    state.checkpoint().state.t = view.waveVortex.t;
    state.checkpoint().state.t0 = view.waveVortex.t0;
  }
  return status;
}

WVKernelStatus WVModel::advanceToTime(WVModelState &state, double finalTime,
                                      double initialStepSize) {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  if (impl_->outputOpen) {
    if (finalTime != impl_->outputFinalTime)
      return invalid("The requested final time differs from the compiled "
                     "output graph.");
    return advanceToTime(state, finalTime, initialStepSize,
                         impl_->outputConfiguration->plan(),
                         impl_->outputSink);
  }
#endif
  auto view = state.mutableView();
  const auto status =
      impl_->integrator->advanceToTime(view, finalTime, initialStepSize);
  if (status) {
    state.checkpoint().state.t = view.waveVortex.t;
    state.checkpoint().state.t0 = view.waveVortex.t0;
  }
  return status;
}

WVCheckpointStatus WVModel::closeOutput() noexcept {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  if (!impl_->outputOpen)
    return WVCheckpointStatus::ok();
  const auto status = impl_->outputSink.close();
  impl_->outputMetrics = impl_->outputSink.metrics();
  if (status)
    impl_->outputOpen = false;
  return status;
#else
  return WVCheckpointStatus::ok();
#endif
}

bool WVModel::hasOutput() const noexcept {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  return impl_->outputOpen;
#else
  return false;
#endif
}

WVKernelStatus WVModel::advanceToTime(WVModelState &state, double finalTime,
                                      double initialStepSize,
                                      const WVOutputPlan &plan,
                                      WVOutputSink &sink) {
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  auto view = state.mutableView();
  WVOutputDriver driver(*impl_->integrator, plan);
  const auto status =
      driver.advanceToTime(view, finalTime, initialStepSize, sink);
  impl_->outputDriverMetrics = driver.metrics();
  if (status) {
    state.checkpoint().state.t = view.waveVortex.t;
    state.checkpoint().state.t0 = view.waveVortex.t0;
  }
  return status;
#else
  (void)state;
  (void)finalTime;
  (void)initialStepSize;
  (void)plan;
  (void)sink;
  return {WVKernelStatusCode::unsupportedOperation,
          "This adapter does not include output orchestration."};
#endif
}

const WVIntegrationStateLayout &WVModel::stateLayout() const noexcept {
  return impl_->system->stateLayout();
}

double WVModel::nextStepSize() const noexcept {
  return impl_->integrator->nextStepSize();
}

WVModelIntegratorKind WVModel::integratorKind() const noexcept {
  return impl_->integratorKind;
}

const std::string &WVModel::forcingScheduleIdentifier() const noexcept {
  return impl_->system->scheduleIdentifier();
}

WVModelMetrics WVModel::metrics(const WVModelState *state) const noexcept {
  WVModelMetrics result;
  result.modelPersistentBytes = sizeof(*this) + sizeof(Impl);
  result.statePersistentBytes = state == nullptr ? 0 : state->persistentBytes();
  result.integrationSystemPersistentBytes = impl_->system->persistentBytes();
  result.integratorPersistentBytes = impl_->integrator->persistentBytes();
  result.kernel = impl_->system->kernelMetrics();
  result.forcing = impl_->system->forcingMetrics();
  result.integratedObservers = impl_->system->metrics();
  if (impl_->integratorKind == WVModelIntegratorKind::adaptiveRK23)
    result.integrator =
        static_cast<const WVAdaptiveRK23 &>(*impl_->integrator).metrics();
  else
    result.integrator =
        static_cast<const WVFixedStepRK4 &>(*impl_->integrator).metrics();
  result.outputDriver = impl_->outputDriverMetrics;
#if !defined(WV_MODEL_ENABLE_OUTPUT) || WV_MODEL_ENABLE_OUTPUT
  if (impl_->outputEvaluation != nullptr)
    result.outputEvaluation = impl_->outputEvaluation->metrics();
  result.output = impl_->outputOpen ? impl_->outputSink.metrics()
                                    : impl_->outputMetrics;
  if (impl_->outputConfiguration != nullptr)
    result.outputPersistentBytes =
        impl_->outputConfiguration->persistentBytes() +
        (impl_->outputEvaluation == nullptr
             ? 0
             : impl_->outputEvaluation->persistentBytes()) +
        impl_->outputSink.metrics().retainedStorageBytes;
#endif
  return result;
}

WVConstantStratificationIntegrationSystem &
WVModel::internalIntegrationSystem() noexcept {
  return *impl_->system;
}

WVTimeIntegrator &WVModel::internalIntegrator() noexcept {
  return *impl_->integrator;
}

} // namespace wavevortex::runtime
