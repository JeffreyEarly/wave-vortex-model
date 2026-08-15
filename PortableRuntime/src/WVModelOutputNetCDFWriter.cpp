#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"

#include "WVModelOutputNetCDFSchema.hpp"
#include "WVObserverAdapter.hpp"
#include "WVNetCDF.hpp"

#include <netcdf.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <limits>
#include <map>
#include <new>
#include <set>
#include <string>
#include <system_error>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVCheckpointStatus failure(WVCheckpointStatusCode code, std::string message,
                           std::string location) {
  return {code, std::move(message), std::move(location)};
}

WVKernelStatus kernelFailure(const WVCheckpointStatus &status) {
  return {WVKernelStatusCode::unsupportedOperation,
          status.message + (status.location.empty()
                                ? std::string{}
                                : " at " + status.location)};
}

std::filesystem::path temporaryPath(const std::filesystem::path &destination) {
  static std::atomic<std::uint64_t> sequence{0};
  const auto stamp =
      std::chrono::steady_clock::now().time_since_epoch().count();
  return destination.parent_path() /
         (destination.filename().string() + ".wv-output-tmp-" +
          std::to_string(stamp) + "-" + std::to_string(++sequence));
}

WVCheckpointStatus
putStringListAttribute(int group, const char *name,
                       const std::vector<std::string> &values,
                       const std::string &path) {
  if (values.empty())
    return WVCheckpointStatus::ok();
  std::vector<const char *> raw;
  raw.reserve(values.size());
  for (const auto &value : values)
    raw.push_back(value.c_str());
  return detail::checkedNetCDF(
      nc_put_att_string(group, NC_GLOBAL, name, raw.size(), raw.data()),
      "String-list attribute definition", path + "/@" + name);
}

WVCheckpointStatus defineScalar(int group, const std::string &name,
                                int &variable, const std::string &path) {
  return detail::defineDoubleVariable(group, name, {}, variable, path);
}

WVCheckpointStatus writeScalar(int group, const std::string &name, double value,
                               const std::string &path) {
  int variable = -1;
  auto result =
      detail::checkedNetCDF(nc_inq_varid(group, name.c_str(), &variable),
                            "Variable lookup", path + "/" + name);
  if (!result)
    return result;
  return detail::checkedNetCDF(nc_put_var_double(group, variable, &value),
                               "Variable write", path + "/" + name);
}

WVCheckpointStatus writeByteScalar(int group, const std::string &name,
                                   bool value, const std::string &path) {
  int variable = -1;
  auto result =
      detail::checkedNetCDF(nc_inq_varid(group, name.c_str(), &variable),
                            "Variable lookup", path + "/" + name);
  if (!result)
    return result;
  const unsigned char raw = value ? 1 : 0;
  return detail::checkedNetCDF(nc_put_var_uchar(group, variable, &raw),
                               "Variable write", path + "/" + name);
}

WVCheckpointStatus defineLogicalScalar(int group, const std::string &name,
                                       int &variable, const std::string &path) {
  auto result = detail::checkedNetCDF(
      nc_def_var(group, name.c_str(), NC_UBYTE, 0, nullptr, &variable),
      "Variable definition", path + "/" + name);
  if (!result)
    return result;
  return detail::putByteAttribute(group, variable, "isLogicalType", 1,
                                  path + "/" + name);
}

std::size_t product(const std::vector<std::size_t> &dimensions) {
  std::size_t value = 1;
  for (const auto dimension : dimensions)
    value *= dimension;
  return value;
}

const WVAdditionalStateBlockConstView *
findBlock(const WVOutputEvent &event, const std::string &identifier) {
  for (std::size_t index = 0; index < event.state.additionalBlockCount;
       ++index) {
    const auto &block = event.state.additionalBlocks[index];
    if (block.layout != nullptr && block.layout->identifier == identifier)
      return &block;
  }
  return nullptr;
}

} // namespace

class WVModelOutputNetCDFSink::Impl {
public:
  struct Variable {
    std::string observerIdentifier;
    WVObserverOutputVariableSpecification specification;
    int realId = -1;
    int imagId = -1;
  };

  struct StaticVariable {
    std::string name;
    std::vector<double> values;
    int id = -1;
  };

  struct DynamicVariable {
    std::string blockIdentifier;
    std::string name;
    WVStateScalarType scalarType = WVStateScalarType::real64;
    std::size_t elementCount = 0;
    std::vector<double> fixedValues;
    int realId = -1;
    int imagId = -1;
  };

  struct Group {
    WVOutputGroupRecord record;
    int id = -1;
    int timeId = -1;
    std::array<int, 3> coefficientReal{{-1, -1, -1}};
    std::array<int, 3> coefficientImag{{-1, -1, -1}};
    std::vector<DynamicVariable> dynamicVariables;
    std::vector<Variable> derivedVariables;
    std::vector<StaticVariable> staticVariables;
    std::size_t recordCount = 0;
    WVOutputScheduleOrdinal committedOrdinal = WVNoCommittedOutputOrdinal;
  };

  struct File {
    WVOutputFileRecord record;
    std::filesystem::path destination;
    std::filesystem::path staging;
    int id = -1;
    std::vector<Group> groups;
  };

  WVModelOutputNetCDFConfiguration configuration;
  WVPortableObserverRecord descriptorRecord;
  WVIntegrationStateLayout stateLayout;
  WVObserverSampleSource *sampleSource = nullptr;
  std::vector<File> files;
  std::vector<WVOutputGroupProgress> progress;
  WVModelOutputNetCDFMetrics metrics;
  std::size_t preparedEventOrdinal = std::numeric_limits<std::size_t>::max();
  bool appendMode = false;
  bool closed = false;
  bool preflightComplete = false;

  ~Impl() { close(); }

  const WVObserverRecord *observer(const std::string &identifier) const {
    const auto found = std::find_if(descriptorRecord.observers.begin(),
                                    descriptorRecord.observers.end(),
                                    [&](const auto &candidate) {
                                      return candidate.identifier == identifier;
                                    });
    return found == descriptorRecord.observers.end() ? nullptr : &*found;
  }

  const WVAdditionalStateBlockLayout *
  blockLayout(const std::string &identifier) const {
    const auto &blocks = stateLayout.additionalBlocks();
    const auto found =
        std::find_if(blocks.begin(), blocks.end(), [&](const auto &candidate) {
          return candidate.identifier == identifier;
        });
    return found == blocks.end() ? nullptr : &*found;
  }

  const WVStateBlockRecord *
  stateBlockRecord(const std::string &identifier) const {
    const auto &blocks = stateLayout.stateBlockRecords();
    const auto found =
        std::find_if(blocks.begin(), blocks.end(), [&](const auto &candidate) {
          return candidate.identifier == identifier;
        });
    return found == blocks.end() ? nullptr : &*found;
  }

  WVCheckpointStatus validateConfiguration() const {
    if (configuration.checkpointTemplate.metadata.profileIdentifier !=
            WVCheckpointProfileIdentifier ||
        configuration.checkpointTemplate.metadata.profileVersion !=
            WVCheckpointProfileVersion)
      return failure(WVCheckpointStatusCode::schemaMismatch,
                     "Unsupported checkpoint template profile.", "/");
    WVTransformConstantStratificationDescriptor transform;
    const auto status = WVTransformConstantStratificationDescriptor::create(
        configuration.checkpointTemplate.configuration, transform);
    if (!status)
      return failure(WVCheckpointStatusCode::descriptorFailure, status.message,
                     "/");
    const auto shape = stateLayout.coefficientShape();
    if (shape.rows != configuration.checkpointTemplate.configuration.Nj ||
        shape.columns != transform.Nkl())
      return failure(WVCheckpointStatusCode::shapeMismatch,
                     "Output state layout and transform configuration differ.",
                     "/");
    std::array<double, 3> coefficientTolerances{};
    std::size_t coefficientIndex = 0;
    for (const auto &block : stateLayout.stateBlockRecords()) {
      if (block.identifier == "Ap" || block.identifier == "Am" ||
          block.identifier == "A0") {
        if (coefficientIndex >= coefficientTolerances.size() ||
            block.toleranceKind != WVToleranceKind::coefficientEnergyScaled ||
            !std::isfinite(block.absoluteTolerance) ||
            block.absoluteTolerance <= 0.0)
          return failure(
              WVCheckpointStatusCode::schemaMismatch,
              "Coefficient state blocks must carry a finite positive "
              "energy-scaled absTolerance for MATLAB persistence.",
              "/observingSystems/WVCoefficients/absTolerance");
        coefficientTolerances[coefficientIndex++] = block.absoluteTolerance;
      }
    }
    if (!configuration.isDynamicsLinear &&
        (coefficientIndex != coefficientTolerances.size() ||
         coefficientTolerances[0] != coefficientTolerances[1] ||
         coefficientTolerances[0] != coefficientTolerances[2]))
      return failure(WVCheckpointStatusCode::schemaMismatch,
                     "Ap, Am, and A0 must use one common absTolerance.",
                     "/observingSystems/WVCoefficients/absTolerance");
    for (const auto &record : descriptorRecord.observers) {
      const bool requiresDerivedValues =
          record.kind == WVObserverKind::eulerianFields ||
          record.kind == WVObserverKind::mooring ||
          (record.kind == WVObserverKind::lagrangianParticles &&
           !record.fieldNames.empty());
      if (requiresDerivedValues && sampleSource == nullptr)
        return failure(WVCheckpointStatusCode::unsupportedObserver,
                       "Observer " + record.identifier +
                           " requires a derived sample source.",
                       "/observingSystems");
    }
    for (const auto &file : descriptorRecord.outputFiles) {
      const auto restart = std::find_if(
          file.groups.begin(), file.groups.end(), [](const auto &group) {
            return group.containsCompleteCoefficientRestart;
          });
      if (restart == file.groups.end())
        return failure(WVCheckpointStatusCode::schemaMismatch,
                       "Each output file requires one complete restart group.",
                       file.destination);
      bool hasCoefficientObserver = false;
      bool hasEulerianCoefficientObserver = false;
      for (const auto &identifier : restart->observerIdentifiers) {
        const auto *record = observer(identifier);
        if (record == nullptr)
          continue;
        hasCoefficientObserver =
            hasCoefficientObserver ||
            record->kind == WVObserverKind::coefficients;
        hasEulerianCoefficientObserver =
            hasEulerianCoefficientObserver ||
            (record->kind == WVObserverKind::eulerianFields &&
             std::find(record->fieldNames.begin(), record->fieldNames.end(),
                       "Ap") != record->fieldNames.end() &&
             std::find(record->fieldNames.begin(), record->fieldNames.end(),
                       "Am") != record->fieldNames.end() &&
             std::find(record->fieldNames.begin(), record->fieldNames.end(),
                       "A0") != record->fieldNames.end());
      }
      if ((configuration.isDynamicsLinear &&
           !hasEulerianCoefficientObserver) ||
          (!configuration.isDynamicsLinear && !hasCoefficientObserver))
        return failure(
            WVCheckpointStatusCode::schemaMismatch,
            configuration.isDynamicsLinear
                ? "Linear output requires initial Eulerian Ap, Am, and A0."
                : "Nonlinear output requires WVCoefficients.",
            file.destination + ":/" + restart->name);
      std::set<std::string> restartBlocks{"Ap", "Am", "A0"};
      for (const auto &observerIdentifier : restart->observerIdentifiers) {
        const auto *record = observer(observerIdentifier);
        if (record != nullptr)
          restartBlocks.insert(record->stateBlockIdentifiers.begin(),
                               record->stateBlockIdentifiers.end());
      }
      for (const auto &block : stateLayout.stateBlockRecords()) {
        if (block.restartRequirement ==
                WVRestartRequirement::requiredDynamicState &&
            restartBlocks.find(block.identifier) == restartBlocks.end())
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "A complete restart group omits required dynamic "
                         "observer state.",
                         file.destination + ":/" + restart->name);
      }
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus validateDestinations(bool requireExisting) const {
    std::set<std::filesystem::path> observed;
    for (const auto &record : descriptorRecord.outputFiles) {
      const auto destination =
          std::filesystem::absolute(record.destination).lexically_normal();
      if (!observed.insert(destination).second)
        return failure(WVCheckpointStatusCode::appendConflict,
                       "Output destinations are not unique.",
                       destination.string());
      std::error_code error;
      const bool exists = std::filesystem::exists(destination, error);
      if (error)
        return failure(WVCheckpointStatusCode::openFailure,
                       "Unable to inspect output destination: " +
                           error.message(),
                       destination.string());
      if (requireExisting != exists)
        return failure(requireExisting ? WVCheckpointStatusCode::openFailure
                                       : WVCheckpointStatusCode::commitFailure,
                       requireExisting
                           ? "Append destination does not exist."
                           : "New output destination already exists.",
                       destination.string());
      if (!std::filesystem::exists(destination.parent_path()))
        return failure(WVCheckpointStatusCode::openFailure,
                       "Output destination parent does not exist.",
                       destination.parent_path().string());
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus defineObserverMetadata(int parent,
                                            const WVObserverRecord &record,
                                            std::size_t ordinal,
                                            const std::string &path) {
    int group = -1;
    const std::string groupName =
        "observingSystems-" + std::to_string(ordinal + 1);
    auto result = detail::checkedNetCDF(
        nc_def_grp(parent, groupName.c_str(), &group),
        "Observer metadata-group definition", path + "/" + groupName);
    if (!result)
      return result;
    const std::string observerPath = path + "/" + groupName;
    const auto *definition = detail::observerDefinition(record.kind);
    if (definition == nullptr)
      return failure(WVCheckpointStatusCode::unsupportedObserver,
                     "Unsupported observer metadata definition.", observerPath);
    result = detail::putTextAttribute(
        group, NC_GLOBAL, "AnnotatedClass",
        definition->matlabClassName, observerPath);
    if (!result)
      return result;
    result = detail::putTextAttribute(group, NC_GLOBAL, "portableIdentifier",
                                      record.identifier, observerPath);
    if (!result)
      return result;
    if (record.kind != WVObserverKind::eulerianFields) {
      result = detail::putTextAttribute(group, NC_GLOBAL, "name", record.name,
                                        observerPath);
      if (!result)
        return result;
    }
    if (definition->fieldListAttribute != nullptr) {
      result = putStringListAttribute(group, definition->fieldListAttribute,
                                      record.fieldNames, observerPath);
      if (!result)
        return result;
    }
    if (record.kind == WVObserverKind::coefficients) {
      int variable = -1;
      result = defineScalar(group, "absTolerance", variable, observerPath);
      if (!result)
        return result;
      return WVCheckpointStatus::ok();
    }
    if (record.kind == WVObserverKind::lagrangianParticles ||
        record.kind == WVObserverKind::tracer) {
      int variable = -1;
      result = defineLogicalScalar(group, "isXYOnly", variable, observerPath);
      if (!result)
        return result;
    }
    if (record.kind == WVObserverKind::lagrangianParticles) {
      for (const char *name : {"absToleranceXY", "absToleranceZ"}) {
        int variable = -1;
        result = defineScalar(group, name, variable, observerPath);
        if (!result)
          return result;
      }
      result = detail::putTextAttribute(
          group, NC_GLOBAL, "advectionInterpolation",
          record.advectionInterpolation == WVPositionInterpolation::linear
              ? "linear"
              : "spline",
          observerPath);
      if (!result)
        return result;
      return detail::putTextAttribute(
          group, NC_GLOBAL, "trackedVarInterpolation",
          record.trackedFieldInterpolation == WVPositionInterpolation::linear
              ? "linear"
              : "spline",
          observerPath);
    }
    if (record.kind == WVObserverKind::tracer) {
      int variable = -1;
      result = defineScalar(group, "absTolerance", variable, observerPath);
      if (!result)
        return result;
      return defineLogicalScalar(group, "shouldAntialias", variable,
                                 observerPath);
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus defineGroup(File &file, Group &group,
                                 const std::array<int, 5> &rootDimensions) {
    auto result = detail::checkedNetCDF(
        nc_def_grp(file.id, group.record.name.c_str(), &group.id),
        "Output-group definition", "/" + group.record.name);
    if (!result)
      return result;
    const std::string path = "/" + group.record.name;
    result = detail::putTextAttribute(group.id, NC_GLOBAL, "AnnotatedClass",
                                      "WVModelOutputGroupEvenlySpaced", path);
    if (!result)
      return result;
    result = detail::putTextAttribute(group.id, NC_GLOBAL, "name",
                                      group.record.name, path);
    if (!result)
      return result;
    result = detail::putTextAttribute(group.id, NC_GLOBAL, "portableIdentifier",
                                      group.record.identifier, path);
    if (!result)
      return result;
    for (const char *name : {"outputInterval", "initialTime", "finalTime"}) {
      int variable = -1;
      result = defineScalar(group.id, name, variable, path);
      if (!result)
        return result;
    }
    int timeDimension = -1;
    result = detail::checkedNetCDF(
        nc_def_dim(group.id, "t", NC_UNLIMITED, &timeDimension),
        "Time-dimension definition", path + "/t");
    if (!result)
      return result;
    result = detail::defineDoubleVariable(group.id, "t", {timeDimension},
                                          group.timeId, path);
    if (!result)
      return result;
    for (const auto &attribute :
         std::array<std::pair<const char *, const char *>, 5>{
             {{"axis", "T"},
              {"calendar", "standard"},
              {"standard_name", "time"},
              {"long_name", "time"},
              {"units", "seconds since 1970-01-01 00:00:00"}}}) {
      result = detail::putTextAttribute(group.id, group.timeId, attribute.first,
                                        attribute.second, path + "/t");
      if (!result)
        return result;
    }
    if (group.record.containsCompleteCoefficientRestart) {
      for (std::size_t family = 0; family < 3; ++family) {
        const std::string name =
            std::array<const char *, 3>{{"Ap", "Am", "A0"}}[family];
        const std::vector<int> coefficientDimensions =
            configuration.isDynamicsLinear
                ? std::vector<int>{rootDimensions[1], rootDimensions[0]}
                : std::vector<int>{timeDimension, rootDimensions[1],
                                   rootDimensions[0]};
        result = detail::defineComplexVariable(group.id, name,
                                               coefficientDimensions, path);
        if (!result)
          return result;
        int real = -1;
        int imag = -1;
        result = detail::checkedNetCDF(
            nc_inq_varid(group.id, (name + "_real").c_str(), &real),
            "Coefficient-variable lookup", path + "/" + name + "_real");
        if (result)
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id, (name + "_imag").c_str(), &imag),
              "Coefficient-variable lookup", path + "/" + name + "_imag");
        const std::string units = name == "A0" ? "m2 s-1" : "m s-1";
        const std::string longName =
            name == "Ap"
                ? "positive wave coefficients at reference time t0"
                : name == "Am"
                      ? "negative wave coefficients at reference time t0"
                      : "geostrophic coefficients at reference time t0";
        for (const int variable : {real, imag}) {
          if (result)
            result = detail::putTextAttribute(group.id, variable, "units",
                                              units, path + "/" + name);
          if (result)
            result = detail::putTextAttribute(group.id, variable, "long_name",
                                              longName, path + "/" + name);
        }
        if (!result)
          return result;
      }
    }

    int metadataRoot = -1;
    result = detail::checkedNetCDF(
        nc_def_grp(group.id, "observingSystems", &metadataRoot),
        "Observer metadata-root definition", path + "/observingSystems");
    if (!result)
      return result;

    std::map<std::string, WVObserverOutputVariableSpecification>
        definedDerivedVariables;
    for (std::size_t ordinal = 0;
         ordinal < group.record.observerIdentifiers.size(); ++ordinal) {
      const auto *record = observer(group.record.observerIdentifiers[ordinal]);
      if (record == nullptr)
        return failure(WVCheckpointStatusCode::schemaMismatch,
                       "Output group references an unknown observer.", path);
      result = defineObserverMetadata(metadataRoot, *record, ordinal,
                                      path + "/observingSystems");
      if (!result)
        return result;

      if (record->kind == WVObserverKind::mooring) {
        int mooringDimension = -1;
        int verticalDimension = -1;
        const std::string idName = record->name + "_id";
        const std::string zName = record->name + "_z";
        result = detail::checkedNetCDF(
            nc_def_dim(group.id, idName.c_str(), record->x.size(),
                       &mooringDimension),
            "Mooring dimension definition", path + "/" + idName);
        if (!result)
          return result;
        result = detail::checkedNetCDF(
            nc_def_dim(group.id, zName.c_str(),
                       configuration.checkpointTemplate.configuration.Nz,
                       &verticalDimension),
            "Mooring vertical-dimension definition", path + "/" + zName);
        if (!result)
          return result;
        auto addStatic = [&](const std::string &name,
                                   std::vector<int> dimensions,
                                   std::vector<double> values,
                                   const std::string &units,
                                   const std::string &longName) {
          StaticVariable variable;
          variable.name = name;
          variable.values = std::move(values);
          auto definition = detail::defineDoubleVariable(
              group.id, name, dimensions, variable.id, path);
          if (!definition)
            return definition;
          definition = detail::putTextAttribute(group.id, variable.id, "units",
                                                units, path + "/" + name);
          if (!definition)
            return definition;
          if (!longName.empty())
            definition = detail::putTextAttribute(
                group.id, variable.id, "long_name", longName,
                path + "/" + name);
          if (definition)
            group.staticVariables.push_back(std::move(variable));
          return definition;
        };
        std::vector<double> ids(record->x.size());
        for (std::size_t index = 0; index < ids.size(); ++index)
          ids[index] = static_cast<double>(index + 1);
        result = addStatic(idName, {mooringDimension}, std::move(ids),
                           "unitless id number", "");
        if (!result)
          return result;
        std::vector<double> z = record->z;
        const auto &model = configuration.checkpointTemplate.configuration;
        if (z.empty()) {
          z.resize(model.Nz);
          const double dz = model.Lz / static_cast<double>(model.Nz - 1);
          for (std::size_t index = 0; index < z.size(); ++index)
            z[index] = -model.Lz + static_cast<double>(index) * dz;
        }
        if (z.size() != model.Nz)
          return failure(WVCheckpointStatusCode::shapeMismatch,
                         "Mooring vertical coordinates do not match Nz.",
                         path + "/" + zName);
        result = addStatic(zName, {verticalDimension}, std::move(z), "m",
                           "z-positions of mooring observations");
        if (!result)
          return result;
        std::vector<double> x = record->x;
        std::vector<double> y = record->y;
        for (auto &value : x) {
          value = std::fmod(value, model.Lx);
          if (value < 0.0)
            value += model.Lx;
        }
        for (auto &value : y) {
          value = std::fmod(value, model.Ly);
          if (value < 0.0)
            value += model.Ly;
        }
        result = addStatic(record->name + "_x", {mooringDimension},
                           std::move(x), "m", "x position of mooring");
        if (!result)
          return result;
        result = addStatic(record->name + "_y", {mooringDimension},
                           std::move(y), "m", "y position of mooring");
        if (!result)
          return result;
      } else if (record->kind == WVObserverKind::lagrangianParticles) {
        int particleDimension = -1;
        const std::string dimensionName = record->name + "_id";
        result = detail::checkedNetCDF(
            nc_def_dim(group.id, dimensionName.c_str(), record->x.size(),
                       &particleDimension),
            "Particle dimension definition", path + "/" + dimensionName);
        if (!result)
          return result;
        int coordinate = -1;
        result = detail::defineDoubleVariable(
            group.id, dimensionName, {particleDimension}, coordinate, path);
        if (!result)
          return result;
        result = detail::putTextAttribute(group.id, coordinate, "units",
                                          "unitless id number",
                                          path + "/" + dimensionName);
        if (!result)
          return result;
        std::vector<double> particleIds(record->x.size());
        for (std::size_t index = 0; index < particleIds.size(); ++index)
          particleIds[index] = static_cast<double>(index + 1);
        group.staticVariables.push_back(
            {dimensionName, std::move(particleIds), coordinate});
        const auto channels = detail::movingFieldChannels(*record);
        for (std::size_t blockIndex = 0; blockIndex < channels.size();
             ++blockIndex) {
          const auto *layout =
              blockLayout(record->stateBlockIdentifiers[blockIndex]);
          if (layout == nullptr)
            return failure(WVCheckpointStatusCode::schemaMismatch,
                           "Particle state block is absent from the layout.",
                           path);
          DynamicVariable dynamic;
          dynamic.blockIdentifier = layout->identifier;
          dynamic.name =
              detail::movingFieldVariableName(*record, channels[blockIndex]);
          const std::string suffix =
              detail::movingFieldChannelName(channels[blockIndex]);
          dynamic.scalarType = layout->scalarType;
          dynamic.elementCount = layout->elementCount;
          result = detail::defineDoubleVariable(
              group.id, dynamic.name, {timeDimension, particleDimension},
              dynamic.realId, path);
          if (!result)
            return result;
          result = detail::putTextAttribute(group.id, dynamic.realId, "units",
                                            "m", path + "/" + dynamic.name);
          if (!result)
            return result;
          result = detail::putTextAttribute(
              group.id, dynamic.realId, "long_name",
              suffix + std::string(" position of particle"),
              path + "/" + dynamic.name);
          if (!result)
            return result;
          const std::array<std::pair<const char *, std::string>, 3> attributes{{
              {"isParticle", "1"},
              {"particleName", record->name},
              {"particleVariableName", suffix}}};
          for (const auto &attribute : attributes) {
            result = detail::putTextAttribute(
                group.id, dynamic.realId, attribute.first, attribute.second,
                path + "/" + dynamic.name);
            if (!result)
              return result;
          }
          group.dynamicVariables.push_back(std::move(dynamic));
        }
        if (record->isXYOnly && !record->z.empty()) {
          DynamicVariable dynamic;
          dynamic.name = record->name + "_z";
          dynamic.scalarType = WVStateScalarType::real64;
          dynamic.elementCount = record->z.size();
          dynamic.fixedValues = record->z;
          result = detail::defineDoubleVariable(
              group.id, dynamic.name, {timeDimension, particleDimension},
              dynamic.realId, path);
          if (!result)
            return result;
          result = detail::putTextAttribute(group.id, dynamic.realId, "units",
                                            "m", path + "/" + dynamic.name);
          if (result)
            result = detail::putTextAttribute(
                group.id, dynamic.realId, "long_name",
                "z position of particle", path + "/" + dynamic.name);
          if (result)
            result = detail::putTextAttribute(group.id, dynamic.realId,
                                              "isParticle", "1",
                                              path + "/" + dynamic.name);
          if (result)
            result = detail::putTextAttribute(group.id, dynamic.realId,
                                              "particleName", record->name,
                                              path + "/" + dynamic.name);
          if (result)
            result = detail::putTextAttribute(group.id, dynamic.realId,
                                              "particleVariableName", "z",
                                              path + "/" + dynamic.name);
          if (!result)
            return result;
          group.dynamicVariables.push_back(std::move(dynamic));
        }
      } else if (record->kind == WVObserverKind::tracer) {
        const auto *layout = blockLayout(record->stateBlockIdentifiers.front());
        if (layout == nullptr)
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "Tracer state block is absent from the layout.", path);
        std::vector<int> dimensions{timeDimension};
        const auto &logical = layout->dimensions;
        if (logical.size() == 2)
          dimensions.insert(dimensions.end(),
                            {rootDimensions[3], rootDimensions[2]});
        else if (logical.size() == 3)
          dimensions.insert(
              dimensions.end(),
              {rootDimensions[4], rootDimensions[3], rootDimensions[2]});
        else
          return failure(WVCheckpointStatusCode::shapeMismatch,
                         "Tracer dimensions must be horizontal or volumetric.",
                         path);
        DynamicVariable dynamic;
        dynamic.blockIdentifier = layout->identifier;
        dynamic.name = record->name;
        dynamic.scalarType = layout->scalarType;
        dynamic.elementCount = layout->elementCount;
        result = detail::defineDoubleVariable(group.id, dynamic.name,
                                              dimensions, dynamic.realId, path);
        if (result)
          result = detail::putTextAttribute(group.id, dynamic.realId,
                                            "isTracer", "1",
                                            path + "/" + dynamic.name);
        if (!result)
          return result;
        group.dynamicVariables.push_back(std::move(dynamic));
      }

      std::vector<WVObserverOutputVariableSpecification> specifications;
      if (sampleSource != nullptr) {
        const auto sourceStatus =
            sampleSource->specifications(*record, specifications);
        if (!sourceStatus)
          return failure(WVCheckpointStatusCode::unsupportedObserver,
                         sourceStatus.message, path);
      }
      for (const auto &specification : specifications) {
        const bool canonicalCoefficient =
            group.record.containsCompleteCoefficientRestart &&
            (specification.name == "Ap" || specification.name == "Am" ||
             specification.name == "A0");
        if (canonicalCoefficient)
          continue;
        if (specification.identifier.empty() || specification.name.empty() ||
            specification.dimensions.size() !=
                specification.dimensionNames.size() ||
            product(specification.dimensions) == 0)
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "Observer output variable specification is invalid.",
                         path);
        const auto existing = definedDerivedVariables.find(specification.name);
        if (existing != definedDerivedVariables.end()) {
          const auto &prior = existing->second;
          if (prior.valueType != specification.valueType ||
              prior.cadence != specification.cadence ||
              prior.dimensionNames != specification.dimensionNames ||
              prior.dimensions != specification.dimensions)
            return failure(WVCheckpointStatusCode::schemaMismatch,
                           "Observers declare incompatible variables with the "
                           "same name.",
                           path + "/" + specification.name);
          continue;
        }
        definedDerivedVariables.emplace(specification.name, specification);
        std::vector<int> dimensions;
        if (specification.cadence == WVObserverOutputCadence::timeSeries)
          dimensions.push_back(timeDimension);
        for (std::size_t reverse = specification.dimensions.size(); reverse > 0;
             --reverse) {
          const auto logicalIndex = reverse - 1;
          int dimension = -1;
          const auto &name = specification.dimensionNames[logicalIndex];
          if (nc_inq_dimid(group.id, name.c_str(), &dimension) != NC_NOERR) {
            result = detail::checkedNetCDF(
                nc_def_dim(group.id, name.c_str(),
                           specification.dimensions[logicalIndex], &dimension),
                "Observer dimension definition", path + "/" + name);
            if (!result)
              return result;
          }
          dimensions.push_back(dimension);
        }
        Variable variable;
        variable.observerIdentifier = record->identifier;
        variable.specification = specification;
        if (specification.valueType == WVOutputValueType::complex64) {
          result = detail::defineComplexVariable(group.id, specification.name,
                                                 dimensions, path);
          if (!result)
            return result;
        } else {
          result = detail::defineDoubleVariable(
              group.id, specification.name, dimensions, variable.realId, path);
          if (!result)
            return result;
        }
        const auto applyAttributes = [&](int variableId,
                                         const std::string &variablePath) {
          auto attributeResult = WVCheckpointStatus::ok();
          if (!specification.units.empty())
            attributeResult = detail::putTextAttribute(
                group.id, variableId, "units", specification.units,
                variablePath);
          if (attributeResult && !specification.longName.empty())
            attributeResult = detail::putTextAttribute(
                group.id, variableId, "long_name", specification.longName,
                variablePath);
          for (const auto &attribute : specification.attributes) {
            if (!attributeResult)
              break;
            attributeResult = detail::putTextAttribute(
                group.id, variableId, attribute.name.c_str(), attribute.value,
                variablePath);
          }
          return attributeResult;
        };
        if (specification.valueType == WVOutputValueType::complex64) {
          int real = -1;
          int imag = -1;
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id, (specification.name + "_real").c_str(),
                           &real),
              "Observer-variable lookup", path);
          if (result)
            result = detail::checkedNetCDF(
                nc_inq_varid(group.id,
                             (specification.name + "_imag").c_str(), &imag),
                "Observer-variable lookup", path);
          variable.realId = real;
          variable.imagId = imag;
          if (result)
            result = applyAttributes(real,
                                     path + "/" + specification.name + "_real");
          if (result)
            result = applyAttributes(imag,
                                     path + "/" + specification.name + "_imag");
        } else {
          result = applyAttributes(variable.realId,
                                   path + "/" + specification.name);
        }
        if (!result)
          return result;
        group.derivedVariables.push_back(std::move(variable));
      }
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus writeObserverMetadata(int fileId, const File &file) {
    for (const auto &group : file.groups) {
      const std::string path = "/" + group.record.name;
      auto result = writeScalar(group.id, "outputInterval",
                                group.record.schedule.outputInterval, path);
      if (!result)
        return result;
      result = writeScalar(group.id, "initialTime",
                           group.record.schedule.initialTime, path);
      if (!result)
        return result;
      result = writeScalar(group.id, "finalTime",
                           group.record.schedule.finalTime, path);
      if (!result)
        return result;
      int metadataRoot = -1;
      result = detail::checkedNetCDF(
          nc_inq_ncid(group.id, "observingSystems", &metadataRoot),
          "Observer metadata-root lookup", path + "/observingSystems");
      if (!result)
        return result;
      for (std::size_t ordinal = 0;
           ordinal < group.record.observerIdentifiers.size(); ++ordinal) {
        const auto *record =
            observer(group.record.observerIdentifiers[ordinal]);
        const std::string groupName =
            "observingSystems-" + std::to_string(ordinal + 1);
        int metadata = -1;
        result = detail::checkedNetCDF(
            nc_inq_ncid(metadataRoot, groupName.c_str(), &metadata),
            "Observer metadata-group lookup",
            path + "/observingSystems/" + groupName);
        if (!result)
          return result;
        const std::string metadataPath =
            path + "/observingSystems/" + groupName;
        if (record->kind == WVObserverKind::coefficients) {
          const auto *block = stateBlockRecord("Ap");
          result = writeScalar(
              metadata, "absTolerance",
              block == nullptr ? 1e-6 : block->absoluteTolerance, metadataPath);
        } else if (record->kind == WVObserverKind::lagrangianParticles) {
          result = writeByteScalar(metadata, "isXYOnly", record->isXYOnly,
                                   metadataPath);
          if (result)
            result =
                writeScalar(metadata, "absToleranceXY",
                            record->horizontalAbsoluteTolerance, metadataPath);
          if (result)
            result =
                writeScalar(metadata, "absToleranceZ",
                            record->verticalAbsoluteTolerance, metadataPath);
        } else if (record->kind == WVObserverKind::tracer) {
          result = writeByteScalar(metadata, "isXYOnly", record->isXYOnly,
                                   metadataPath);
          if (result) {
            const auto *block =
                blockLayout(record->stateBlockIdentifiers.front());
            result =
                writeScalar(metadata, "absTolerance",
                            block == nullptr ? 1e-5 : block->absoluteTolerance,
                            metadataPath);
          }
          if (result)
            result = writeByteScalar(metadata, "shouldAntialias",
                                     record->shouldAntialias, metadataPath);
        }
        if (!result)
          return result;
      }
    }
    (void)fileId;
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus writeInitialAndStaticValues(File &file) {
    const auto coefficientCount =
        configuration.checkpointTemplate.state.coefficients.shape.elementCount();
    for (auto &group : file.groups) {
      const std::string path = "/" + group.record.name;
      for (const auto &variable : group.staticVariables) {
        const auto result = detail::checkedNetCDF(
            nc_put_var_double(group.id, variable.id, variable.values.data()),
            "Static observer-variable write", path + "/" + variable.name);
        if (!result)
          return result;
      }
      if (group.record.containsCompleteCoefficientRestart &&
          configuration.isDynamicsLinear) {
        const std::array<const WVComplex64 *, 3> values{
            configuration.checkpointTemplate.state.coefficients.Ap.data(),
            configuration.checkpointTemplate.state.coefficients.Am.data(),
            configuration.checkpointTemplate.state.coefficients.A0.data()};
        for (std::size_t family = 0; family < 3; ++family) {
          const std::string name =
              std::array<const char *, 3>{{"Ap", "Am", "A0"}}[family];
          int real = -1;
          int imag = -1;
          auto result = detail::checkedNetCDF(
              nc_inq_varid(group.id, (name + "_real").c_str(), &real),
              "Initial coefficient-variable lookup", path + "/" + name);
          if (result)
            result = detail::checkedNetCDF(
                nc_inq_varid(group.id, (name + "_imag").c_str(), &imag),
                "Initial coefficient-variable lookup", path + "/" + name);
          if (!result)
            return result;
          std::vector<double> realValues(coefficientCount);
          std::vector<double> imaginaryValues(coefficientCount);
          for (std::size_t index = 0; index < coefficientCount; ++index) {
            realValues[index] = values[family][index].real;
            imaginaryValues[index] = values[family][index].imag;
          }
          result = detail::checkedNetCDF(
              nc_put_var_double(group.id, real, realValues.data()),
              "Initial coefficient write", path + "/" + name + "_real");
          if (result)
            result = detail::checkedNetCDF(
                nc_put_var_double(group.id, imag, imaginaryValues.data()),
                "Initial coefficient write", path + "/" + name + "_imag");
          if (!result)
            return result;
        }
      }
      for (const auto &variable : group.derivedVariables) {
        if (variable.specification.cadence !=
            WVObserverOutputCadence::initialOnly)
          continue;
        const auto *record = observer(variable.observerIdentifier);
        WVObserverOutputValueView value;
        const auto status = sampleSource->value(
            *record, variable.specification, value);
        if (!status)
          return failure(WVCheckpointStatusCode::unsupportedObserver,
                         status.message,
                         path + "/" + variable.specification.name);
        const auto expected = product(variable.specification.dimensions);
        if (value.elementCount != expected ||
            value.valueType != variable.specification.valueType)
          return failure(WVCheckpointStatusCode::shapeMismatch,
                         "Initial observer sample does not match its schema.",
                         path + "/" + variable.specification.name);
        if (value.valueType == WVOutputValueType::real64) {
          const auto result = detail::checkedNetCDF(
              nc_put_var_double(group.id, variable.realId, value.realData),
              "Initial observer-variable write",
              path + "/" + variable.specification.name);
          if (!result)
            return result;
        } else {
          std::vector<double> realValues(expected);
          std::vector<double> imaginaryValues(expected);
          for (std::size_t index = 0; index < expected; ++index) {
            realValues[index] = value.complexData[index].real;
            imaginaryValues[index] = value.complexData[index].imag;
          }
          auto result = detail::checkedNetCDF(
              nc_put_var_double(group.id, variable.realId, realValues.data()),
              "Initial observer-variable write",
              path + "/" + variable.specification.name + "_real");
          if (result)
            result = detail::checkedNetCDF(
                nc_put_var_double(group.id, variable.imagId,
                                  imaginaryValues.data()),
                "Initial observer-variable write",
                path + "/" + variable.specification.name + "_imag");
          if (!result)
            return result;
        }
      }
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus stageFiles() {
    if (sampleSource != nullptr) {
      const auto status = sampleSource->prepareInitial(
          configuration.checkpointTemplate.state.view());
      if (!status)
        return failure(WVCheckpointStatusCode::unsupportedObserver,
                       status.message, "/observingSystems");
    }
    files.clear();
    files.reserve(descriptorRecord.outputFiles.size());
    for (const auto &record : descriptorRecord.outputFiles) {
      File file;
      file.record = record;
      file.destination =
          std::filesystem::absolute(record.destination).lexically_normal();
      file.staging = temporaryPath(file.destination);
      int id = -1;
      auto result = detail::checkedNetCDF(
          nc_create(file.staging.c_str(), NC_NETCDF4 | NC_NOCLOBBER, &id),
          "Output-file creation", file.staging.string());
      if (!result)
        return result;
      file.id = id;
      files.push_back(std::move(file));
      auto &staged = files.back();
      std::array<int, 5> rootDimensions{};
      std::vector<int> forcingGroups;
      std::vector<const WVFrozenForcingEntry *> forcingEntries;
      result = detail::defineModelOutputRoot(
          staged.id, configuration.checkpointTemplate,
          configuration.isDynamicsLinear, rootDimensions, forcingGroups,
          forcingEntries);
      if (!result)
        return result;
      result = detail::putTextAttribute(staged.id, NC_GLOBAL,
                                        "portableFileIdentifier",
                                        record.identifier, "/");
      if (!result)
        return result;
      staged.groups.reserve(record.groups.size());
      for (const auto &groupRecord : record.groups) {
        Group group;
        group.record = groupRecord;
        result = defineGroup(staged, group, rootDimensions);
        if (!result)
          return result;
        staged.groups.push_back(std::move(group));
      }
      result = detail::checkedNetCDF(nc_enddef(staged.id),
                                     "End output-file definition",
                                     staged.staging.string());
      if (!result)
        return result;
      result = detail::writeModelOutputRoot(staged.id,
                                            configuration.checkpointTemplate,
                                            forcingGroups, forcingEntries);
      if (!result)
        return result;
      result = writeObserverMetadata(staged.id, staged);
      if (!result)
        return result;
      result = writeInitialAndStaticValues(staged);
      if (!result)
        return result;
      result = detail::checkedNetCDF(nc_sync(staged.id),
                                     "Output-file initialization sync",
                                     staged.staging.string());
      if (!result)
        return result;
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus commitStagedFiles() {
    for (auto &file : files) {
      if (file.id >= 0) {
        const int id = std::exchange(file.id, -1);
        const auto result = detail::checkedNetCDF(
            nc_close(id), "Output-file initialization close",
            file.staging.string());
        if (!result)
          return result;
      }
    }
    std::vector<std::filesystem::path> committed;
    for (auto &file : files) {
      std::error_code error;
      std::filesystem::create_hard_link(file.staging, file.destination, error);
      if (error) {
        for (const auto &path : committed) {
          std::error_code ignored;
          std::filesystem::remove(path, ignored);
        }
        return failure(WVCheckpointStatusCode::commitFailure,
                       "Unable to commit output file set: " + error.message(),
                       file.destination.string());
      }
      committed.push_back(file.destination);
    }
    for (auto &file : files) {
      std::error_code ignored;
      std::filesystem::remove(file.staging, ignored);
      int id = -1;
      auto result = detail::checkedNetCDF(
          nc_open(file.destination.c_str(), NC_WRITE, &id),
          "Committed output-file open", file.destination.string());
      if (!result) {
        for (auto &candidate : files) {
          if (candidate.id >= 0) {
            nc_close(std::exchange(candidate.id, -1));
          }
        }
        for (const auto &path : committed) {
          std::error_code rollbackError;
          std::filesystem::remove(path, rollbackError);
        }
        return result;
      }
      file.id = id;
      result = resolveFile(file);
      if (!result) {
        for (auto &candidate : files) {
          if (candidate.id >= 0)
            nc_close(std::exchange(candidate.id, -1));
        }
        for (const auto &path : committed) {
          std::error_code rollbackError;
          std::filesystem::remove(path, rollbackError);
        }
        return result;
      }
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus resolveFile(File &file) {
    for (auto &group : file.groups) {
      auto result = detail::checkedNetCDF(
          nc_inq_ncid(file.id, group.record.name.c_str(), &group.id),
          "Output-group lookup", "/" + group.record.name);
      if (!result)
        return result;
      for (const auto &expected :
           std::array<std::pair<const char *, double>, 3>{
               {{"outputInterval", group.record.schedule.outputInterval},
                {"initialTime", group.record.schedule.initialTime},
                {"finalTime", group.record.schedule.finalTime}}}) {
        double observed = 0.0;
        result = detail::readDoubleScalar(group.id, expected.first, observed,
                                          "/" + group.record.name);
        if (!result)
          return result;
        if (observed != expected.second)
          return failure(WVCheckpointStatusCode::appendConflict,
                         "Existing output schedule does not match append "
                         "configuration.",
                         "/" + group.record.name + "/" + expected.first);
      }
      result = detail::checkedNetCDF(nc_inq_varid(group.id, "t", &group.timeId),
                                     "Time-variable lookup",
                                     "/" + group.record.name + "/t");
      if (!result)
        return result;
      if (group.record.containsCompleteCoefficientRestart) {
        for (std::size_t family = 0; family < 3; ++family) {
          const std::string name =
              std::array<const char *, 3>{{"Ap", "Am", "A0"}}[family];
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id, (name + "_real").c_str(),
                           &group.coefficientReal[family]),
              "Coefficient-variable lookup",
              "/" + group.record.name + "/" + name + "_real");
          if (!result && configuration.isDynamicsLinear) {
            result = detail::checkedNetCDF(
                nc_inq_varid(group.id, name.c_str(),
                             &group.coefficientReal[family]),
                "Initial coefficient-variable lookup",
                "/" + group.record.name + "/" + name);
            group.coefficientImag[family] = -1;
            if (!result)
              return result;
            continue;
          }
          if (!result)
            return result;
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id, (name + "_imag").c_str(),
                           &group.coefficientImag[family]),
              "Coefficient-variable lookup",
              "/" + group.record.name + "/" + name + "_imag");
          if (!result)
            return result;
        }
      }
      for (auto &dynamic : group.dynamicVariables) {
        result = detail::checkedNetCDF(
            nc_inq_varid(group.id, dynamic.name.c_str(), &dynamic.realId),
            "Dynamic observer-variable lookup",
            "/" + group.record.name + "/" + dynamic.name);
        if (!result)
          return result;
      }
      for (auto &variable : group.staticVariables) {
        result = detail::checkedNetCDF(
            nc_inq_varid(group.id, variable.name.c_str(), &variable.id),
            "Static observer-variable lookup",
            "/" + group.record.name + "/" + variable.name);
        if (!result)
          return result;
        std::vector<double> observed(variable.values.size());
        result = detail::checkedNetCDF(
            nc_get_var_double(group.id, variable.id, observed.data()),
            "Static observer-variable read",
            "/" + group.record.name + "/" + variable.name);
        if (!result)
          return result;
        const bool coordinatesMatch =
            observed.size() == variable.values.size() &&
            std::equal(observed.begin(), observed.end(),
                       variable.values.begin(), [](double first,
                                                   double second) {
                         const double scale =
                             std::max({1.0, std::abs(first), std::abs(second)});
                         return std::abs(first - second) <= 1e-12 * scale;
                       });
        if (!coordinatesMatch)
          return failure(WVCheckpointStatusCode::appendConflict,
                         "Static observer coordinates changed.",
                         "/" + group.record.name + "/" + variable.name);
      }
      for (auto &variable : group.derivedVariables) {
        if (variable.specification.valueType == WVOutputValueType::complex64) {
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id,
                           (variable.specification.name + "_real").c_str(),
                           &variable.realId),
              "Observer-variable lookup", "/" + group.record.name);
          if (!result)
            return result;
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id,
                           (variable.specification.name + "_imag").c_str(),
                           &variable.imagId),
              "Observer-variable lookup", "/" + group.record.name);
        } else {
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id, variable.specification.name.c_str(),
                           &variable.realId),
              "Observer-variable lookup", "/" + group.record.name);
        }
        if (!result)
          return result;
        const auto validateComponent = [&](int variableId,
                                           const std::string &variableName) {
          int rank = 0;
          auto contract = detail::checkedNetCDF(
              nc_inq_varndims(group.id, variableId, &rank),
              "Observer-variable rank inspection",
              "/" + group.record.name + "/" + variableName);
          if (!contract)
            return contract;
          const std::size_t expectedRank =
              variable.specification.dimensionNames.size() +
              (variable.specification.cadence ==
                       WVObserverOutputCadence::timeSeries
                   ? 1
                   : 0);
          if (static_cast<std::size_t>(rank) != expectedRank)
            return failure(WVCheckpointStatusCode::appendConflict,
                           "Observer-variable cadence or rank changed.",
                           "/" + group.record.name + "/" + variableName);
          std::vector<int> dimensions(expectedRank);
          if (rank > 0) {
            contract = detail::checkedNetCDF(
                nc_inq_vardimid(group.id, variableId, dimensions.data()),
                "Observer-variable dimension inspection",
                "/" + group.record.name + "/" + variableName);
            if (!contract)
              return contract;
          }
          std::vector<std::string> expectedNames;
          std::vector<std::size_t> expectedLengths;
          if (variable.specification.cadence ==
              WVObserverOutputCadence::timeSeries) {
            expectedNames.push_back("t");
            expectedLengths.push_back(group.recordCount);
          }
          for (std::size_t reverse =
                   variable.specification.dimensionNames.size();
               reverse > 0; --reverse) {
            expectedNames.push_back(
                variable.specification.dimensionNames[reverse - 1]);
            expectedLengths.push_back(
                variable.specification.dimensions[reverse - 1]);
          }
          for (std::size_t index = 0; index < dimensions.size(); ++index) {
            char name[NC_MAX_NAME + 1] = {};
            std::size_t length = 0;
            contract = detail::checkedNetCDF(
                nc_inq_dim(group.id, dimensions[index], name, &length),
                "Observer-variable dimension inspection",
                "/" + group.record.name + "/" + variableName);
            if (!contract)
              return contract;
            if (expectedNames[index] != name ||
                ((index != 0 || expectedNames[index] != "t") &&
                 expectedLengths[index] != length))
              return failure(WVCheckpointStatusCode::appendConflict,
                             "Observer-variable dimensions changed.",
                             "/" + group.record.name + "/" + variableName);
          }
          const auto requireAttribute = [&](const std::string &name,
                                            const std::string &expected) {
            if (expected.empty())
              return WVCheckpointStatus::ok();
            std::size_t length = 0;
            auto attributeStatus = detail::checkedNetCDF(
                nc_inq_attlen(group.id, variableId, name.c_str(), &length),
                "Observer-variable attribute inspection",
                "/" + group.record.name + "/" + variableName + "/@" +
                    name);
            if (!attributeStatus)
              return attributeStatus;
            std::string observed(length, '\0');
            attributeStatus = detail::checkedNetCDF(
                nc_get_att_text(group.id, variableId, name.c_str(),
                                observed.data()),
                "Observer-variable attribute read",
                "/" + group.record.name + "/" + variableName + "/@" +
                    name);
            if (!attributeStatus)
              return attributeStatus;
            if (observed != expected)
              return failure(WVCheckpointStatusCode::appendConflict,
                             "Observer-variable metadata changed: expected '" +
                                 expected + "' but observed '" + observed +
                                 "'.",
                             "/" + group.record.name + "/" + variableName +
                                 "/@" + name);
            return WVCheckpointStatus::ok();
          };
          contract = requireAttribute("units", variable.specification.units);
          if (contract)
            contract =
                requireAttribute("long_name", variable.specification.longName);
          for (const auto &attribute : variable.specification.attributes) {
            if (!contract)
              break;
            contract = requireAttribute(attribute.name, attribute.value);
          }
          if (!contract)
            return contract;
          if (variable.specification.cadence ==
              WVObserverOutputCadence::initialOnly) {
            const auto count = product(variable.specification.dimensions);
            std::vector<double> values(count);
            contract = detail::checkedNetCDF(
                nc_get_var_double(group.id, variableId, values.data()),
                "Initial observer-variable read",
                "/" + group.record.name + "/" + variableName);
            if (!contract)
              return contract;
            if (std::find(values.begin(), values.end(), NC_FILL_DOUBLE) !=
                values.end())
              return failure(WVCheckpointStatusCode::incompleteRecord,
                             "Initial observer variable is unwritten.",
                             "/" + group.record.name + "/" + variableName);
          }
          return WVCheckpointStatus::ok();
        };
        result = validateComponent(variable.realId,
                                   variable.specification.valueType ==
                                           WVOutputValueType::complex64
                                       ? variable.specification.name + "_real"
                                       : variable.specification.name);
        if (result && variable.specification.valueType ==
                          WVOutputValueType::complex64)
          result = validateComponent(variable.imagId,
                                     variable.specification.name + "_imag");
        if (!result)
          return result;
      }
      int timeDimension = -1;
      std::size_t length = 0;
      result = detail::checkedNetCDF(
          nc_inq_dimid(group.id, "t", &timeDimension), "Time-dimension lookup",
          "/" + group.record.name + "/t");
      if (!result)
        return result;
      result = detail::checkedNetCDF(
          nc_inq_dimlen(group.id, timeDimension, &length),
          "Time-dimension length", "/" + group.record.name + "/t");
      if (!result)
        return result;
      group.recordCount = length;
      if (length > 0) {
        std::vector<double> times(length);
        result = detail::checkedNetCDF(
            nc_get_var_double(group.id, group.timeId, times.data()),
            "Output-time read", "/" + group.record.name + "/t");
        if (!result)
          return result;
        for (std::size_t timeIndex = 0; timeIndex < times.size(); ++timeIndex) {
          const double observed = times[timeIndex];
          const double raw = (observed - group.record.schedule.initialTime) /
                             group.record.schedule.outputInterval;
          const auto ordinal =
              static_cast<WVOutputScheduleOrdinal>(std::llround(raw));
          const double expected = group.record.schedule.initialTime +
                                  static_cast<double>(ordinal) *
                                      group.record.schedule.outputInterval;
          const double tolerance =
              8 * std::numeric_limits<double>::epsilon() *
              std::max({1.0, std::abs(observed), std::abs(expected)});
          if (!std::isfinite(observed) ||
              std::abs(observed - expected) > tolerance || ordinal < 0 ||
              (timeIndex > 0 && !(observed > times[timeIndex - 1])))
            return failure(
                WVCheckpointStatusCode::appendConflict,
                "Existing output times are not a strictly increasing subset "
                "of the configured schedule lattice.",
                "/" + group.record.name + "/t");
          group.committedOrdinal = ordinal;
        }

        int variableCount = 0;
        result = detail::checkedNetCDF(
            nc_inq_varids(group.id, &variableCount, nullptr),
            "Output-variable enumeration", "/" + group.record.name);
        if (!result)
          return result;
        std::vector<int> variableIds(static_cast<std::size_t>(variableCount));
        result = detail::checkedNetCDF(
            nc_inq_varids(group.id, &variableCount, variableIds.data()),
            "Output-variable enumeration", "/" + group.record.name);
        if (!result)
          return result;
        for (const int variable : variableIds) {
          nc_type type = NC_NAT;
          int dimensionCount = 0;
          result = detail::checkedNetCDF(
              nc_inq_vartype(group.id, variable, &type),
              "Output-variable type inspection", "/" + group.record.name);
          if (!result)
            return result;
          result = detail::checkedNetCDF(
              nc_inq_varndims(group.id, variable, &dimensionCount),
              "Output-variable rank inspection", "/" + group.record.name);
          if (!result)
            return result;
          if (type != NC_DOUBLE || dimensionCount == 0)
            continue;
          std::vector<int> dimensions(static_cast<std::size_t>(dimensionCount));
          result = detail::checkedNetCDF(
              nc_inq_vardimid(group.id, variable, dimensions.data()),
              "Output-variable dimension inspection", "/" + group.record.name);
          if (!result)
            return result;
          char firstName[NC_MAX_NAME + 1] = {};
          result = detail::checkedNetCDF(
              nc_inq_dimname(group.id, dimensions.front(), firstName),
              "Output-variable dimension-name inspection",
              "/" + group.record.name);
          if (!result)
            return result;
          if (std::string(firstName) != "t")
            continue;
          std::vector<std::size_t> start(dimensions.size(), 0);
          std::vector<std::size_t> count(dimensions.size(), 1);
          std::size_t slabSize = 1;
          for (std::size_t index = 1; index < dimensions.size(); ++index) {
            result = detail::checkedNetCDF(
                nc_inq_dimlen(group.id, dimensions[index], &count[index]),
                "Output-variable dimension-length inspection",
                "/" + group.record.name);
            if (!result)
              return result;
            slabSize *= count[index];
          }
          std::vector<double> slab(slabSize);
          for (std::size_t recordIndex = 0; recordIndex < length;
               ++recordIndex) {
            start.front() = recordIndex;
            result = detail::checkedNetCDF(
                nc_get_vara_double(group.id, variable, start.data(),
                                   count.data(), slab.data()),
                "Committed output-record read", "/" + group.record.name);
            if (!result)
              return result;
            if (std::find(slab.begin(), slab.end(), NC_FILL_DOUBLE) !=
                slab.end()) {
              char variableName[NC_MAX_NAME + 1] = {};
              nc_inq_varname(group.id, variable, variableName);
              return failure(WVCheckpointStatusCode::incompleteRecord,
                             "A committed output record contains unwritten "
                             "payload values.",
                             "/" + group.record.name + "/" + variableName);
            }
          }
        }
      }
    }
    return WVCheckpointStatus::ok();
  }

  void rebuildProgress() {
    progress.clear();
    for (const auto &file : files)
      for (const auto &group : file.groups)
        progress.push_back({file.record.identifier, group.record.identifier,
                            group.committedOrdinal});
  }

  void updateRetainedStorageMetric() {
    std::size_t bytes = sizeof(*this) + stateLayout.persistentBytes() +
                        files.capacity() * sizeof(File) +
                        progress.capacity() * sizeof(WVOutputGroupProgress);
    for (const auto &file : files) {
      bytes += file.record.identifier.capacity() +
               file.record.destination.capacity() +
               file.groups.capacity() * sizeof(Group);
      for (const auto &group : file.groups) {
        bytes += group.record.identifier.capacity() +
                 group.record.name.capacity() +
                 group.dynamicVariables.capacity() * sizeof(DynamicVariable) +
                 group.derivedVariables.capacity() * sizeof(Variable) +
                 group.staticVariables.capacity() * sizeof(StaticVariable);
        for (const auto &dynamic : group.dynamicVariables)
          bytes += dynamic.blockIdentifier.capacity() + dynamic.name.capacity();
        for (const auto &variable : group.derivedVariables)
          bytes += variable.observerIdentifier.capacity() +
                   variable.specification.identifier.capacity() +
                   variable.specification.name.capacity() +
                   variable.specification.units.capacity() +
                   variable.specification.longName.capacity() +
                   variable.specification.dimensionNames.capacity() *
                       sizeof(std::string) +
                   variable.specification.dimensions.capacity() *
                       sizeof(std::size_t) +
                   variable.specification.attributes.capacity() *
                       sizeof(WVObserverOutputAttribute);
        for (const auto &variable : group.derivedVariables) {
          for (const auto &name : variable.specification.dimensionNames)
            bytes += name.capacity();
          for (const auto &attribute : variable.specification.attributes)
            bytes += attribute.name.capacity() + attribute.value.capacity();
        }
        for (const auto &variable : group.staticVariables)
          bytes += variable.name.capacity() +
                   variable.values.capacity() * sizeof(double);
      }
    }
    metrics.retainedStorageBytes = bytes;
  }

  WVCheckpointStatus openExistingFiles() {
    files.clear();
    files.reserve(descriptorRecord.outputFiles.size());
    for (const auto &record : descriptorRecord.outputFiles) {
      WVCheckpointInspection inspection;
      auto result = WVCheckpointReader::inspect(record.destination, inspection);
      if (!result)
        return result;
      if (!sameTransformConfiguration(
              configuration.checkpointTemplate.configuration,
              inspection.configuration))
        return failure(WVCheckpointStatusCode::schemaMismatch,
                       "Append model configuration does not match the file.",
                       record.destination);
      File file;
      file.record = record;
      file.destination =
          std::filesystem::absolute(record.destination).lexically_normal();
      int id = -1;
      result = detail::checkedNetCDF(
          nc_open(file.destination.c_str(), NC_WRITE, &id),
          "Append output-file open", file.destination.string());
      if (!result)
        return result;
      file.id = id;
      file.groups.reserve(record.groups.size());
      for (const auto &groupRecord : record.groups) {
        Group group;
        group.record = groupRecord;
        // Rebuild variable contracts without mutating the existing file.
        for (const auto &identifier : groupRecord.observerIdentifiers) {
          const auto *recordPointer = observer(identifier);
          if (recordPointer == nullptr)
            return failure(WVCheckpointStatusCode::schemaMismatch,
                           "Append group references an unknown observer.",
                           file.destination.string());
          if (recordPointer->kind == WVObserverKind::lagrangianParticles ||
              recordPointer->kind == WVObserverKind::tracer) {
            const auto channels = detail::movingFieldChannels(*recordPointer);
            for (std::size_t blockIndex = 0; blockIndex < channels.size();
                 ++blockIndex) {
              const auto *layout =
                  blockLayout(recordPointer->stateBlockIdentifiers[blockIndex]);
              DynamicVariable dynamic;
              dynamic.blockIdentifier = layout->identifier;
              dynamic.name = detail::movingFieldVariableName(
                  *recordPointer, channels[blockIndex]);
              dynamic.scalarType = layout->scalarType;
              dynamic.elementCount = layout->elementCount;
              group.dynamicVariables.push_back(std::move(dynamic));
            }
            if (recordPointer->kind == WVObserverKind::lagrangianParticles &&
                recordPointer->isXYOnly && !recordPointer->z.empty())
              group.dynamicVariables.push_back(
                  {{}, recordPointer->name + "_z",
                   WVStateScalarType::real64, recordPointer->z.size(),
                   recordPointer->z, -1, -1});
          } else if (recordPointer->kind == WVObserverKind::mooring) {
            const auto &model = configuration.checkpointTemplate.configuration;
            std::vector<double> ids(recordPointer->x.size());
            for (std::size_t index = 0; index < ids.size(); ++index)
              ids[index] = static_cast<double>(index + 1);
            std::vector<double> z(model.Nz);
            const double dz = model.Lz / static_cast<double>(model.Nz - 1);
            for (std::size_t index = 0; index < z.size(); ++index)
              z[index] = -model.Lz + static_cast<double>(index) * dz;
            std::vector<double> x = recordPointer->x;
            std::vector<double> y = recordPointer->y;
            for (auto &value : x) {
              value = std::fmod(value, model.Lx);
              if (value < 0.0)
                value += model.Lx;
            }
            for (auto &value : y) {
              value = std::fmod(value, model.Ly);
              if (value < 0.0)
                value += model.Ly;
            }
            group.staticVariables.push_back(
                {recordPointer->name + "_id", std::move(ids), -1});
            group.staticVariables.push_back(
                {recordPointer->name + "_z", std::move(z), -1});
            group.staticVariables.push_back(
                {recordPointer->name + "_x", std::move(x), -1});
            group.staticVariables.push_back(
                {recordPointer->name + "_y", std::move(y), -1});
          }
          if (sampleSource != nullptr) {
            std::vector<WVObserverOutputVariableSpecification> specifications;
            const auto sourceStatus =
                sampleSource->specifications(*recordPointer, specifications);
            if (!sourceStatus)
              return failure(WVCheckpointStatusCode::unsupportedObserver,
                             sourceStatus.message, file.destination.string());
            for (const auto &specification : specifications) {
              const bool canonicalCoefficient =
                  groupRecord.containsCompleteCoefficientRestart &&
                  (specification.name == "Ap" || specification.name == "Am" ||
                   specification.name == "A0");
              if (!canonicalCoefficient) {
                const auto existing = std::find_if(
                    group.derivedVariables.begin(),
                    group.derivedVariables.end(), [&](const auto &variable) {
                      return variable.specification.name == specification.name;
                    });
                if (existing == group.derivedVariables.end())
                  group.derivedVariables.push_back(
                      {identifier, specification, -1, -1});
                else if (existing->specification.valueType !=
                             specification.valueType ||
                         existing->specification.cadence !=
                             specification.cadence ||
                         existing->specification.dimensions !=
                             specification.dimensions ||
                         existing->specification.dimensionNames !=
                             specification.dimensionNames)
                  return failure(
                      WVCheckpointStatusCode::appendConflict,
                      "Observers declare incompatible variables with the same "
                      "name.",
                      file.destination.string());
              }
            }
          }
        }
        file.groups.push_back(std::move(group));
      }
      result = resolveFile(file);
      if (!result)
        return result;
      files.push_back(std::move(file));
    }
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus writeRealSlab(int group, int variable,
                                   std::size_t recordIndex,
                                   const double *values,
                                   std::size_t elementCount,
                                   const std::string &path) {
    int dimensionCount = 0;
    auto result =
        detail::checkedNetCDF(nc_inq_varndims(group, variable, &dimensionCount),
                              "Output-variable rank inspection", path);
    if (!result)
      return result;
    std::vector<int> dimensionIds(static_cast<std::size_t>(dimensionCount));
    result = detail::checkedNetCDF(
        nc_inq_vardimid(group, variable, dimensionIds.data()),
        "Output-variable dimension inspection", path);
    if (!result)
      return result;
    std::vector<std::size_t> start(static_cast<std::size_t>(dimensionCount), 0);
    std::vector<std::size_t> count(static_cast<std::size_t>(dimensionCount), 1);
    start.front() = recordIndex;
    std::size_t observed = 1;
    for (std::size_t index = 1; index < dimensionIds.size(); ++index) {
      result = detail::checkedNetCDF(
          nc_inq_dimlen(group, dimensionIds[index], &count[index]),
          "Output-variable dimension length", path);
      if (!result)
        return result;
      observed *= count[index];
    }
    if (observed != elementCount)
      return failure(WVCheckpointStatusCode::shapeMismatch,
                     "Output value and NetCDF slab sizes differ.", path);
    return detail::checkedNetCDF(
        nc_put_vara_double(group, variable, start.data(), count.data(), values),
        "Output-variable write", path);
  }

  WVCheckpointStatus writeComplexSlab(int group, int realId, int imagId,
                                      std::size_t recordIndex,
                                      const WVComplex64 *values,
                                      std::size_t elementCount,
                                      const std::string &path) {
    std::vector<double> real(elementCount);
    std::vector<double> imag(elementCount);
    for (std::size_t index = 0; index < elementCount; ++index) {
      real[index] = values[index].real;
      imag[index] = values[index].imag;
    }
    auto result = writeRealSlab(group, realId, recordIndex, real.data(),
                                elementCount, path + "_real");
    if (!result)
      return result;
    return writeRealSlab(group, imagId, recordIndex, imag.data(), elementCount,
                         path + "_imag");
  }

  WVCheckpointStatus writeRoute(const WVOutputEvent &event,
                                const WVOutputRouteView &route,
                                WVOutputDeliveryResult &delivery) {
    const auto payloadStarted = std::chrono::steady_clock::now();
    if (route.fileOrdinal >= files.size() ||
        route.groupOrdinal >= files[route.fileOrdinal].groups.size())
      return failure(WVCheckpointStatusCode::schemaMismatch,
                     "Output route is outside the configured file graph.", "/");
    auto &file = files[route.fileOrdinal];
    auto &group = file.groups[route.groupOrdinal];
    const std::size_t index = group.recordCount;
    const std::size_t coefficientCount =
        stateLayout.coefficientShape().elementCount();
    if (group.record.containsCompleteCoefficientRestart &&
        !configuration.isDynamicsLinear) {
      const std::array<const WVComplex64 *, 3> values = {
          event.state.waveVortex.coefficients.Ap.data,
          event.state.waveVortex.coefficients.Am.data,
          event.state.waveVortex.coefficients.A0.data};
      for (std::size_t family = 0; family < 3; ++family) {
        auto result = writeComplexSlab(
            group.id, group.coefficientReal[family],
            group.coefficientImag[family], index, values[family],
            coefficientCount,
            "/" + group.record.name + "/" +
                std::array<const char *, 3>{{"Ap", "Am", "A0"}}[family]);
        if (!result)
          return result;
      }
      delivery.writeCount += 6;
      delivery.writtenBytes += 6 * coefficientCount * sizeof(double);
    }
    for (const auto &dynamic : group.dynamicVariables) {
      const auto *block = dynamic.blockIdentifier.empty()
                              ? nullptr
                              : findBlock(event, dynamic.blockIdentifier);
      const double *values = dynamic.fixedValues.empty()
                                 ? block == nullptr ? nullptr : block->realData
                                 : dynamic.fixedValues.data();
      if (values == nullptr || dynamic.scalarType != WVStateScalarType::real64)
        return failure(WVCheckpointStatusCode::shapeMismatch,
                       "Dynamic observer state is absent or incompatible.",
                       "/" + group.record.name + "/" + dynamic.name);
      auto result = writeRealSlab(group.id, dynamic.realId, index,
                                  values, dynamic.elementCount,
                                  "/" + group.record.name + "/" + dynamic.name);
      if (!result)
        return result;
      ++delivery.writeCount;
      delivery.writtenBytes += dynamic.elementCount * sizeof(double);
    }
    for (const auto &variable : group.derivedVariables) {
      if (variable.specification.cadence ==
          WVObserverOutputCadence::initialOnly)
        continue;
      const auto *record = observer(variable.observerIdentifier);
      WVObserverOutputValueView value;
      const auto sourceStatus =
          sampleSource->value(*record, variable.specification, value);
      if (!sourceStatus)
        return failure(
            WVCheckpointStatusCode::unsupportedObserver, sourceStatus.message,
            "/" + group.record.name + "/" + variable.specification.name);
      const auto expected = product(variable.specification.dimensions);
      if (value.elementCount != expected ||
          value.valueType != variable.specification.valueType)
        return failure(WVCheckpointStatusCode::shapeMismatch,
                       "Observer sample does not match its declared schema.",
                       "/" + group.record.name + "/" +
                           variable.specification.name);
      WVCheckpointStatus result;
      if (value.valueType == WVOutputValueType::complex64)
        result = writeComplexSlab(group.id, variable.realId, variable.imagId,
                                  index, value.complexData, expected,
                                  "/" + group.record.name + "/" +
                                      variable.specification.name);
      else
        result = writeRealSlab(
            group.id, variable.realId, index, value.realData, expected,
            "/" + group.record.name + "/" + variable.specification.name);
      if (!result)
        return result;
      delivery.writeCount +=
          value.valueType == WVOutputValueType::complex64 ? 2 : 1;
      delivery.writtenBytes +=
          expected * sizeof(double) *
          (value.valueType == WVOutputValueType::complex64 ? 2 : 1);
    }
    const std::size_t start[] = {index};
    const std::size_t count[] = {1};
    auto result = detail::checkedNetCDF(
        nc_put_vara_double(group.id, group.timeId, start, count,
                           &event.scheduledTime),
        "Output-time commit", "/" + group.record.name + "/t");
    if (!result)
      return result;
    metrics.payloadWriteSeconds += std::chrono::duration<double>(
        std::chrono::steady_clock::now() - payloadStarted).count();
    const auto synchronizationStarted = std::chrono::steady_clock::now();
    result = detail::checkedNetCDF(nc_sync(file.id), "Output-route sync",
                                   file.destination.string());
    if (!result)
      return result;
    metrics.synchronizationSeconds += std::chrono::duration<double>(
        std::chrono::steady_clock::now() - synchronizationStarted).count();
    ++group.recordCount;
    group.committedOrdinal = route.scheduleOrdinal;
    ++metrics.committedRecordCount;
    ++metrics.synchronizationCount;
    metrics.writtenBytes += delivery.writtenBytes + sizeof(double);
    delivery.writeCount += 1;
    delivery.writtenBytes += sizeof(double);
    rebuildProgress();
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus close() noexcept {
    WVCheckpointStatus first = WVCheckpointStatus::ok();
    for (auto &file : files) {
      if (file.id >= 0) {
        const int id = std::exchange(file.id, -1);
        const int code = nc_close(id);
        if (code != NC_NOERR && first)
          first = detail::netcdfFailure(code, "Output-file close",
                                        file.destination.string());
      }
      if (!file.staging.empty()) {
        std::error_code ignored;
        std::filesystem::remove(file.staging, ignored);
      }
    }
    closed = true;
    return first;
  }
};

WVModelOutputNetCDFSink::WVModelOutputNetCDFSink() : impl_(new Impl) {}
WVModelOutputNetCDFSink::~WVModelOutputNetCDFSink() = default;
WVModelOutputNetCDFSink::WVModelOutputNetCDFSink(
    WVModelOutputNetCDFSink &&) noexcept = default;
WVModelOutputNetCDFSink &WVModelOutputNetCDFSink::operator=(
    WVModelOutputNetCDFSink &&) noexcept = default;

WVCheckpointStatus WVModelOutputNetCDFSink::createNew(
    const WVModelOutputNetCDFConfiguration &configuration,
    const WVPortableObserverDescriptor &descriptor,
    const WVIntegrationStateLayout &stateLayout,
    WVObserverSampleSource *sampleSource, WVModelOutputNetCDFSink &sink) {
  try {
    auto candidate = std::make_unique<Impl>();
    candidate->configuration = configuration;
    candidate->descriptorRecord = descriptor.record();
    candidate->stateLayout = stateLayout;
    candidate->sampleSource = sampleSource;
    auto result = candidate->validateConfiguration();
    if (!result)
      return result;
    result = candidate->validateDestinations(false);
    if (!result)
      return result;
    result = candidate->stageFiles();
    if (!result)
      return result;
    result = candidate->commitStagedFiles();
    if (!result)
      return result;
    candidate->rebuildProgress();
    candidate->metrics.fileCount = candidate->files.size();
    for (const auto &file : candidate->files)
      candidate->metrics.groupCount += file.groups.size();
    candidate->metrics.initializedFileCount = candidate->files.size();
    candidate->updateRetainedStorageMetric();
    sink.impl_ = std::move(candidate);
    return WVCheckpointStatus::ok();
  } catch (const std::bad_alloc &) {
    return failure(WVCheckpointStatusCode::writeFailure,
                   "Output persistence allocation failed.", "/");
  } catch (const std::exception &exception) {
    return failure(WVCheckpointStatusCode::writeFailure,
                   "Output persistence creation failed: " +
                       std::string(exception.what()),
                   "/");
  }
}

WVCheckpointStatus WVModelOutputNetCDFSink::openAppend(
    const WVModelOutputNetCDFConfiguration &configuration,
    const WVPortableObserverDescriptor &descriptor,
    const WVIntegrationStateLayout &stateLayout,
    WVObserverSampleSource *sampleSource, WVModelOutputNetCDFSink &sink) {
  try {
    auto candidate = std::make_unique<Impl>();
    candidate->configuration = configuration;
    candidate->descriptorRecord = descriptor.record();
    candidate->stateLayout = stateLayout;
    candidate->sampleSource = sampleSource;
    candidate->appendMode = true;
    auto result = candidate->validateConfiguration();
    if (!result)
      return result;
    result = candidate->validateDestinations(true);
    if (!result)
      return result;
    result = candidate->openExistingFiles();
    if (!result)
      return result;
    candidate->rebuildProgress();
    candidate->metrics.fileCount = candidate->files.size();
    for (const auto &file : candidate->files)
      candidate->metrics.groupCount += file.groups.size();
    candidate->updateRetainedStorageMetric();
    sink.impl_ = std::move(candidate);
    return WVCheckpointStatus::ok();
  } catch (const std::exception &exception) {
    return failure(WVCheckpointStatusCode::openFailure,
                   "Output append failed: " + std::string(exception.what()),
                   "/");
  }
}

WVKernelStatus
WVModelOutputNetCDFSink::preflight(const WVOutputPlan &plan) {
  if (!impl_ || impl_->closed)
    return {WVKernelStatusCode::invalidConfiguration,
            "NetCDF output sink is closed."};
  if (plan.metrics().fileCount != impl_->files.size())
    return {WVKernelStatusCode::invalidConfiguration,
            "Output plan and NetCDF file graph differ."};
  if (impl_->sampleSource != nullptr) {
    const auto sourceStatus = impl_->sampleSource->preflight(plan);
    if (!sourceStatus)
      return sourceStatus;
  }
  std::map<std::pair<std::size_t, std::size_t>, WVOutputScheduleOrdinal>
      lastOrdinals;
  for (std::size_t eventIndex = 0; eventIndex < plan.eventCount();
       ++eventIndex) {
    const auto event = plan.event(eventIndex);
    for (std::size_t routeIndex = 0; routeIndex < event.routeCount;
         ++routeIndex) {
      const auto &route = event.routes[routeIndex];
      if (route.fileOrdinal >= impl_->files.size() ||
          route.groupOrdinal >= impl_->files[route.fileOrdinal].groups.size())
        return {WVKernelStatusCode::invalidConfiguration,
                "Output plan contains an out-of-range NetCDF route."};
      const auto &file = impl_->files[route.fileOrdinal];
      const auto &group = file.groups[route.groupOrdinal];
      if (route.fileIdentifier != file.record.identifier ||
          route.destination != file.record.destination ||
          route.groupIdentifier != group.record.identifier ||
          route.groupName != group.record.name ||
          route.observerCount != group.record.observerIdentifiers.size())
        return {WVKernelStatusCode::invalidConfiguration,
                "Output plan and NetCDF route identity differ."};
      for (std::size_t observerIndex = 0; observerIndex < route.observerCount;
           ++observerIndex) {
        if (route.observers[observerIndex].record == nullptr ||
            route.observers[observerIndex].record->identifier !=
                group.record.observerIdentifiers[observerIndex])
          return {WVKernelStatusCode::invalidConfiguration,
                  "Output plan and NetCDF observer route differ."};
      }
      const double expected = group.record.schedule.initialTime +
                              static_cast<double>(route.scheduleOrdinal) *
                                  group.record.schedule.outputInterval;
      const double tolerance =
          8 * std::numeric_limits<double>::epsilon() *
          std::max({1.0, std::abs(expected), std::abs(event.scheduledTime)});
      const auto key = std::make_pair(route.fileOrdinal, route.groupOrdinal);
      auto position = lastOrdinals.emplace(key, group.committedOrdinal).first;
      auto &last = position->second;
      if (route.scheduleOrdinal <= group.committedOrdinal ||
          route.scheduleOrdinal <= last ||
          std::abs(event.scheduledTime - expected) > tolerance)
        return {WVKernelStatusCode::invalidConfiguration,
                "Output plan is incompatible with committed NetCDF progress."};
      last = route.scheduleOrdinal;
    }
  }
  impl_->preflightComplete = true;
  return WVKernelStatus::ok();
}

WVKernelStatus
WVModelOutputNetCDFSink::deliver(const WVOutputEvent &event,
                                 const WVOutputRouteView &route,
                                 WVOutputDeliveryResult &result) {
  if (!impl_ || !impl_->preflightComplete || impl_->closed)
    return {WVKernelStatusCode::invalidConfiguration,
            "NetCDF output sink has not completed preflight."};
  if (impl_->sampleSource != nullptr &&
      impl_->preparedEventOrdinal != event.eventOrdinal) {
    const auto status = impl_->sampleSource->prepare(event);
    if (!status) {
      ++impl_->metrics.failureCount;
      return status;
    }
    impl_->preparedEventOrdinal = event.eventOrdinal;
  }
  const auto status = impl_->writeRoute(event, route, result);
  if (!status) {
    ++impl_->metrics.failureCount;
    return kernelFailure(status);
  }
  return WVKernelStatus::ok();
}

const std::vector<WVOutputGroupProgress> &
WVModelOutputNetCDFSink::progress() const noexcept {
  static const std::vector<WVOutputGroupProgress> empty;
  return impl_ ? impl_->progress : empty;
}

const WVModelOutputNetCDFMetrics &
WVModelOutputNetCDFSink::metrics() const noexcept {
  static const WVModelOutputNetCDFMetrics empty;
  return impl_ ? impl_->metrics : empty;
}

WVCheckpointStatus WVModelOutputNetCDFSink::close() noexcept {
  return impl_ ? impl_->close() : WVCheckpointStatus::ok();
}

} // namespace wavevortex::runtime
