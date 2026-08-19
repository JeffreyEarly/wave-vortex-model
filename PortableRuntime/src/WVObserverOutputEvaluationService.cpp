#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"
#include "WaveVortexRuntime/WVObserverOutputProvider.hpp"

#include <algorithm>
#include <chrono>
#include <map>
#include <new>
#include <set>
#include <sstream>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

std::string samplingKey(const std::string &field,
                        const WVFieldSamplingRequest &sampling) {
  std::ostringstream stream;
  stream << field << ':' << static_cast<int>(sampling.kind);
  for (const auto value : sampling.xIndices)
    stream << ":x" << value;
  for (const auto value : sampling.yIndices)
    stream << ":y" << value;
  for (const auto value : sampling.x)
    stream << ":X" << value;
  for (const auto value : sampling.y)
    stream << ":Y" << value;
  for (const auto value : sampling.z)
    stream << ":Z" << value;
  stream << ":i" << static_cast<int>(sampling.interpolation);
  return stream.str();
}

std::string outputKey(const std::string &observerIdentifier,
                      const std::string &identifier) {
  return observerIdentifier + '/' + identifier;
}

const WVObservationVariable *
findVariable(const WVObservationSchema &schema,
             const std::string &identifier) noexcept {
  const auto found =
      std::find_if(schema.variables.begin(), schema.variables.end(),
                   [&](const auto &candidate) {
                     return candidate.identifier == identifier;
                   });
  return found == schema.variables.end() ? nullptr : &*found;
}

WVKernelStatus fixedExtents(const WVObservationSchema &schema,
                            const WVObservationVariable &variable,
                            std::vector<std::size_t> &extents) {
  extents.clear();
  extents.reserve(variable.dimensionIdentifiers.size());
  for (const auto &identifier : variable.dimensionIdentifiers) {
    const auto axis = std::find_if(
        schema.axes.begin(), schema.axes.end(), [&](const auto &candidate) {
          return candidate.identifier == identifier;
        });
    if (axis == schema.axes.end() ||
        axis->kind != WVObservationAxisKind::fixed)
      return invalid("Shared observer evaluation channels require fixed axes.");
    extents.push_back(axis->extent);
  }
  return WVKernelStatus::ok();
}

std::size_t elementCount(const std::vector<std::size_t> &extents) noexcept {
  std::size_t count = 1;
  for (const auto extent : extents)
    count *= extent;
  return count;
}

WVObserverOutputVariableSpecification legacySpecification(
    const WVObservationVariable &variable,
    const WVObserverOutputChannel &channel,
    const std::vector<std::size_t> &extents) {
  WVObserverOutputVariableSpecification specification;
  specification.identifier =
      channel.source == WVObserverOutputChannelSource::coefficient ||
              channel.source == WVObserverOutputChannelSource::sampledField ||
              channel.source == WVObserverOutputChannelSource::movingField
          ? channel.sourceIdentifier
          : variable.identifier;
  specification.name = variable.name;
  specification.valueType =
      variable.scalarType == WVObservationScalarType::complex64
          ? WVOutputValueType::complex64
          : WVOutputValueType::real64;
  specification.dimensionNames = variable.dimensionIdentifiers;
  specification.dimensions = extents;
  specification.units = variable.units;
  specification.longName = variable.description;
  specification.cadence =
      variable.layout == WVObservationValueLayout::staticValue ||
              variable.layout == WVObservationValueLayout::initialValue
          ? WVObserverOutputCadence::initialOnly
          : WVObserverOutputCadence::timeSeries;
  for (const auto &attribute : variable.attributes)
    specification.attributes.push_back({attribute.name, attribute.value});
  return specification;
}

} // namespace

class WVObserverOutputEvaluationService::Impl {
public:
  struct Output {
    std::string variableIdentifier;
    WVObserverOutputVariableSpecification specification;
    WVObserverOutputChannelSource source =
        WVObserverOutputChannelSource::sampledField;
    std::size_t coefficientFamily = 0;
    std::size_t fieldOutput = 0;
    bool initialField = false;
    bool exposeLegacySpecification = true;
    std::string stateBlockIdentifier;
    double scale = 1.0;
    double offset = 0.0;
  };

  struct MovingCoordinates {
    std::string observerIdentifier;
    std::string xBlock;
    std::string yBlock;
    std::string zBlock;
    std::vector<double> fixedZ;
    std::size_t offset = 0;
    std::size_t count = 0;
    bool isXYOnly = false;
  };

  WVTransformConstantStratificationConfiguration configuration;
  bool isDynamicsLinear = false;
  WVPortableObserverDescriptor descriptor;
  std::unique_ptr<WVFieldEvaluationService> ownedFields;
  WVFieldEvaluationService *fields = nullptr;
  WVFieldEvaluationPlan initialFieldPlan;
  WVFieldEvaluationPlan timeSeriesFieldPlan;
  std::vector<std::vector<double>> initialFieldStorage;
  std::vector<std::vector<double>> timeSeriesFieldStorage;
  std::vector<WVFieldOutputView> initialFieldViews;
  std::vector<WVFieldOutputView> timeSeriesFieldViews;
  WVMovingFieldEvaluationPlan movingFieldPlan;
  std::vector<std::vector<double>> movingFieldStorage;
  std::vector<WVFieldOutputView> movingFieldViews;
  std::vector<MovingCoordinates> movingCoordinates;
  std::vector<double> movingX;
  std::vector<double> movingY;
  std::vector<double> movingZ;
  std::set<std::string> movingObserverIdentifiers;
  std::map<std::string, std::shared_ptr<const WVObservingSystem>>
      implementationsByObserver;
  std::map<std::string, WVObserverOutputPlan> plansByObserver;
  std::map<std::string, std::vector<Output>> outputsByObserver;
  std::map<std::string, std::pair<std::string, std::size_t>> outputLookup;
  std::map<std::string, std::vector<double>> affineStorage;
  WVState preparedState;
  WVIntegrationState preparedIntegrationState;
  std::size_t preparedEventOrdinal = 0;
  double preparedScheduledTime = 0.0;
  bool prepared = false;
  bool running = false;

  const Output *output(const std::string &observerIdentifier,
                       const std::string &identifier) const noexcept {
    const auto found = outputLookup.find(outputKey(observerIdentifier, identifier));
    if (found == outputLookup.end())
      return nullptr;
    return &outputsByObserver.at(found->second.first)[found->second.second];
  }

  WVKernelStatus evaluate(const WVState &state, bool initial,
                          const WVIntegrationState *integrationState,
                          bool evaluateMoving,
                          WVObserverOutputEvaluationMetrics &metrics) {
    if (running)
      return invalid("Observer evaluation is not reentrant.");
    running = true;
    const auto finish = [this]() { running = false; };
    auto &views = initial ? initialFieldViews : timeSeriesFieldViews;
    const auto &plan = initial ? initialFieldPlan : timeSeriesFieldPlan;
    if (!views.empty()) {
      const auto status = fields->evaluate(plan, state, views.data(), views.size());
      if (!status) {
        finish();
        return status;
      }
      ++metrics.fieldEvaluationCount;
    }
    if (!initial && !movingFieldViews.empty() && evaluateMoving) {
      if (integrationState == nullptr) {
        finish();
        return invalid("Moving observer output requires integration state.");
      }
      const auto findBlock = [&](const std::string &identifier) {
        for (std::size_t index = 0;
             index < integrationState->additionalBlockCount; ++index)
          if (integrationState->additionalBlocks[index].layout->identifier ==
              identifier)
            return integrationState->additionalBlocks + index;
        return static_cast<const WVAdditionalStateBlockConstView *>(nullptr);
      };
      for (const auto &coordinates : movingCoordinates) {
        const auto *x = findBlock(coordinates.xBlock);
        const auto *y = findBlock(coordinates.yBlock);
        const auto *z =
            coordinates.isXYOnly ? nullptr : findBlock(coordinates.zBlock);
        if (x == nullptr || y == nullptr ||
            (!coordinates.isXYOnly && z == nullptr)) {
          finish();
          return invalid("Moving observer coordinate state is unavailable.");
        }
        std::copy_n(x->realData, coordinates.count,
                    movingX.data() + coordinates.offset);
        std::copy_n(y->realData, coordinates.count,
                    movingY.data() + coordinates.offset);
        if (coordinates.isXYOnly)
          std::copy(coordinates.fixedZ.begin(), coordinates.fixedZ.end(),
                    movingZ.data() + coordinates.offset);
        else
          std::copy_n(z->realData, coordinates.count,
                      movingZ.data() + coordinates.offset);
      }
      const auto status = fields->evaluateMoving(
          movingFieldPlan, state,
          {movingX.data(), movingY.data(), movingZ.data(), movingX.size()},
          movingFieldViews.data(), movingFieldViews.size());
      if (!status) {
        finish();
        return status;
      }
      ++metrics.fieldEvaluationCount;
      ++metrics.routeAwareParticleEvaluationCount;
    } else if (!initial && !movingFieldViews.empty()) {
      ++metrics.skippedParticleEvaluationCount;
    }
    preparedState = state;
    preparedIntegrationState = integrationState == nullptr
                                   ? WVIntegrationState{state, nullptr, 0}
                                   : *integrationState;
    prepared = true;
    ++metrics.preparedEventCount;
    finish();
    return WVKernelStatus::ok();
  }

  WVKernelStatus borrowedValue(
      const std::string &observerIdentifier,
      const std::string &variableIdentifier,
      WVObserverBorrowedValueView &value,
      WVObserverOutputEvaluationMetrics &metrics) {
    if (!prepared)
      return invalid("Observer values were requested before prepare().");
    const auto *entry = output(observerIdentifier, variableIdentifier);
    if (entry == nullptr)
      return invalid("Observer output variable is not part of this service.");
    value = {};
    value.scalarType = entry->specification.valueType ==
                               WVOutputValueType::complex64
                           ? WVObservationScalarType::complex64
                           : WVObservationScalarType::real64;
    value.extents = entry->specification.dimensions;
    value.elementCount = elementCount(value.extents);
    if (entry->source == WVObserverOutputChannelSource::coefficient) {
      const auto &coefficients = preparedState.coefficients;
      value.complex64 = entry->coefficientFamily == 0
                            ? coefficients.Ap.data
                            : entry->coefficientFamily == 1
                                  ? coefficients.Am.data
                                  : coefficients.A0.data;
      ++metrics.borrowedCoefficientViewCount;
      return WVKernelStatus::ok();
    }
    if (entry->source == WVObserverOutputChannelSource::additionalState) {
      for (std::size_t index = 0;
           index < preparedIntegrationState.additionalBlockCount; ++index) {
        const auto &block = preparedIntegrationState.additionalBlocks[index];
        if (block.layout->identifier == entry->stateBlockIdentifier) {
          if (block.realData == nullptr)
            return invalid("Observer state output is not real-valued.");
          value.real64 = block.realData;
          return WVKernelStatus::ok();
        }
      }
      return invalid("Observer state output is unavailable.");
    }
    const auto &storage =
        entry->source == WVObserverOutputChannelSource::movingField
            ? movingFieldStorage
            : entry->initialField ? initialFieldStorage
                                  : timeSeriesFieldStorage;
    if (entry->fieldOutput >= storage.size())
      return invalid("Observer field output binding is invalid.");
    if (entry->scale != 1.0 || entry->offset != 0.0) {
      auto &transformed = affineStorage[outputKey(observerIdentifier,
                                                   variableIdentifier)];
      transformed.resize(storage[entry->fieldOutput].size());
      std::transform(storage[entry->fieldOutput].begin(),
                     storage[entry->fieldOutput].end(), transformed.begin(),
                     [&](double input) {
                       return entry->scale * input + entry->offset;
                     });
      value.real64 = transformed.data();
      value.elementCount = transformed.size();
    } else {
      value.real64 = storage[entry->fieldOutput].data();
      value.elementCount = storage[entry->fieldOutput].size();
    }
    return WVKernelStatus::ok();
  }
};

WVObserverOutputEvaluationService::~WVObserverOutputEvaluationService() =
    default;

WVKernelStatus WVObserverOutputEvaluationService::create(
    const WVTransformConstantStratificationConfiguration &configuration,
    bool isDynamicsLinear, const WVPortableObserverDescriptor &descriptor,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVObserverOutputEvaluationService> &service,
    WVFieldEvaluationService *borrowedFieldEvaluationService) {
  try {
    auto candidate = std::unique_ptr<WVObserverOutputEvaluationService>(
        new WVObserverOutputEvaluationService());
    candidate->impl_ = std::make_unique<Impl>();
    auto &impl = *candidate->impl_;
    impl.configuration = configuration;
    impl.isDynamicsLinear = isDynamicsLinear;
    impl.descriptor = descriptor;
    const auto &descriptorRecord = impl.descriptor.record();
    WVKernelStatus status;
    if (borrowedFieldEvaluationService == nullptr) {
      status = WVFieldEvaluationService::create(configuration, std::move(engine),
                                                impl.ownedFields);
      if (!status)
        return status;
      impl.fields = impl.ownedFields.get();
    } else {
      impl.fields = borrowedFieldEvaluationService;
    }

    WVObserverOutputPlanningContext planningContext;
    planningContext.configuration = &configuration;
    planningContext.stateBlocks = descriptorRecord.stateBlocks.data();
    planningContext.stateBlockCount = descriptorRecord.stateBlocks.size();
    planningContext.isDynamicsLinear = isDynamicsLinear;
    std::vector<WVFieldRequest> initialRequests;
    std::vector<WVFieldRequest> timeSeriesRequests;
    std::map<std::string, std::size_t> initialRequestIndex;
    std::map<std::string, std::size_t> timeSeriesRequestIndex;
    std::vector<WVMovingFieldRequest> movingRequests;

    for (const auto &observer : descriptorRecord.observers) {
      const auto *resolved = impl.descriptor.resolvedObserver(observer);
      if (resolved == nullptr)
        return {WVKernelStatusCode::unsupportedOperation,
                "Observer output evaluation received an unresolved observer."};
      WVObserverOutputPlan plan;
      status = resolved->outputPlan(observer, planningContext, plan);
      if (!status)
        return status;
      status = validateObservationSchema(plan.schema);
      if (!status)
        return status;
      impl.implementationsByObserver.emplace(
          observer.identifier, resolved->implementationHandle());
      auto insertedPlan =
          impl.plansByObserver.emplace(observer.identifier, std::move(plan));
      const auto &storedPlan = insertedPlan.first->second;
      auto &outputs = impl.outputsByObserver[observer.identifier];

      std::size_t movingOffset = 0;
      const bool hasMovingChannels = std::any_of(
          storedPlan.channels.begin(), storedPlan.channels.end(),
          [](const auto &channel) {
            return channel.source ==
                   WVObserverOutputChannelSource::movingField;
          });
      if (hasMovingChannels) {
        const auto &positions = storedPlan.movingPositions;
        if (positions.positionCount == 0 ||
            positions.stateBlockIdentifiers.size() < 2 ||
            (!positions.isXYOnly &&
             positions.stateBlockIdentifiers.size() < 3) ||
            positions.fixedZ.size() != positions.positionCount)
          return invalid("Moving observer output plan has invalid coordinates.");
        movingOffset = impl.movingX.size();
        impl.movingX.resize(movingOffset + positions.positionCount);
        impl.movingY.resize(movingOffset + positions.positionCount);
        impl.movingZ.resize(movingOffset + positions.positionCount);
        impl.movingCoordinates.push_back(
            {observer.identifier, positions.stateBlockIdentifiers[0],
             positions.stateBlockIdentifiers[1],
             positions.isXYOnly ? std::string{}
                                : positions.stateBlockIdentifiers[2],
             positions.fixedZ, movingOffset, positions.positionCount,
             positions.isXYOnly});
        impl.movingObserverIdentifiers.insert(observer.identifier);
      }

      for (const auto &channel : storedPlan.channels) {
        const auto *variable =
            findVariable(storedPlan.schema, channel.variableIdentifier);
        if (variable == nullptr)
          return invalid("Observer output channel references an unknown variable.");
        if (variable->scalarType != WVObservationScalarType::real64 &&
            variable->scalarType != WVObservationScalarType::complex64)
          return invalid("Shared evaluation channels support real or complex values.");
        std::vector<std::size_t> extents;
        status = fixedExtents(storedPlan.schema, *variable, extents);
        if (!status)
          return status;
        Impl::Output output;
        output.variableIdentifier = channel.variableIdentifier;
        output.specification = legacySpecification(*variable, channel, extents);
        output.source = channel.source;
        output.coefficientFamily = channel.coefficientFamily;
        output.stateBlockIdentifier = channel.sourceIdentifier;
        output.scale = channel.scale;
        output.offset = channel.offset;
        output.exposeLegacySpecification =
            channel.source !=
            WVObserverOutputChannelSource::additionalState;
        if (channel.source == WVObserverOutputChannelSource::sampledField) {
          const bool initial =
              variable->layout == WVObservationValueLayout::initialValue ||
              variable->layout == WVObservationValueLayout::staticValue;
          auto &requests = initial ? initialRequests : timeSeriesRequests;
          auto &requestIndex =
              initial ? initialRequestIndex : timeSeriesRequestIndex;
          const auto key =
              samplingKey(channel.sourceIdentifier, channel.sampling);
          const auto found = requestIndex.find(key);
          if (found == requestIndex.end()) {
            output.fieldOutput = requests.size();
            requestIndex.emplace(key, output.fieldOutput);
            requests.push_back({"field-" + std::to_string(output.fieldOutput),
                                channel.sourceIdentifier, channel.sampling});
          } else {
            output.fieldOutput = found->second;
            ++candidate->metrics_.sharedFieldReuseCount;
          }
          output.initialField = initial;
        } else if (channel.source ==
                   WVObserverOutputChannelSource::movingField) {
          output.fieldOutput = impl.movingFieldStorage.size();
          impl.movingFieldStorage.emplace_back(elementCount(extents));
          impl.movingFieldViews.push_back(
              {impl.movingFieldStorage.back().data(),
               impl.movingFieldStorage.back().size()});
          movingRequests.push_back(
              {observer.identifier + '-' + channel.sourceIdentifier,
               channel.sourceIdentifier, movingOffset,
               storedPlan.movingPositions.positionCount,
               storedPlan.movingPositions.interpolation});
        }
        const auto index = outputs.size();
        outputs.push_back(std::move(output));
        const auto &stored = outputs.back();
        impl.outputLookup.emplace(
            outputKey(observer.identifier, stored.variableIdentifier),
            std::make_pair(observer.identifier, index));
        impl.outputLookup.emplace(
            outputKey(observer.identifier, stored.specification.identifier),
            std::make_pair(observer.identifier, index));
      }
    }

    const auto buildPlan = [&](const std::vector<WVFieldRequest> &requests,
                               WVFieldEvaluationPlan &plan,
                               std::vector<std::vector<double>> &storage,
                               std::vector<WVFieldOutputView> &views) {
      if (requests.empty())
        return WVKernelStatus::ok();
      auto planStatus = impl.fields->createPlan(requests, plan);
      if (!planStatus)
        return planStatus;
      storage.resize(plan.outputCount());
      views.resize(plan.outputCount());
      for (std::size_t index = 0; index < plan.outputCount(); ++index) {
        const auto count = plan.outputs()[index].elementCount;
        storage[index].resize(count);
        views[index] = {storage[index].data(), count};
        candidate->metrics_.outputCapacityBytes +=
            storage[index].capacity() * sizeof(double);
      }
      return WVKernelStatus::ok();
    };
    status = buildPlan(initialRequests, impl.initialFieldPlan,
                       impl.initialFieldStorage, impl.initialFieldViews);
    if (!status)
      return status;
    status = buildPlan(timeSeriesRequests, impl.timeSeriesFieldPlan,
                       impl.timeSeriesFieldStorage,
                       impl.timeSeriesFieldViews);
    if (!status)
      return status;
    if (!movingRequests.empty()) {
      status = impl.fields->createMovingPlan(movingRequests,
                                             impl.movingFieldPlan);
      if (!status)
        return status;
      for (const auto &storage : impl.movingFieldStorage)
        candidate->metrics_.outputCapacityBytes +=
            storage.capacity() * sizeof(double);
    }
    candidate->metrics_.uniqueFieldOutputCount =
        initialRequests.size() + timeSeriesRequests.size();
    candidate->metrics_.retainedStorageBytes = candidate->persistentBytes();
    service = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate observer-output evaluation storage."};
  }
}

WVKernelStatus WVObserverOutputEvaluationService::specifications(
    const WVObserverRecord &observer,
    std::vector<WVObserverOutputVariableSpecification> &output) {
  const auto found = impl_->outputsByObserver.find(observer.identifier);
  if (found == impl_->outputsByObserver.end())
    return invalid("Observer is not part of this evaluation service.");
  output.clear();
  for (const auto &entry : found->second)
    if (entry.exposeLegacySpecification)
      output.push_back(entry.specification);
  return WVKernelStatus::ok();
}

WVKernelStatus WVObserverOutputEvaluationService::observationSchema(
    const WVObserverRecord &observer, WVObservationSchema &output) {
  const auto found = impl_->plansByObserver.find(observer.identifier);
  if (found == impl_->plansByObserver.end())
    return invalid("Observer is not part of this evaluation service.");
  output = found->second.schema;
  return WVKernelStatus::ok();
}

WVKernelStatus WVObserverOutputEvaluationService::observationBatchForKind(
    const WVObserverRecord &observer, WVObservationBatchKind kind,
    WVObservationBatch &output) {
  const auto plan = impl_->plansByObserver.find(observer.identifier);
  const auto implementation =
      impl_->implementationsByObserver.find(observer.identifier);
  if (plan == impl_->plansByObserver.end() ||
      implementation == impl_->implementationsByObserver.end())
    return invalid("Observer is not part of this evaluation service.");
  if (!impl_->prepared)
    return invalid("Observation batch was requested before prepare().");
  class Context final : public WVObserverOutputEvaluationContext {
  public:
    Context(Impl &impl, WVObserverOutputEvaluationMetrics &metrics,
            std::string observerIdentifier)
        : impl_(impl), metrics_(metrics),
          observerIdentifier_(std::move(observerIdentifier)) {}
    std::size_t eventOrdinal() const noexcept override {
      return impl_.preparedEventOrdinal;
    }
    double scheduledTime() const noexcept override {
      return impl_.preparedScheduledTime;
    }
    WVKernelStatus value(const std::string &identifier,
                         WVObserverBorrowedValueView &value) const override {
      return impl_.borrowedValue(observerIdentifier_, identifier, value,
                                 metrics_);
    }

  private:
    Impl &impl_;
    WVObserverOutputEvaluationMetrics &metrics_;
    std::string observerIdentifier_;
  } context(*impl_, metrics_, observer.identifier);
  WVObservationBatch batch;
  auto status = implementation->second->observationBatch(
      observer, plan->second, context, kind, batch);
  if (!status)
    return status;
  status = validateObservationBatch(plan->second.schema, batch);
  if (!status)
    return status;
  const auto batchMetrics = batch.metrics();
  metrics_.batchRetainedStorageBytes =
      std::max(metrics_.batchRetainedStorageBytes,
               batchMetrics.retainedStorageBytes);
  metrics_.batchMaximumLiveBytes =
      std::max(metrics_.batchMaximumLiveBytes, batchMetrics.liveBytes);
  output = std::move(batch);
  return WVKernelStatus::ok();
}

WVKernelStatus WVObserverOutputEvaluationService::initialObservationBatch(
    const WVObserverRecord &observer, WVObservationBatch &output) {
  return observationBatchForKind(observer, WVObservationBatchKind::initial,
                                 output);
}

WVKernelStatus WVObserverOutputEvaluationService::observationBatch(
    const WVObserverRecord &observer, WVObservationBatch &output) {
  return observationBatchForKind(observer, WVObservationBatchKind::event,
                                 output);
}

WVKernelStatus WVObserverOutputEvaluationService::preflight(
    const WVOutputPlan &plan) {
  for (std::size_t groupIndex = 0; groupIndex < plan.groupCount(); ++groupIndex) {
    const auto route = plan.groupRoute(groupIndex);
    for (std::size_t observerIndex = 0;
         observerIndex < route.observerCount; ++observerIndex) {
      const auto &resolved = route.observers[observerIndex];
      if (resolved.record == nullptr || resolved.resolved == nullptr ||
          impl_->plansByObserver.find(resolved.record->identifier) ==
              impl_->plansByObserver.end())
        return invalid("Output plan references an observer outside this "
                       "evaluation service.");
    }
  }
  return WVKernelStatus::ok();
}

WVKernelStatus WVObserverOutputEvaluationService::useFieldEvaluationService(
    WVFieldEvaluationService &fieldEvaluationService) {
  if (!sameTransformConfiguration(impl_->configuration,
                                  fieldEvaluationService.configuration()))
    return invalid("Borrowed field-evaluation service uses an incompatible "
                   "constant-stratification configuration.");
  impl_->ownedFields.reset();
  impl_->fields = &fieldEvaluationService;
  metrics_.retainedStorageBytes = persistentBytes();
  return WVKernelStatus::ok();
}

WVKernelStatus
WVObserverOutputEvaluationService::prepareInitial(const WVState &state) {
  const auto started = std::chrono::steady_clock::now();
  impl_->preparedEventOrdinal = 0;
  impl_->preparedScheduledTime = state.t;
  const auto status = impl_->evaluate(state, true, nullptr, false, metrics_);
  metrics_.evaluationSeconds +=
      std::chrono::duration<double>(std::chrono::steady_clock::now() - started)
          .count();
  return status;
}

WVKernelStatus WVObserverOutputEvaluationService::prepare(
    const WVOutputEvent &event) {
  const auto started = std::chrono::steady_clock::now();
  bool needsMoving = event.routes == nullptr;
  for (std::size_t route = 0; route < event.routeCount && !needsMoving;
       ++route)
    for (std::size_t observer = 0;
         observer < event.routes[route].observerCount; ++observer) {
      const auto *record = event.routes[route].observers[observer].record;
      if (record != nullptr &&
          impl_->movingObserverIdentifiers.find(record->identifier) !=
              impl_->movingObserverIdentifiers.end()) {
        needsMoving = true;
        break;
      }
    }
  impl_->preparedEventOrdinal = event.eventOrdinal;
  impl_->preparedScheduledTime = event.scheduledTime;
  const auto status = impl_->evaluate(event.state.waveVortex, false,
                                      &event.state, needsMoving, metrics_);
  metrics_.evaluationSeconds +=
      std::chrono::duration<double>(std::chrono::steady_clock::now() - started)
          .count();
  return status;
}

WVKernelStatus WVObserverOutputEvaluationService::value(
    const WVObserverRecord &observer,
    const WVObserverOutputVariableSpecification &variable,
    WVObserverOutputValueView &output) {
  WVObserverBorrowedValueView value;
  const auto status = impl_->borrowedValue(observer.identifier,
                                           variable.identifier, value,
                                           metrics_);
  if (!status)
    return status;
  if (value.scalarType != WVObservationScalarType::real64 &&
      value.scalarType != WVObservationScalarType::complex64)
    return invalid("Legacy observer value view supports real or complex data.");
  output = {};
  output.valueType = value.scalarType == WVObservationScalarType::complex64
                         ? WVOutputValueType::complex64
                         : WVOutputValueType::real64;
  output.realData = value.real64;
  output.complexData = value.complex64;
  output.elementCount = value.elementCount;
  return WVKernelStatus::ok();
}

std::size_t WVObserverOutputEvaluationService::persistentBytes() const noexcept {
  if (!impl_)
    return sizeof(*this);
  std::size_t bytes =
      sizeof(*this) + sizeof(Impl) +
      (impl_->ownedFields ? impl_->ownedFields->persistentBytes() : 0) +
      impl_->initialFieldPlan.persistentBytes() +
      impl_->timeSeriesFieldPlan.persistentBytes() +
      impl_->movingFieldPlan.persistentBytes();
  for (const auto &storage : impl_->initialFieldStorage)
    bytes += storage.capacity() * sizeof(double);
  for (const auto &storage : impl_->timeSeriesFieldStorage)
    bytes += storage.capacity() * sizeof(double);
  for (const auto &storage : impl_->movingFieldStorage)
    bytes += storage.capacity() * sizeof(double);
  bytes += (impl_->movingX.capacity() + impl_->movingY.capacity() +
            impl_->movingZ.capacity()) *
           sizeof(double);
  for (const auto &[identifier, plan] : impl_->plansByObserver)
    bytes += identifier.capacity() + observerOutputPlanRetainedBytes(plan);
  for (const auto &identifier : impl_->movingObserverIdentifiers)
    bytes += identifier.capacity();
  for (const auto &[key, storage] : impl_->affineStorage)
    bytes += key.capacity() + storage.capacity() * sizeof(double);
  for (const auto &[identifier, outputs] : impl_->outputsByObserver) {
    bytes += identifier.capacity() + outputs.capacity() * sizeof(Impl::Output);
    for (const auto &output : outputs)
      bytes += output.variableIdentifier.capacity() +
               output.specification.identifier.capacity() +
               output.specification.name.capacity() +
               output.specification.units.capacity() +
               output.specification.longName.capacity() +
               output.stateBlockIdentifier.capacity();
  }
  return bytes;
}

} // namespace wavevortex::runtime
