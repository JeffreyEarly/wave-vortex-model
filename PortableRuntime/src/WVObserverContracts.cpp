#include "WaveVortexRuntime/WVObserverContracts.hpp"
#include "WVObserverAdapter.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <new>
#include <set>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

bool validIdentifier(const std::string &value) {
  if (value.empty())
    return false;
  return std::all_of(value.begin(), value.end(), [](unsigned char character) {
    return (character >= 'a' && character <= 'z') ||
           (character >= 'A' && character <= 'Z') ||
           (character >= '0' && character <= '9') || character == '-' ||
           character == '_' || character == '.';
  });
}

WVKernelStatus validateDimensions(const WVStateBlockRecord &block) {
  if (block.dimensions.empty())
    return invalid("State block " + block.identifier +
                   " must have at least one dimension.");
  std::size_t count = 1;
  for (const auto dimension : block.dimensions) {
    if (dimension == 0)
      return invalid("State block " + block.identifier +
                     " dimensions must be nonzero.");
    if (count > std::numeric_limits<std::size_t>::max() / dimension)
      return {WVKernelStatusCode::sizeOverflow,
              "State block " + block.identifier +
                  " element count overflows size_t."};
    count *= dimension;
  }
  if (block.toleranceKind == WVToleranceKind::coefficientEnergyScaled) {
    if (block.identifier != "Ap" && block.identifier != "Am" &&
        block.identifier != "A0")
      return invalid("Energy-scaled tolerance is reserved for canonical "
                     "WaveVortex coefficients.");
  } else if (!std::isfinite(block.absoluteTolerance) ||
             block.absoluteTolerance <= 0.0) {
    return invalid(
        "Uniform state-block tolerance must be finite and positive.");
  }
  if (block.ownership == WVStateOwnership::observerDerived &&
      block.restartRequirement == WVRestartRequirement::requiredDynamicState)
    return invalid("Observer-derived state cannot be marked as required "
                   "dynamic restart state.");
  return WVKernelStatus::ok();
}

std::size_t stringBytes(const std::string &value) noexcept {
  return value.capacity();
}

} // namespace

WVKernelStatus
WVPortableObserverDescriptor::create(const WVPortableObserverRecord &record,
                                     WVPortableObserverDescriptor &descriptor) {
  if (record.schemaIdentifier != WVPortableObserverContractIdentifier ||
      record.schemaVersion != WVPortableObserverContractVersion) {
    return invalid("Unsupported portable observing-system contract schema.");
  }
  detail::sealObserverDefinitions();
  try {
    std::set<std::string> blockIdentifiers;
    std::map<std::string, const WVStateBlockRecord *> blocksByIdentifier;
    for (const auto &block : record.stateBlocks) {
      if (!validIdentifier(block.identifier))
        return invalid("State-block identifier is empty or contains "
                       "unsupported characters.");
      if (!blockIdentifiers.insert(block.identifier).second)
        return invalid("Duplicate state-block identifier: " + block.identifier);
      blocksByIdentifier.emplace(block.identifier, &block);
      const auto status = validateDimensions(block);
      if (!status)
        return status;
    }

    std::set<std::string> observerIdentifiers;
    std::map<std::string, std::shared_ptr<const WVObservingSystem>>
        observerImplementations;
    std::map<std::string, std::size_t> integratedBlockOwnerCounts;
    for (const auto &block : record.stateBlocks) {
      const bool canonical = block.identifier == "Ap" ||
                             block.identifier == "Am" ||
                             block.identifier == "A0";
      if (!canonical && block.ownership == WVStateOwnership::integratorOwned)
        integratedBlockOwnerCounts.emplace(block.identifier, 0);
    }
    for (const auto &observer : record.observers) {
      if (!validIdentifier(observer.identifier) || observer.name.empty())
        return invalid("Observer identifier and name must be nonempty.");
      if (!observerIdentifiers.insert(observer.identifier).second)
        return invalid("Duplicate observer identifier: " + observer.identifier);
      const auto implementation = detail::observerImplementation(
          observer.typeIdentifier, observer.contractVersion);
      if (!implementation)
        return {WVKernelStatusCode::unsupportedOperation,
                "Unsupported observing-system identity or contract version."};
      observerImplementations.emplace(observer.identifier, implementation);
      std::set<std::string> observerBlocks;
      for (const auto &identifier : observer.stateBlockIdentifiers) {
        if (blockIdentifiers.find(identifier) == blockIdentifiers.end())
          return invalid("Observer " + observer.identifier +
                         " references unknown state block " + identifier + ".");
        if (!observerBlocks.insert(identifier).second)
          return invalid("Observer " + observer.identifier +
                         " repeats state block " + identifier + ".");
      }
      const auto observerStatus = implementation->validate(
          observer, blocksByIdentifier, integratedBlockOwnerCounts);
      if (!observerStatus)
        return observerStatus;
    }

    for (const auto &[identifier, ownerCount] : integratedBlockOwnerCounts) {
      if (ownerCount == 0)
        return invalid("Integrator-owned state block " + identifier +
                       " is not owned by an integrated observer.");
      if (ownerCount != 1)
        return invalid("Integrator-owned state block " + identifier +
                       " is owned by more than one integrated observer.");
    }

    std::set<std::string> fileIdentifiers;
    std::set<std::string> destinations;
    for (const auto &file : record.outputFiles) {
      if (!validIdentifier(file.identifier) || file.destination.empty())
        return invalid(
            "Output-file identifier and destination must be nonempty.");
      if (!fileIdentifiers.insert(file.identifier).second)
        return invalid("Duplicate output-file identifier: " + file.identifier);
      if (!destinations.insert(file.destination).second)
        return invalid("Duplicate output-file destination: " +
                       file.destination);
      std::set<std::string> groupIdentifiers;
      std::set<std::string> groupNames;
      std::size_t restartGroupCount = 0;
      for (const auto &group : file.groups) {
        if (!validIdentifier(group.identifier) || group.name.empty())
          return invalid("Output-group identifier and name must be nonempty.");
        if (!groupIdentifiers.insert(group.identifier).second ||
            !groupNames.insert(group.name).second)
          return invalid("Duplicate output-group identifier or name in " +
                         file.identifier + ".");
        if (!std::isfinite(group.schedule.outputInterval) ||
            group.schedule.outputInterval <= 0.0 ||
            std::isnan(group.schedule.initialTime) ||
            std::isnan(group.schedule.finalTime) ||
            group.schedule.finalTime < group.schedule.initialTime)
          return invalid("Output-group schedule is invalid.");
        std::set<std::string> groupObservers;
        for (const auto &identifier : group.observerIdentifiers) {
          if (observerIdentifiers.find(identifier) == observerIdentifiers.end())
            return invalid("Output group " + group.identifier +
                           " references unknown observer " + identifier + ".");
          if (!groupObservers.insert(identifier).second)
            return invalid("Output group " + group.identifier +
                           " repeats observer " + identifier + ".");
        }
        if (group.containsCompleteCoefficientRestart) {
          ++restartGroupCount;
          const bool containsCoefficients = std::any_of(
              group.observerIdentifiers.begin(),
              group.observerIdentifiers.end(), [&](const auto &identifier) {
                return observerImplementations.at(identifier)
                    ->recordsCoefficients();
              });
          const bool containsEulerianCoefficients = std::any_of(
              group.observerIdentifiers.begin(),
              group.observerIdentifiers.end(), [&](const auto &identifier) {
                if (!observerImplementations.at(identifier)
                         ->recordsEulerianFields())
                  return false;
                const auto observer = std::find_if(
                    record.observers.begin(), record.observers.end(),
                    [&](const auto &candidate) {
                      return candidate.identifier == identifier;
                    });
                if (observer == record.observers.end())
                  return false;
                return std::find(observer->fieldNames.begin(),
                                 observer->fieldNames.end(), "Ap") !=
                           observer->fieldNames.end() &&
                       std::find(observer->fieldNames.begin(),
                                 observer->fieldNames.end(), "Am") !=
                           observer->fieldNames.end() &&
                       std::find(observer->fieldNames.begin(),
                                 observer->fieldNames.end(), "A0") !=
                           observer->fieldNames.end();
              });
          if (!containsCoefficients && !containsEulerianCoefficients)
            return invalid("A complete coefficient-restart group must contain "
                           "WVCoefficients or Eulerian Ap, Am, and A0.");
        }
      }
      if (!file.groups.empty() && restartGroupCount != 1)
        return invalid("Every configured output file must designate exactly "
                       "one complete coefficient-restart group.");
    }
    descriptor.record_ = record;
    descriptor.implementations_.clear();
    descriptor.implementations_.reserve(record.observers.size());
    for (const auto &observer : record.observers)
      descriptor.implementations_.push_back(
          observerImplementations.at(observer.identifier));
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Portable observing-system descriptor allocation failed."};
  }
}

bool WVObserverFactoryRegistry::supports(
    const std::string &typeIdentifier,
    std::uint32_t contractVersion) noexcept {
  return static_cast<bool>(
      detail::observerImplementation(typeIdentifier, contractVersion));
}

WVPortableCapability WVObserverFactoryRegistry::capability(
    std::string typeIdentifier, std::uint32_t contractVersion) {
  const auto implementation = detail::observerImplementation(
      typeIdentifier, contractVersion);
  std::optional<WVPortableImplementationIdentity> available;
  if (implementation)
    available = WVPortableImplementationIdentity{
        implementation->typeIdentifier(), implementation->contractVersion()};
  else
    for (const auto &candidate : detail::observerImplementations())
      if (candidate->typeIdentifier() == typeIdentifier) {
        available = WVPortableImplementationIdentity{
            candidate->typeIdentifier(), candidate->contractVersion()};
        break;
      }
  return evaluatePortableCapability(
      {std::move(typeIdentifier), contractVersion}, std::move(available));
}

bool WVObserverFactoryRegistry::isSealed() noexcept {
  return detail::observerDefinitionsSealed();
}

WVKernelStatus WVObserverFactoryRegistry::registerImplementation(
    std::shared_ptr<const WVObservingSystem> implementation) {
  return detail::registerObserverImplementation(std::move(implementation));
}

const WVObservingSystem *WVPortableObserverDescriptor::implementation(
    const WVObserverRecord &observer) const noexcept {
  for (std::size_t index = 0; index < record_.observers.size(); ++index)
    if (record_.observers[index].identifier == observer.identifier)
      return implementations_[index].get();
  return nullptr;
}

std::size_t WVPortableObserverDescriptor::persistentBytes() const noexcept {
  std::size_t bytes =
      record_.schemaIdentifier.capacity() +
      record_.stateBlocks.capacity() * sizeof(WVStateBlockRecord) +
      record_.observers.capacity() * sizeof(WVObserverRecord) +
      record_.outputFiles.capacity() * sizeof(WVOutputFileRecord);
  for (const auto &block : record_.stateBlocks)
    bytes += stringBytes(block.identifier) +
             block.dimensions.capacity() * sizeof(std::size_t);
  for (const auto &observer : record_.observers) {
    bytes += stringBytes(observer.identifier) + stringBytes(observer.name) +
             stringBytes(observer.typeIdentifier) +
             observer.stateBlockIdentifiers.capacity() * sizeof(std::string) +
             observer.fieldNames.capacity() * sizeof(std::string);
    for (const auto &value : observer.stateBlockIdentifiers)
      bytes += stringBytes(value);
    for (const auto &value : observer.fieldNames)
      bytes += stringBytes(value);
    bytes += (observer.x.capacity() + observer.y.capacity() +
              observer.z.capacity()) *
             sizeof(double);
  }
  bytes += implementations_.capacity() *
           sizeof(std::shared_ptr<const WVObservingSystem>);
  for (const auto &file : record_.outputFiles) {
    bytes += stringBytes(file.identifier) + stringBytes(file.destination) +
             file.groups.capacity() * sizeof(WVOutputGroupRecord);
    for (const auto &group : file.groups) {
      bytes += stringBytes(group.identifier) + stringBytes(group.name) +
               group.observerIdentifiers.capacity() * sizeof(std::string);
      for (const auto &value : group.observerIdentifiers)
        bytes += stringBytes(value);
    }
  }
  return bytes;
}

} // namespace wavevortex::runtime
