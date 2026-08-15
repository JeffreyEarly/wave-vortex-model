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
      testKind, "WVTestFields", "WVTestFields",
      WVObserverStateContract::sampleOnly,
      WVObserverOutputRule::eulerianFields, "fieldNames"};
  require(static_cast<bool>(
              WVObserverFactoryRegistry::registerAdapter(registration)),
          "test observer adapter registration failed");
  require(WVObserverFactoryRegistry::supports(testKind),
          "registered test observer is unsupported");
  require(std::string(WVObserverFactoryRegistry::portableTag(testKind)) ==
              "WVTestFields" &&
              std::string(WVObserverFactoryRegistry::matlabClassName(testKind)) ==
                  "WVTestFields",
          "registered test observer identity was not preserved");
  require(!WVObserverFactoryRegistry::registerAdapter(registration),
          "duplicate observer adapter registration succeeded");

  WVPortableObserverRecord testRecord;
  WVObserverRecord testObserver;
  testObserver.identifier = "test-fields";
  testObserver.name = "test fields";
  testObserver.kind = testKind;
  testObserver.fieldNames = {"u"};
  testRecord.observers.push_back(testObserver);
  WVPortableObserverDescriptor testDescriptor;
  require(static_cast<bool>(
              WVPortableObserverDescriptor::create(testRecord, testDescriptor)),
          "registered test observer descriptor validation failed");
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
