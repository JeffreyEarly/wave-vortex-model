#include "WaveVortexRuntime/WVObserverContracts.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"
#include "WaveVortexRuntime/WVObserverOutputProvider.hpp"
#include "WaveVortexRuntime/WVOutputSchedule.hpp"
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

const WVObservationVariable *
observationVariable(const WVObservationSchema &schema,
                    const std::string &identifier) noexcept {
  const auto found =
      std::find_if(schema.variables.begin(), schema.variables.end(),
                   [&](const auto &value) {
                     return value.identifier == identifier;
                   });
  return found == schema.variables.end() ? nullptr : &*found;
}

bool belongsToBatch(const WVObservationVariable &variable,
                    WVObservationBatchKind kind) noexcept {
  const bool initial =
      variable.layout == WVObservationValueLayout::staticValue ||
      variable.layout == WVObservationValueLayout::initialValue;
  return initial == (kind == WVObservationBatchKind::initial);
}

WVKernelStatus borrowValue(const WVObservationValue &value,
                           WVObservationValue &output) {
  switch (value.scalarType) {
  case WVObservationScalarType::real64:
    output = WVObservationValue::borrowReal(
        value.variableIdentifier, value.extents, value.real64Data());
    break;
  case WVObservationScalarType::complex64:
    output = WVObservationValue::borrowComplex(
        value.variableIdentifier, value.extents, value.complex64Data());
    break;
  case WVObservationScalarType::integer64:
    output = WVObservationValue::borrowInteger(
        value.variableIdentifier, value.extents, value.integer64Data());
    break;
  case WVObservationScalarType::boolean8:
    output = WVObservationValue::borrowBoolean(
        value.variableIdentifier, value.extents, value.boolean8Data());
    break;
  case WVObservationScalarType::text:
    output = WVObservationValue::borrowText(
        value.variableIdentifier, value.extents, value.textData());
    break;
  }
  return WVKernelStatus::ok();
}

WVKernelStatus borrowValue(const std::string &identifier,
                           const WVObserverBorrowedValueView &value,
                           WVObservationValue &output) {
  switch (value.scalarType) {
  case WVObservationScalarType::real64:
    output = WVObservationValue::borrowReal(identifier, value.extents,
                                             value.real64);
    break;
  case WVObservationScalarType::complex64:
    output = WVObservationValue::borrowComplex(identifier, value.extents,
                                                value.complex64);
    break;
  case WVObservationScalarType::integer64:
    output = WVObservationValue::borrowInteger(identifier, value.extents,
                                                value.integer64);
    break;
  case WVObservationScalarType::boolean8:
    output = WVObservationValue::borrowBoolean(identifier, value.extents,
                                                value.boolean8);
    break;
  case WVObservationScalarType::text:
    output = WVObservationValue::borrowText(identifier, value.extents,
                                             value.text);
    break;
  }
  if (output.elementCount() != value.elementCount)
    return invalid("Observer output context returned inconsistent extents.");
  return WVKernelStatus::ok();
}

} // namespace

class WVPortableObserverDescriptor::Impl final {
public:
  std::shared_ptr<const WVExtensionCatalog> catalog;
  WVPortableObserverRecord record;
  std::vector<std::unique_ptr<const WVResolvedObserver>> resolvedObservers;
};

const WVStateBlockRecord *WVObserverOutputPlanningContext::stateBlock(
    const std::string &identifier) const noexcept {
  for (std::size_t index = 0; index < stateBlockCount; ++index)
    if (stateBlocks[index].identifier == identifier)
      return stateBlocks + index;
  return nullptr;
}

WVKernelStatus WVObservingSystem::outputPlan(
    const WVObserverRecord &, const WVObserverOutputPlanningContext &,
    WVObserverOutputPlan &) const {
  return {WVKernelStatusCode::unsupportedOperation,
          "Observer implementation does not declare an output plan."};
}

WVKernelStatus WVObservingSystem::bindIntegration(
    const WVObserverRecord &,
    const WVObserverIntegrationBinder &) const {
  return WVKernelStatus::ok();
}

WVKernelStatus WVObservingSystem::observationBatch(
    const WVObserverRecord &, const WVObserverOutputPlan &plan,
    const WVObserverOutputEvaluationContext &context,
    WVObservationBatchKind kind, WVObservationBatch &output) const {
  WVObservationBatch candidate;
  candidate.schemaIdentifier = plan.schema.identifier;
  candidate.schemaVersion = plan.schema.version;
  candidate.kind = kind;
  for (const auto &constant : plan.constantValues) {
    const auto *variable =
        observationVariable(plan.schema, constant.variableIdentifier);
    if (variable == nullptr || !belongsToBatch(*variable, kind))
      continue;
    WVObservationValue borrowed;
    auto status = borrowValue(constant, borrowed);
    if (!status)
      return status;
    candidate.values.push_back(std::move(borrowed));
  }
  for (const auto &channel : plan.channels) {
    const auto *variable =
        observationVariable(plan.schema, channel.variableIdentifier);
    if (variable == nullptr)
      return invalid("Observer output channel references an unknown schema "
                     "variable.");
    if (!belongsToBatch(*variable, kind))
      continue;
    WVObserverBorrowedValueView value;
    auto status = context.value(channel.variableIdentifier, value);
    if (!status)
      return status;
    if (value.scalarType != variable->scalarType)
      return invalid("Observer output context returned the wrong scalar type.");
    WVObservationValue borrowed;
    status = borrowValue(channel.variableIdentifier, value, borrowed);
    if (!status)
      return status;
    candidate.values.push_back(std::move(borrowed));
  }
  const auto status = validateObservationBatch(plan.schema, candidate);
  if (!status)
    return status;
  output = std::move(candidate);
  return WVKernelStatus::ok();
}

WVKernelStatus WVResolvedObserver::outputPlan(
    const WVObserverRecord &observer,
    const WVObserverOutputPlanningContext &context,
    WVObserverOutputPlan &plan) const {
  return implementation_->outputPlan(observer, context, plan);
}

WVKernelStatus WVResolvedObserver::observationBatch(
    const WVObserverRecord &observer, const WVObserverOutputPlan &plan,
    const WVObserverOutputEvaluationContext &context,
    WVObservationBatchKind kind, WVObservationBatch &batch) const {
  return implementation_->observationBatch(observer, plan, context, kind,
                                             batch);
}

std::size_t observerOutputPlanRetainedBytes(
    const WVObserverOutputPlan &plan) noexcept {
  std::size_t bytes = observationSchemaRetainedBytes(plan.schema) +
                      plan.constantValues.capacity() *
                          sizeof(WVObservationValue) +
                      plan.channels.capacity() *
                          sizeof(WVObserverOutputChannel);
  for (const auto &value : plan.constantValues)
    bytes += value.retainedBytes();
  for (const auto &channel : plan.channels) {
    bytes += channel.variableIdentifier.capacity() +
             channel.sourceIdentifier.capacity() +
             channel.sampling.xIndices.capacity() * sizeof(std::size_t) +
             channel.sampling.yIndices.capacity() * sizeof(std::size_t) +
             (channel.sampling.x.capacity() + channel.sampling.y.capacity() +
              channel.sampling.z.capacity()) *
                 sizeof(double);
  }
  bytes += plan.movingPositions.stateBlockIdentifiers.capacity() *
               sizeof(std::string) +
           plan.movingPositions.fixedZ.capacity() * sizeof(double);
  for (const auto &identifier :
       plan.movingPositions.stateBlockIdentifiers)
    bytes += identifier.capacity();
  return bytes;
}

WVKernelStatus
WVPortableObserverDescriptor::create(const WVPortableObserverRecord &record,
                                     std::shared_ptr<const WVExtensionCatalog> catalog,
                                     WVPortableObserverDescriptor &descriptor) {
  if (!catalog)
    return invalid("Observer descriptor requires an extension catalog.");
  if (record.schemaIdentifier != WVPortableObserverContractIdentifier ||
      record.schemaVersion != WVPortableObserverContractVersion) {
    return invalid("Unsupported portable observing-system contract schema.");
  }
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
    std::map<std::string, WVPortableTypedRecord> observerConfigurations;
    std::map<std::string, WVObserverExecutionPlan> observerExecutionPlans;
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
      WVPortableTypedRecord configuration;
      const auto configurationStatus =
          catalog->observers().resolveConfiguration(observer, configuration);
      if (!configurationStatus)
        return configurationStatus;
      observerConfigurations.emplace(observer.identifier,
                                     std::move(configuration));
      auto configuredObserver = observer;
      configuredObserver.configuration =
          observerConfigurations.at(observer.identifier);
      std::shared_ptr<const WVObservingSystem> implementation;
      const auto constructionStatus = catalog->observers().create(
          configuredObserver, configuredObserver.configuration,
          implementation);
      if (!constructionStatus)
        return constructionStatus;
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
          configuredObserver, blocksByIdentifier, integratedBlockOwnerCounts);
      if (!observerStatus)
        return observerStatus;
      WVObserverExecutionPlan executionPlan;
      const auto planStatus =
          implementation->executionPlan(configuredObserver, executionPlan);
      if (!planStatus)
        return planStatus;
      observerExecutionPlans.emplace(observer.identifier,
                                     std::move(executionPlan));
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
        std::shared_ptr<const WVOutputSchedule> scheduleImplementation;
        auto scheduleStatus = catalog->outputSchedules().resolve(
            group.schedule, scheduleImplementation);
        if (!scheduleStatus)
          return scheduleStatus;
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
          std::set<std::string> restartFamilies;
          for (const auto &identifier : group.observerIdentifiers) {
            const auto &families = observerExecutionPlans.at(identifier)
                                       .coefficientRestartFamilies;
            restartFamilies.insert(families.begin(), families.end());
          }
          if (restartFamilies.find("Ap") == restartFamilies.end() ||
              restartFamilies.find("Am") == restartFamilies.end() ||
              restartFamilies.find("A0") == restartFamilies.end())
            return invalid("A complete coefficient-restart group must contain "
                           "providers for Ap, Am, and A0.");
        }
      }
      if (!file.groups.empty() && restartGroupCount != 1)
        return invalid("Every configured output file must designate exactly "
                       "one complete coefficient-restart group.");
    }
    auto candidate = std::make_shared<Impl>();
    candidate->catalog = std::move(catalog);
    candidate->record = record;
    candidate->resolvedObservers.reserve(record.observers.size());
    for (auto &observer : candidate->record.observers) {
      observer.configuration = observerConfigurations.at(observer.identifier);
      auto resolved = std::make_unique<WVResolvedObserver>();
      resolved->identifier_ = observer.identifier;
      resolved->configuration_ = observer.configuration;
      resolved->executionPlan_ =
          observerExecutionPlans.at(observer.identifier);
      resolved->implementation_ =
          observerImplementations.at(observer.identifier);
      candidate->resolvedObservers.push_back(std::move(resolved));
    }
    descriptor.impl_ = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Portable observing-system descriptor allocation failed."};
  }
}

const WVObservingSystem *WVPortableObserverDescriptor::implementation(
    const WVObserverRecord &observer) const noexcept {
  const auto *resolved = resolvedObserver(observer);
  return resolved == nullptr ? nullptr : &resolved->implementation();
}

const WVResolvedObserver *WVPortableObserverDescriptor::resolvedObserver(
    const WVObserverRecord &observer) const noexcept {
  if (!impl_)
    return nullptr;
  for (std::size_t index = 0; index < impl_->record.observers.size(); ++index)
    if (impl_->record.observers[index].identifier == observer.identifier)
      return impl_->resolvedObservers[index].get();
  return nullptr;
}

const WVPortableObserverRecord &
WVPortableObserverDescriptor::record() const noexcept {
  static const WVPortableObserverRecord empty;
  return impl_ ? impl_->record : empty;
}

const std::vector<WVStateBlockRecord> &
WVPortableObserverDescriptor::stateBlocks() const noexcept {
  return record().stateBlocks;
}

const std::vector<WVObserverRecord> &
WVPortableObserverDescriptor::observers() const noexcept {
  return record().observers;
}

const std::vector<WVOutputFileRecord> &
WVPortableObserverDescriptor::outputFiles() const noexcept {
  return record().outputFiles;
}

const std::shared_ptr<const WVExtensionCatalog> &
WVPortableObserverDescriptor::catalog() const noexcept {
  static const std::shared_ptr<const WVExtensionCatalog> empty;
  return impl_ ? impl_->catalog : empty;
}

std::size_t WVResolvedObserver::persistentBytes() const noexcept {
  std::size_t bytes = sizeof(*this) + identifier_.capacity() +
         configuration_.persistentBytes() - sizeof(WVPortableTypedRecord) +
         implementation_->persistentBytes();
  bytes += executionPlan_.fieldListAttribute.capacity() +
           executionPlan_.persistedName.capacity() +
           executionPlan_.outputFields.capacity() * sizeof(std::string) +
           executionPlan_.coefficientRestartFamilies.capacity() *
               sizeof(std::string);
  for (const auto &value : executionPlan_.outputFields)
    bytes += value.capacity();
  for (const auto &value : executionPlan_.coefficientRestartFamilies)
    bytes += value.capacity();
  return bytes;
}

std::size_t WVPortableObserverDescriptor::persistentBytes() const noexcept {
  if (!impl_)
    return sizeof(*this);
  const auto &record_ = impl_->record;
  const auto &resolvedObservers_ = impl_->resolvedObservers;
  std::size_t bytes =
      sizeof(*this) + sizeof(Impl) + record_.schemaIdentifier.capacity() +
      record_.stateBlocks.capacity() * sizeof(WVStateBlockRecord) +
      record_.observers.capacity() * sizeof(WVObserverRecord) +
      record_.outputFiles.capacity() * sizeof(WVOutputFileRecord);
  for (const auto &block : record_.stateBlocks)
    bytes += stringBytes(block.identifier) +
             block.dimensions.capacity() * sizeof(std::size_t);
  for (const auto &observer : record_.observers) {
    bytes += stringBytes(observer.identifier) + stringBytes(observer.name) +
             stringBytes(observer.typeIdentifier) +
             observer.configuration.persistentBytes() -
                 sizeof(WVPortableTypedRecord) +
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
  bytes += resolvedObservers_.capacity() *
           sizeof(std::unique_ptr<const WVResolvedObserver>);
  for (const auto &observer : resolvedObservers_)
    bytes += observer->persistentBytes();
  for (const auto &file : record_.outputFiles) {
    bytes += stringBytes(file.identifier) + stringBytes(file.destination) +
             file.groups.capacity() * sizeof(WVOutputGroupRecord);
    for (const auto &group : file.groups) {
      bytes += stringBytes(group.identifier) + stringBytes(group.name) +
               stringBytes(group.schedule.typeIdentifier) +
               group.schedule.configuration.persistentBytes() -
                   sizeof(WVPortableTypedRecord) +
               group.observerIdentifiers.capacity() * sizeof(std::string);
      for (const auto &value : group.observerIdentifiers)
        bytes += stringBytes(value);
    }
  }
  return bytes;
}

} // namespace wavevortex::runtime
