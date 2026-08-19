#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"
#include "WaveVortexRuntime/generated/WVPortableVariableCatalog.hpp"

#include "WVModelOutputNetCDFSchema.hpp"
#include "WVNetCDF.hpp"
#include "WVObserverAdapter.hpp"

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

std::shared_ptr<const WVObservingSystem>
observerImplementation(const WVObserverRecord &record) {
  return detail::observerImplementation(record.typeIdentifier,
                                        record.contractVersion);
}

WVCheckpointStatus failure(WVCheckpointStatusCode code, std::string message,
                           std::string location) {
  return {code, std::move(message), std::move(location)};
}

const WVPortableVariableMetadata *
coefficientMetadata(std::string_view name) noexcept {
  const auto *metadata = findPortableVariable(name);
  return metadata != nullptr &&
                 metadata->kind == WVPortableVariableKind::coefficient
             ? metadata
             : nullptr;
}

const char *coordinateRoleName(WVObservationCoordinateRole role) noexcept {
  switch (role) {
  case WVObservationCoordinateRole::none:
    return "none";
  case WVObservationCoordinateRole::recordTime:
    return "record-time";
  case WVObservationCoordinateRole::sampleTime:
    return "sample-time";
  case WVObservationCoordinateRole::x:
    return "x";
  case WVObservationCoordinateRole::y:
    return "y";
  case WVObservationCoordinateRole::z:
    return "z";
  case WVObservationCoordinateRole::identifier:
    return "identifier";
  case WVObservationCoordinateRole::depth:
    return "depth";
  case WVObservationCoordinateRole::pass:
    return "pass";
  case WVObservationCoordinateRole::profile:
    return "profile";
  }
  return "none";
}

const char *raggedRoleName(WVObservationRaggedRole role) noexcept {
  switch (role) {
  case WVObservationRaggedRole::none:
    return "none";
  case WVObservationRaggedRole::rowCount:
    return "row-count";
  case WVObservationRaggedRole::rowOffset:
    return "row-offset";
  }
  return "none";
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

std::string hexEncode(const std::vector<std::uint8_t> &bytes) {
  static constexpr char digits[] = "0123456789abcdef";
  std::string result(bytes.size() * 2, '0');
  for (std::size_t index = 0; index < bytes.size(); ++index) {
    result[2 * index] = digits[bytes[index] >> 4U];
    result[2 * index + 1] = digits[bytes[index] & 0x0fU];
  }
  return result;
}

bool hexDecode(const std::string &text, std::vector<std::uint8_t> &bytes) {
  if (text.size() % 2 != 0)
    return false;
  auto digit = [](char value) -> int {
    if (value >= '0' && value <= '9')
      return value - '0';
    if (value >= 'a' && value <= 'f')
      return value - 'a' + 10;
    if (value >= 'A' && value <= 'F')
      return value - 'A' + 10;
    return -1;
  };
  bytes.resize(text.size() / 2);
  for (std::size_t index = 0; index < bytes.size(); ++index) {
    const auto high = digit(text[2 * index]);
    const auto low = digit(text[2 * index + 1]);
    if (high < 0 || low < 0)
      return false;
    bytes[index] = static_cast<std::uint8_t>((high << 4) | low);
  }
  return true;
}

} // namespace

class WVModelOutputNetCDFSink::Impl {
public:
  struct Variable {
    std::string observerIdentifier;
    std::string schemaIdentifier;
    std::uint32_t schemaVersion = WVObservationSchemaContractVersion;
    WVObservationVariable specification;
    std::vector<WVObservationAxis> axes;
    int realId = -1;
    int imagId = -1;
  };

  struct ObserverSchema {
    std::string observerIdentifier;
    WVObservationSchema schema;
  };

  struct UnlimitedAxis {
    std::string name;
    std::size_t committedCount = 0;
    int dimensionId = -1;
    int progressVariableId = -1;
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
    int scheduleOrdinalId = -1;
    int scheduleCursorId = -1;
    std::array<int, 3> coefficientReal{{-1, -1, -1}};
    std::array<int, 3> coefficientImag{{-1, -1, -1}};
    std::vector<DynamicVariable> dynamicVariables;
    std::vector<Variable> derivedVariables;
    std::vector<StaticVariable> staticVariables;
    std::vector<ObserverSchema> observerSchemas;
    std::vector<UnlimitedAxis> unlimitedAxes;
    std::size_t recordCount = 0;
    WVOutputScheduleOrdinal committedOrdinal = WVNoCommittedOutputOrdinal;
    WVPortableTypedRecord scheduleCursor;
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

  static const WVObservationAxis *
  axis(const WVObservationSchema &schema,
       const std::string &identifier) noexcept {
    const auto found =
        std::find_if(schema.axes.begin(), schema.axes.end(),
                     [&](const auto &candidate) {
                       return candidate.identifier == identifier;
                     });
    return found == schema.axes.end() ? nullptr : &*found;
  }

  static const WVObservationValue *
  value(const WVObservationBatch &batch,
        const std::string &identifier) noexcept {
    const auto found =
        std::find_if(batch.values.begin(), batch.values.end(),
                     [&](const auto &candidate) {
                       return candidate.variableIdentifier == identifier;
                     });
    return found == batch.values.end() ? nullptr : &*found;
  }

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
      const auto observerBehavior = observerImplementation(record);
      const bool requiresDerivedValues =
          observerBehavior->recordsEulerianFields() ||
          observerBehavior->recordsFixedProfiles() ||
          observerBehavior->recordsFixedPoints() ||
          (observerBehavior->recordsMovingParticles() &&
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
            observerImplementation(*record)->recordsCoefficients();
        hasEulerianCoefficientObserver =
            hasEulerianCoefficientObserver ||
            (observerImplementation(*record)->recordsEulerianFields() &&
             std::find(record->fieldNames.begin(), record->fieldNames.end(),
                       "Ap") != record->fieldNames.end() &&
             std::find(record->fieldNames.begin(), record->fieldNames.end(),
                       "Am") != record->fieldNames.end() &&
             std::find(record->fieldNames.begin(), record->fieldNames.end(),
                       "A0") != record->fieldNames.end());
      }
      if ((configuration.isDynamicsLinear && !hasEulerianCoefficientObserver) ||
          (!configuration.isDynamicsLinear && !hasCoefficientObserver))
        return failure(
            WVCheckpointStatusCode::schemaMismatch,
            configuration.isDynamicsLinear
                ? "Linear output requires initial Eulerian Ap, Am, and A0."
                : "Nonlinear output requires WVCoefficients.",
            file.destination + ":/" + restart->name);
      std::set<std::string> restartBlocks{"Ap", "Am", "A0"};
      for (const auto &group : file.groups) {
        for (const auto &observerIdentifier : group.observerIdentifiers) {
          const auto *record = observer(observerIdentifier);
          if (record != nullptr)
            restartBlocks.insert(record->stateBlockIdentifiers.begin(),
                                 record->stateBlockIdentifiers.end());
        }
      }
      for (const auto &block : stateLayout.stateBlockRecords()) {
        if (block.restartRequirement ==
                WVRestartRequirement::requiredDynamicState &&
            restartBlocks.find(block.identifier) == restartBlocks.end())
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "The output file omits required dynamic observer "
                         "state from its restart graph.",
                         file.destination);
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
                                            const std::string &path,
                                            const WVObservationSchema *schema,
                                            int &group) {
    const std::string groupName =
        "observingSystems-" + std::to_string(ordinal + 1);
    auto result = detail::checkedNetCDF(
        nc_def_grp(parent, groupName.c_str(), &group),
        "Observer metadata-group definition", path + "/" + groupName);
    if (!result)
      return result;
    const std::string observerPath = path + "/" + groupName;
    const auto observerBehavior = observerImplementation(record);
    if (!observerBehavior)
      return failure(WVCheckpointStatusCode::unsupportedObserver,
                     "Unsupported observer metadata definition.", observerPath);
    result = detail::putTextAttribute(group, NC_GLOBAL, "AnnotatedClass",
                                      observerBehavior->typeIdentifier(),
                                      observerPath);
    if (!result)
      return result;
    result = detail::putTextAttribute(group, NC_GLOBAL, "portableIdentifier",
                                      record.identifier, observerPath);
    if (!result)
      return result;
    if (schema != nullptr && !schema->preservesLegacyEncoding) {
      result = detail::putTextAttribute(
          group, NC_GLOBAL, "portableObservationSchemaIdentifier",
          schema->identifier, observerPath);
      if (!result)
        return result;
      result = detail::checkedNetCDF(
          nc_put_att_uint(group, NC_GLOBAL,
                          "portableObservationSchemaVersion", NC_UINT, 1,
                          &schema->version),
          "Observation-schema version definition", observerPath);
      if (!result)
        return result;
    }
    if (!observerBehavior->recordsEulerianFields()) {
      result = detail::putTextAttribute(group, NC_GLOBAL, "name", record.name,
                                        observerPath);
      if (!result)
        return result;
    }
    if (!observerBehavior->fieldListAttribute().empty()) {
      result = putStringListAttribute(
          group, observerBehavior->fieldListAttribute().c_str(),
          record.fieldNames, observerPath);
      if (!result)
        return result;
    }
    if (observerBehavior->recordsCoefficients()) {
      int variable = -1;
      result = defineScalar(group, "absTolerance", variable, observerPath);
      if (!result)
        return result;
      return WVCheckpointStatus::ok();
    }
    if (observerBehavior->recordsMovingParticles() ||
        observerBehavior->recordsTracerState()) {
      int variable = -1;
      result = defineLogicalScalar(group, "isXYOnly", variable, observerPath);
      if (!result)
        return result;
    }
    if (observerBehavior->recordsMovingParticles()) {
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
    if (observerBehavior->recordsTracerState()) {
      int variable = -1;
      result = defineScalar(group, "absTolerance", variable, observerPath);
      if (!result)
        return result;
      return defineLogicalScalar(group, "shouldAntialias", variable,
                                 observerPath);
    }
    if (observerBehavior->recordsFixedPoints()) {
      int variable = -1;
      result = defineScalar(group, "outputScale", variable, observerPath);
      if (!result)
        return result;
      result = defineScalar(group, "outputOffset", variable, observerPath);
      if (!result)
        return result;
      return detail::putTextAttribute(
          group, NC_GLOBAL, "trackedVarInterpolation",
          record.trackedFieldInterpolation == WVPositionInterpolation::linear
              ? "linear"
              : "spline",
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
    if (!group.record.schedule.typeIdentifier.empty()) {
      result = detail::putTextAttribute(
          group.id, NC_GLOBAL, "portableScheduleTypeIdentifier",
          group.record.schedule.typeIdentifier, path);
      if (!result)
        return result;
      result = detail::checkedNetCDF(
          nc_put_att_uint(group.id, NC_GLOBAL,
                          "portableScheduleContractVersion", NC_UINT, 1,
                          &group.record.schedule.contractVersion),
          "Schedule-version attribute definition", path);
      if (!result)
        return result;
      std::vector<std::uint8_t> configuration;
      const auto encoded = encodePortableTypedRecord(
          group.record.schedule.configuration, configuration);
      if (!encoded)
        return failure(WVCheckpointStatusCode::invalidValue, encoded.message,
                       path);
      result = detail::putTextAttribute(group.id, NC_GLOBAL,
                                        "portableScheduleConfiguration",
                                        hexEncode(configuration), path);
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
    if (!group.record.schedule.typeIdentifier.empty()) {
      result = detail::checkedNetCDF(
          nc_def_var(group.id, "portableScheduleOrdinal", NC_INT64, 1,
                     &timeDimension, &group.scheduleOrdinalId),
          "Schedule-ordinal variable definition", path);
      if (!result)
        return result;
      result = detail::checkedNetCDF(
          nc_def_var(group.id, "portableScheduleCursor", NC_STRING, 1,
                     &timeDimension, &group.scheduleCursorId),
          "Schedule-cursor variable definition", path);
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
        const auto *metadata = coefficientMetadata(name);
        if (metadata == nullptr)
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "Canonical coefficient metadata is unavailable.",
                         path + "/" + name);
        for (const int variable : {real, imag}) {
          if (result)
            result =
                detail::putTextAttribute(group.id, variable, "units",
                                         metadata->units, path + "/" + name);
          if (result)
            result = detail::putTextAttribute(group.id, variable, "long_name",
                                              metadata->description,
                                              path + "/" + name);
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

    std::map<std::string, WVObservationVariable> definedDerivedVariables;
    for (std::size_t ordinal = 0;
         ordinal < group.record.observerIdentifiers.size(); ++ordinal) {
      const auto *record = observer(group.record.observerIdentifiers[ordinal]);
      if (record == nullptr)
        return failure(WVCheckpointStatusCode::schemaMismatch,
                       "Output group references an unknown observer.", path);
      WVObservationSchema observationSchemaValue;
      const WVObservationSchema *observationSchema = nullptr;
      if (sampleSource != nullptr) {
        const auto sourceStatus = sampleSource->observationSchema(
            *record, observationSchemaValue);
        if (!sourceStatus)
          return failure(WVCheckpointStatusCode::unsupportedObserver,
                         sourceStatus.message, path);
        const auto schemaStatus =
            validateObservationSchema(observationSchemaValue);
        if (!schemaStatus)
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         schemaStatus.message, path);
        observationSchema = &observationSchemaValue;
      }
      int observerMetadataGroup = -1;
      result = defineObserverMetadata(metadataRoot, *record, ordinal,
                                      path + "/observingSystems",
                                      observationSchema,
                                      observerMetadataGroup);
      if (!result)
        return result;

      const auto observerBehavior = observerImplementation(*record);
      if (observerBehavior->recordsFixedProfiles()) {
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
            definition =
                detail::putTextAttribute(group.id, variable.id, "long_name",
                                         longName, path + "/" + name);
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
      } else if (observerBehavior->recordsFixedPoints()) {
        int pointDimension = -1;
        const std::string dimensionName = record->name + "_id";
        result = detail::checkedNetCDF(
            nc_def_dim(group.id, dimensionName.c_str(), record->x.size(),
                       &pointDimension),
            "Point-observer dimension definition", path + "/" + dimensionName);
        if (!result)
          return result;
        const auto addStaticPoint =
            [&](const std::string &name, std::vector<double> values,
                const std::string &units, const std::string &longName) {
              StaticVariable variable;
              variable.name = name;
              variable.values = std::move(values);
              auto definition = detail::defineDoubleVariable(
                  group.id, name, {pointDimension}, variable.id, path);
              if (definition)
                definition = detail::putTextAttribute(
                    group.id, variable.id, "units", units, path + "/" + name);
              if (definition && !longName.empty())
                definition =
                    detail::putTextAttribute(group.id, variable.id, "long_name",
                                             longName, path + "/" + name);
              if (definition)
                group.staticVariables.push_back(std::move(variable));
              return definition;
            };
        std::vector<double> identifiers(record->x.size());
        for (std::size_t index = 0; index < identifiers.size(); ++index)
          identifiers[index] = static_cast<double>(index + 1);
        result = addStaticPoint(dimensionName, std::move(identifiers),
                                "unitless id number", "");
        if (!result)
          return result;
        for (const auto &[suffix, values] :
             std::array<std::pair<const char *, const std::vector<double> *>,
                        3>{
                 {{"x", &record->x}, {"y", &record->y}, {"z", &record->z}}}) {
          result = addStaticPoint(record->name + '_' + suffix, *values, "m",
                                  std::string(suffix) +
                                      " position of fixed observation");
          if (!result)
            return result;
        }
      } else if (observerBehavior->recordsMovingParticles()) {
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
          const std::array<std::pair<const char *, std::string>, 3> attributes{
              {{"isParticle", "1"},
               {"particleName", record->name},
               {"particleVariableName", suffix}}};
          for (const auto &attribute : attributes) {
            result = detail::putTextAttribute(group.id, dynamic.realId,
                                              attribute.first, attribute.second,
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
                group.id, dynamic.realId, "long_name", "z position of particle",
                path + "/" + dynamic.name);
          if (result)
            result =
                detail::putTextAttribute(group.id, dynamic.realId, "isParticle",
                                         "1", path + "/" + dynamic.name);
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
      } else if (observerBehavior->recordsTracerState()) {
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
          result =
              detail::putTextAttribute(group.id, dynamic.realId, "isTracer",
                                       "1", path + "/" + dynamic.name);
        if (!result)
          return result;
        group.dynamicVariables.push_back(std::move(dynamic));
      }

      if (observationSchema == nullptr)
        continue;
      for (const auto &specification : observationSchema->variables) {
        const bool canonicalCoefficient =
            group.record.containsCompleteCoefficientRestart &&
            coefficientMetadata(specification.name) != nullptr;
        if (canonicalCoefficient)
          continue;
        const auto existing = definedDerivedVariables.find(specification.name);
        if (existing != definedDerivedVariables.end()) {
          const auto &prior = existing->second;
          if (prior.scalarType != specification.scalarType ||
              prior.layout != specification.layout ||
              prior.dimensionIdentifiers !=
                  specification.dimensionIdentifiers)
            return failure(WVCheckpointStatusCode::schemaMismatch,
                           "Observers declare incompatible variables with the "
                           "same name.",
                           path + "/" + specification.name);
          continue;
        }
        definedDerivedVariables.emplace(specification.name, specification);
        std::vector<int> dimensions;
        if (specification.layout == WVObservationValueLayout::record)
          dimensions.push_back(timeDimension);
        std::vector<WVObservationAxis> variableAxes;
        variableAxes.reserve(specification.dimensionIdentifiers.size());
        for (const auto &identifier : specification.dimensionIdentifiers) {
          const auto *axisDefinition = axis(*observationSchema, identifier);
          if (axisDefinition == nullptr)
            return failure(WVCheckpointStatusCode::schemaMismatch,
                           "Observation variable references an unknown axis.",
                           path + "/" + specification.name);
          variableAxes.push_back(*axisDefinition);
        }
        for (std::size_t reverse = variableAxes.size(); reverse > 0; --reverse) {
          const auto logicalIndex = reverse - 1;
          int dimension = -1;
          const auto &axisDefinition = variableAxes[logicalIndex];
          const auto &name = axisDefinition.name;
          if (nc_inq_dimid(group.id, name.c_str(), &dimension) != NC_NOERR) {
            result = detail::checkedNetCDF(
                nc_def_dim(group.id, name.c_str(),
                           axisDefinition.kind == WVObservationAxisKind::unlimited
                               ? NC_UNLIMITED
                               : axisDefinition.extent,
                           &dimension),
                "Observer dimension definition", path + "/" + name);
            if (!result)
              return result;
          }
          if (axisDefinition.kind == WVObservationAxisKind::unlimited) {
            const auto foundAxis = std::find_if(
                group.unlimitedAxes.begin(), group.unlimitedAxes.end(),
                [&](const auto &candidate) { return candidate.name == name; });
            if (foundAxis == group.unlimitedAxes.end()) {
              UnlimitedAxis unlimited;
              unlimited.name = name;
              unlimited.dimensionId = dimension;
              const std::string progressName = "portableCommitted_" + name;
              result = detail::checkedNetCDF(
                  nc_def_var(group.id, progressName.c_str(), NC_INT64, 1,
                             &timeDimension, &unlimited.progressVariableId),
                  "Observation-axis progress definition",
                  path + "/" + progressName);
              if (!result)
                return result;
              group.unlimitedAxes.push_back(std::move(unlimited));
            } else if (foundAxis->dimensionId != dimension) {
              return failure(WVCheckpointStatusCode::schemaMismatch,
                             "Observation schemas disagree on an unlimited axis.",
                             path + "/" + name);
            }
          }
          dimensions.push_back(dimension);
        }
        Variable variable;
        variable.observerIdentifier = record->identifier;
        variable.schemaIdentifier = observationSchema->identifier;
        variable.schemaVersion = observationSchema->version;
        variable.specification = specification;
        variable.axes = std::move(variableAxes);
        if (specification.scalarType == WVObservationScalarType::complex64) {
          result = detail::defineComplexVariable(group.id, specification.name,
                                                 dimensions, path);
          if (!result)
            return result;
        } else if (specification.scalarType ==
                   WVObservationScalarType::real64) {
          result = detail::defineDoubleVariable(
              group.id, specification.name, dimensions, variable.realId, path);
          if (!result)
            return result;
        } else {
          const nc_type type =
              specification.scalarType == WVObservationScalarType::integer64
                  ? NC_INT64
                  : specification.scalarType ==
                            WVObservationScalarType::boolean8
                        ? NC_UBYTE
                        : NC_STRING;
          result = detail::checkedNetCDF(
              nc_def_var(group.id, specification.name.c_str(), type,
                         static_cast<int>(dimensions.size()),
                         dimensions.empty() ? nullptr : dimensions.data(),
                         &variable.realId),
              "Observer-variable definition",
              path + "/" + specification.name);
          if (!result)
            return result;
          if (specification.scalarType == WVObservationScalarType::boolean8) {
            result = detail::putByteAttribute(
                group.id, variable.realId, "isLogicalType", 1,
                path + "/" + specification.name);
            if (!result)
              return result;
          }
        }
        const auto applyAttributes = [&](int variableId,
                                         const std::string &variablePath) {
          auto attributeResult = WVCheckpointStatus::ok();
          if (!specification.units.empty())
            attributeResult =
                detail::putTextAttribute(group.id, variableId, "units",
                                         specification.units, variablePath);
          if (attributeResult && !specification.description.empty())
            attributeResult =
                detail::putTextAttribute(group.id, variableId, "long_name",
                                         specification.description, variablePath);
          for (const auto &attribute : specification.attributes) {
            if (!attributeResult)
              break;
            attributeResult = detail::putTextAttribute(
                group.id, variableId, attribute.name.c_str(), attribute.value,
                variablePath);
          }
          if (attributeResult && !observationSchema->preservesLegacyEncoding) {
            attributeResult = detail::putTextAttribute(
                group.id, variableId, "portableObservationVariableIdentifier",
                specification.identifier, variablePath);
          }
          if (attributeResult && !observationSchema->preservesLegacyEncoding &&
              specification.coordinateRole !=
                  WVObservationCoordinateRole::none)
            attributeResult = detail::putTextAttribute(
                group.id, variableId, "portableCoordinateRole",
                coordinateRoleName(specification.coordinateRole), variablePath);
          if (attributeResult && !observationSchema->preservesLegacyEncoding &&
              specification.raggedRole != WVObservationRaggedRole::none) {
            attributeResult = detail::putTextAttribute(
                group.id, variableId, "portableRaggedRole",
                raggedRoleName(specification.raggedRole), variablePath);
            if (attributeResult)
              attributeResult = detail::putTextAttribute(
                  group.id, variableId, "portableRaggedChildAxis",
                  specification.raggedChildAxisIdentifier, variablePath);
          }
          return attributeResult;
        };
        if (specification.scalarType == WVObservationScalarType::complex64) {
          int real = -1;
          int imag = -1;
          result = detail::checkedNetCDF(
              nc_inq_varid(group.id, (specification.name + "_real").c_str(),
                           &real),
              "Observer-variable lookup", path);
          if (result)
            result = detail::checkedNetCDF(
                nc_inq_varid(group.id, (specification.name + "_imag").c_str(),
                             &imag),
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
          result =
              applyAttributes(variable.realId, path + "/" + specification.name);
        }
        if (!result)
          return result;
        group.derivedVariables.push_back(std::move(variable));
      }
      group.observerSchemas.push_back(
          {record->identifier, std::move(observationSchemaValue)});
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
        const auto observerBehavior = observerImplementation(*record);
        if (observerBehavior->recordsCoefficients()) {
          const auto *block = stateBlockRecord("Ap");
          result = writeScalar(
              metadata, "absTolerance",
              block == nullptr ? 1e-6 : block->absoluteTolerance, metadataPath);
        } else if (observerBehavior->recordsMovingParticles()) {
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
        } else if (observerBehavior->recordsTracerState()) {
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
        } else if (observerBehavior->recordsFixedPoints()) {
          result = writeScalar(metadata, "outputScale", record->outputScale,
                               metadataPath);
          if (result)
            result = writeScalar(metadata, "outputOffset", record->outputOffset,
                                 metadataPath);
        }
        if (!result)
          return result;
      }
    }
    (void)fileId;
    return WVCheckpointStatus::ok();
  }

  WVCheckpointStatus writeObservationValue(
      Group &group, const Variable &variable,
      const WVObservationValue &value, std::size_t recordIndex,
      const std::string &path) {
    std::vector<std::size_t> start;
    std::vector<std::size_t> count;
    if (variable.specification.layout == WVObservationValueLayout::record) {
      start.push_back(recordIndex);
      count.push_back(1);
    }
    for (std::size_t reverse = variable.axes.size(); reverse > 0; --reverse) {
      const auto logicalIndex = reverse - 1;
      const auto &axisDefinition = variable.axes[logicalIndex];
      std::size_t axisStart = 0;
      if (axisDefinition.kind == WVObservationAxisKind::unlimited) {
        const auto found = std::find_if(
            group.unlimitedAxes.begin(), group.unlimitedAxes.end(),
            [&](const auto &candidate) {
              return candidate.name == axisDefinition.name;
            });
        if (found == group.unlimitedAxes.end())
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "Observation batch references an unresolved unlimited axis.",
                         path);
        axisStart = found->committedCount;
      }
      start.push_back(axisStart);
      count.push_back(value.extents[logicalIndex]);
    }
    const auto elementCount = value.elementCount();
    if (elementCount == 0)
      return WVCheckpointStatus::ok();
    const auto putReal = [&](int variableId, const double *values,
                             const std::string &variablePath) {
      return detail::checkedNetCDF(
          start.empty()
              ? nc_put_var_double(group.id, variableId, values)
              : nc_put_vara_double(group.id, variableId, start.data(),
                                   count.data(), values),
          "Observation value write", variablePath);
    };
    if (value.scalarType == WVObservationScalarType::real64)
      return putReal(variable.realId, value.real64Data(), path);
    if (value.scalarType == WVObservationScalarType::complex64) {
      std::vector<double> real(elementCount);
      std::vector<double> imaginary(elementCount);
      for (std::size_t index = 0; index < elementCount; ++index) {
        real[index] = value.complex64Data()[index].real;
        imaginary[index] = value.complex64Data()[index].imag;
      }
      auto result = putReal(variable.realId, real.data(), path + "_real");
      if (!result)
        return result;
      return putReal(variable.imagId, imaginary.data(), path + "_imag");
    }
    if (value.scalarType == WVObservationScalarType::integer64) {
      std::vector<long long> integers(elementCount);
      std::transform(value.integer64Data(),
                     value.integer64Data() + elementCount, integers.begin(),
                     [](std::int64_t entry) {
                       return static_cast<long long>(entry);
                     });
      return detail::checkedNetCDF(
          start.empty()
              ? nc_put_var_longlong(group.id, variable.realId,
                                    integers.data())
              : nc_put_vara_longlong(group.id, variable.realId, start.data(),
                                     count.data(), integers.data()),
          "Integer observation value write", path);
    }
    if (value.scalarType == WVObservationScalarType::boolean8)
      return detail::checkedNetCDF(
          start.empty()
              ? nc_put_var_uchar(group.id, variable.realId,
                                 value.boolean8Data())
              : nc_put_vara_uchar(group.id, variable.realId, start.data(),
                                  count.data(), value.boolean8Data()),
          "Boolean observation value write", path);
    std::vector<const char *> textValues(elementCount);
    for (std::size_t index = 0; index < elementCount; ++index)
      textValues[index] = value.textData()[index].c_str();
    return detail::checkedNetCDF(
        start.empty()
            ? nc_put_var_string(group.id, variable.realId, textValues.data())
            : nc_put_vara_string(group.id, variable.realId, start.data(),
                                 count.data(), textValues.data()),
        "Text observation value write", path);
  }

  WVCheckpointStatus writeInitialAndStaticValues(File &file) {
    const auto coefficientCount = configuration.checkpointTemplate.state
                                      .coefficients.shape.elementCount();
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
      for (const auto &observerSchema : group.observerSchemas) {
        const auto *record = observer(observerSchema.observerIdentifier);
        WVObservationBatch batch;
        const auto sourceStatus =
            sampleSource->initialObservationBatch(*record, batch);
        if (!sourceStatus)
          return failure(WVCheckpointStatusCode::unsupportedObserver,
                         sourceStatus.message, path);
        const auto batchStatus =
            validateObservationBatch(observerSchema.schema, batch);
        if (!batchStatus)
          return failure(WVCheckpointStatusCode::shapeMismatch,
                         batchStatus.message, path);
        const auto batchMetrics = batch.metrics();
        metrics.batchRetainedStorageBytes = std::max(
            metrics.batchRetainedStorageBytes,
            batchMetrics.retainedStorageBytes);
        metrics.batchMaximumLiveBytes =
            std::max(metrics.batchMaximumLiveBytes, batchMetrics.liveBytes);
        for (const auto &value : batch.values) {
          const auto variable = std::find_if(
              group.derivedVariables.begin(), group.derivedVariables.end(),
              [&](const auto &candidate) {
                return candidate.observerIdentifier ==
                           observerSchema.observerIdentifier &&
                       candidate.specification.identifier ==
                           value.variableIdentifier;
              });
          if (variable == group.derivedVariables.end()) {
            const auto declared = std::find_if(
                observerSchema.schema.variables.begin(),
                observerSchema.schema.variables.end(), [&](const auto &item) {
                  return item.identifier == value.variableIdentifier;
                });
            if (declared != observerSchema.schema.variables.end() &&
                group.record.containsCompleteCoefficientRestart &&
                coefficientMetadata(declared->name) != nullptr)
              continue;
            return failure(WVCheckpointStatusCode::schemaMismatch,
                           "Initial observation value has no persistence variable.",
                           path);
          }
          const auto result = writeObservationValue(
              group, *variable, value, 0,
              path + "/" + variable->specification.name);
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

  WVCheckpointStatus replaceStagedFiles() {
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

    struct Replacement {
      std::filesystem::path destination;
      std::filesystem::path backup;
      bool moved = false;
      bool installed = false;
    };
    std::vector<Replacement> replacements;
    replacements.reserve(files.size());
    for (const auto &file : files)
      replacements.push_back(
          {file.destination, temporaryPath(file.destination), false, false});

    auto rollback = [&]() noexcept {
      for (auto &file : files) {
        if (file.id >= 0)
          nc_close(std::exchange(file.id, -1));
      }
      for (auto iterator = replacements.rbegin();
           iterator != replacements.rend(); ++iterator) {
        std::error_code ignored;
        if (iterator->installed)
          std::filesystem::remove(iterator->destination, ignored);
        if (iterator->moved)
          std::filesystem::rename(iterator->backup, iterator->destination,
                                  ignored);
      }
    };

    for (auto &replacement : replacements) {
      std::error_code error;
      std::filesystem::rename(replacement.destination, replacement.backup,
                              error);
      if (error) {
        rollback();
        return failure(WVCheckpointStatusCode::commitFailure,
                       "Unable to stage the existing output set for "
                       "replacement: " +
                           error.message(),
                       replacement.destination.string());
      }
      replacement.moved = true;
    }
    for (std::size_t index = 0; index < files.size(); ++index) {
      std::error_code error;
      std::filesystem::create_hard_link(files[index].staging,
                                        files[index].destination, error);
      if (error) {
        rollback();
        return failure(WVCheckpointStatusCode::commitFailure,
                       "Unable to install the replacement output set: " +
                           error.message(),
                       files[index].destination.string());
      }
      replacements[index].installed = true;
    }

    for (auto &file : files) {
      int id = -1;
      auto result = detail::checkedNetCDF(
          nc_open(file.destination.c_str(), NC_WRITE, &id),
          "Replacement output-file open", file.destination.string());
      if (!result) {
        rollback();
        return result;
      }
      file.id = id;
      result = resolveFile(file);
      if (!result) {
        rollback();
        return result;
      }
    }

    // Replacement is committed once every new file has opened and resolved.
    // Backup cleanup is best-effort: a cleanup failure must not report a
    // rollback-safe failure after an earlier backup has already been removed.
    for (const auto &replacement : replacements) {
      std::error_code ignored;
      std::filesystem::remove(replacement.backup, ignored);
    }
    for (auto &file : files) {
      std::error_code ignored;
      std::filesystem::remove(file.staging, ignored);
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
      if (!group.record.schedule.typeIdentifier.empty()) {
        std::string observedType;
        result = detail::readTextAttribute(
            group.id, "portableScheduleTypeIdentifier", observedType,
            "/" + group.record.name);
        if (!result || observedType != group.record.schedule.typeIdentifier)
          return failure(WVCheckpointStatusCode::appendConflict,
                         "Existing algorithmic schedule identity differs.",
                         "/" + group.record.name);
        unsigned int observedVersion = 0;
        result = detail::checkedNetCDF(
            nc_get_att_uint(group.id, NC_GLOBAL,
                            "portableScheduleContractVersion",
                            &observedVersion),
            "Schedule-version attribute read", "/" + group.record.name);
        if (!result || observedVersion != group.record.schedule.contractVersion)
          return failure(WVCheckpointStatusCode::appendConflict,
                         "Existing algorithmic schedule version differs.",
                         "/" + group.record.name);
        std::vector<std::uint8_t> configuration;
        const auto encoded = encodePortableTypedRecord(
            group.record.schedule.configuration, configuration);
        if (!encoded)
          return failure(WVCheckpointStatusCode::invalidValue, encoded.message,
                         "/" + group.record.name);
        std::string observedConfiguration;
        result = detail::readTextAttribute(
            group.id, "portableScheduleConfiguration", observedConfiguration,
            "/" + group.record.name);
        if (!result || observedConfiguration != hexEncode(configuration))
          return failure(WVCheckpointStatusCode::appendConflict,
                         "Existing algorithmic schedule configuration differs.",
                         "/" + group.record.name);
      }
      if (!group.observerSchemas.empty()) {
        int metadataRoot = -1;
        result = detail::checkedNetCDF(
            nc_inq_ncid(group.id, "observingSystems", &metadataRoot),
            "Observer metadata-root lookup",
            "/" + group.record.name + "/observingSystems");
        if (!result)
          return result;
        for (std::size_t ordinal = 0;
             ordinal < group.record.observerIdentifiers.size(); ++ordinal) {
          const auto schema = std::find_if(
              group.observerSchemas.begin(), group.observerSchemas.end(),
              [&](const auto &candidate) {
                return candidate.observerIdentifier ==
                       group.record.observerIdentifiers[ordinal];
              });
          if (schema == group.observerSchemas.end() ||
              schema->schema.preservesLegacyEncoding)
            continue;
          int metadata = -1;
          const std::string metadataName =
              "observingSystems-" + std::to_string(ordinal + 1);
          result = detail::checkedNetCDF(
              nc_inq_ncid(metadataRoot, metadataName.c_str(), &metadata),
              "Observer metadata-group lookup",
              "/" + group.record.name + "/observingSystems/" + metadataName);
          if (!result)
            return result;
          std::string observedIdentifier;
          result = detail::readTextAttribute(
              metadata, "portableObservationSchemaIdentifier",
              observedIdentifier,
              "/" + group.record.name + "/observingSystems/" + metadataName);
          if (!result || observedIdentifier != schema->schema.identifier)
            return failure(WVCheckpointStatusCode::appendConflict,
                           "Observation schema identity changed.",
                           "/" + group.record.name + "/observingSystems/" +
                               metadataName);
          unsigned int observedVersion = 0;
          result = detail::checkedNetCDF(
              nc_get_att_uint(metadata, NC_GLOBAL,
                              "portableObservationSchemaVersion",
                              &observedVersion),
              "Observation-schema version read",
              "/" + group.record.name + "/observingSystems/" + metadataName);
          if (!result || observedVersion != schema->schema.version)
            return failure(WVCheckpointStatusCode::appendConflict,
                           "Observation schema version changed.",
                           "/" + group.record.name + "/observingSystems/" +
                               metadataName);
        }
      }
      result = detail::checkedNetCDF(nc_inq_varid(group.id, "t", &group.timeId),
                                     "Time-variable lookup",
                                     "/" + group.record.name + "/t");
      if (!result)
        return result;
      if (!group.record.schedule.typeIdentifier.empty()) {
        result = detail::checkedNetCDF(
            nc_inq_varid(group.id, "portableScheduleOrdinal",
                         &group.scheduleOrdinalId),
            "Schedule-ordinal variable lookup", "/" + group.record.name);
        if (!result)
          return result;
        result = detail::checkedNetCDF(
            nc_inq_varid(group.id, "portableScheduleCursor",
                         &group.scheduleCursorId),
            "Schedule-cursor variable lookup", "/" + group.record.name);
        if (!result)
          return result;
      }
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
                       variable.values.begin(),
                       [](double first, double second) {
                         const double scale =
                             std::max({1.0, std::abs(first), std::abs(second)});
                         return std::abs(first - second) <= 1e-12 * scale;
                       });
        if (!coordinatesMatch)
          return failure(WVCheckpointStatusCode::appendConflict,
                         "Static observer coordinates changed.",
                         "/" + group.record.name + "/" + variable.name);
      }
      for (auto &axisDefinition : group.unlimitedAxes) {
        result = detail::checkedNetCDF(
            nc_inq_dimid(group.id, axisDefinition.name.c_str(),
                         &axisDefinition.dimensionId),
            "Observation-axis lookup",
            "/" + group.record.name + "/" + axisDefinition.name);
        if (!result)
          return result;
        const std::string progressName =
            "portableCommitted_" + axisDefinition.name;
        result = detail::checkedNetCDF(
            nc_inq_varid(group.id, progressName.c_str(),
                         &axisDefinition.progressVariableId),
            "Observation-axis progress lookup",
            "/" + group.record.name + "/" + progressName);
        if (!result)
          return result;
      }
      for (auto &variable : group.derivedVariables) {
        if (variable.specification.scalarType ==
            WVObservationScalarType::complex64) {
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
          nc_type observedType = NC_NAT;
          auto contract = detail::checkedNetCDF(
              nc_inq_vartype(group.id, variableId, &observedType),
              "Observer-variable type inspection",
              "/" + group.record.name + "/" + variableName);
          if (!contract)
            return contract;
          const nc_type expectedType =
              variable.specification.scalarType ==
                          WVObservationScalarType::integer64
                      ? NC_INT64
                      : variable.specification.scalarType ==
                                WVObservationScalarType::boolean8
                            ? NC_UBYTE
                            : variable.specification.scalarType ==
                                      WVObservationScalarType::text
                                  ? NC_STRING
                                  : NC_DOUBLE;
          if (observedType != expectedType)
            return failure(WVCheckpointStatusCode::appendConflict,
                           "Observer-variable scalar type changed.",
                           "/" + group.record.name + "/" + variableName);
          int rank = 0;
          contract = detail::checkedNetCDF(
              nc_inq_varndims(group.id, variableId, &rank),
              "Observer-variable rank inspection",
              "/" + group.record.name + "/" + variableName);
          if (!contract)
            return contract;
          const std::size_t expectedRank =
              variable.axes.size() +
              (variable.specification.layout ==
                       WVObservationValueLayout::record
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
          std::vector<const WVObservationAxis *> expectedAxes;
          if (variable.specification.layout ==
              WVObservationValueLayout::record) {
            expectedNames.push_back("t");
            expectedAxes.push_back(nullptr);
          }
          for (std::size_t reverse = variable.axes.size(); reverse > 0;
               --reverse) {
            expectedNames.push_back(variable.axes[reverse - 1].name);
            expectedAxes.push_back(&variable.axes[reverse - 1]);
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
                (expectedAxes[index] != nullptr &&
                 expectedAxes[index]->kind == WVObservationAxisKind::fixed &&
                 expectedAxes[index]->extent != length))
              return failure(WVCheckpointStatusCode::appendConflict,
                             "Observer-variable dimensions changed.",
                             "/" + group.record.name + "/" + variableName);
          }
          const auto requireAttribute = [&](const std::string &name,
                                            const std::string &expected,
                                            bool optional = false) {
            if (expected.empty())
              return WVCheckpointStatus::ok();
            nc_type type = NC_NAT;
            std::size_t length = 0;
            const int inquiry =
                nc_inq_att(group.id, variableId, name.c_str(), &type, &length);
            if (inquiry == NC_ENOTATT && optional)
              return WVCheckpointStatus::ok();
            auto attributeStatus = detail::checkedNetCDF(
                inquiry, "Observer-variable attribute inspection",
                "/" + group.record.name + "/" + variableName + "/@" + name);
            if (!attributeStatus)
              return attributeStatus;
            std::string observed;
            if (type == NC_CHAR) {
              observed.assign(length, '\0');
              attributeStatus = detail::checkedNetCDF(
                  nc_get_att_text(group.id, variableId, name.c_str(),
                                  observed.data()),
                  "Observer-variable attribute read",
                  "/" + group.record.name + "/" + variableName + "/@" + name);
              if (!attributeStatus)
                return attributeStatus;
            } else if (length == 1 && (expected == "0" || expected == "1")) {
              double numeric = 0.0;
              attributeStatus = detail::checkedNetCDF(
                  nc_get_att_double(group.id, variableId, name.c_str(),
                                    &numeric),
                  "Observer-variable logical-attribute read",
                  "/" + group.record.name + "/" + variableName + "/@" + name);
              if (!attributeStatus)
                return attributeStatus;
              observed = numeric == 0.0 ? "0" : numeric == 1.0 ? "1" : "";
            } else {
              return failure(WVCheckpointStatusCode::appendConflict,
                             "Observer-variable metadata type changed.",
                             "/" + group.record.name + "/" + variableName +
                                 "/@" + name);
            }
            if (observed != expected)
              return failure(
                  WVCheckpointStatusCode::appendConflict,
                  "Observer-variable metadata changed: expected '" + expected +
                      "' but observed '" + observed + "'.",
                  "/" + group.record.name + "/" + variableName + "/@" + name);
            return WVCheckpointStatus::ok();
          };
          contract = requireAttribute("units", variable.specification.units);
          if (contract)
            contract = requireAttribute("long_name",
                                        variable.specification.description);
          for (const auto &attribute : variable.specification.attributes) {
            if (!contract)
              break;
            contract = requireAttribute(attribute.name, attribute.value,
                                        attribute.name != "isParticle" &&
                                            attribute.name != "isTracer");
          }
          if (!contract)
            return contract;
          if ((variable.specification.layout ==
                   WVObservationValueLayout::initialValue ||
               variable.specification.layout ==
                   WVObservationValueLayout::staticValue) &&
              (variable.specification.scalarType ==
                   WVObservationScalarType::real64 ||
               variable.specification.scalarType ==
                   WVObservationScalarType::complex64)) {
            std::size_t count = 1;
            for (const auto &axis : variable.axes)
              count *= axis.extent;
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
                                   variable.specification.scalarType ==
                                           WVObservationScalarType::complex64
                                       ? variable.specification.name + "_real"
                                       : variable.specification.name);
        if (result &&
            variable.specification.scalarType ==
                WVObservationScalarType::complex64)
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
      if (length > 0) {
        std::vector<double> times(length);
        result = detail::checkedNetCDF(
            nc_get_var_double(group.id, group.timeId, times.data()),
            "Output-time read", "/" + group.record.name + "/t");
        if (!result)
          return result;
        const auto firstUncommitted =
            std::find(times.begin(), times.end(), NC_FILL_DOUBLE);
        if (firstUncommitted != times.end() &&
            std::any_of(firstUncommitted, times.end(), [](double value) {
              return value != NC_FILL_DOUBLE;
            }))
          return failure(WVCheckpointStatusCode::incompleteRecord,
                         "Output time commit markers contain an internal gap.",
                         "/" + group.record.name + "/t");
        length = static_cast<std::size_t>(
            std::distance(times.begin(), firstUncommitted));
        times.resize(length);
        group.recordCount = length;
        for (auto &axisDefinition : group.unlimitedAxes) {
          if (length == 0)
            continue;
          const std::size_t position[] = {length - 1};
          long long committedCount = -1;
          result = detail::checkedNetCDF(
              nc_get_var1_longlong(group.id,
                                   axisDefinition.progressVariableId,
                                   position, &committedCount),
              "Observation-axis progress read",
              "/" + group.record.name + "/portableCommitted_" +
                  axisDefinition.name);
          if (!result)
            return result;
          std::size_t physicalAxisLength = 0;
          result = detail::checkedNetCDF(
              nc_inq_dimlen(group.id, axisDefinition.dimensionId,
                            &physicalAxisLength),
              "Observation-axis length inspection",
              "/" + group.record.name + "/" + axisDefinition.name);
          if (!result)
            return result;
          if (committedCount < 0 ||
              static_cast<std::uint64_t>(committedCount) > physicalAxisLength)
            return failure(WVCheckpointStatusCode::incompleteRecord,
                           "Committed observation-axis count is invalid.",
                           "/" + group.record.name + "/" +
                               axisDefinition.name);
          axisDefinition.committedCount =
              static_cast<std::size_t>(committedCount);
        }
        if (group.record.schedule.typeIdentifier.empty()) {
          for (std::size_t timeIndex = 0; timeIndex < times.size();
               ++timeIndex) {
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
        } else {
          std::vector<long long> ordinals(length);
          result = detail::checkedNetCDF(
              nc_get_var_longlong(group.id, group.scheduleOrdinalId,
                                  ordinals.data()),
              "Schedule-ordinal read", "/" + group.record.name);
          if (!result)
            return result;
          for (std::size_t timeIndex = 0; timeIndex < times.size();
               ++timeIndex) {
            if (!std::isfinite(times[timeIndex]) || ordinals[timeIndex] < 0 ||
                (timeIndex > 0 &&
                 (!(times[timeIndex] > times[timeIndex - 1]) ||
                  ordinals[timeIndex] <= ordinals[timeIndex - 1])))
              return failure(WVCheckpointStatusCode::appendConflict,
                             "Existing algorithmic output history is not "
                             "strictly monotone.",
                             "/" + group.record.name);
            const std::size_t position[] = {timeIndex};
            char *cursorText = nullptr;
            result = detail::checkedNetCDF(
                nc_get_var1_string(group.id, group.scheduleCursorId, position,
                                   &cursorText),
                "Schedule-cursor read", "/" + group.record.name);
            if (!result)
              return result;
            const std::string encoded = cursorText == nullptr ? "" : cursorText;
            if (cursorText != nullptr)
              nc_free_string(1, &cursorText);
            std::vector<std::uint8_t> cursorBytes;
            if (!hexDecode(encoded, cursorBytes) ||
                cursorBytes.size() > WVMaximumOutputScheduleCursorBytes)
              return failure(WVCheckpointStatusCode::appendConflict,
                             "Existing algorithmic output cursor is malformed.",
                             "/" + group.record.name);
            const auto decoded = decodePortableTypedRecord(
                cursorBytes, group.scheduleCursor,
                {WVMaximumOutputScheduleCursorBytes, true, false});
            if (!decoded)
              return failure(WVCheckpointStatusCode::appendConflict,
                             decoded.message, "/" + group.record.name);
            group.committedOrdinal =
                static_cast<WVOutputScheduleOrdinal>(ordinals[timeIndex]);
          }
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
      } else {
        group.recordCount = 0;
      }
    }
    return WVCheckpointStatus::ok();
  }

  void rebuildProgress() {
    progress.clear();
    for (const auto &file : files)
      for (const auto &group : file.groups) {
        progress.push_back({file.record.identifier, group.record.identifier,
                            group.committedOrdinal});
        progress.back().scheduleCursor = group.scheduleCursor;
      }
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
                 group.scheduleCursor.persistentBytes() -
                 sizeof(WVPortableTypedRecord) +
                 group.dynamicVariables.capacity() * sizeof(DynamicVariable) +
                 group.derivedVariables.capacity() * sizeof(Variable) +
                 group.staticVariables.capacity() * sizeof(StaticVariable) +
                 group.observerSchemas.capacity() * sizeof(ObserverSchema) +
                 group.unlimitedAxes.capacity() * sizeof(UnlimitedAxis);
        for (const auto &dynamic : group.dynamicVariables)
          bytes += dynamic.blockIdentifier.capacity() + dynamic.name.capacity();
        for (const auto &variable : group.derivedVariables)
          bytes += variable.observerIdentifier.capacity() +
                   variable.schemaIdentifier.capacity() +
                   variable.specification.identifier.capacity() +
                   variable.specification.name.capacity() +
                   variable.specification.units.capacity() +
                   variable.specification.description.capacity() +
                   variable.specification.dimensionIdentifiers.capacity() *
                       sizeof(std::string) +
                   variable.axes.capacity() * sizeof(WVObservationAxis) +
                   variable.specification.attributes.capacity() *
                       sizeof(WVObservationAttribute);
        for (const auto &variable : group.derivedVariables) {
          for (const auto &name : variable.specification.dimensionIdentifiers)
            bytes += name.capacity();
          for (const auto &axisDefinition : variable.axes)
            bytes += axisDefinition.identifier.capacity() +
                     axisDefinition.name.capacity();
          for (const auto &attribute : variable.specification.attributes)
            bytes += attribute.name.capacity() + attribute.value.capacity();
        }
        for (const auto &axisDefinition : group.unlimitedAxes)
          bytes += axisDefinition.name.capacity();
        for (const auto &variable : group.staticVariables)
          bytes += variable.name.capacity() +
                   variable.values.capacity() * sizeof(double);
      }
    }
    for (const auto &item : progress)
      bytes +=
          item.fileIdentifier.capacity() + item.groupIdentifier.capacity() +
          item.scheduleCursor.persistentBytes() - sizeof(WVPortableTypedRecord);
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
          const auto observerBehavior = observerImplementation(*recordPointer);
          if (observerBehavior->recordsMovingParticles() ||
              observerBehavior->recordsTracerState()) {
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
            if (observerBehavior->recordsMovingParticles() &&
                recordPointer->isXYOnly && !recordPointer->z.empty())
              group.dynamicVariables.push_back({{},
                                                recordPointer->name + "_z",
                                                WVStateScalarType::real64,
                                                recordPointer->z.size(),
                                                recordPointer->z,
                                                -1,
                                                -1});
          } else if (observerBehavior->recordsFixedProfiles()) {
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
            WVObservationSchema schema;
            const auto sourceStatus = sampleSource->observationSchema(
                *recordPointer, schema);
            if (!sourceStatus)
              return failure(WVCheckpointStatusCode::unsupportedObserver,
                             sourceStatus.message, file.destination.string());
            const auto schemaStatus = validateObservationSchema(schema);
            if (!schemaStatus)
              return failure(WVCheckpointStatusCode::schemaMismatch,
                             schemaStatus.message, file.destination.string());
            for (const auto &specification : schema.variables) {
              const bool canonicalCoefficient =
                  groupRecord.containsCompleteCoefficientRestart &&
                  coefficientMetadata(specification.name) != nullptr;
              if (!canonicalCoefficient) {
                const auto existing = std::find_if(
                    group.derivedVariables.begin(),
                    group.derivedVariables.end(), [&](const auto &variable) {
                      return variable.specification.name == specification.name;
                    });
                if (existing == group.derivedVariables.end()) {
                  Variable variable;
                  variable.observerIdentifier = identifier;
                  variable.schemaIdentifier = schema.identifier;
                  variable.schemaVersion = schema.version;
                  variable.specification = specification;
                  for (const auto &axisIdentifier :
                       specification.dimensionIdentifiers) {
                    const auto *axisDefinition = axis(schema, axisIdentifier);
                    if (axisDefinition == nullptr)
                      return failure(
                          WVCheckpointStatusCode::schemaMismatch,
                          "Observation variable references an unknown axis.",
                          file.destination.string());
                    variable.axes.push_back(*axisDefinition);
                    if (axisDefinition->kind ==
                            WVObservationAxisKind::unlimited &&
                        std::none_of(
                            group.unlimitedAxes.begin(),
                            group.unlimitedAxes.end(), [&](const auto &item) {
                              return item.name == axisDefinition->name;
                            })) {
                      UnlimitedAxis unlimited;
                      unlimited.name = axisDefinition->name;
                      group.unlimitedAxes.push_back(std::move(unlimited));
                    }
                  }
                  group.derivedVariables.push_back(std::move(variable));
                } else if (existing->specification.scalarType !=
                               specification.scalarType ||
                           existing->specification.layout !=
                               specification.layout ||
                           existing->specification.dimensionIdentifiers !=
                               specification.dimensionIdentifiers)
                  return failure(
                      WVCheckpointStatusCode::appendConflict,
                      "Observers declare incompatible variables with the same "
                      "name.",
                      file.destination.string());
              }
            }
            group.observerSchemas.push_back(
                {identifier, std::move(schema)});
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
    std::vector<WVObservationBatch> observationBatches;
    observationBatches.reserve(group.observerSchemas.size());
    std::map<std::string, std::size_t> unlimitedAxisIncrements;
    for (const auto &observerSchema : group.observerSchemas) {
      const auto *record = observer(observerSchema.observerIdentifier);
      WVObservationBatch batch;
      const auto sourceStatus = sampleSource->observationBatch(*record, batch);
      if (!sourceStatus)
        return failure(WVCheckpointStatusCode::unsupportedObserver,
                       sourceStatus.message,
                       "/" + group.record.name);
      const auto batchStatus =
          validateObservationBatch(observerSchema.schema, batch);
      if (!batchStatus)
        return failure(WVCheckpointStatusCode::shapeMismatch,
                       batchStatus.message, "/" + group.record.name);
      const auto batchMetrics = batch.metrics();
      metrics.batchRetainedStorageBytes = std::max(
          metrics.batchRetainedStorageBytes,
          batchMetrics.retainedStorageBytes);
      metrics.batchMaximumLiveBytes =
          std::max(metrics.batchMaximumLiveBytes, batchMetrics.liveBytes);
      for (const auto &value : batch.values) {
        const auto declared = std::find_if(
            observerSchema.schema.variables.begin(),
            observerSchema.schema.variables.end(), [&](const auto &candidate) {
              return candidate.identifier == value.variableIdentifier;
            });
        if (declared == observerSchema.schema.variables.end())
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "Observation batch contains an undeclared value.",
                         "/" + group.record.name);
        for (std::size_t dimension = 0;
             dimension < declared->dimensionIdentifiers.size(); ++dimension) {
          const auto *axisDefinition = axis(
              observerSchema.schema,
              declared->dimensionIdentifiers[dimension]);
          if (axisDefinition->kind != WVObservationAxisKind::unlimited)
            continue;
          const auto inserted = unlimitedAxisIncrements.emplace(
              axisDefinition->name, value.extents[dimension]);
          if (!inserted.second &&
              inserted.first->second != value.extents[dimension])
            return failure(
                WVCheckpointStatusCode::shapeMismatch,
                "Observation batches disagree on a shared unlimited axis.",
                "/" + group.record.name + "/" + axisDefinition->name);
        }
      }
      observationBatches.push_back(std::move(batch));
    }
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
      auto result = writeRealSlab(group.id, dynamic.realId, index, values,
                                  dynamic.elementCount,
                                  "/" + group.record.name + "/" + dynamic.name);
      if (!result)
        return result;
      ++delivery.writeCount;
      delivery.writtenBytes += dynamic.elementCount * sizeof(double);
    }
    for (std::size_t schemaIndex = 0;
         schemaIndex < group.observerSchemas.size(); ++schemaIndex) {
      const auto &observerSchema = group.observerSchemas[schemaIndex];
      const auto &batch = observationBatches[schemaIndex];
      for (const auto &value : batch.values) {
        const auto variable = std::find_if(
            group.derivedVariables.begin(), group.derivedVariables.end(),
            [&](const auto &candidate) {
              return candidate.observerIdentifier ==
                         observerSchema.observerIdentifier &&
                     candidate.specification.identifier ==
                         value.variableIdentifier;
            });
        if (variable == group.derivedVariables.end()) {
          const auto declared = std::find_if(
              observerSchema.schema.variables.begin(),
              observerSchema.schema.variables.end(), [&](const auto &item) {
                return item.identifier == value.variableIdentifier;
              });
          if (declared != observerSchema.schema.variables.end() &&
              group.record.containsCompleteCoefficientRestart &&
              coefficientMetadata(declared->name) != nullptr)
            continue;
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "Observation value has no persistence variable.",
                         "/" + group.record.name);
        }
        auto result = writeObservationValue(
            group, *variable, value, index,
            "/" + group.record.name + "/" + variable->specification.name);
        if (!result)
          return result;
        if (value.elementCount() > 0)
          delivery.writeCount +=
              value.scalarType == WVObservationScalarType::complex64 ? 2 : 1;
        delivery.writtenBytes += value.liveBytes();
      }
    }
    const std::size_t start[] = {index};
    const std::size_t count[] = {1};
    for (const auto &axisDefinition : group.unlimitedAxes) {
      const auto increment = unlimitedAxisIncrements.find(axisDefinition.name);
      const std::size_t value =
          axisDefinition.committedCount +
          (increment == unlimitedAxisIncrements.end() ? 0 : increment->second);
      if (value > static_cast<std::size_t>(
                      std::numeric_limits<long long>::max()) ||
          value < axisDefinition.committedCount)
        return failure(WVCheckpointStatusCode::invalidValue,
                       "Committed observation-axis count overflowed.",
                       "/" + group.record.name + "/" + axisDefinition.name);
      const auto persisted = static_cast<long long>(value);
      auto progressResult = detail::checkedNetCDF(
          nc_put_var1_longlong(group.id, axisDefinition.progressVariableId,
                               start, &persisted),
          "Observation-axis progress write",
          "/" + group.record.name + "/portableCommitted_" +
              axisDefinition.name);
      if (!progressResult)
        return progressResult;
      ++delivery.writeCount;
      delivery.writtenBytes += sizeof(std::int64_t);
    }
    if (!group.record.schedule.typeIdentifier.empty()) {
      if (route.proposedScheduleCursor == nullptr)
        return failure(WVCheckpointStatusCode::invalidValue,
                       "Algorithmic output route has no proposed cursor.",
                       "/" + group.record.name);
      std::vector<std::uint8_t> cursorBytes;
      auto cursorStatus =
          encodePortableTypedRecord(*route.proposedScheduleCursor, cursorBytes);
      if (!cursorStatus)
        return failure(WVCheckpointStatusCode::invalidValue,
                       cursorStatus.message, "/" + group.record.name);
      if (cursorBytes.size() > WVMaximumOutputScheduleCursorBytes)
        return failure(WVCheckpointStatusCode::invalidValue,
                       "Algorithmic output cursor exceeds 4 KiB.",
                       "/" + group.record.name);
      const auto cursorHex = hexEncode(cursorBytes);
      const char *cursorText = cursorHex.c_str();
      const auto ordinal = static_cast<long long>(route.scheduleOrdinal);
      auto scheduleResult = detail::checkedNetCDF(
          nc_put_var1_longlong(group.id, group.scheduleOrdinalId, start,
                               &ordinal),
          "Schedule-ordinal write", "/" + group.record.name);
      if (!scheduleResult)
        return scheduleResult;
      scheduleResult = detail::checkedNetCDF(
          nc_put_var1_string(group.id, group.scheduleCursorId, start,
                             &cursorText),
          "Schedule-cursor write", "/" + group.record.name);
      if (!scheduleResult)
        return scheduleResult;
      delivery.writeCount += 2;
      delivery.writtenBytes += sizeof(std::int64_t) + cursorHex.size();
    }
    auto result = detail::checkedNetCDF(
        nc_put_vara_double(group.id, group.timeId, start, count,
                           &event.scheduledTime),
        "Output-time commit", "/" + group.record.name + "/t");
    if (!result)
      return result;
    metrics.payloadWriteSeconds +=
        std::chrono::duration<double>(std::chrono::steady_clock::now() -
                                      payloadStarted)
            .count();
    const auto synchronizationStarted = std::chrono::steady_clock::now();
    result = detail::checkedNetCDF(nc_sync(file.id), "Output-route sync",
                                   file.destination.string());
    if (!result)
      return result;
    metrics.synchronizationSeconds +=
        std::chrono::duration<double>(std::chrono::steady_clock::now() -
                                      synchronizationStarted)
            .count();
    ++group.recordCount;
    for (auto &axisDefinition : group.unlimitedAxes) {
      const auto increment = unlimitedAxisIncrements.find(axisDefinition.name);
      if (increment != unlimitedAxisIncrements.end())
        axisDefinition.committedCount += increment->second;
    }
    group.committedOrdinal = route.scheduleOrdinal;
    if (route.proposedScheduleCursor != nullptr)
      group.scheduleCursor = *route.proposedScheduleCursor;
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

WVCheckpointStatus WVModelOutputNetCDFSink::replaceExisting(
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
    result = candidate->validateDestinations(true);
    if (!result)
      return result;
    result = candidate->stageFiles();
    if (!result)
      return result;
    result = candidate->replaceStagedFiles();
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
                   "Output replacement allocation failed.", "/");
  } catch (const std::exception &exception) {
    return failure(
        WVCheckpointStatusCode::writeFailure,
        "Output replacement failed: " + std::string(exception.what()), "/");
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

WVKernelStatus WVModelOutputNetCDFSink::preflight(const WVOutputPlan &plan) {
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
  for (std::size_t groupIndex = 0; groupIndex < plan.groupCount();
       ++groupIndex) {
    const auto route = plan.groupRoute(groupIndex);
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
    const auto &progress = plan.initialProgress()[groupIndex];
    if (progress.fileIdentifier != file.record.identifier ||
        progress.groupIdentifier != group.record.identifier ||
        progress.committedOrdinal != group.committedOrdinal)
      return {WVKernelStatusCode::invalidConfiguration,
              "Output plan is incompatible with committed NetCDF progress."};
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
