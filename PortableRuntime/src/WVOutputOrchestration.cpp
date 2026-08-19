#include "WaveVortexRuntime/WVOutputOrchestration.hpp"
#include "WVObserverAdapter.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <limits>
#include <map>
#include <new>
#include <utility>

namespace wavevortex::runtime {
namespace {

double timeTolerance(double first, double second) noexcept {
  return 8.0 * std::numeric_limits<double>::epsilon() *
         std::max({1.0, std::abs(first), std::abs(second)});
}

bool sameTime(double first, double second) noexcept {
  return std::abs(first - second) <= timeTolerance(first, second);
}

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

std::size_t stringBytes(const std::string &value) noexcept {
  return value.capacity();
}

std::size_t observerRecordBytes(const WVObserverRecord &observer) noexcept {
  std::size_t bytes =
      stringBytes(observer.identifier) + stringBytes(observer.name) +
      observer.stateBlockIdentifiers.capacity() * sizeof(std::string) +
      observer.fieldNames.capacity() * sizeof(std::string) +
      (observer.x.capacity() + observer.y.capacity() + observer.z.capacity()) *
          sizeof(double);
  for (const auto &value : observer.stateBlockIdentifiers)
    bytes += stringBytes(value);
  for (const auto &value : observer.fieldNames)
    bytes += stringBytes(value);
  return bytes;
}

bool canonicalBlock(const std::string &identifier) noexcept {
  return identifier == "Ap" || identifier == "Am" || identifier == "A0";
}

bool sameStateBlockRecord(const WVStateBlockRecord &first,
                          const WVStateBlockRecord &second) noexcept {
  return first.identifier == second.identifier &&
         first.scalarType == second.scalarType &&
         first.dimensions == second.dimensions &&
         first.toleranceKind == second.toleranceKind &&
         first.absoluteTolerance == second.absoluteTolerance &&
         first.ownership == second.ownership &&
         first.restartRequirement == second.restartRequirement;
}

bool sameObserverRecord(const WVObserverRecord &first,
                        const WVObserverRecord &second) noexcept {
  return first.identifier == second.identifier && first.name == second.name &&
         first.typeIdentifier == second.typeIdentifier &&
         first.contractVersion == second.contractVersion &&
         first.stateBlockIdentifiers == second.stateBlockIdentifiers &&
         first.fieldNames == second.fieldNames && first.x == second.x &&
         first.y == second.y && first.z == second.z &&
         first.isXYOnly == second.isXYOnly &&
         first.shouldAntialias == second.shouldAntialias &&
         first.advectionInterpolation == second.advectionInterpolation &&
         first.trackedFieldInterpolation == second.trackedFieldInterpolation &&
         first.horizontalAbsoluteTolerance ==
             second.horizontalAbsoluteTolerance &&
         first.verticalAbsoluteTolerance == second.verticalAbsoluteTolerance &&
         first.outputScale == second.outputScale &&
         first.outputOffset == second.outputOffset;
}

WVKernelStatus
validateDescriptorLayout(const WVPortableObserverRecord &record,
                         const WVIntegrationStateLayout &layout) {
  if (record.stateBlocks.size() != layout.stateBlockRecords().size() ||
      !std::equal(record.stateBlocks.begin(), record.stateBlocks.end(),
                  layout.stateBlockRecords().begin(), sameStateBlockRecord))
    return invalid("Output plan state-block descriptor does not match the "
                   "integrator layout descriptor.");
  if (record.observers.size() != layout.observerRecords().size() ||
      !std::equal(record.observers.begin(), record.observers.end(),
                  layout.observerRecords().begin(), sameObserverRecord))
    return invalid("Output plan observer descriptor does not match the "
                   "integrator layout descriptor.");
  const auto coefficientShape = layout.coefficientShape();
  const std::vector<std::size_t> coefficientDimensions{
      coefficientShape.rows, coefficientShape.columns};
  std::size_t additionalIndex = 0;
  for (const auto &block : record.stateBlocks) {
    if (canonicalBlock(block.identifier)) {
      if (block.scalarType != WVStateScalarType::complex64 ||
          block.dimensions != coefficientDimensions ||
          block.ownership != WVStateOwnership::integratorOwned)
        return invalid("Output descriptor canonical coefficient blocks do not "
                       "match the integrator state layout.");
      continue;
    }
    if (block.ownership == WVStateOwnership::observerDerived)
      continue;
    if (additionalIndex >= layout.additionalBlocks().size())
      return invalid("Output descriptor contains integrated state blocks that "
                     "are absent from the integrator layout.");
    const auto &expected = layout.additionalBlocks()[additionalIndex++];
    if (block.identifier != expected.identifier ||
        block.scalarType != expected.scalarType ||
        block.dimensions != expected.dimensions ||
        block.toleranceKind != expected.toleranceKind ||
        block.absoluteTolerance != expected.absoluteTolerance ||
        block.ownership != expected.ownership ||
        block.restartRequirement != expected.restartRequirement)
      return invalid("Output descriptor integrated state-block identity, "
                     "order, type, dimensions, or tolerance metadata does not "
                     "match the integrator layout.");
  }
  if (additionalIndex != layout.additionalBlocks().size())
    return invalid("Integrator layout contains integrated state blocks that "
                   "are absent from the output descriptor.");
  return WVKernelStatus::ok();
}

WVKernelStatus copyIntegrationState(const WVIntegrationStateLayout &layout,
                                    const WVIntegrationState &source,
                                    WVMutableIntegrationState &destination) {
  auto status = validateIntegrationState(layout, source);
  if (!status)
    return status;
  status = validateMutableIntegrationState(layout, destination);
  if (!status)
    return status;
  const auto count = layout.coefficientShape().elementCount();
  const WVComplexConstView sourceCoefficients[] = {
      source.waveVortex.coefficients.Ap, source.waveVortex.coefficients.Am,
      source.waveVortex.coefficients.A0};
  WVComplexView destinationCoefficients[] = {
      destination.waveVortex.coefficients.Ap,
      destination.waveVortex.coefficients.Am,
      destination.waveVortex.coefficients.A0};
  for (std::size_t component = 0; component < 3; ++component)
    std::copy_n(sourceCoefficients[component].data, count,
                destinationCoefficients[component].data);
  for (std::size_t block = 0; block < source.additionalBlockCount; ++block) {
    const auto &metadata = *source.additionalBlocks[block].layout;
    if (metadata.scalarType == WVStateScalarType::real64)
      std::copy_n(source.additionalBlocks[block].realData,
                  metadata.elementCount,
                  destination.additionalBlocks[block].realData);
    else
      std::copy_n(source.additionalBlocks[block].complexData,
                  metadata.elementCount,
                  destination.additionalBlocks[block].complexData);
  }
  destination.waveVortex.t = source.waveVortex.t;
  destination.waveVortex.t0 = source.waveVortex.t0;
  return WVKernelStatus::ok();
}

WVKernelStatus stageCheckpointState(WVCheckpoint &checkpoint,
                                    const WVIntegrationState &state) {
  const auto shape = checkpoint.state.coefficients.shape;
  const auto actual = state.waveVortex.coefficients.Ap.shape;
  if (shape.rows != actual.rows || shape.columns != actual.columns ||
      state.waveVortex.coefficients.Am.shape.rows != shape.rows ||
      state.waveVortex.coefficients.Am.shape.columns != shape.columns ||
      state.waveVortex.coefficients.A0.shape.rows != shape.rows ||
      state.waveVortex.coefficients.A0.shape.columns != shape.columns)
    return {WVKernelStatusCode::invalidShape,
            "Checkpoint template and output state shapes differ."};
  const auto count = shape.elementCount();
  if (checkpoint.state.coefficients.Ap.size() != count ||
      checkpoint.state.coefficients.Am.size() != count ||
      checkpoint.state.coefficients.A0.size() != count)
    return {WVKernelStatusCode::invalidShape,
            "Checkpoint template coefficient storage is incomplete."};
  const WVComplexConstView sources[] = {state.waveVortex.coefficients.Ap,
                                        state.waveVortex.coefficients.Am,
                                        state.waveVortex.coefficients.A0};
  std::vector<WVComplex64> *destinations[] = {
      &checkpoint.state.coefficients.Ap, &checkpoint.state.coefficients.Am,
      &checkpoint.state.coefficients.A0};
  for (std::size_t component = 0; component < 3; ++component)
    std::copy_n(sources[component].data, count,
                destinations[component]->data());
  checkpoint.state.t = state.waveVortex.t;
  checkpoint.state.t0 = state.waveVortex.t0;
  return WVKernelStatus::ok();
}

std::size_t
checkpointCoefficientCapacityBytes(const WVCheckpoint &checkpoint) noexcept {
  return (checkpoint.state.coefficients.Ap.capacity() +
          checkpoint.state.coefficients.Am.capacity() +
          checkpoint.state.coefficients.A0.capacity()) *
         sizeof(WVComplex64);
}

} // namespace

class WVOutputPlan::Impl {
public:
  struct Group {
    std::size_t fileOrdinal = 0;
    std::size_t groupOrdinal = 0;
    std::size_t progressIndex = 0;
    const WVOutputFileRecord *file = nullptr;
    const WVOutputGroupRecord *group = nullptr;
    std::vector<WVOutputObserverView> observers;
    std::shared_ptr<const WVOutputSchedule> schedule;
    WVOutputRouteView route;
  };

  WVPortableObserverRecord record;
  WVIntegrationStateLayout stateLayout;
  double initialTime = 0.0;
  double finalTime = 0.0;
  std::vector<Group> groups;
  std::vector<WVOutputGroupProgress> progress;
  mutable std::vector<WVOutputRouteView> diagnosticRoutes;
  mutable std::vector<WVOutputScheduleCursor> diagnosticCursors;
  WVOutputPlanMetrics metrics;

  bool
  generateDiagnosticEvent(std::size_t requestedIndex, double &scheduledTime,
                          std::vector<WVOutputRouteView> &routes,
                          std::size_t *eventCount = nullptr) const noexcept;

  std::size_t persistentBytes() const noexcept {
    std::size_t bytes =
        stringBytes(record.schemaIdentifier) +
        record.stateBlocks.capacity() * sizeof(WVStateBlockRecord) +
        record.observers.capacity() * sizeof(WVObserverRecord) +
        record.outputFiles.capacity() * sizeof(WVOutputFileRecord) +
        groups.capacity() * sizeof(Group) +
        diagnosticRoutes.capacity() * sizeof(WVOutputRouteView) +
        diagnosticCursors.capacity() * sizeof(WVOutputScheduleCursor) +
        progress.capacity() * sizeof(WVOutputGroupProgress);
    for (const auto &block : record.stateBlocks)
      bytes += stringBytes(block.identifier) +
               block.dimensions.capacity() * sizeof(std::size_t);
    for (const auto &observer : record.observers)
      bytes += observerRecordBytes(observer);
    for (const auto &file : record.outputFiles) {
      bytes += stringBytes(file.identifier) + stringBytes(file.destination) +
               file.groups.capacity() * sizeof(WVOutputGroupRecord);
      for (const auto &group : file.groups) {
        bytes += stringBytes(group.identifier) + stringBytes(group.name) +
                 stringBytes(group.schedule.typeIdentifier) +
                 group.schedule.configuration.persistentBytes() -
                 sizeof(WVPortableTypedRecord) +
                 group.observerIdentifiers.capacity() * sizeof(std::string);
        for (const auto &identifier : group.observerIdentifiers)
          bytes += stringBytes(identifier);
      }
    }
    for (const auto &group : groups)
      bytes += group.observers.capacity() * sizeof(WVOutputObserverView);
    for (const auto &item : progress) {
      bytes +=
          stringBytes(item.fileIdentifier) + stringBytes(item.groupIdentifier) +
          item.scheduleCursor.persistentBytes() - sizeof(WVPortableTypedRecord);
    }
    for (const auto &group : groups)
      if (group.schedule)
        bytes += group.schedule->persistentBytes();
    return bytes;
  }
};

bool WVOutputPlan::Impl::generateDiagnosticEvent(
    std::size_t requestedIndex, double &scheduledTime,
    std::vector<WVOutputRouteView> &routes,
    std::size_t *eventCount) const noexcept {
  try {
    std::vector<WVOutputScheduleCursor> cursors;
    std::vector<WVOutputScheduleOccurrence> occurrences(groups.size());
    std::vector<std::uint8_t> available(groups.size(), 0);
    cursors.reserve(progress.size());
    for (const auto &item : progress)
      cursors.push_back({item.committedOrdinal, item.scheduleCursor});
    std::size_t eventIndex = 0;
    for (;;) {
      double earliest = std::numeric_limits<double>::infinity();
      for (std::size_t groupIndex = 0; groupIndex < groups.size();
           ++groupIndex) {
        bool found = false;
        const auto status = groups[groupIndex].schedule->peek(
            cursors[groupIndex], initialTime, finalTime,
            occurrences[groupIndex], found);
        if (!status)
          return false;
        available[groupIndex] = found ? 1 : 0;
        if (found)
          earliest = std::min(earliest, occurrences[groupIndex].scheduledTime);
      }
      if (!std::isfinite(earliest)) {
        if (eventCount)
          *eventCount = eventIndex;
        return false;
      }
      if (eventIndex == requestedIndex) {
        routes.clear();
        diagnosticCursors.clear();
        scheduledTime = earliest;
        for (std::size_t groupIndex = 0; groupIndex < groups.size();
             ++groupIndex) {
          if (!available[groupIndex] ||
              occurrences[groupIndex].scheduledTime != earliest)
            continue;
          auto route = groups[groupIndex].route;
          route.scheduleOrdinal = occurrences[groupIndex].ordinal;
          diagnosticCursors.push_back(occurrences[groupIndex].proposedCursor);
          route.proposedScheduleCursor = &diagnosticCursors.back().values;
          routes.push_back(route);
        }
        return true;
      }
      for (std::size_t groupIndex = 0; groupIndex < groups.size(); ++groupIndex)
        if (available[groupIndex] &&
            occurrences[groupIndex].scheduledTime == earliest)
          cursors[groupIndex] = occurrences[groupIndex].proposedCursor;
      if (eventIndex == std::numeric_limits<std::size_t>::max())
        return false;
      ++eventIndex;
    }
  } catch (...) {
    return false;
  }
}

WVOutputPlan::WVOutputPlan() : impl_(new Impl) {}
WVOutputPlan::~WVOutputPlan() = default;
WVOutputPlan::WVOutputPlan(WVOutputPlan &&) noexcept = default;
WVOutputPlan &WVOutputPlan::operator=(WVOutputPlan &&) noexcept = default;

WVKernelStatus
WVOutputPlan::create(const WVPortableObserverDescriptor &descriptor,
                     double initialTime, double finalTime,
                     const std::vector<WVOutputGroupProgress> &suppliedProgress,
                     WVOutputPlan &plan) {
  if (!std::isfinite(initialTime) || !std::isfinite(finalTime) ||
      finalTime < initialTime)
    return invalid("Output planning requires a finite, nondecreasing "
                   "integration interval.");
  try {
    auto candidate = std::make_unique<Impl>();
    candidate->record = descriptor.record();
    const auto canonical = std::find_if(
        candidate->record.stateBlocks.begin(),
        candidate->record.stateBlocks.end(),
        [](const auto &block) { return block.identifier == "Ap"; });
    if (canonical == candidate->record.stateBlocks.end() ||
        canonical->dimensions.size() != 2)
      return invalid("Output planning requires a canonical [Nj,Nkl] Ap block.");
    auto layoutStatus = WVIntegrationStateLayout::create(
        {canonical->dimensions[0], canonical->dimensions[1]}, descriptor,
        candidate->stateLayout);
    if (!layoutStatus)
      return layoutStatus;
    layoutStatus =
        validateDescriptorLayout(candidate->record, candidate->stateLayout);
    if (!layoutStatus)
      return layoutStatus;
    candidate->initialTime = initialTime;
    candidate->finalTime = finalTime;
    candidate->metrics.fileCount = candidate->record.outputFiles.size();
    candidate->metrics.distinctObserverCount =
        candidate->record.observers.size();

    std::size_t groupCount = 0;
    for (const auto &file : candidate->record.outputFiles) {
      if (groupCount >
          std::numeric_limits<std::size_t>::max() - file.groups.size())
        return {WVKernelStatusCode::sizeOverflow,
                "Output group count overflows size_t."};
      groupCount += file.groups.size();
    }
    candidate->metrics.groupCount = groupCount;
    candidate->groups.reserve(groupCount);
    candidate->progress.reserve(groupCount);

    if (!suppliedProgress.empty() && suppliedProgress.size() != groupCount)
      return invalid("Committed output progress must be empty for a new run or "
                     "contain exactly one entry per configured group.");

    std::map<std::string, std::size_t> observerOrdinals;
    for (std::size_t index = 0; index < candidate->record.observers.size();
         ++index)
      observerOrdinals.emplace(candidate->record.observers[index].identifier,
                               index);

    std::size_t progressIndex = 0;
    for (std::size_t fileIndex = 0;
         fileIndex < candidate->record.outputFiles.size(); ++fileIndex) {
      const auto &file = candidate->record.outputFiles[fileIndex];
      for (std::size_t groupIndex = 0; groupIndex < file.groups.size();
           ++groupIndex, ++progressIndex) {
        const auto &group = file.groups[groupIndex];
        WVOutputGroupProgress cursor;
        cursor.fileIdentifier = file.identifier;
        cursor.groupIdentifier = group.identifier;
        if (!suppliedProgress.empty()) {
          cursor = suppliedProgress[progressIndex];
          if (cursor.fileIdentifier != file.identifier ||
              cursor.groupIdentifier != group.identifier ||
              cursor.committedOrdinal < WVNoCommittedOutputOrdinal)
            return invalid("Committed output progress does not match the "
                           "deterministic file/group order or ordinal range.");
        }
        Impl::Group resolved;
        resolved.fileOrdinal = fileIndex;
        resolved.groupOrdinal = groupIndex;
        resolved.progressIndex = progressIndex;
        resolved.file = &file;
        resolved.group = &group;
        auto scheduleStatus = WVOutputScheduleFactoryRegistry::resolve(
            group.schedule, resolved.schedule);
        if (!scheduleStatus)
          return scheduleStatus;
        WVOutputScheduleCursor scheduleCursor{cursor.committedOrdinal,
                                              cursor.scheduleCursor};
        scheduleStatus = resolved.schedule->validateCursor(scheduleCursor);
        if (!scheduleStatus)
          return scheduleStatus;
        double committedTime = 0.0;
        bool hasCommittedTime = false;
        scheduleStatus = resolved.schedule->committedTime(
            scheduleCursor, committedTime, hasCommittedTime);
        if (!scheduleStatus)
          return scheduleStatus;
        if (hasCommittedTime &&
            committedTime >
                initialTime + timeTolerance(committedTime, initialTime))
          return invalid("Committed output progress lies beyond the segment "
                         "start.");
        candidate->progress.push_back(cursor);
        resolved.observers.reserve(group.observerIdentifiers.size());
        for (const auto &identifier : group.observerIdentifiers) {
          const auto found = observerOrdinals.find(identifier);
          if (found == observerOrdinals.end())
            return invalid("Output route references an unresolved observer: " +
                           identifier);
          resolved.observers.push_back(
              {found->second, &candidate->record.observers[found->second],
               descriptor.implementation(
                   descriptor.observers()[found->second])});
        }
        resolved.route = {fileIndex,
                          groupIndex,
                          WVNoCommittedOutputOrdinal,
                          file.identifier,
                          file.destination,
                          group.identifier,
                          group.name,
                          resolved.observers.data(),
                          resolved.observers.size()};
        candidate->groups.push_back(std::move(resolved));
      }
    }
    candidate->metrics.maximumCoincidentRouteCount = candidate->groups.size();
    candidate->diagnosticRoutes.reserve(candidate->groups.size());
    candidate->diagnosticCursors.reserve(candidate->groups.size());
    candidate->metrics.retainedStorageBytes = candidate->persistentBytes();
    plan.impl_ = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Output planning allocation failed."};
  }
}

WVKernelStatus
WVOutputPlan::createExplicit(const WVIntegrationStateLayout &layout,
                             double initialTime, double finalTime,
                             const std::vector<WVExplicitOutputTarget> &targets,
                             WVOutputPlan &plan) {
  try {
    WVPortableObserverRecord record;
    record.stateBlocks = layout.stateBlockRecords();
    record.observers = layout.observerRecords();
    auto coefficientObserver = std::find_if(
        record.observers.begin(), record.observers.end(), [](const auto &item) {
          const auto implementation = detail::observerImplementation(
              item.typeIdentifier, item.contractVersion);
          return implementation && implementation->recordsCoefficients();
        });
    std::string coefficientIdentifier;
    if (coefficientObserver == record.observers.end()) {
      const auto implementation = std::find_if(
          detail::observerImplementations().begin(),
          detail::observerImplementations().end(), [](const auto &candidate) {
            return candidate->recordsCoefficients();
          });
      if (implementation == detail::observerImplementations().end())
        return {WVKernelStatusCode::unsupportedOperation,
                "No coefficient observer implementation is registered."};
      WVObserverRecord observer;
      observer.identifier = "explicit-checkpoint-coefficients";
      observer.name = (*implementation)->typeIdentifier();
      observer.typeIdentifier = (*implementation)->typeIdentifier();
      observer.contractVersion = (*implementation)->contractVersion();
      observer.stateBlockIdentifiers = {"Ap", "Am", "A0"};
      coefficientIdentifier = observer.identifier;
      record.observers.push_back(std::move(observer));
    } else {
      coefficientIdentifier = coefficientObserver->identifier;
    }
    record.outputFiles.reserve(targets.size());
    for (std::size_t index = 0; index < targets.size(); ++index) {
      const auto &target = targets[index];
      if (!std::isfinite(target.requestedTime) || target.destination.empty() ||
          target.requestedTime <
              initialTime - timeTolerance(initialTime, finalTime) ||
          target.requestedTime >
              finalTime + timeTolerance(initialTime, finalTime))
        return invalid("Explicit output target is outside the planned interval "
                       "or has an empty destination.");
      WVOutputFileRecord file;
      file.identifier = "explicit-file-" + std::to_string(index + 1);
      file.destination = target.destination;
      WVOutputGroupRecord group;
      group.identifier = "checkpoint";
      group.name = "checkpoint";
      group.schedule = {1.0, target.requestedTime, target.requestedTime};
      group.observerIdentifiers = {coefficientIdentifier};
      group.containsCompleteCoefficientRestart = true;
      file.groups.push_back(std::move(group));
      record.outputFiles.push_back(std::move(file));
    }
    WVPortableObserverDescriptor descriptor;
    auto status = WVPortableObserverDescriptor::create(record, descriptor);
    if (!status)
      return status;
    status = WVOutputPlan::create(descriptor, initialTime, finalTime, {}, plan);
    if (!status)
      return status;
    plan.impl_->stateLayout = layout;
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Explicit output planning allocation failed."};
  }
}

double WVOutputPlan::initialTime() const noexcept { return impl_->initialTime; }
double WVOutputPlan::finalTime() const noexcept { return impl_->finalTime; }
std::size_t WVOutputPlan::groupCount() const noexcept {
  return impl_->groups.size();
}
WVOutputRouteView WVOutputPlan::groupRoute(std::size_t index) const noexcept {
  if (index >= impl_->groups.size())
    return {};
  return impl_->groups[index].route;
}
std::size_t WVOutputPlan::eventCount() const noexcept {
  std::size_t count = 0;
  double ignored = 0.0;
  impl_->generateDiagnosticEvent(std::numeric_limits<std::size_t>::max(),
                                 ignored, impl_->diagnosticRoutes, &count);
  return count;
}
WVOutputPlannedEventView WVOutputPlan::event(std::size_t index) const noexcept {
  double time = 0.0;
  if (!impl_->generateDiagnosticEvent(index, time, impl_->diagnosticRoutes))
    return {};
  return {index, time, impl_->diagnosticRoutes.data(),
          impl_->diagnosticRoutes.size()};
}
const std::vector<WVOutputGroupProgress> &
WVOutputPlan::initialProgress() const noexcept {
  return impl_->progress;
}
const WVOutputPlanMetrics &WVOutputPlan::metrics() const noexcept {
  return impl_->metrics;
}
const WVIntegrationStateLayout &WVOutputPlan::stateLayout() const noexcept {
  return impl_->stateLayout;
}
std::size_t WVOutputPlan::persistentBytes() const noexcept {
  return impl_->persistentBytes();
}

class WVOutputDriver::Impl {
public:
  Impl(WVTimeIntegrator &integrator, const WVOutputPlan &plan)
      : integrator(integrator), plan(plan) {}

  WVTimeIntegrator &integrator;
  const WVOutputPlan &plan;
  std::vector<WVComplex64> interpolationCoefficients;
  WVAdditionalStateStorage interpolationAdditional;
  WVMutableIntegrationState interpolationState;
  std::vector<WVAdditionalStateBlockConstView> interpolationConstViews;
  std::vector<WVAdditionalStateBlockConstView> sourceConstViews;
  std::vector<WVOutputGroupProgress> progress;
  std::vector<WVOutputScheduleOccurrence> nextOccurrences;
  std::vector<std::uint8_t> occurrenceAvailable;
  std::vector<std::uint8_t> occurrenceNeedsRefresh;
  std::vector<WVOutputRouteView> stagedRoutes;
  std::vector<std::size_t> stagedProgressIndices;
  std::vector<WVOutputScheduleCursor> stagedProposedCursors;
  std::vector<WVOutputDeliveryRecord> records;
  WVOutputDriverMetrics metrics;
  std::size_t nextRouteIndex = 0;
  std::size_t nextRouteOrdinal = 0;
  std::size_t stagedEventOrdinal = 0;
  double stagedEventTime = 0.0;
  double proposedStepSize = 0.0;
  double acceptedStateTime = 0.0;
  WVOutputEventKind stagedEventKind = WVOutputEventKind::acceptedEndpoint;
  bool running = false;
  bool started = false;
  bool completed = false;
  bool hasPendingEvent = false;
  bool hasStagedEvent = false;

  std::size_t persistentBytes() const noexcept {
    std::size_t bytes =
        interpolationCoefficients.capacity() * sizeof(WVComplex64) +
        interpolationAdditional.capacityBytes() +
        interpolationConstViews.capacity() *
            sizeof(WVAdditionalStateBlockConstView) +
        sourceConstViews.capacity() * sizeof(WVAdditionalStateBlockConstView) +
        progress.capacity() * sizeof(WVOutputGroupProgress) +
        nextOccurrences.capacity() * sizeof(WVOutputScheduleOccurrence) +
        occurrenceAvailable.capacity() * sizeof(std::uint8_t) +
        occurrenceNeedsRefresh.capacity() * sizeof(std::uint8_t) +
        stagedRoutes.capacity() * sizeof(WVOutputRouteView) +
        stagedProgressIndices.capacity() * sizeof(std::size_t) +
        stagedProposedCursors.capacity() * sizeof(WVOutputScheduleCursor) +
        records.capacity() * sizeof(WVOutputDeliveryRecord) +
        metrics.files.capacity() * sizeof(WVOutputFileMetrics);
    for (const auto &item : progress)
      bytes +=
          stringBytes(item.fileIdentifier) + stringBytes(item.groupIdentifier) +
          item.scheduleCursor.persistentBytes() - sizeof(WVPortableTypedRecord);
    for (const auto &item : nextOccurrences)
      bytes += item.proposedCursor.values.persistentBytes() -
               sizeof(WVPortableTypedRecord);
    for (const auto &item : stagedProposedCursors)
      bytes += item.values.persistentBytes() - sizeof(WVPortableTypedRecord);
    for (const auto &record : records)
      bytes +=
          stringBytes(record.fileIdentifier) + stringBytes(record.destination) +
          stringBytes(record.groupIdentifier) + stringBytes(record.failure);
    for (const auto &file : metrics.files) {
      bytes += stringBytes(file.fileIdentifier) +
               stringBytes(file.destination) +
               file.groups.capacity() * sizeof(WVOutputGroupMetrics);
      for (const auto &group : file.groups)
        bytes += stringBytes(group.fileIdentifier) +
                 stringBytes(group.groupIdentifier);
    }
    return bytes;
  }

  WVKernelStatus prepareTracking() {
    try {
      progress = plan.impl_->progress;
      metrics = {};
      metrics.files.reserve(plan.impl_->record.outputFiles.size());
      for (const auto &file : plan.impl_->record.outputFiles) {
        WVOutputFileMetrics fileMetrics;
        fileMetrics.fileIdentifier = file.identifier;
        fileMetrics.destination = file.destination;
        fileMetrics.groups.reserve(file.groups.size());
        for (const auto &group : file.groups)
          fileMetrics.groups.push_back(
              {file.identifier, group.identifier, 0, 0, 0, 0, 0, 0});
        metrics.files.push_back(std::move(fileMetrics));
      }
      records.clear();
      nextOccurrences.resize(plan.impl_->groups.size());
      occurrenceAvailable.assign(plan.impl_->groups.size(), 0);
      occurrenceNeedsRefresh.assign(plan.impl_->groups.size(), 1);
      stagedRoutes.reserve(plan.impl_->groups.size());
      stagedProgressIndices.reserve(plan.impl_->groups.size());
      stagedProposedCursors.reserve(plan.impl_->groups.size());
      return WVKernelStatus::ok();
    } catch (const std::bad_alloc &) {
      return {WVKernelStatusCode::allocationFailure,
              "Output delivery tracking allocation failed."};
    }
  }

  WVKernelStatus prepareInterpolation() {
    if (plan.impl_->groups.empty())
      return WVKernelStatus::ok();
    try {
      const auto &layout = integrator.stateLayout();
      const auto count = layout.coefficientShape().elementCount();
      if (count > std::numeric_limits<std::size_t>::max() / 3)
        return {
            WVKernelStatusCode::sizeOverflow,
            "Integration interpolation coefficient count overflows size_t."};
      interpolationCoefficients.assign(3 * count, WVComplex64{});
      auto status = interpolationAdditional.initialize(layout);
      if (!status)
        return status;
      const auto shape = layout.coefficientShape();
      interpolationState = {
          {0.0,
           0.0,
           {{interpolationCoefficients.data(), shape},
            {interpolationCoefficients.data() + count, shape},
            {interpolationCoefficients.data() + 2 * count, shape}}},
          interpolationAdditional.mutableBlocks(),
          interpolationAdditional.blockCount()};
      interpolationConstViews.reserve(layout.additionalBlocks().size());
      sourceConstViews.reserve(layout.additionalBlocks().size());
      metrics.interpolationBufferCapacityBytes =
          interpolationCoefficients.capacity() * sizeof(WVComplex64) +
          interpolationAdditional.capacityBytes() +
          interpolationConstViews.capacity() *
              sizeof(WVAdditionalStateBlockConstView);
      metrics.interpolationBufferMaximumLiveBytes =
          metrics.interpolationBufferCapacityBytes;
      return WVKernelStatus::ok();
    } catch (const std::bad_alloc &) {
      return {WVKernelStatusCode::allocationFailure,
              "Output interpolation staging allocation failed."};
    }
  }

  WVKernelStatus selectNextEvent(double lowerBound) {
    if (hasPendingEvent)
      return WVKernelStatus::ok();
    double earliest = std::numeric_limits<double>::infinity();
    for (std::size_t index = 0; index < plan.impl_->groups.size(); ++index) {
      if (occurrenceNeedsRefresh[index]) {
        const auto &group = plan.impl_->groups[index];
        const auto &item = progress[group.progressIndex];
        WVOutputScheduleCursor cursor{item.committedOrdinal,
                                      item.scheduleCursor};
        bool available = false;
        auto status = group.schedule->peek(cursor, lowerBound, plan.finalTime(),
                                           nextOccurrences[index], available);
        if (!status)
          return status;
        if (available) {
          const auto &next = nextOccurrences[index];
          double committedTime = 0.0;
          bool hasCommittedTime = false;
          status = group.schedule->committedTime(cursor, committedTime,
                                                 hasCommittedTime);
          if (!status)
            return status;
          if (!std::isfinite(next.scheduledTime) ||
              next.scheduledTime <
                  lowerBound - timeTolerance(next.scheduledTime, lowerBound) ||
              next.scheduledTime >
                  plan.finalTime() +
                      timeTolerance(next.scheduledTime, plan.finalTime()) ||
              next.ordinal <= item.committedOrdinal ||
              next.proposedCursor.committedOrdinal != next.ordinal ||
              (hasCommittedTime && !(next.scheduledTime > committedTime)))
            return invalid("An output schedule returned a non-monotone or "
                           "incompatible occurrence.");
          auto cursorStatus = validatePortableTypedRecord(
              next.proposedCursor.values,
              {WVMaximumOutputScheduleCursorBytes, true, false});
          if (std::string_view(group.schedule->typeIdentifier()) !=
                  WVEvenlySpacedOutputScheduleType &&
              next.proposedCursor.values.schemaIdentifier.empty())
            return invalid("An algorithmic output schedule returned an empty "
                           "cursor envelope.");
          if (!next.proposedCursor.values.schemaIdentifier.empty() &&
              !cursorStatus)
            return cursorStatus;
          if (next.proposedCursor.values.encodedBytes() >
              WVMaximumOutputScheduleCursorBytes)
            return {WVKernelStatusCode::sizeOverflow,
                    "An output schedule cursor exceeds 4 KiB."};
        }
        occurrenceAvailable[index] = available ? 1 : 0;
        occurrenceNeedsRefresh[index] = 0;
      }
      if (occurrenceAvailable[index])
        earliest = std::min(earliest, nextOccurrences[index].scheduledTime);
    }
    if (!std::isfinite(earliest))
      return WVKernelStatus::ok();

    stagedRoutes.clear();
    stagedProgressIndices.clear();
    stagedProposedCursors.clear();
    stagedEventTime = earliest;
    stagedEventOrdinal = metrics.generatedEventCount++;
    for (std::size_t index = 0; index < plan.impl_->groups.size(); ++index) {
      if (!occurrenceAvailable[index] ||
          nextOccurrences[index].scheduledTime != earliest)
        continue;
      auto route = plan.impl_->groups[index].route;
      route.scheduleOrdinal = nextOccurrences[index].ordinal;
      stagedRoutes.push_back(route);
      stagedProgressIndices.push_back(plan.impl_->groups[index].progressIndex);
      stagedProposedCursors.push_back(nextOccurrences[index].proposedCursor);
      route.proposedScheduleCursor = &stagedProposedCursors.back().values;
      stagedRoutes.back() = route;
      ++metrics.generatedRouteCount;
      auto &file = metrics.files[route.fileOrdinal];
      auto &group = file.groups[route.groupOrdinal];
      ++file.scheduledDeliveryCount;
      ++group.scheduledDeliveryCount;
      WVOutputDeliveryRecord record;
      record.eventOrdinal = stagedEventOrdinal;
      record.routeOrdinal = nextRouteOrdinal++;
      record.fileOrdinal = route.fileOrdinal;
      record.groupOrdinal = route.groupOrdinal;
      record.scheduleOrdinal = route.scheduleOrdinal;
      record.scheduledTime = earliest;
      record.fileIdentifier = std::string(route.fileIdentifier);
      record.destination = std::string(route.destination);
      record.groupIdentifier = std::string(route.groupIdentifier);
      record.observerCount = route.observerCount;
      records.push_back(std::move(record));
    }
    metrics.maximumCoincidentRouteCount =
        std::max(metrics.maximumCoincidentRouteCount, stagedRoutes.size());
    metrics.routeStagingCapacityBytes =
        stagedRoutes.capacity() * sizeof(WVOutputRouteView) +
        stagedProgressIndices.capacity() * sizeof(std::size_t) +
        stagedProposedCursors.capacity() * sizeof(WVOutputScheduleCursor);
    metrics.routeStagingMaximumLiveBytes = std::max(
        metrics.routeStagingMaximumLiveBytes,
        stagedRoutes.size() * sizeof(WVOutputRouteView) +
            stagedProgressIndices.size() * sizeof(std::size_t) +
            stagedProposedCursors.size() * sizeof(WVOutputScheduleCursor));
    hasPendingEvent = true;
    nextRouteIndex = 0;
    return WVKernelStatus::ok();
  }

  void markStagedEvent(WVOutputEventKind kind) {
    stagedEventKind = kind;
    hasStagedEvent = true;
    ++metrics.outputStateEvaluationCount;
    switch (kind) {
    case WVOutputEventKind::initial:
      ++metrics.initialStateEventCount;
      break;
    case WVOutputEventKind::interpolated:
      ++metrics.interpolatedStateEvaluationCount;
      break;
    case WVOutputEventKind::acceptedEndpoint:
      ++metrics.acceptedEndpointStateEventCount;
      break;
    }
  }

  WVKernelStatus stageEventState(WVOutputEventKind kind,
                                 const WVIntegrationState &state) {
    auto status = copyIntegrationState(integrator.stateLayout(), state,
                                       interpolationState);
    if (!status)
      return status;
    markStagedEvent(kind);
    return WVKernelStatus::ok();
  }

  WVKernelStatus deliverStagedEvent(WVOutputSink &sink, bool &terminate) {
    if (!hasStagedEvent || !hasPendingEvent)
      return {WVKernelStatusCode::numericalFailure,
              "Output resume cursor has no staged event."};
    const auto state =
        integrationConstView(interpolationState, interpolationConstViews);
    WVOutputEvent event{stagedEventOrdinal,  stagedEventTime,
                        stagedEventKind,     state,
                        stagedRoutes.data(), stagedRoutes.size()};
    const std::size_t firstRecordIndex = records.size() - stagedRoutes.size();
    for (; nextRouteIndex < stagedRoutes.size(); ++nextRouteIndex) {
      const auto recordIndex = firstRecordIndex + nextRouteIndex;
      auto &record = records[recordIndex];
      record.eventKind = stagedEventKind;
      record.attempted = true;
      ++record.attemptCount;
      auto &file = metrics.files[record.fileOrdinal];
      auto &group = file.groups[record.groupOrdinal];
      ++metrics.deliveryAttemptCount;
      ++file.attemptedDeliveryCount;
      ++group.attemptedDeliveryCount;
      WVOutputDeliveryResult result;
      auto status = sink.deliver(event, stagedRoutes[nextRouteIndex], result);
      if (!status) {
        ++metrics.failureCount;
        ++file.failureCount;
        ++group.failureCount;
        ++record.failureCount;
        record.failureCode = status.code;
        record.failure = std::move(status.message);
        return {record.failureCode, record.failure};
      }
      record.committed = true;
      record.writeCount = result.writeCount;
      record.writtenBytes = result.writtenBytes;
      ++metrics.committedDeliveryCount;
      metrics.writeCount += result.writeCount;
      metrics.writtenBytes += result.writtenBytes;
      ++file.committedDeliveryCount;
      file.writeCount += result.writeCount;
      file.writtenBytes += result.writtenBytes;
      ++group.committedDeliveryCount;
      group.writeCount += result.writeCount;
      group.writtenBytes += result.writtenBytes;
      const auto progressIndex = stagedProgressIndices[nextRouteIndex];
      progress[progressIndex].committedOrdinal =
          stagedProposedCursors[nextRouteIndex].committedOrdinal;
      progress[progressIndex].scheduleCursor =
          stagedProposedCursors[nextRouteIndex].values;
      occurrenceNeedsRefresh[progressIndex] = 1;
      terminate = terminate ||
                  result.action == WVOutputDeliveryResult::Action::terminate;
    }
    hasStagedEvent = false;
    hasPendingEvent = false;
    nextRouteIndex = 0;
    return WVKernelStatus::ok();
  }
};

WVOutputDriver::WVOutputDriver(WVTimeIntegrator &integrator,
                               const WVOutputPlan &plan)
    : impl_(new Impl(integrator, plan)) {}
WVOutputDriver::~WVOutputDriver() = default;

WVKernelStatus WVOutputDriver::advanceToTime(WVMutableIntegrationState &state,
                                             double finalTime,
                                             double initialStepSize,
                                             WVOutputSink &sink) {
  if (impl_->running)
    return {WVKernelStatusCode::reentrantExecution,
            "Output orchestration is not reentrant."};
  if (impl_->completed)
    return invalid("Output orchestration has already completed.");
  if (!std::isfinite(state.waveVortex.t) || !std::isfinite(finalTime) ||
      !std::isfinite(initialStepSize) || initialStepSize <= 0.0 ||
      finalTime < state.waveVortex.t ||
      !sameTime(finalTime, impl_->plan.finalTime()))
    return invalid("Output execution must use the planned final "
                   "time and a positive initial step size.");
  if ((!impl_->started &&
       !sameTime(state.waveVortex.t, impl_->plan.initialTime())) ||
      (impl_->started &&
       !sameTime(state.waveVortex.t, impl_->acceptedStateTime)))
    return invalid("Output continuation state does not match the "
                   "planned start or retained accepted-state cursor.");
  if (!sameIntegrationStateLayout(impl_->plan.impl_->stateLayout,
                                  impl_->integrator.stateLayout()))
    return invalid("Output plan and integrator state layouts differ.");
  auto status =
      validateMutableIntegrationState(impl_->integrator.stateLayout(), state);
  if (!status)
    return status;
  if (!impl_->started) {
    status = impl_->prepareTracking();
    if (!status)
      return status;
    status = impl_->prepareInterpolation();
    if (!status)
      return status;
  }
  impl_->metrics.retainedStorageBytes = impl_->persistentBytes();

  impl_->running = true;
  struct Guard {
    Impl &impl;
    ~Guard() {
      impl.running = false;
      impl.metrics.retainedStorageBytes = impl.persistentBytes();
    }
  } guard{*impl_};
  status = sink.preflight(impl_->plan);
  if (!status)
    return status;
  if (!impl_->started) {
    impl_->started = true;
    impl_->proposedStepSize = initialStepSize;
    impl_->acceptedStateTime = state.waveVortex.t;
  }

  bool terminate = false;
  if (impl_->hasStagedEvent) {
    status = impl_->deliverStagedEvent(sink, terminate);
    if (!status)
      return status;
  }
  if (terminate) {
    impl_->completed = true;
    return WVKernelStatus::ok();
  }

  status = impl_->selectNextEvent(impl_->plan.initialTime());
  if (!status)
    return status;

  while (impl_->hasPendingEvent &&
         impl_->stagedEventTime == impl_->plan.initialTime() &&
         state.waveVortex.t == impl_->plan.initialTime()) {
    const auto initial = integrationConstView(state, impl_->sourceConstViews);
    status = impl_->stageEventState(WVOutputEventKind::initial, initial);
    if (!status)
      return status;
    status = impl_->deliverStagedEvent(sink, terminate);
    if (!status)
      return status;
    if (terminate) {
      impl_->completed = true;
      return WVKernelStatus::ok();
    }
    status = impl_->selectNextEvent(impl_->plan.initialTime());
    if (!status)
      return status;
  }

  auto processAcceptedEvents = [&](const WVAcceptedStep &accepted) {
    auto selectStatus = impl_->selectNextEvent(accepted.initialTime);
    if (!selectStatus)
      return selectStatus;
    while (impl_->hasPendingEvent &&
           impl_->stagedEventTime <=
               accepted.finalTime +
                   timeTolerance(impl_->stagedEventTime, accepted.finalTime)) {
      const double outputTime = impl_->stagedEventTime;
      if (outputTime < accepted.initialTime -
                           timeTolerance(outputTime, accepted.initialTime))
        return WVKernelStatus{
            WVKernelStatusCode::numericalFailure,
            "Retained accepted-step history does not cover the next output "
            "event."};
      if (sameTime(outputTime, accepted.finalTime)) {
        auto stageStatus = impl_->stageEventState(
            WVOutputEventKind::acceptedEndpoint, accepted.endpoint);
        if (!stageStatus)
          return stageStatus;
      } else {
        if (accepted.denseOutput == nullptr)
          return WVKernelStatus{WVKernelStatusCode::unsupportedOperation,
                                "An interior integration-state output requires "
                                "method-owned dense "
                                "output."};
        const auto start = std::chrono::steady_clock::now();
        auto stageStatus = accepted.denseOutput->evaluateState(
            outputTime, impl_->interpolationState);
        const auto stop = std::chrono::steady_clock::now();
        impl_->metrics.interpolationSeconds +=
            std::chrono::duration<double>(stop - start).count();
        if (!stageStatus)
          return stageStatus;
        impl_->markStagedEvent(WVOutputEventKind::interpolated);
      }
      auto deliveryStatus = impl_->deliverStagedEvent(sink, terminate);
      if (!deliveryStatus)
        return deliveryStatus;
      if (terminate)
        break;
      selectStatus = impl_->selectNextEvent(outputTime);
      if (!selectStatus)
        return selectStatus;
    }
    return WVKernelStatus::ok();
  };

  const auto *retainedStep = impl_->integrator.lastAcceptedStep();
  if (retainedStep != nullptr &&
      sameTime(retainedStep->finalTime, state.waveVortex.t)) {
    status = processAcceptedEvents(*retainedStep);
    if (!status)
      return status;
    if (terminate) {
      impl_->completed = true;
      return WVKernelStatus::ok();
    }
  }

  while (state.waveVortex.t < finalTime &&
         !sameTime(state.waveVortex.t, finalTime)) {
    const double use =
        std::min(impl_->proposedStepSize, finalTime - state.waveVortex.t);
    status = impl_->integrator.step(state, use);
    if (!status)
      return status;
    ++impl_->metrics.acceptedStepCount;
    impl_->proposedStepSize = impl_->integrator.nextStepSize();
    impl_->acceptedStateTime = state.waveVortex.t;
    if (!std::isfinite(impl_->proposedStepSize) ||
        impl_->proposedStepSize <= 0.0)
      return {WVKernelStatusCode::numericalFailure,
              "Integrator did not publish a finite positive next "
              "step size."};
    const auto *accepted = impl_->integrator.lastAcceptedStep();
    if (accepted == nullptr)
      return {WVKernelStatusCode::numericalFailure,
              "Integrator succeeded without an accepted-step "
              "view."};
    status = processAcceptedEvents(*accepted);
    if (!status)
      return status;
    if (terminate)
      break;
  }
  if (!terminate && impl_->hasPendingEvent)
    return {WVKernelStatusCode::numericalFailure,
            "Integration ended before the complete output plan was "
            "delivered."};
  impl_->completed = true;
  return WVKernelStatus::ok();
}

const std::vector<WVOutputGroupProgress> &
WVOutputDriver::committedProgress() const noexcept {
  return impl_->progress;
}
const std::vector<WVOutputDeliveryRecord> &
WVOutputDriver::records() const noexcept {
  return impl_->records;
}
const WVOutputDriverMetrics &WVOutputDriver::metrics() const noexcept {
  return impl_->metrics;
}
bool WVOutputDriver::hasPendingDelivery() const noexcept {
  return impl_->hasStagedEvent;
}
std::size_t WVOutputDriver::persistentBytes() const noexcept {
  return impl_->persistentBytes();
}

WVCheckpointOutputSink::WVCheckpointOutputSink(WVCheckpoint checkpointTemplate)
    : checkpoint_(std::move(checkpointTemplate)) {}

WVKernelStatus WVCheckpointOutputSink::preflight(const WVOutputPlan &plan) {
  const auto shape = plan.stateLayout().coefficientShape();
  if (checkpoint_.state.coefficients.shape.rows != shape.rows ||
      checkpoint_.state.coefficients.shape.columns != shape.columns)
    return {WVKernelStatusCode::invalidShape,
            "Checkpoint template and output plan coefficient shapes differ."};
  try {
    records_.reserve(plan.groupCount());
    preflighted_ = true;
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Checkpoint output tracking allocation failed."};
  }
}

WVKernelStatus WVCheckpointOutputSink::deliver(const WVOutputEvent &event,
                                               const WVOutputRouteView &route,
                                               WVOutputDeliveryResult &result) {
  if (!preflighted_)
    return invalid("Checkpoint output sink was not preflighted.");
  ++metrics_.receivedEventCount;
  WVCheckpointOutputRecord record;
  record.ordinal = records_.size() + 1;
  record.requestedTime = event.scheduledTime;
  record.emittedTime = event.state.waveVortex.t;
  record.eventKind = event.kind;
  record.destination = std::string(route.destination);
  auto status = stageCheckpointState(checkpoint_, event.state);
  if (!status) {
    record.failure = status.message;
    records_.push_back(std::move(record));
    return status;
  }
  const auto started = std::chrono::steady_clock::now();
  const auto written = WVCheckpointWriter::write(
      record.destination, checkpoint_, WVCheckpointCommitPolicy::createNew);
  record.writeSeconds =
      std::chrono::duration<double>(std::chrono::steady_clock::now() - started)
          .count();
  metrics_.checkpointWriteSeconds += record.writeSeconds;
  if (!written) {
    record.failure = "Checkpoint output failed at " + written.location + ": " +
                     written.message;
    records_.push_back(std::move(record));
    return {WVKernelStatusCode::unsupportedOperation, records_.back().failure};
  }
  record.committed = true;
  const auto count = checkpoint_.state.coefficients.shape.elementCount();
  ++metrics_.checkpointWriteCount;
  metrics_.copiedCoefficientBytes += 3 * count * sizeof(WVComplex64);
  result.writeCount = 1;
  result.writtenBytes = 3 * count * sizeof(WVComplex64);
  records_.push_back(std::move(record));
  return WVKernelStatus::ok();
}

std::size_t WVCheckpointOutputSink::persistentBytes() const noexcept {
  std::size_t bytes = checkpointCoefficientCapacityBytes(checkpoint_) +
                      records_.capacity() * sizeof(WVCheckpointOutputRecord);
  for (const auto &record : records_)
    bytes += record.destination.capacity() + record.failure.capacity();
  return bytes;
}

} // namespace wavevortex::runtime
