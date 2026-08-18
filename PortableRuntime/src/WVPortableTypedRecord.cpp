#include "WaveVortexRuntime/WVPortableTypedRecord.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <set>
#include <type_traits>

namespace wavevortex::runtime {
namespace {

constexpr std::size_t encodedLengthBytes = sizeof(std::uint64_t);

std::size_t saturatingAdd(std::size_t left, std::size_t right) noexcept {
  if (right > std::numeric_limits<std::size_t>::max() - left)
    return std::numeric_limits<std::size_t>::max();
  return left + right;
}

std::size_t saturatingMultiply(std::size_t left, std::size_t right) noexcept {
  if (left != 0 && right > std::numeric_limits<std::size_t>::max() / left)
    return std::numeric_limits<std::size_t>::max();
  return left * right;
}

std::size_t expectedCount(const std::vector<std::size_t> &dimensions,
                          bool &overflow) noexcept {
  overflow = false;
  if (dimensions.empty())
    return 1;
  std::size_t result = 1;
  for (const auto dimension : dimensions) {
    if (dimension != 0 &&
        result > std::numeric_limits<std::size_t>::max() / dimension) {
      overflow = true;
      return 0;
    }
    result *= dimension;
  }
  return result;
}

} // namespace

WVPortableValueType WVPortableNamedValue::valueType() const noexcept {
  switch (storage.index()) {
  case 0:
    return WVPortableValueType::boolean;
  case 1:
    return WVPortableValueType::integer;
  case 2:
    return WVPortableValueType::real;
  case 3:
    return WVPortableValueType::text;
  }
  return WVPortableValueType::real;
}

std::size_t WVPortableNamedValue::valueCount() const noexcept {
  return std::visit([](const auto &values) { return values.size(); }, storage);
}

std::size_t WVPortableNamedValue::encodedBytes() const noexcept {
  std::size_t result = encodedLengthBytes + name.size() + sizeof(std::uint8_t) +
                       encodedLengthBytes;
  result = saturatingAdd(
      result, saturatingMultiply(dimensions.size(), sizeof(std::uint64_t)));
  result = saturatingAdd(result, encodedLengthBytes);
  std::visit(
      [&](const auto &values) {
        using Value = typename std::decay_t<decltype(values)>::value_type;
        if constexpr (std::is_same_v<Value, std::string>) {
          for (const auto &value : values) {
            result = saturatingAdd(result, encodedLengthBytes);
            result = saturatingAdd(result, value.size());
          }
        } else {
          result = saturatingAdd(
              result, saturatingMultiply(values.size(), sizeof(Value)));
        }
      },
      storage);
  return result;
}

std::size_t WVPortableNamedValue::persistentBytes() const noexcept {
  std::size_t result = sizeof(*this) + name.capacity() +
                       dimensions.capacity() * sizeof(std::size_t);
  std::visit(
      [&](const auto &values) {
        using Value = typename std::decay_t<decltype(values)>::value_type;
        result = saturatingAdd(result, values.capacity() * sizeof(Value));
        if constexpr (std::is_same_v<Value, std::string>)
          for (const auto &value : values)
            result = saturatingAdd(result, value.capacity());
      },
      storage);
  return result;
}

const WVPortableNamedValue *
WVPortableTypedRecord::value(const std::string &name) const noexcept {
  const auto found = std::find_if(values.begin(), values.end(),
                                  [&](const auto &candidate) {
                                    return candidate.name == name;
                                  });
  return found == values.end() ? nullptr : &*found;
}

std::size_t WVPortableTypedRecord::encodedBytes() const noexcept {
  std::size_t result = encodedLengthBytes + schemaIdentifier.size() +
                       sizeof(schemaVersion) + encodedLengthBytes;
  for (const auto &value : values)
    result = saturatingAdd(result, value.encodedBytes());
  return result;
}

std::size_t WVPortableTypedRecord::persistentBytes() const noexcept {
  std::size_t result = sizeof(*this) + schemaIdentifier.capacity() +
                       values.capacity() * sizeof(WVPortableNamedValue);
  for (const auto &value : values)
    result = saturatingAdd(result, value.persistentBytes() - sizeof(value));
  return result;
}

WVKernelStatus validatePortableTypedRecord(
    const WVPortableTypedRecord &record,
    WVPortableTypedRecordValidation validation) {
  if (record.schemaIdentifier.empty() || record.schemaVersion == 0)
    return {WVKernelStatusCode::invalidConfiguration,
            "A portable typed record requires a schema identifier and "
            "positive schema version."};
  std::set<std::string> names;
  for (const auto &value : record.values) {
    if (value.name.empty() || !names.insert(value.name).second)
      return {WVKernelStatusCode::invalidConfiguration,
              "Portable typed-record value names must be nonempty and "
              "unique."};
    bool overflow = false;
    const auto count = expectedCount(value.dimensions, overflow);
    if (overflow)
      return {WVKernelStatusCode::sizeOverflow,
              "Portable typed-record dimensions overflow size_t."};
    if (count != value.valueCount())
      return {WVKernelStatusCode::invalidShape,
              "A portable typed-record value does not match its declared "
              "dimensions."};
    if (value.valueType() == WVPortableValueType::text &&
        !validation.allowText)
      return {WVKernelStatusCode::invalidConfiguration,
              "Text values are not permitted in this portable typed record."};
    if (value.valueType() == WVPortableValueType::boolean) {
      const auto &values = std::get<std::vector<std::uint8_t>>(value.storage);
      if (std::any_of(values.begin(), values.end(),
                      [](const auto item) { return item > 1; }))
        return {WVKernelStatusCode::invalidConfiguration,
                "Portable Boolean values must be encoded as zero or one."};
    }
    if (value.valueType() == WVPortableValueType::real &&
        validation.requireFiniteReals) {
      const auto &values = std::get<std::vector<double>>(value.storage);
      if (std::any_of(values.begin(), values.end(),
                      [](const auto item) { return !std::isfinite(item); }))
        return {WVKernelStatusCode::invalidConfiguration,
                "Portable real values must be finite in this record."};
    }
  }
  const auto bytes = record.encodedBytes();
  if (bytes == std::numeric_limits<std::size_t>::max())
    return {WVKernelStatusCode::sizeOverflow,
            "Portable typed-record encoded size overflowed size_t."};
  if (bytes > validation.maximumEncodedBytes)
    return {WVKernelStatusCode::sizeOverflow,
            "Portable typed record exceeds its encoded-size limit."};
  return WVKernelStatus::ok();
}

} // namespace wavevortex::runtime
