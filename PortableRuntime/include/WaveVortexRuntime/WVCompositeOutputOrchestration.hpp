#pragma once

#include "WaveVortexRuntime/WVCompositeIntegration.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <string_view>
#include <vector>

namespace wavevortex::runtime {

using WVOutputScheduleOrdinal = std::int64_t;
inline constexpr WVOutputScheduleOrdinal WVNoCommittedOutputOrdinal = -1;

// Caller-owned continuation cursor for one named output group. Ordinals are
// anchored to the group's original initialTime + ordinal*outputInterval
// lattice, not to the start of a segmented integration.
struct WVOutputGroupProgress {
  std::string fileIdentifier;
  std::string groupIdentifier;
  WVOutputScheduleOrdinal committedOrdinal = WVNoCommittedOutputOrdinal;
};

// A shared observer identity resolved once by the output plan. The same
// record pointer is used whenever an observer is routed to several groups or
// destinations.
struct WVCompositeOutputObserverView {
  std::size_t observerOrdinal = 0;
  const WVObserverRecord *record = nullptr;
};

// Immutable route occurrence for one group on one original schedule ordinal.
// All strings and observer arrays are owned by the plan and remain valid for
// the plan's lifetime.
struct WVCompositeOutputRouteView {
  std::size_t fileOrdinal = 0;
  std::size_t groupOrdinal = 0;
  WVOutputScheduleOrdinal scheduleOrdinal = WVNoCommittedOutputOrdinal;
  std::string_view fileIdentifier;
  std::string_view destination;
  std::string_view groupIdentifier;
  std::string_view groupName;
  const WVCompositeOutputObserverView *observers = nullptr;
  std::size_t observerCount = 0;
};

struct WVCompositeOutputPlannedEventView {
  std::size_t eventOrdinal = 0;
  double scheduledTime = 0.0;
  const WVCompositeOutputRouteView *routes = nullptr;
  std::size_t routeCount = 0;
};

struct WVCompositeOutputPlanMetrics {
  std::size_t fileCount = 0;
  std::size_t groupCount = 0;
  std::size_t distinctObserverCount = 0;
  std::size_t scheduledEventCount = 0;
  std::size_t scheduledRouteCount = 0;
  std::size_t maximumCoincidentRouteCount = 0;
  std::size_t retainedStorageBytes = 0;
};

// Fully resolved, immutable multi-file/multi-group schedule. create()
// validates every route and enumerates the complete bounded integration
// window before an integrator or output sink can mutate state.
class WVCompositeOutputPlan final {
public:
  WVCompositeOutputPlan();
  ~WVCompositeOutputPlan();
  WVCompositeOutputPlan(WVCompositeOutputPlan &&) noexcept;
  WVCompositeOutputPlan &operator=(WVCompositeOutputPlan &&) noexcept;
  WVCompositeOutputPlan(const WVCompositeOutputPlan &) = delete;
  WVCompositeOutputPlan &operator=(const WVCompositeOutputPlan &) = delete;

  static WVKernelStatus
  create(const WVPortableObserverDescriptor &descriptor, double initialTime,
         double finalTime, const std::vector<WVOutputGroupProgress> &progress,
         WVCompositeOutputPlan &plan);

  double initialTime() const noexcept;
  double finalTime() const noexcept;
  std::size_t eventCount() const noexcept;
  WVCompositeOutputPlannedEventView event(std::size_t index) const noexcept;
  const std::vector<WVOutputGroupProgress> &initialProgress() const noexcept;
  const WVCompositeOutputPlanMetrics &metrics() const noexcept;
  std::size_t persistentBytes() const noexcept;

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
  friend class WVCompositeOutputDriver;
};

enum class WVCompositeOutputEventKind : std::uint8_t {
  initial,
  interpolated,
  acceptedEndpoint
};

struct WVCompositeOutputEvent {
  std::size_t eventOrdinal = 0;
  double scheduledTime = 0.0;
  WVCompositeOutputEventKind kind =
      WVCompositeOutputEventKind::acceptedEndpoint;
  WVCompositeState state;
  const WVCompositeOutputRouteView *routes = nullptr;
  std::size_t routeCount = 0;
};

struct WVCompositeOutputDeliveryResult {
  enum class Action : std::uint8_t { continueIntegration, terminate };
  Action action = Action::continueIntegration;
  std::size_t writeCount = 0;
  std::size_t writtenBytes = 0;
};

// Abstract orchestration sink. preflight() must validate all destinations and
// resources without writing output. deliver() receives immutable state and
// route views. A failed delivery must leave its route uncommitted and safe to
// retry with the same event state; a successfully returned delivery is never
// repeated by the driver. NetCDF persistence is intentionally outside this
// issue.
class WVCompositeOutputSink {
public:
  virtual ~WVCompositeOutputSink() = default;
  virtual WVKernelStatus preflight(const WVCompositeOutputPlan &plan) = 0;
  virtual WVKernelStatus
  deliver(const WVCompositeOutputEvent &event,
          const WVCompositeOutputRouteView &route,
          WVCompositeOutputDeliveryResult &result) = 0;
};

struct WVCompositeOutputDeliveryRecord {
  std::size_t eventOrdinal = 0;
  std::size_t routeOrdinal = 0;
  std::size_t fileOrdinal = 0;
  std::size_t groupOrdinal = 0;
  WVOutputScheduleOrdinal scheduleOrdinal = WVNoCommittedOutputOrdinal;
  double scheduledTime = 0.0;
  WVCompositeOutputEventKind eventKind =
      WVCompositeOutputEventKind::acceptedEndpoint;
  std::string fileIdentifier;
  std::string destination;
  std::string groupIdentifier;
  std::size_t observerCount = 0;
  std::size_t writeCount = 0;
  std::size_t writtenBytes = 0;
  std::size_t attemptCount = 0;
  std::size_t failureCount = 0;
  bool attempted = false;
  bool committed = false;
  WVKernelStatusCode failureCode = WVKernelStatusCode::success;
  std::string failure;
};

struct WVCompositeOutputGroupMetrics {
  std::string fileIdentifier;
  std::string groupIdentifier;
  std::size_t scheduledDeliveryCount = 0;
  std::size_t attemptedDeliveryCount = 0;
  std::size_t committedDeliveryCount = 0;
  std::size_t writeCount = 0;
  std::size_t writtenBytes = 0;
  std::size_t failureCount = 0;
};

struct WVCompositeOutputFileMetrics {
  std::string fileIdentifier;
  std::string destination;
  std::size_t scheduledDeliveryCount = 0;
  std::size_t attemptedDeliveryCount = 0;
  std::size_t committedDeliveryCount = 0;
  std::size_t writeCount = 0;
  std::size_t writtenBytes = 0;
  std::size_t failureCount = 0;
  std::vector<WVCompositeOutputGroupMetrics> groups;
};

struct WVCompositeOutputDriverMetrics {
  std::size_t acceptedStepCount = 0;
  std::size_t outputStateEvaluationCount = 0;
  std::size_t initialStateEventCount = 0;
  std::size_t interpolatedStateEvaluationCount = 0;
  std::size_t acceptedEndpointStateEventCount = 0;
  std::size_t deliveryAttemptCount = 0;
  std::size_t committedDeliveryCount = 0;
  std::size_t writeCount = 0;
  std::size_t writtenBytes = 0;
  std::size_t failureCount = 0;
  std::size_t interpolationBufferCapacityBytes = 0;
  std::size_t interpolationBufferMaximumLiveBytes = 0;
  std::size_t routeStagingCapacityBytes = 0;
  std::size_t routeStagingMaximumLiveBytes = 0;
  double interpolationSeconds = 0.0;
  std::size_t retainedStorageBytes = 0;
  std::vector<WVCompositeOutputFileMetrics> files;
};

// Method-neutral scheduled-output driver. Solver steps are selected without
// consulting output times. One reusable composite state is staged for every
// event, and coincident routes share that single state evaluation. If a route
// fails, the driver retains that immutable state and route cursor; calling
// advanceToTime() again replays only the failed route before integration
// continues from the later accepted state.
class WVCompositeOutputDriver final {
public:
  WVCompositeOutputDriver(WVCompositeTimeIntegrator &integrator,
                          const WVCompositeOutputPlan &plan);
  ~WVCompositeOutputDriver();
  WVCompositeOutputDriver(const WVCompositeOutputDriver &) = delete;
  WVCompositeOutputDriver &operator=(const WVCompositeOutputDriver &) = delete;

  WVKernelStatus advanceToTime(WVMutableCompositeState &state,
                               double finalTime, double initialStepSize,
                               WVCompositeOutputSink &sink);

  const std::vector<WVOutputGroupProgress> &committedProgress() const noexcept;
  const std::vector<WVCompositeOutputDeliveryRecord> &records() const noexcept;
  const WVCompositeOutputDriverMetrics &metrics() const noexcept;
  bool hasPendingDelivery() const noexcept;
  std::size_t persistentBytes() const noexcept;

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace wavevortex::runtime
