#include "WVObserverAdapter.hpp"

#include <cmath>
#include <mutex>
#include <utility>

namespace wavevortex::runtime::detail {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

class BuiltInObservingSystem : public WVObservingSystem {
public:
  BuiltInObservingSystem(std::string typeIdentifier,
                         std::string fieldListAttribute = {})
      : typeIdentifier_(std::move(typeIdentifier)),
        fieldListAttribute_(std::move(fieldListAttribute)) {}

  const std::string &typeIdentifier() const noexcept override {
    return typeIdentifier_;
  }
  std::uint32_t contractVersion() const noexcept override {
    return WVPortablePairContractVersion;
  }
  const std::string &fieldListAttribute() const noexcept override {
    return fieldListAttribute_;
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this) + typeIdentifier_.capacity() +
           fieldListAttribute_.capacity();
  }

protected:
  static WVKernelStatus validateSampleOnly(
      const WVObserverRecord &observer) {
    return observer.stateBlockIdentifiers.empty()
               ? WVKernelStatus::ok()
               : invalid("Sample-only observers cannot own integrated state blocks.");
  }

private:
  std::string typeIdentifier_;
  std::string fieldListAttribute_;
};

class WVCoefficientsImplementation final : public BuiltInObservingSystem {
public:
  WVCoefficientsImplementation() : BuiltInObservingSystem("WVCoefficients") {}
  bool recordsCoefficients() const noexcept override { return true; }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    if (observer.stateBlockIdentifiers !=
        std::vector<std::string>({"Ap", "Am", "A0"}))
      return invalid(
          "WVCoefficients must reference Ap, Am, and A0 in canonical order.");
    return WVKernelStatus::ok();
  }
};

class WVEulerianFieldsImplementation final : public BuiltInObservingSystem {
public:
  WVEulerianFieldsImplementation()
      : BuiltInObservingSystem("WVEulerianFields", "fieldNames") {}
  bool recordsEulerianFields() const noexcept override { return true; }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    return validateSampleOnly(observer);
  }
};

class WVMooringImplementation final : public BuiltInObservingSystem {
public:
  WVMooringImplementation()
      : BuiltInObservingSystem("WVMooring", "trackedFieldNames") {}
  bool recordsFixedProfiles() const noexcept override { return true; }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    const auto status = validateSampleOnly(observer);
    if (!status)
      return status;
    if (observer.x.empty() || observer.x.size() != observer.y.size())
      return invalid("WVMooring requires equal nonempty x and y coordinates.");
    return WVKernelStatus::ok();
  }
};

class WVLagrangianParticlesImplementation final
    : public BuiltInObservingSystem {
public:
  WVLagrangianParticlesImplementation()
      : BuiltInObservingSystem("WVLagrangianParticles", "trackedFieldNames") {}
  bool recordsMovingParticles() const noexcept override { return true; }
  bool contributesRightHandSide() const noexcept override { return true; }
  bool ownsParticleState() const noexcept override { return true; }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &blocks,
      std::map<std::string, std::size_t> &ownerCounts) const override {
    if (observer.x.empty() || observer.x.size() != observer.y.size())
      return invalid(
          "WVLagrangianParticles requires equal nonempty x and y coordinates.");
    if (!observer.isXYOnly && observer.z.size() != observer.x.size())
      return invalid(
          "Three-dimensional particles require one z coordinate per particle.");
    if (!(observer.horizontalAbsoluteTolerance > 0.0) ||
        !std::isfinite(observer.horizontalAbsoluteTolerance))
      return invalid(
          "Particle horizontal tolerance must be finite and positive.");
    if (!observer.isXYOnly &&
        (!(observer.verticalAbsoluteTolerance > 0.0) ||
         !std::isfinite(observer.verticalAbsoluteTolerance)))
      return invalid("Particle vertical tolerance must be finite and positive.");
    const auto channels = movingFieldChannels(observer);
    if (observer.stateBlockIdentifiers.size() != channels.size())
      return invalid("WVLagrangianParticles requires ordered x, y, and "
                     "optional z state blocks.");
    for (const auto &identifier : observer.stateBlockIdentifiers) {
      const auto found = blocks.find(identifier);
      if (found == blocks.end())
        return invalid("Particle observer references an unknown state block.");
      const auto *block = found->second;
      if (block->scalarType != WVStateScalarType::real64 ||
          block->ownership != WVStateOwnership::integratorOwned ||
          block->dimensions !=
              std::vector<std::size_t>({observer.x.size()}))
        return invalid("Particle state blocks must be integrator-owned real "
                       "vectors matching the particle count.");
      ++ownerCounts.at(identifier);
    }
    return WVKernelStatus::ok();
  }
};

class WVTracerImplementation final : public BuiltInObservingSystem {
public:
  WVTracerImplementation() : BuiltInObservingSystem("WVTracer") {}
  bool recordsTracerState() const noexcept override { return true; }
  bool contributesRightHandSide() const noexcept override { return true; }
  bool ownsTracerState() const noexcept override { return true; }
  WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &blocks,
      std::map<std::string, std::size_t> &ownerCounts) const override {
    if (observer.stateBlockIdentifiers.size() != 1)
      return invalid("WVTracer requires exactly one state block.");
    const auto found = blocks.find(observer.stateBlockIdentifiers.front());
    if (found == blocks.end())
      return invalid("WVTracer references an unknown state block.");
    const auto *block = found->second;
    if (block->scalarType != WVStateScalarType::real64 ||
        block->ownership != WVStateOwnership::integratorOwned)
      return invalid("WVTracer requires one integrator-owned real state block.");
    const std::size_t expectedRank = observer.isXYOnly ? 2 : 3;
    if (block->dimensions.size() != expectedRank)
      return invalid(observer.isXYOnly
                         ? "A two-dimensional WVTracer requires a rank-two state block."
                         : "A three-dimensional WVTracer requires a rank-three state block.");
    ++ownerCounts.at(observer.stateBlockIdentifiers.front());
    return WVKernelStatus::ok();
  }
};

std::deque<std::shared_ptr<const WVObservingSystem>> &mutableImplementations() {
  static std::deque<std::shared_ptr<const WVObservingSystem>> implementations{
      std::make_shared<WVCoefficientsImplementation>(),
      std::make_shared<WVEulerianFieldsImplementation>(),
      std::make_shared<WVMooringImplementation>(),
      std::make_shared<WVLagrangianParticlesImplementation>(),
      std::make_shared<WVTracerImplementation>()};
  return implementations;
}

std::mutex &registryMutex() {
  static std::mutex value;
  return value;
}

bool &registrySealed() {
  static bool value = false;
  return value;
}

} // namespace

const std::deque<std::shared_ptr<const WVObservingSystem>> &
observerImplementations() noexcept {
  return mutableImplementations();
}

std::shared_ptr<const WVObservingSystem>
observerImplementation(const std::string &typeIdentifier,
                       std::uint32_t contractVersion) noexcept {
  for (const auto &implementation : mutableImplementations())
    if (implementation->typeIdentifier() == typeIdentifier &&
        implementation->contractVersion() == contractVersion)
      return implementation;
  return {};
}

WVKernelStatus registerObserverImplementation(
    std::shared_ptr<const WVObservingSystem> implementation) {
  if (!implementation || implementation->typeIdentifier().empty())
    return invalid("Observer implementation identity must be nonempty.");
  if (implementation->contractVersion() == 0)
    return invalid("Observer implementation contract versions must be positive.");
  std::lock_guard<std::mutex> lock(registryMutex());
  if (registrySealed())
    return invalid(
        "Observer implementations must be registered before descriptor construction.");
  for (const auto &existing : mutableImplementations())
    if (existing->typeIdentifier() == implementation->typeIdentifier())
      return invalid("Observer implementation identities must be unique.");
  mutableImplementations().push_back(std::move(implementation));
  return WVKernelStatus::ok();
}

void sealObserverDefinitions() noexcept {
  std::lock_guard<std::mutex> lock(registryMutex());
  registrySealed() = true;
}

bool observerDefinitionsSealed() noexcept {
  std::lock_guard<std::mutex> lock(registryMutex());
  return registrySealed();
}

const char *movingFieldChannelName(WVMovingFieldChannel channel) noexcept {
  switch (channel) {
  case WVMovingFieldChannel::x:
    return "x";
  case WVMovingFieldChannel::y:
    return "y";
  case WVMovingFieldChannel::z:
    return "z";
  case WVMovingFieldChannel::tracerValue:
    return "value";
  }
  return nullptr;
}

std::vector<WVMovingFieldChannel>
movingFieldChannels(const WVObserverRecord &observer) {
  const auto implementation = observerImplementation(
      observer.typeIdentifier, observer.contractVersion);
  if (!implementation)
    return {};
  if (implementation->ownsParticleState())
    return observer.isXYOnly
               ? std::vector<WVMovingFieldChannel>{WVMovingFieldChannel::x,
                                                   WVMovingFieldChannel::y}
               : std::vector<WVMovingFieldChannel>{WVMovingFieldChannel::x,
                                                   WVMovingFieldChannel::y,
                                                   WVMovingFieldChannel::z};
  if (implementation->ownsTracerState())
    return {WVMovingFieldChannel::tracerValue};
  return {};
}

std::string movingFieldVariableName(const WVObserverRecord &observer,
                                    WVMovingFieldChannel channel) {
  if (channel == WVMovingFieldChannel::tracerValue)
    return observer.name;
  return observer.name + '_' + movingFieldChannelName(channel);
}

} // namespace wavevortex::runtime::detail
