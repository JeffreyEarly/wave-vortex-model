#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"
#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"

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
  const std::string &fieldListAttribute() const noexcept override {
    static const std::string value = "fieldNames";
    return value;
  }
  bool recordsEulerianFields() const noexcept override { return true; }
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
  const std::string &fieldListAttribute() const noexcept override {
    static const std::string value = "fieldNames";
    return value;
  }
  bool recordsFixedPoints() const noexcept override { return true; }
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
  const std::string &fieldListAttribute() const noexcept override {
    static const std::string value;
    return value;
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
};

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
      output = std::move(schema);
      return WVKernelStatus::ok();
    }
    schema.identifier = "synthetic-variable-observation";
    schema.version = version_;
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
    eventOrdinal_ = event.eventOrdinal;
    scheduledTime_ = event.scheduledTime;
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

private:
  std::uint32_t version_ = 1;
  bool failFirstBatch_ = false;
  bool failedOnce_ = false;
  std::size_t eventOrdinal_ = 0;
  double scheduledTime_ = 0.0;
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
  auto record = recordFor(checkpoint, path);
  WVObserverRecord synthetic;
  synthetic.identifier = "synthetic-observations";
  synthetic.name = "synthetic";
  synthetic.typeIdentifier = "WVTestObservationBatches";
  record.observers.push_back(synthetic);
  record.outputFiles[0].groups[0].observerIdentifiers.push_back(
      synthetic.identifier);
  auto descriptor = descriptorFor(record);
  WVIntegrationStateLayout layout;
  auto status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration configuration{checkpoint, false};
  VariableBatchSource source(1, true);
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      configuration, descriptor, layout, &source, sink);
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
  WVOutputDeliveryResult delivery;
  status = sink.deliver(event, event.routes[0], delivery);
  require(!status, "malformed ragged batch was written");
  int file = -1, group = -1, timeDimension = -1;
  std::size_t timeCount = 99;
  require(nc_open(path.c_str(), NC_NOWRITE, &file) == NC_NOERR &&
              nc_inq_ncid(file, "wave-vortex", &group) == NC_NOERR &&
              nc_inq_dimid(group, "t", &timeDimension) == NC_NOERR &&
              nc_inq_dimlen(group, timeDimension, &timeCount) == NC_NOERR &&
              timeCount == 0 && nc_close(file) == NC_NOERR,
          "failed batch mutated the output before validation");

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
              sink.metrics().failureCount == 1,
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
          "generic graph reader dropped the variable-batch observer");

  VariableBatchSource driftedSource(2);
  WVModelOutputNetCDFSink drifted;
  persistence = WVModelOutputNetCDFSink::openAppend(
      configuration, descriptor, layout, &driftedSource, drifted);
  require(!persistence &&
              persistence.code == WVCheckpointStatusCode::appendConflict,
          "append accepted observation schema drift");

  VariableBatchSource appendSource;
  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(
      configuration, descriptor, layout, &appendSource, append);
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

} // namespace

int main() {
  try {
    auto registration = WVObserverFactoryRegistry::registerImplementation(
        std::make_shared<WVTestFieldsImplementation>());
    require(static_cast<bool>(registration), registration.message);
    registration = WVObserverFactoryRegistry::registerImplementation(
        std::make_shared<WVTestPortablePointDiagnosticImplementation>());
    require(static_cast<bool>(registration), registration.message);
    registration = WVObserverFactoryRegistry::registerImplementation(
        std::make_shared<WVTestObservationBatchesImplementation>());
    require(static_cast<bool>(registration), registration.message);
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
    std::cout << "PASS: MATLAB-compatible model-output persistence\n";
    return 0;
  } catch (const std::exception &exception) {
    std::cerr << "FAIL: " << exception.what() << '\n';
    return 1;
  }
}
