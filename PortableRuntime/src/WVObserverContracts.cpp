#include "WaveVortexRuntime/WVObserverContracts.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
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

bool supportedObserver(WVObserverKind kind) noexcept {
  return kind == WVObserverKind::coefficients ||
         kind == WVObserverKind::eulerianFields ||
         kind == WVObserverKind::mooring ||
         kind == WVObserverKind::lagrangianParticles ||
         kind == WVObserverKind::tracer;
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
  try {
    std::set<std::string> blockIdentifiers;
    for (const auto &block : record.stateBlocks) {
      if (!validIdentifier(block.identifier))
        return invalid("State-block identifier is empty or contains "
                       "unsupported characters.");
      if (!blockIdentifiers.insert(block.identifier).second)
        return invalid("Duplicate state-block identifier: " + block.identifier);
      const auto status = validateDimensions(block);
      if (!status)
        return status;
    }

    std::set<std::string> observerIdentifiers;
    for (const auto &observer : record.observers) {
      if (!validIdentifier(observer.identifier) || observer.name.empty())
        return invalid("Observer identifier and name must be nonempty.");
      if (!observerIdentifiers.insert(observer.identifier).second)
        return invalid("Duplicate observer identifier: " + observer.identifier);
      if (!WVObserverFactoryRegistry::supports(observer.kind))
        return {WVKernelStatusCode::unsupportedOperation,
                "Unsupported observing-system tag."};
      std::set<std::string> observerBlocks;
      for (const auto &identifier : observer.stateBlockIdentifiers) {
        if (blockIdentifiers.find(identifier) == blockIdentifiers.end())
          return invalid("Observer " + observer.identifier +
                         " references unknown state block " + identifier + ".");
        if (!observerBlocks.insert(identifier).second)
          return invalid("Observer " + observer.identifier +
                         " repeats state block " + identifier + ".");
      }
      if (observer.kind == WVObserverKind::coefficients &&
          observer.stateBlockIdentifiers !=
              std::vector<std::string>({"Ap", "Am", "A0"}))
        return invalid(
            "WVCoefficients must reference Ap, Am, and A0 in canonical order.");
      if (observer.kind == WVObserverKind::mooring &&
          (observer.x.empty() || observer.x.size() != observer.y.size()))
        return invalid(
            "WVMooring requires equal nonempty x and y coordinates.");
      if (observer.kind == WVObserverKind::lagrangianParticles) {
        if (observer.x.empty() || observer.x.size() != observer.y.size())
          return invalid("WVLagrangianParticles requires equal nonempty x and "
                         "y coordinates.");
        if (!observer.isXYOnly && observer.z.size() != observer.x.size())
          return invalid("Three-dimensional particles require one z coordinate "
                         "per particle.");
        if (!(observer.horizontalAbsoluteTolerance > 0.0) ||
            !std::isfinite(observer.horizontalAbsoluteTolerance))
          return invalid(
              "Particle horizontal tolerance must be finite and positive.");
        if (!observer.isXYOnly &&
            (!(observer.verticalAbsoluteTolerance > 0.0) ||
             !std::isfinite(observer.verticalAbsoluteTolerance)))
          return invalid(
              "Particle vertical tolerance must be finite and positive.");
      }
      if (observer.kind == WVObserverKind::tracer &&
          observer.stateBlockIdentifiers.size() != 1)
        return invalid("WVTracer requires exactly one state block.");
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
        if (group.containsCompleteCoefficientRestart)
          ++restartGroupCount;
      }
      if (!file.groups.empty() && restartGroupCount != 1)
        return invalid("Every configured output file must designate exactly "
                       "one complete coefficient-restart group.");
    }
    descriptor.record_ = record;
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Portable observing-system descriptor allocation failed."};
  }
}

bool WVObserverFactoryRegistry::supports(WVObserverKind kind) noexcept {
  return supportedObserver(kind);
}

const char *
WVObserverFactoryRegistry::portableTag(WVObserverKind kind) noexcept {
  switch (kind) {
  case WVObserverKind::coefficients:
    return "WVCoefficients";
  case WVObserverKind::eulerianFields:
    return "WVEulerianFields";
  case WVObserverKind::mooring:
    return "WVMooring";
  case WVObserverKind::lagrangianParticles:
    return "WVLagrangianParticles";
  case WVObserverKind::tracer:
    return "WVTracer";
  }
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
