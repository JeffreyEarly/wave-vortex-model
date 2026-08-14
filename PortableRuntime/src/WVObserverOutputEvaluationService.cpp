#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"

#include <algorithm>
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

struct FieldMetadata {
  const char *units;
  const char *longName;
  const char *attributeName = nullptr;
  const char *attributeValue = nullptr;
};

const std::map<std::string, FieldMetadata> &fieldMetadata() {
  static const std::map<std::string, FieldMetadata> values{
      {"u", {"m s-1", "x-component of the fluid velocity", "standard_name", "eastward_sea_water_velocity"}},
      {"v", {"m s-1", "y-component of the fluid velocity", "standard_name", "northward_sea_water_velocity"}},
      {"w", {"m s-1", "z-component of the fluid velocity", "standard_name", "upwardward_sea_water_velocity"}},
      {"eta", {"m", "approximate isopycnal deviation"}},
      {"pi", {"m", "height anomaly"}},
      {"p", {"kg m-1 s-2", "pressure anomaly"}},
      {"psi", {"m2 s-1", "geostrophic streamfunction"}},
      {"qgpv", {"s-1", "quasigeostrophic potential vorticity"}},
      {"rho_e", {"kg m-3", "excess density"}},
      {"rho_total", {"kg m-3", "total potential density"}},
      {"rho_bar", {"kg m-3", "mean density"}},
      {"zeta_x", {"s-1", "x-component component of relative vorticity"}},
      {"zeta_y", {"s-1", "y-component component of relative vorticity"}},
      {"zeta_z", {"s-1", "vertical component of relative vorticity", "short_name", "ocean_relative_vorticity"}},
      {"ssu", {"m s-1", "x-component of the fluid velocity at the surface"}},
      {"ssv", {"m s-1", "y-component of the fluid velocity at the surface"}},
      {"ssh", {"m", "sea-surface height"}},
      {"energy", {"m3 s-2", "horizontally-averaged depth-integrated energy computed spectrally from wave-vortex coefficients"}},
      {"uvMax", {"m s-1", "max horizontal fluid speed"}},
      {"wMax", {"m s-1", "max vertical fluid speed"}}};
  return values;
}

bool linearInitialOnly(const std::string &name) {
  return name == "Ap" || name == "Am" || name == "A0" || name == "psi" ||
         name == "qgpv" || name == "energy";
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

bool isCoefficient(const std::string &name) {
  return name == "Ap" || name == "Am" || name == "A0";
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
                          const WVCompositeState *composite,
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
      if (composite == nullptr) {
        reset();
        return invalid("Particle output requires composite event state.");
      }
      const auto findBlock = [&](const std::string &identifier) {
        for (std::size_t index = 0; index < composite->additionalBlockCount;
             ++index)
          if (composite->additionalBlocks[index].layout->identifier == identifier)
            return composite->additionalBlocks + index;
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
    std::unique_ptr<WVObserverOutputEvaluationService> &service) {
  try {
    auto candidate = std::unique_ptr<WVObserverOutputEvaluationService>(
        new WVObserverOutputEvaluationService());
    candidate->impl_ = std::make_unique<Impl>();
    auto &impl = *candidate->impl_;
    impl.configuration = configuration;
    impl.isDynamicsLinear = isDynamicsLinear;
    impl.descriptor = descriptor.record();
    auto status = WVFieldEvaluationService::create(
        configuration, std::move(engine), impl.ownedFields);
    if (!status)
      return status;
    impl.fields = impl.ownedFields.get();

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
      const auto metadata = fieldMetadata().find(field);
      if (metadata == fieldMetadata().end())
        return invalid("Unsupported observer field: " + field + ".");
      const bool initialField = isDynamicsLinear && linearInitialOnly(field);
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
          isDynamicsLinear && linearInitialOnly(field)
              ? WVObserverOutputCadence::initialOnly
              : WVObserverOutputCadence::timeSeries;
      specification.dimensionNames = std::move(dimensionNames);
      specification.dimensions = std::move(dimensions);
      specification.units = metadata->second.units;
      specification.longName = metadata->second.longName;
      if (metadata->second.attributeName != nullptr)
        specification.attributes.push_back(
            {metadata->second.attributeName, metadata->second.attributeValue});
      outputs.push_back(
          {std::move(specification), false, 0, index, initialField, false});
      return WVKernelStatus::ok();
    };

    const auto supportedFieldList =
        WVFieldEvaluationService::supportedFieldNames();
    std::set<std::string> supportedFields(supportedFieldList.begin(),
                                          supportedFieldList.end());
    for (const auto &observer : impl.descriptor.observers) {
      auto &outputs = impl.outputsByObserver[observer.identifier];
      if (observer.kind == WVObserverKind::coefficients ||
          observer.kind == WVObserverKind::eulerianFields) {
        for (const auto &field : observer.kind == WVObserverKind::coefficients
                                     ? std::vector<std::string>{"Ap", "Am", "A0"}
                                     : observer.fieldNames) {
          if (isCoefficient(field)) {
            WVObserverOutputVariableSpecification specification;
            specification.identifier = field;
            specification.name = field;
            specification.valueType = WVOutputValueType::complex64;
            specification.cadence = isDynamicsLinear
                                        ? WVObserverOutputCadence::initialOnly
                                        : WVObserverOutputCadence::timeSeries;
            specification.dimensionNames = {"j", "kl"};
            specification.dimensions = {configuration.Nj, 0};
            WVTransformConstantStratificationDescriptor transform;
            status = WVTransformConstantStratificationDescriptor::create(
                configuration, transform);
            if (!status)
              return status;
            specification.dimensions[1] = transform.Nkl();
            specification.units = field == "A0" ? "m2 s-1" : "m s-1";
            specification.longName =
                field == "Ap"
                    ? "positive wave coefficients at reference time t0"
                    : field == "Am"
                          ? "negative wave coefficients at reference time t0"
                          : "geostrophic coefficients at reference time t0";
            const std::size_t family = field == "Ap" ? 0 : field == "Am" ? 1 : 2;
            outputs.push_back(
                {std::move(specification), true, family, 0, false, false});
          } else {
            if (supportedFields.find(field) == supportedFields.end())
              return invalid("Unsupported WVEulerianFields variable: " + field + ".");
            WVFieldSamplingRequest sampling;
            std::vector<std::string> names;
            std::vector<std::size_t> dimensions;
            if (field == "rho_bar") {
              names = {"z"};
              dimensions = {configuration.Nz};
            } else if (field == "ssu" || field == "ssv" || field == "ssh") {
              names = {"x", "y"};
              dimensions = {configuration.Nx, configuration.Ny};
            } else if (field == "energy" || field == "uvMax" || field == "wMax") {
              names = {};
              dimensions = {};
            } else {
              names = {"x", "y", "z"};
              dimensions = {configuration.Nx, configuration.Ny, configuration.Nz};
            }
            status = addField(field, sampling, field, std::move(names),
                              std::move(dimensions), outputs);
            if (!status)
              return status;
          }
        }
      } else if (observer.kind == WVObserverKind::mooring) {
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
      } else if (observer.kind == WVObserverKind::lagrangianParticles) {
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
          const auto metadata = fieldMetadata().find(field);
          if (metadata == fieldMetadata().end())
            return invalid("Unsupported particle tracked field: " + field + ".");
          WVObserverOutputVariableSpecification specification;
          specification.identifier = field;
          specification.name = observer.name + '_' + field;
          specification.dimensionNames = {observer.name + "_id"};
          specification.dimensions = {observer.x.size()};
          specification.units = metadata->second.units;
          specification.longName =
              std::string(metadata->second.longName) +
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
        if (observer.kind != WVObserverKind::lagrangianParticles)
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
    const WVCompositeOutputPlan &plan) {
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
  metrics_.retainedStorageBytes = persistentBytes();
  return WVKernelStatus::ok();
}

WVKernelStatus
WVObserverOutputEvaluationService::prepareInitial(const WVState &state) {
  return impl_->evaluate(state, true, nullptr, false, metrics_);
}

WVKernelStatus WVObserverOutputEvaluationService::prepare(
    const WVCompositeOutputEvent &event) {
  bool needsParticles = event.routes == nullptr;
  for (std::size_t route = 0; route < event.routeCount && !needsParticles;
       ++route)
    for (std::size_t observer = 0;
         observer < event.routes[route].observerCount; ++observer) {
      const auto *record = event.routes[route].observers[observer].record;
      if (record != nullptr &&
          record->kind == WVObserverKind::lagrangianParticles &&
          !record->fieldNames.empty()) {
        needsParticles = true;
        break;
      }
    }
  return impl_->evaluate(event.state.waveVortex, false, &event.state,
                         needsParticles, metrics_);
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
