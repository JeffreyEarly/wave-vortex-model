#include "WaveVortexRuntime/WVObservation.hpp"

#include <algorithm>
#include <limits>
#include <map>
#include <set>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

bool validIdentifier(const std::string &value) {
  if (value.empty())
    return false;
  return std::all_of(value.begin(), value.end(), [](unsigned char character) {
    return (character >= 'a' && character <= 'z') ||
           (character >= 'A' && character <= 'Z') ||
           (character >= '0' && character <= '9') || character == '-' ||
           character == '_' || character == '.';
  });
}

bool multiply(std::size_t left, std::size_t right,
              std::size_t &product) noexcept {
  if (right != 0 && left > std::numeric_limits<std::size_t>::max() / right)
    return false;
  product = left * right;
  return true;
}

std::size_t scalarBytes(WVObservationScalarType type) noexcept {
  switch (type) {
  case WVObservationScalarType::real64:
    return sizeof(double);
  case WVObservationScalarType::complex64:
    return sizeof(WVComplex64);
  case WVObservationScalarType::integer64:
    return sizeof(std::int64_t);
  case WVObservationScalarType::boolean8:
    return sizeof(std::uint8_t);
  case WVObservationScalarType::text:
    return sizeof(std::string);
  }
  return 0;
}

template <typename T>
const T *storageData(WVObservationBufferOwnership ownership,
                     const T *borrowed,
                     const std::vector<T> &owned) noexcept {
  return ownership == WVObservationBufferOwnership::borrowed
             ? borrowed
             : owned.data();
}

WVObservationValue borrowedValue(std::string identifier,
                                 WVObservationScalarType type,
                                 std::vector<std::size_t> extents) {
  WVObservationValue value;
  value.variableIdentifier = std::move(identifier);
  value.scalarType = type;
  value.ownership = WVObservationBufferOwnership::borrowed;
  value.extents = std::move(extents);
  return value;
}

WVObservationValue ownedValue(std::string identifier,
                              WVObservationScalarType type,
                              std::vector<std::size_t> extents) {
  WVObservationValue value;
  value.variableIdentifier = std::move(identifier);
  value.scalarType = type;
  value.ownership = WVObservationBufferOwnership::owned;
  value.extents = std::move(extents);
  return value;
}

bool applicable(const WVObservationVariable &variable,
                WVObservationBatchKind kind) noexcept {
  const bool initial = variable.layout == WVObservationValueLayout::staticValue ||
                       variable.layout == WVObservationValueLayout::initialValue;
  return kind == WVObservationBatchKind::initial ? initial : !initial;
}

} // namespace

WVObservationValue
WVObservationValue::borrowReal(std::string identifier,
                               std::vector<std::size_t> extents,
                               const double *values) {
  auto value = borrowedValue(std::move(identifier),
                             WVObservationScalarType::real64,
                             std::move(extents));
  value.borrowedReal64 = values;
  return value;
}

WVObservationValue
WVObservationValue::borrowComplex(std::string identifier,
                                  std::vector<std::size_t> extents,
                                  const WVComplex64 *values) {
  auto value = borrowedValue(std::move(identifier),
                             WVObservationScalarType::complex64,
                             std::move(extents));
  value.borrowedComplex64 = values;
  return value;
}

WVObservationValue
WVObservationValue::borrowInteger(std::string identifier,
                                  std::vector<std::size_t> extents,
                                  const std::int64_t *values) {
  auto value = borrowedValue(std::move(identifier),
                             WVObservationScalarType::integer64,
                             std::move(extents));
  value.borrowedInteger64 = values;
  return value;
}

WVObservationValue
WVObservationValue::borrowBoolean(std::string identifier,
                                  std::vector<std::size_t> extents,
                                  const std::uint8_t *values) {
  auto value = borrowedValue(std::move(identifier),
                             WVObservationScalarType::boolean8,
                             std::move(extents));
  value.borrowedBoolean8 = values;
  return value;
}

WVObservationValue
WVObservationValue::borrowText(std::string identifier,
                               std::vector<std::size_t> extents,
                               const std::string *values) {
  auto value = borrowedValue(std::move(identifier), WVObservationScalarType::text,
                             std::move(extents));
  value.borrowedText = values;
  return value;
}

WVObservationValue
WVObservationValue::ownReal(std::string identifier,
                            std::vector<std::size_t> extents,
                            std::vector<double> values) {
  auto value = ownedValue(std::move(identifier), WVObservationScalarType::real64,
                          std::move(extents));
  value.ownedReal64 = std::move(values);
  return value;
}

WVObservationValue
WVObservationValue::ownComplex(std::string identifier,
                               std::vector<std::size_t> extents,
                               std::vector<WVComplex64> values) {
  auto value = ownedValue(std::move(identifier),
                          WVObservationScalarType::complex64,
                          std::move(extents));
  value.ownedComplex64 = std::move(values);
  return value;
}

WVObservationValue
WVObservationValue::ownInteger(std::string identifier,
                               std::vector<std::size_t> extents,
                               std::vector<std::int64_t> values) {
  auto value = ownedValue(std::move(identifier),
                          WVObservationScalarType::integer64,
                          std::move(extents));
  value.ownedInteger64 = std::move(values);
  return value;
}

WVObservationValue
WVObservationValue::ownBoolean(std::string identifier,
                               std::vector<std::size_t> extents,
                               std::vector<std::uint8_t> values) {
  auto value = ownedValue(std::move(identifier),
                          WVObservationScalarType::boolean8,
                          std::move(extents));
  value.ownedBoolean8 = std::move(values);
  return value;
}

WVObservationValue
WVObservationValue::ownText(std::string identifier,
                            std::vector<std::size_t> extents,
                            std::vector<std::string> values) {
  auto value = ownedValue(std::move(identifier), WVObservationScalarType::text,
                          std::move(extents));
  value.ownedText = std::move(values);
  return value;
}

std::size_t WVObservationValue::elementCount() const noexcept {
  std::size_t count = 1;
  for (const auto extent : extents)
    if (!multiply(count, extent, count))
      return std::numeric_limits<std::size_t>::max();
  return count;
}

std::size_t WVObservationValue::liveBytes() const noexcept {
  const auto count = elementCount();
  if (count == std::numeric_limits<std::size_t>::max())
    return count;
  std::size_t bytes = 0;
  if (!multiply(count, scalarBytes(scalarType), bytes))
    return std::numeric_limits<std::size_t>::max();
  if (scalarType == WVObservationScalarType::text) {
    const auto *values = textData();
    for (std::size_t index = 0; values != nullptr && index < count; ++index) {
      if (bytes > std::numeric_limits<std::size_t>::max() -
                      values[index].size())
        return std::numeric_limits<std::size_t>::max();
      bytes += values[index].size();
    }
  }
  return bytes;
}

std::size_t WVObservationValue::retainedBytes() const noexcept {
  if (ownership == WVObservationBufferOwnership::borrowed)
    return variableIdentifier.capacity() +
           extents.capacity() * sizeof(std::size_t);
  std::size_t bytes = variableIdentifier.capacity() +
                      extents.capacity() * sizeof(std::size_t) +
                      ownedReal64.capacity() * sizeof(double) +
                      ownedComplex64.capacity() * sizeof(WVComplex64) +
                      ownedInteger64.capacity() * sizeof(std::int64_t) +
                      ownedBoolean8.capacity() * sizeof(std::uint8_t) +
                      ownedText.capacity() * sizeof(std::string);
  for (const auto &value : ownedText)
    bytes += value.capacity();
  return bytes;
}

const double *WVObservationValue::real64Data() const noexcept {
  return scalarType == WVObservationScalarType::real64
             ? storageData(ownership, borrowedReal64, ownedReal64)
             : nullptr;
}

const WVComplex64 *WVObservationValue::complex64Data() const noexcept {
  return scalarType == WVObservationScalarType::complex64
             ? storageData(ownership, borrowedComplex64, ownedComplex64)
             : nullptr;
}

const std::int64_t *WVObservationValue::integer64Data() const noexcept {
  return scalarType == WVObservationScalarType::integer64
             ? storageData(ownership, borrowedInteger64, ownedInteger64)
             : nullptr;
}

const std::uint8_t *WVObservationValue::boolean8Data() const noexcept {
  return scalarType == WVObservationScalarType::boolean8
             ? storageData(ownership, borrowedBoolean8, ownedBoolean8)
             : nullptr;
}

const std::string *WVObservationValue::textData() const noexcept {
  return scalarType == WVObservationScalarType::text
             ? storageData(ownership, borrowedText, ownedText)
             : nullptr;
}

WVObservationBatchMetrics WVObservationBatch::metrics() const noexcept {
  WVObservationBatchMetrics result;
  for (const auto &value : values) {
    const auto live = value.liveBytes();
    const auto retained = value.retainedBytes();
    if (result.liveBytes > std::numeric_limits<std::size_t>::max() - live)
      result.liveBytes = std::numeric_limits<std::size_t>::max();
    else
      result.liveBytes += live;
    if (result.retainedStorageBytes >
        std::numeric_limits<std::size_t>::max() - retained)
      result.retainedStorageBytes = std::numeric_limits<std::size_t>::max();
    else
      result.retainedStorageBytes += retained;
  }
  result.retainedStorageBytes +=
      schemaIdentifier.capacity() + values.capacity() * sizeof(WVObservationValue);
  return result;
}

WVKernelStatus validateObservationSchema(const WVObservationSchema &schema) {
  if (!validIdentifier(schema.identifier) || schema.version == 0)
    return invalid("Observation schema identity and version must be valid.");
  std::map<std::string, const WVObservationAxis *> axes;
  std::set<std::string> axisNames;
  for (const auto &axis : schema.axes) {
    if (!validIdentifier(axis.identifier) || axis.name.empty() ||
        !axisNames.insert(axis.name).second ||
        !axes.emplace(axis.identifier, &axis).second)
      return invalid("Observation axes require unique identities and names.");
    if ((axis.kind == WVObservationAxisKind::fixed && axis.extent == 0) ||
        (axis.kind == WVObservationAxisKind::unlimited && axis.extent != 0))
      return invalid("Observation axis extent is inconsistent with its kind.");
  }
  std::set<std::string> variableIdentifiers;
  std::set<std::string> variableNames;
  for (const auto &variable : schema.variables) {
    if (!validIdentifier(variable.identifier) || variable.name.empty() ||
        !variableIdentifiers.insert(variable.identifier).second ||
        !variableNames.insert(variable.name).second)
      return invalid(
          "Observation variables require unique identities and names.");
    std::set<std::string> dimensions;
    bool hasUnlimitedAxis = false;
    for (const auto &identifier : variable.dimensionIdentifiers) {
      const auto found = axes.find(identifier);
      if (found == axes.end() || !dimensions.insert(identifier).second)
        return invalid("Observation variable dimensions are undeclared or repeated.");
      hasUnlimitedAxis =
          hasUnlimitedAxis ||
          found->second->kind == WVObservationAxisKind::unlimited;
    }
    if (variable.layout == WVObservationValueLayout::flat &&
        !hasUnlimitedAxis)
      return invalid("Flat observation variables require an unlimited axis.");
    if (variable.layout != WVObservationValueLayout::flat && hasUnlimitedAxis)
      return invalid(
          "Only flat observation variables may use unlimited axes.");
    if (variable.raggedRole != WVObservationRaggedRole::none) {
      const auto child = axes.find(variable.raggedChildAxisIdentifier);
      if (variable.scalarType != WVObservationScalarType::integer64 ||
          child == axes.end() ||
          child->second->kind != WVObservationAxisKind::unlimited)
        return invalid(
            "Ragged relationships require integer values and a declared child unlimited axis.");
    } else if (!variable.raggedChildAxisIdentifier.empty()) {
      return invalid("Non-ragged variables cannot name a ragged child axis.");
    }
    std::set<std::string> attributeNames;
    for (const auto &attribute : variable.attributes)
      if (attribute.name.empty() ||
          !attributeNames.insert(attribute.name).second)
        return invalid("Observation variable attributes must be unique.");
  }
  return WVKernelStatus::ok();
}

WVKernelStatus validateObservationBatch(const WVObservationSchema &schema,
                                        const WVObservationBatch &batch) {
  const auto schemaStatus = validateObservationSchema(schema);
  if (!schemaStatus)
    return schemaStatus;
  if (batch.schemaIdentifier != schema.identifier ||
      batch.schemaVersion != schema.version)
    return invalid("Observation batch schema identity or version drifted.");
  std::map<std::string, const WVObservationAxis *> axes;
  for (const auto &axis : schema.axes)
    axes.emplace(axis.identifier, &axis);
  std::map<std::string, const WVObservationVariable *> variables;
  std::size_t expectedValueCount = 0;
  for (const auto &variable : schema.variables) {
    variables.emplace(variable.identifier, &variable);
    expectedValueCount += applicable(variable, batch.kind) ? 1 : 0;
  }
  if (batch.values.size() != expectedValueCount)
    return invalid("Observation batch does not contain every applicable declared variable.");

  std::set<std::string> observedVariables;
  std::map<std::string, std::size_t> unlimitedExtents;
  std::map<std::string, const WVObservationValue *> valuesByIdentifier;
  for (const auto &value : batch.values) {
    const auto found = variables.find(value.variableIdentifier);
    if (found == variables.end())
      return invalid("Observation batch contains an undeclared variable.");
    const auto &variable = *found->second;
    if (!applicable(variable, batch.kind) ||
        !observedVariables.insert(value.variableIdentifier).second)
      return invalid("Observation batch variable is duplicated or belongs to another phase.");
    if (value.scalarType != variable.scalarType ||
        value.extents.size() != variable.dimensionIdentifiers.size())
      return invalid("Observation batch value type or rank differs from its schema.");
    std::size_t expectedElements = 1;
    for (std::size_t index = 0; index < value.extents.size(); ++index) {
      const auto &axis = *axes.at(variable.dimensionIdentifiers[index]);
      const auto extent = value.extents[index];
      if (axis.kind == WVObservationAxisKind::fixed) {
        if (extent != axis.extent)
          return invalid("Observation batch fixed-axis extent changed.");
      } else {
        const auto prior = unlimitedExtents.find(axis.identifier);
        if (prior == unlimitedExtents.end())
          unlimitedExtents.emplace(axis.identifier, extent);
        else if (prior->second != extent)
          return invalid("Observation batch unlimited-axis extents are inconsistent.");
      }
      if (!multiply(expectedElements, extent, expectedElements))
        return {WVKernelStatusCode::sizeOverflow,
                "Observation batch element count overflows size_t."};
    }
    if (value.elementCount() != expectedElements)
      return {WVKernelStatusCode::sizeOverflow,
              "Observation batch element count overflows size_t."};
    const bool hasData =
        expectedElements == 0 ||
        (value.scalarType == WVObservationScalarType::real64 &&
         value.real64Data() != nullptr) ||
        (value.scalarType == WVObservationScalarType::complex64 &&
         value.complex64Data() != nullptr) ||
        (value.scalarType == WVObservationScalarType::integer64 &&
         value.integer64Data() != nullptr) ||
        (value.scalarType == WVObservationScalarType::boolean8 &&
         value.boolean8Data() != nullptr) ||
        (value.scalarType == WVObservationScalarType::text &&
         value.textData() != nullptr);
    if (!hasData)
      return invalid("Observation batch value has no compatible contiguous buffer.");
    if (value.ownership == WVObservationBufferOwnership::owned) {
      const std::size_t ownedCount =
          value.scalarType == WVObservationScalarType::real64
              ? value.ownedReal64.size()
              : value.scalarType == WVObservationScalarType::complex64
                    ? value.ownedComplex64.size()
                    : value.scalarType == WVObservationScalarType::integer64
                          ? value.ownedInteger64.size()
                          : value.scalarType == WVObservationScalarType::boolean8
                                ? value.ownedBoolean8.size()
                                : value.ownedText.size();
      if (ownedCount != expectedElements)
        return invalid("Owned observation buffer size differs from its extents.");
    }
    if (value.scalarType == WVObservationScalarType::boolean8) {
      const auto *booleans = value.boolean8Data();
      for (std::size_t index = 0; index < expectedElements; ++index)
        if (booleans[index] > 1)
          return invalid("Boolean observation values must contain zero or one.");
    }
    valuesByIdentifier.emplace(value.variableIdentifier, &value);
  }

  for (const auto &variable : schema.variables) {
    if (!applicable(variable, batch.kind) ||
        variable.raggedRole == WVObservationRaggedRole::none)
      continue;
    const auto &value = *valuesByIdentifier.at(variable.identifier);
    const auto childExtent = unlimitedExtents.find(
        variable.raggedChildAxisIdentifier);
    if (childExtent == unlimitedExtents.end())
      return invalid("Ragged child axis is absent from the observation batch.");
    const auto *integers = value.integer64Data();
    const auto count = value.elementCount();
    if (variable.raggedRole == WVObservationRaggedRole::rowCount) {
      std::size_t total = 0;
      for (std::size_t index = 0; index < count; ++index) {
        if (integers[index] < 0 ||
            static_cast<std::uint64_t>(integers[index]) >
                std::numeric_limits<std::size_t>::max())
          return invalid("Ragged row counts must be nonnegative and bounded.");
        const auto row = static_cast<std::size_t>(integers[index]);
        if (total > std::numeric_limits<std::size_t>::max() - row)
          return {WVKernelStatusCode::sizeOverflow,
                  "Ragged row-count sum overflows size_t."};
        total += row;
      }
      if (total != childExtent->second)
        return invalid("Ragged row counts do not span the child axis.");
    } else if (count > 0) {
      if (integers[0] != 0)
        return invalid("Ragged row offsets must begin at zero in each batch.");
      for (std::size_t index = 0; index < count; ++index)
        if (integers[index] < 0 ||
            static_cast<std::uint64_t>(integers[index]) > childExtent->second ||
            (index > 0 && integers[index] < integers[index - 1]))
          return invalid("Ragged row offsets are malformed.");
    }
  }
  return WVKernelStatus::ok();
}

} // namespace wavevortex::runtime
