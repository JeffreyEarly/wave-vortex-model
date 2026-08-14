#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"
#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"

#include "WVReferenceFFTEngine.hpp"

#include <netcdf.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

void require(bool condition, const std::string &message) {
  if (!condition)
    throw std::runtime_error(message);
}

std::filesystem::path fixture(const std::string &name) {
  return std::filesystem::path(WV_CHECKPOINT_FIXTURE_DIR) / name;
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
  const auto result = WVCheckpointReader::read(
      path, checkpoint);
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
  coefficients.kind = WVObserverKind::coefficients;
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

WVCompositeState eventState(const WVCheckpoint &checkpoint) {
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
    if (observer.kind == WVObserverKind::eulerianFields &&
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
    if (observer.kind == WVObserverKind::lagrangianParticles &&
        !observer.fieldNames.empty())
      output.push_back({observer.identifier + "-u",
                        observer.name + "_u",
                        WVOutputValueType::real64,
                        {observer.name + "_id"},
                        {observer.x.size()},
                        "m s-1",
                        "x-component of the fluid velocity, recorded along "
                        "the particle trajectory"});
    if (observer.kind == WVObserverKind::mooring &&
        !observer.fieldNames.empty())
      output.push_back({observer.identifier + "-u",
                        observer.name + "_u",
                        WVOutputValueType::real64,
                        {observer.name + "_z", observer.name + "_id"},
                        {observer.z.size(), observer.x.size()},
                        "m s-1",
                        "x-component of the fluid velocity, recorded at the "
                        "mooring"});
    return WVKernelStatus::ok();
  }

  WVKernelStatus prepare(const WVCompositeOutputEvent &) override {
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
                         const WVCompositeOutputPlan &plan,
                         std::size_t eventIndex,
                         const WVCheckpoint &checkpoint) {
  const auto planned = plan.event(eventIndex);
  require(planned.routeCount == 1, "test plan route count");
  WVCompositeOutputEvent event;
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = eventState(checkpoint);
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  WVCompositeOutputDeliveryResult delivery;
  const auto status = sink.deliver(event, planned.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  require(delivery.writeCount == 7,
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

void testCreateReadAndAppend() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto path = directory.path / "multigroup.nc";
  auto record = recordFor(checkpoint, path);
  auto descriptor = descriptorFor(record);
  WVCompositeStateLayout layout;
  auto status = WVCompositeStateLayout::create(
      checkpoint.state.coefficients.shape, descriptor, layout);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration configuration{checkpoint, false};
  WVModelOutputNetCDFSink sink;
  auto persistence = WVModelOutputNetCDFSink::createNew(
      configuration, descriptor, layout, nullptr, sink);
  require(static_cast<bool>(persistence),
          persistence.message + " at " + persistence.location);

  WVCompositeOutputPlan firstPlan;
  status = WVCompositeOutputPlan::create(
      descriptor, checkpoint.state.t, checkpoint.state.t + 1.0, {}, firstPlan);
  require(static_cast<bool>(status), status.message);
  auto incompatibleRecord = record;
  incompatibleRecord.outputFiles.front().groups.front().identifier =
      "different-group";
  auto incompatibleDescriptor = descriptorFor(incompatibleRecord);
  WVCompositeOutputPlan incompatiblePlan;
  status = WVCompositeOutputPlan::create(
      incompatibleDescriptor, checkpoint.state.t, checkpoint.state.t + 1.0, {},
      incompatiblePlan);
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

  WVCheckpoint restored;
  persistence = WVCheckpointReader::read(path.string(), restored);
  require(static_cast<bool>(persistence), persistence.message);
  require(restored.state.t == checkpoint.state.t,
          "latest output state was not restartable");

  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(configuration, descriptor,
                                                    layout, nullptr, append);
  require(static_cast<bool>(persistence), persistence.message);
  WVCompositeOutputPlan appendPlan;
  status = WVCompositeOutputPlan::create(descriptor, checkpoint.state.t,
                                         checkpoint.state.t + 1.0,
                                         append.progress(), appendPlan);
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
  fields.name = "WVEulerianFields";
  fields.kind = WVObserverKind::eulerianFields;
  fields.fieldNames = {"Ap", "Am", "A0", "u", "psi"};
  record.observers.push_back(fields);
  WVObserverRecord mooring;
  mooring.identifier = "mooring-central";
  mooring.name = "central";
  mooring.kind = WVObserverKind::mooring;
  mooring.fieldNames = {"u"};
  mooring.x = {-1.0, checkpoint.configuration.Lx};
  mooring.y = {checkpoint.configuration.Ly,
               0.5 * checkpoint.configuration.Ly};
  record.observers.push_back(mooring);
  record.outputFiles.front().groups.front().observerIdentifiers =
      {fields.identifier, mooring.identifier};
  auto descriptor = descriptorFor(record);
  WVCompositeStateLayout layout;
  auto status = WVCompositeStateLayout::create(
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

  WVCompositeOutputPlan plan;
  status = WVCompositeOutputPlan::create(
      descriptor, checkpoint.state.t, checkpoint.state.t, {}, plan);
  require(static_cast<bool>(status), status.message);
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  const auto planned = plan.event(0);
  WVCompositeOutputEvent event;
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = eventState(checkpoint);
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  WVCompositeOutputDeliveryResult delivery;
  status = sink.deliver(event, planned.routes[0], delivery);
  require(static_cast<bool>(status), status.message);
  require(delivery.writeCount == 3,
          "linear delivery must write Eulerian u, mooring u, and time");
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
  require(nc_inq_varid(group, "u", &variable) == NC_NOERR,
          "locate Eulerian u");
  require(nc_inq_varndims(group, variable, &rank) == NC_NOERR && rank == 4,
          "linear u must remain [t,z,y,x]");
  require(nc_inq_varid(group, "psi", &variable) == NC_NOERR &&
              nc_inq_varndims(group, variable, &rank) == NC_NOERR &&
              rank == 3,
          "linear psi must remain initial-only [z,y,x]");
  require(nc_inq_varid(group, "central_u", &variable) == NC_NOERR &&
              nc_inq_varndims(group, variable, &rank) == NC_NOERR &&
              rank == 3,
          "mooring field must use [t,id,z] NetCDF order");
  require(nc_inq_varid(group, "central_x", &variable) == NC_NOERR,
          "mooring x coordinate is absent");
  std::vector<double> x(2);
  require(nc_get_var_double(group, variable, x.data()) == NC_NOERR &&
              x[0] == checkpoint.configuration.Lx - 1.0 && x[1] == 0.0,
          "mooring periodic x coordinates changed");
  require(nc_close(root) == NC_NOERR, "close linear passive output");

  WVModelOutputNetCDFInspection inspection;
  persistence = WVModelOutputNetCDFSink::inspect({path.string()}, inspection);
  require(static_cast<bool>(persistence), persistence.message);
  require(inspection.latestRestart.state.coefficients.Ap[1].real == 1.0 &&
              inspection.latestRestart.state.coefficients.Ap[1].imag == 2.0,
          "linear initial coefficient did not round-trip");

  auto appendDescriptor = descriptorFor(inspection.observerRecord);
  std::unique_ptr<WVObserverOutputEvaluationService> appendSource;
  status = WVObserverOutputEvaluationService::create(
      inspection.latestRestart.configuration, true, appendDescriptor,
      std::make_unique<WVReferenceFFTEngine>(), appendSource);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFConfiguration appendConfiguration{
      inspection.latestRestart, true};
  WVModelOutputNetCDFSink append;
  persistence = WVModelOutputNetCDFSink::openAppend(
      appendConfiguration, appendDescriptor, inspection.stateLayout,
      appendSource.get(), append);
  require(static_cast<bool>(persistence), persistence.message);
  WVCompositeOutputPlan appendPlan;
  status = WVCompositeOutputPlan::create(
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
  WVCompositeStateLayout layout;
  auto status = WVCompositeStateLayout::create(
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
  coefficients.kind = WVObserverKind::coefficients;
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  WVObserverRecord particles;
  particles.identifier = "particles";
  particles.name = "particles";
  particles.kind = WVObserverKind::lagrangianParticles;
  particles.stateBlockIdentifiers = {"particles-x", "particles-y"};
  particles.x = {0.1, 0.2};
  particles.y = {0.3, 0.4};
  particles.z = {-100.0, -300.0};
  particles.isXYOnly = true;
  particles.horizontalAbsoluteTolerance = 1e-4;
  WVObserverRecord tracer;
  tracer.identifier = "tracer";
  tracer.name = "tracer";
  tracer.kind = WVObserverKind::tracer;
  tracer.stateBlockIdentifiers = {"tracer-state"};
  tracer.isXYOnly = false;
  tracer.shouldAntialias = true;
  WVObserverRecord fields;
  fields.identifier = "fields";
  fields.name = "WVEulerianFields";
  fields.kind = WVObserverKind::eulerianFields;
  fields.fieldNames = {"u", "v", "rho_e"};
  WVObserverRecord mooring;
  mooring.identifier = "mooring";
  mooring.name = "mooring";
  mooring.kind = WVObserverKind::mooring;
  mooring.fieldNames = {"u", "v"};
  mooring.x = {0.0, 0.5 * checkpoint.configuration.Lx};
  mooring.y = {0.0, 0.5 * checkpoint.configuration.Ly};
  record.observers = {coefficients, fields, mooring, particles, tracer};
  const auto end = checkpoint.state.t + 1.0;
  const char *exportPath = std::getenv("WV_RUNTIME_MODEL_OUTPUT_EXPORT");
  const auto first = exportPath == nullptr
                         ? directory.path / "first.nc"
                         : std::filesystem::path(exportPath);
  const auto second = exportPath == nullptr
                          ? directory.path / "second.nc"
                          : std::filesystem::path(std::string(exportPath) +
                                                  ".second.nc");
  record.outputFiles = {{"first",
                         first.string(),
                         {{"restart",
                           "wave-vortex",
                           {1.0, checkpoint.state.t, end},
                           {"coefficients", "fields", "mooring", "particles",
                            "tracer"},
                           true},
                          {"shared",
                           "shared",
                           {1.0, checkpoint.state.t, end},
                           {"fields", "mooring", "particles", "tracer"},
                           false}}},
                        {"second",
                         second.string(),
                         {{"restart",
                           "restart",
                           {1.0, checkpoint.state.t, end},
                           {"coefficients", "fields", "mooring", "particles",
                            "tracer"},
                           true}}}};
  auto descriptor = descriptorFor(record);
  WVCompositeStateLayout layout;
  auto status = WVCompositeStateLayout::create(
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
  WVCompositeOutputPlan plan;
  status = WVCompositeOutputPlan::create(descriptor, checkpoint.state.t, end,
                                         {}, plan);
  require(static_cast<bool>(status), status.message);
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  WVCompositeOutputEvent event;
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
    WVCompositeOutputDeliveryResult delivery;
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
                nc_inq_ncid(file, "wave-vortex", &group) == NC_NOERR &&
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
  const auto restoredParticles = std::find_if(
      inspection.observerRecord.observers.begin(),
      inspection.observerRecord.observers.end(), [](const auto &observer) {
        return observer.identifier == "particles";
      });
  require(restoredParticles != inspection.observerRecord.observers.end() &&
              restoredParticles->z == std::vector<double>({-100.0, -300.0}),
          "fixed XY particle z configuration was not reconstructed");
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
  const char *secondPath =
      std::getenv("WV_MATLAB_MODEL_OUTPUT_FIXTURE_SECOND");
  if (secondPath != nullptr)
    paths.emplace_back(secondPath);
  WVModelOutputNetCDFInspection inspection;
  const auto inspectStatus =
      WVModelOutputNetCDFSink::inspect(paths, inspection);
  require(static_cast<bool>(inspectStatus),
          inspectStatus.message + " at " + inspectStatus.location);
  const auto hasKind = [&](WVObserverKind kind) {
    return std::any_of(inspection.observerRecord.observers.begin(),
                       inspection.observerRecord.observers.end(),
                       [&](const auto &observer) {
                         return observer.kind == kind;
                       });
  };
  const bool hasCoefficients = hasKind(WVObserverKind::coefficients);
  const bool hasEulerian = hasKind(WVObserverKind::eulerianFields);
  const bool hasMooring = hasKind(WVObserverKind::mooring);
  const bool hasParticles = hasKind(WVObserverKind::lagrangianParticles);
  const bool hasTracer = hasKind(WVObserverKind::tracer);
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
  WVCompositeStateLayout layout;
  auto status = WVCompositeStateLayout::create(
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
  WVCompositeOutputPlan plan;
  status = WVCompositeOutputPlan::create(
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
  WVCompositeOutputEvent event;
  const auto planned = plan.event(0);
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = {appendInspection.latestRestart.state.view(), blocks.data(),
                 blocks.size()};
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  for (std::size_t route = 0; route < planned.routeCount; ++route) {
    WVCompositeOutputDeliveryResult delivery;
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
              inspection.observerRecord.observers.front().kind ==
                  WVObserverKind::eulerianFields,
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
  WVCompositeOutputPlan plan;
  status = WVCompositeOutputPlan::create(
      descriptor, inspection.latestRestart.state.t,
      inspection.latestRestart.state.t + 1.0, sink.progress(), plan);
  require(static_cast<bool>(status) && plan.eventCount() == 1,
          "MATLAB linear append plan mismatch");
  status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  const auto planned = plan.event(0);
  WVCompositeOutputEvent event;
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = eventState(inspection.latestRestart);
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  WVCompositeOutputDeliveryResult delivery;
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
  const auto persistence =
      WVModelOutputNetCDFSink::inspect({path}, inspection);
  require(static_cast<bool>(persistence),
          persistence.message + " at " + persistence.location);
  require(inspection.observerRecord.observers.size() == 2,
          "MATLAB passive observer graph was not reconstructed");
  const auto coefficients = std::count_if(
      inspection.observerRecord.observers.begin(),
      inspection.observerRecord.observers.end(), [](const auto &observer) {
        return observer.kind == WVObserverKind::coefficients;
      });
  const auto eulerian = std::count_if(
      inspection.observerRecord.observers.begin(),
      inspection.observerRecord.observers.end(), [](const auto &observer) {
        return observer.kind == WVObserverKind::eulerianFields;
      });
  require(coefficients == 1 && eulerian == 1,
          "MATLAB coefficient and Eulerian metadata changed");
}

} // namespace

int main() {
  try {
    testCreateReadAndAppend();
    testLinearInitialCoefficientsAndPassiveFields();
    testTransactionalRefusal();
    testMultipleFilesGroupsAndSharedState();
    testOptionalMatlabFixture();
    testOptionalMatlabLinearFixture();
    testOptionalMatlabPassiveFixture();
    std::cout << "PASS: MATLAB-compatible model-output persistence\n";
    return 0;
  } catch (const std::exception &exception) {
    std::cerr << "FAIL: " << exception.what() << '\n';
    return 1;
  }
}
