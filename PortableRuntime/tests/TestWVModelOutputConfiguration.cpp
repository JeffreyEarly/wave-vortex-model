#include "WaveVortexRuntime/WVModelOutputConfiguration.hpp"

#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
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

struct TemporaryDirectory {
  std::filesystem::path path =
      std::filesystem::temp_directory_path() /
      ("wv-output-configuration-" +
       std::to_string(
           std::chrono::steady_clock::now().time_since_epoch().count()));
  TemporaryDirectory() { std::filesystem::create_directories(path); }
  ~TemporaryDirectory() {
    std::error_code ignored;
    std::filesystem::remove_all(path, ignored);
  }
};

WVCheckpoint checkpointTemplate() {
  WVCheckpoint checkpoint;
  const auto path = std::filesystem::path(WV_RUNTIME_FIXTURE_DIR) /
                    "forcing-nonlinear.nc";
  const auto status = WVCheckpointReader::read(path.string(), checkpoint);
  require(static_cast<bool>(status), status.message);
  return checkpoint;
}

std::vector<char> fileBytes(const std::filesystem::path &path) {
  std::ifstream stream(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(stream),
          std::istreambuf_iterator<char>()};
}

class FailingSampleSource final : public WVObserverSampleSource {
public:
  WVKernelStatus specifications(
      const WVObserverRecord &,
      std::vector<WVObserverOutputVariableSpecification> &) override {
    return {WVKernelStatusCode::allocationFailure,
            "injected output-schema failure"};
  }
  WVKernelStatus prepare(const WVOutputEvent &) override {
    return WVKernelStatus::ok();
  }
  WVKernelStatus value(const WVObserverRecord &,
                       const WVObserverOutputVariableSpecification &,
                       WVObserverOutputValueView &) override {
    return WVKernelStatus::ok();
  }
};

WVPortableObserverRecord allObserverRecord(const WVCheckpoint &checkpoint) {
  WVPortableObserverRecord record;
  const std::vector<std::size_t> coefficientShape = {
      checkpoint.state.coefficients.shape.rows,
      checkpoint.state.coefficients.shape.columns};
  for (const auto *name : {"Ap", "Am", "A0"})
    record.stateBlocks.push_back(
        {name, WVStateScalarType::complex64, coefficientShape,
         WVToleranceKind::coefficientEnergyScaled, 1e-6,
         WVStateOwnership::integratorOwned,
         WVRestartRequirement::requiredDynamicState});
  for (const auto *name : {"particles-x", "particles-y"})
    record.stateBlocks.push_back(
        {name, WVStateScalarType::real64, {2},
         WVToleranceKind::uniformAbsolute, 1e-4,
         WVStateOwnership::integratorOwned,
         WVRestartRequirement::requiredDynamicState});
  record.stateBlocks.push_back(
      {"tracer-state", WVStateScalarType::real64,
       {checkpoint.configuration.Nx, checkpoint.configuration.Ny,
        checkpoint.configuration.Nz},
       WVToleranceKind::uniformAbsolute, 1e-5,
       WVStateOwnership::integratorOwned,
       WVRestartRequirement::requiredDynamicState});

  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "wave-vortex coefficients";
  coefficients.kind = WVObserverKind::coefficients;
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  WVObserverRecord fields;
  fields.identifier = "fields";
  fields.name = "WVEulerianFields";
  fields.kind = WVObserverKind::eulerianFields;
  fields.fieldNames = {"u", "v", "rho_e"};
  WVObserverRecord mooring;
  mooring.identifier = "mooring";
  mooring.name = "mooring";
  mooring.kind = WVObserverKind::mooring;
  mooring.fieldNames = {"u"};
  mooring.x = {0.0};
  mooring.y = {0.0};
  WVObserverRecord particles;
  particles.identifier = "particles";
  particles.name = "particles";
  particles.kind = WVObserverKind::lagrangianParticles;
  particles.stateBlockIdentifiers = {"particles-x", "particles-y"};
  particles.x = {0.1, 0.2};
  particles.y = {0.3, 0.4};
  particles.z = {-100.0, -200.0};
  particles.isXYOnly = true;
  particles.horizontalAbsoluteTolerance = 1e-4;
  WVObserverRecord tracer;
  tracer.identifier = "tracer";
  tracer.name = "tracer";
  tracer.kind = WVObserverKind::tracer;
  tracer.stateBlockIdentifiers = {"tracer-state"};
  record.observers = {coefficients, fields, mooring, particles, tracer};
  return record;
}

WVPortableObserverRecord coefficientRecord(const WVCheckpoint &checkpoint) {
  auto record = allObserverRecord(checkpoint);
  record.stateBlocks.resize(3);
  record.observers.resize(1);
  return record;
}

WVModelOutputFile fileBuilder(const std::filesystem::path &path,
                              const std::string &identifier,
                              double initialTime, double finalTime,
                              bool allObservers) {
  WVModelOutputFile file;
  auto status = WVModelOutputFile::create(path.string(), file, identifier);
  require(static_cast<bool>(status), status.message);
  WVModelOutputGroup *restart = nullptr;
  status = file.addNewEvenlySpacedOutputGroup(
      "wave-vortex", 1.0, initialTime, finalTime, restart, "restart");
  require(static_cast<bool>(status) && restart != nullptr,
          "failed to add restart group");
  for (const auto *observer : {"coefficients", "fields", "mooring",
                               "particles", "tracer"}) {
    if (allObservers || std::string(observer) == "coefficients") {
      status = restart->addObservingSystem(observer);
      require(static_cast<bool>(status), status.message);
    }
  }
  status = restart->containsCompleteCoefficientRestart(true);
  require(static_cast<bool>(status), status.message);
  return file;
}

void deliverFirstEvent(WVModelOutputNetCDFSink &sink,
                       const WVOutputPlan &plan,
                       const WVCheckpoint &checkpoint) {
  auto status = sink.preflight(plan);
  require(static_cast<bool>(status), status.message);
  require(plan.eventCount() != 0, "test output plan has no event");
  const auto planned = plan.event(0);
  WVOutputEvent event;
  event.eventOrdinal = planned.eventOrdinal;
  event.scheduledTime = planned.scheduledTime;
  event.state = {checkpoint.state.view(), nullptr, 0};
  event.routes = planned.routes;
  event.routeCount = planned.routeCount;
  for (std::size_t route = 0; route < planned.routeCount; ++route) {
    WVOutputDeliveryResult delivery;
    status = sink.deliver(event, planned.routes[route], delivery);
    require(static_cast<bool>(status), status.message);
  }
}

void testStructuralCompilation() {
  TemporaryDirectory directory;
  const auto checkpoint = checkpointTemplate();
  auto record = allObserverRecord(checkpoint);
  std::vector<WVModelOutputFile> files;
  files.push_back(fileBuilder(directory.path / "first.nc", "first",
                              checkpoint.state.t, checkpoint.state.t + 2.0,
                              true));
  files.push_back(fileBuilder(directory.path / "second.nc", "second",
                              checkpoint.state.t, checkpoint.state.t + 2.0,
                              true));
  auto *stable = files.front().outputGroupWithName("wave-vortex");
  require(stable != nullptr, "group lookup failed");
  WVModelOutputGroup extra;
  auto status = WVModelOutputGroup::evenlySpaced(
      "diagnostics", 0.5, checkpoint.state.t, checkpoint.state.t + 2.0,
      extra, "diagnostics");
  require(static_cast<bool>(status), status.message);
  for (const auto *observer : {"fields", "mooring", "particles", "tracer"})
    require(static_cast<bool>(extra.addObservingSystem(observer)),
            "failed to configure diagnostic group");
  status = files.front().addOutputGroup(std::move(extra));
  require(static_cast<bool>(status), status.message);
  require(stable == files.front().outputGroupWithName("wave-vortex"),
          "adding a group invalidated a returned group reference");
  require(stable == files.front().outputGroupWithIdentifier("restart"),
          "group identifier lookup failed");
  require(!files.front().addObservingSystem("fields"),
          "file-level addition accepted multiple groups");

  WVModelOutputConfiguration configuration;
  status = WVModelOutputConfiguration::build(
      std::move(record), std::move(files), WVModelOutputPolicy::create,
      checkpoint.state.t, checkpoint.state.t + 2.0, configuration);
  require(static_cast<bool>(status), status.message);
  require(configuration.descriptor().outputFiles().size() == 2,
          "compiled descriptor lost output files");
  require(configuration.plan().metrics().fileCount == 2 &&
              configuration.plan().metrics().groupCount == 3 &&
              configuration.plan().metrics().distinctObserverCount == 5,
          "compiled plan does not match the builder graph");
  require(configuration.policy() == WVModelOutputPolicy::create &&
              configuration.persistentBytes() >=
                  configuration.plan().persistentBytes(),
          "compiled configuration accounting is incomplete");
}

void testValidationAndDeterministicIdentifiers() {
  TemporaryDirectory directory;
  const auto checkpoint = checkpointTemplate();
  WVModelOutputFile first;
  WVModelOutputFile second;
  auto status = WVModelOutputFile::create(
      (directory.path / "same.nc").string(), first);
  require(static_cast<bool>(status), status.message);
  status = WVModelOutputFile::create(
      (directory.path / "." / "same.nc").string(), second);
  require(static_cast<bool>(status) && first.identifier() == second.identifier(),
          "default file identifiers are not deterministic");
  WVModelOutputGroup *group = nullptr;
  status = first.addNewEvenlySpacedOutputGroup(
      "group", 1.0, checkpoint.state.t, checkpoint.state.t + 1.0, group);
  require(static_cast<bool>(status), status.message);
  require(static_cast<bool>(group->addObservingSystem("coefficients")),
          "observer addition failed");
  require(!group->addObservingSystem("coefficients"),
          "duplicate observer membership was accepted");
  require(static_cast<bool>(group->containsCompleteCoefficientRestart(true)),
          "restart declaration failed");
  const auto generatedGroupIdentifier = group->identifier();
  require(!generatedGroupIdentifier.empty(), "group identifier was not generated");

  auto record = coefficientRecord(checkpoint);
  record.observers.front().identifier = "different";
  std::vector<WVModelOutputFile> files;
  files.push_back(std::move(first));
  WVModelOutputConfiguration rejected;
  status = WVModelOutputConfiguration::build(
      std::move(record), std::move(files), WVModelOutputPolicy::create,
      checkpoint.state.t, checkpoint.state.t + 1.0, rejected);
  require(!status, "an unresolved observing system was accepted");
}

void testCreateReplaceAndAppendPolicies() {
  TemporaryDirectory directory;
  auto checkpoint = checkpointTemplate();
  const auto path = directory.path / "policy.nc";
  auto record = coefficientRecord(checkpoint);
  std::vector<WVModelOutputFile> files;
  files.push_back(fileBuilder(path, "policy", checkpoint.state.t,
                              checkpoint.state.t + 2.0, false));
  WVModelOutputConfiguration create;
  auto status = WVModelOutputConfiguration::build(
      record, std::move(files), WVModelOutputPolicy::create,
      checkpoint.state.t, checkpoint.state.t + 2.0, create);
  require(static_cast<bool>(status), status.message);
  WVIntegrationStateLayout layout;
  status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, create.descriptor(), layout);
  require(static_cast<bool>(status), status.message);
  WVModelOutputNetCDFSink sink;
  auto persistence = create.openNetCDFSink({checkpoint, false}, layout,
                                           nullptr, sink);
  require(static_cast<bool>(persistence), persistence.message);
  deliverFirstEvent(sink, create.plan(), checkpoint);
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);

  files.clear();
  files.push_back(fileBuilder(path, "policy", checkpoint.state.t,
                              checkpoint.state.t + 3.0, false));
  WVModelOutputConfiguration rejectedAppend;
  status = WVModelOutputConfiguration::build(
      record, std::move(files), WVModelOutputPolicy::append,
      checkpoint.state.t, checkpoint.state.t + 3.0, rejectedAppend);
  require(!status, "append accepted a changed schedule graph");

  files.clear();
  auto wrongProgress = fileBuilder(path, "policy", checkpoint.state.t,
                                   checkpoint.state.t + 2.0, false);
  require(static_cast<bool>(
              wrongProgress.outputGroupWithName("wave-vortex")
                  ->committedOrdinal(1)),
          "explicit append progress setup failed");
  files.push_back(std::move(wrongProgress));
  status = WVModelOutputConfiguration::build(
      record, std::move(files), WVModelOutputPolicy::append,
      checkpoint.state.t, checkpoint.state.t + 2.0, rejectedAppend);
  require(!status, "append accepted mismatched committed progress");

  const auto original = fileBytes(path);
  files.clear();
  files.push_back(fileBuilder(path, "policy", checkpoint.state.t,
                              checkpoint.state.t + 2.0, true));
  WVModelOutputConfiguration failedReplacement;
  status = WVModelOutputConfiguration::build(
      allObserverRecord(checkpoint), std::move(files),
      WVModelOutputPolicy::replace, checkpoint.state.t,
      checkpoint.state.t + 2.0, failedReplacement);
  require(static_cast<bool>(status), status.message);
  WVIntegrationStateLayout allLayout;
  status = WVIntegrationStateLayout::create(
      checkpoint.state.coefficients.shape, failedReplacement.descriptor(),
      allLayout);
  require(static_cast<bool>(status), status.message);
  FailingSampleSource failure;
  persistence = failedReplacement.openNetCDFSink(
      {checkpoint, false}, allLayout, &failure, sink);
  require(!persistence && fileBytes(path) == original,
          "failed replacement changed the original destination");

  files.clear();
  files.push_back(fileBuilder(path, "policy", checkpoint.state.t,
                              checkpoint.state.t + 2.0, false));
  WVModelOutputConfiguration replace;
  status = WVModelOutputConfiguration::build(
      record, std::move(files), WVModelOutputPolicy::replace,
      checkpoint.state.t, checkpoint.state.t + 2.0, replace);
  require(static_cast<bool>(status), status.message);
  persistence = replace.openNetCDFSink({checkpoint, false}, layout, nullptr,
                                       sink);
  require(static_cast<bool>(persistence), persistence.message);
  deliverFirstEvent(sink, replace.plan(), checkpoint);
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);

  files.clear();
  files.push_back(fileBuilder(path, "policy", checkpoint.state.t,
                              checkpoint.state.t + 2.0, false));
  WVModelOutputConfiguration append;
  status = WVModelOutputConfiguration::build(
      record, std::move(files), WVModelOutputPolicy::append,
      checkpoint.state.t, checkpoint.state.t + 2.0, append);
  require(static_cast<bool>(status), status.message);
  require(append.progress().size() == 1 &&
              append.progress().front().committedOrdinal == 0,
          "append progress was not recovered");
  persistence = append.openNetCDFSink({checkpoint, false}, layout, nullptr,
                                      sink);
  require(static_cast<bool>(persistence), persistence.message);
  persistence = sink.close();
  require(static_cast<bool>(persistence), persistence.message);

  files.clear();
  files.push_back(fileBuilder(path, "policy", checkpoint.state.t,
                              checkpoint.state.t + 2.0, false));
  WVModelOutputConfiguration collision;
  status = WVModelOutputConfiguration::build(
      record, std::move(files), WVModelOutputPolicy::create,
      checkpoint.state.t, checkpoint.state.t + 2.0, collision);
  require(!status, "create policy accepted an existing destination");
}

} // namespace

int main() {
  try {
    testStructuralCompilation();
    testValidationAndDeterministicIdentifiers();
    testCreateReplaceAndAppendPolicies();
    std::cout << "WVModelOutputConfiguration tests passed\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "FAIL: " << error.what() << '\n';
    return 1;
  }
}
