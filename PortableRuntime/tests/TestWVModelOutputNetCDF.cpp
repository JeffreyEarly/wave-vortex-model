#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"
#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"
#include "WaveVortexRuntime/WVObserverOutputProvider.hpp"

#include "WVReferenceFFTEngine.hpp"
#include "WVTestQuadraticSchedule.hpp"

#include <netcdf.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;
using namespace wavevortex::runtime::test;

namespace {

void require(bool condition, const std::string &message) {
  if (!condition)
    throw std::runtime_error(message);
}

class WVTestFieldsImplementation final : public WVObservingSystem {
public:
  const std::string &typeIdentifier() const noexcept override {
    static const std::string value = "WVTestFields";
    return value;
  }
  std::uint32_t contractVersion() const noexcept override { return 1; }
  WVKernelStatus executionPlan(const WVObserverRecord &record,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.fieldListAttribute = "fieldNames";
    plan.outputFields = record.fieldNames;
    for (const auto *family : {"Ap", "Am", "A0"})
      if (std::find(record.fieldNames.begin(), record.fieldNames.end(),
                    family) != record.fieldNames.end())
        plan.coefficientRestartFamilies.emplace_back(family);
    return WVKernelStatus::ok();
  }
  WVKernelStatus outputPlan(
      const WVObserverRecord &record,
      const WVObserverOutputPlanningContext &context,
      WVObserverOutputPlan &plan) const override {
    if (context.configuration == nullptr)
      return {WVKernelStatusCode::invalidConfiguration,
              "Test field output requires a transform configuration."};
    WVObserverOutputPlan candidate;
    candidate.schema.identifier =
        "legacy-" + record.identifier + "-observation-v1";
    candidate.schema.preservesLegacyEncoding = true;
    candidate.schema.metadata.attributes = {
        {"AnnotatedClass", typeIdentifier()},
        {"portableIdentifier", record.identifier}};
    candidate.schema.metadata.stringListAttributes = {
        {"fieldNames", record.fieldNames}};
    for (const auto &field : record.fieldNames) {
      const auto *metadata = findPortableVariable(field);
      if (metadata == nullptr)
        return {WVKernelStatusCode::invalidConfiguration,
                "Test field output is unsupported."};
      std::vector<std::string> names;
      for (std::size_t dimension = 0; dimension < metadata->dimensionCount;
           ++dimension)
        names.emplace_back(metadata->dimensions[dimension]);
      std::vector<std::size_t> extents;
      WVObserverOutputChannel channel;
      channel.sourceIdentifier = field;
      if (metadata->kind == WVPortableVariableKind::coefficient) {
        WVTransformConstantStratificationDescriptor transform;
        auto status = WVTransformConstantStratificationDescriptor::create(
            *context.configuration, transform);
        if (!status)
          return status;
        extents = {context.configuration->Nj, transform.Nkl()};
        channel.source = WVObserverOutputChannelSource::coefficient;
        channel.coefficientFamily =
            metadata->identifier == WVPortableVariable::Ap
                ? 0
                : metadata->identifier == WVPortableVariable::Am ? 1 : 2;
      } else {
        channel.source = WVObserverOutputChannelSource::sampledField;
        if (metadata->naturalRank == WVPortableNaturalRank::vertical)
          extents = {context.configuration->Nz};
        else if (metadata->naturalRank == WVPortableNaturalRank::horizontal)
          extents = {context.configuration->Nx, context.configuration->Ny};
        else if (metadata->naturalRank == WVPortableNaturalRank::scalar)
          extents = {};
        else
          extents = {context.configuration->Nx, context.configuration->Ny,
                     context.configuration->Nz};
      }
      for (std::size_t index = 0; index < names.size(); ++index) {
        const auto found = std::find_if(
            candidate.schema.axes.begin(), candidate.schema.axes.end(),
            [&](const auto &axis) { return axis.identifier == names[index]; });
        if (found == candidate.schema.axes.end())
          candidate.schema.axes.push_back(
              {names[index], names[index], WVObservationAxisKind::fixed,
               extents[index], WVObservationCoordinateRole::none});
      }
      WVObservationVariable variable;
      variable.identifier = "derived-" + field;
      variable.name = field;
      variable.scalarType =
          metadata->kind == WVPortableVariableKind::coefficient
              ? WVObservationScalarType::complex64
              : WVObservationScalarType::real64;
      variable.dimensionIdentifiers = names;
      variable.layout =
          context.isDynamicsLinear &&
                  !metadata->isVariableWithLinearTimeStep
              ? WVObservationValueLayout::initialValue
              : WVObservationValueLayout::record;
      variable.units = metadata->units;
      variable.description = metadata->description;
      channel.variableIdentifier = variable.identifier;
      candidate.schema.variables.push_back(std::move(variable));
      candidate.channels.push_back(std::move(channel));
    }
    plan = std::move(candidate);
    return WVKernelStatus::ok();
  }
  WVKernelStatus
  validate(const WVObserverRecord &record,
           const std::map<std::string, const WVStateBlockRecord *> &,
           std::map<std::string, std::size_t> &) const override {
    return record.stateBlockIdentifiers.empty()
               ? WVKernelStatus::ok()
               : WVKernelStatus{WVKernelStatusCode::invalidConfiguration,
                                "Test fields cannot own state blocks."};
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }
};

class WVTestPortablePointDiagnosticImplementation final
    : public WVObservingSystem {
public:
  const std::string &typeIdentifier() const noexcept override {
    static const std::string value = "WVTestPortablePointDiagnostic";
    return value;
  }
  std::uint32_t contractVersion() const noexcept override { return 1; }
  WVKernelStatus executionPlan(const WVObserverRecord &record,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.sampling = WVObserverSamplingTopology::fixedPositions;
    plan.fieldListAttribute = "fieldNames";
    plan.persistedName = record.name;
    plan.outputFields = record.fieldNames;
    return WVKernelStatus::ok();
  }
  WVKernelStatus outputPlan(
      const WVObserverRecord &record,
      const WVObserverOutputPlanningContext &context,
      WVObserverOutputPlan &plan) const override {
    if (context.configuration == nullptr || record.fieldNames.size() != 1)
      return {WVKernelStatusCode::invalidConfiguration,
              "Point diagnostic output planning is invalid."};
    const auto *metadata = findPortableVariable(record.fieldNames.front());
    if (metadata == nullptr ||
        metadata->kind != WVPortableVariableKind::field)
      return {WVKernelStatusCode::invalidConfiguration,
              "Point diagnostic field is unsupported."};
    WVObserverOutputPlan candidate;
    candidate.schema.identifier =
        "legacy-" + record.identifier + "-observation-v1";
    candidate.schema.preservesLegacyEncoding = true;
    candidate.schema.metadata.attributes = {
        {"AnnotatedClass", typeIdentifier()},
        {"portableIdentifier", record.identifier}, {"name", record.name},
        {"trackedVarInterpolation", "linear"}};
    candidate.schema.metadata.stringListAttributes = {
        {"fieldNames", record.fieldNames}};
    candidate.schema.metadata.variables.push_back(
        {"outputScale",
         WVObservationValue::ownReal("outputScale", {}, {record.outputScale}),
         false});
    candidate.schema.metadata.variables.push_back(
        {"outputOffset",
         WVObservationValue::ownReal("outputOffset", {}, {record.outputOffset}),
         false});
    const std::string idName = record.name + "_id";
    candidate.schema.axes.push_back(
        {idName, idName, WVObservationAxisKind::fixed, record.x.size(),
         WVObservationCoordinateRole::identifier});
    const auto addConstant = [&](std::string identifier, std::string name,
                                 const std::vector<double> &values,
                                 WVObservationCoordinateRole role,
                                 std::string description) {
      candidate.schema.variables.push_back(
          {identifier, std::move(name), WVObservationScalarType::real64,
           {idName}, WVObservationValueLayout::staticValue, "m",
           std::move(description), {}, role,
           WVObservationRaggedRole::none, {}});
      candidate.constantValues.push_back(WVObservationValue::ownReal(
          std::move(identifier), {values.size()}, values));
    };
    std::vector<double> identifiers(record.x.size());
    for (std::size_t index = 0; index < identifiers.size(); ++index)
      identifiers[index] = static_cast<double>(index + 1);
    addConstant("static-" + idName, idName, identifiers,
                WVObservationCoordinateRole::identifier, "");
    addConstant("static-x", record.name + "_x", record.x,
                WVObservationCoordinateRole::x,
                "x position of fixed observation");
    addConstant("static-y", record.name + "_y", record.y,
                WVObservationCoordinateRole::y,
                "y position of fixed observation");
    addConstant("static-z", record.name + "_z", record.z,
                WVObservationCoordinateRole::z,
                "z position of fixed observation");
    WVObservationVariable value;
    value.identifier = "derived-" + record.fieldNames.front();
    value.name = record.name + "_value";
    value.dimensionIdentifiers = {idName};
    value.layout =
        context.isDynamicsLinear && !metadata->isVariableWithLinearTimeStep
            ? WVObservationValueLayout::initialValue
            : WVObservationValueLayout::record;
    value.units = metadata->units;
    value.description = std::string(metadata->description) +
                        ", sampled and affinely transformed by the observing system";
    candidate.schema.variables.push_back(value);
    WVObserverOutputChannel channel;
    channel.variableIdentifier = value.identifier;
    channel.source = WVObserverOutputChannelSource::sampledField;
    channel.sourceIdentifier = record.fieldNames.front();
    channel.sampling.kind = WVFieldSamplingKind::positions;
    channel.sampling.x = record.x;
    channel.sampling.y = record.y;
    channel.sampling.z = record.z;
    channel.scale = record.outputScale;
    channel.offset = record.outputOffset;
    candidate.channels.push_back(std::move(channel));
    plan = std::move(candidate);
    return WVKernelStatus::ok();
  }
  WVKernelStatus
  validate(const WVObserverRecord &record,
           const std::map<std::string, const WVStateBlockRecord *> &,
           std::map<std::string, std::size_t> &) const override {
    if (!record.stateBlockIdentifiers.empty() ||
        record.fieldNames.size() != 1 || record.x.empty() ||
        record.x.size() != record.y.size() ||
        record.x.size() != record.z.size() ||
        !std::isfinite(record.outputScale) ||
        !std::isfinite(record.outputOffset))
      return {WVKernelStatusCode::invalidConfiguration,
              "Point diagnostic configuration is invalid."};
    return WVKernelStatus::ok();
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }
};

class WVTestObservationBatchesImplementation final : public WVObservingSystem {
public:
  const std::string &typeIdentifier() const noexcept override {
    static const std::string value = "WVTestObservationBatches";
    return value;
  }
  std::uint32_t contractVersion() const noexcept override { return 1; }
  WVKernelStatus executionPlan(const WVObserverRecord &record,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    plan.persistedName = record.name;
    return WVKernelStatus::ok();
  }
  WVKernelStatus outputPlan(
      const WVObserverRecord &record,
      const WVObserverOutputPlanningContext &,
      WVObserverOutputPlan &output) const override {
    WVObserverOutputPlan plan;
    plan.schema.identifier = "synthetic-variable-observation";
    plan.schema.metadata.attributes = {
        {"AnnotatedClass", record.typeIdentifier},
        {"portableIdentifier", record.identifier}, {"name", record.name}};
    plan.schema.axes = {
        {"depth", "synthetic_depth", WVObservationAxisKind::fixed, 2,
         WVObservationCoordinateRole::depth},
        {"profile", "synthetic_profile", WVObservationAxisKind::unlimited, 0,
         WVObservationCoordinateRole::profile},
        {"sample", "synthetic_sample", WVObservationAxisKind::unlimited, 0,
         WVObservationCoordinateRole::identifier}};
    plan.schema.variables = {
        {"depth", "synthetic_depth", WVObservationScalarType::real64,
         {"depth"}, WVObservationValueLayout::staticValue, "m",
         "fixed depth-bin axis", {}, WVObservationCoordinateRole::depth,
         WVObservationRaggedRole::none, {}},
        {"profile-id", "synthetic_profile_id",
         WVObservationScalarType::integer64, {"profile"},
         WVObservationValueLayout::flat, "1", "profile identifier", {},
         WVObservationCoordinateRole::profile,
         WVObservationRaggedRole::none, {}},
        {"row-count", "synthetic_row_count",
         WVObservationScalarType::integer64, {"profile"},
         WVObservationValueLayout::flat, "1", "samples in each profile", {},
         WVObservationCoordinateRole::none,
         WVObservationRaggedRole::rowCount, "sample"},
        {"time", "synthetic_time", WVObservationScalarType::real64,
         {"sample"}, WVObservationValueLayout::flat, "s", "sample time", {},
         WVObservationCoordinateRole::sampleTime,
         WVObservationRaggedRole::none, {}},
        {"x", "synthetic_x", WVObservationScalarType::real64, {"sample"},
         WVObservationValueLayout::flat, "m", "moving x coordinate", {},
         WVObservationCoordinateRole::x, WVObservationRaggedRole::none, {}},
        {"y", "synthetic_y", WVObservationScalarType::real64, {"sample"},
         WVObservationValueLayout::flat, "m", "moving y coordinate", {},
         WVObservationCoordinateRole::y, WVObservationRaggedRole::none, {}},
        {"z", "synthetic_z", WVObservationScalarType::real64, {"sample"},
         WVObservationValueLayout::flat, "m", "moving z coordinate", {},
         WVObservationCoordinateRole::z, WVObservationRaggedRole::none, {}},
        {"bins", "synthetic_bins", WVObservationScalarType::complex64,
         {"depth", "sample"}, WVObservationValueLayout::flat, "m s-1",
         "fixed-depth-bin samples", {{"provider", "fixed-bin"}},
         WVObservationCoordinateRole::none, WVObservationRaggedRole::none, {}},
        {"valid", "synthetic_valid", WVObservationScalarType::boolean8,
         {"sample"}, WVObservationValueLayout::flat, "1", "sample validity",
         {}, WVObservationCoordinateRole::none,
         WVObservationRaggedRole::none, {}},
        {"label", "synthetic_label", WVObservationScalarType::text,
         {"profile"}, WVObservationValueLayout::flat, "", "profile label",
         {}, WVObservationCoordinateRole::none,
         WVObservationRaggedRole::none, {}},
        {"pass", "synthetic_pass", WVObservationScalarType::integer64, {},
         WVObservationValueLayout::record, "1", "pass identifier", {},
         WVObservationCoordinateRole::pass,
         WVObservationRaggedRole::none, {}}};
    plan.constantValues.push_back(WVObservationValue::ownReal(
        "depth", {2}, std::vector<double>{-10.0, -20.0}));
    output = std::move(plan);
    return WVKernelStatus::ok();
  }
  WVKernelStatus observationBatch(
      const WVObserverRecord &record, const WVObserverOutputPlan &plan,
      const WVObserverOutputEvaluationContext &context,
      WVObservationBatchKind kind, WVObservationBatch &output) const override {
    if (kind == WVObservationBatchKind::initial)
      return WVObservingSystem::observationBatch(record, plan, context, kind,
                                                  output);
    ++batchCounts_[record.identifier];
    const bool empty = context.eventOrdinal() % 2 == 1;
    const std::size_t profileCount = empty ? 0 : 2;
    const std::size_t sampleCount = empty ? 0 : 3;
    WVObservationBatch batch;
    batch.schemaIdentifier = plan.schema.identifier;
    batch.schemaVersion = plan.schema.version;
    batch.values.push_back(WVObservationValue::ownInteger(
        "profile-id", {profileCount},
        empty ? std::vector<std::int64_t>{}
              : std::vector<std::int64_t>{10, 11}));
    batch.values.push_back(WVObservationValue::ownInteger(
        "row-count", {profileCount},
        empty ? std::vector<std::int64_t>{}
              : std::vector<std::int64_t>{1, 2}));
    batch.values.push_back(WVObservationValue::ownReal(
        "time", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{context.scheduledTime(),
                                    context.scheduledTime() + 0.1,
                                    context.scheduledTime() + 0.2}));
    batch.values.push_back(WVObservationValue::ownReal(
        "x", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{1.0, 2.0, 3.0}));
    batch.values.push_back(WVObservationValue::ownReal(
        "y", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{4.0, 5.0, 6.0}));
    batch.values.push_back(WVObservationValue::ownReal(
        "z", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{-1.0, -2.0, -3.0}));
    batch.values.push_back(WVObservationValue::ownComplex(
        "bins", {2, sampleCount},
        empty ? std::vector<WVComplex64>{}
              : std::vector<WVComplex64>{{1.0, -1.0}, {2.0, -2.0},
                                         {3.0, -3.0}, {4.0, -4.0},
                                         {5.0, -5.0}, {6.0, -6.0}}));
    batch.values.push_back(WVObservationValue::ownBoolean(
        "valid", {sampleCount},
        empty ? std::vector<std::uint8_t>{}
              : std::vector<std::uint8_t>{1, 0, 1}));
    batch.values.push_back(WVObservationValue::ownText(
        "label", {profileCount},
        empty ? std::vector<std::string>{}
              : std::vector<std::string>{"pass-a", "pass-b"}));
    batch.values.push_back(WVObservationValue::ownInteger(
        "pass", {}, {static_cast<std::int64_t>(context.eventOrdinal())}));
    output = std::move(batch);
    return WVKernelStatus::ok();
  }
  WVKernelStatus
  validate(const WVObserverRecord &record,
           const std::map<std::string, const WVStateBlockRecord *> &,
           std::map<std::string, std::size_t> &) const override {
    return record.stateBlockIdentifiers.empty()
               ? WVKernelStatus::ok()
               : WVKernelStatus{WVKernelStatusCode::invalidConfiguration,
                                "Synthetic batches cannot own state blocks."};
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }
  std::size_t batchCount(const std::string &identifier) const {
    const auto found = batchCounts_.find(identifier);
    return found == batchCounts_.end() ? 0 : found->second;
  }
  void resetCounts() const { batchCounts_.clear(); }

private:
  mutable std::map<std::string, std::size_t> batchCounts_;
};

std::shared_ptr<WVTestObservationBatchesImplementation> registeredBatches;

enum class TestTopology { fixedBin, movingTrack, variablePass, raggedProfile };

class WVTestTopologyImplementation final : public WVObservingSystem {
public:
  WVTestTopologyImplementation(std::string identifier, TestTopology topology)
      : identifier_(std::move(identifier)), topology_(topology) {}
  const std::string &typeIdentifier() const noexcept override {
    return identifier_;
  }
  std::uint32_t contractVersion() const noexcept override { return 1; }
  WVKernelStatus executionPlan(const WVObserverRecord &,
                               WVObserverExecutionPlan &plan) const override {
    plan = {};
    return WVKernelStatus::ok();
  }
  WVKernelStatus validate(
      const WVObserverRecord &record,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    return record.stateBlockIdentifiers.empty()
               ? WVKernelStatus::ok()
               : WVKernelStatus{WVKernelStatusCode::invalidConfiguration,
                                "Test topology providers are sample-only."};
  }
  WVKernelStatus outputPlan(
      const WVObserverRecord &record,
      const WVObserverOutputPlanningContext &,
      WVObserverOutputPlan &output) const override {
    WVObserverOutputPlan plan;
    plan.schema.identifier = schemaIdentifier();
    plan.schema.metadata.attributes = {
        {"AnnotatedClass", identifier_},
        {"portableIdentifier", record.identifier}, {"name", record.name}};
    if (topology_ == TestTopology::fixedBin) {
      plan.schema.axes = {
          {"depth", "fixed_bin_depth", WVObservationAxisKind::fixed, 3,
           WVObservationCoordinateRole::depth}};
      plan.schema.variables = {
          {"depth", "fixed_bin_depth", WVObservationScalarType::real64,
           {"depth"}, WVObservationValueLayout::staticValue, "m",
           "fixed depth bins", {}, WVObservationCoordinateRole::depth,
           WVObservationRaggedRole::none, {}},
          {"value", "fixed_bin_value", WVObservationScalarType::complex64,
           {"depth"}, WVObservationValueLayout::record, "m s-1",
           "fixed-bin values", {{"ordered-a", "1"}, {"ordered-b", "2"}},
           WVObservationCoordinateRole::none,
           WVObservationRaggedRole::none, {}}};
      plan.constantValues.push_back(WVObservationValue::ownReal(
          "depth", {3}, {-5.0, -15.0, -25.0}));
    } else if (topology_ == TestTopology::movingTrack) {
      plan.schema.axes = {
          {"sample", "moving_track_sample",
           WVObservationAxisKind::unlimited, 0,
           WVObservationCoordinateRole::identifier}};
      plan.schema.variables = {
          {"time", "moving_track_time", WVObservationScalarType::real64,
           {"sample"}, WVObservationValueLayout::flat, "s", "sample time",
           {}, WVObservationCoordinateRole::sampleTime,
           WVObservationRaggedRole::none, {}},
          {"x", "moving_track_x", WVObservationScalarType::real64,
           {"sample"}, WVObservationValueLayout::flat, "m", "moving x", {},
           WVObservationCoordinateRole::x, WVObservationRaggedRole::none, {}},
          {"y", "moving_track_y", WVObservationScalarType::real64,
           {"sample"}, WVObservationValueLayout::flat, "m", "moving y", {},
           WVObservationCoordinateRole::y, WVObservationRaggedRole::none, {}},
          {"z", "moving_track_z", WVObservationScalarType::real64,
           {"sample"}, WVObservationValueLayout::flat, "m", "moving z", {},
           WVObservationCoordinateRole::z, WVObservationRaggedRole::none, {}}};
    } else if (topology_ == TestTopology::variablePass) {
      plan.schema.axes = {
          {"pass", "variable_pass", WVObservationAxisKind::unlimited, 0,
           WVObservationCoordinateRole::pass}};
      plan.schema.variables = {
          {"pass", "variable_pass_id", WVObservationScalarType::integer64,
           {"pass"}, WVObservationValueLayout::flat, "1", "pass id", {},
           WVObservationCoordinateRole::pass,
           WVObservationRaggedRole::none, {}},
          {"label", "variable_pass_label", WVObservationScalarType::text,
           {"pass"}, WVObservationValueLayout::flat, "", "pass label", {},
           WVObservationCoordinateRole::none,
           WVObservationRaggedRole::none, {}}};
    } else {
      plan.schema.axes = {
          {"profile", "ragged_profile", WVObservationAxisKind::unlimited, 0,
           WVObservationCoordinateRole::profile},
          {"sample", "ragged_sample", WVObservationAxisKind::unlimited, 0,
           WVObservationCoordinateRole::identifier}};
      plan.schema.variables = {
          {"profile", "ragged_profile_id",
           WVObservationScalarType::integer64, {"profile"},
           WVObservationValueLayout::flat, "1", "profile id", {},
           WVObservationCoordinateRole::profile,
           WVObservationRaggedRole::none, {}},
          {"row-count", "ragged_row_count",
           WVObservationScalarType::integer64, {"profile"},
           WVObservationValueLayout::flat, "1", "row count", {},
           WVObservationCoordinateRole::none,
           WVObservationRaggedRole::rowCount, "sample"},
          {"value", "ragged_value", WVObservationScalarType::real64,
           {"sample"}, WVObservationValueLayout::flat, "1", "sample value",
           {}, WVObservationCoordinateRole::none,
           WVObservationRaggedRole::none, {}}};
    }
    output = std::move(plan);
    return WVKernelStatus::ok();
  }
  WVKernelStatus observationBatch(
      const WVObserverRecord &record, const WVObserverOutputPlan &plan,
      const WVObserverOutputEvaluationContext &context,
      WVObservationBatchKind kind, WVObservationBatch &output) const override {
    if (kind == WVObservationBatchKind::initial)
      return WVObservingSystem::observationBatch(record, plan, context, kind,
                                                  output);
    ++batchCounts_[record.identifier];
    WVObservationBatch batch;
    batch.schemaIdentifier = plan.schema.identifier;
    batch.schemaVersion = plan.schema.version;
    if (topology_ == TestTopology::fixedBin) {
      batch.values.push_back(WVObservationValue::ownComplex(
          "value", {3}, {{1.0, -1.0}, {2.0, -2.0}, {3.0, -3.0}}));
    } else if (topology_ == TestTopology::movingTrack) {
      const std::size_t count = context.eventOrdinal() % 2 == 0 ? 2 : 1;
      batch.values.push_back(WVObservationValue::ownReal(
          "time", {count},
          count == 2 ? std::vector<double>{context.scheduledTime(),
                                           context.scheduledTime() + 0.25}
                     : std::vector<double>{context.scheduledTime()}));
      batch.values.push_back(WVObservationValue::ownReal(
          "x", {count}, count == 2 ? std::vector<double>{1.0, 2.0}
                                     : std::vector<double>{3.0}));
      batch.values.push_back(WVObservationValue::ownReal(
          "y", {count}, count == 2 ? std::vector<double>{4.0, 5.0}
                                     : std::vector<double>{6.0}));
      batch.values.push_back(WVObservationValue::ownReal(
          "z", {count}, count == 2 ? std::vector<double>{-1.0, -2.0}
                                     : std::vector<double>{-3.0}));
    } else if (topology_ == TestTopology::variablePass) {
      const std::size_t count = context.eventOrdinal() % 2 == 0 ? 2 : 1;
      batch.values.push_back(WVObservationValue::ownInteger(
          "pass", {count}, count == 2 ? std::vector<std::int64_t>{7, 8}
                                       : std::vector<std::int64_t>{9}));
      batch.values.push_back(WVObservationValue::ownText(
          "label", {count}, count == 2
                                ? std::vector<std::string>{"out", "back"}
                                : std::vector<std::string>{"final"}));
    } else {
      const bool malformed = record.name == "malformed";
      batch.values.push_back(WVObservationValue::ownInteger(
          "profile", {2}, {1, 2}));
      batch.values.push_back(WVObservationValue::ownInteger(
          "row-count", {2}, malformed ? std::vector<std::int64_t>{2, 2}
                                        : std::vector<std::int64_t>{1, 2}));
      batch.values.push_back(WVObservationValue::ownReal(
          "value", {3}, {10.0, 20.0, 30.0}));
    }
    output = std::move(batch);
    return WVKernelStatus::ok();
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this) + identifier_.capacity();
  }
  std::size_t batchCount(const std::string &identifier) const {
    const auto found = batchCounts_.find(identifier);
    return found == batchCounts_.end() ? 0 : found->second;
  }
  void resetCounts() const { batchCounts_.clear(); }

private:
  std::string schemaIdentifier() const {
    if (topology_ == TestTopology::fixedBin)
      return "test-fixed-bin-v1";
    if (topology_ == TestTopology::movingTrack)
      return "test-moving-track-v1";
    if (topology_ == TestTopology::variablePass)
      return "test-variable-pass-v1";
    return "test-ragged-profile-v1";
  }
  std::string identifier_;
  TestTopology topology_;
  mutable std::map<std::string, std::size_t> batchCounts_;
};

std::shared_ptr<WVTestTopologyImplementation> fixedBinProvider;
std::shared_ptr<WVTestTopologyImplementation> movingTrackProvider;
std::shared_ptr<WVTestTopologyImplementation> variablePassProvider;
std::shared_ptr<WVTestTopologyImplementation> raggedProfileProvider;

class VariableBatchSource final : public WVObserverSampleSource {
public:
  explicit VariableBatchSource(std::uint32_t version = 1,
                               bool failFirstBatch = false)
      : version_(version), failFirstBatch_(failFirstBatch) {}

  WVKernelStatus observationSchema(const WVObserverRecord &observer,
                                   WVObservationSchema &output) override {
    WVObservationSchema schema;
    if (observer.typeIdentifier != "WVTestObservationBatches") {
      schema.identifier = "legacy-coefficient-observation-v1";
      schema.preservesLegacyEncoding = true;
      schema.metadata.attributes = {{"AnnotatedClass", observer.typeIdentifier},
                                    {"portableIdentifier", observer.identifier},
                                    {"name", observer.name}};
      WVObservationMetadataVariable tolerance;
      tolerance.name = "absTolerance";
      tolerance.value =
          WVObservationValue::ownReal("absTolerance", {}, {1e-6});
      schema.metadata.variables.push_back(std::move(tolerance));
      output = std::move(schema);
      return WVKernelStatus::ok();
    }
    schema.identifier = "synthetic-variable-observation";
    schema.version = version_;
    schema.metadata.attributes = {{"AnnotatedClass", observer.typeIdentifier},
                                  {"portableIdentifier", observer.identifier},
                                  {"name", observer.name}};
    schema.axes = {
        {"depth", "synthetic_depth", WVObservationAxisKind::fixed, 2,
         WVObservationCoordinateRole::depth},
        {"profile", "synthetic_profile", WVObservationAxisKind::unlimited, 0,
         WVObservationCoordinateRole::profile},
        {"sample", "synthetic_sample", WVObservationAxisKind::unlimited, 0,
         WVObservationCoordinateRole::identifier}};
    schema.variables = {
        {"depth", "synthetic_depth", WVObservationScalarType::real64,
         {"depth"}, WVObservationValueLayout::staticValue, "m",
         "fixed depth-bin axis", {}, WVObservationCoordinateRole::depth,
         WVObservationRaggedRole::none, {}},
        {"profile-id", "synthetic_profile_id",
         WVObservationScalarType::integer64, {"profile"},
         WVObservationValueLayout::flat, "1", "profile identifier", {},
         WVObservationCoordinateRole::profile,
         WVObservationRaggedRole::none, {}},
        {"row-count", "synthetic_row_count",
         WVObservationScalarType::integer64, {"profile"},
         WVObservationValueLayout::flat, "1", "samples in each profile", {},
         WVObservationCoordinateRole::none,
         WVObservationRaggedRole::rowCount, "sample"},
        {"time", "synthetic_time", WVObservationScalarType::real64,
         {"sample"}, WVObservationValueLayout::flat, "s", "sample time", {},
         WVObservationCoordinateRole::sampleTime,
         WVObservationRaggedRole::none, {}},
        {"x", "synthetic_x", WVObservationScalarType::real64, {"sample"},
         WVObservationValueLayout::flat, "m", "moving x coordinate", {},
         WVObservationCoordinateRole::x, WVObservationRaggedRole::none, {}},
        {"y", "synthetic_y", WVObservationScalarType::real64, {"sample"},
         WVObservationValueLayout::flat, "m", "moving y coordinate", {},
         WVObservationCoordinateRole::y, WVObservationRaggedRole::none, {}},
        {"z", "synthetic_z", WVObservationScalarType::real64, {"sample"},
         WVObservationValueLayout::flat, "m", "moving z coordinate", {},
         WVObservationCoordinateRole::z, WVObservationRaggedRole::none, {}},
        {"bins", "synthetic_bins", WVObservationScalarType::complex64,
         {"depth", "sample"}, WVObservationValueLayout::flat, "m s-1",
         "fixed-depth-bin samples", {}, WVObservationCoordinateRole::none,
         WVObservationRaggedRole::none, {}},
        {"valid", "synthetic_valid", WVObservationScalarType::boolean8,
         {"sample"}, WVObservationValueLayout::flat, "1", "sample validity",
         {}, WVObservationCoordinateRole::none,
         WVObservationRaggedRole::none, {}},
        {"label", "synthetic_label", WVObservationScalarType::text,
         {"profile"}, WVObservationValueLayout::flat, "", "profile label",
         {}, WVObservationCoordinateRole::none,
         WVObservationRaggedRole::none, {}},
        {"pass", "synthetic_pass", WVObservationScalarType::integer64, {},
         WVObservationValueLayout::record, "1", "pass identifier", {},
         WVObservationCoordinateRole::pass,
         WVObservationRaggedRole::none, {}}};
    output = std::move(schema);
    return WVKernelStatus::ok();
  }

  WVKernelStatus initialObservationBatch(
      const WVObserverRecord &observer, WVObservationBatch &output) override {
    WVObservationSchema schema;
    auto status = observationSchema(observer, schema);
    if (!status)
      return status;
    WVObservationBatch batch;
    batch.schemaIdentifier = schema.identifier;
    batch.schemaVersion = schema.version;
    batch.kind = WVObservationBatchKind::initial;
    if (observer.typeIdentifier == "WVTestObservationBatches")
      batch.values.push_back(WVObservationValue::ownReal(
          "depth", {2}, std::vector<double>{-10.0, -20.0}));
    output = std::move(batch);
    return WVKernelStatus::ok();
  }

  WVKernelStatus prepare(const WVOutputEvent &event) override {
    ++prepareCount_;
    eventOrdinal_ = event.eventOrdinal;
    scheduledTime_ = event.scheduledTime;
    return WVKernelStatus::ok();
  }

  WVKernelStatus observationBatch(const WVObserverRecord &observer,
                                  WVObservationBatch &output) override {
    ++batchCounts_[observer.identifier];
    WVObservationSchema schema;
    auto status = observationSchema(observer, schema);
    if (!status)
      return status;
    WVObservationBatch batch;
    batch.schemaIdentifier = schema.identifier;
    batch.schemaVersion = schema.version;
    if (observer.typeIdentifier != "WVTestObservationBatches") {
      output = std::move(batch);
      return WVKernelStatus::ok();
    }
    const bool empty = eventOrdinal_ % 2 == 1;
    const std::size_t profileCount = empty ? 0 : 2;
    const std::size_t sampleCount = empty ? 0 : 3;
    batch.values.push_back(WVObservationValue::ownInteger(
        "profile-id", {profileCount},
        empty ? std::vector<std::int64_t>{}
              : std::vector<std::int64_t>{10, 11}));
    batch.values.push_back(WVObservationValue::ownInteger(
        "row-count", {profileCount},
        empty ? std::vector<std::int64_t>{}
              : failFirstBatch_ && !failedOnce_
                    ? std::vector<std::int64_t>{2, 2}
                    : std::vector<std::int64_t>{1, 2}));
    batch.values.push_back(WVObservationValue::ownReal(
        "time", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{scheduledTime_, scheduledTime_ + 0.1,
                                    scheduledTime_ + 0.2}));
    batch.values.push_back(WVObservationValue::ownReal(
        "x", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{1.0, 2.0, 3.0}));
    batch.values.push_back(WVObservationValue::ownReal(
        "y", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{4.0, 5.0, 6.0}));
    batch.values.push_back(WVObservationValue::ownReal(
        "z", {sampleCount},
        empty ? std::vector<double>{}
              : std::vector<double>{-1.0, -2.0, -3.0}));
    batch.values.push_back(WVObservationValue::ownComplex(
        "bins", {2, sampleCount},
        empty ? std::vector<WVComplex64>{}
              : std::vector<WVComplex64>{{1.0, -1.0}, {2.0, -2.0},
                                         {3.0, -3.0}, {4.0, -4.0},
                                         {5.0, -5.0}, {6.0, -6.0}}));
    batch.values.push_back(WVObservationValue::ownBoolean(
        "valid", {sampleCount},
        empty ? std::vector<std::uint8_t>{}
              : std::vector<std::uint8_t>{1, 0, 1}));
    batch.values.push_back(WVObservationValue::ownText(
        "label", {profileCount},
        empty ? std::vector<std::string>{}
              : std::vector<std::string>{"pass-a", "pass-b"}));
    batch.values.push_back(WVObservationValue::ownInteger(
        "pass", {},
        std::vector<std::int64_t>{static_cast<std::int64_t>(eventOrdinal_)}));
    if (failFirstBatch_ && !failedOnce_)
      failedOnce_ = true;
    output = std::move(batch);
    return WVKernelStatus::ok();
  }

  std::size_t prepareCount() const noexcept { return prepareCount_; }

  std::size_t batchCount(const std::string &observerIdentifier) const {
    const auto found = batchCounts_.find(observerIdentifier);
    return found == batchCounts_.end() ? 0 : found->second;
  }

private:
  std::uint32_t version_ = 1;
  bool failFirstBatch_ = false;
  bool failedOnce_ = false;
  std::size_t eventOrdinal_ = 0;
  double scheduledTime_ = 0.0;
  std::size_t prepareCount_ = 0;
  std::map<std::string, std::size_t> batchCounts_;
};

class ConflictingSchemaSource final : public WVObserverSampleSource {
public:
  explicit ConflictingSchemaSource(bool conflictingAxis,
                                   bool conflictingRole = false)
      : conflictingAxis_(conflictingAxis),
        conflictingRole_(conflictingRole) {}
  WVKernelStatus observationSchema(const WVObserverRecord &observer,
                                   WVObservationSchema &output) override {
    WVObservationSchema schema;
    if (observer.typeIdentifier != "WVTestObservationBatches") {
      schema.identifier = "legacy-coefficient-observation-v1";
      schema.preservesLegacyEncoding = true;
      output = std::move(schema);
      return WVKernelStatus::ok();
    }
    schema.identifier = "conflict-" + observer.identifier;
    const std::size_t extent =
        conflictingAxis_ && !conflictingRole_ &&
                observer.identifier == "conflict-b"
            ? 3
            : 2;
    const auto role =
        conflictingRole_ && observer.identifier == "conflict-b"
            ? WVObservationCoordinateRole::depth
            : WVObservationCoordinateRole::identifier;
    schema.axes = {{"shared", "shared_axis", WVObservationAxisKind::fixed,
                    extent, role}};
    schema.variables = {
        {"value",
         conflictingAxis_ ? observer.identifier + "_value" : "shared_value",
         WVObservationScalarType::real64, {"shared"},
         WVObservationValueLayout::record, "1", "conflict probe", {},
         WVObservationCoordinateRole::none,
         WVObservationRaggedRole::none, {}}};
    output = std::move(schema);
    return WVKernelStatus::ok();
  }
  WVKernelStatus initialObservationBatch(
      const WVObserverRecord &observer, WVObservationBatch &output) override {
    WVObservationSchema schema;
    auto status = observationSchema(observer, schema);
    if (!status)
      return status;
    WVObservationBatch batch;
    batch.schemaIdentifier = schema.identifier;
    batch.schemaVersion = schema.version;
    batch.kind = WVObservationBatchKind::initial;
    output = std::move(batch);
    return WVKernelStatus::ok();
  }
  WVKernelStatus prepare(const WVOutputEvent &) override {
    return WVKernelStatus::ok();
  }
  WVKernelStatus observationBatch(const WVObserverRecord &observer,
                                  WVObservationBatch &output) override {
    WVObservationSchema schema;
    auto status = observationSchema(observer, schema);
    if (!status)
      return status;
    WVObservationBatch batch;
    batch.schemaIdentifier = schema.identifier;
    batch.schemaVersion = schema.version;
    const auto extent = schema.axes.empty() ? 0 : schema.axes.front().extent;
    if (!schema.variables.empty())
      batch.values.push_back(WVObservationValue::ownReal(
          "value", {extent}, std::vector<double>(extent, 0.0)));
    output = std::move(batch);
    return WVKernelStatus::ok();
  }

private:
  bool conflictingAxis_ = false;
  bool conflictingRole_ = false;
};

std::filesystem::path fixture(const std::string &name) {
  return std::filesystem::path(WV_CHECKPOINT_FIXTURE_DIR) / name;
}

std::string shellQuote(const std::filesystem::path &path) {
  std::string result = "'";
  for (const auto character : path.string())
    result += character == '\'' ? "'\\''" : std::string(1, character);
  return result + "'";
}

std::vector<char> fileBytes(const std::filesystem::path &path) {
  std::ifstream input(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(input),
          std::istreambuf_iterator<char>()};
}

struct TemporaryDirectory {
  std::filesystem::path path =
      std::filesystem::temp_directory_path() /
      ("wave-vortex-model-output-" +
       std::to_string(
           std::chrono::steady_clock::now().time_since_epoch().count()));
  TemporaryDirectory() { std::filesystem::create_directories(path); }
  ~TemporaryDirectory() {
    if (std::getenv("WV_KEEP_MODEL_OUTPUT_FIXTURE") != nullptr) {
      std::cout << "Retained model-output fixture at " << path << '\n';
      return;
    }
    std::error_code ignored;
    std::filesystem::remove_all(path, ignored);
  }
};

WVCheckpoint checkpointTemplate() {
  WVCheckpoint checkpoint;
  const char *overridePath = std::getenv("WV_RUNTIME_CHECKPOINT_FIXTURE");
  const auto path = overridePath == nullptr
                        ? fixture("forcing-nonlinear.nc").string()
                        : std::string(overridePath);
  const auto result = WVCheckpointReader::read(path, checkpoint);
  require(static_cast<bool>(result), result.message);
  return checkpoint;
}

WVPortableObserverRecord recordFor(const WVCheckpoint &checkpoint,
                                   const std::filesystem::path &path) {
  WVPortableObserverRecord record;
  const std::vector<std::size_t> shape = {
      checkpoint.state.coefficients.shape.rows,
      checkpoint.state.coefficients.shape.columns};
  for (const auto *name : {"Ap", "Am", "A0"})
    record.stateBlocks.push_back({name, WVStateScalarType::complex64, shape,
                                  WVToleranceKind::coefficientEnergyScaled,
                                  1e-6, WVStateOwnership::integratorOwned,
                                  WVRestartRequirement::requiredDynamicState});
  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "wave-vortex coefficient flux";
  coefficients.typeIdentifier = "WVCoefficients";
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  record.observers.push_back(coefficients);
  record.outputFiles = {{"primary",
                         path.string(),
                         {{"restart",
                           "wave-vortex",
                           {1.0, checkpoint.state.t, checkpoint.state.t + 2.0},
                           {"coefficients"},
                           true}}}};
  return record;
}

WVPortableObserverDescriptor
descriptorFor(const WVPortableObserverRecord &record) {
  WVPortableObserverDescriptor descriptor;
  const auto status = WVPortableObserverDescriptor::create(record, descriptor);
  require(static_cast<bool>(status), status.message);
  return descriptor;
}

WVIntegrationState eventState(const WVCheckpoint &checkpoint) {
  return {checkpoint.state.view(), nullptr, 0};
}

class ZeroSampleSource final : public WVObserverSampleSource {
public:
  explicit ZeroSampleSource(
      WVTransformConstantStratificationConfiguration configuration)
      : configuration_(configuration) {}

  WVKernelStatus specifications(
      const WVObserverRecord &observer,
      std::vector<WVObserverOutputVariableSpecification> &output) override {
    output.clear();
    if (observer.typeIdentifier == "WVEulerianFields" &&
        std::find(observer.fieldNames.begin(), observer.fieldNames.end(),
                  "u") != observer.fieldNames.end())
      output.push_back(
          {observer.identifier + "-u",
           "u",
           WVOutputValueType::real64,
           {"x", "y", "z"},
           {configuration_.Nx, configuration_.Ny, configuration_.Nz},
           "m s-1",
           "x-component of the fluid velocity"});
    if (observer.typeIdentifier == "WVLagrangianParticles" &&
        !observer.fieldNames.empty())
      output.push_back({observer.identifier + "-u",
                        observer.name + "_u",
                        WVOutputValueType::real64,
                        {observer.name + "_id"},
                        {observer.x.size()},
                        "m s-1",
                        "x-component of the fluid velocity, recorded along "
                        "the particle trajectory"});
    if (observer.typeIdentifier == "WVMooring" && !observer.fieldNames.empty())
      output.push_back({observer.identifier + "-u",
                        observer.name + "_u",
                        WVOutputValueType::real64,
                        {observer.name + "_z", observer.name + "_id"},
                        {observer.z.size(), observer.x.size()},
                        "m s-1",
                        "x-component of the fluid velocity, recorded at the "
                        "mooring"});
    if (observer.typeIdentifier == "WVTestPortablePointDiagnostic")
      output.push_back({observer.identifier + "-value",
                        observer.name + "_value",
                        WVOutputValueType::real64,
                        {observer.name + "_id"},
                        {observer.x.size()},
                        "m s-1",
                        "affinely transformed point diagnostic"});
    return WVKernelStatus::ok();
  }

  WVKernelStatus prepare(const WVOutputEvent &) override {
    return WVKernelStatus::ok();
  }

  WVKernelStatus value(const WVObserverRecord &,
                       const WVObserverOutputVariableSpecification &variable,
                       WVObserverOutputValueView &output) override {
    std::size_t count = 1;
    for (const auto dimension : variable.dimensions)
      count *= dimension;
    auto &storage = values_[variable.identifier];
    storage.assign(count, 0.0);
    output = {WVOutputValueType::real64, storage.data(), nullptr,
              storage.size()};
    return WVKernelStatus::ok();
  }

private:
  WVTransformConstantStratificationConfiguration configuration_;
  std::map<std::string, std::vector<double>> values_;
};

void deliverPlannedEvent(WVModelOutputNetCDFSink &sink,
                         const WVOutputPlan &plan, std::size_t eventIndex,
                         const WVCheckpoint &checkpoint) {
  const auto planned = plan.event(eventIndex);
  require(planned.routeCount == 1, "test plan route count");
  WVOutputEvent event;
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = eventState(checkpoint);
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  WVOutputDeliveryResult delivery;
  const auto status = sink.deliver(event, planned.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  require(delivery.writeCount == 7 || delivery.writeCount == 9,
          "coefficient delivery did not report six components and time");
}

void requireTimeSeries(const std::filesystem::path &path,
                       const std::vector<double> &expected) {
  int root = -1;
  require(nc_open(path.c_str(), NC_NOWRITE, &root) == NC_NOERR,
          "open output for time inspection");
  int group = -1;
  require(nc_inq_ncid(root, "wave-vortex", &group) == NC_NOERR,
          "locate output group");
  int variable = -1;
  require(nc_inq_varid(group, "t", &variable) == NC_NOERR,
          "locate time variable");
  std::vector<double> actual(expected.size());
  require(nc_get_var_double(group, variable, actual.data()) == NC_NOERR,
          "read time variable");
  require(actual == expected, "output time lattice changed");
  require(nc_close(root) == NC_NOERR, "close time inspection");
}

void requireLegacyScheduleSchema(const std::filesystem::path &path) {
  int root = -1, group = -1, variable = -1;
  require(nc_open(path.c_str(), NC_NOWRITE, &root) == NC_NOERR &&
              nc_inq_ncid(root, "wave-vortex", &group) == NC_NOERR,
          "open legacy schedule schema");
  require(nc_inq_att(group, NC_GLOBAL, "portableScheduleTypeIdentifier",
                     nullptr, nullptr) == NC_ENOTATT &&
              nc_inq_varid(group, "portableScheduleOrdinal", &variable) ==
                  NC_ENOTVAR &&
              nc_inq_varid(group, "portableScheduleCursor", &variable) ==
                  NC_ENOTVAR,
          "legacy evenly-spaced schema gained algorithmic metadata");
  for (const auto *name : {"outputInterval", "initialTime", "finalTime"})
    require(nc_inq_varid(group, name, &variable) == NC_NOERR,
            "legacy schedule scalar was removed");
  require(nc_close(root) == NC_NOERR, "close legacy schedule schema");
}

void testCreateReadAndAppend() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto path = directory.path / "multigroup.nc";
  auto record = recordFor(checkpoint, path);
  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration configuration{checkpoint, false};
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      configuration, descriptor, layout, nullptr, sink);
  require(static_cast<bool>(persistence),
          persistence.message + " at " + persistence.location);

  WVOutputPlan firstPlan;
  status = WVOutputPlan::create(descriptor, checkpoint.state.t,
                                checkpoint.state.t + 1.0, {}, firstPlan);
  require(static_cast<bool>(status), status.message);
  auto incompatibleRecord = record;
  incompatibleRecord.outputFiles.front().groups.front().identifier =
      "different-group";
  auto incompatibleDescriptor = descriptorFor(incompatibleRecord);
  WVOutputPlan incompatiblePlan;
  status = WVOutputPlan::create(incompatibleDescriptor, checkpoint.state.t,
                                checkpoint.state.t + 1.0, {}, incompatiblePlan);
  require(static_cast<bool>(status), status.message);
  status = sink.preflight(incompatiblePlan);
  require(!status, "NetCDF sink accepted an incompatible output plan");
  status = sink.preflight(firstPlan);
  require(static_cast<bool>(status), status.message);
  checkpoint.state.t = firstPlan.event(0).scheduledTime;
  deliverPlannedEvent(sink, firstPlan, 0, checkpoint);
  checkpoint.state.t = firstPlan.event(1).scheduledTime;
  deliverPlannedEvent(sink, firstPlan, 1, checkpoint);
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);
  require(sink.metrics().synchronizationCount == 2 &&
              sink.metrics().writtenBytes > 0 &&
              sink.metrics().payloadWriteSeconds >= 0.0 &&
              sink.metrics().synchronizationSeconds >= 0.0,
          "model-output timing and byte metrics are incomplete");
  requireTimeSeries(path, {firstPlan.event(0).scheduledTime,
                           firstPlan.event(1).scheduledTime});
  requireLegacyScheduleSchema(path);

  WVCheckpoint restored;
  persistence = WVCheckpointReader::read(path.string(), restored);
  require(static_cast<bool>(persistence), persistence.message);
  require(restored.state.t == checkpoint.state.t,
          "latest output state was not restartable");

  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(configuration, descriptor,
                                                    layout, nullptr, append);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan appendPlan;
  status = WVOutputPlan::create(descriptor, checkpoint.state.t,
                                checkpoint.state.t + 1.0, append.progress(),
                                appendPlan);
  require(static_cast<bool>(status), status.message);
  require(appendPlan.eventCount() == 1,
          "append plan repeated a committed output time");
  status = append.preflight(appendPlan);
  require(static_cast<bool>(status), status.message);
  checkpoint.state.t = appendPlan.event(0).scheduledTime;
  deliverPlannedEvent(append, appendPlan, 0, checkpoint);
  persistence = append.close();
  require(static_cast<bool>(persistence), persistence.message);
  requireTimeSeries(
      path, {restored.state.t - 1.0, restored.state.t, checkpoint.state.t});

  WVModelOutputNetCDFInspection inspection;
  persistence = WVModelOutputNetCDFSink::inspect({path.string()}, inspection);
  require(static_cast<bool>(persistence), persistence.message);
  require(inspection.latestRestart.state.t == checkpoint.state.t,
          "output inspection selected the wrong restart state");
  require(inspection.observerRecord.outputFiles.size() == 1 &&
              inspection.observerRecord.observers.size() == 1 &&
              inspection.progress.size() == 1,
          "output inspection did not reconstruct the observer graph");

  int file = -1;
  require(nc_open(path.c_str(), NC_WRITE, &file) == NC_NOERR,
          "open output for interrupted-record injection");
  int group = -1;
  require(nc_inq_ncid(file, "wave-vortex", &group) == NC_NOERR,
          "locate interrupted output group");
  int variable = -1;
  require(nc_inq_varid(group, "Ap_real", &variable) == NC_NOERR,
          "locate interrupted output variable");
  const std::size_t start[] = {2, 0, 0};
  const std::size_t count[] = {1, 1, 1};
  const double fill = NC_FILL_DOUBLE;
  require(nc_put_vara_double(group, variable, start, count, &fill) == NC_NOERR,
          "inject interrupted output value");
  require(nc_close(file) == NC_NOERR, "close interrupted-record injection");
  WVModelOutputNetCDFSink rejected;
  persistence = WVModelOutputNetCDFSink::openAppend(configuration, descriptor,
                                                    layout, nullptr, rejected);
  require(!persistence &&
              persistence.code == WVCheckpointStatusCode::incompleteRecord,
          "append accepted an incomplete committed output record");
  WVModelOutputNetCDFInspection rejectedInspection;
  persistence =
      WVModelOutputNetCDFSink::inspect({path.string()}, rejectedInspection);
  require(!persistence &&
              persistence.code == WVCheckpointStatusCode::incompleteRecord,
          "inspection accepted an incomplete committed output record");
}

void testLinearInitialCoefficientsAndPassiveFields() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  checkpoint.state.coefficients.Ap[1] = {1.0, 2.0};
  checkpoint.state.coefficients.Am[1] = {3.0, -4.0};
  checkpoint.state.coefficients.A0[1] = {5.0, 6.0};
  const auto path = directory.path / "linear-passive.nc";
  auto record = recordFor(checkpoint, path);
  record.observers.clear();
  WVObserverRecord fields;
  fields.identifier = "eulerian-fields-Ap-Am-A0-u";
  fields.name = "WVTestFields";
  fields.typeIdentifier = "WVTestFields";
  fields.fieldNames = {"Ap", "Am", "A0", "u", "psi"};
  record.observers.push_back(fields);
  WVObserverRecord mooring;
  mooring.identifier = "mooring-central";
  mooring.name = "central";
  mooring.typeIdentifier = "WVMooring";
  mooring.fieldNames = {"u"};
  mooring.x = {-1.0, checkpoint.configuration.Lx};
  mooring.y = {checkpoint.configuration.Ly, 0.5 * checkpoint.configuration.Ly};
  record.observers.push_back(mooring);
  WVObserverRecord diagnostic;
  diagnostic.identifier = "point-diagnostic";
  diagnostic.name = "diagnostic";
  diagnostic.typeIdentifier = "WVTestPortablePointDiagnostic";
  diagnostic.fieldNames = {"u"};
  diagnostic.x = {100.0, 200.0};
  diagnostic.y = {300.0, 400.0};
  diagnostic.z = {-100.0, -200.0};
  diagnostic.outputScale = 2.5;
  diagnostic.outputOffset = -1.25;
  record.observers.push_back(diagnostic);
  record.outputFiles.front().groups.front().observerIdentifiers = {
      fields.identifier, mooring.identifier, diagnostic.identifier};
  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  std::unique_ptr<WVObserverOutputEvaluationService> source;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, true, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), source);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration configuration{checkpoint, true};
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      configuration, descriptor, layout, source.get(), sink);
  require(static_cast<bool>(persistence), persistence.message);

  WVOutputPlan plan;
  status = WVOutputPlan::create(descriptor, checkpoint.state.t,
                                checkpoint.state.t, {}, plan);
  require(static_cast<bool>(status), status.message);
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  const auto planned = plan.event(0);
  WVOutputEvent event;
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = eventState(checkpoint);
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  WVOutputDeliveryResult delivery;
  status = sink.deliver(event, planned.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  require(delivery.writeCount == 4,
          "linear delivery must write Eulerian, mooring, diagnostic, and time");
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);

  int root = -1;
  require(nc_open(path.c_str(), NC_NOWRITE, &root) == NC_NOERR,
          "open linear passive output");
  int group = -1;
  require(nc_inq_ncid(root, "wave-vortex", &group) == NC_NOERR,
          "locate linear passive group");
  int variable = -1;
  require(nc_inq_varid(group, "Ap_real", &variable) == NC_NOERR,
          "locate initial coefficient");
  int rank = 0;
  require(nc_inq_varndims(group, variable, &rank) == NC_NOERR && rank == 2,
          "linear coefficient must be initial-only [kl,j]");
  require(nc_inq_varid(group, "u", &variable) == NC_NOERR, "locate Eulerian u");
  require(nc_inq_varndims(group, variable, &rank) == NC_NOERR && rank == 4,
          "linear u must remain [t,z,y,x]");
  require(nc_inq_varid(group, "psi", &variable) == NC_NOERR &&
              nc_inq_varndims(group, variable, &rank) == NC_NOERR && rank == 3,
          "linear psi must remain initial-only [z,y,x]");
  require(nc_inq_varid(group, "central_u", &variable) == NC_NOERR &&
              nc_inq_varndims(group, variable, &rank) == NC_NOERR && rank == 3,
          "mooring field must use [t,id,z] NetCDF order");
  require(nc_inq_varid(group, "central_x", &variable) == NC_NOERR,
          "mooring x coordinate is absent");
  std::vector<double> x(2);
  require(nc_get_var_double(group, variable, x.data()) == NC_NOERR &&
              x[0] == checkpoint.configuration.Lx - 1.0 && x[1] == 0.0,
          "mooring periodic x coordinates changed");
  require(nc_inq_varid(group, "diagnostic_value", &variable) == NC_NOERR &&
              nc_inq_varndims(group, variable, &rank) == NC_NOERR && rank == 2,
          "point-diagnostic output must use [t,id] NetCDF order");
  require(nc_close(root) == NC_NOERR, "close linear passive output");

  WVModelOutputNetCDFInspection inspection;
  persistence = WVModelOutputNetCDFSink::inspect({path.string()}, inspection);
  require(static_cast<bool>(persistence), persistence.message);
  require(inspection.latestRestart.state.coefficients.Ap[1].real == 1.0 &&
              inspection.latestRestart.state.coefficients.Ap[1].imag == 2.0,
          "linear initial coefficient did not round-trip");
  require(inspection.observerRecord.observers.size() == 3 &&
              inspection.observerRecord.observers.front().typeIdentifier ==
                  "WVTestFields" &&
              inspection.observerRecord.observers.front().name ==
                  "WVTestFields",
          "registered field observer did not round-trip through NetCDF");
  const auto restoredDiagnostic = std::find_if(
      inspection.observerRecord.observers.begin(),
      inspection.observerRecord.observers.end(), [](const auto &observer) {
        return observer.typeIdentifier == "WVTestPortablePointDiagnostic";
      });
  require(restoredDiagnostic != inspection.observerRecord.observers.end() &&
              restoredDiagnostic->fieldNames ==
                  std::vector<std::string>({"u"}) &&
              restoredDiagnostic->x == diagnostic.x &&
              restoredDiagnostic->y == diagnostic.y &&
              restoredDiagnostic->z == diagnostic.z &&
              restoredDiagnostic->outputScale == diagnostic.outputScale &&
              restoredDiagnostic->outputOffset == diagnostic.outputOffset,
          "point-diagnostic configuration did not round-trip through NetCDF");

  require(nc_open(path.c_str(), NC_WRITE, &root) == NC_NOERR &&
              nc_inq_ncid(root, "wave-vortex", &group) == NC_NOERR &&
              nc_redef(root) == NC_NOERR,
          "open legacy MATLAB attribute spelling injection");
  for (const auto &[name, description] :
       std::array<std::pair<const char *, const char *>, 2>{{
           {"central_x", "x coordinate position of mooring"},
           {"central_y", "y coordinate position of mooring"}}}) {
    require(nc_inq_varid(group, name, &variable) == NC_NOERR &&
                nc_put_att_text(group, variable, "long_name",
                                std::char_traits<char>::length(description),
                                description) == NC_NOERR,
            "inject legacy MATLAB long_name spelling");
  }
  require(nc_enddef(root) == NC_NOERR && nc_close(root) == NC_NOERR,
          "close legacy MATLAB attribute spelling injection");

  auto appendDescriptor = descriptorFor(inspection.observerRecord);
  std::unique_ptr<WVObserverOutputEvaluationService> appendSource;
  status = WVObserverOutputEvaluationService::create(
      inspection.latestRestart.configuration, true, appendDescriptor,
      std::make_unique<WVReferenceFFTEngine>(), appendSource);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration appendConfiguration{inspection.latestRestart,
                                                       true};
  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(
      appendConfiguration, appendDescriptor, inspection.stateLayout,
      appendSource.get(), append);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan appendPlan;
  status = WVOutputPlan::create(
      appendDescriptor, inspection.latestRestart.state.t,
      inspection.latestRestart.state.t + 1.0, append.progress(), appendPlan);
  require(static_cast<bool>(status) && appendPlan.eventCount() == 1,
          "linear append plan mismatch");
  status = append.preflight(appendPlan);
  require(static_cast<bool>(status), status.message);
  const auto next = appendPlan.event(0);
  event.eventOrdinal = next.eventOrdinal;
  event.scheduledTime = next.scheduledTime;
  event.state = eventState(inspection.latestRestart);
  event.routes = next.routes;
  event.routeCount = next.routeCount;
  delivery = {};
  status = append.deliver(event, next.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  persistence = append.close();
  require(static_cast<bool>(persistence), persistence.message);
  WVCheckpoint reread;
  persistence = WVCheckpointReader::read(path.string(), reread);
  require(static_cast<bool>(persistence), persistence.message);
  require(reread.state.t == next.scheduledTime &&
              reread.state.coefficients.Ap[1].imag == 2.0,
          "linear append changed initial coefficients or latest time");
}

void testTransactionalRefusal() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto path = directory.path / "existing.nc";
  {
    int file = -1;
    require(nc_create(path.c_str(), NC_NETCDF4, &file) == NC_NOERR,
            "create collision sentinel");
    require(nc_close(file) == NC_NOERR, "close collision sentinel");
  }
  auto record = recordFor(checkpoint, path);
  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink sink;
  const auto result = WVModelOutputNetCDFSink::createNew(
      {checkpoint, false}, descriptor, layout, nullptr, sink);
  require(!result && result.code == WVCheckpointStatusCode::commitFailure,
          "create-new output replaced an existing destination");
}

void testMultipleFilesGroupsAndSharedState() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  WVPortableObserverRecord record;
  const std::vector<std::size_t> coefficientShape = {
      checkpoint.state.coefficients.shape.rows,
      checkpoint.state.coefficients.shape.columns};
  for (const auto *name : {"Ap", "Am", "A0"})
    record.stateBlocks.push_back({name, WVStateScalarType::complex64,
                                  coefficientShape,
                                  WVToleranceKind::coefficientEnergyScaled,
                                  1e-6, WVStateOwnership::integratorOwned,
                                  WVRestartRequirement::requiredDynamicState});
  for (const auto *name : {"particles-x", "particles-y"})
    record.stateBlocks.push_back({name,
                                  WVStateScalarType::real64,
                                  {2},
                                  WVToleranceKind::uniformAbsolute,
                                  1e-4,
                                  WVStateOwnership::integratorOwned,
                                  WVRestartRequirement::requiredDynamicState});
  record.stateBlocks.push_back(
      {"tracer-state",
       WVStateScalarType::real64,
       {checkpoint.configuration.Nx, checkpoint.configuration.Ny,
        checkpoint.configuration.Nz},
       WVToleranceKind::uniformAbsolute,
       1e-5,
       WVStateOwnership::integratorOwned,
       WVRestartRequirement::requiredDynamicState});
  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "wave-vortex coefficients";
  coefficients.typeIdentifier = "WVCoefficients";
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  WVObserverRecord particles;
  particles.identifier = "particles";
  particles.name = "particles";
  particles.typeIdentifier = "WVLagrangianParticles";
  particles.stateBlockIdentifiers = {"particles-x", "particles-y"};
  particles.x = {0.1, 0.2};
  particles.y = {0.3, 0.4};
  particles.z = {-100.0, -300.0};
  particles.isXYOnly = true;
  particles.horizontalAbsoluteTolerance = 1e-4;
  WVObserverRecord tracer;
  tracer.identifier = "tracer";
  tracer.name = "tracer";
  tracer.typeIdentifier = "WVTracer";
  tracer.stateBlockIdentifiers = {"tracer-state"};
  tracer.isXYOnly = false;
  tracer.shouldAntialias = true;
  WVObserverRecord fields;
  fields.identifier = "fields";
  fields.name = "WVEulerianFields";
  fields.typeIdentifier = "WVEulerianFields";
  fields.fieldNames = {"u", "v", "rho_e"};
  WVObserverRecord mooring;
  mooring.identifier = "mooring";
  mooring.name = "mooring";
  mooring.typeIdentifier = "WVMooring";
  mooring.fieldNames = {"u", "v"};
  mooring.x = {0.0, 0.5 * checkpoint.configuration.Lx};
  mooring.y = {0.0, 0.5 * checkpoint.configuration.Ly};
  record.observers = {coefficients, fields, mooring, particles, tracer};
  const auto outputInterval = 1e-7;
  const auto end = checkpoint.state.t + 2.0 * outputInterval;
  const char *exportPath = std::getenv("WV_RUNTIME_MODEL_OUTPUT_EXPORT");
  const auto first = exportPath == nullptr ? directory.path / "first.nc"
                                           : std::filesystem::path(exportPath);
  const auto second =
      exportPath == nullptr
          ? directory.path / "second.nc"
          : std::filesystem::path(std::string(exportPath) + ".second.nc");
  record.outputFiles = {
      {"first",
       first.string(),
       {{"restart",
         "wave-vortex",
         {outputInterval, checkpoint.state.t, end},
         {"coefficients", "fields", "mooring"},
         true},
        {"shared",
         "shared",
         {outputInterval, checkpoint.state.t, end},
         {"fields", "mooring", "particles", "tracer"},
         false}}},
      {"second",
       second.string(),
       {{"restart",
         "restart",
         {outputInterval, checkpoint.state.t, end},
         {"coefficients", "fields", "mooring", "particles", "tracer"},
         true}}}};
  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  WVAdditionalStateStorage additional;
  status = additional.initialize(layout);
  require(static_cast<bool>(status), status.message);
  for (std::size_t block = 0; block < additional.blockCount(); ++block)
    std::fill_n(additional.mutableBlocks()[block].realData,
                additional.mutableBlocks()[block].layout->elementCount,
                static_cast<double>(block + 1));
  std::unique_ptr<WVObserverOutputEvaluationService> source;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, false, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), source);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      {checkpoint, false}, descriptor, layout, source.get(), sink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan plan;
  status = WVOutputPlan::create(descriptor, checkpoint.state.t, end, {}, plan);
  require(static_cast<bool>(status), status.message);
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  WVOutputEvent event;
  const auto planned = plan.event(0);
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = {checkpoint.state.view(), additional.constBlocks(),
                 additional.blockCount()};
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  require(planned.routeCount == 3,
          "coincident multi-file routes were not grouped");
  for (std::size_t route = 0; route < planned.routeCount; ++route) {
    WVOutputDeliveryResult delivery;
    status = sink.deliver(event, planned.routes[route], delivery);
    require(static_cast<bool>(status), status.message);
  }
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);
  {
    int file = -1;
    int group = -1;
    int ids = -1;
    int z = -1;
    int tracerVariable = -1;
    require(nc_open(first.c_str(), NC_NOWRITE, &file) == NC_NOERR &&
                nc_inq_ncid(file, "shared", &group) == NC_NOERR &&
                nc_inq_varid(group, "particles_id", &ids) == NC_NOERR &&
                nc_inq_varid(group, "particles_z", &z) == NC_NOERR &&
                nc_inq_varid(group, "tracer", &tracerVariable) == NC_NOERR,
            "particle MATLAB schema variables missing");
    std::array<double, 2> idValues{};
    require(nc_get_var_double(group, ids, idValues.data()) == NC_NOERR &&
                idValues == std::array<double, 2>{{1.0, 2.0}},
            "particle identifiers are not one-based");
    const std::size_t start[] = {0, 0};
    const std::size_t count[] = {1, 2};
    std::array<double, 2> zValues{};
    require(nc_get_vara_double(group, z, start, count, zValues.data()) ==
                    NC_NOERR &&
                zValues == std::array<double, 2>{{-100.0, -300.0}},
            "fixed particle z values were not written on [id,t]");
    char attribute[64]{};
    require(nc_get_att_text(group, z, "particleName", attribute) == NC_NOERR &&
                std::string(attribute, std::string("particles").size()) ==
                    "particles",
            "particle metadata attributes missing");
    std::fill(std::begin(attribute), std::end(attribute), '\0');
    require(nc_get_att_text(group, tracerVariable, "isTracer", attribute) ==
                    NC_NOERR &&
                attribute[0] == '1',
            "tracer marker attribute missing");
    require(nc_close(file) == NC_NOERR, "close particle schema inspection");
  }
  WVModelOutputNetCDFInspection inspection;
  persistence = WVModelOutputNetCDFSink::inspect(
      {first.string(), second.string()}, inspection);
  require(static_cast<bool>(persistence), persistence.message);
  require(inspection.observerRecord.outputFiles.size() == 2 &&
              inspection.progress.size() == 3 &&
              inspection.observerRecord.observers.size() == 5,
          "multi-file graph or shared observer identity was not reconstructed");
  require(inspection.additionalState.blockCount() == 3,
          "shared dynamic state was duplicated during reconstruction");
  const auto particleX =
      std::find_if(inspection.additionalState.constBlocks(),
                   inspection.additionalState.constBlocks() +
                       inspection.additionalState.blockCount(),
                   [](const auto &view) {
                     return view.layout->identifier == "particles-x";
                   });
  const auto tracerState =
      std::find_if(inspection.additionalState.constBlocks(),
                   inspection.additionalState.constBlocks() +
                       inspection.additionalState.blockCount(),
                   [](const auto &view) {
                     return view.layout->identifier == "tracer-state";
                   });
  require(particleX != inspection.additionalState.constBlocks() +
                           inspection.additionalState.blockCount() &&
              particleX->realData[0] == 1.0 &&
              tracerState != inspection.additionalState.constBlocks() +
                                 inspection.additionalState.blockCount() &&
              tracerState->realData[0] == 3.0,
          "dynamic state stored outside the coefficient group was not "
          "restored");
  for (std::size_t block = 0; block < inspection.additionalState.blockCount();
       ++block) {
    const auto &view = inspection.additionalState.constBlocks()[block];
    require(view.layout != nullptr && view.realData != nullptr,
            "restored dynamic-state view is invalid");
    require(std::all_of(view.realData,
                        view.realData + view.layout->elementCount,
                        [](double value) { return std::isfinite(value); }),
            "restored dynamic state contains nonfinite values");
  }
  const auto restoredParticles = std::find_if(
      inspection.observerRecord.observers.begin(),
      inspection.observerRecord.observers.end(),
      [](const auto &observer) { return observer.identifier == "particles"; });
  require(restoredParticles != inspection.observerRecord.observers.end() &&
              restoredParticles->z == std::vector<double>({-100.0, -300.0}),
          "fixed XY particle z configuration was not reconstructed");
  {
    const auto sourceFirstBytes = fileBytes(first);
    const auto sourceSecondBytes = fileBytes(second);
    const auto requestPath = directory.path / "portable-run.json";
    const auto requestedFirst = directory.path / "requested-first.nc";
    const auto requestedSecond = directory.path / "requested-second.nc";
    const auto requestedReport = directory.path / "portable-run-report.json";
    std::ofstream request(requestPath, std::ios::binary | std::ios::trunc);
    request << std::setprecision(17)
            << "{\"schemaIdentifier\":\"wave-vortex-run-request-v1\","
               "\"schemaVersion\":1,\"modelFiles\":["
            << "\"" << first.string() << "\",\"" << second.string()
            << "\"],\"integration\":{\"method\":\"fixed-rk4\","
               "\"finalTime\":"
            << end << ",\"initialStep\":" << outputInterval
            << "},\"output\":{\"policy\":\"create\",\"destinations\":{"
               "\"first\":\""
            << requestedFirst.string() << "\",\"second\":\""
            << requestedSecond.string()
            << "\"}},\"execution\":{\"fftProvider\":\"reference\","
               "\"threads\":1},\"report\":\""
            << requestedReport.string() << "\"}";
    request.close();
    std::ostringstream command;
    command << shellQuote(WV_RUNTIME_RUNNER) << " --request "
            << shellQuote(requestPath) << " >/dev/null";
    require(std::system(command.str().c_str()) == 0,
            "MATLAB-authored multi-file run request failed");
    WVModelOutputNetCDFInspection requested;
    persistence = WVModelOutputNetCDFSink::inspect(
        {requestedFirst.string(), requestedSecond.string()}, requested);
    require(static_cast<bool>(persistence), persistence.message);
    require(std::abs(requested.latestRestart.state.t - end) <= 1e-14 &&
                requested.observerRecord.observers.size() == 5 &&
                requested.additionalState.blockCount() == 3,
            "run request did not preserve the complete model graph");
    require(fileBytes(first) == sourceFirstBytes &&
                fileBytes(second) == sourceSecondBytes,
            "create request mutated its MATLAB-authored source bundle");
    require(std::filesystem::exists(requestedReport),
            "run request did not write its report");

    const auto partialPath = directory.path / "partial-run.json";
    std::ofstream partial(partialPath, std::ios::binary | std::ios::trunc);
    partial << std::setprecision(17)
            << "{\"schemaIdentifier\":\"wave-vortex-run-request-v1\","
               "\"schemaVersion\":1,\"modelFiles\":[\""
            << first.string() << "\",\"" << second.string()
            << "\"],\"integration\":{\"method\":\"fixed-rk4\","
               "\"finalTime\":"
            << end << ",\"initialStep\":" << outputInterval
            << "},\"output\":{\"policy\":\"create\",\"destinations\":{"
               "\"first\":\""
            << (directory.path / "partial.nc").string()
            << "\"}},\"execution\":{\"fftProvider\":\"native-fftw\","
               "\"threads\":1},\"report\":\""
            << (directory.path / "partial-report.json").string() << "\"}";
    partial.close();
    require(std::system((shellQuote(WV_RUNTIME_RUNNER) + " --request " +
                         shellQuote(partialPath) + " >/dev/null 2>&1")
                            .c_str()) != 0,
            "incomplete destination map passed graph preflight");
    require(
        !std::filesystem::exists(directory.path / "partial.nc"),
        "failed graph preflight mutated output before provider construction");
    require(
        std::system((shellQuote(WV_RUNTIME_RUNNER) + " --request " +
                     shellQuote(requestPath) + " --threads 1 >/dev/null 2>&1")
                        .c_str()) != 0,
        "request mode accepted legacy semantic overrides");
  }
  {
    int file = -1;
    int group = -1;
    int variable = -1;
    require(nc_open(second.c_str(), NC_WRITE, &file) == NC_NOERR &&
                nc_inq_ncid(file, "restart", &group) == NC_NOERR &&
                nc_inq_varid(group, "particles_x", &variable) == NC_NOERR,
            "open duplicate particle state for ambiguity test");
    const std::size_t start[] = {0, 0};
    const std::size_t count[] = {1, 1};
    double conflicting = 99.0;
    require(nc_put_vara_double(group, variable, start, count, &conflicting) ==
                    NC_NOERR &&
                nc_close(file) == NC_NOERR,
            "write conflicting duplicate particle state");
    WVModelOutputNetCDFInspection rejected;
    const auto rejectedStatus = WVModelOutputNetCDFSink::inspect(
        {first.string(), second.string()}, rejected);
    require(!rejectedStatus &&
                rejectedStatus.code == WVCheckpointStatusCode::ambiguousState,
            "conflicting cross-group restart state was not rejected");
  }
  std::ostringstream fixedCommand;
  fixedCommand << shellQuote(WV_RUNTIME_RUNNER) << ' ' << shellQuote(first)
               << " --restart-mode model --output-policy append --delta-t "
               << outputInterval << " --final-time " << std::setprecision(17)
               << end << " --fft-provider reference >/dev/null";
  require(std::system(fixedCommand.str().c_str()) == 0,
          "fixed-step full-model continuation failed");
  WVModelOutputNetCDFInspection continued;
  persistence = WVModelOutputNetCDFSink::inspect({first.string()}, continued);
  require(static_cast<bool>(persistence), persistence.message);
  require(std::abs(continued.latestRestart.state.t - end) <= 1e-14 &&
              continued.observerRecord.observers.size() == 5 &&
              continued.additionalState.blockCount() == 3,
          "fixed-step continuation did not preserve the complete model graph");

  std::cout << "OUTPUT_METRICS files=" << sink.metrics().fileCount
            << " groups=" << sink.metrics().groupCount
            << " records=" << sink.metrics().committedRecordCount
            << " syncs=" << sink.metrics().synchronizationCount
            << " bytes=" << sink.metrics().writtenBytes
            << " payload_seconds=" << sink.metrics().payloadWriteSeconds
            << " sync_seconds=" << sink.metrics().synchronizationSeconds
            << " sink_bytes=" << sink.metrics().retainedStorageBytes
            << " observer_bytes=" << source->persistentBytes() << '\n';
}

void testOptionalMatlabFixture() {
  const char *path = std::getenv("WV_MATLAB_MODEL_OUTPUT_FIXTURE");
  if (path == nullptr)
    return;
  std::vector<std::string> paths{path};
  const char *secondPath = std::getenv("WV_MATLAB_MODEL_OUTPUT_FIXTURE_SECOND");
  if (secondPath != nullptr)
    paths.emplace_back(secondPath);
  WVModelOutputNetCDFInspection inspection;
  const auto inspectStatus =
      WVModelOutputNetCDFSink::inspect(paths, inspection);
  require(static_cast<bool>(inspectStatus),
          inspectStatus.message + " at " + inspectStatus.location);
  const auto hasType = [&](const std::string &typeIdentifier) {
    return std::any_of(inspection.observerRecord.observers.begin(),
                       inspection.observerRecord.observers.end(),
                       [&](const auto &observer) {
                         return observer.typeIdentifier == typeIdentifier;
                       });
  };
  const bool hasCoefficients = hasType("WVCoefficients");
  const bool hasEulerian = hasType("WVEulerianFields");
  const bool hasMooring = hasType("WVMooring");
  const bool hasParticles = hasType("WVLagrangianParticles");
  const bool hasTracer = hasType("WVTracer");
  require(hasEulerian && hasMooring && hasParticles && hasTracer,
          "MATLAB observer graph kinds: coefficients=" +
              std::to_string(hasCoefficients) +
              " eulerian=" + std::to_string(hasEulerian) +
              " mooring=" + std::to_string(hasMooring) +
              " particles=" + std::to_string(hasParticles) +
              " tracer=" + std::to_string(hasTracer));
  require(inspection.observerRecord.outputFiles.size() == paths.size() &&
              inspection.observerRecord.outputFiles.front().groups.size() == 2,
          "MATLAB multi-group graph was not reconstructed");
  require(inspection.additionalState.blockCount() == 4,
          "MATLAB dynamic particle/tracer state was not reconstructed");

  TemporaryDirectory directory;
  const auto appendPath = directory.path / "matlab-append.nc";
  std::filesystem::copy_file(path, appendPath);
  WVModelOutputNetCDFInspection appendInspection;
  auto persistence =
      WVModelOutputNetCDFSink::inspect({appendPath.string()}, appendInspection);
  require(static_cast<bool>(persistence), persistence.message);
  appendInspection.observerRecord.outputFiles.front().destination =
      appendPath.string();
  auto descriptor = descriptorFor(appendInspection.observerRecord);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      appendInspection.latestRestart.state.coefficients.shape, descriptor,
      layout);
  require(static_cast<bool>(status), status.message);
  ZeroSampleSource samples(appendInspection.latestRestart.configuration);
  WVModelOutputNetCDFSink sink;
  persistence = WVModelOutputNetCDFSink::openAppend(
      {appendInspection.latestRestart, false}, descriptor, layout, &samples,
      sink);
  require(static_cast<bool>(persistence),
          persistence.message + " at " + persistence.location);
  WVOutputPlan plan;
  status = WVOutputPlan::create(
      descriptor, appendInspection.latestRestart.state.t,
      appendInspection.latestRestart.state.t + 1.0, sink.progress(), plan);
  require(static_cast<bool>(status), status.message);
  require(plan.eventCount() >= 1,
          "MATLAB append plan did not select a future schedule point");
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  std::vector<WVAdditionalStateBlockConstView> blocks;
  blocks.reserve(appendInspection.additionalState.blockCount());
  for (std::size_t index = 0;
       index < appendInspection.additionalState.blockCount(); ++index)
    blocks.push_back(appendInspection.additionalState.constBlocks()[index]);
  WVOutputEvent event;
  const auto planned = plan.event(0);
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = {appendInspection.latestRestart.state.view(), blocks.data(),
                 blocks.size()};
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  for (std::size_t route = 0; route < planned.routeCount; ++route) {
    WVOutputDeliveryResult delivery;
    status = sink.deliver(event, planned.routes[route], delivery);
    require(static_cast<bool>(status), status.message);
  }
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);
  WVCheckpoint appended;
  persistence = WVCheckpointReader::read(appendPath.string(), appended);
  require(static_cast<bool>(persistence), persistence.message);
  require(appended.state.t == planned.scheduledTime,
          "runtime did not append the next MATLAB output time");
}

void testOptionalMatlabLinearFixture() {
  const char *path = std::getenv("WV_MATLAB_LINEAR_OUTPUT_FIXTURE");
  if (path == nullptr)
    return;
  WVModelOutputNetCDFInspection inspection;
  auto persistence = WVModelOutputNetCDFSink::inspect({path}, inspection);
  require(static_cast<bool>(persistence),
          persistence.message + " at " + persistence.location);
  require(inspection.observerRecord.observers.size() == 1 &&
              inspection.observerRecord.observers.front().typeIdentifier ==
                  "WVEulerianFields",
          "MATLAB linear Eulerian observer was not reconstructed");
  require(inspection.latestRestart.state.coefficients.Ap.size() ==
              inspection.latestRestart.state.coefficients.shape.elementCount(),
          "MATLAB linear coefficients were not reconstructed");

  TemporaryDirectory directory;
  const auto appendPath = directory.path / "matlab-linear-append.nc";
  std::filesystem::copy_file(path, appendPath);
  inspection.observerRecord.outputFiles.front().destination =
      appendPath.string();
  auto descriptor = descriptorFor(inspection.observerRecord);
  std::unique_ptr<WVObserverOutputEvaluationService> source;
  auto status = WVObserverOutputEvaluationService::create(
      inspection.latestRestart.configuration, true, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), source);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink sink;
  persistence = WVModelOutputNetCDFSink::openAppend(
      {inspection.latestRestart, true}, descriptor, inspection.stateLayout,
      source.get(), sink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan plan;
  status = WVOutputPlan::create(descriptor, inspection.latestRestart.state.t,
                                inspection.latestRestart.state.t + 1.0,
                                sink.progress(), plan);
  require(static_cast<bool>(status) && plan.eventCount() == 1,
          "MATLAB linear append plan mismatch");
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  const auto planned = plan.event(0);
  WVOutputEvent event;
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = eventState(inspection.latestRestart);
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  WVOutputDeliveryResult delivery;
  status = sink.deliver(event, planned.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);
  WVCheckpoint appended;
  persistence = WVCheckpointReader::read(appendPath.string(), appended);
  require(static_cast<bool>(persistence) &&
              appended.state.t == planned.scheduledTime,
          "MATLAB linear file did not append");
}

void testOptionalMatlabPassiveFixture() {
  const char *path = std::getenv("WV_MATLAB_PASSIVE_OUTPUT_FIXTURE");
  if (path == nullptr)
    return;
  WVModelOutputNetCDFInspection inspection;
  const auto persistence = WVModelOutputNetCDFSink::inspect({path}, inspection);
  require(static_cast<bool>(persistence),
          persistence.message + " at " + persistence.location);
  require(inspection.observerRecord.observers.size() == 2,
          "MATLAB passive observer graph was not reconstructed");
  const auto coefficients = std::count_if(
      inspection.observerRecord.observers.begin(),
      inspection.observerRecord.observers.end(), [](const auto &observer) {
        return observer.typeIdentifier == "WVCoefficients";
      });
  const auto eulerian = std::count_if(
      inspection.observerRecord.observers.begin(),
      inspection.observerRecord.observers.end(), [](const auto &observer) {
        return observer.typeIdentifier == "WVEulerianFields";
      });
  require(coefficients == 1 && eulerian == 1,
          "MATLAB coefficient and Eulerian metadata changed");
}

void testAlgorithmicSchedulePersistence() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto initialTime = checkpoint.state.t;
  const auto path = directory.path / "algorithmic.nc";
  auto record = recordFor(checkpoint, path);
  record.outputFiles[0].groups[0].schedule =
      quadraticSchedule(initialTime + 4.0, initialTime);
  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration configuration{checkpoint, false};
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      configuration, descriptor, layout, nullptr, sink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan plan;
  status = WVOutputPlan::create(descriptor, initialTime, initialTime + 1.0, {},
                                plan);
  require(static_cast<bool>(status) && plan.eventCount() == 2,
          "algorithmic schedule create plan");
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  for (std::size_t index = 0; index < plan.eventCount(); ++index) {
    checkpoint.state.t = plan.event(index).scheduledTime;
    deliverPlannedEvent(sink, plan, index, checkpoint);
  }
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);

  WVModelOutputNetCDFInspection inspection;
  persistence = WVModelOutputNetCDFSink::inspect({path.string()}, inspection);
  require(static_cast<bool>(persistence), persistence.message);
  const auto &restoredSchedule =
      inspection.observerRecord.outputFiles[0].groups[0].schedule;
  const auto *next = inspection.progress[0].scheduleCursor.value("nextOrdinal");
  require(restoredSchedule.typeIdentifier == quadraticScheduleType &&
              restoredSchedule.contractVersion == 1 &&
              restoredSchedule.configuration.value("scale") != nullptr &&
              inspection.progress[0].committedOrdinal == 1 && next != nullptr &&
              std::get<std::vector<std::int64_t>>(next->storage)[0] == 2,
          "algorithmic schedule configuration and cursor round trip");

  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(configuration, descriptor,
                                                    layout, nullptr, append);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan resumed;
  status = WVOutputPlan::create(descriptor, initialTime + 1.0,
                                initialTime + 4.0, append.progress(), resumed);
  require(static_cast<bool>(status) && resumed.eventCount() == 1 &&
              resumed.event(0).scheduledTime == initialTime + 4.0,
          "algorithmic schedule append cursor");
  status = append.preflight(resumed);
  require(static_cast<bool>(status), status.message);
  checkpoint.state.t = resumed.event(0).scheduledTime;
  deliverPlannedEvent(append, resumed, 0, checkpoint);
  persistence = append.close();
  require(static_cast<bool>(persistence), persistence.message);
}

void testVariableObservationBatches() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto initialTime = checkpoint.state.t;
  const auto path = directory.path / "variable-observations.nc";
  WVObserverRecord synthetic;
  synthetic.identifier = "synthetic-observations";
  synthetic.name = "synthetic";
  synthetic.typeIdentifier = "WVTestObservationBatches";
  const auto configuredRecord = [&](const std::filesystem::path &destination) {
    auto configured = recordFor(checkpoint, destination);
    configured.observers.push_back(synthetic);
    configured.outputFiles[0].groups[0].observerIdentifiers.push_back(
        synthetic.identifier);
    return configured;
  };
  const auto invalidPath = directory.path / "invalid-observations.nc";
  auto invalidRecord = configuredRecord(invalidPath);
  auto invalidDescriptor = descriptorFor(invalidRecord);
  WVIntegrationStateLayout invalidLayout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, invalidDescriptor, invalidLayout);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration configuration{checkpoint, false};
  VariableBatchSource malformedSource(1, true);
  WVModelOutputNetCDFSink malformedSink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      configuration, invalidDescriptor, invalidLayout, &malformedSource,
      malformedSink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan invalidPlan;
  status = WVOutputPlan::create(invalidDescriptor, initialTime,
                                initialTime + 1.0, {}, invalidPlan);
  require(static_cast<bool>(status) && invalidPlan.eventCount() == 2,
          "malformed variable-batch output plan");
  status = malformedSink.preflight(invalidPlan);
  require(static_cast<bool>(status), status.message);

  WVOutputEvent invalidEvent;
  invalidEvent.eventOrdinal = invalidPlan.event(0).eventOrdinal;
  invalidEvent.scheduledTime = invalidPlan.event(0).scheduledTime;
  invalidEvent.state = eventState(checkpoint);
  invalidEvent.routes = invalidPlan.event(0).routes;
  invalidEvent.routeCount = invalidPlan.event(0).routeCount;
  WVOutputDeliveryResult delivery;
  status = malformedSink.deliver(invalidEvent, invalidEvent.routes[0], delivery);
  require(!status, "malformed ragged batch was written");
  delivery = {};
  status = malformedSink.deliver(invalidEvent, invalidEvent.routes[0], delivery);
  require(!status, "an exact-event retry accepted its malformed batch");
  require(malformedSource.prepareCount() == 1,
          "an exact-event retry repeated source preparation: " +
              std::to_string(malformedSource.prepareCount()));
  require(malformedSource.batchCount(synthetic.identifier) == 1,
          "an exact-event retry regenerated its malformed observation batch: " +
              std::to_string(
                  malformedSource.batchCount(synthetic.identifier)));
  int file = -1, group = -1, timeDimension = -1;
  std::size_t timeCount = 99;
  require(nc_open(invalidPath.c_str(), NC_NOWRITE, &file) == NC_NOERR &&
              nc_inq_ncid(file, "wave-vortex", &group) == NC_NOERR &&
              nc_inq_dimid(group, "t", &timeDimension) == NC_NOERR &&
              nc_inq_dimlen(group, timeDimension, &timeCount) == NC_NOERR &&
              timeCount == 0 && nc_close(file) == NC_NOERR,
          "failed batch mutated the output before validation");
  persistence = malformedSink.close();
  require(static_cast<bool>(persistence), persistence.message);

  auto record = configuredRecord(path);
  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  registeredBatches->resetCounts();
  std::unique_ptr<WVObserverOutputEvaluationService> source;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, false, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), source);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink sink;
  persistence = WVModelOutputNetCDFSink::createNew(
      configuration, descriptor, layout, source.get(), sink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan plan;
  status = WVOutputPlan::create(descriptor, initialTime, initialTime + 1.0, {},
                                plan);
  require(static_cast<bool>(status) && plan.eventCount() == 2,
          "variable-batch output plan");
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);

  WVOutputEvent event;
  event.eventOrdinal = plan.event(0).eventOrdinal;
  event.scheduledTime = plan.event(0).scheduledTime;
  event.state = eventState(checkpoint);
  event.routes = plan.event(0).routes;
  event.routeCount = plan.event(0).routeCount;
  delivery = {};
  status = sink.deliver(event, event.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  event.eventOrdinal = plan.event(1).eventOrdinal;
  event.scheduledTime = plan.event(1).scheduledTime;
  event.routes = plan.event(1).routes;
  event.routeCount = plan.event(1).routeCount;
  delivery = {};
  status = sink.deliver(event, event.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  require(sink.metrics().batchMaximumLiveBytes > 0 &&
              sink.metrics().batchRetainedStorageBytes > 0 &&
              sink.metrics().failureCount == 0 &&
              source->metrics().preparedEventCount == 3 &&
              registeredBatches->batchCount(synthetic.identifier) == 2,
          "variable-batch storage/failure metrics are incomplete");
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);

  file = -1;
  group = -1;
  require(nc_open(path.c_str(), NC_NOWRITE, &file) == NC_NOERR &&
              nc_inq_ncid(file, "wave-vortex", &group) == NC_NOERR,
          "open variable observation output");
  int sampleDimension = -1, profileDimension = -1;
  std::size_t sampleCount = 0, profileCount = 0;
  require(nc_inq_dimid(group, "synthetic_sample", &sampleDimension) ==
                  NC_NOERR &&
              nc_inq_dimlen(group, sampleDimension, &sampleCount) == NC_NOERR &&
              sampleCount == 3 &&
              nc_inq_dimid(group, "synthetic_profile", &profileDimension) ==
                  NC_NOERR &&
              nc_inq_dimlen(group, profileDimension, &profileCount) ==
                  NC_NOERR &&
              profileCount == 2,
          "flat variable observation axes have the wrong committed extent");
  int progressVariable = -1;
  std::array<long long, 2> sampleProgress{};
  require(nc_inq_varid(group, "portableCommitted_synthetic_sample",
                       &progressVariable) == NC_NOERR &&
              nc_get_var_longlong(group, progressVariable,
                                  sampleProgress.data()) == NC_NOERR &&
              sampleProgress == std::array<long long, 2>{3, 3},
          "zero-length batch changed committed sample progress");
  int integerVariable = -1, booleanVariable = -1, textVariable = -1;
  nc_type integerType = NC_NAT, booleanType = NC_NAT, textType = NC_NAT;
  require(nc_inq_varid(group, "synthetic_pass", &integerVariable) == NC_NOERR &&
              nc_inq_vartype(group, integerVariable, &integerType) == NC_NOERR &&
              integerType == NC_INT64 &&
              nc_inq_varid(group, "synthetic_valid", &booleanVariable) ==
                  NC_NOERR &&
              nc_inq_vartype(group, booleanVariable, &booleanType) == NC_NOERR &&
              booleanType == NC_UBYTE &&
              nc_inq_varid(group, "synthetic_label", &textVariable) ==
                  NC_NOERR &&
              nc_inq_vartype(group, textVariable, &textType) == NC_NOERR &&
              textType == NC_STRING,
          "integer/Boolean/text observation types were not preserved");
  int metadataRoot = -1, metadata = -1;
  std::size_t schemaLength = 0;
  require(nc_inq_ncid(group, "observingSystems", &metadataRoot) == NC_NOERR &&
              nc_inq_ncid(metadataRoot, "observingSystems-2", &metadata) ==
                  NC_NOERR &&
              nc_inq_attlen(metadata, NC_GLOBAL,
                            "portableObservationSchemaIdentifier",
                            &schemaLength) == NC_NOERR &&
              schemaLength == std::string("synthetic-variable-observation").size() &&
              nc_close(file) == NC_NOERR,
          "observation schema identity was not persisted");

  WVModelOutputNetCDFInspection inspection;
  persistence = WVModelOutputNetCDFSink::inspect({path.string()}, inspection);
  require(static_cast<bool>(persistence) &&
              inspection.observerRecord.observers.size() == 2,
          "generic graph reader reconstructed " +
              std::to_string(inspection.observerRecord.observers.size()) +
              " observers: " + persistence.message);
  require(inspection.observationSchemas.size() == 1 &&
              inspection.observationSchemas[0].observerIdentifier ==
                  synthetic.identifier &&
              inspection.observationSchemas[0].schema.identifier ==
                  "synthetic-variable-observation" &&
              inspection.observationSchemas[0].schema.axes.size() == 3 &&
              inspection.observationSchemas[0].schema.variables.size() == 11,
          "generic graph reader did not reconstruct the provisional schema");
  const auto &inspectedSchema = inspection.observationSchemas[0].schema;
  const auto inspectedBins = std::find_if(
      inspectedSchema.variables.begin(), inspectedSchema.variables.end(),
      [](const auto &variable) { return variable.identifier == "bins"; });
  const auto inspectedRows = std::find_if(
      inspectedSchema.variables.begin(), inspectedSchema.variables.end(),
      [](const auto &variable) { return variable.identifier == "row-count"; });
  require(inspectedBins != inspectedSchema.variables.end() &&
              inspectedBins->scalarType ==
                  WVObservationScalarType::complex64 &&
              inspectedBins->dimensionIdentifiers ==
                  std::vector<std::string>{"depth", "sample"} &&
              inspectedRows != inspectedSchema.variables.end() &&
              inspectedRows->raggedRole ==
                  WVObservationRaggedRole::rowCount &&
              inspectedRows->raggedChildAxisIdentifier == "sample",
          "generic graph reader changed typed or ragged schema declarations");

  const auto requireRejectedTextAttribute =
      [&](const std::string &label, const std::string &variableName,
          const char *attributeName, const std::string &value) {
        const auto malformedPath = directory.path / (label + ".nc");
        std::filesystem::copy_file(path, malformedPath);
        int malformedFile = -1;
        int malformedGroup = -1;
        int malformedVariable = -1;
        require(nc_open(malformedPath.c_str(), NC_WRITE, &malformedFile) ==
                    NC_NOERR &&
                    nc_inq_ncid(malformedFile, "wave-vortex",
                                &malformedGroup) == NC_NOERR &&
                    nc_inq_varid(malformedGroup, variableName.c_str(),
                                 &malformedVariable) == NC_NOERR &&
                    nc_redef(malformedFile) == NC_NOERR &&
                    nc_put_att_text(malformedGroup, malformedVariable,
                                    attributeName, value.size(),
                                    value.c_str()) == NC_NOERR &&
                    nc_enddef(malformedFile) == NC_NOERR &&
                    nc_close(malformedFile) == NC_NOERR,
                "failed to create malformed " + label + " fixture");
        WVModelOutputNetCDFInspection malformedInspection;
        const auto malformedStatus = WVModelOutputNetCDFSink::inspect(
            {malformedPath.string()}, malformedInspection);
        require(!malformedStatus,
                "reader accepted malformed " + label + " metadata");
      };
  requireRejectedTextAttribute(
      "unknown-layout", "synthetic_pass",
      "portableObservationValueLayout", "unknown");
  requireRejectedTextAttribute(
      "unknown-coordinate", "synthetic_time", "portableCoordinateRole",
      "unknown");
  requireRejectedTextAttribute(
      "unknown-ragged", "synthetic_row_count", "portableRaggedRole",
      "unknown");
  requireRejectedTextAttribute("custom-attribute-drift",
                               "synthetic_bins_real", "provider", "changed");
  const auto axisRolePath = directory.path / "unknown-axis-role.nc";
  std::filesystem::copy_file(path, axisRolePath);
  int axisFile = -1;
  int axisGroup = -1;
  int axisVariable = -1;
  const char *unknownRole = "unknown";
  require(nc_open(axisRolePath.c_str(), NC_WRITE, &axisFile) == NC_NOERR &&
              nc_inq_ncid(axisFile, "wave-vortex", &axisGroup) == NC_NOERR &&
              nc_inq_varid(axisGroup, "synthetic_time", &axisVariable) ==
                  NC_NOERR &&
              nc_redef(axisFile) == NC_NOERR &&
              nc_put_att_string(axisGroup, axisVariable,
                                "portableObservationAxisCoordinateRoles", 1,
                                &unknownRole) == NC_NOERR &&
              nc_enddef(axisFile) == NC_NOERR &&
              nc_close(axisFile) == NC_NOERR,
          "failed to create malformed axis-role fixture");
  WVModelOutputNetCDFInspection malformedAxisInspection;
  persistence = WVModelOutputNetCDFSink::inspect(
      {axisRolePath.string()}, malformedAxisInspection);
  require(!persistence, "reader accepted an unknown axis coordinate role");

  VariableBatchSource driftedSource(2);
  WVModelOutputNetCDFSink drifted;
  persistence = WVModelOutputNetCDFSink::openAppend(
      configuration, descriptor, layout, &driftedSource, drifted);
  require(!persistence &&
              persistence.code == WVCheckpointStatusCode::appendConflict,
          "append accepted observation schema drift");

  std::unique_ptr<WVObserverOutputEvaluationService> appendSource;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, false, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), appendSource);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(
      configuration, descriptor, layout, appendSource.get(), append);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan appendPlan;
  status = WVOutputPlan::create(descriptor, initialTime + 1.0,
                                initialTime + 2.0, append.progress(),
                                appendPlan);
  require(static_cast<bool>(status) && appendPlan.eventCount() == 1,
          "variable-batch append plan");
  status = append.preflight(appendPlan);
  require(static_cast<bool>(status), status.message);
  event.eventOrdinal = appendPlan.event(0).eventOrdinal;
  event.scheduledTime = appendPlan.event(0).scheduledTime;
  event.routes = appendPlan.event(0).routes;
  event.routeCount = appendPlan.event(0).routeCount;
  delivery = {};
  status = append.deliver(event, event.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  persistence = append.close();
  require(static_cast<bool>(persistence), persistence.message);
}

void testRegisteredTopologyProviders() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto initialTime = checkpoint.state.t;
  const auto path = directory.path / "registered-topologies.nc";
  auto record = recordFor(checkpoint, path);
  const auto addObserver = [&](std::string identifier, std::string name,
                               std::string type) {
    WVObserverRecord observer;
    observer.identifier = std::move(identifier);
    observer.name = std::move(name);
    observer.typeIdentifier = std::move(type);
    record.observers.push_back(std::move(observer));
  };
  addObserver("fixed-bin", "fixed-bin", "WVTestFixedBin");
  addObserver("moving-track", "moving-track", "WVTestMovingTrack");
  addObserver("variable-pass", "variable-pass", "WVTestVariablePass");
  addObserver("ragged-a", "ragged-a", "WVTestRaggedProfile");
  addObserver("ragged-b", "ragged-b", "WVTestRaggedProfile");
  auto &primary = record.outputFiles[0].groups[0];
  primary.observerIdentifiers.insert(primary.observerIdentifiers.end(),
                                     {"fixed-bin", "moving-track",
                                      "variable-pass", "ragged-a"});
  auto secondary = primary;
  secondary.identifier = "ragged-secondary";
  secondary.name = "ragged-secondary";
  secondary.containsCompleteCoefficientRestart = false;
  secondary.observerIdentifiers = {"ragged-b"};
  record.outputFiles[0].groups.push_back(std::move(secondary));

  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  std::unique_ptr<WVObserverOutputEvaluationService> source;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, false, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), source);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      {checkpoint, false}, descriptor, layout, source.get(), sink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan plan;
  status = WVOutputPlan::create(descriptor, initialTime, initialTime + 1.0, {},
                                plan);
  require(static_cast<bool>(status) && plan.groupCount() == 2,
          "registered topology plan did not retain both groups");
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  for (std::size_t eventIndex = 0; eventIndex < plan.eventCount(); ++eventIndex) {
    const auto planned = plan.event(eventIndex);
    WVOutputEvent event;
    event.eventOrdinal = planned.eventOrdinal;
    event.scheduledTime = planned.scheduledTime;
    event.state = eventState(checkpoint);
    event.routes = planned.routes;
    event.routeCount = planned.routeCount;
    for (std::size_t route = 0; route < planned.routeCount; ++route) {
      WVOutputDeliveryResult delivery;
      status = sink.deliver(event, planned.routes[route], delivery);
      require(static_cast<bool>(status), status.message);
    }
  }
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);

  WVModelOutputNetCDFInspection inspection;
  persistence = WVModelOutputNetCDFSink::inspect({path.string()}, inspection);
  require(static_cast<bool>(persistence), persistence.message);
  const auto raggedSchemas = std::count_if(
      inspection.observationSchemas.begin(),
      inspection.observationSchemas.end(), [](const auto &candidate) {
        return candidate.schema.identifier == "test-ragged-profile-v1" &&
               (candidate.observerIdentifier == "ragged-a" ||
                candidate.observerIdentifier == "ragged-b");
      });
  const auto fixedSchema = std::find_if(
      inspection.observationSchemas.begin(),
      inspection.observationSchemas.end(), [](const auto &candidate) {
        return candidate.observerIdentifier == "fixed-bin";
      });
  require(raggedSchemas == 2 &&
              inspection.observationSchemas.size() == 5 &&
              fixedSchema != inspection.observationSchemas.end(),
          "registered providers or same-provider ownership did not round trip");
  const auto fixedValue = std::find_if(
      fixedSchema->schema.variables.begin(), fixedSchema->schema.variables.end(),
      [](const auto &variable) { return variable.identifier == "value"; });
  require(fixedValue != fixedSchema->schema.variables.end() &&
              fixedValue->attributes.size() == 2 &&
              fixedValue->attributes[0].name == "ordered-a" &&
              fixedValue->attributes[1].name == "ordered-b",
          "ordered schema attributes did not round trip");

  std::unique_ptr<WVObserverOutputEvaluationService> appendSource;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, false, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), appendSource);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(
      {checkpoint, false}, descriptor, layout, appendSource.get(), append);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan appendPlan;
  status = WVOutputPlan::create(descriptor, initialTime + 1.0,
                                initialTime + 2.0, append.progress(),
                                appendPlan);
  require(static_cast<bool>(status) && appendPlan.eventCount() == 1,
          "same-provider append plan is incorrect");
  status = append.preflight(appendPlan);
  require(static_cast<bool>(status), status.message);
  const auto planned = appendPlan.event(0);
  WVOutputEvent appendEvent;
  appendEvent.eventOrdinal = planned.eventOrdinal;
  appendEvent.scheduledTime = planned.scheduledTime;
  appendEvent.state = eventState(checkpoint);
  appendEvent.routes = planned.routes;
  appendEvent.routeCount = planned.routeCount;
  for (std::size_t route = 0; route < planned.routeCount; ++route) {
    WVOutputDeliveryResult delivery;
    status = append.deliver(appendEvent, planned.routes[route], delivery);
    require(static_cast<bool>(status), status.message);
  }
  persistence = append.close();
  require(static_cast<bool>(persistence), persistence.message);

  const auto invalidPath = directory.path / "registered-ragged-retry.nc";
  auto invalidRecord = recordFor(checkpoint, invalidPath);
  WVObserverRecord malformed;
  malformed.identifier = "malformed-ragged";
  malformed.name = "malformed";
  malformed.typeIdentifier = "WVTestRaggedProfile";
  invalidRecord.observers.push_back(malformed);
  invalidRecord.outputFiles[0].groups[0].observerIdentifiers.push_back(
      malformed.identifier);
  auto invalidDescriptor = descriptorFor(invalidRecord);
  WVIntegrationStateLayout invalidLayout;
  status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, invalidDescriptor, invalidLayout);
  require(static_cast<bool>(status), status.message);
  raggedProfileProvider->resetCounts();
  std::unique_ptr<WVObserverOutputEvaluationService> invalidSource;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, false, invalidDescriptor,
      std::make_unique<WVReferenceFFTEngine>(), invalidSource);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink invalidSink;
  persistence = WVModelOutputNetCDFSink::createNew(
      {checkpoint, false}, invalidDescriptor, invalidLayout,
      invalidSource.get(), invalidSink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan invalidPlan;
  status = WVOutputPlan::create(invalidDescriptor, initialTime, initialTime, {},
                                invalidPlan);
  require(static_cast<bool>(status), status.message);
  status = invalidSink.preflight(invalidPlan);
  require(static_cast<bool>(status), status.message);
  const auto invalidPlanned = invalidPlan.event(0);
  WVOutputEvent invalidEvent;
  invalidEvent.eventOrdinal = invalidPlanned.eventOrdinal;
  invalidEvent.scheduledTime = invalidPlanned.scheduledTime;
  invalidEvent.state = eventState(checkpoint);
  invalidEvent.routes = invalidPlanned.routes;
  invalidEvent.routeCount = invalidPlanned.routeCount;
  WVOutputDeliveryResult delivery;
  status = invalidSink.deliver(invalidEvent, invalidPlanned.routes[0], delivery);
  require(!status, "malformed registered ragged batch was accepted");
  delivery = {};
  status = invalidSink.deliver(invalidEvent, invalidPlanned.routes[0], delivery);
  require(!status &&
              raggedProfileProvider->batchCount(malformed.identifier) == 1,
          "registered exact-event retry regenerated its retained batch");
  persistence = invalidSink.close();
  require(static_cast<bool>(persistence), persistence.message);
}

void testObservationGraphCollisionPreflight() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto requireRejected = [&](bool conflictingAxis, bool conflictingRole,
                                   const std::string &filename) {
    const auto path = directory.path / filename;
    auto record = recordFor(checkpoint, path);
    for (const auto &identifier : {"conflict-a", "conflict-b"}) {
      WVObserverRecord observer;
      observer.identifier = identifier;
      observer.name = identifier;
      observer.typeIdentifier = "WVTestObservationBatches";
      record.observers.push_back(observer);
      record.outputFiles[0].groups[0].observerIdentifiers.push_back(identifier);
    }
    auto descriptor = descriptorFor(record);
    WVIntegrationStateLayout layout;
    auto status = WVIntegrationStateLayout::create(
        checkpoint.state.coefficients.shape, descriptor, layout);
    require(static_cast<bool>(status), status.message);
    ConflictingSchemaSource source(conflictingAxis, conflictingRole);
    WVModelOutputNetCDFSink sink;
    const auto persistence = WVModelOutputNetCDFSink::createNew(
        {checkpoint, false}, descriptor, layout, &source, sink);
    require(!persistence && !std::filesystem::exists(path),
            conflictingAxis
                ? "incompatible shared axes survived complete-graph preflight"
                : "duplicate persisted variable names survived complete-graph preflight");
  };
  requireRejected(false, false, "variable-collision.nc");
  requireRejected(true, false, "axis-collision.nc");
  requireRejected(true, true, "axis-role-collision.nc");
}

void testCoincidentRoutesShareExactEventBatches() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto initialTime = checkpoint.state.t;
  const auto primaryPath = directory.path / "coincident-primary.nc";
  const auto secondaryPath = directory.path / "coincident-secondary.nc";
  auto record = recordFor(checkpoint, primaryPath);
  WVObserverRecord synthetic;
  synthetic.identifier = "coincident-observations";
  synthetic.name = "coincident";
  synthetic.typeIdentifier = "WVTestObservationBatches";
  record.observers.push_back(synthetic);
  record.outputFiles[0].groups[0].observerIdentifiers.push_back(
      synthetic.identifier);
  auto secondary = record.outputFiles[0];
  secondary.identifier = "secondary";
  secondary.destination = secondaryPath.string();
  secondary.groups[0].identifier = "secondary-restart";
  secondary.groups[0].name = "wave-vortex-secondary";
  record.outputFiles.push_back(std::move(secondary));

  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  registeredBatches->resetCounts();
  std::unique_ptr<WVObserverOutputEvaluationService> source;
  status = WVObserverOutputEvaluationService::create(
      checkpoint.configuration, false, descriptor,
      std::make_unique<WVReferenceFFTEngine>(), source);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      {checkpoint, false}, descriptor, layout, source.get(), sink);
  require(static_cast<bool>(persistence), persistence.message);
  WVOutputPlan plan;
  status = WVOutputPlan::create(descriptor, initialTime, initialTime, {}, plan);
  require(static_cast<bool>(status) && plan.eventCount() == 1 &&
              plan.event(0).routeCount == 2,
          "coincident-route output plan did not preserve two routes");
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);

  WVOutputEvent event;
  event.eventOrdinal = plan.event(0).eventOrdinal;
  event.scheduledTime = plan.event(0).scheduledTime;
  event.state = eventState(checkpoint);
  event.routes = plan.event(0).routes;
  event.routeCount = plan.event(0).routeCount;
  WVOutputDeliveryResult delivery;
  status = sink.deliver(event, event.routes[0], delivery);
  require(static_cast<bool>(status) &&
              source->metrics().preparedEventCount == 2 &&
              registeredBatches->batchCount(synthetic.identifier) == 1,
          "first coincident route did not evaluate its exact event once");
  delivery = {};
  status = sink.deliver(event, event.routes[1], delivery);
  require(static_cast<bool>(status) &&
              source->metrics().preparedEventCount == 2 &&
              registeredBatches->batchCount(synthetic.identifier) == 1,
          "second coincident route regenerated an exact-event batch");
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);
}

} // namespace

int main() {
  try {
    auto registration = WVObserverFactoryRegistry::registerImplementation(
        std::make_shared<WVTestFieldsImplementation>());
    require(static_cast<bool>(registration), registration.message);
    registration = WVObserverFactoryRegistry::registerImplementation(
        std::make_shared<WVTestPortablePointDiagnosticImplementation>());
    require(static_cast<bool>(registration), registration.message);
    registeredBatches =
        std::make_shared<WVTestObservationBatchesImplementation>();
    registration = WVObserverFactoryRegistry::registerImplementation(
        registeredBatches);
    require(static_cast<bool>(registration), registration.message);
    fixedBinProvider = std::make_shared<WVTestTopologyImplementation>(
        "WVTestFixedBin", TestTopology::fixedBin);
    movingTrackProvider = std::make_shared<WVTestTopologyImplementation>(
        "WVTestMovingTrack", TestTopology::movingTrack);
    variablePassProvider = std::make_shared<WVTestTopologyImplementation>(
        "WVTestVariablePass", TestTopology::variablePass);
    raggedProfileProvider = std::make_shared<WVTestTopologyImplementation>(
        "WVTestRaggedProfile", TestTopology::raggedProfile);
    for (const auto &provider :
         {fixedBinProvider, movingTrackProvider, variablePassProvider,
          raggedProfileProvider}) {
      registration =
          WVObserverFactoryRegistry::registerImplementation(provider);
      require(static_cast<bool>(registration), registration.message);
    }
    require(static_cast<bool>(registerQuadraticSchedule()),
            "quadratic schedule registration");
    testCreateReadAndAppend();
    testLinearInitialCoefficientsAndPassiveFields();
    testTransactionalRefusal();
    testMultipleFilesGroupsAndSharedState();
    testOptionalMatlabFixture();
    testOptionalMatlabLinearFixture();
    testOptionalMatlabPassiveFixture();
    testAlgorithmicSchedulePersistence();
    testVariableObservationBatches();
    testRegisteredTopologyProviders();
    testObservationGraphCollisionPreflight();
    testCoincidentRoutesShareExactEventBatches();
    std::cout << "PASS: MATLAB-compatible model-output persistence\n";
    return 0;
  } catch (const std::exception &exception) {
    std::cerr << "FAIL: " << exception.what() << '\n';
    return 1;
  }
}
