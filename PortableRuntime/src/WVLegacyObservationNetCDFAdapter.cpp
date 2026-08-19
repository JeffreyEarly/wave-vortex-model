#include "WVLegacyObservationNetCDFAdapter.hpp"
#include "WVModelOutputNetCDFSchema.hpp"
#include "WVNetCDF.hpp"
#include "WVObserverAdapter.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <limits>
#include <map>
#include <netcdf.h>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace wavevortex::runtime {
namespace {

WVCheckpointStatus failure(WVCheckpointStatusCode code, std::string message,
                           std::string location) {
  return {code, std::move(message), std::move(location)};
}

WVCheckpointStatus optionalTextAttribute(int group, const char *name,
                                         std::string &value, bool &present,
                                         const std::string &path) {
  nc_type type = NC_NAT;
  std::size_t length = 0;
  const int inquiry = nc_inq_att(group, NC_GLOBAL, name, &type, &length);
  if (inquiry == NC_ENOTATT) {
    present = false;
    value.clear();
    return WVCheckpointStatus::ok();
  }
  if (inquiry != NC_NOERR)
    return detail::netcdfFailure(inquiry, "Attribute inspection",
                                 path + "/@" + name);
  present = true;
  return detail::readTextAttribute(group, name, value, path);
}

WVCheckpointStatus stringListAttribute(int group, const char *name,
                                       std::vector<std::string> &values,
                                       bool &present, const std::string &path) {
  nc_type type = NC_NAT;
  std::size_t length = 0;
  const int inquiry = nc_inq_att(group, NC_GLOBAL, name, &type, &length);
  if (inquiry == NC_ENOTATT) {
    present = false;
    values.clear();
    return WVCheckpointStatus::ok();
  }
  if (inquiry != NC_NOERR)
    return detail::netcdfFailure(inquiry, "String-list inspection",
                                 path + "/@" + name);
  present = true;
  values.clear();
  if (type == NC_STRING) {
    std::vector<char *> raw(length, nullptr);
    const int result = nc_get_att_string(group, NC_GLOBAL, name, raw.data());
    if (result != NC_NOERR)
      return detail::netcdfFailure(result, "String-list read",
                                   path + "/@" + name);
    values.reserve(length);
    for (const auto *entry : raw)
      values.emplace_back(entry == nullptr ? "" : entry);
    nc_free_string(length, raw.data());
    return WVCheckpointStatus::ok();
  }
  if (type == NC_CHAR) {
    std::string raw(length, '\0');
    const int result = nc_get_att_text(group, NC_GLOBAL, name, raw.data());
    if (result != NC_NOERR)
      return detail::netcdfFailure(result, "String-list read",
                                   path + "/@" + name);
    values.push_back(std::move(raw));
    return WVCheckpointStatus::ok();
  }
  return failure(WVCheckpointStatusCode::typeMismatch,
                 "Observer field-name attributes must contain strings.",
                 path + "/@" + name);
}

std::string portableIdentifier(std::string value) {
  for (auto &character : value) {
    const bool valid = (character >= 'a' && character <= 'z') ||
                       (character >= 'A' && character <= 'Z') ||
                       (character >= '0' && character <= '9') ||
                       character == '-' || character == '_' || character == '.';
    if (!valid)
      character = '-';
  }
  if (value.empty())
    value = "unnamed";
  return value;
}

bool sameObserverConfiguration(const WVObserverRecord &left,
                               const WVObserverRecord &right) {
  return left.name == right.name &&
         left.typeIdentifier == right.typeIdentifier &&
         left.contractVersion == right.contractVersion &&
         left.stateBlockIdentifiers == right.stateBlockIdentifiers &&
         left.fieldNames == right.fieldNames && left.x == right.x &&
         left.y == right.y && left.z == right.z &&
         left.isXYOnly == right.isXYOnly &&
         left.shouldAntialias == right.shouldAntialias &&
         left.advectionInterpolation == right.advectionInterpolation &&
         left.trackedFieldInterpolation == right.trackedFieldInterpolation &&
         left.horizontalAbsoluteTolerance ==
             right.horizontalAbsoluteTolerance &&
         left.verticalAbsoluteTolerance == right.verticalAbsoluteTolerance &&
         left.outputScale == right.outputScale &&
         left.outputOffset == right.outputOffset;
}

bool sameRestartValues(const std::vector<double> &left,
                       const std::vector<double> &right) {
  if (left.size() != right.size())
    return false;
  for (std::size_t index = 0; index < left.size(); ++index) {
    const double scale =
        std::max({1.0, std::abs(left[index]), std::abs(right[index])});
    if (!std::isfinite(left[index]) || !std::isfinite(right[index]) ||
        std::abs(left[index] - right[index]) >
            32 * std::numeric_limits<double>::epsilon() * scale)
      return false;
  }
  return true;
}

WVCheckpointStatus variableShape(int group, const std::string &name,
                                 std::vector<std::string> &dimensionNames,
                                 std::vector<std::size_t> &dimensionLengths,
                                 const std::string &path) {
  int variable = -1;
  auto result =
      detail::checkedNetCDF(nc_inq_varid(group, name.c_str(), &variable),
                            "Variable lookup", path + "/" + name);
  if (!result)
    return result;
  int count = 0;
  result = detail::checkedNetCDF(nc_inq_varndims(group, variable, &count),
                                 "Variable-rank inspection", path + "/" + name);
  if (!result)
    return result;
  std::vector<int> dimensions(static_cast<std::size_t>(count));
  result =
      detail::checkedNetCDF(nc_inq_vardimid(group, variable, dimensions.data()),
                            "Variable-dimension inspection", path + "/" + name);
  if (!result)
    return result;
  dimensionNames.clear();
  dimensionLengths.clear();
  for (const int dimension : dimensions) {
    char rawName[NC_MAX_NAME + 1] = {};
    std::size_t length = 0;
    result = detail::checkedNetCDF(
        nc_inq_dim(group, dimension, rawName, &length),
        "Variable-dimension inspection", path + "/" + name);
    if (!result)
      return result;
    dimensionNames.emplace_back(rawName);
    dimensionLengths.push_back(length);
  }
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus readLatestRealSlab(int group, const std::string &name,
                                      std::size_t recordIndex,
                                      std::vector<double> &values,
                                      const std::string &path) {
  int variable = -1;
  auto result =
      detail::checkedNetCDF(nc_inq_varid(group, name.c_str(), &variable),
                            "Variable lookup", path + "/" + name);
  if (!result)
    return result;
  std::vector<std::string> dimensionNames;
  std::vector<std::size_t> dimensions;
  result = variableShape(group, name, dimensionNames, dimensions, path);
  if (!result)
    return result;
  if (dimensions.empty() || dimensionNames.front() != "t")
    return failure(WVCheckpointStatusCode::shapeMismatch,
                   "Dynamic observer values must begin with time.",
                   path + "/" + name);
  std::vector<std::size_t> start(dimensions.size(), 0);
  std::vector<std::size_t> count = dimensions;
  start.front() = recordIndex;
  count.front() = 1;
  std::size_t elementCount = 1;
  for (std::size_t index = 1; index < count.size(); ++index)
    elementCount *= count[index];
  values.resize(elementCount);
  return detail::checkedNetCDF(nc_get_vara_double(group, variable, start.data(),
                                                  count.data(), values.data()),
                               "Dynamic observer-state read",
                               path + "/" + name);
}

WVCheckpointStatus recordAtTime(int group, double selectedTime,
                                std::size_t &recordIndex, bool &found,
                                const std::string &path) {
  std::size_t count = 0;
  auto result = detail::dimensionLength(group, "t", count, path);
  if (!result)
    return result;
  int variable = -1;
  result = detail::checkedNetCDF(nc_inq_varid(group, "t", &variable),
                                 "Output-time lookup", path + "/t");
  if (!result)
    return result;
  std::vector<double> times(count);
  result =
      detail::checkedNetCDF(nc_get_var_double(group, variable, times.data()),
                            "Output-time read", path + "/t");
  if (!result)
    return result;
  found = false;
  for (std::size_t index = 0; index < times.size(); ++index) {
    const double scale =
        std::max({1.0, std::abs(times[index]), std::abs(selectedTime)});
    if (std::abs(times[index] - selectedTime) <=
        8 * std::numeric_limits<double>::epsilon() * scale) {
      if (found)
        return failure(WVCheckpointStatusCode::ambiguousState,
                       "An output group contains the selected restart time "
                       "more than once.",
                       path + "/t");
      found = true;
      recordIndex = index;
    }
  }
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus
readObserverStateAtTime(const std::string &filePath,
                        const WVOutputGroupRecord &groupRecord,
                        const WVObserverRecord &observer, double selectedTime,
                        std::vector<std::vector<double>> &values, bool &found) {
  detail::WVNetCDFFile file;
  auto result = detail::WVNetCDFFile::openReadOnly(filePath, file);
  if (!result)
    return result;
  int group = -1;
  const std::string groupPath = "/" + groupRecord.name;
  result = detail::checkedNetCDF(
      nc_inq_ncid(file.id(), groupRecord.name.c_str(), &group),
      "Observer restart-group lookup", groupPath);
  if (!result)
    return result;
  std::size_t recordIndex = 0;
  result = recordAtTime(group, selectedTime, recordIndex, found, groupPath);
  if (!result || !found)
    return result;

  const auto implementation = detail::observerImplementation(
      observer.typeIdentifier, observer.contractVersion);
  if (!implementation)
    return failure(WVCheckpointStatusCode::unsupportedObserver,
                   "Dynamic observer state uses an unsupported observer.",
                   groupPath);
  values.clear();
  if (implementation->recordsMovingParticles()) {
    const auto channels = detail::movingFieldChannels(observer);
    values.resize(channels.size());
    for (std::size_t index = 0; index < channels.size(); ++index) {
      result = readLatestRealSlab(
          group,
          observer.name + "_" + detail::movingFieldChannelName(channels[index]),
          recordIndex, values[index], groupPath);
      if (!result)
        return result;
    }
    if (observer.isXYOnly && !observer.z.empty()) {
      values.emplace_back();
      result = readLatestRealSlab(group, observer.name + "_z", recordIndex,
                                  values.back(), groupPath);
      if (!result)
        return result;
    }
  } else if (implementation->recordsTracerState()) {
    values.resize(1);
    result = readLatestRealSlab(group, observer.name, recordIndex, values[0],
                                groupPath);
    if (!result)
      return result;
  } else {
    found = false;
  }
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus readWholeDoubleVariable(int group, const std::string &name,
                                           std::vector<double> &values,
                                           const std::string &path) {
  int variable = -1;
  auto result =
      detail::checkedNetCDF(nc_inq_varid(group, name.c_str(), &variable),
                            "Variable lookup", path + "/" + name);
  if (!result)
    return result;
  std::vector<std::string> names;
  std::vector<std::size_t> dimensions;
  result = variableShape(group, name, names, dimensions, path);
  if (!result)
    return result;
  std::size_t count = 1;
  for (const auto dimension : dimensions)
    count *= dimension;
  values.resize(count);
  return detail::checkedNetCDF(
      nc_get_var_double(group, variable, values.data()), "Variable read",
      path + "/" + name);
}

WVCheckpointStatus mergeStateBlock(WVPortableObserverRecord &record,
                                   const WVStateBlockRecord &block) {
  const auto found =
      std::find_if(record.stateBlocks.begin(), record.stateBlocks.end(),
                   [&](const auto &candidate) {
                     return candidate.identifier == block.identifier;
                   });
  if (found == record.stateBlocks.end()) {
    record.stateBlocks.push_back(block);
    return WVCheckpointStatus::ok();
  }
  if (found->scalarType != block.scalarType ||
      found->dimensions != block.dimensions ||
      found->toleranceKind != block.toleranceKind ||
      found->absoluteTolerance != block.absoluteTolerance ||
      found->ownership != block.ownership ||
      found->restartRequirement != block.restartRequirement)
    return failure(WVCheckpointStatusCode::schemaMismatch,
                   "Shared observer state-block definitions conflict.",
                   "/observingSystems");
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus mergeObserver(WVPortableObserverRecord &record,
                                 WVObserverRecord observer) {
  const auto found =
      std::find_if(record.observers.begin(), record.observers.end(),
                   [&](const auto &candidate) {
                     return candidate.identifier == observer.identifier;
                   });
  if (found == record.observers.end()) {
    record.observers.push_back(std::move(observer));
    return WVCheckpointStatus::ok();
  }
  if (!sameObserverConfiguration(*found, observer))
    return failure(WVCheckpointStatusCode::schemaMismatch,
                   "Shared observer metadata conflicts across output groups.",
                   "/observingSystems");
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus parseObserver(int outputGroup, int metadataGroup,
                                 const std::string &outputPath,
                                 WVPortableObserverRecord &portable,
                                 std::string &identifier) {
  std::string className;
  auto result = detail::readTextAttribute(metadataGroup, "AnnotatedClass",
                                          className, outputPath);
  if (!result)
    return result;
  const auto implementation =
      detail::observerImplementation(className, WVPortablePairContractVersion);
  WVObserverRecord observer;
  observer.typeIdentifier = className;
  bool present = false;
  if (!implementation) {
    std::string schemaIdentifier;
    result = optionalTextAttribute(metadataGroup,
                                   "portableObservationSchemaIdentifier",
                                   schemaIdentifier, present, outputPath);
    if (!result)
      return result;
    if (!present)
      return failure(WVCheckpointStatusCode::unsupportedObserver,
                     "Unsupported MATLAB observing-system class '" +
                         className + "'.",
                     outputPath + "/@AnnotatedClass");
    unsigned int schemaVersion = 0;
    result = detail::checkedNetCDF(
        nc_get_att_uint(metadataGroup, NC_GLOBAL,
                        "portableObservationSchemaVersion", &schemaVersion),
        "Observation-schema version read", outputPath);
    if (!result)
      return result;
    observer.contractVersion = schemaVersion;
    result = optionalTextAttribute(metadataGroup, "name", observer.name,
                                   present, outputPath);
    if (!result)
      return result;
    if (!present)
      observer.name = className;
    result = optionalTextAttribute(metadataGroup, "portableIdentifier",
                                   observer.identifier, present, outputPath);
    if (!result)
      return result;
    if (!present)
      observer.identifier = portableIdentifier(schemaIdentifier + "-" +
                                               observer.name);
    identifier = observer.identifier;
    return mergeObserver(portable, std::move(observer));
  }
  observer.contractVersion = implementation->contractVersion();
  const auto &behavior = *implementation;

  result = optionalTextAttribute(metadataGroup, "name", observer.name, present,
                                 outputPath);
  if (!result)
    return result;
  if (!present)
    observer.name = className;
  result = optionalTextAttribute(metadataGroup, "portableIdentifier",
                                 observer.identifier, present, outputPath);
  if (!result)
    return result;
  const bool hadPortableIdentifier = present;
  if (!hadPortableIdentifier) {
    if (behavior.recordsCoefficients())
      observer.identifier = "coefficients";
    else if (behavior.recordsEulerianFields())
      observer.identifier = "eulerian-fields";
    else
      observer.identifier = portableIdentifier(className + "-" + observer.name);
  }
  identifier = observer.identifier;

  if (!implementation->fieldListAttribute().empty()) {
    result = stringListAttribute(metadataGroup,
                                 implementation->fieldListAttribute().c_str(),
                                 observer.fieldNames, present, outputPath);
    if (!result)
      return result;
    if (!present)
      observer.fieldNames.clear();
    else
      observer.fieldNames.erase(std::remove(observer.fieldNames.begin(),
                                            observer.fieldNames.end(),
                                            std::string{}),
                                observer.fieldNames.end());
    if (!hadPortableIdentifier && behavior.recordsEulerianFields()) {
      for (const auto &field : observer.fieldNames)
        observer.identifier += "-" + portableIdentifier(field);
      identifier = observer.identifier;
    }
  }

  if (behavior.recordsCoefficients()) {
    double tolerance = 0.0;
    result = detail::readDoubleScalar(metadataGroup, "absTolerance", tolerance,
                                      outputPath);
    if (!result)
      return result;
    observer.stateBlockIdentifiers = {"Ap", "Am", "A0"};
    std::vector<std::string> names;
    std::vector<std::size_t> dimensions;
    result =
        variableShape(outputGroup, "Ap_real", names, dimensions, outputPath);
    if (!result)
      return result;
    if (names.size() != 3 || names[0] != "t" || names[1] != "kl" ||
        names[2] != "j")
      return failure(WVCheckpointStatusCode::shapeMismatch,
                     "Coefficient output must use [t,kl,j] NetCDF order.",
                     outputPath + "/Ap_real");
    const std::vector<std::size_t> logical{dimensions[2], dimensions[1]};
    for (const char *name : {"Ap", "Am", "A0"}) {
      result = mergeStateBlock(portable,
                               {name, WVStateScalarType::complex64, logical,
                                WVToleranceKind::coefficientEnergyScaled,
                                tolerance, WVStateOwnership::integratorOwned,
                                WVRestartRequirement::requiredDynamicState});
      if (!result)
        return result;
    }
  } else if (behavior.recordsEulerianFields()) {
    const bool hasCompleteCoefficients =
        std::find(observer.fieldNames.begin(), observer.fieldNames.end(),
                  "Ap") != observer.fieldNames.end() &&
        std::find(observer.fieldNames.begin(), observer.fieldNames.end(),
                  "Am") != observer.fieldNames.end() &&
        std::find(observer.fieldNames.begin(), observer.fieldNames.end(),
                  "A0") != observer.fieldNames.end();
    if (hasCompleteCoefficients) {
      std::vector<std::string> names;
      std::vector<std::size_t> dimensions;
      int coefficient = -1;
      bool paired = false;
      result = detail::variableIdIfPresent(outputGroup, "Ap_real", coefficient,
                                           paired, outputPath);
      if (!result)
        return result;
      result = variableShape(outputGroup, paired ? "Ap_real" : "Ap", names,
                             dimensions, outputPath);
      if (!result)
        return result;
      if ((names.size() != 2 && names.size() != 3) ||
          names[names.size() - 2] != "kl" || names.back() != "j")
        return failure(WVCheckpointStatusCode::shapeMismatch,
                       "Eulerian coefficients must use [kl,j] or [t,kl,j] "
                       "NetCDF order.",
                       outputPath + (paired ? "/Ap_real" : "/Ap"));
      const std::vector<std::size_t> logical{dimensions.back(),
                                             dimensions[dimensions.size() - 2]};
      for (const char *name : {"Ap", "Am", "A0"}) {
        const auto existing = std::find_if(
            portable.stateBlocks.begin(), portable.stateBlocks.end(),
            [&](const auto &block) { return block.identifier == name; });
        const double tolerance = existing == portable.stateBlocks.end()
                                     ? 1e-6
                                     : existing->absoluteTolerance;
        result = mergeStateBlock(portable,
                                 {name, WVStateScalarType::complex64, logical,
                                  WVToleranceKind::coefficientEnergyScaled,
                                  tolerance, WVStateOwnership::integratorOwned,
                                  WVRestartRequirement::requiredDynamicState});
        if (!result)
          return result;
      }
    }
  } else if (behavior.recordsMovingParticles()) {
    result = detail::readLogicalScalar(metadataGroup, "isXYOnly",
                                       observer.isXYOnly, outputPath);
    if (!result)
      return result;
    result = detail::readDoubleScalar(metadataGroup, "absToleranceXY",
                                      observer.horizontalAbsoluteTolerance,
                                      outputPath);
    if (!result)
      return result;
    result = detail::readDoubleScalar(metadataGroup, "absToleranceZ",
                                      observer.verticalAbsoluteTolerance,
                                      outputPath);
    if (!result)
      return result;
    std::string interpolation;
    result = optionalTextAttribute(metadataGroup, "advectionInterpolation",
                                   interpolation, present, outputPath);
    if (!result)
      return result;
    observer.advectionInterpolation = interpolation == "spline"
                                          ? WVPositionInterpolation::spline
                                          : WVPositionInterpolation::linear;
    result = optionalTextAttribute(metadataGroup, "trackedVarInterpolation",
                                   interpolation, present, outputPath);
    if (!result)
      return result;
    observer.trackedFieldInterpolation = interpolation == "spline"
                                             ? WVPositionInterpolation::spline
                                             : WVPositionInterpolation::linear;
    std::size_t count = 0;
    result = detail::dimensionLength(outputGroup, observer.name + "_id", count,
                                     outputPath);
    if (!result)
      return result;
    observer.x.assign(count, 0.0);
    observer.y.assign(count, 0.0);
    int fixedZVariable = -1;
    if (!observer.isXYOnly ||
        nc_inq_varid(outputGroup, (observer.name + "_z").c_str(),
                     &fixedZVariable) == NC_NOERR)
      observer.z.assign(count, 0.0);
    const auto channels = detail::movingFieldChannels(observer);
    for (std::size_t index = 0; index < channels.size(); ++index) {
      const std::string block = observer.identifier + "-" +
                                detail::movingFieldChannelName(channels[index]);
      observer.stateBlockIdentifiers.push_back(block);
      result = mergeStateBlock(portable,
                               {block,
                                WVStateScalarType::real64,
                                {count},
                                WVToleranceKind::uniformAbsolute,
                                index < 2 ? observer.horizontalAbsoluteTolerance
                                          : observer.verticalAbsoluteTolerance,
                                WVStateOwnership::integratorOwned,
                                WVRestartRequirement::requiredDynamicState});
      if (!result)
        return result;
    }
  } else if (behavior.recordsTracerState()) {
    result = detail::readLogicalScalar(metadataGroup, "isXYOnly",
                                       observer.isXYOnly, outputPath);
    if (!result)
      return result;
    result = detail::readLogicalScalar(metadataGroup, "shouldAntialias",
                                       observer.shouldAntialias, outputPath);
    if (!result)
      return result;
    double tolerance = 0.0;
    result = detail::readDoubleScalar(metadataGroup, "absTolerance", tolerance,
                                      outputPath);
    if (!result)
      return result;
    std::vector<std::string> names;
    std::vector<std::size_t> dimensions;
    result = variableShape(outputGroup, observer.name, names, dimensions,
                           outputPath);
    if (!result)
      return result;
    if (names.empty() || names.front() != "t" ||
        (dimensions.size() != 3 && dimensions.size() != 4))
      return failure(WVCheckpointStatusCode::shapeMismatch,
                     "Tracer output has incompatible dimensions.",
                     outputPath + "/" + observer.name);
    std::vector<std::size_t> logical(dimensions.rbegin(),
                                     dimensions.rend() - 1);
    const std::string block = observer.identifier + "-state";
    observer.stateBlockIdentifiers = {block};
    result =
        mergeStateBlock(portable, {block, WVStateScalarType::real64, logical,
                                   WVToleranceKind::uniformAbsolute, tolerance,
                                   WVStateOwnership::integratorOwned,
                                   WVRestartRequirement::requiredDynamicState});
    if (!result)
      return result;
  } else if (behavior.recordsFixedPoints()) {
    result = detail::readDoubleScalar(metadataGroup, "outputScale",
                                      observer.outputScale, outputPath);
    if (!result)
      return result;
    result = detail::readDoubleScalar(metadataGroup, "outputOffset",
                                      observer.outputOffset, outputPath);
    if (!result)
      return result;
    std::string interpolation;
    result = optionalTextAttribute(metadataGroup, "trackedVarInterpolation",
                                   interpolation, present, outputPath);
    if (!result)
      return result;
    observer.trackedFieldInterpolation = interpolation == "spline"
                                             ? WVPositionInterpolation::spline
                                             : WVPositionInterpolation::linear;
    result = readWholeDoubleVariable(outputGroup, observer.name + "_x",
                                     observer.x, outputPath);
    if (!result)
      return result;
    result = readWholeDoubleVariable(outputGroup, observer.name + "_y",
                                     observer.y, outputPath);
    if (!result)
      return result;
    result = readWholeDoubleVariable(outputGroup, observer.name + "_z",
                                     observer.z, outputPath);
    if (!result)
      return result;
  } else if (behavior.recordsFixedProfiles()) {
    result = readWholeDoubleVariable(outputGroup, observer.name + "_x",
                                     observer.x, outputPath);
    if (!result)
      return result;
    result = readWholeDoubleVariable(outputGroup, observer.name + "_y",
                                     observer.y, outputPath);
    if (!result)
      return result;
    result = readWholeDoubleVariable(outputGroup, observer.name + "_z",
                                     observer.z, outputPath);
    if (!result)
      return result;
  }
  return mergeObserver(portable, std::move(observer));
}


} // namespace

namespace detail {

WVCheckpointStatus parsePersistedObserver(
    int outputGroup, int metadataGroup, const std::string &outputPath,
    WVPortableObserverRecord &portable, std::string &identifier) {
  return parseObserver(outputGroup, metadataGroup, outputPath, portable,
                       identifier);
}

bool persistedObserverCarriesCoefficientState(int metadataGroup) noexcept {
  std::string className;
  const auto status = readTextAttribute(metadataGroup, "AnnotatedClass",
                                        className, "/observingSystems");
  if (!status)
    return false;
  const auto implementation = observerImplementation(
      className, WVPortablePairContractVersion);
  return implementation && implementation->recordsCoefficients();
}

WVCheckpointStatus resolvePersistedObserverRestartState(
    const std::vector<WVOutputFileRecord> &files,
    std::vector<WVObserverRecord> &observers, double selectedTime,
    std::map<std::string, std::vector<std::vector<double>>> &resolvedState) {
  resolvedState.clear();
  for (auto &observer : observers) {
    const auto implementation = observerImplementation(
        observer.typeIdentifier, observer.contractVersion);
    if (!implementation || observer.stateBlockIdentifiers.empty() ||
        (!implementation->recordsMovingParticles() &&
         !implementation->recordsTracerState()))
      continue;
    std::vector<std::vector<double>> selectedValues;
    std::string selectedLocation;
    bool hasSelectedValues = false;
    for (const auto &file : files) {
      for (const auto &group : file.groups) {
        if (std::find(group.observerIdentifiers.begin(),
                      group.observerIdentifiers.end(), observer.identifier) ==
            group.observerIdentifiers.end())
          continue;
        std::vector<std::vector<double>> values;
        bool found = false;
        auto result = readObserverStateAtTime(
            file.destination, group, observer, selectedTime, values, found);
        if (!result)
          return result;
        if (!found)
          continue;
        const std::string location = file.destination + "/" + group.name;
        if (!hasSelectedValues) {
          selectedValues = std::move(values);
          selectedLocation = location;
          hasSelectedValues = true;
          continue;
        }
        const bool compatible =
            values.size() == selectedValues.size() &&
            std::equal(values.begin(), values.end(), selectedValues.begin(),
                       [](const auto &left, const auto &right) {
                         return sameRestartValues(left, right);
                       });
        if (!compatible)
          return failure(
              WVCheckpointStatusCode::ambiguousState,
              "Dynamic observer state conflicts across output groups.",
              selectedLocation + " and " + location);
      }
    }
    if (!hasSelectedValues)
      return failure(WVCheckpointStatusCode::missingVariable,
                     "No output group contains required dynamic observer "
                     "state at the selected restart time.",
                     "/observingSystems/" + observer.identifier);
    const bool hasFixedParticleZ =
        implementation->recordsMovingParticles() && observer.isXYOnly &&
        !observer.z.empty();
    if (selectedValues.size() !=
        observer.stateBlockIdentifiers.size() + (hasFixedParticleZ ? 1 : 0))
      return failure(WVCheckpointStatusCode::shapeMismatch,
                     "Dynamic observer state has an incompatible block "
                     "count.",
                     selectedLocation);
    if (implementation->recordsMovingParticles()) {
      observer.x = selectedValues[0];
      observer.y = selectedValues[1];
      if (hasFixedParticleZ)
        observer.z = selectedValues.back();
      else if (selectedValues.size() == 3)
        observer.z = selectedValues[2];
    }
    if (hasFixedParticleZ)
      selectedValues.pop_back();
    resolvedState.emplace(observer.identifier, std::move(selectedValues));
  }
  return WVCheckpointStatus::ok();
}

} // namespace detail
} // namespace wavevortex::runtime
