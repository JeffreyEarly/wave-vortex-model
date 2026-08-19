#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"

#include "WVModelOutputNetCDFSchema.hpp"
#include "WVNetCDF.hpp"
#include "WVObserverAdapter.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <filesystem>
#include <limits>
#include <map>
#include <netcdf.h>
#include <new>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace wavevortex::runtime {
namespace {

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

WVCheckpointStatus optionalLogicalAttribute(int group, const char *name,
                                            bool &value, bool &present,
                                            const std::string &path) {
  nc_type type = NC_NAT;
  std::size_t length = 0;
  const int inquiry = nc_inq_att(group, NC_GLOBAL, name, &type, &length);
  if (inquiry == NC_ENOTATT) {
    present = false;
    value = false;
    return WVCheckpointStatus::ok();
  }
  if (inquiry != NC_NOERR)
    return detail::netcdfFailure(inquiry, "Attribute inspection",
                                 path + "/@" + name);
  if ((type != NC_BYTE && type != NC_UBYTE) || length != 1)
    return failure(WVCheckpointStatusCode::typeMismatch,
                   "Logical attributes must contain one byte.",
                   path + "/@" + name);
  unsigned char raw = 0;
  const int read = nc_get_att_uchar(group, NC_GLOBAL, name, &raw);
  if (read != NC_NOERR)
    return detail::netcdfFailure(read, "Attribute read", path + "/@" + name);
  if (raw > 1)
    return failure(WVCheckpointStatusCode::invalidValue,
                   "Logical attributes must contain zero or one.",
                   path + "/@" + name);
  present = true;
  value = raw != 0;
  return WVCheckpointStatus::ok();
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
  if (!implementation)
    return failure(WVCheckpointStatusCode::unsupportedObserver,
                   "Unsupported MATLAB observing-system class '" + className +
                       "'.",
                   outputPath + "/@AnnotatedClass");
  WVObserverRecord observer;
  observer.typeIdentifier = className;
  observer.contractVersion = implementation->contractVersion();
  const auto &behavior = *implementation;

  bool present = false;
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

WVCheckpointStatus
validateReadableHistory(int group, const WVOutputScheduleRecord &schedule,
                        const std::string &path,
                        WVOutputScheduleOrdinal &committedOrdinal,
                        WVPortableTypedRecord &scheduleCursor) {
  std::size_t timeCount = 0;
  auto result = detail::dimensionLength(group, "t", timeCount, path);
  if (!result)
    return result;
  committedOrdinal = WVNoCommittedOutputOrdinal;
  scheduleCursor = {};
  if (timeCount == 0)
    return WVCheckpointStatus::ok();
  int timeVariable = -1;
  result = detail::checkedNetCDF(nc_inq_varid(group, "t", &timeVariable),
                                 "Time-variable lookup", path + "/t");
  if (!result)
    return result;
  std::vector<double> times(timeCount);
  result = detail::checkedNetCDF(
      nc_get_var_double(group, timeVariable, times.data()), "Output-time read",
      path + "/t");
  if (!result)
    return result;
  if (schedule.typeIdentifier.empty()) {
    for (std::size_t index = 0; index < times.size(); ++index) {
      const double raw =
          (times[index] - schedule.initialTime) / schedule.outputInterval;
      const auto ordinal =
          static_cast<WVOutputScheduleOrdinal>(std::llround(raw));
      const double expected =
          schedule.initialTime +
          static_cast<double>(ordinal) * schedule.outputInterval;
      const double tolerance =
          8 * std::numeric_limits<double>::epsilon() *
          std::max({1.0, std::abs(times[index]), std::abs(expected)});
      if (!std::isfinite(times[index]) || ordinal < 0 ||
          std::abs(times[index] - expected) > tolerance ||
          (index > 0 && !(times[index] > times[index - 1])))
        return failure(WVCheckpointStatusCode::appendConflict,
                       "Output history is not a strictly increasing subset of "
                       "its configured schedule lattice.",
                       path + "/t");
      committedOrdinal = ordinal;
    }
  } else {
    int ordinalVariable = -1, cursorVariable = -1;
    result = detail::checkedNetCDF(
        nc_inq_varid(group, "portableScheduleOrdinal", &ordinalVariable),
        "Schedule-ordinal lookup", path);
    if (!result)
      return result;
    result = detail::checkedNetCDF(
        nc_inq_varid(group, "portableScheduleCursor", &cursorVariable),
        "Schedule-cursor lookup", path);
    if (!result)
      return result;
    std::vector<long long> ordinals(timeCount);
    result = detail::checkedNetCDF(
        nc_get_var_longlong(group, ordinalVariable, ordinals.data()),
        "Schedule-ordinal read", path);
    if (!result)
      return result;
    for (std::size_t index = 0; index < timeCount; ++index) {
      if (!std::isfinite(times[index]) || ordinals[index] < 0 ||
          (index > 0 && (!(times[index] > times[index - 1]) ||
                         ordinals[index] <= ordinals[index - 1])))
        return failure(WVCheckpointStatusCode::appendConflict,
                       "Algorithmic output history is not strictly monotone.",
                       path + "/t");
      const std::size_t position[] = {index};
      char *encodedCursor = nullptr;
      result = detail::checkedNetCDF(
          nc_get_var1_string(group, cursorVariable, position, &encodedCursor),
          "Schedule-cursor read", path);
      if (!result)
        return result;
      const std::string encoded = encodedCursor == nullptr ? "" : encodedCursor;
      if (encodedCursor != nullptr)
        nc_free_string(1, &encodedCursor);
      std::vector<std::uint8_t> cursorBytes;
      if (!hexDecode(encoded, cursorBytes) ||
          cursorBytes.size() > WVMaximumOutputScheduleCursorBytes)
        return failure(WVCheckpointStatusCode::appendConflict,
                       "Algorithmic output cursor is malformed or oversized.",
                       path);
      WVPortableTypedRecord cursor;
      const auto decoded = decodePortableTypedRecord(
          cursorBytes, cursor,
          {WVMaximumOutputScheduleCursorBytes, true, false});
      if (!decoded)
        return failure(WVCheckpointStatusCode::appendConflict, decoded.message,
                       path);
      scheduleCursor = std::move(cursor);
      committedOrdinal = static_cast<WVOutputScheduleOrdinal>(ordinals[index]);
    }
  }
  int variableCount = 0;
  result = detail::checkedNetCDF(nc_inq_varids(group, &variableCount, nullptr),
                                 "Output-variable enumeration", path);
  if (!result)
    return result;
  std::vector<int> variables(static_cast<std::size_t>(variableCount));
  result = detail::checkedNetCDF(
      nc_inq_varids(group, &variableCount, variables.data()),
      "Output-variable enumeration", path);
  if (!result)
    return result;
  for (const int variable : variables) {
    nc_type type = NC_NAT;
    int dimensionCount = 0;
    if (nc_inq_vartype(group, variable, &type) != NC_NOERR ||
        nc_inq_varndims(group, variable, &dimensionCount) != NC_NOERR)
      return failure(WVCheckpointStatusCode::netcdfFailure,
                     "Unable to inspect output variable.", path);
    if (type != NC_DOUBLE || dimensionCount == 0)
      continue;
    std::vector<int> dimensions(static_cast<std::size_t>(dimensionCount));
    result = detail::checkedNetCDF(
        nc_inq_vardimid(group, variable, dimensions.data()),
        "Output-variable dimension inspection", path);
    if (!result)
      return result;
    char firstName[NC_MAX_NAME + 1] = {};
    result = detail::checkedNetCDF(
        nc_inq_dimname(group, dimensions.front(), firstName),
        "Output-variable dimension-name inspection", path);
    if (!result)
      return result;
    if (std::string(firstName) != "t")
      continue;
    std::vector<std::size_t> start(dimensions.size(), 0);
    std::vector<std::size_t> count(dimensions.size(), 1);
    std::size_t slabSize = 1;
    for (std::size_t dimension = 1; dimension < dimensions.size();
         ++dimension) {
      result = detail::checkedNetCDF(
          nc_inq_dimlen(group, dimensions[dimension], &count[dimension]),
          "Output-variable dimension-length inspection", path);
      if (!result)
        return result;
      slabSize *= count[dimension];
    }
    std::vector<double> slab(slabSize);
    for (std::size_t record = 0; record < timeCount; ++record) {
      start.front() = record;
      result = detail::checkedNetCDF(
          nc_get_vara_double(group, variable, start.data(), count.data(),
                             slab.data()),
          "Committed output-record read", path);
      if (!result)
        return result;
      if (std::find(slab.begin(), slab.end(), NC_FILL_DOUBLE) != slab.end()) {
        char name[NC_MAX_NAME + 1] = {};
        nc_inq_varname(group, variable, name);
        return failure(WVCheckpointStatusCode::incompleteRecord,
                       "A committed output record contains unwritten payload "
                       "values.",
                       path + "/" + name);
      }
    }
  }
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus parseOutputFile(const std::string &path,
                                   WVPortableObserverRecord &portable,
                                   std::vector<WVOutputGroupProgress> &progress,
                                   WVOutputFileRecord &fileRecord,
                                   bool &isDynamicsLinear) {
  detail::WVNetCDFFile file;
  auto result = detail::WVNetCDFFile::openReadOnly(path, file);
  if (!result)
    return result;
  bool present = false;
  result = optionalLogicalAttribute(file.id(), "WVModelIsDynamicsLinear",
                                    isDynamicsLinear, present, "/");
  if (!result)
    return result;
  if (!present)
    isDynamicsLinear = false;
  result = optionalTextAttribute(file.id(), "portableFileIdentifier",
                                 fileRecord.identifier, present, "/");
  if (!result)
    return result;
  if (!present)
    fileRecord.identifier = portableIdentifier(
        std::filesystem::absolute(path).lexically_normal().string());
  fileRecord.destination = path;

  std::vector<int> children;
  result = detail::childGroups(file.id(), children, "/");
  if (!result)
    return result;
  std::size_t restartGroupCount = 0;
  for (const int groupId : children) {
    std::string groupName;
    result = detail::groupName(groupId, groupName, "/");
    if (!result)
      return result;
    const std::string groupPath = "/" + groupName;
    std::string className;
    result = optionalTextAttribute(groupId, "AnnotatedClass", className,
                                   present, groupPath);
    if (!result)
      return result;
    if (!present || className != "WVModelOutputGroupEvenlySpaced")
      continue;
    WVOutputGroupRecord group;
    group.name = groupName;
    result = optionalTextAttribute(groupId, "portableIdentifier",
                                   group.identifier, present, groupPath);
    if (!result)
      return result;
    if (!present)
      group.identifier = portableIdentifier(groupName);
    result = optionalTextAttribute(groupId, "portableScheduleTypeIdentifier",
                                   group.schedule.typeIdentifier, present,
                                   groupPath);
    if (!result)
      return result;
    if (present) {
      unsigned int version = 0;
      result = detail::checkedNetCDF(
          nc_get_att_uint(groupId, NC_GLOBAL, "portableScheduleContractVersion",
                          &version),
          "Schedule-version attribute read", groupPath);
      if (!result)
        return result;
      group.schedule.contractVersion = version;
      std::string encodedConfiguration;
      bool hasConfiguration = false;
      result = optionalTextAttribute(groupId, "portableScheduleConfiguration",
                                     encodedConfiguration, hasConfiguration,
                                     groupPath);
      if (!result)
        return result;
      std::vector<std::uint8_t> configurationBytes;
      if (!hasConfiguration ||
          !hexDecode(encodedConfiguration, configurationBytes))
        return failure(WVCheckpointStatusCode::invalidValue,
                       "Algorithmic output schedule configuration is missing "
                       "or malformed.",
                       groupPath);
      const auto decoded = decodePortableTypedRecord(
          configurationBytes, group.schedule.configuration);
      if (!decoded)
        return failure(WVCheckpointStatusCode::invalidValue, decoded.message,
                       groupPath);
    }
    result = detail::readDoubleScalar(groupId, "outputInterval",
                                      group.schedule.outputInterval, groupPath);
    if (!result)
      return result;
    result = detail::readDoubleScalar(groupId, "initialTime",
                                      group.schedule.initialTime, groupPath);
    if (!result)
      return result;
    result = detail::readDoubleScalar(groupId, "finalTime",
                                      group.schedule.finalTime, groupPath);
    if (!result)
      return result;
    int coefficientVariable = -1;
    bool hasCoefficients = false;
    result = detail::variableIdIfPresent(
        groupId, "Ap_real", coefficientVariable, hasCoefficients, groupPath);
    if (!result)
      return result;
    if (!hasCoefficients) {
      result = detail::variableIdIfPresent(groupId, "Ap", coefficientVariable,
                                           hasCoefficients, groupPath);
      if (!result)
        return result;
    }
    group.containsCompleteCoefficientRestart = hasCoefficients;
    restartGroupCount += hasCoefficients ? 1 : 0;

    int metadataRoot = -1;
    const int metadataLookup =
        nc_inq_ncid(groupId, "observingSystems", &metadataRoot);
    if (metadataLookup == NC_ENOGRP)
      return failure(WVCheckpointStatusCode::missingVariable,
                     "Output group lacks observing-system metadata.",
                     groupPath + "/observingSystems");
    result =
        detail::checkedNetCDF(metadataLookup, "Observer metadata-root lookup",
                              groupPath + "/observingSystems");
    if (!result)
      return result;
    std::vector<int> observers;
    result = detail::childGroups(metadataRoot, observers,
                                 groupPath + "/observingSystems");
    if (!result)
      return result;
    std::string rootObserverClass;
    result =
        optionalTextAttribute(metadataRoot, "AnnotatedClass", rootObserverClass,
                              present, groupPath + "/observingSystems");
    if (!result)
      return result;
    if (present) {
      std::string observerIdentifier;
      result =
          parseObserver(groupId, metadataRoot, groupPath + "/observingSystems",
                        portable, observerIdentifier);
      if (!result)
        return result;
      group.observerIdentifiers.push_back(std::move(observerIdentifier));
    }
    std::map<int, std::string> parsedIdentifiers;
    const auto parseOne = [&](int observerGroup) {
      std::string observerIdentifier;
      auto observerResult =
          parseObserver(groupId, observerGroup, groupPath + "/observingSystems",
                        portable, observerIdentifier);
      if (observerResult)
        parsedIdentifiers.emplace(observerGroup, std::move(observerIdentifier));
      return observerResult;
    };
    std::set<int> parsedObservers;
    for (const int observerGroup : observers) {
      std::string observerClass;
      result =
          optionalTextAttribute(observerGroup, "AnnotatedClass", observerClass,
                                present, groupPath + "/observingSystems");
      if (!result)
        return result;
      const auto implementation = detail::observerImplementation(
          observerClass, WVPortablePairContractVersion);
      if (present && implementation && implementation->recordsCoefficients()) {
        result = parseOne(observerGroup);
        if (!result)
          return result;
        parsedObservers.insert(observerGroup);
      }
    }
    for (const int observerGroup : observers) {
      if (parsedObservers.find(observerGroup) != parsedObservers.end())
        continue;
      result = parseOne(observerGroup);
      if (!result)
        return result;
    }
    for (const int observerGroup : observers)
      group.observerIdentifiers.push_back(parsedIdentifiers.at(observerGroup));

    WVOutputScheduleOrdinal ordinal = WVNoCommittedOutputOrdinal;
    WVPortableTypedRecord scheduleCursor;
    result = validateReadableHistory(groupId, group.schedule, groupPath,
                                     ordinal, scheduleCursor);
    if (!result)
      return result;
    progress.push_back({fileRecord.identifier, group.identifier, ordinal});
    progress.back().scheduleCursor = std::move(scheduleCursor);
    fileRecord.groups.push_back(std::move(group));
  }
  if (fileRecord.groups.empty())
    return failure(WVCheckpointStatusCode::missingVariable,
                   "File contains no supported output group.", path);
  if (restartGroupCount != 1)
    return failure(WVCheckpointStatusCode::ambiguousState,
                   "Each restartable output file must contain exactly one "
                   "complete coefficient stream.",
                   path);
  return WVCheckpointStatus::ok();
}

} // namespace

WVCheckpointStatus
WVModelOutputNetCDFSink::inspect(const std::vector<std::string> &paths,
                                 WVModelOutputNetCDFInspection &inspection) {
  if (paths.empty())
    return failure(WVCheckpointStatusCode::openFailure,
                   "At least one output path is required.", "/");
  try {
    WVModelOutputNetCDFInspection candidate;
    candidate.paths = paths;
    std::string selectedPath;
    WVCheckpointInspection selectedCheckpoint;
    bool firstFile = true;
    for (const auto &path : paths) {
      WVOutputFileRecord fileRecord;
      bool isDynamicsLinear = false;
      auto result =
          parseOutputFile(path, candidate.observerRecord, candidate.progress,
                          fileRecord, isDynamicsLinear);
      if (!result)
        return result;
      if (firstFile) {
        candidate.isDynamicsLinear = isDynamicsLinear;
        firstFile = false;
      } else if (candidate.isDynamicsLinear != isDynamicsLinear) {
        return failure(WVCheckpointStatusCode::schemaMismatch,
                       "Output files disagree on the model dynamics mode.",
                       path);
      }
      candidate.observerRecord.outputFiles.push_back(std::move(fileRecord));
      WVCheckpointInspection checkpoint;
      result = WVCheckpointReader::inspect(path, checkpoint);
      if (!result)
        return result;
      if (selectedPath.empty()) {
        selectedCheckpoint = std::move(checkpoint);
        selectedPath = path;
      } else {
        if (!sameTransformConfiguration(selectedCheckpoint.configuration,
                                        checkpoint.configuration))
          return failure(WVCheckpointStatusCode::schemaMismatch,
                         "Output files do not describe one model.", path);
        if (checkpoint.t > selectedCheckpoint.t) {
          selectedCheckpoint = std::move(checkpoint);
          selectedPath = path;
        }
      }
    }

    auto selectedFile = std::find_if(
        candidate.observerRecord.outputFiles.begin(),
        candidate.observerRecord.outputFiles.end(), [&](const auto &file) {
          return std::filesystem::absolute(file.destination)
                     .lexically_normal() ==
                 std::filesystem::absolute(selectedPath).lexically_normal();
        });
    if (selectedFile == candidate.observerRecord.outputFiles.end())
      return failure(WVCheckpointStatusCode::schemaMismatch,
                     "Selected restart file is absent from the output graph.",
                     selectedPath);
    const std::string selectedGroupName =
        selectedCheckpoint.metadata.stateGroupPath.size() > 1
            ? selectedCheckpoint.metadata.stateGroupPath.substr(1)
            : std::string{};
    auto selectedGroup = std::find_if(
        selectedFile->groups.begin(), selectedFile->groups.end(),
        [&](const auto &group) { return group.name == selectedGroupName; });
    if (selectedGroup == selectedFile->groups.end())
      return failure(WVCheckpointStatusCode::schemaMismatch,
                     "Selected restart group is absent from the output graph.",
                     selectedCheckpoint.metadata.stateGroupPath);
    std::map<std::string, std::vector<std::vector<double>>> resolvedState;
    for (auto &observer : candidate.observerRecord.observers) {
      const auto implementation = detail::observerImplementation(
          observer.typeIdentifier, observer.contractVersion);
      if (!implementation || observer.stateBlockIdentifiers.empty() ||
          (!implementation->recordsMovingParticles() &&
           !implementation->recordsTracerState()))
        continue;
      std::vector<std::vector<double>> selectedValues;
      std::string selectedLocation;
      bool hasSelectedValues = false;
      for (const auto &file : candidate.observerRecord.outputFiles) {
        for (const auto &group : file.groups) {
          if (std::find(group.observerIdentifiers.begin(),
                        group.observerIdentifiers.end(),
                        observer.identifier) == group.observerIdentifiers.end())
            continue;
          std::vector<std::vector<double>> values;
          bool found = false;
          auto result =
              readObserverStateAtTime(file.destination, group, observer,
                                      selectedCheckpoint.t, values, found);
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
      const bool hasFixedParticleZ = implementation->recordsMovingParticles() &&
                                     observer.isXYOnly && !observer.z.empty();
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

    WVPortableObserverDescriptor descriptor;
    const auto descriptorStatus = WVPortableObserverDescriptor::create(
        candidate.observerRecord, descriptor);
    if (!descriptorStatus)
      return failure(WVCheckpointStatusCode::descriptorFailure,
                     descriptorStatus.message, "/observingSystems");
    const auto layoutStatus = WVIntegrationStateLayout::create(
        selectedCheckpoint.coefficientShape, descriptor, candidate.stateLayout);
    if (!layoutStatus)
      return failure(WVCheckpointStatusCode::descriptorFailure,
                     layoutStatus.message, "/observingSystems");

    auto result =
        WVCheckpointReader::read(selectedPath, candidate.latestRestart);
    if (!result)
      return result;

    const auto storageStatus =
        candidate.additionalState.initialize(candidate.stateLayout);
    if (!storageStatus)
      return failure(WVCheckpointStatusCode::descriptorFailure,
                     storageStatus.message, "/observingSystems");
    for (const auto &observer : candidate.observerRecord.observers) {
      if (observer.stateBlockIdentifiers.empty())
        continue;
      const auto values = resolvedState.find(observer.identifier);
      if (values == resolvedState.end())
        continue;
      for (std::size_t valueIndex = 0;
           valueIndex < observer.stateBlockIdentifiers.size(); ++valueIndex) {
        const auto block =
            std::find_if(candidate.additionalState.mutableBlocks(),
                         candidate.additionalState.mutableBlocks() +
                             candidate.additionalState.blockCount(),
                         [&](const auto &view) {
                           return view.layout->identifier ==
                                  observer.stateBlockIdentifiers[valueIndex];
                         });
        if (block == candidate.additionalState.mutableBlocks() +
                         candidate.additionalState.blockCount())
          return failure(WVCheckpointStatusCode::descriptorFailure,
                         "Resolved dynamic observer state is absent from the "
                         "integration layout.",
                         "/observingSystems/" + observer.identifier);
        if (block->layout->elementCount != values->second[valueIndex].size())
          return failure(WVCheckpointStatusCode::shapeMismatch,
                         "Dynamic observer restart state has an incompatible "
                         "shape.",
                         "/observingSystems/" + observer.identifier);
        std::copy(values->second[valueIndex].begin(),
                  values->second[valueIndex].end(), block->realData);
      }
    }
    inspection = std::move(candidate);
    return WVCheckpointStatus::ok();
  } catch (const std::bad_alloc &) {
    return failure(WVCheckpointStatusCode::writeFailure,
                   "Output inspection allocation failed.", "/");
  }
}

} // namespace wavevortex::runtime
