#include "WaveVortexRuntime/WVModelOutputConfiguration.hpp"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <iomanip>
#include <limits>
#include <set>
#include <sstream>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

WVKernelStatus fromCheckpoint(const WVCheckpointStatus &status) {
  if (status)
    return WVKernelStatus::ok();
  return {status.code == WVCheckpointStatusCode::unsupportedObserver
              ? WVKernelStatusCode::unsupportedOperation
              : WVKernelStatusCode::invalidConfiguration,
          status.message + (status.location.empty() ? "" :
                            " [" + status.location + "]")};
}

std::string normalizedDestination(const std::string &value) {
  return std::filesystem::absolute(std::filesystem::path(value))
      .lexically_normal()
      .string();
}

std::string stableIdentifier(const std::string &prefix,
                             const std::string &value) {
  std::uint64_t hash = UINT64_C(14695981039346656037);
  for (const auto character : value) {
    hash ^= static_cast<unsigned char>(character);
    hash *= UINT64_C(1099511628211);
  }
  std::ostringstream stream;
  stream << prefix << '-' << std::hex << std::setw(16) << std::setfill('0')
         << hash;
  return stream.str();
}

bool sameSchedule(const WVOutputScheduleRecord &left,
                  const WVOutputScheduleRecord &right) noexcept {
  return left.outputInterval == right.outputInterval &&
         left.initialTime == right.initialTime &&
         left.finalTime == right.finalTime;
}

bool sameStateBlock(const WVStateBlockRecord &left,
                    const WVStateBlockRecord &right) noexcept {
  return left.identifier == right.identifier &&
         left.scalarType == right.scalarType &&
         left.dimensions == right.dimensions &&
         left.toleranceKind == right.toleranceKind &&
         left.absoluteTolerance == right.absoluteTolerance &&
         left.ownership == right.ownership &&
         left.restartRequirement == right.restartRequirement;
}

bool sameObserver(const WVObserverRecord &left,
                  const WVObserverRecord &right) noexcept {
  return left.identifier == right.identifier && left.name == right.name &&
         left.kind == right.kind &&
         left.stateBlockIdentifiers == right.stateBlockIdentifiers &&
         left.fieldNames == right.fieldNames && left.x == right.x &&
         left.y == right.y && left.z == right.z &&
         left.isXYOnly == right.isXYOnly &&
         left.shouldAntialias == right.shouldAntialias &&
         left.advectionInterpolation == right.advectionInterpolation &&
         left.trackedFieldInterpolation == right.trackedFieldInterpolation &&
         left.horizontalAbsoluteTolerance ==
             right.horizontalAbsoluteTolerance &&
         left.verticalAbsoluteTolerance == right.verticalAbsoluteTolerance;
}

bool sameOutputFile(const WVOutputFileRecord &left,
                    const WVOutputFileRecord &right) {
  if (left.identifier != right.identifier ||
      left.destination != right.destination ||
      left.groups.size() != right.groups.size())
    return false;
  for (std::size_t index = 0; index < left.groups.size(); ++index) {
    const auto &a = left.groups[index];
    const auto &b = right.groups[index];
    if (a.identifier != b.identifier || a.name != b.name ||
        !sameSchedule(a.schedule, b.schedule) ||
        a.observerIdentifiers != b.observerIdentifiers ||
        a.containsCompleteCoefficientRestart !=
            b.containsCompleteCoefficientRestart)
      return false;
  }
  return true;
}

bool sameGraph(const WVPortableObserverRecord &left,
               const WVPortableObserverRecord &right) {
  if (left.schemaIdentifier != right.schemaIdentifier ||
      left.schemaVersion != right.schemaVersion ||
      left.stateBlocks.size() != right.stateBlocks.size() ||
      left.observers.size() != right.observers.size() ||
      left.outputFiles.size() != right.outputFiles.size())
    return false;
  for (std::size_t index = 0; index < left.stateBlocks.size(); ++index)
    if (!sameStateBlock(left.stateBlocks[index], right.stateBlocks[index]))
      return false;
  for (std::size_t index = 0; index < left.observers.size(); ++index)
    if (!sameObserver(left.observers[index], right.observers[index]))
      return false;
  for (std::size_t index = 0; index < left.outputFiles.size(); ++index)
    if (!sameOutputFile(left.outputFiles[index], right.outputFiles[index]))
      return false;
  return true;
}

bool sameProgress(const std::vector<WVOutputGroupProgress> &left,
                  const std::vector<WVOutputGroupProgress> &right) noexcept {
  if (left.size() != right.size())
    return false;
  for (std::size_t index = 0; index < left.size(); ++index)
    if (left[index].fileIdentifier != right[index].fileIdentifier ||
        left[index].groupIdentifier != right[index].groupIdentifier ||
        left[index].committedOrdinal != right[index].committedOrdinal)
      return false;
  return true;
}

} // namespace

WVKernelStatus WVModelOutputGroup::evenlySpaced(
    std::string name, double outputInterval, double initialTime,
    double finalTime, WVModelOutputGroup &group, std::string identifier) {
  if (name.empty() || !std::isfinite(outputInterval) || outputInterval <= 0.0 ||
      !std::isfinite(initialTime) || std::isnan(finalTime) ||
      finalTime < initialTime)
    return invalid("An evenly spaced output group requires a name, positive "
                   "finite interval, a finite initial time, and a "
                   "nondecreasing finite or unbounded final time.");
  WVModelOutputGroup candidate;
  candidate.record_.name = std::move(name);
  candidate.record_.identifier = std::move(identifier);
  candidate.record_.schedule = {outputInterval, initialTime, finalTime};
  group = std::move(candidate);
  return WVKernelStatus::ok();
}

WVKernelStatus
WVModelOutputGroup::addObservingSystem(std::string observerIdentifier) {
  if (sealed_)
    return invalid("The output group is sealed.");
  if (observerIdentifier.empty())
    return invalid("An observing-system identifier is required.");
  if (std::find(record_.observerIdentifiers.begin(),
                record_.observerIdentifiers.end(), observerIdentifier) !=
      record_.observerIdentifiers.end())
    return invalid("The observing system is already a member of this group.");
  record_.observerIdentifiers.push_back(std::move(observerIdentifier));
  return WVKernelStatus::ok();
}

WVKernelStatus
WVModelOutputGroup::containsCompleteCoefficientRestart(bool value) {
  if (sealed_)
    return invalid("The output group is sealed.");
  record_.containsCompleteCoefficientRestart = value;
  return WVKernelStatus::ok();
}

WVKernelStatus
WVModelOutputGroup::committedOrdinal(WVOutputScheduleOrdinal value) {
  if (sealed_)
    return invalid("The output group is sealed.");
  if (value < WVNoCommittedOutputOrdinal)
    return invalid("A committed output ordinal cannot be less than -1.");
  committedOrdinal_ = value;
  hasExplicitProgress_ = true;
  return WVKernelStatus::ok();
}

std::size_t WVModelOutputGroup::persistentBytes() const noexcept {
  std::size_t result = sizeof(*this) + record_.identifier.capacity() +
                       record_.name.capacity() +
                       record_.observerIdentifiers.capacity() *
                           sizeof(std::string);
  for (const auto &identifier : record_.observerIdentifiers)
    result += identifier.capacity();
  return result;
}

WVKernelStatus WVModelOutputFile::create(std::string destination,
                                         WVModelOutputFile &file,
                                         std::string identifier) {
  if (destination.empty())
    return invalid("An output destination is required.");
  WVModelOutputFile candidate;
  try {
    candidate.destination_ = normalizedDestination(destination);
  } catch (const std::exception &error) {
    return invalid(std::string("The output destination cannot be resolved: ") +
                   error.what());
  }
  candidate.identifier_ =
      identifier.empty()
          ? stableIdentifier("output-file", candidate.destination_)
          : std::move(identifier);
  file = std::move(candidate);
  return WVKernelStatus::ok();
}

WVKernelStatus WVModelOutputFile::addOutputGroup(WVModelOutputGroup group) {
  if (sealed_)
    return invalid("The output file is sealed.");
  if (group.sealed_)
    return invalid("A sealed output group cannot be added.");
  if (group.record_.identifier.empty())
    group.record_.identifier =
        stableIdentifier("output-group", identifier_ + ":" + group.name());
  if (outputGroupWithName(group.name()) != nullptr)
    return invalid("The output file already contains a group with this name.");
  const auto duplicateIdentifier =
      std::find_if(groups_.begin(), groups_.end(), [&](const auto &existing) {
        return existing.identifier() == group.identifier();
      });
  if (duplicateIdentifier != groups_.end())
    return invalid("The output file already contains this group identifier.");
  groups_.push_back(std::move(group));
  return WVKernelStatus::ok();
}

WVKernelStatus WVModelOutputFile::addNewEvenlySpacedOutputGroup(
    std::string name, double outputInterval, double initialTime,
    double finalTime, WVModelOutputGroup *&group, std::string identifier) {
  group = nullptr;
  WVModelOutputGroup candidate;
  auto status = WVModelOutputGroup::evenlySpaced(
      std::move(name), outputInterval, initialTime, finalTime, candidate,
      std::move(identifier));
  if (!status)
    return status;
  status = addOutputGroup(std::move(candidate));
  if (!status)
    return status;
  group = &groups_.back();
  return WVKernelStatus::ok();
}

WVKernelStatus
WVModelOutputFile::addObservingSystem(std::string observerIdentifier) {
  if (sealed_)
    return invalid("The output file is sealed.");
  if (groups_.size() != 1)
    return invalid("File-level observing-system addition requires exactly "
                   "one output group.");
  return groups_.front().addObservingSystem(std::move(observerIdentifier));
}

WVModelOutputGroup *
WVModelOutputFile::outputGroupWithName(const std::string &name) noexcept {
  const auto found = std::find_if(groups_.begin(), groups_.end(),
                                  [&](const auto &group) {
                                    return group.name() == name;
                                  });
  return found == groups_.end() ? nullptr : &*found;
}

const WVModelOutputGroup *WVModelOutputFile::outputGroupWithName(
    const std::string &name) const noexcept {
  const auto found = std::find_if(groups_.begin(), groups_.end(),
                                  [&](const auto &group) {
                                    return group.name() == name;
                                  });
  return found == groups_.end() ? nullptr : &*found;
}

WVModelOutputGroup *WVModelOutputFile::outputGroupWithIdentifier(
    const std::string &identifier) noexcept {
  const auto found = std::find_if(groups_.begin(), groups_.end(),
                                  [&](const auto &group) {
                                    return group.identifier() == identifier;
                                  });
  return found == groups_.end() ? nullptr : &*found;
}

const WVModelOutputGroup *WVModelOutputFile::outputGroupWithIdentifier(
    const std::string &identifier) const noexcept {
  const auto found = std::find_if(groups_.begin(), groups_.end(),
                                  [&](const auto &group) {
                                    return group.identifier() == identifier;
                                  });
  return found == groups_.end() ? nullptr : &*found;
}

std::size_t WVModelOutputFile::persistentBytes() const noexcept {
  std::size_t result = sizeof(*this) + destination_.capacity() +
                       identifier_.capacity();
  for (const auto &group : groups_)
    result += group.persistentBytes();
  return result;
}

class WVModelOutputConfiguration::Impl final {
public:
  WVPortableObserverDescriptor descriptor;
  WVOutputPlan plan;
  std::vector<WVOutputGroupProgress> progress;
  WVModelOutputPolicy policy = WVModelOutputPolicy::create;
};

WVModelOutputConfiguration::WVModelOutputConfiguration()
    : impl_(std::make_unique<Impl>()) {}
WVModelOutputConfiguration::~WVModelOutputConfiguration() = default;
WVModelOutputConfiguration::WVModelOutputConfiguration(
    WVModelOutputConfiguration &&) noexcept = default;
WVModelOutputConfiguration &WVModelOutputConfiguration::operator=(
    WVModelOutputConfiguration &&) noexcept = default;

WVKernelStatus WVModelOutputConfiguration::build(
    WVPortableObserverRecord observerRecord,
    std::vector<WVModelOutputFile> files, WVModelOutputPolicy policy,
    double initialTime, double finalTime,
    WVModelOutputConfiguration &configuration) {
  if (files.empty())
    return invalid("At least one output file is required.");
  try {
    std::set<std::string> destinations;
    std::set<std::string> fileIdentifiers;
    observerRecord.outputFiles.clear();
    std::vector<WVOutputGroupProgress> explicitProgress;
    bool hasAnyExplicitProgress = false;
    bool hasAnyImplicitProgress = false;
    std::vector<std::string> appendPaths;
    for (auto &file : files) {
      if (file.sealed_)
        return invalid("An output file builder was already consumed.");
      file.destination_ = normalizedDestination(file.destination_);
      if (!destinations.insert(file.destination_).second)
        return invalid("Output destinations must be unique across the graph.");
      if (!fileIdentifiers.insert(file.identifier_).second)
        return invalid("Output file identifiers must be unique.");
      const bool exists = std::filesystem::exists(file.destination_);
      if (policy == WVModelOutputPolicy::create && exists)
        return invalid("Create policy requires every destination to be absent.");
      if ((policy == WVModelOutputPolicy::replace ||
           policy == WVModelOutputPolicy::append) &&
          !exists)
        return invalid("Replace and append policies require every destination "
                       "to exist.");
      WVOutputFileRecord record{file.identifier_, file.destination_, {}};
      for (auto &group : file.groups_) {
        if (group.sealed_)
          return invalid("An output group builder was already consumed.");
        if (group.record_.identifier.empty())
          group.record_.identifier = stableIdentifier(
              "output-group", file.identifier_ + ":" + group.name());
        record.groups.push_back(group.record_);
        explicitProgress.push_back({file.identifier_, group.identifier(),
                                    group.committedOrdinal_});
        hasAnyExplicitProgress |= group.hasExplicitProgress_;
        hasAnyImplicitProgress |= !group.hasExplicitProgress_;
        group.sealed_ = true;
      }
      file.sealed_ = true;
      observerRecord.outputFiles.push_back(std::move(record));
      appendPaths.push_back(file.destination_);
    }
    if (hasAnyExplicitProgress && hasAnyImplicitProgress)
      return invalid("Committed progress must be supplied for every output "
                     "group or for none of them.");

    auto candidate = std::make_unique<Impl>();
    auto status = WVPortableObserverDescriptor::create(observerRecord,
                                                        candidate->descriptor);
    if (!status)
      return status;

    if (policy == WVModelOutputPolicy::append) {
      WVModelOutputNetCDFInspection inspection;
      const auto inspected =
          WVModelOutputNetCDFSink::inspect(appendPaths, inspection);
      if (!inspected)
        return fromCheckpoint(inspected);
      if (!sameGraph(observerRecord, inspection.observerRecord))
        return invalid("Append destinations do not contain the configured "
                       "observer and output graph.");
      candidate->progress = inspection.progress;
      if (hasAnyExplicitProgress &&
          !sameProgress(candidate->progress, explicitProgress))
        return invalid("Explicit committed ordinals do not match the append "
                       "destinations.");
    } else if (hasAnyExplicitProgress) {
      candidate->progress = std::move(explicitProgress);
    }

    status = WVOutputPlan::create(candidate->descriptor, initialTime, finalTime,
                                  candidate->progress, candidate->plan);
    if (!status)
      return status;
    candidate->progress = candidate->plan.initialProgress();
    candidate->policy = policy;
    files.clear();
    configuration.impl_ = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Output configuration allocation failed."};
  } catch (const std::exception &error) {
    return invalid(std::string("Output configuration failed: ") + error.what());
  }
}

WVCheckpointStatus WVModelOutputConfiguration::openNetCDFSink(
    const WVModelOutputNetCDFConfiguration &configuration,
    const WVIntegrationStateLayout &stateLayout,
    WVObserverSampleSource *sampleSource,
    WVModelOutputNetCDFSink &sink) const {
  switch (impl_->policy) {
  case WVModelOutputPolicy::create:
    return WVModelOutputNetCDFSink::createNew(
        configuration, impl_->descriptor, stateLayout, sampleSource, sink);
  case WVModelOutputPolicy::replace:
    return WVModelOutputNetCDFSink::replaceExisting(
        configuration, impl_->descriptor, stateLayout, sampleSource, sink);
  case WVModelOutputPolicy::append:
    return WVModelOutputNetCDFSink::openAppend(
        configuration, impl_->descriptor, stateLayout, sampleSource, sink);
  }
  return {WVCheckpointStatusCode::invalidValue,
          "Unsupported output policy.", {}};
}

const WVPortableObserverDescriptor &
WVModelOutputConfiguration::descriptor() const noexcept {
  return impl_->descriptor;
}

const WVOutputPlan &WVModelOutputConfiguration::plan() const noexcept {
  return impl_->plan;
}

const std::vector<WVOutputGroupProgress> &
WVModelOutputConfiguration::progress() const noexcept {
  return impl_->progress;
}

WVModelOutputPolicy WVModelOutputConfiguration::policy() const noexcept {
  return impl_->policy;
}

std::size_t WVModelOutputConfiguration::persistentBytes() const noexcept {
  return sizeof(*this) + sizeof(Impl) + impl_->descriptor.persistentBytes() +
         impl_->plan.persistentBytes() +
         impl_->progress.capacity() * sizeof(WVOutputGroupProgress);
}

} // namespace wavevortex::runtime
