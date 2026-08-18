#include "WVObserverAdapter.hpp"

#include <cstdlib>
#include <iostream>
#include <set>
#include <string>

using namespace wavevortex::runtime;

namespace {

void require(bool condition, const char *message) {
  if (!condition) {
    std::cerr << message << '\n';
    std::exit(1);
  }
}

} // namespace

int main() {
  const auto &definitions = detail::observerDefinitions();
  require(definitions.size() == 5, "registry must contain five v1 built-ins");
  std::set<WVObserverKind> kinds;
  std::set<std::string> tags;
  std::set<std::string> classes;
  for (const auto &definition : definitions) {
    require(kinds.insert(definition.kind).second, "observer kind is duplicated");
    require(!definition.portableTag.empty(),
            "portable tag is absent");
    require(!definition.matlabClassName.empty(),
            "MATLAB class name is absent");
    require(definition.contractVersion == WVPortablePairContractVersion,
            "observer pair contract version changed");
    require(tags.insert(definition.portableTag).second,
            "portable tag is duplicated");
    require(classes.insert(definition.matlabClassName).second,
            "MATLAB class name is duplicated");
    require(detail::observerDefinition(definition.kind) == &definition,
            "kind lookup did not preserve definition identity");
    require(detail::observerDefinitionForMatlabClass(
                definition.matlabClassName) == &definition,
            "MATLAB-class lookup did not preserve definition identity");
    require(WVObserverFactoryRegistry::supports(definition.kind),
            "public registry rejected a built-in definition");
    require(std::string(WVObserverFactoryRegistry::portableTag(
                definition.kind)) == definition.portableTag,
            "public registry tag differs from the adapter definition");
  }

  constexpr auto testKind = static_cast<WVObserverKind>(200);
  auto registration = WVObserverFactoryRegistry::Registration{
      testKind, "WVTestPortableTracer", "WVTestPortableTracer",
      WVPortablePairContractVersion,
      WVObserverStateContract::tracerField,
      WVObserverOutputRule::tracer, ""};
  require(static_cast<bool>(
              WVObserverFactoryRegistry::registerAdapter(registration)),
          "test observer adapter registration failed");
  require(WVObserverFactoryRegistry::supports(testKind),
          "registered test observer is unsupported");
  require(std::string(WVObserverFactoryRegistry::portableTag(testKind)) ==
              "WVTestPortableTracer" &&
              std::string(WVObserverFactoryRegistry::matlabClassName(testKind)) ==
                  "WVTestPortableTracer",
          "registered test observer identity was not preserved");
  require(!WVObserverFactoryRegistry::registerAdapter(registration),
          "duplicate observer adapter registration succeeded");
  require(WVObserverFactoryRegistry::capability(
              "WVTestPortableTracer", WVPortablePairContractVersion)
              .isSupported(),
          "registered observer pair is unavailable");
  require(WVObserverFactoryRegistry::capability("WVTestPortableTracer", 2).status ==
              WVPortableCapabilityStatus::versionMismatch,
          "observer contract mismatch was accepted");
  require(WVObserverFactoryRegistry::capability("WVCustomObserver", 1).status ==
              WVPortableCapabilityStatus::unavailable,
          "missing observer pair did not report unavailability");

  WVPortableObserverRecord testRecord;
  WVStateBlockRecord testBlock;
  testBlock.identifier = "test-tracer-state";
  testBlock.dimensions = {2, 2, 2};
  testBlock.absoluteTolerance = 1e-6;
  testRecord.stateBlocks.push_back(testBlock);
  WVObserverRecord testObserver;
  testObserver.identifier = "test-portable-tracer";
  testObserver.name = "test portable tracer";
  testObserver.kind = testKind;
  testObserver.stateBlockIdentifiers = {testBlock.identifier};
  testRecord.observers.push_back(testObserver);
  WVPortableObserverDescriptor testDescriptor;
  const auto descriptorStatus =
      WVPortableObserverDescriptor::create(testRecord, testDescriptor);
  require(static_cast<bool>(descriptorStatus), descriptorStatus.message.c_str());
  require(WVObserverFactoryRegistry::isSealed(),
          "observer registry was not sealed by descriptor construction");
  auto lateRegistration = registration;
  lateRegistration.kind = static_cast<WVObserverKind>(201);
  lateRegistration.portableTag = "WVLateObserver";
  lateRegistration.matlabClassName = "WVLateObserver";
  require(!WVObserverFactoryRegistry::registerAdapter(lateRegistration),
          "late observer registration succeeded");
  require(detail::observerDefinition(static_cast<WVObserverKind>(255)) ==
              nullptr,
          "unknown observer kind was accepted");
  require(detail::observerDefinitionForMatlabClass("WVCustomObserver") ==
              nullptr,
          "custom observer class was accepted");

  WVObserverRecord particles;
  particles.name = "floats";
  particles.kind = WVObserverKind::lagrangianParticles;
  particles.isXYOnly = false;
  auto channels = detail::movingFieldChannels(particles);
  require(channels ==
              std::vector<detail::WVMovingFieldChannel>{
                  detail::WVMovingFieldChannel::x,
                  detail::WVMovingFieldChannel::y,
                  detail::WVMovingFieldChannel::z},
          "three-dimensional particle channels are not x/y/z");
  require(detail::movingFieldVariableName(particles, channels[0]) ==
              "floats_x" &&
              detail::movingFieldVariableName(particles, channels[1]) ==
                  "floats_y" &&
              detail::movingFieldVariableName(particles, channels[2]) ==
                  "floats_z",
          "particle variable names changed");
  particles.isXYOnly = true;
  channels = detail::movingFieldChannels(particles);
  require(channels.size() == 2,
          "two-dimensional particles must expose x/y channels only");

  WVObserverRecord tracer;
  tracer.name = "dye";
  tracer.kind = WVObserverKind::tracer;
  channels = detail::movingFieldChannels(tracer);
  require(channels == std::vector<detail::WVMovingFieldChannel>{
                          detail::WVMovingFieldChannel::tracerValue},
          "tracer must expose one named value channel");
  require(detail::movingFieldVariableName(tracer, channels.front()) == "dye",
          "tracer variable name changed");

  return 0;
}
