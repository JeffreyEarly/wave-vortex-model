#include "WVObserverAdapter.hpp"
#include "WaveVortexRuntime/WVObserverOutputProvider.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <mutex>
#include <tuple>
#include <utility>

namespace wavevortex::runtime::detail {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

WVKernelStatus configuredText(const WVObserverRecord &observer,
                              const char *name,
                              const std::vector<std::string> &fallback,
                              std::vector<std::string> &output) {
  const auto *value = observer.configuration.value(name);
  if (value == nullptr) {
    output = fallback;
    return WVKernelStatus::ok();
  }
  const auto *text =
      std::get_if<std::vector<std::string>>(&value->storage);
  if (text == nullptr)
    return invalid(std::string("Observer configuration value '") + name +
                   "' must contain text.");
  output = *text;
  return WVKernelStatus::ok();
}

void addAxis(WVObservationSchema &schema, const std::string &name,
             std::size_t extent, WVObservationCoordinateRole role) {
  const auto found =
      std::find_if(schema.axes.begin(), schema.axes.end(),
                   [&](const auto &axis) { return axis.identifier == name; });
  if (found == schema.axes.end())
    schema.axes.push_back(
        {name, name, WVObservationAxisKind::fixed, extent, role});
}

WVObservationMetadataVariable metadataReal(const std::string &name,
                                           double value) {
  WVObservationMetadataVariable variable;
  variable.name = name;
  variable.value = WVObservationValue::ownReal(name, {}, {value});
  return variable;
}

WVObservationMetadataVariable metadataBoolean(const std::string &name,
                                              bool value) {
  WVObservationMetadataVariable variable;
  variable.name = name;
  variable.value = WVObservationValue::ownBoolean(
      name, {}, {static_cast<std::uint8_t>(value ? 1 : 0)});
  variable.isLogicalType = true;
  return variable;
}

void addConstantReal(
    WVObserverOutputPlan &plan, std::string identifier, std::string name,
    std::vector<std::string> dimensions, WVObservationValueLayout layout,
    std::vector<double> values, std::string units, std::string description,
    WVObservationCoordinateRole role,
    std::vector<WVObservationAttribute> attributes = {}) {
  WVObservationVariable variable;
  variable.identifier = identifier;
  variable.name = std::move(name);
  variable.dimensionIdentifiers = std::move(dimensions);
  variable.layout = layout;
  variable.units = std::move(units);
  variable.description = std::move(description);
  variable.attributes = std::move(attributes);
  variable.coordinateRole = role;
  plan.schema.variables.push_back(std::move(variable));
  std::vector<std::size_t> extents;
  for (const auto &dimension :
       plan.schema.variables.back().dimensionIdentifiers) {
    const auto axis = std::find_if(
        plan.schema.axes.begin(), plan.schema.axes.end(),
        [&](const auto &candidate) {
          return candidate.identifier == dimension;
        });
    extents.push_back(axis == plan.schema.axes.end() ? 0 : axis->extent);
  }
  plan.constantValues.push_back(WVObservationValue::ownReal(
      std::move(identifier), std::move(extents), std::move(values)));
}

void addChannel(WVObserverOutputPlan &plan, WVObservationVariable variable,
                WVObserverOutputChannel channel) {
  channel.variableIdentifier = variable.identifier;
  plan.schema.variables.push_back(std::move(variable));
  plan.channels.push_back(std::move(channel));
}

WVObservationVariable fieldVariable(
    const WVPortableVariableMetadata &metadata, std::string identifier,
    std::string name, std::vector<std::string> dimensions,
    WVObservationValueLayout layout, std::string descriptionSuffix = {}) {
  WVObservationVariable variable;
  variable.identifier = std::move(identifier);
  variable.name = std::move(name);
  variable.scalarType = metadata.kind == WVPortableVariableKind::coefficient
                            ? WVObservationScalarType::complex64
                            : WVObservationScalarType::real64;
  variable.dimensionIdentifiers = std::move(dimensions);
  variable.layout = layout;
  variable.units = metadata.units;
  variable.description = std::string(metadata.description) + descriptionSuffix;
  if (metadata.netCDFAttributeCount != 0)
    variable.attributes.push_back(
        {metadata.netCDFAttribute.name, metadata.netCDFAttribute.value});
  return variable;
}

WVKernelStatus buildLegacyOutputPlan(
    const WVObservingSystem &implementation,
    const WVObserverRecord &observer,
    const WVObserverExecutionPlan &execution,
    const WVObserverOutputPlanningContext &context,
    WVObserverOutputPlan &output) {
  if (context.configuration == nullptr)
    return invalid("Observer output planning requires a transform configuration.");
  const auto &configuration = *context.configuration;
  WVObserverOutputPlan plan;
  plan.schema.identifier =
      "legacy-" + observer.identifier + "-observation-v1";
  plan.schema.preservesLegacyEncoding = true;
  plan.schema.metadata.attributes.push_back(
      {"AnnotatedClass", implementation.typeIdentifier()});
  plan.schema.metadata.attributes.push_back(
      {"portableIdentifier", observer.identifier});
  if (!execution.persistedName.empty())
    plan.schema.metadata.attributes.push_back(
        {"name", execution.persistedName});
  if (!execution.fieldListAttribute.empty())
    plan.schema.metadata.stringListAttributes.push_back(
        {execution.fieldListAttribute, execution.outputFields});

  const auto outputLayout = [&](const WVPortableVariableMetadata &metadata) {
    return context.isDynamicsLinear &&
                   !metadata.isVariableWithLinearTimeStep
               ? WVObservationValueLayout::initialValue
               : WVObservationValueLayout::record;
  };
  const auto addFullField = [&](const std::string &field) {
    const auto *metadata = findPortableVariable(field);
    if (metadata == nullptr)
      return invalid("Unsupported observer field: " + field + ".");
    std::vector<std::string> names;
    for (std::size_t dimension = 0; dimension < metadata->dimensionCount;
         ++dimension)
      names.emplace_back(metadata->dimensions[dimension]);
    std::vector<std::size_t> dimensions;
    WVObserverOutputChannel channel;
    channel.sourceIdentifier = field;
    if (metadata->kind == WVPortableVariableKind::coefficient) {
      WVTransformConstantStratificationDescriptor transform;
      auto status = WVTransformConstantStratificationDescriptor::create(
          configuration, transform);
      if (!status)
        return status;
      dimensions = {configuration.Nj, transform.Nkl()};
      channel.source = WVObserverOutputChannelSource::coefficient;
      channel.coefficientFamily =
          metadata->identifier == WVPortableVariable::Ap
              ? 0
              : metadata->identifier == WVPortableVariable::Am ? 1 : 2;
    } else if (metadata->kind == WVPortableVariableKind::field) {
      if (metadata->naturalRank == WVPortableNaturalRank::vertical)
        dimensions = {configuration.Nz};
      else if (metadata->naturalRank == WVPortableNaturalRank::horizontal)
        dimensions = {configuration.Nx, configuration.Ny};
      else if (metadata->naturalRank == WVPortableNaturalRank::scalar)
        dimensions = {};
      else
        dimensions = {configuration.Nx, configuration.Ny, configuration.Nz};
      channel.source = WVObserverOutputChannelSource::sampledField;
    } else {
      return invalid("Unsupported observer field: " + field + ".");
    }
    for (std::size_t index = 0; index < names.size(); ++index)
      addAxis(plan.schema, names[index], dimensions[index],
              WVObservationCoordinateRole::none);
    addChannel(plan,
               fieldVariable(*metadata, "derived-" + field, field, names,
                             outputLayout(*metadata)),
               std::move(channel));
    return WVKernelStatus::ok();
  };

  if (observer.stateBlockIdentifiers ==
      std::vector<std::string>({"Ap", "Am", "A0"})) {
    const auto *block = context.stateBlock("Ap");
    plan.schema.metadata.variables.push_back(
        metadataReal("absTolerance",
                     block == nullptr ? 1e-6 : block->absoluteTolerance));
  }

  switch (execution.sampling) {
  case WVObserverSamplingTopology::fullField:
    for (const auto &field : execution.outputFields) {
      const auto status = addFullField(field);
      if (!status)
        return status;
    }
    break;
  case WVObserverSamplingTopology::fixedVerticalProfiles: {
    const std::string idName = observer.name + "_id";
    const std::string zName = observer.name + "_z";
    addAxis(plan.schema, idName, observer.x.size(),
            WVObservationCoordinateRole::identifier);
    addAxis(plan.schema, zName, configuration.Nz,
            WVObservationCoordinateRole::z);
    std::vector<double> identifiers(observer.x.size());
    for (std::size_t index = 0; index < identifiers.size(); ++index)
      identifiers[index] = static_cast<double>(index + 1);
    addConstantReal(plan, "static-" + idName, idName, {idName},
                    WVObservationValueLayout::staticValue,
                    std::move(identifiers), "unitless id number", "",
                    WVObservationCoordinateRole::identifier);
    std::vector<double> z = observer.z;
    if (z.empty()) {
      z.resize(configuration.Nz);
      const double dz =
          configuration.Lz / static_cast<double>(configuration.Nz - 1);
      for (std::size_t index = 0; index < z.size(); ++index)
        z[index] = -configuration.Lz + static_cast<double>(index) * dz;
    }
    addConstantReal(plan, "static-" + zName, zName, {zName},
                    WVObservationValueLayout::staticValue, std::move(z), "m",
                    "z-positions of mooring observations",
                    WVObservationCoordinateRole::z);
    std::vector<double> x = observer.x;
    std::vector<double> y = observer.y;
    WVFieldSamplingRequest sampling;
    sampling.kind = WVFieldSamplingKind::fixedVerticalProfiles;
    const double dx = configuration.Lx / static_cast<double>(configuration.Nx);
    const double dy = configuration.Ly / static_cast<double>(configuration.Ny);
    for (std::size_t index = 0; index < x.size(); ++index) {
      x[index] = std::fmod(x[index], configuration.Lx);
      y[index] = std::fmod(y[index], configuration.Ly);
      if (x[index] < 0.0)
        x[index] += configuration.Lx;
      if (y[index] < 0.0)
        y[index] += configuration.Ly;
      sampling.xIndices.push_back(std::min(
          configuration.Nx,
          static_cast<std::size_t>(std::floor(x[index] / dx)) + 1));
      sampling.yIndices.push_back(std::min(
          configuration.Ny,
          static_cast<std::size_t>(std::floor(y[index] / dy)) + 1));
    }
    addConstantReal(plan, "static-x", observer.name + "_x", {idName},
                    WVObservationValueLayout::staticValue, std::move(x), "m",
                    "x position of mooring", WVObservationCoordinateRole::x);
    addConstantReal(plan, "static-y", observer.name + "_y", {idName},
                    WVObservationValueLayout::staticValue, std::move(y), "m",
                    "y position of mooring", WVObservationCoordinateRole::y);
    for (const auto &field : execution.outputFields) {
      const auto *metadata = findPortableVariable(field);
      if (metadata == nullptr ||
          metadata->kind != WVPortableVariableKind::field)
        return invalid("Unsupported mooring field: " + field + ".");
      WVObserverOutputChannel channel;
      channel.source = WVObserverOutputChannelSource::sampledField;
      channel.sourceIdentifier = field;
      channel.sampling = sampling;
      addChannel(
          plan,
          fieldVariable(*metadata, "derived-" + field,
                        observer.name + '_' + field, {zName, idName},
                        outputLayout(*metadata), ", recorded at the mooring"),
          std::move(channel));
    }
    break;
  }
  case WVObserverSamplingTopology::fixedPositions: {
    plan.schema.metadata.variables.push_back(
        metadataReal("outputScale", observer.outputScale));
    plan.schema.metadata.variables.push_back(
        metadataReal("outputOffset", observer.outputOffset));
    plan.schema.metadata.attributes.push_back(
        {"trackedVarInterpolation",
         observer.trackedFieldInterpolation == WVPositionInterpolation::linear
             ? "linear"
             : "spline"});
    const std::string idName = observer.name + "_id";
    addAxis(plan.schema, idName, observer.x.size(),
            WVObservationCoordinateRole::identifier);
    std::vector<double> identifiers(observer.x.size());
    for (std::size_t index = 0; index < identifiers.size(); ++index)
      identifiers[index] = static_cast<double>(index + 1);
    addConstantReal(plan, "static-" + idName, idName, {idName},
                    WVObservationValueLayout::staticValue,
                    std::move(identifiers), "unitless id number", "",
                    WVObservationCoordinateRole::identifier);
    for (const auto &[suffix, values, role] :
         std::array<std::tuple<const char *, const std::vector<double> *,
                               WVObservationCoordinateRole>,
                    3>{{{"x", &observer.x, WVObservationCoordinateRole::x},
                        {"y", &observer.y, WVObservationCoordinateRole::y},
                        {"z", &observer.z, WVObservationCoordinateRole::z}}})
      addConstantReal(plan, "static-" + std::string(suffix),
                      observer.name + '_' + suffix, {idName},
                      WVObservationValueLayout::staticValue, *values, "m",
                      std::string(suffix) + " position of fixed observation",
                      role);
    const auto &field = execution.outputFields.front();
    const auto *metadata = findPortableVariable(field);
    if (metadata == nullptr ||
        metadata->kind != WVPortableVariableKind::field)
      return invalid("Unsupported fixed-position field: " + field + ".");
    WVObserverOutputChannel channel;
    channel.source = WVObserverOutputChannelSource::sampledField;
    channel.sourceIdentifier = field;
    channel.sampling.kind = WVFieldSamplingKind::positions;
    channel.sampling.x = observer.x;
    channel.sampling.y = observer.y;
    channel.sampling.z = observer.z;
    channel.sampling.interpolation = observer.trackedFieldInterpolation;
    channel.scale = observer.outputScale;
    channel.offset = observer.outputOffset;
    addChannel(
        plan,
        fieldVariable(*metadata, "derived-" + field,
                      observer.name + "_value", {idName},
                      outputLayout(*metadata),
                      ", sampled and affinely transformed by the observing system"),
        std::move(channel));
    break;
  }
  case WVObserverSamplingTopology::movingPositions: {
    plan.schema.metadata.variables.push_back(
        metadataBoolean("isXYOnly", observer.isXYOnly));
    plan.schema.metadata.variables.push_back(metadataReal(
        "absToleranceXY", observer.horizontalAbsoluteTolerance));
    plan.schema.metadata.variables.push_back(metadataReal(
        "absToleranceZ", observer.verticalAbsoluteTolerance));
    plan.schema.metadata.attributes.push_back(
        {"advectionInterpolation",
         observer.advectionInterpolation == WVPositionInterpolation::linear
             ? "linear"
             : "spline"});
    plan.schema.metadata.attributes.push_back(
        {"trackedVarInterpolation",
         observer.trackedFieldInterpolation == WVPositionInterpolation::linear
             ? "linear"
             : "spline"});
    const std::string idName = observer.name + "_id";
    addAxis(plan.schema, idName, observer.x.size(),
            WVObservationCoordinateRole::identifier);
    std::vector<double> identifiers(observer.x.size());
    for (std::size_t index = 0; index < identifiers.size(); ++index)
      identifiers[index] = static_cast<double>(index + 1);
    const auto particleAttributes = [&](const std::string &value) {
      return std::vector<WVObservationAttribute>{
          {"isParticle", "1"}, {"particleName", observer.name},
          {"particleVariableName", value}};
    };
    addConstantReal(plan, "static-" + idName, idName, {idName},
                    WVObservationValueLayout::staticValue,
                    std::move(identifiers), "unitless id number", "",
                    WVObservationCoordinateRole::identifier,
                    particleAttributes("id"));
    const auto channels = movingFieldChannels(observer);
    for (std::size_t index = 0; index < channels.size(); ++index) {
      const std::string suffix = movingFieldChannelName(channels[index]);
      WVObservationVariable variable;
      variable.identifier = "state-" + suffix;
      variable.name = movingFieldVariableName(observer, channels[index]);
      variable.dimensionIdentifiers = {idName};
      variable.layout = WVObservationValueLayout::record;
      variable.units = "m";
      variable.description = suffix + " position of particle";
      variable.attributes = particleAttributes(suffix);
      variable.coordinateRole =
          channels[index] == WVMovingFieldChannel::x
              ? WVObservationCoordinateRole::x
              : channels[index] == WVMovingFieldChannel::y
                    ? WVObservationCoordinateRole::y
                    : WVObservationCoordinateRole::z;
      WVObserverOutputChannel channel;
      channel.source = WVObserverOutputChannelSource::additionalState;
      channel.sourceIdentifier = observer.stateBlockIdentifiers[index];
      addChannel(plan, std::move(variable), std::move(channel));
    }
    if (observer.isXYOnly && !observer.z.empty())
      addConstantReal(plan, "fixed-z", observer.name + "_z", {idName},
                      WVObservationValueLayout::record, observer.z, "m",
                      "z position of particle",
                      WVObservationCoordinateRole::z,
                      particleAttributes("z"));
    plan.movingPositions.stateBlockIdentifiers =
        observer.stateBlockIdentifiers;
    plan.movingPositions.fixedZ = observer.z;
    plan.movingPositions.positionCount = observer.x.size();
    plan.movingPositions.isXYOnly = observer.isXYOnly;
    plan.movingPositions.interpolation =
        observer.trackedFieldInterpolation;
    for (const auto &field : execution.outputFields) {
      const auto *metadata = findPortableVariable(field);
      if (metadata == nullptr ||
          metadata->kind != WVPortableVariableKind::field ||
          metadata->movingPrimitiveChannel < 0)
        return invalid("Unsupported particle tracked field: " + field + ".");
      auto variable = fieldVariable(
          *metadata, "derived-" + field, observer.name + '_' + field,
          {idName}, WVObservationValueLayout::record,
          ", recorded along the particle trajectory");
      variable.attributes = particleAttributes(field);
      WVObserverOutputChannel channel;
      channel.source = WVObserverOutputChannelSource::movingField;
      channel.sourceIdentifier = field;
      addChannel(plan, std::move(variable), std::move(channel));
    }
    break;
  }
  case WVObserverSamplingTopology::integratedState: {
    plan.schema.metadata.variables.push_back(
        metadataBoolean("isXYOnly", observer.isXYOnly));
    const auto *block =
        context.stateBlock(observer.stateBlockIdentifiers.front());
    if (block == nullptr)
      return invalid("Integrated observer state block is unavailable.");
    plan.schema.metadata.variables.push_back(metadataReal(
        "absTolerance", block->absoluteTolerance));
    plan.schema.metadata.variables.push_back(
        metadataBoolean("shouldAntialias", observer.shouldAntialias));
    const std::vector<std::string> names =
        block->dimensions.size() == 2
            ? std::vector<std::string>{"x", "y"}
            : std::vector<std::string>{"x", "y", "z"};
    for (std::size_t index = 0; index < names.size(); ++index)
      addAxis(plan.schema, names[index], block->dimensions[index],
              names[index] == "x"
                  ? WVObservationCoordinateRole::x
                  : names[index] == "y" ? WVObservationCoordinateRole::y
                                           : WVObservationCoordinateRole::z);
    WVObservationVariable variable;
    variable.identifier = "state-tracer";
    variable.name = observer.name;
    variable.dimensionIdentifiers = names;
    variable.layout = WVObservationValueLayout::record;
    variable.attributes = {{"isTracer", "1"}};
    WVObserverOutputChannel channel;
    channel.source = WVObserverOutputChannelSource::additionalState;
    channel.sourceIdentifier = observer.stateBlockIdentifiers.front();
    addChannel(plan, std::move(variable), std::move(channel));
    break;
  }
  }
  const auto status = validateObservationSchema(plan.schema);
  if (!status)
    return status;
  output = std::move(plan);
  return WVKernelStatus::ok();
}

class BuiltInObservingSystem : public WVObservingSystem {
public:
  explicit BuiltInObservingSystem(std::string typeIdentifier)
      : typeIdentifier_(std::move(typeIdentifier)) {}

  const std::string &typeIdentifier() const noexcept override {
    return typeIdentifier_;
  }
  std::uint32_t contractVersion() const noexcept override {
    return WVPortablePairContractVersion;
  }
  WVKernelStatus outputPlan(
      const WVObserverRecord &observer,
      const WVObserverOutputPlanningContext &context,
      WVObserverOutputPlan &plan) const override {
    WVObserverExecutionPlan execution;
    const auto status = executionPlan(observer, execution);
    if (!status)
      return status;
    return buildLegacyOutputPlan(*this, observer, execution, context, plan);
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this) + typeIdentifier_.capacity();
  }

protected:
  static WVKernelStatus validateSampleOnly(
      const WVObserverRecord &observer) {
    return observer.stateBlockIdentifiers.empty()
               ? WVKernelStatus::ok()
               : invalid("Sample-only observers cannot own integrated state blocks.");
  }

private:
  std::string typeIdentifier_;
};

class WVCoefficientsImplementation final : public BuiltInObservingSystem {
public:
  WVCoefficientsImplementation() : BuiltInObservingSystem("WVCoefficients") {}
  WVKernelStatus executionPlan(const WVObserverRecord &observer,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.persistedName = observer.name;
    plan.outputFields = {"Ap", "Am", "A0"};
    plan.coefficientRestartFamilies = plan.outputFields;
    return WVKernelStatus::ok();
  }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    if (observer.stateBlockIdentifiers !=
        std::vector<std::string>({"Ap", "Am", "A0"}))
      return invalid(
          "WVCoefficients must reference Ap, Am, and A0 in canonical order.");
    return WVKernelStatus::ok();
  }
};

class WVEulerianFieldsImplementation final : public BuiltInObservingSystem {
public:
  WVEulerianFieldsImplementation()
      : BuiltInObservingSystem("WVEulerianFields") {}
  WVKernelStatus executionPlan(const WVObserverRecord &observer,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.fieldListAttribute = "fieldNames";
    auto status = configuredText(observer, "fieldNames", observer.fieldNames,
                                 plan.outputFields);
    if (!status)
      return status;
    for (const auto *family : {"Ap", "Am", "A0"})
      if (std::find(observer.fieldNames.begin(), observer.fieldNames.end(),
                    family) != observer.fieldNames.end())
        plan.coefficientRestartFamilies.emplace_back(family);
    return WVKernelStatus::ok();
  }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    return validateSampleOnly(observer);
  }
};

class WVMooringImplementation final : public BuiltInObservingSystem {
public:
  WVMooringImplementation()
      : BuiltInObservingSystem("WVMooring") {}
  WVKernelStatus executionPlan(const WVObserverRecord &observer,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.sampling = WVObserverSamplingTopology::fixedVerticalProfiles;
    plan.fieldListAttribute = "trackedFieldNames";
    plan.persistedName = observer.name;
    return configuredText(observer, "trackedFieldNames", observer.fieldNames,
                          plan.outputFields);
  }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    const auto status = validateSampleOnly(observer);
    if (!status)
      return status;
    if (observer.x.empty() || observer.x.size() != observer.y.size())
      return invalid("WVMooring requires equal nonempty x and y coordinates.");
    return WVKernelStatus::ok();
  }
};

class WVLagrangianParticlesImplementation final
    : public BuiltInObservingSystem {
public:
  WVLagrangianParticlesImplementation()
      : BuiltInObservingSystem("WVLagrangianParticles") {}
  WVKernelStatus executionPlan(const WVObserverRecord &observer,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.sampling = WVObserverSamplingTopology::movingPositions;
    plan.integratedOperation =
        WVObserverIntegratedOperation::advectedPositions;
    plan.fieldListAttribute = "trackedFieldNames";
    plan.persistedName = observer.name;
    return configuredText(observer, "trackedFieldNames", observer.fieldNames,
                          plan.outputFields);
  }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &blocks,
      std::map<std::string, std::size_t> &ownerCounts) const override {
    if (observer.x.empty() || observer.x.size() != observer.y.size())
      return invalid(
          "WVLagrangianParticles requires equal nonempty x and y coordinates.");
    if (!observer.isXYOnly && observer.z.size() != observer.x.size())
      return invalid(
          "Three-dimensional particles require one z coordinate per particle.");
    if (!(observer.horizontalAbsoluteTolerance > 0.0) ||
        !std::isfinite(observer.horizontalAbsoluteTolerance))
      return invalid(
          "Particle horizontal tolerance must be finite and positive.");
    if (!observer.isXYOnly &&
        (!(observer.verticalAbsoluteTolerance > 0.0) ||
         !std::isfinite(observer.verticalAbsoluteTolerance)))
      return invalid("Particle vertical tolerance must be finite and positive.");
    const auto channels = movingFieldChannels(observer);
    if (observer.stateBlockIdentifiers.size() != channels.size())
      return invalid("WVLagrangianParticles requires ordered x, y, and "
                     "optional z state blocks.");
    for (const auto &identifier : observer.stateBlockIdentifiers) {
      const auto found = blocks.find(identifier);
      if (found == blocks.end())
        return invalid("Particle observer references an unknown state block.");
      const auto *block = found->second;
      if (block->scalarType != WVStateScalarType::real64 ||
          block->ownership != WVStateOwnership::integratorOwned ||
          block->dimensions !=
              std::vector<std::size_t>({observer.x.size()}))
        return invalid("Particle state blocks must be integrator-owned real "
                       "vectors matching the particle count.");
      ++ownerCounts.at(identifier);
    }
    return WVKernelStatus::ok();
  }
};

class WVTracerImplementation final : public BuiltInObservingSystem {
public:
  WVTracerImplementation() : BuiltInObservingSystem("WVTracer") {}
  WVKernelStatus executionPlan(const WVObserverRecord &observer,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.sampling = WVObserverSamplingTopology::integratedState;
    plan.integratedOperation = WVObserverIntegratedOperation::advectedScalar;
    plan.persistedName = observer.name;
    return WVKernelStatus::ok();
  }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &blocks,
      std::map<std::string, std::size_t> &ownerCounts) const override {
    if (observer.stateBlockIdentifiers.size() != 1)
      return invalid("WVTracer requires exactly one state block.");
    const auto found = blocks.find(observer.stateBlockIdentifiers.front());
    if (found == blocks.end())
      return invalid("WVTracer references an unknown state block.");
    const auto *block = found->second;
    if (block->scalarType != WVStateScalarType::real64 ||
        block->ownership != WVStateOwnership::integratorOwned)
      return invalid("WVTracer requires one integrator-owned real state block.");
    const std::size_t expectedRank = observer.isXYOnly ? 2 : 3;
    if (block->dimensions.size() != expectedRank)
      return invalid(observer.isXYOnly
                         ? "A two-dimensional WVTracer requires a rank-two state block."
                         : "A three-dimensional WVTracer requires a rank-three state block.");
    ++ownerCounts.at(observer.stateBlockIdentifiers.front());
    return WVKernelStatus::ok();
  }
};

std::deque<std::shared_ptr<const WVObservingSystem>> &mutableImplementations() {
  static std::deque<std::shared_ptr<const WVObservingSystem>> implementations{
      std::make_shared<WVCoefficientsImplementation>(),
      std::make_shared<WVEulerianFieldsImplementation>(),
      std::make_shared<WVMooringImplementation>(),
      std::make_shared<WVLagrangianParticlesImplementation>(),
      std::make_shared<WVTracerImplementation>()};
  return implementations;
}

std::mutex &registryMutex() {
  static std::mutex value;
  return value;
}

bool &registrySealed() {
  static bool value = false;
  return value;
}

} // namespace

const std::deque<std::shared_ptr<const WVObservingSystem>> &
observerImplementations() noexcept {
  return mutableImplementations();
}

std::shared_ptr<const WVObservingSystem>
observerImplementation(const std::string &typeIdentifier,
                       std::uint32_t contractVersion) noexcept {
  for (const auto &implementation : mutableImplementations())
    if (implementation->typeIdentifier() == typeIdentifier &&
        implementation->contractVersion() == contractVersion)
      return implementation;
  return {};
}

WVKernelStatus registerObserverImplementation(
    std::shared_ptr<const WVObservingSystem> implementation) {
  if (!implementation || implementation->typeIdentifier().empty())
    return invalid("Observer implementation identity must be nonempty.");
  if (implementation->contractVersion() == 0)
    return invalid("Observer implementation contract versions must be positive.");
  std::lock_guard<std::mutex> lock(registryMutex());
  if (registrySealed())
    return invalid(
        "Observer implementations must be registered before descriptor construction.");
  for (const auto &existing : mutableImplementations())
    if (existing->typeIdentifier() == implementation->typeIdentifier() &&
        existing->contractVersion() == implementation->contractVersion())
      return invalid(
          "Observer implementation identity/version pairs must be unique.");
  mutableImplementations().push_back(std::move(implementation));
  return WVKernelStatus::ok();
}

void sealObserverDefinitions() noexcept {
  std::lock_guard<std::mutex> lock(registryMutex());
  registrySealed() = true;
}

bool observerDefinitionsSealed() noexcept {
  std::lock_guard<std::mutex> lock(registryMutex());
  return registrySealed();
}

WVKernelStatus resolveObserverConfiguration(
    const WVObserverRecord &observer, WVPortableTypedRecord &configuration) {
  if (!observer.configuration.schemaIdentifier.empty()) {
    const auto status = validatePortableTypedRecord(
        observer.configuration, {1024 * 1024, true, true});
    if (!status)
      return status;
    configuration = observer.configuration;
    return WVKernelStatus::ok();
  }

  WVPortableTypedRecord candidate;
  candidate.schemaIdentifier =
      "legacy-" + observer.typeIdentifier + "-configuration-v1";
  candidate.schemaVersion = 1;
  const auto addText = [&](std::string name,
                           const std::vector<std::string> &values) {
    if (!values.empty())
      candidate.values.push_back(
          {std::move(name), {values.size()}, values});
  };
  const auto addReal = [&](std::string name,
                           const std::vector<double> &values) {
    if (!values.empty())
      candidate.values.push_back(
          {std::move(name), {values.size()}, values});
  };
  const auto addBoolean = [&](std::string name, bool value) {
    candidate.values.push_back(
        {std::move(name), {},
         std::vector<std::uint8_t>{static_cast<std::uint8_t>(value ? 1 : 0)}});
  };
  const auto addScalar = [&](std::string name, double value) {
    candidate.values.push_back(
        {std::move(name), {}, std::vector<double>{value}});
  };
  const auto interpolation = [](WVPositionInterpolation value) {
    return value == WVPositionInterpolation::spline ? std::string("spline")
                                                     : std::string("linear");
  };

  if (observer.typeIdentifier == "WVEulerianFields") {
    addText("fieldNames", observer.fieldNames);
  } else if (observer.typeIdentifier == "WVMooring") {
    addText("trackedFieldNames", observer.fieldNames);
    addReal("x", observer.x);
    addReal("y", observer.y);
    addReal("z", observer.z);
  } else if (observer.typeIdentifier == "WVLagrangianParticles") {
    addText("trackedFieldNames", observer.fieldNames);
    addReal("x", observer.x);
    addReal("y", observer.y);
    addReal("z", observer.z);
    addBoolean("isXYOnly", observer.isXYOnly);
    candidate.values.push_back(
        {"advectionInterpolation", {},
         std::vector<std::string>{
             interpolation(observer.advectionInterpolation)}});
    candidate.values.push_back(
        {"trackedFieldInterpolation", {},
         std::vector<std::string>{
             interpolation(observer.trackedFieldInterpolation)}});
    addScalar("horizontalAbsoluteTolerance",
              observer.horizontalAbsoluteTolerance);
    addScalar("verticalAbsoluteTolerance", observer.verticalAbsoluteTolerance);
  } else if (observer.typeIdentifier == "WVTracer") {
    addBoolean("isXYOnly", observer.isXYOnly);
    addBoolean("shouldAntialias", observer.shouldAntialias);
  } else if (observer.typeIdentifier != "WVCoefficients") {
    // Source-linked implementations without a built-in compatibility mapping
    // receive a sparse typed record. Providers should supply an explicit
    // schema to avoid this legacy inference path.
    addText("fieldNames", observer.fieldNames);
    addReal("x", observer.x);
    addReal("y", observer.y);
    addReal("z", observer.z);
    addBoolean("isXYOnly", observer.isXYOnly);
    addBoolean("shouldAntialias", observer.shouldAntialias);
    addScalar("horizontalAbsoluteTolerance",
              observer.horizontalAbsoluteTolerance);
    addScalar("verticalAbsoluteTolerance", observer.verticalAbsoluteTolerance);
    addScalar("outputScale", observer.outputScale);
    addScalar("outputOffset", observer.outputOffset);
  }
  const auto status =
      validatePortableTypedRecord(candidate, {1024 * 1024, true, true});
  if (!status)
    return status;
  configuration = std::move(candidate);
  return WVKernelStatus::ok();
}

WVKernelStatus canonicalCoefficientObserver(std::string identifier,
                                            WVObserverRecord &observer) {
  const auto implementation = std::find_if(
      mutableImplementations().begin(), mutableImplementations().end(),
      [](const auto &candidate) {
        WVObserverExecutionPlan plan;
        return candidate->executionPlan({}, plan) &&
               plan.coefficientRestartFamilies ==
                   std::vector<std::string>({"Ap", "Am", "A0"});
      });
  if (implementation == mutableImplementations().end())
    return {WVKernelStatusCode::unsupportedOperation,
            "No coefficient observer implementation is registered."};
  WVObserverRecord candidate;
  candidate.identifier = std::move(identifier);
  candidate.name = (*implementation)->typeIdentifier();
  candidate.typeIdentifier = (*implementation)->typeIdentifier();
  candidate.contractVersion = (*implementation)->contractVersion();
  candidate.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  const auto configurationStatus =
      resolveObserverConfiguration(candidate, candidate.configuration);
  if (!configurationStatus)
    return configurationStatus;
  observer = std::move(candidate);
  return WVKernelStatus::ok();
}

const char *movingFieldChannelName(WVMovingFieldChannel channel) noexcept {
  switch (channel) {
  case WVMovingFieldChannel::x:
    return "x";
  case WVMovingFieldChannel::y:
    return "y";
  case WVMovingFieldChannel::z:
    return "z";
  case WVMovingFieldChannel::tracerValue:
    return "value";
  }
  return nullptr;
}

std::vector<WVMovingFieldChannel>
movingFieldChannels(const WVObserverRecord &observer) {
  const auto implementation = observerImplementation(
      observer.typeIdentifier, observer.contractVersion);
  if (!implementation)
    return {};
  WVObserverExecutionPlan plan;
  if (!implementation->executionPlan(observer, plan))
    return {};
  if (plan.integratedOperation ==
      WVObserverIntegratedOperation::advectedPositions)
    return observer.isXYOnly
               ? std::vector<WVMovingFieldChannel>{WVMovingFieldChannel::x,
                                                   WVMovingFieldChannel::y}
               : std::vector<WVMovingFieldChannel>{WVMovingFieldChannel::x,
                                                   WVMovingFieldChannel::y,
                                                   WVMovingFieldChannel::z};
  if (plan.integratedOperation == WVObserverIntegratedOperation::advectedScalar)
    return {WVMovingFieldChannel::tracerValue};
  return {};
}

std::string movingFieldVariableName(const WVObserverRecord &observer,
                                    WVMovingFieldChannel channel) {
  if (channel == WVMovingFieldChannel::tracerValue)
    return observer.name;
  return observer.name + '_' + movingFieldChannelName(channel);
}

} // namespace wavevortex::runtime::detail
