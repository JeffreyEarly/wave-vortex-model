#include "WaveVortexRuntime/WVCompositeOutputOrchestration.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <limits>
#include <map>
#include <new>
#include <set>
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
  std::size_t bytes = stringBytes(observer.identifier) +
                      stringBytes(observer.name) +
                      observer.stateBlockIdentifiers.capacity() *
                          sizeof(std::string) +
                      observer.fieldNames.capacity() * sizeof(std::string) +
                      (observer.x.capacity() + observer.y.capacity() +
                       observer.z.capacity()) *
                          sizeof(double);
  for (const auto &value : observer.stateBlockIdentifiers)
    bytes += stringBytes(value);
  for (const auto &value : observer.fieldNames)
    bytes += stringBytes(value);
  return bytes;
}

WVKernelStatus ordinalAtOrAfter(double anchor, double interval, double bound,
                                WVOutputScheduleOrdinal &ordinal) {
  const long double ratio =
      (static_cast<long double>(bound) - static_cast<long double>(anchor)) /
      static_cast<long double>(interval);
  const long double allowance =
      static_cast<long double>(timeTolerance(anchor, bound) / interval);
  const long double candidate = std::ceil(ratio - allowance);
  if (candidate >
      static_cast<long double>(
          std::numeric_limits<WVOutputScheduleOrdinal>::max()))
    return {WVKernelStatusCode::sizeOverflow,
            "Output schedule ordinal exceeds int64 capacity."};
  ordinal = candidate <= 0.0L
                ? 0
                : static_cast<WVOutputScheduleOrdinal>(candidate);
  return WVKernelStatus::ok();
}

WVKernelStatus ordinalAtOrBefore(double anchor, double interval, double bound,
                                 WVOutputScheduleOrdinal &ordinal) {
  const long double ratio =
      (static_cast<long double>(bound) - static_cast<long double>(anchor)) /
      static_cast<long double>(interval);
  const long double allowance =
      static_cast<long double>(timeTolerance(anchor, bound) / interval);
  const long double candidate = std::floor(ratio + allowance);
  if (candidate >
      static_cast<long double>(
          std::numeric_limits<WVOutputScheduleOrdinal>::max()))
    return {WVKernelStatusCode::sizeOverflow,
            "Output schedule ordinal exceeds int64 capacity."};
  ordinal = candidate < 0.0L
                ? WVNoCommittedOutputOrdinal
                : static_cast<WVOutputScheduleOrdinal>(candidate);
  return WVKernelStatus::ok();
}

double scheduledTime(double anchor, double interval,
                     WVOutputScheduleOrdinal ordinal) noexcept {
  return std::fma(static_cast<double>(ordinal), interval, anchor);
}

bool matchingInterval(double firstInitial, double firstFinal,
                      double secondInitial, double secondFinal) noexcept {
  return sameTime(firstInitial, secondInitial) &&
         sameTime(firstFinal, secondFinal);
}

} // namespace

class WVCompositeOutputPlan::Impl {
public:
  struct Group {
    std::size_t fileOrdinal = 0;
    std::size_t groupOrdinal = 0;
    std::size_t progressIndex = 0;
    const WVOutputFileRecord *file = nullptr;
    const WVOutputGroupRecord *group = nullptr;
    std::vector<WVCompositeOutputObserverView> observers;
  };

  struct Event {
    double scheduledTime = 0.0;
    std::size_t firstRouteOrdinal = 0;
    std::vector<WVCompositeOutputRouteView> routes;
    std::vector<std::size_t> progressIndices;
  };

  WVPortableObserverRecord record;
  double initialTime = 0.0;
  double finalTime = 0.0;
  std::vector<Group> groups;
  std::vector<Event> events;
  std::vector<WVOutputGroupProgress> progress;
  WVCompositeOutputPlanMetrics metrics;

  std::size_t persistentBytes() const noexcept {
    std::size_t bytes = stringBytes(record.schemaIdentifier) +
                        record.stateBlocks.capacity() *
                            sizeof(WVStateBlockRecord) +
                        record.observers.capacity() * sizeof(WVObserverRecord) +
                        record.outputFiles.capacity() *
                            sizeof(WVOutputFileRecord) +
                        groups.capacity() * sizeof(Group) +
                        events.capacity() * sizeof(Event) +
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
                 group.observerIdentifiers.capacity() * sizeof(std::string);
        for (const auto &identifier : group.observerIdentifiers)
          bytes += stringBytes(identifier);
      }
    }
    for (const auto &group : groups)
      bytes += group.observers.capacity() *
               sizeof(WVCompositeOutputObserverView);
    for (const auto &event : events)
      bytes += event.routes.capacity() * sizeof(WVCompositeOutputRouteView) +
               event.progressIndices.capacity() * sizeof(std::size_t);
    for (const auto &item : progress)
      bytes += stringBytes(item.fileIdentifier) +
               stringBytes(item.groupIdentifier);
    return bytes;
  }
};

WVCompositeOutputPlan::WVCompositeOutputPlan() : impl_(new Impl) {}
WVCompositeOutputPlan::~WVCompositeOutputPlan() = default;
WVCompositeOutputPlan::WVCompositeOutputPlan(WVCompositeOutputPlan &&) noexcept =
    default;
WVCompositeOutputPlan &
WVCompositeOutputPlan::operator=(WVCompositeOutputPlan &&) noexcept = default;

WVKernelStatus WVCompositeOutputPlan::create(
    const WVPortableObserverDescriptor &descriptor, double initialTime,
    double finalTime, const std::vector<WVOutputGroupProgress> &suppliedProgress,
    WVCompositeOutputPlan &plan) {
  if (!std::isfinite(initialTime) || !std::isfinite(finalTime) ||
      finalTime < initialTime)
    return invalid("Composite output planning requires a finite, nondecreasing "
                   "integration interval.");
  try {
    auto candidate = std::make_unique<Impl>();
    candidate->record = descriptor.record();
    candidate->initialTime = initialTime;
    candidate->finalTime = finalTime;
    candidate->metrics.fileCount = candidate->record.outputFiles.size();
    candidate->metrics.distinctObserverCount =
        candidate->record.observers.size();

    std::size_t groupCount = 0;
    for (const auto &file : candidate->record.outputFiles) {
      if (groupCount > std::numeric_limits<std::size_t>::max() -
                           file.groups.size())
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
        const auto &schedule = group.schedule;
        if (!std::isfinite(schedule.initialTime) ||
            !std::isfinite(schedule.outputInterval) ||
            schedule.outputInterval <= 0.0 ||
            std::isnan(schedule.finalTime) ||
            schedule.finalTime < schedule.initialTime)
          return invalid("Output planning requires a finite lattice anchor, a "
                         "positive finite interval, and a valid inclusive "
                         "group window.");

        WVOutputGroupProgress cursor{file.identifier, group.identifier,
                                     WVNoCommittedOutputOrdinal};
        if (!suppliedProgress.empty()) {
          cursor = suppliedProgress[progressIndex];
          if (cursor.fileIdentifier != file.identifier ||
              cursor.groupIdentifier != group.identifier ||
              cursor.committedOrdinal < WVNoCommittedOutputOrdinal)
            return invalid("Committed output progress does not match the "
                           "deterministic file/group order or ordinal range.");
          if (cursor.committedOrdinal >= 0) {
            const double committedTime =
                scheduledTime(schedule.initialTime, schedule.outputInterval,
                              cursor.committedOrdinal);
            if (!std::isfinite(committedTime) ||
                committedTime > initialTime +
                                    timeTolerance(committedTime, initialTime) ||
                committedTime > schedule.finalTime +
                                    timeTolerance(committedTime,
                                                  schedule.finalTime))
              return invalid("Committed output progress lies beyond the "
                             "segment start or group schedule.");
          }
        }
        candidate->progress.push_back(cursor);
        Impl::Group resolved;
        resolved.fileOrdinal = fileIndex;
        resolved.groupOrdinal = groupIndex;
        resolved.progressIndex = progressIndex;
        resolved.file = &file;
        resolved.group = &group;
        resolved.observers.reserve(group.observerIdentifiers.size());
        for (const auto &identifier : group.observerIdentifiers) {
          const auto found = observerOrdinals.find(identifier);
          if (found == observerOrdinals.end())
            return invalid("Output route references an unresolved observer: " +
                           identifier);
          resolved.observers.push_back(
              {found->second, &candidate->record.observers[found->second]});
        }
        candidate->groups.push_back(std::move(resolved));
      }
    }

    struct Occurrence {
      double time = 0.0;
      std::size_t groupIndex = 0;
      WVOutputScheduleOrdinal scheduleOrdinal = 0;
    };
    std::vector<Occurrence> occurrences;
    for (std::size_t groupIndex = 0; groupIndex < candidate->groups.size();
         ++groupIndex) {
      const auto &resolved = candidate->groups[groupIndex];
      const auto &schedule = resolved.group->schedule;
      const double lowerBound =
          std::max(initialTime, schedule.initialTime);
      const double upperBound = std::min(finalTime, schedule.finalTime);
      if (upperBound + timeTolerance(lowerBound, upperBound) < lowerBound)
        continue;
      WVOutputScheduleOrdinal first = 0, last = WVNoCommittedOutputOrdinal;
      auto status = ordinalAtOrAfter(schedule.initialTime,
                                     schedule.outputInterval, lowerBound, first);
      if (!status)
        return status;
      status = ordinalAtOrBefore(schedule.initialTime,
                                 schedule.outputInterval, upperBound, last);
      if (!status)
        return status;
      if (resolved.progressIndex < candidate->progress.size() &&
          candidate->progress[resolved.progressIndex].committedOrdinal >= first)
        first = candidate->progress[resolved.progressIndex].committedOrdinal + 1;
      if (last < first)
        continue;
      const auto count = static_cast<std::uint64_t>(last - first) + 1U;
      if (count > std::numeric_limits<std::size_t>::max() -
                      occurrences.size())
        return {WVKernelStatusCode::sizeOverflow,
                "Complete output schedule exceeds addressable storage."};
      occurrences.reserve(occurrences.size() +
                          static_cast<std::size_t>(count));
      for (auto ordinal = first;; ++ordinal) {
        const double time = scheduledTime(schedule.initialTime,
                                          schedule.outputInterval, ordinal);
        if (!std::isfinite(time))
          return {WVKernelStatusCode::sizeOverflow,
                  "Output schedule time overflowed finite precision."};
        occurrences.push_back({time, groupIndex, ordinal});
        if (ordinal == last)
          break;
      }
    }

    std::stable_sort(occurrences.begin(), occurrences.end(),
                     [](const auto &first, const auto &second) {
                       return first.time < second.time;
                     });
    candidate->events.reserve(occurrences.size());
    for (std::size_t index = 0; index < occurrences.size();) {
      std::size_t end = index + 1;
      while (end < occurrences.size() &&
             sameTime(occurrences[index].time, occurrences[end].time))
        ++end;
      std::stable_sort(occurrences.begin() + static_cast<std::ptrdiff_t>(index),
                       occurrences.begin() + static_cast<std::ptrdiff_t>(end),
                       [&](const auto &first, const auto &second) {
                         const auto &a = candidate->groups[first.groupIndex];
                         const auto &b = candidate->groups[second.groupIndex];
                         return a.fileOrdinal < b.fileOrdinal ||
                                (a.fileOrdinal == b.fileOrdinal &&
                                 a.groupOrdinal < b.groupOrdinal);
                       });
      Impl::Event event;
      event.scheduledTime = occurrences[index].time;
      event.firstRouteOrdinal = candidate->metrics.scheduledRouteCount;
      event.routes.reserve(end - index);
      event.progressIndices.reserve(end - index);
      for (std::size_t routeIndex = index; routeIndex < end; ++routeIndex) {
        const auto &occurrence = occurrences[routeIndex];
        const auto &resolved = candidate->groups[occurrence.groupIndex];
        event.routes.push_back(
            {resolved.fileOrdinal,
             resolved.groupOrdinal,
             occurrence.scheduleOrdinal,
             resolved.file->identifier,
             resolved.file->destination,
             resolved.group->identifier,
             resolved.group->name,
             resolved.observers.data(),
             resolved.observers.size()});
        event.progressIndices.push_back(resolved.progressIndex);
      }
      candidate->metrics.maximumCoincidentRouteCount =
          std::max(candidate->metrics.maximumCoincidentRouteCount,
                   event.routes.size());
      candidate->metrics.scheduledRouteCount += event.routes.size();
      candidate->events.push_back(std::move(event));
      index = end;
    }
    candidate->metrics.scheduledEventCount = candidate->events.size();
    candidate->metrics.scheduledRouteCount = occurrences.size();
    candidate->metrics.retainedStorageBytes = candidate->persistentBytes();
    plan.impl_ = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Composite output planning allocation failed."};
  }
}

double WVCompositeOutputPlan::initialTime() const noexcept {
  return impl_->initialTime;
}
double WVCompositeOutputPlan::finalTime() const noexcept {
  return impl_->finalTime;
}
std::size_t WVCompositeOutputPlan::eventCount() const noexcept {
  return impl_->events.size();
}
WVCompositeOutputPlannedEventView
WVCompositeOutputPlan::event(std::size_t index) const noexcept {
  if (index >= impl_->events.size())
    return {};
  const auto &value = impl_->events[index];
  return {index, value.scheduledTime, value.routes.data(),
          value.routes.size()};
}
const std::vector<WVOutputGroupProgress> &
WVCompositeOutputPlan::initialProgress() const noexcept {
  return impl_->progress;
}
const WVCompositeOutputPlanMetrics &
WVCompositeOutputPlan::metrics() const noexcept {
  return impl_->metrics;
}
std::size_t WVCompositeOutputPlan::persistentBytes() const noexcept {
  return impl_->persistentBytes();
}

class WVCompositeOutputDriver::Impl {
public:
  Impl(WVCompositeTimeIntegrator &integrator,
       const WVCompositeOutputPlan &plan)
      : integrator(integrator), plan(plan) {}

  WVCompositeTimeIntegrator &integrator;
  const WVCompositeOutputPlan &plan;
  std::vector<WVComplex64> interpolationCoefficients;
  WVAdditionalStateStorage interpolationAdditional;
  WVMutableCompositeState interpolationState;
  std::vector<WVAdditionalStateBlockConstView> interpolationConstViews;
  std::vector<WVAdditionalStateBlockConstView> acceptedConstViews;
  std::vector<WVOutputGroupProgress> progress;
  std::vector<WVCompositeOutputDeliveryRecord> records;
  WVCompositeOutputDriverMetrics metrics;
  bool running = false;
  bool hasRun = false;

  std::size_t persistentBytes() const noexcept {
    std::size_t bytes =
        interpolationCoefficients.capacity() * sizeof(WVComplex64) +
        interpolationAdditional.capacityBytes() +
        interpolationConstViews.capacity() *
            sizeof(WVAdditionalStateBlockConstView) +
        acceptedConstViews.capacity() *
            sizeof(WVAdditionalStateBlockConstView) +
        progress.capacity() * sizeof(WVOutputGroupProgress) +
        records.capacity() * sizeof(WVCompositeOutputDeliveryRecord) +
        metrics.files.capacity() * sizeof(WVCompositeOutputFileMetrics);
    for (const auto &item : progress)
      bytes += stringBytes(item.fileIdentifier) +
               stringBytes(item.groupIdentifier);
    for (const auto &record : records)
      bytes += stringBytes(record.fileIdentifier) +
               stringBytes(record.destination) +
               stringBytes(record.groupIdentifier) +
               stringBytes(record.failure);
    for (const auto &file : metrics.files) {
      bytes += stringBytes(file.fileIdentifier) + stringBytes(file.destination) +
               file.groups.capacity() * sizeof(WVCompositeOutputGroupMetrics);
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
        WVCompositeOutputFileMetrics fileMetrics;
        fileMetrics.fileIdentifier = file.identifier;
        fileMetrics.destination = file.destination;
        fileMetrics.groups.reserve(file.groups.size());
        for (const auto &group : file.groups)
          fileMetrics.groups.push_back(
              {file.identifier, group.identifier, 0, 0, 0, 0, 0, 0});
        metrics.files.push_back(std::move(fileMetrics));
      }
      records.clear();
      records.reserve(plan.impl_->metrics.scheduledRouteCount);
      std::size_t routeOrdinal = 0;
      for (std::size_t eventIndex = 0; eventIndex < plan.impl_->events.size();
           ++eventIndex) {
        const auto &event = plan.impl_->events[eventIndex];
        for (const auto &route : event.routes) {
          records.push_back({eventIndex,
                             routeOrdinal++,
                             route.fileOrdinal,
                             route.groupOrdinal,
                             route.scheduleOrdinal,
                             event.scheduledTime,
                             WVCompositeOutputEventKind::acceptedEndpoint,
                             std::string(route.fileIdentifier),
                             std::string(route.destination),
                             std::string(route.groupIdentifier),
                             route.observerCount,
                             0,
                             0,
                             false,
                             false,
                             WVKernelStatusCode::success,
                             {}});
          auto &file = metrics.files[route.fileOrdinal];
          auto &group = file.groups[route.groupOrdinal];
          ++file.scheduledDeliveryCount;
          ++group.scheduledDeliveryCount;
        }
      }
      return WVKernelStatus::ok();
    } catch (const std::bad_alloc &) {
      return {WVKernelStatusCode::allocationFailure,
              "Composite output delivery tracking allocation failed."};
    }
  }

  WVKernelStatus prepareInterpolation() {
    if (plan.impl_->events.empty())
      return WVKernelStatus::ok();
    try {
      const auto &layout = integrator.stateLayout();
      const auto count = layout.coefficientShape().elementCount();
      if (count > std::numeric_limits<std::size_t>::max() / 3)
        return {WVKernelStatusCode::sizeOverflow,
                "Composite interpolation coefficient count overflows size_t."};
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
      acceptedConstViews.reserve(layout.additionalBlocks().size());
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
              "Composite output interpolation staging allocation failed."};
    }
  }

  WVKernelStatus deliverEvent(std::size_t eventIndex,
                              WVCompositeOutputEventKind kind,
                              const WVCompositeState &state,
                              WVCompositeOutputSink &sink,
                              bool &terminate) {
    const auto &planned = plan.impl_->events[eventIndex];
    WVCompositeOutputEvent event{eventIndex, planned.scheduledTime, kind, state,
                                 planned.routes.data(), planned.routes.size()};
    ++metrics.outputStateEvaluationCount;
    switch (kind) {
    case WVCompositeOutputEventKind::initial:
      ++metrics.initialStateEventCount;
      break;
    case WVCompositeOutputEventKind::interpolated:
      ++metrics.interpolatedStateEvaluationCount;
      break;
    case WVCompositeOutputEventKind::acceptedEndpoint:
      ++metrics.acceptedEndpointStateEventCount;
      break;
    }
    std::size_t recordIndex = planned.firstRouteOrdinal;
    for (std::size_t routeIndex = 0; routeIndex < planned.routes.size();
         ++routeIndex, ++recordIndex) {
      auto &record = records[recordIndex];
      record.eventKind = kind;
      record.attempted = true;
      auto &file = metrics.files[record.fileOrdinal];
      auto &group = file.groups[record.groupOrdinal];
      ++metrics.deliveryAttemptCount;
      ++file.attemptedDeliveryCount;
      ++group.attemptedDeliveryCount;
      WVCompositeOutputDeliveryResult result;
      auto status = sink.deliver(event, planned.routes[routeIndex], result);
      if (!status) {
        ++metrics.failureCount;
        ++file.failureCount;
        ++group.failureCount;
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
      const auto progressIndex = planned.progressIndices[routeIndex];
      progress[progressIndex].committedOrdinal =
          planned.routes[routeIndex].scheduleOrdinal;
      terminate = terminate ||
                  result.action ==
                      WVCompositeOutputDeliveryResult::Action::terminate;
    }
    return WVKernelStatus::ok();
  }
};

WVCompositeOutputDriver::WVCompositeOutputDriver(
    WVCompositeTimeIntegrator &integrator, const WVCompositeOutputPlan &plan)
    : impl_(new Impl(integrator, plan)) {}
WVCompositeOutputDriver::~WVCompositeOutputDriver() = default;

WVKernelStatus WVCompositeOutputDriver::advanceToTime(
    WVMutableCompositeState &state, double finalTime, double initialStepSize,
    WVCompositeOutputSink &sink) {
  if (impl_->running)
    return {WVKernelStatusCode::reentrantExecution,
            "Composite output orchestration is not reentrant."};
  if (impl_->hasRun)
    return invalid("A composite output driver is single-use; create a new plan "
                   "with its committed progress for continuation.");
  if (!std::isfinite(state.waveVortex.t) || !std::isfinite(finalTime) ||
      !std::isfinite(initialStepSize) || initialStepSize <= 0.0 ||
      finalTime < state.waveVortex.t ||
      !matchingInterval(state.waveVortex.t, finalTime,
                        impl_->plan.initialTime(), impl_->plan.finalTime()))
    return invalid("Composite output execution must match its finite planned "
                   "interval and use a positive initial step size.");
  auto status =
      validateMutableCompositeState(impl_->integrator.stateLayout(), state);
  if (!status)
    return status;
  status = impl_->prepareTracking();
  if (!status)
    return status;
  status = impl_->prepareInterpolation();
  if (!status)
    return status;
  impl_->metrics.retainedStorageBytes = impl_->persistentBytes();
  status = sink.preflight(impl_->plan);
  if (!status)
    return status;

  impl_->running = true;
  impl_->hasRun = true;
  struct Guard {
    Impl &impl;
    ~Guard() {
      impl.running = false;
      impl.metrics.retainedStorageBytes = impl.persistentBytes();
    }
  } guard{*impl_};

  std::size_t eventIndex = 0;
  bool terminate = false;
  while (eventIndex < impl_->plan.impl_->events.size() &&
         sameTime(impl_->plan.impl_->events[eventIndex].scheduledTime,
                  state.waveVortex.t)) {
    const auto initial = compositeConstView(state, impl_->acceptedConstViews);
    status = impl_->deliverEvent(eventIndex,
                                 WVCompositeOutputEventKind::initial, initial,
                                 sink, terminate);
    if (!status)
      return status;
    ++eventIndex;
  }
  if (terminate) {
    impl_->metrics.retainedStorageBytes = impl_->persistentBytes();
    return WVKernelStatus::ok();
  }

  double proposedStepSize = initialStepSize;
  while (state.waveVortex.t < finalTime &&
         !sameTime(state.waveVortex.t, finalTime)) {
    const double use = std::min(proposedStepSize,
                                finalTime - state.waveVortex.t);
    status = impl_->integrator.step(state, use);
    if (!status)
      return status;
    ++impl_->metrics.acceptedStepCount;
    proposedStepSize = impl_->integrator.nextStepSize();
    if (!std::isfinite(proposedStepSize) || proposedStepSize <= 0.0)
      return {WVKernelStatusCode::numericalFailure,
              "Composite integrator did not publish a finite positive next "
              "step size."};
    const auto *accepted = impl_->integrator.lastAcceptedStep();
    if (accepted == nullptr)
      return {WVKernelStatusCode::numericalFailure,
              "Composite integrator succeeded without an accepted-step "
              "view."};
    while (eventIndex < impl_->plan.impl_->events.size() &&
           impl_->plan.impl_->events[eventIndex].scheduledTime <=
               accepted->finalTime +
                   timeTolerance(
                       impl_->plan.impl_->events[eventIndex].scheduledTime,
                       accepted->finalTime)) {
      const double outputTime =
          impl_->plan.impl_->events[eventIndex].scheduledTime;
      WVCompositeOutputEventKind kind =
          WVCompositeOutputEventKind::acceptedEndpoint;
      WVCompositeState outputState = accepted->endpoint;
      if (!sameTime(outputTime, accepted->finalTime)) {
        if (accepted->denseOutput == nullptr)
          return {WVKernelStatusCode::unsupportedOperation,
                  "An interior composite output requires method-owned dense "
                  "output."};
        const auto start = std::chrono::steady_clock::now();
        status = accepted->denseOutput->evaluateState(
            outputTime, impl_->interpolationState);
        const auto stop = std::chrono::steady_clock::now();
        impl_->metrics.interpolationSeconds +=
            std::chrono::duration<double>(stop - start).count();
        if (!status)
          return status;
        kind = WVCompositeOutputEventKind::interpolated;
        outputState = compositeConstView(impl_->interpolationState,
                                         impl_->interpolationConstViews);
      }
      status = impl_->deliverEvent(eventIndex, kind, outputState, sink,
                                   terminate);
      if (!status)
        return status;
      ++eventIndex;
      if (terminate)
        break;
    }
    if (terminate)
      break;
  }
  if (!terminate && eventIndex != impl_->plan.impl_->events.size())
    return {WVKernelStatusCode::numericalFailure,
            "Composite integration ended before the complete output plan was "
            "delivered."};
  impl_->metrics.retainedStorageBytes = impl_->persistentBytes();
  return WVKernelStatus::ok();
}

const std::vector<WVOutputGroupProgress> &
WVCompositeOutputDriver::committedProgress() const noexcept {
  return impl_->progress;
}
const std::vector<WVCompositeOutputDeliveryRecord> &
WVCompositeOutputDriver::records() const noexcept {
  return impl_->records;
}
const WVCompositeOutputDriverMetrics &
WVCompositeOutputDriver::metrics() const noexcept {
  return impl_->metrics;
}
std::size_t WVCompositeOutputDriver::persistentBytes() const noexcept {
  return impl_->persistentBytes();
}

} // namespace wavevortex::runtime
