#include "WVObserverAdapter.hpp"

#include <cstdlib>
#include <iostream>
#include <set>
#include <string>

using namespace wavevortex::runtime;
using wavevortex::WVKernelStatus;
using wavevortex::WVKernelStatusCode;

namespace {

void require(bool condition, const char *message) {
  if (!condition) {
    std::cerr << message << '\n';
    std::exit(1);
  }
}

class WVTestPortablePointDiagnostic final : public WVObservingSystem {
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
  WVKernelStatus validate(
      const WVObserverRecord &record,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    if (!record.stateBlockIdentifiers.empty() || record.fieldNames.size() != 1 ||
        record.x.empty() || record.x.size() != record.y.size() ||
        record.x.size() != record.z.size())
      return {WVKernelStatusCode::invalidConfiguration,
              "Point diagnostic requires one field and equal fixed x/y/z points."};
    return WVKernelStatus::ok();
  }
  bool recordsFixedPoints() const noexcept override { return true; }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }
};

class WVTestPortablePointDiagnosticV2 final : public WVObservingSystem {
public:
  const std::string &typeIdentifier() const noexcept override {
    static const std::string value = "WVTestPortablePointDiagnostic";
    return value;
  }
  std::uint32_t contractVersion() const noexcept override { return 2; }
  const std::string &fieldListAttribute() const noexcept override {
    static const std::string value = "fieldNames";
    return value;
  }
  WVKernelStatus validate(
      const WVObserverRecord &,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    return WVKernelStatus::ok();
  }
  bool recordsFixedPoints() const noexcept override { return true; }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }
};

} // namespace

int main() {
  const auto &implementations = detail::observerImplementations();
  require(implementations.size() == 5,
          "registry must contain five v1 built-ins");
  std::set<std::string> identities;
  for (const auto &implementation : implementations) {
    require(identities.insert(implementation->typeIdentifier()).second,
            "observer identity is duplicated");
    require(implementation->contractVersion() ==
                WVPortablePairContractVersion,
            "observer pair contract version changed");
    require(detail::observerImplementation(implementation->typeIdentifier(),
                                           implementation->contractVersion()) ==
                implementation,
            "identity lookup did not preserve implementation identity");
    require(WVObserverFactoryRegistry::supports(
                implementation->typeIdentifier(),
                implementation->contractVersion()),
            "public registry rejected a built-in implementation");
  }

  auto testImplementation =
      std::make_shared<WVTestPortablePointDiagnostic>();
  require(static_cast<bool>(
              WVObserverFactoryRegistry::registerImplementation(
                  testImplementation)),
          "test observer implementation registration failed");
  require(WVObserverFactoryRegistry::supports(
              "WVTestPortablePointDiagnostic", 1),
          "registered test observer is unsupported");
  require(!WVObserverFactoryRegistry::registerImplementation(
              testImplementation),
          "duplicate observer implementation registration succeeded");
  auto testImplementationV2 =
      std::make_shared<WVTestPortablePointDiagnosticV2>();
  require(static_cast<bool>(WVObserverFactoryRegistry::registerImplementation(
              testImplementationV2)),
          "a second contract version could not be registered");
  require(WVObserverFactoryRegistry::capability(
              "WVTestPortablePointDiagnostic", 1)
              .isSupported(),
          "registered observer pair is unavailable");
  require(WVObserverFactoryRegistry::capability(
              "WVTestPortablePointDiagnostic", 2)
              .isSupported(),
          "the second observer contract version is unavailable");
  require(WVObserverFactoryRegistry::capability(
              "WVTestPortablePointDiagnostic", 3)
              .status == WVPortableCapabilityStatus::versionMismatch,
          "an unavailable observer contract version was accepted");
  require(WVObserverFactoryRegistry::capability("WVCustomObserver", 1).status ==
              WVPortableCapabilityStatus::unavailable,
          "missing observer pair did not report unavailability");

  WVPortableObserverRecord record;
  WVObserverRecord observer;
  observer.identifier = "test-point-diagnostic";
  observer.name = "test point diagnostic";
  observer.typeIdentifier = "WVTestPortablePointDiagnostic";
  observer.fieldNames = {"u"};
  observer.x = {0.1, 0.2};
  observer.y = {0.3, 0.4};
  observer.z = {-0.5, -0.6};
  record.observers.push_back(observer);
  WVPortableObserverDescriptor descriptor;
  const auto descriptorStatus =
      WVPortableObserverDescriptor::create(record, descriptor);
  require(static_cast<bool>(descriptorStatus),
          descriptorStatus.message.c_str());
  require(descriptor.implementation(descriptor.observers().front()) ==
              testImplementation.get(),
          "descriptor did not retain the resolved implementation");
  require(WVObserverFactoryRegistry::isSealed(),
          "observer registry was not sealed by descriptor construction");
  require(!WVObserverFactoryRegistry::registerImplementation(
              std::make_shared<WVTestPortablePointDiagnostic>()),
          "late observer implementation registration succeeded");
  require(!detail::observerImplementation("WVCustomObserver", 1),
          "unknown observer identity was accepted");

  WVObserverRecord particles;
  particles.name = "floats";
  particles.typeIdentifier = "WVLagrangianParticles";
  particles.isXYOnly = false;
  auto channels = detail::movingFieldChannels(particles);
  require(channels ==
              std::vector<detail::WVMovingFieldChannel>{
                  detail::WVMovingFieldChannel::x,
                  detail::WVMovingFieldChannel::y,
                  detail::WVMovingFieldChannel::z},
          "three-dimensional particle channels are not x/y/z");
  particles.isXYOnly = true;
  require(detail::movingFieldChannels(particles).size() == 2,
          "two-dimensional particles must expose x/y channels only");

  WVObserverRecord tracer;
  tracer.name = "dye";
  tracer.typeIdentifier = "WVTracer";
  channels = detail::movingFieldChannels(tracer);
  require(channels == std::vector<detail::WVMovingFieldChannel>{
                          detail::WVMovingFieldChannel::tracerValue},
          "tracer must expose one named value channel");
  require(detail::movingFieldVariableName(tracer, channels.front()) == "dye",
          "tracer variable name changed");
  return 0;
}
