#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"
#include "WVObserverAdapter.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
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

bool linearInitialOnly(const WVPortableVariableMetadata &metadata) {
  return !metadata.isVariableWithLinearTimeStep;
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

std::string outputKey(const WVObserverRecord &observer,
                      const std::string &identifier) {
  return observer.identifier + '/' + identifier;
}

} // namespace

class WVObserverOutputEvaluationService::Impl {
public:
  struct Output {
    WVObserverOutputVariableSpecification specification;
    bool coefficient = false;
    std::size_t coefficientFamily = 0;
    std::size_t fieldOutput = 0;
    bool initialField = false;
    bool particleField = false;
  };

  struct ParticleCoordinates {
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
  WVPortableObserverRecord descriptor;
  std::unique_ptr<WVFieldEvaluationService> ownedFields;
  WVFieldEvaluationService *fields = nullptr;
  WVFieldEvaluationPlan initialFieldPlan;
  WVFieldEvaluationPlan timeSeriesFieldPlan;
  std::vector<std::vector<double>> initialFieldStorage;
  std::vector<std::vector<double>> timeSeriesFieldStorage;
  std::vector<WVFieldOutputView> initialFieldViews;
  std::vector<WVFieldOutputView> timeSeriesFieldViews;
  WVMovingFieldEvaluationPlan particleFieldPlan;
  std::vector<std::vector<double>> particleFieldStorage;
  std::vector<WVFieldOutputView> particleFieldViews;
  std::vector<ParticleCoordinates> particleCoordinates;
  std::vector<double> particleX;
  std::vector<double> particleY;
  std::vector<double> particleZ;
  std::map<std::string, std::vector<Output>> outputsByObserver;
  std::map<std::string, std::pair<std::string, std::size_t>> outputLookup;
  WVState preparedState;
  bool prepared = false;
  bool running = false;

  WVKernelStatus evaluate(const WVState &state, bool initial,
                          const WVIntegrationState *integrationState,
                          bool evaluateParticles,
                          WVObserverOutputEvaluationMetrics &metrics) {
    if (running)
      return invalid("Observer evaluation is not reentrant.");
    running = true;
    const auto reset = [this]() { running = false; };
    auto &views = initial ? initialFieldViews : timeSeriesFieldViews;
    const auto &plan = initial ? initialFieldPlan : timeSeriesFieldPlan;
    if (!views.empty()) {
      const auto status =
          fields->evaluate(plan, state, views.data(), views.size());
      if (!status) {
        reset();
        return status;
      }
      ++metrics.fieldEvaluationCount;
    }
    if (!initial && !particleFieldViews.empty() && evaluateParticles) {
      if (integrationState == nullptr) {
        reset();
        return invalid("Particle output requires complete integration state.");
      }
      const auto findBlock = [&](const std::string &identifier) {
        for (std::size_t index = 0;
             index < integrationState->additionalBlockCount;
             ++index)
          if (integrationState->additionalBlocks[index].layout->identifier ==
              identifier)
            return integrationState->additionalBlocks + index;
        return static_cast<const WVAdditionalStateBlockConstView *>(nullptr);
      };
      for (const auto &coordinates : particleCoordinates) {
        const auto *x = findBlock(coordinates.xBlock);
        const auto *y = findBlock(coordinates.yBlock);
        const auto *z = coordinates.isXYOnly ? nullptr : findBlock(coordinates.zBlock);
        if (x == nullptr || y == nullptr ||
            (!coordinates.isXYOnly && z == nullptr)) {
          reset();
          return invalid("Particle output state blocks are absent from the event.");
        }
        std::copy_n(x->realData, coordinates.count,
                    particleX.data() + coordinates.offset);
        std::copy_n(y->realData, coordinates.count,
                    particleY.data() + coordinates.offset);
        if (coordinates.isXYOnly)
          std::copy(coordinates.fixedZ.begin(), coordinates.fixedZ.end(),
                    particleZ.data() + coordinates.offset);
        else
          std::copy_n(z->realData, coordinates.count,
                      particleZ.data() + coordinates.offset);
      }
      const auto status = fields->evaluateMoving(
          particleFieldPlan, state,
          {particleX.data(), particleY.data(), particleZ.data(),
           particleX.size()},
          particleFieldViews.data(), particleFieldViews.size());
      if (!status) {
        reset();
        return status;
      }
      ++metrics.fieldEvaluationCount;
      ++metrics.routeAwareParticleEvaluationCount;
    } else if (!initial && !particleFieldViews.empty()) {
      ++metrics.skippedParticleEvaluationCount;
    }
    preparedState = state;
    prepared = true;
    ++metrics.preparedEventCount;
    reset();
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
    impl.descriptor = descriptor.record();
    WVKernelStatus status;
    if (borrowedFieldEvaluationService == nullptr) {
      status = WVFieldEvaluationService::create(
          configuration, std::move(engine), impl.ownedFields);
      if (!status)
        return status;
      impl.fields = impl.ownedFields.get();
    } else {
      impl.fields = borrowedFieldEvaluationService;
    }

    std::vector<WVFieldRequest> initialRequests;
    std::vector<WVFieldRequest> timeSeriesRequests;
    std::map<std::string, std::size_t> initialRequestIndex;
    std::map<std::string, std::size_t> timeSeriesRequestIndex;
    auto addField = [&](const std::string &field,
                              const WVFieldSamplingRequest &sampling,
                              const std::string &variableName,
                              std::vector<std::string> dimensionNames,
                              std::vector<std::size_t> dimensions,
                              std::vector<Impl::Output> &outputs) mutable {
      const auto *metadata = findPortableVariable(field);
      if (metadata == nullptr || metadata->kind != WVPortableVariableKind::field)
        return invalid("Unsupported observer field: " + field + ".");
      const bool initialField = isDynamicsLinear && linearInitialOnly(*metadata);
      auto &requests = initialField ? initialRequests : timeSeriesRequests;
      auto &requestIndex =
          initialField ? initialRequestIndex : timeSeriesRequestIndex;
      const auto key = samplingKey(field, sampling);
      auto found = requestIndex.find(key);
      std::size_t index = 0;
      if (found == requestIndex.end()) {
        index = requests.size();
        requestIndex.emplace(key, index);
        requests.push_back({"field-" + std::to_string(index), field, sampling});
      } else {
        index = found->second;
        ++candidate->metrics_.sharedFieldReuseCount;
      }
      WVObserverOutputVariableSpecification specification;
      specification.identifier = field;
      specification.name = variableName;
      specification.cadence =
          isDynamicsLinear && linearInitialOnly(*metadata)
              ? WVObserverOutputCadence::initialOnly
              : WVObserverOutputCadence::timeSeries;
      specification.dimensionNames = std::move(dimensionNames);
      specification.dimensions = std::move(dimensions);
      specification.units = metadata->units;
      specification.longName = metadata->description;
      if (metadata->netCDFAttributeCount != 0)
        specification.attributes.push_back(
            {metadata->netCDFAttribute.name, metadata->netCDFAttribute.value});
      outputs.push_back(
          {std::move(specification), false, 0, index, initialField, false});
      return WVKernelStatus::ok();
    };

    for (const auto &observer : impl.descriptor.observers) {
      const auto *definition = detail::observerDefinition(observer.kind);
      if (definition == nullptr)
        return {WVKernelStatusCode::unsupportedOperation,
                "Observer output evaluation received an unsupported built-in."};
      const auto outputRule = definition->outputRule;
      auto &outputs = impl.outputsByObserver[observer.identifier];
      if (outputRule == WVObserverOutputRule::coefficients ||
          outputRule == WVObserverOutputRule::eulerianFields) {
        for (const auto &field : outputRule ==
                                          WVObserverOutputRule::coefficients
                                     ? std::vector<std::string>{"Ap", "Am", "A0"}
                                     : observer.fieldNames) {
          const auto *metadata = findPortableVariable(field);
          if (metadata != nullptr &&
              metadata->kind == WVPortableVariableKind::coefficient) {
            WVObserverOutputVariableSpecification specification;
            specification.identifier = field;
            specification.name = field;
            specification.valueType = WVOutputValueType::complex64;
            specification.cadence = isDynamicsLinear
                                        ? WVObserverOutputCadence::initialOnly
                                        : WVObserverOutputCadence::timeSeries;
            for (std::size_t dimension = 0;
                 dimension < metadata->dimensionCount; ++dimension)
              specification.dimensionNames.emplace_back(
                  metadata->dimensions[dimension]);
            specification.dimensions = {configuration.Nj, 0};
            WVTransformConstantStratificationDescriptor transform;
            status = WVTransformConstantStratificationDescriptor::create(
                configuration, transform);
            if (!status)
              return status;
            specification.dimensions[1] = transform.Nkl();
            specification.units = metadata->units;
            specification.longName = metadata->description;
            const std::size_t family =
                metadata->identifier == WVPortableVariable::Ap
                    ? 0
                    : metadata->identifier == WVPortableVariable::Am ? 1 : 2;
            outputs.push_back(
                {std::move(specification), true, family, 0, false, false});
          } else {
            if (metadata == nullptr ||
                metadata->kind != WVPortableVariableKind::field)
              return invalid("Unsupported WVEulerianFields variable: " + field + ".");
            WVFieldSamplingRequest sampling;
            std::vector<std::string> names;
            std::vector<std::size_t> dimensions;
            for (std::size_t dimension = 0;
                 dimension < metadata->dimensionCount; ++dimension)
              names.emplace_back(metadata->dimensions[dimension]);
            if (metadata->naturalRank == WVPortableNaturalRank::vertical) {
              dimensions = {configuration.Nz};
            } else if (metadata->naturalRank ==
                       WVPortableNaturalRank::horizontal) {
              dimensions = {configuration.Nx, configuration.Ny};
            } else if (metadata->naturalRank == WVPortableNaturalRank::scalar) {
              dimensions = {};
            } else {
              dimensions = {configuration.Nx, configuration.Ny, configuration.Nz};
            }
            status = addField(field, sampling, field, std::move(names),
                              std::move(dimensions), outputs);
            if (!status)
              return status;
          }
        }
      } else if (outputRule == WVObserverOutputRule::mooring) {
        if (observer.x.empty() || observer.x.size() != observer.y.size())
          return invalid("WVMooring requires equal nonempty x and y coordinates.");
        WVFieldSamplingRequest sampling;
        sampling.kind = WVFieldSamplingKind::fixedVerticalProfiles;
        const double dx = configuration.Lx / static_cast<double>(configuration.Nx);
        const double dy = configuration.Ly / static_cast<double>(configuration.Ny);
        for (std::size_t index = 0; index < observer.x.size(); ++index) {
          double x = std::fmod(observer.x[index], configuration.Lx);
          double y = std::fmod(observer.y[index], configuration.Ly);
          if (x < 0.0)
            x += configuration.Lx;
          if (y < 0.0)
            y += configuration.Ly;
          sampling.xIndices.push_back(
              std::min(configuration.Nx,
                       static_cast<std::size_t>(std::floor(x / dx)) + 1));
          sampling.yIndices.push_back(
              std::min(configuration.Ny,
                       static_cast<std::size_t>(std::floor(y / dy)) + 1));
        }
        for (const auto &field : observer.fieldNames) {
          status = addField(field, sampling, observer.name + '_' + field,
                            {observer.name + "_z", observer.name + "_id"},
                            {configuration.Nz, observer.x.size()}, outputs);
          if (!status)
            return status;
          outputs.back().specification.longName += ", recorded at the mooring";
        }
      } else if (outputRule ==
                 WVObserverOutputRule::lagrangianParticles) {
        if (observer.z.size() != observer.x.size())
          return invalid("Constant-stratification particles require one z "
                         "coordinate per particle.");
        const std::size_t offset = impl.particleX.size();
        impl.particleX.resize(offset + observer.x.size());
        impl.particleY.resize(offset + observer.x.size());
        impl.particleZ.resize(offset + observer.x.size());
        impl.particleCoordinates.push_back(
            {observer.identifier, observer.stateBlockIdentifiers[0],
             observer.stateBlockIdentifiers[1],
             observer.isXYOnly ? std::string{}
                               : observer.stateBlockIdentifiers[2],
             observer.z, offset, observer.x.size(), observer.isXYOnly});
        for (const auto &field : observer.fieldNames) {
          const auto *metadata = findPortableVariable(field);
          if (metadata == nullptr ||
              metadata->kind != WVPortableVariableKind::field ||
              metadata->movingPrimitiveChannel < 0)
            return invalid("Unsupported particle tracked field: " + field + ".");
          WVObserverOutputVariableSpecification specification;
          specification.identifier = field;
          specification.name = observer.name + '_' + field;
          specification.dimensionNames = {observer.name + "_id"};
          specification.dimensions = {observer.x.size()};
          specification.units = metadata->units;
          specification.longName =
              std::string(metadata->description) +
              ", recorded along the particle trajectory";
          specification.attributes.push_back(
              {"isParticle", "1"});
          specification.attributes.push_back(
              {"particleName", observer.name});
          specification.attributes.push_back(
              {"particleVariableName", field});
          const auto index = impl.particleFieldStorage.size();
          outputs.push_back(
              {std::move(specification), false, 0, index, false, true});
          impl.particleFieldStorage.emplace_back(observer.x.size());
          impl.particleFieldViews.push_back(
              {impl.particleFieldStorage.back().data(), observer.x.size()});
        }
      }
      for (std::size_t index = 0; index < outputs.size(); ++index)
        impl.outputLookup.emplace(
            outputKey(observer, outputs[index].specification.identifier),
            std::make_pair(observer.identifier, index));
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
    if (!impl.particleFieldStorage.empty()) {
      std::vector<WVMovingFieldRequest> particleRequests;
      particleRequests.reserve(impl.particleFieldStorage.size());
      for (const auto &observer : impl.descriptor.observers) {
        const auto *definition = detail::observerDefinition(observer.kind);
        if (definition == nullptr ||
            definition->outputRule !=
                WVObserverOutputRule::lagrangianParticles)
          continue;
        const auto coordinates = std::find_if(
            impl.particleCoordinates.begin(), impl.particleCoordinates.end(),
            [&](const auto &candidate) {
              return candidate.observerIdentifier == observer.identifier;
            });
        for (const auto &field : observer.fieldNames)
          particleRequests.push_back(
              {observer.identifier + '-' + field, field, coordinates->offset,
               coordinates->count, observer.trackedFieldInterpolation});
      }
      status = impl.fields->createMovingPlan(particleRequests,
                                             impl.particleFieldPlan);
      if (!status)
        return status;
      for (std::size_t index = 0; index < impl.particleFieldViews.size(); ++index)
        impl.particleFieldViews[index] = {
            impl.particleFieldStorage[index].data(),
            impl.particleFieldStorage[index].size()};
      for (const auto &storage : impl.particleFieldStorage)
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
  output.reserve(found->second.size());
  for (const auto &value : found->second)
    output.push_back(value.specification);
  return WVKernelStatus::ok();
}

WVKernelStatus WVObserverOutputEvaluationService::preflight(
    const WVOutputPlan &plan) {
  for (std::size_t eventIndex = 0; eventIndex < plan.eventCount(); ++eventIndex) {
    const auto event = plan.event(eventIndex);
    for (std::size_t routeIndex = 0; routeIndex < event.routeCount; ++routeIndex)
      for (std::size_t observerIndex = 0;
           observerIndex < event.routes[routeIndex].observerCount;
           ++observerIndex) {
        const auto *record =
            event.routes[routeIndex].observers[observerIndex].record;
        if (record == nullptr ||
            impl_->outputsByObserver.find(record->identifier) ==
                impl_->outputsByObserver.end())
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
  impl_->ownedFields.reset();
  metrics_.retainedStorageBytes = persistentBytes();
  return WVKernelStatus::ok();
}

WVKernelStatus
WVObserverOutputEvaluationService::prepareInitial(const WVState &state) {
  const auto started = std::chrono::steady_clock::now();
  const auto status = impl_->evaluate(state, true, nullptr, false, metrics_);
  metrics_.evaluationSeconds += std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
  return status;
}

WVKernelStatus WVObserverOutputEvaluationService::prepare(
    const WVOutputEvent &event) {
  const auto started = std::chrono::steady_clock::now();
  bool needsParticles = event.routes == nullptr;
  for (std::size_t route = 0; route < event.routeCount && !needsParticles;
       ++route)
    for (std::size_t observer = 0;
         observer < event.routes[route].observerCount; ++observer) {
      const auto *record = event.routes[route].observers[observer].record;
      const auto *definition =
          record == nullptr ? nullptr : detail::observerDefinition(record->kind);
      if (record != nullptr && definition != nullptr &&
          definition->outputRule ==
              WVObserverOutputRule::lagrangianParticles &&
          !record->fieldNames.empty()) {
        needsParticles = true;
        break;
      }
    }
  const auto status = impl_->evaluate(event.state.waveVortex, false,
                                      &event.state, needsParticles, metrics_);
  metrics_.evaluationSeconds += std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
  return status;
}

WVKernelStatus WVObserverOutputEvaluationService::value(
    const WVObserverRecord &observer,
    const WVObserverOutputVariableSpecification &variable,
    WVObserverOutputValueView &output) {
  if (!impl_->prepared)
    return invalid("Observer values were requested before prepare().");
  const auto found = impl_->outputLookup.find(outputKey(observer, variable.identifier));
  if (found == impl_->outputLookup.end())
    return invalid("Observer output variable is not part of this service.");
  const auto &entry = impl_->outputsByObserver.at(found->second.first)[found->second.second];
  output = {};
  output.valueType = entry.specification.valueType;
  if (entry.coefficient) {
    const auto &coefficients = impl_->preparedState.coefficients;
    output.complexData = entry.coefficientFamily == 0
                             ? coefficients.Ap.data
                             : entry.coefficientFamily == 1 ? coefficients.Am.data
                                                            : coefficients.A0.data;
    output.elementCount = coefficients.Ap.shape.elementCount();
    ++metrics_.borrowedCoefficientViewCount;
  } else {
    const auto &storage = entry.particleField
                              ? impl_->particleFieldStorage
                              : entry.initialField ? impl_->initialFieldStorage
                                                   : impl_->timeSeriesFieldStorage;
    output.realData = storage[entry.fieldOutput].data();
    output.elementCount = storage[entry.fieldOutput].size();
  }
  return WVKernelStatus::ok();
}

std::size_t WVObserverOutputEvaluationService::persistentBytes() const noexcept {
  if (!impl_)
    return sizeof(*this);
  std::size_t bytes = sizeof(*this) + sizeof(Impl) +
                      (impl_->ownedFields
                           ? impl_->ownedFields->persistentBytes()
                           : 0) +
                      impl_->initialFieldPlan.persistentBytes() +
                      impl_->timeSeriesFieldPlan.persistentBytes();
  for (const auto &storage : impl_->initialFieldStorage)
    bytes += storage.capacity() * sizeof(double);
  for (const auto &storage : impl_->timeSeriesFieldStorage)
    bytes += storage.capacity() * sizeof(double);
  bytes += impl_->particleFieldPlan.persistentBytes();
  for (const auto &storage : impl_->particleFieldStorage)
    bytes += storage.capacity() * sizeof(double);
  bytes += (impl_->particleX.capacity() + impl_->particleY.capacity() +
            impl_->particleZ.capacity()) * sizeof(double);
  return bytes;
}

} // namespace wavevortex::runtime
