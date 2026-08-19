#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"
#include "WVObserverAdapter.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <map>
#include <new>
#include <set>
#include <sstream>
#include <tuple>
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
    double scale = 1.0;
    double offset = 0.0;
    bool affine = false;
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

  enum class ObservationSource : std::uint8_t {
    derived,
    additionalState,
    fixedReal
  };

  struct ObservationBinding {
    WVObservationVariable variable;
    ObservationSource source = ObservationSource::derived;
    std::size_t outputIndex = 0;
    std::string stateBlockIdentifier;
    std::vector<double> fixedReal;
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
  std::map<std::string, WVObservationSchema> schemasByObserver;
  std::map<std::string, std::vector<ObservationBinding>>
      observationBindingsByObserver;
  std::map<std::string, std::vector<double>> affineStorage;
  WVState preparedState;
  WVIntegrationState preparedIntegrationState;
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
    preparedIntegrationState = integrationState == nullptr
                                   ? WVIntegrationState{state, nullptr, 0}
                                   : *integrationState;
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
      const auto implementation = detail::observerImplementation(
          observer.typeIdentifier, observer.contractVersion);
      if (!implementation)
        return {WVKernelStatusCode::unsupportedOperation,
                "Observer output evaluation received an unsupported built-in."};
      const auto &behavior = *implementation;
      auto &outputs = impl.outputsByObserver[observer.identifier];
      if (behavior.recordsCoefficients() ||
          behavior.recordsEulerianFields()) {
        for (const auto &field : behavior.recordsCoefficients()
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
      } else if (behavior.recordsFixedProfiles()) {
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
      } else if (behavior.recordsFixedPoints()) {
        if (observer.fieldNames.size() != 1 || observer.x.empty() ||
            observer.x.size() != observer.y.size() ||
            observer.x.size() != observer.z.size())
          return invalid("A fixed-point diagnostic requires one field and "
                         "equal nonempty x/y/z coordinate vectors.");
        WVFieldSamplingRequest sampling;
        sampling.kind = WVFieldSamplingKind::positions;
        sampling.x = observer.x;
        sampling.y = observer.y;
        sampling.z = observer.z;
        sampling.interpolation = observer.trackedFieldInterpolation;
        const auto &field = observer.fieldNames.front();
        status = addField(field, sampling, observer.name + "_value",
                          {observer.name + "_id"}, {observer.x.size()},
                          outputs);
        if (!status)
          return status;
        outputs.back().scale = observer.outputScale;
        outputs.back().offset = observer.outputOffset;
        outputs.back().affine = observer.outputScale != 1.0 ||
                                observer.outputOffset != 0.0;
        outputs.back().specification.longName +=
            ", sampled and affinely transformed by the observing system";
      } else if (behavior.recordsMovingParticles()) {
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
        const auto implementation = detail::observerImplementation(
            observer.typeIdentifier, observer.contractVersion);
        if (!implementation || !implementation->recordsMovingParticles())
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

    const auto stateBlock = [&](const std::string &identifier) {
      const auto found = std::find_if(
          impl.descriptor.stateBlocks.begin(), impl.descriptor.stateBlocks.end(),
          [&](const auto &candidate) {
            return candidate.identifier == identifier;
          });
      return found == impl.descriptor.stateBlocks.end() ? nullptr : &*found;
    };
    const auto addAxis = [](WVObservationSchema &schema,
                            const std::string &name, std::size_t extent,
                            WVObservationCoordinateRole role) {
      const auto found =
          std::find_if(schema.axes.begin(), schema.axes.end(),
                       [&](const auto &axis) { return axis.identifier == name; });
      if (found == schema.axes.end())
        schema.axes.push_back(
            {name, name, WVObservationAxisKind::fixed, extent, role});
    };
    const auto addFixedReal = [&](WVObservationSchema &schema,
                                  std::vector<Impl::ObservationBinding> &bindings,
                                  std::string identifier, std::string name,
                                  std::vector<std::string> dimensions,
                                  WVObservationValueLayout layout,
                                  std::vector<double> values,
                                  std::string units, std::string description,
                                  WVObservationCoordinateRole role,
                                  std::vector<WVObservationAttribute> attributes = {}) {
      WVObservationVariable variable;
      variable.identifier = std::move(identifier);
      variable.name = std::move(name);
      variable.dimensionIdentifiers = std::move(dimensions);
      variable.layout = layout;
      variable.units = std::move(units);
      variable.description = std::move(description);
      variable.attributes = std::move(attributes);
      variable.coordinateRole = role;
      schema.variables.push_back(variable);
      Impl::ObservationBinding binding;
      binding.variable = std::move(variable);
      binding.source = Impl::ObservationSource::fixedReal;
      binding.fixedReal = std::move(values);
      bindings.push_back(std::move(binding));
    };
    const auto addStateReal = [&](WVObservationSchema &schema,
                                  std::vector<Impl::ObservationBinding> &bindings,
                                  std::string identifier, std::string name,
                                  std::vector<std::string> dimensions,
                                  std::string blockIdentifier,
                                  std::string units, std::string description,
                                  WVObservationCoordinateRole role,
                                  std::vector<WVObservationAttribute> attributes = {}) {
      WVObservationVariable variable;
      variable.identifier = std::move(identifier);
      variable.name = std::move(name);
      variable.dimensionIdentifiers = std::move(dimensions);
      variable.layout = WVObservationValueLayout::record;
      variable.units = std::move(units);
      variable.description = std::move(description);
      variable.attributes = std::move(attributes);
      variable.coordinateRole = role;
      schema.variables.push_back(variable);
      Impl::ObservationBinding binding;
      binding.variable = std::move(variable);
      binding.source = Impl::ObservationSource::additionalState;
      binding.stateBlockIdentifier = std::move(blockIdentifier);
      bindings.push_back(std::move(binding));
    };
    const auto addDerived = [&](const WVObserverRecord &observer,
                                WVObservationSchema &schema,
                                std::vector<Impl::ObservationBinding> &bindings) {
      const auto &outputs = impl.outputsByObserver.at(observer.identifier);
      for (std::size_t outputIndex = 0; outputIndex < outputs.size();
           ++outputIndex) {
        const auto &specification = outputs[outputIndex].specification;
        WVObservationVariable variable;
        variable.identifier = "derived-" + specification.identifier;
        variable.name = specification.name;
        variable.scalarType =
            specification.valueType == WVOutputValueType::complex64
                ? WVObservationScalarType::complex64
                : WVObservationScalarType::real64;
        variable.dimensionIdentifiers = specification.dimensionNames;
        variable.layout =
            specification.cadence == WVObserverOutputCadence::initialOnly
                ? WVObservationValueLayout::initialValue
                : WVObservationValueLayout::record;
        variable.units = specification.units;
        variable.description = specification.longName;
        for (const auto &attribute : specification.attributes)
          variable.attributes.push_back({attribute.name, attribute.value});
        for (std::size_t dimension = 0;
             dimension < specification.dimensionNames.size(); ++dimension)
          addAxis(schema, specification.dimensionNames[dimension],
                  specification.dimensions[dimension],
                  WVObservationCoordinateRole::none);
        schema.variables.push_back(variable);
        Impl::ObservationBinding binding;
        binding.variable = std::move(variable);
        binding.source = Impl::ObservationSource::derived;
        binding.outputIndex = outputIndex;
        bindings.push_back(std::move(binding));
      }
    };
    const auto metadataReal = [](const std::string &name, double value) {
      WVObservationMetadataVariable variable;
      variable.name = name;
      variable.value = WVObservationValue::ownReal(name, {}, {value});
      return variable;
    };
    const auto metadataBoolean = [](const std::string &name, bool value) {
      WVObservationMetadataVariable variable;
      variable.name = name;
      variable.value = WVObservationValue::ownBoolean(
          name, {}, {static_cast<std::uint8_t>(value ? 1 : 0)});
      variable.isLogicalType = true;
      return variable;
    };

    for (const auto &observer : impl.descriptor.observers) {
      const auto implementation = detail::observerImplementation(
          observer.typeIdentifier, observer.contractVersion);
      if (!implementation)
        return {WVKernelStatusCode::unsupportedOperation,
                "Observer schema construction received an unsupported implementation."};
      const auto &behavior = *implementation;
      WVObservationSchema schema;
      schema.identifier = "legacy-" + observer.identifier + "-observation-v1";
      schema.preservesLegacyEncoding = true;
      schema.metadata.attributes.push_back(
          {"AnnotatedClass", behavior.typeIdentifier()});
      schema.metadata.attributes.push_back(
          {"portableIdentifier", observer.identifier});
      if (!behavior.recordsEulerianFields())
        schema.metadata.attributes.push_back({"name", observer.name});
      if (!behavior.fieldListAttribute().empty())
        schema.metadata.stringListAttributes.push_back(
            {behavior.fieldListAttribute(), observer.fieldNames});
      auto &bindings =
          impl.observationBindingsByObserver[observer.identifier];

      if (behavior.recordsCoefficients()) {
        const auto *block = stateBlock("Ap");
        schema.metadata.variables.push_back(
            metadataReal("absTolerance",
                         block == nullptr ? 1e-6 : block->absoluteTolerance));
      } else if (behavior.recordsMovingParticles()) {
        schema.metadata.variables.push_back(
            metadataBoolean("isXYOnly", observer.isXYOnly));
        schema.metadata.variables.push_back(metadataReal(
            "absToleranceXY", observer.horizontalAbsoluteTolerance));
        schema.metadata.variables.push_back(metadataReal(
            "absToleranceZ", observer.verticalAbsoluteTolerance));
        schema.metadata.attributes.push_back(
            {"advectionInterpolation",
             observer.advectionInterpolation == WVPositionInterpolation::linear
                 ? "linear"
                 : "spline"});
        schema.metadata.attributes.push_back(
            {"trackedVarInterpolation",
             observer.trackedFieldInterpolation == WVPositionInterpolation::linear
                 ? "linear"
                 : "spline"});
        const std::string idName = observer.name + "_id";
        addAxis(schema, idName, observer.x.size(),
                WVObservationCoordinateRole::identifier);
        std::vector<double> identifiers(observer.x.size());
        for (std::size_t index = 0; index < identifiers.size(); ++index)
          identifiers[index] = static_cast<double>(index + 1);
        addFixedReal(schema, bindings, "static-" + idName, idName, {idName},
                     WVObservationValueLayout::staticValue,
                     std::move(identifiers), "unitless id number", "",
                     WVObservationCoordinateRole::identifier);
        const auto channels = detail::movingFieldChannels(observer);
        for (std::size_t index = 0; index < channels.size(); ++index) {
          const std::string suffix =
              detail::movingFieldChannelName(channels[index]);
          const std::string name =
              detail::movingFieldVariableName(observer, channels[index]);
          const WVObservationCoordinateRole role =
              channels[index] == detail::WVMovingFieldChannel::x
                  ? WVObservationCoordinateRole::x
                  : channels[index] == detail::WVMovingFieldChannel::y
                        ? WVObservationCoordinateRole::y
                        : WVObservationCoordinateRole::z;
          addStateReal(
              schema, bindings, "state-" + suffix, name, {idName},
              observer.stateBlockIdentifiers[index], "m",
              suffix + " position of particle", role,
              {{"isParticle", "1"},
               {"particleName", observer.name},
               {"particleVariableName", suffix}});
        }
        if (observer.isXYOnly && !observer.z.empty())
          addFixedReal(
              schema, bindings, "fixed-z", observer.name + "_z", {idName},
              WVObservationValueLayout::record, observer.z, "m",
              "z position of particle", WVObservationCoordinateRole::z,
              {{"isParticle", "1"},
               {"particleName", observer.name},
               {"particleVariableName", "z"}});
      } else if (behavior.recordsTracerState()) {
        schema.metadata.variables.push_back(
            metadataBoolean("isXYOnly", observer.isXYOnly));
        const auto *block = stateBlock(observer.stateBlockIdentifiers.front());
        schema.metadata.variables.push_back(metadataReal(
            "absTolerance", block == nullptr ? 1e-5 : block->absoluteTolerance));
        schema.metadata.variables.push_back(
            metadataBoolean("shouldAntialias", observer.shouldAntialias));
        const auto &dimensions = block->dimensions;
        const std::vector<std::string> names =
            dimensions.size() == 2
                ? std::vector<std::string>{"x", "y"}
                : std::vector<std::string>{"x", "y", "z"};
        for (std::size_t index = 0; index < names.size(); ++index)
          addAxis(schema, names[index], dimensions[index],
                  names[index] == "x"
                      ? WVObservationCoordinateRole::x
                      : names[index] == "y" ? WVObservationCoordinateRole::y
                                             : WVObservationCoordinateRole::z);
        addStateReal(schema, bindings, "state-tracer", observer.name, names,
                     observer.stateBlockIdentifiers.front(), "", "",
                     WVObservationCoordinateRole::none,
                     {{"isTracer", "1"}});
      } else if (behavior.recordsFixedProfiles()) {
        const std::string idName = observer.name + "_id";
        const std::string zName = observer.name + "_z";
        addAxis(schema, idName, observer.x.size(),
                WVObservationCoordinateRole::identifier);
        addAxis(schema, zName, configuration.Nz,
                WVObservationCoordinateRole::z);
        std::vector<double> identifiers(observer.x.size());
        for (std::size_t index = 0; index < identifiers.size(); ++index)
          identifiers[index] = static_cast<double>(index + 1);
        addFixedReal(schema, bindings, "static-" + idName, idName, {idName},
                     WVObservationValueLayout::staticValue,
                     std::move(identifiers), "unitless id number", "",
                     WVObservationCoordinateRole::identifier);
        std::vector<double> z = observer.z;
        if (z.empty()) {
          z.resize(configuration.Nz);
          const double dz = configuration.Lz /
                            static_cast<double>(configuration.Nz - 1);
          for (std::size_t index = 0; index < z.size(); ++index)
            z[index] = -configuration.Lz + static_cast<double>(index) * dz;
        }
        addFixedReal(schema, bindings, "static-" + zName, zName, {zName},
                     WVObservationValueLayout::staticValue, std::move(z), "m",
                     "z-positions of mooring observations",
                     WVObservationCoordinateRole::z);
        std::vector<double> x = observer.x;
        std::vector<double> y = observer.y;
        for (auto &value : x) {
          value = std::fmod(value, configuration.Lx);
          if (value < 0.0)
            value += configuration.Lx;
        }
        for (auto &value : y) {
          value = std::fmod(value, configuration.Ly);
          if (value < 0.0)
            value += configuration.Ly;
        }
        addFixedReal(schema, bindings, "static-x", observer.name + "_x",
                     {idName}, WVObservationValueLayout::staticValue,
                     std::move(x), "m", "x position of mooring",
                     WVObservationCoordinateRole::x);
        addFixedReal(schema, bindings, "static-y", observer.name + "_y",
                     {idName}, WVObservationValueLayout::staticValue,
                     std::move(y), "m", "y position of mooring",
                     WVObservationCoordinateRole::y);
      } else if (behavior.recordsFixedPoints()) {
        schema.metadata.variables.push_back(
            metadataReal("outputScale", observer.outputScale));
        schema.metadata.variables.push_back(
            metadataReal("outputOffset", observer.outputOffset));
        schema.metadata.attributes.push_back(
            {"trackedVarInterpolation",
             observer.trackedFieldInterpolation == WVPositionInterpolation::linear
                 ? "linear"
                 : "spline"});
        const std::string idName = observer.name + "_id";
        addAxis(schema, idName, observer.x.size(),
                WVObservationCoordinateRole::identifier);
        std::vector<double> identifiers(observer.x.size());
        for (std::size_t index = 0; index < identifiers.size(); ++index)
          identifiers[index] = static_cast<double>(index + 1);
        addFixedReal(schema, bindings, "static-" + idName, idName, {idName},
                     WVObservationValueLayout::staticValue,
                     std::move(identifiers), "unitless id number", "",
                     WVObservationCoordinateRole::identifier);
        for (const auto &[suffix, values, role] :
             std::array<std::tuple<const char *, const std::vector<double> *,
                                   WVObservationCoordinateRole>, 3>{
                 {{"x", &observer.x, WVObservationCoordinateRole::x},
                  {"y", &observer.y, WVObservationCoordinateRole::y},
                  {"z", &observer.z, WVObservationCoordinateRole::z}}})
          addFixedReal(schema, bindings, "static-" + std::string(suffix),
                       observer.name + '_' + suffix, {idName},
                       WVObservationValueLayout::staticValue, *values, "m",
                       std::string(suffix) + " position of fixed observation",
                       role);
      }
      addDerived(observer, schema, bindings);
      const auto schemaStatus = validateObservationSchema(schema);
      if (!schemaStatus)
        return schemaStatus;
      impl.schemasByObserver.emplace(observer.identifier, std::move(schema));
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

WVKernelStatus WVObserverOutputEvaluationService::observationSchema(
    const WVObserverRecord &observer, WVObservationSchema &output) {
  const auto found = impl_->schemasByObserver.find(observer.identifier);
  if (found == impl_->schemasByObserver.end())
    return invalid("Observer is not part of this evaluation service.");
  output = found->second;
  return WVKernelStatus::ok();
}

WVKernelStatus WVObserverOutputEvaluationService::observationBatchForKind(
    const WVObserverRecord &observer, WVObservationBatchKind kind,
    WVObservationBatch &output) {
  const auto schema = impl_->schemasByObserver.find(observer.identifier);
  const auto bindings =
      impl_->observationBindingsByObserver.find(observer.identifier);
  if (schema == impl_->schemasByObserver.end() ||
      bindings == impl_->observationBindingsByObserver.end())
    return invalid("Observer is not part of this evaluation service.");
  if (!impl_->prepared)
    return invalid("Observation batch was requested before prepare().");
  WVObservationBatch batch;
  batch.schemaIdentifier = schema->second.identifier;
  batch.schemaVersion = schema->second.version;
  batch.kind = kind;
  for (const auto &binding : bindings->second) {
    const bool initial =
        binding.variable.layout == WVObservationValueLayout::staticValue ||
        binding.variable.layout == WVObservationValueLayout::initialValue;
    if ((kind == WVObservationBatchKind::initial) != initial)
      continue;
    std::vector<std::size_t> extents;
    extents.reserve(binding.variable.dimensionIdentifiers.size());
    for (const auto &identifier : binding.variable.dimensionIdentifiers) {
      const auto axis = std::find_if(
          schema->second.axes.begin(), schema->second.axes.end(),
          [&](const auto &candidate) {
            return candidate.identifier == identifier;
          });
      if (axis == schema->second.axes.end() ||
          axis->kind != WVObservationAxisKind::fixed)
        return invalid("Built-in observation binding has an invalid axis.");
      extents.push_back(axis->extent);
    }
    if (binding.source == Impl::ObservationSource::fixedReal) {
      batch.values.push_back(WVObservationValue::borrowReal(
          binding.variable.identifier, std::move(extents),
          binding.fixedReal.data()));
      continue;
    }
    if (binding.source == Impl::ObservationSource::additionalState) {
      const WVAdditionalStateBlockConstView *block = nullptr;
      for (std::size_t index = 0;
           index < impl_->preparedIntegrationState.additionalBlockCount;
           ++index)
        if (impl_->preparedIntegrationState.additionalBlocks[index]
                .layout->identifier == binding.stateBlockIdentifier) {
          block = impl_->preparedIntegrationState.additionalBlocks + index;
          break;
        }
      if (block == nullptr || block->realData == nullptr)
        return invalid("Observation batch dynamic state is unavailable.");
      batch.values.push_back(WVObservationValue::borrowReal(
          binding.variable.identifier, std::move(extents), block->realData));
      continue;
    }
    const auto &entry =
        impl_->outputsByObserver.at(observer.identifier)[binding.outputIndex];
    WVObserverOutputValueView valueView;
    auto status = value(observer, entry.specification, valueView);
    if (!status)
      return status;
    if (valueView.valueType == WVOutputValueType::complex64)
      batch.values.push_back(WVObservationValue::borrowComplex(
          binding.variable.identifier, std::move(extents),
          valueView.complexData));
    else
      batch.values.push_back(WVObservationValue::borrowReal(
          binding.variable.identifier, std::move(extents),
          valueView.realData));
  }
  const auto status = validateObservationBatch(schema->second, batch);
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
        const auto *record = resolved.record;
        if (record == nullptr || resolved.implementation == nullptr ||
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
      const auto &resolved = event.routes[route].observers[observer];
      const auto *record = resolved.record;
      if (record != nullptr && resolved.implementation != nullptr &&
          resolved.implementation->recordsMovingParticles() &&
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
    if (entry.affine) {
      auto &transformed = impl_->affineStorage[outputKey(
          observer, variable.identifier)];
      transformed.resize(storage[entry.fieldOutput].size());
      std::transform(storage[entry.fieldOutput].begin(),
                     storage[entry.fieldOutput].end(), transformed.begin(),
                     [&](double value) {
                       return entry.scale * value + entry.offset;
                     });
      output.realData = transformed.data();
      output.elementCount = transformed.size();
    } else {
      output.realData = storage[entry.fieldOutput].data();
      output.elementCount = storage[entry.fieldOutput].size();
    }
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
  for (const auto &[key, storage] : impl_->affineStorage)
    bytes += key.capacity() + storage.capacity() * sizeof(double);
  for (const auto &[identifier, schema] : impl_->schemasByObserver)
    bytes += identifier.capacity() + sizeof(WVObservationSchema) +
             observationSchemaRetainedBytes(schema);
  for (const auto &[identifier, bindings] :
       impl_->observationBindingsByObserver) {
    bytes += identifier.capacity() +
             bindings.capacity() * sizeof(Impl::ObservationBinding);
    for (const auto &binding : bindings) {
      bytes += binding.stateBlockIdentifier.capacity() +
               binding.fixedReal.capacity() * sizeof(double) +
               binding.variable.identifier.capacity() +
               binding.variable.name.capacity() +
               binding.variable.units.capacity() +
               binding.variable.description.capacity() +
               binding.variable.raggedChildAxisIdentifier.capacity() +
               binding.variable.dimensionIdentifiers.capacity() *
                   sizeof(std::string) +
               binding.variable.attributes.capacity() *
                   sizeof(WVObservationAttribute);
      for (const auto &axis : binding.variable.dimensionIdentifiers)
        bytes += axis.capacity();
      for (const auto &attribute : binding.variable.attributes)
        bytes += attribute.name.capacity() + attribute.value.capacity();
    }
  }
  return bytes;
}

} // namespace wavevortex::runtime
