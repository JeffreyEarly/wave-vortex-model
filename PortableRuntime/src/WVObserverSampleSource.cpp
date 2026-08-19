#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"

#include <algorithm>
#include <map>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

std::string schemaIdentifier(const WVObserverRecord &observer) {
  return "legacy-" + observer.identifier + "-observation-v1";
}

WVObservationScalarType scalarType(WVOutputValueType type) noexcept {
  return type == WVOutputValueType::complex64
             ? WVObservationScalarType::complex64
             : WVObservationScalarType::real64;
}

WVObserverOutputVariableSpecification
legacySpecification(const WVObservationVariable &variable,
                    const std::map<std::string, const WVObservationAxis *> &axes) {
  WVObserverOutputVariableSpecification result;
  result.identifier = variable.identifier;
  result.name = variable.name;
  result.valueType = variable.scalarType == WVObservationScalarType::complex64
                         ? WVOutputValueType::complex64
                         : WVOutputValueType::real64;
  result.dimensionNames.reserve(variable.dimensionIdentifiers.size());
  result.dimensions.reserve(variable.dimensionIdentifiers.size());
  for (const auto &identifier : variable.dimensionIdentifiers) {
    result.dimensionNames.push_back(axes.at(identifier)->name);
    result.dimensions.push_back(axes.at(identifier)->extent);
  }
  result.units = variable.units;
  result.longName = variable.description;
  result.cadence = variable.layout == WVObservationValueLayout::initialValue
                       ? WVObserverOutputCadence::initialOnly
                       : WVObserverOutputCadence::timeSeries;
  for (const auto &attribute : variable.attributes)
    result.attributes.push_back({attribute.name, attribute.value});
  return result;
}

WVKernelStatus legacyBatch(WVObserverSampleSource &source,
                           const WVObserverRecord &observer,
                           WVObservationBatchKind kind,
                           WVObservationBatch &output) {
  WVObservationSchema schema;
  auto status = source.observationSchema(observer, schema);
  if (!status)
    return status;
  std::map<std::string, const WVObservationAxis *> axes;
  for (const auto &axis : schema.axes)
    axes.emplace(axis.identifier, &axis);
  WVObservationBatch candidate;
  candidate.schemaIdentifier = schema.identifier;
  candidate.schemaVersion = schema.version;
  candidate.kind = kind;
  for (const auto &variable : schema.variables) {
    const bool isInitial =
        variable.layout == WVObservationValueLayout::staticValue ||
        variable.layout == WVObservationValueLayout::initialValue;
    if ((kind == WVObservationBatchKind::initial) != isInitial)
      continue;
    if (variable.scalarType != WVObservationScalarType::real64 &&
        variable.scalarType != WVObservationScalarType::complex64)
      return invalid("Legacy observer values support only real or complex values.");
    const auto specification = legacySpecification(variable, axes);
    WVObserverOutputValueView value;
    status = source.value(observer, specification, value);
    if (!status)
      return status;
    if (value.valueType != specification.valueType)
      return invalid("Legacy observer value type differs from its specification.");
    if (value.elementCount != [&]() {
          std::size_t count = 1;
          for (const auto extent : specification.dimensions)
            count *= extent;
          return count;
        }())
      return invalid("Legacy observer value extent differs from its specification.");
    if (value.valueType == WVOutputValueType::complex64)
      candidate.values.push_back(WVObservationValue::borrowComplex(
          variable.identifier, specification.dimensions, value.complexData));
    else
      candidate.values.push_back(WVObservationValue::borrowReal(
          variable.identifier, specification.dimensions, value.realData));
  }
  status = validateObservationBatch(schema, candidate);
  if (!status)
    return status;
  output = std::move(candidate);
  return WVKernelStatus::ok();
}

} // namespace

WVKernelStatus WVObserverSampleSource::observationSchema(
    const WVObserverRecord &observer, WVObservationSchema &output) {
  std::vector<WVObserverOutputVariableSpecification> specificationsValue;
  auto status = specifications(observer, specificationsValue);
  if (!status)
    return status;
  WVObservationSchema candidate;
  candidate.identifier = schemaIdentifier(observer);
  candidate.preservesLegacyEncoding = true;
  std::map<std::string, std::size_t> axisExtents;
  for (const auto &specification : specificationsValue) {
    if (specification.dimensionNames.size() != specification.dimensions.size())
      return invalid("Legacy observer specification dimensions are inconsistent.");
    WVObservationVariable variable;
    variable.identifier = specification.identifier;
    variable.name = specification.name;
    variable.scalarType = scalarType(specification.valueType);
    variable.layout = specification.cadence == WVObserverOutputCadence::initialOnly
                          ? WVObservationValueLayout::initialValue
                          : WVObservationValueLayout::record;
    variable.units = specification.units;
    variable.description = specification.longName;
    for (const auto &attribute : specification.attributes)
      variable.attributes.push_back({attribute.name, attribute.value});
    for (std::size_t index = 0; index < specification.dimensionNames.size();
         ++index) {
      const auto &name = specification.dimensionNames[index];
      const auto extent = specification.dimensions[index];
      const auto inserted = axisExtents.emplace(name, extent);
      if (!inserted.second && inserted.first->second != extent)
        return invalid("Legacy observer specifications disagree on an axis extent.");
      variable.dimensionIdentifiers.push_back(name);
    }
    candidate.variables.push_back(std::move(variable));
  }
  for (const auto &[name, extent] : axisExtents)
    candidate.axes.push_back(
        {name, name, WVObservationAxisKind::fixed, extent,
         WVObservationCoordinateRole::none});
  status = validateObservationSchema(candidate);
  if (!status)
    return status;
  output = std::move(candidate);
  return WVKernelStatus::ok();
}

WVKernelStatus WVObserverSampleSource::initialObservationBatch(
    const WVObserverRecord &observer, WVObservationBatch &output) {
  return legacyBatch(*this, observer, WVObservationBatchKind::initial, output);
}

WVKernelStatus WVObserverSampleSource::observationBatch(
    const WVObserverRecord &observer, WVObservationBatch &output) {
  return legacyBatch(*this, observer, WVObservationBatchKind::event, output);
}

WVKernelStatus WVObserverSampleSource::specifications(
    const WVObserverRecord &,
    std::vector<WVObserverOutputVariableSpecification> &) {
  return invalid("Observer sample source does not provide a legacy fixed schema.");
}

WVKernelStatus WVObserverSampleSource::value(
    const WVObserverRecord &,
    const WVObserverOutputVariableSpecification &,
    WVObserverOutputValueView &) {
  return invalid("Observer sample source does not provide a legacy fixed value.");
}

} // namespace wavevortex::runtime
