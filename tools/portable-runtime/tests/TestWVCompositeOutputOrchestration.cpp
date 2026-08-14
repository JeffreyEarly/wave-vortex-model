#include "WaveVortexRuntime/WVCompositeOutputOrchestration.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>
#include <utility>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

void require(bool condition, const std::string &message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
  }
}

WVPortableObserverRecord outputRecord(double finalTime = 1.0) {
  WVPortableObserverRecord record;
  for (const auto *identifier : {"Ap", "Am", "A0"})
    record.stateBlocks.push_back(
        {identifier, WVStateScalarType::complex64, {1, 1},
         WVToleranceKind::coefficientEnergyScaled, 0.0,
         WVStateOwnership::integratorOwned,
         WVRestartRequirement::requiredDynamicState});
  record.stateBlocks.push_back(
      {"tracerAmplitude", WVStateScalarType::real64, {2},
       WVToleranceKind::uniformAbsolute, 1e-10,
       WVStateOwnership::integratorOwned,
       WVRestartRequirement::requiredDynamicState});
  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "Wave-vortex coefficients";
  coefficients.kind = WVObserverKind::coefficients;
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  record.observers.push_back(coefficients);
  WVObserverRecord tracer;
  tracer.identifier = "sharedTracer";
  tracer.name = "Shared tracer";
  tracer.kind = WVObserverKind::tracer;
  tracer.stateBlockIdentifiers = {"tracerAmplitude"};
  record.observers.push_back(tracer);
  record.outputFiles = {
      {"alpha",
       "alpha.record",
       {{"fast", "Fast state", {0.25, 0.0, finalTime},
         {"coefficients", "sharedTracer"}, true},
        {"slow", "Slow tracer", {0.5, 0.0, finalTime},
         {"sharedTracer"}, false}}},
      {"beta",
       "beta.record",
       {{"offset", "Offset state", {0.5, 0.125, finalTime},
         {"sharedTracer", "coefficients"}, true}}}};
  return record;
}

WVPortableObserverDescriptor descriptorFrom(
    const WVPortableObserverRecord &record) {
  WVPortableObserverDescriptor descriptor;
  require(static_cast<bool>(
              WVPortableObserverDescriptor::create(record, descriptor)),
          "observer descriptor creation");
  return descriptor;
}

class LinearSystem final : public WVCompositeIntegrationSystem {
public:
  explicit LinearSystem(WVCompositeStateLayout layout)
      : layout_(std::move(layout)) {}
  const WVCompositeStateLayout &stateLayout() const noexcept override {
    return layout_;
  }
  WVKernelStatus evaluateRightHandSide(const WVCompositeState &state,
                                       WVCompositeFlux &rhs) override {
    const WVComplexConstView source[] = {
        state.waveVortex.coefficients.Ap, state.waveVortex.coefficients.Am,
        state.waveVortex.coefficients.A0};
    WVComplexView destination[] = {rhs.waveVortex.Fp, rhs.waveVortex.Fm,
                                   rhs.waveVortex.F0};
    for (std::size_t component = 0; component < 3; ++component)
      for (std::size_t index = 0;
           index < source[component].shape.elementCount(); ++index)
        destination[component].data[index] =
            {-source[component].data[index].real,
             -source[component].data[index].imag};
    for (std::size_t block = 0; block < state.additionalBlockCount; ++block) {
      const auto count = state.additionalBlocks[block].layout->elementCount;
      for (std::size_t index = 0; index < count; ++index)
        rhs.additionalBlocks[block].realData[index] =
            -2.0 * state.additionalBlocks[block].realData[index];
    }
    return WVKernelStatus::ok();
  }
  WVStateConstraintResult
  enforceStateConstraints(WVMutableCompositeState &) override {
    return {WVKernelStatus::ok(), 0, true};
  }
  double coefficientAbsoluteTolerance(std::size_t,
                                      std::size_t) const noexcept override {
    return 1e-10;
  }

private:
  WVCompositeStateLayout layout_;
};

struct StateFixture {
  WVShape2D shape{1, 1};
  std::vector<WVComplex64> coefficients{{1.0, 0.5},
                                        {0.8, -0.2},
                                        {0.3, 0.1}};
  WVAdditionalStateStorage additional;
  WVMutableCompositeState state;

  StateFixture(const WVCompositeStateLayout &layout, double time = 0.0) {
    require(static_cast<bool>(additional.initialize(layout)),
            "state storage initialization");
    state = {{time,
              0.0,
              {{coefficients.data(), shape},
               {coefficients.data() + 1, shape},
               {coefficients.data() + 2, shape}}},
             additional.mutableBlocks(),
             additional.blockCount()};
    for (std::size_t block = 0; block < state.additionalBlockCount; ++block)
      std::fill_n(state.additionalBlocks[block].realData,
                  state.additionalBlocks[block].layout->elementCount, 1.0);
  }

  std::vector<double> values() const {
    std::vector<double> result;
    for (const auto value : coefficients) {
      result.push_back(value.real);
      result.push_back(value.imag);
    }
    for (std::size_t block = 0; block < state.additionalBlockCount; ++block)
      for (std::size_t index = 0;
           index < state.additionalBlocks[block].layout->elementCount; ++index)
        result.push_back(state.additionalBlocks[block].realData[index]);
    result.push_back(state.waveVortex.t);
    return result;
  }
};

struct DeliveredRoute {
  std::size_t eventOrdinal = 0;
  std::size_t fileOrdinal = 0;
  std::size_t groupOrdinal = 0;
  WVOutputScheduleOrdinal scheduleOrdinal = 0;
  double time = 0.0;
  WVCompositeOutputEventKind kind =
      WVCompositeOutputEventKind::acceptedEndpoint;
  const WVObserverRecord *firstObserver = nullptr;
};

class RecordingSink final : public WVCompositeOutputSink {
public:
  WVKernelStatus preflight(const WVCompositeOutputPlan &plan) override {
    preflightEventCount = plan.eventCount();
    if (preflightFailure)
      return {WVKernelStatusCode::allocationFailure,
              "simulated staging allocation failure"};
    return WVKernelStatus::ok();
  }
  WVKernelStatus
  deliver(const WVCompositeOutputEvent &event,
          const WVCompositeOutputRouteView &route,
          WVCompositeOutputDeliveryResult &result) override {
    ++attempts;
    delivered.push_back(
        {event.eventOrdinal, route.fileOrdinal, route.groupOrdinal,
         route.scheduleOrdinal, event.scheduledTime, event.kind,
         route.observerCount ? route.observers[0].record : nullptr});
    if (failAtAttempt == attempts)
      return {failureCode, failureMessage};
    result.writeCount = route.observerCount;
    result.writtenBytes = route.observerCount * 16;
    if (terminateAtAttempt == attempts)
      result.action = WVCompositeOutputDeliveryResult::Action::terminate;
    return WVKernelStatus::ok();
  }

  bool preflightFailure = false;
  std::size_t failAtAttempt = std::numeric_limits<std::size_t>::max();
  std::size_t terminateAtAttempt = std::numeric_limits<std::size_t>::max();
  WVKernelStatusCode failureCode = WVKernelStatusCode::numericalFailure;
  std::string failureMessage = "simulated interruption";
  std::size_t preflightEventCount = 0;
  std::size_t attempts = 0;
  std::vector<DeliveredRoute> delivered;
};

struct Context {
  WVPortableObserverDescriptor descriptor;
  WVCompositeStateLayout layout;
  LinearSystem system;

  Context()
      : descriptor(descriptorFrom(outputRecord())),
        layout([&] {
          WVCompositeStateLayout value;
          require(static_cast<bool>(WVCompositeStateLayout::create(
                      {1, 1}, descriptor, value)),
                  "composite layout creation");
          return value;
        }()),
        system(std::move(layout)) {}
};

void testPlanningOrderingIdentityAndMetrics(Context &context) {
  WVCompositeOutputPlan plan;
  auto status = WVCompositeOutputPlan::create(context.descriptor, 0.0, 1.0,
                                              {}, plan);
  require(static_cast<bool>(status), "complete output plan");
  require(plan.metrics().fileCount == 2 && plan.metrics().groupCount == 3 &&
              plan.metrics().distinctObserverCount == 2,
          "plan inventory metrics");
  require(plan.metrics().scheduledEventCount == 7 &&
              plan.metrics().scheduledRouteCount == 10 &&
              plan.metrics().maximumCoincidentRouteCount == 2,
          "coincident/distinct schedule metrics");
  require(plan.event(0).scheduledTime == 0.0 &&
              plan.event(6).scheduledTime == 1.0,
          "inclusive schedule endpoints");
  const auto initial = plan.event(0);
  require(initial.routeCount == 2 && initial.routes[0].fileOrdinal == 0 &&
              initial.routes[0].groupOrdinal == 0 &&
              initial.routes[1].groupOrdinal == 1,
          "deterministic file/group ordering");
  const auto sharedFromFast = initial.routes[0].observers[1].record;
  const auto sharedFromSlow = initial.routes[1].observers[0].record;
  const auto sharedFromOtherFile = plan.event(1).routes[0].observers[0].record;
  require(sharedFromFast == sharedFromSlow &&
              sharedFromSlow == sharedFromOtherFile,
          "stable shared observer identity");
  require(plan.persistentBytes() == plan.metrics().retainedStorageBytes,
          "exact plan retained storage");

  auto emptyRecord = outputRecord(3.0);
  emptyRecord.outputFiles[0].groups[0].schedule.initialTime = 2.0;
  emptyRecord.outputFiles[0].groups[1].schedule.initialTime = 2.0;
  emptyRecord.outputFiles[1].groups[0].schedule.initialTime = 2.125;
  auto emptyDescriptor = descriptorFrom(emptyRecord);
  WVCompositeOutputPlan empty;
  status = WVCompositeOutputPlan::create(emptyDescriptor, 0.0, 1.0, {}, empty);
  require(static_cast<bool>(status) && empty.eventCount() == 0,
          "empty bounded schedules");
  StateFixture emptyFixture(context.system.stateLayout());
  WVCompositeFixedStepRK4 emptyIntegrator(context.system, true);
  require(static_cast<bool>(
              emptyIntegrator.prepareStateAfterRestart(emptyFixture.state)),
          "empty-schedule preparation");
  RecordingSink emptySink;
  WVCompositeOutputDriver emptyDriver(emptyIntegrator, empty);
  status = emptyDriver.advanceToTime(emptyFixture.state, 1.0, 0.2, emptySink);
  require(static_cast<bool>(status) && emptySink.attempts == 0 &&
              emptyFixture.state.waveVortex.t == 1.0,
          "empty schedules advance without deliveries");
}

void testFixedDeliveryAndExactMetrics(Context &context) {
  StateFixture fixture(context.system.stateLayout());
  WVCompositeFixedStepRK4 rk4(context.system, true);
  require(static_cast<bool>(rk4.prepareStateAfterRestart(fixture.state)),
          "fixed restart preparation");
  WVCompositeOutputPlan plan;
  require(static_cast<bool>(WVCompositeOutputPlan::create(
              context.descriptor, 0.0, 1.0, {}, plan)),
          "fixed plan");
  RecordingSink sink;
  WVCompositeOutputDriver driver(rk4, plan);
  const auto status = driver.advanceToTime(fixture.state, 1.0, 0.2, sink);
  require(static_cast<bool>(status), "fixed scheduled delivery");
  const auto &metrics = driver.metrics();
  require(metrics.acceptedStepCount == 5 &&
              metrics.outputStateEvaluationCount == 7 &&
              metrics.initialStateEventCount == 1 &&
              metrics.interpolatedStateEvaluationCount == 5 &&
              metrics.acceptedEndpointStateEventCount == 1,
          "fixed state-evaluation aggregation metrics");
  require(metrics.deliveryAttemptCount == 10 &&
              metrics.committedDeliveryCount == 10 &&
              metrics.writeCount == 17 && metrics.writtenBytes == 272 &&
              metrics.failureCount == 0,
          "exact delivery/write metrics");
  require(metrics.files[0].committedDeliveryCount == 8 &&
              metrics.files[0].groups[0].committedDeliveryCount == 5 &&
              metrics.files[0].groups[1].committedDeliveryCount == 3 &&
              metrics.files[1].groups[0].committedDeliveryCount == 2,
          "per-file/group delivery metrics");
  require(driver.records().size() == 10 &&
              std::all_of(driver.records().begin(), driver.records().end(),
                          [](const auto &record) {
                            return record.attempted && record.committed &&
                                   record.failure.empty();
                          }),
          "structured successful route records");
  require(metrics.interpolationBufferCapacityBytes > 0 &&
              metrics.interpolationBufferMaximumLiveBytes ==
                  metrics.interpolationBufferCapacityBytes &&
              metrics.retainedStorageBytes == driver.persistentBytes(),
          "bounded staging and exact retained storage");
  std::cout << "METRICS schedule_events=" << plan.metrics().scheduledEventCount
            << " schedule_routes=" << plan.metrics().scheduledRouteCount
            << " maximum_coincident_routes="
            << plan.metrics().maximumCoincidentRouteCount
            << " plan_retained_bytes=" << plan.metrics().retainedStorageBytes
            << " output_state_evaluations="
            << metrics.outputStateEvaluationCount
            << " interpolations="
            << metrics.interpolatedStateEvaluationCount
            << " deliveries=" << metrics.committedDeliveryCount
            << " writes=" << metrics.writeCount
            << " written_bytes=" << metrics.writtenBytes
            << " failures=" << metrics.failureCount
            << " interpolation_capacity_bytes="
            << metrics.interpolationBufferCapacityBytes
            << " driver_retained_bytes=" << metrics.retainedStorageBytes
            << " alpha_deliveries="
            << metrics.files[0].committedDeliveryCount
            << " alpha_fast_deliveries="
            << metrics.files[0].groups[0].committedDeliveryCount
            << " alpha_slow_deliveries="
            << metrics.files[0].groups[1].committedDeliveryCount
            << " beta_deliveries="
            << metrics.files[1].committedDeliveryCount << '\n';
}

void testSegmentedContinuation(Context &context) {
  StateFixture fixture(context.system.stateLayout());
  WVCompositeFixedStepRK4 firstIntegrator(context.system, true);
  require(static_cast<bool>(
              firstIntegrator.prepareStateAfterRestart(fixture.state)),
          "first segment preparation");
  WVCompositeOutputPlan firstPlan;
  require(static_cast<bool>(WVCompositeOutputPlan::create(
              context.descriptor, 0.0, 0.5, {}, firstPlan)),
          "first segment plan");
  RecordingSink firstSink;
  WVCompositeOutputDriver firstDriver(firstIntegrator, firstPlan);
  require(static_cast<bool>(firstDriver.advanceToTime(fixture.state, 0.5, 0.2,
                                                      firstSink)),
          "first segment delivery");

  WVCompositeOutputPlan secondPlan;
  require(static_cast<bool>(WVCompositeOutputPlan::create(
              context.descriptor, 0.5, 1.0, firstDriver.committedProgress(),
              secondPlan)),
          "second segment plan");
  require(secondPlan.eventCount() > 0 &&
              secondPlan.event(0).scheduledTime > 0.5,
          "committed boundary is not duplicated");
  bool foundAnchoredFastRoute = false;
  for (std::size_t eventIndex = 0; eventIndex < secondPlan.eventCount();
       ++eventIndex) {
    const auto event = secondPlan.event(eventIndex);
    for (std::size_t routeIndex = 0; routeIndex < event.routeCount;
         ++routeIndex)
      if (event.routes[routeIndex].fileIdentifier == "alpha" &&
          event.routes[routeIndex].groupIdentifier == "fast") {
        foundAnchoredFastRoute =
            event.routes[routeIndex].scheduleOrdinal == 3 &&
            event.scheduledTime == 0.75;
        break;
      }
    if (foundAnchoredFastRoute)
      break;
  }
  require(foundAnchoredFastRoute,
          "segment remains anchored to original lattice ordinal");
  WVCompositeFixedStepRK4 secondIntegrator(context.system, true);
  require(static_cast<bool>(
              secondIntegrator.prepareStateAfterRestart(fixture.state)),
          "second segment preparation");
  RecordingSink secondSink;
  WVCompositeOutputDriver secondDriver(secondIntegrator, secondPlan);
  require(static_cast<bool>(secondDriver.advanceToTime(
              fixture.state, 1.0, 0.2, secondSink)),
          "second segment delivery");
  require(secondDriver.committedProgress()[0].committedOrdinal == 4 &&
              secondDriver.committedProgress()[1].committedOrdinal == 2 &&
              secondDriver.committedProgress()[2].committedOrdinal == 1,
          "segmented committed progress");
}

void testPreflightAndMalformedProgress(Context &context) {
  WVCompositeOutputPlan plan;
  require(static_cast<bool>(WVCompositeOutputPlan::create(
              context.descriptor, 0.0, 1.0, {}, plan)),
          "preflight plan");
  StateFixture fixture(context.system.stateLayout());
  const auto before = fixture.values();
  WVCompositeFixedStepRK4 rk4(context.system, true);
  require(static_cast<bool>(rk4.prepareStateAfterRestart(fixture.state)),
          "allocation-failure preparation");
  RecordingSink sink;
  sink.preflightFailure = true;
  WVCompositeOutputDriver driver(rk4, plan);
  auto status = driver.advanceToTime(fixture.state, 1.0, 0.2, sink);
  require(status.code == WVKernelStatusCode::allocationFailure &&
              fixture.values() == before && rk4.metrics().acceptedStepCount == 0,
          "allocation failure occurs before state mutation");

  auto malformed = plan.initialProgress();
  malformed[0].fileIdentifier = "wrong";
  WVCompositeOutputPlan ignored;
  status = WVCompositeOutputPlan::create(context.descriptor, 0.0, 1.0,
                                         malformed, ignored);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "misnamed progress rejected");
  malformed = plan.initialProgress();
  malformed[0].committedOrdinal = 3;
  status = WVCompositeOutputPlan::create(context.descriptor, 0.0, 1.0,
                                         malformed, ignored);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "future progress rejected");
  malformed.pop_back();
  status = WVCompositeOutputPlan::create(context.descriptor, 0.0, 1.0,
                                         malformed, ignored);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "incomplete progress rejected");
}

void testTerminationInterruptionAndLaterRouteFailure(Context &context) {
  WVCompositeOutputPlan plan;
  require(static_cast<bool>(WVCompositeOutputPlan::create(
              context.descriptor, 0.0, 1.0, {}, plan)),
          "failure plan");

  StateFixture terminated(context.system.stateLayout());
  WVCompositeFixedStepRK4 terminatingIntegrator(context.system, true);
  require(static_cast<bool>(
              terminatingIntegrator.prepareStateAfterRestart(terminated.state)),
          "termination preparation");
  RecordingSink terminatingSink;
  terminatingSink.terminateAtAttempt = 1;
  WVCompositeOutputDriver terminatingDriver(terminatingIntegrator, plan);
  require(static_cast<bool>(terminatingDriver.advanceToTime(
              terminated.state, 1.0, 0.2, terminatingSink)) &&
              terminated.state.waveVortex.t == 0.0 &&
              terminatingSink.attempts == 2,
          "termination completes coincident routes then stops cleanly");

  StateFixture laterFailure(context.system.stateLayout());
  WVCompositeFixedStepRK4 laterIntegrator(context.system, true);
  require(static_cast<bool>(
              laterIntegrator.prepareStateAfterRestart(laterFailure.state)),
          "later-route failure preparation");
  RecordingSink laterSink;
  laterSink.failAtAttempt = 2;
  laterSink.failureMessage = "later route failed";
  WVCompositeOutputDriver laterDriver(laterIntegrator, plan);
  auto status = laterDriver.advanceToTime(laterFailure.state, 1.0, 0.2,
                                          laterSink);
  require(!status && laterFailure.state.waveVortex.t == 0.0 &&
              laterDriver.records()[0].committed &&
              laterDriver.records()[1].attempted &&
              !laterDriver.records()[1].committed &&
              laterDriver.records()[1].failure == "later route failed" &&
              !laterDriver.records()[2].attempted,
          "later coincident route failure records partial delivery");

  StateFixture interrupted(context.system.stateLayout());
  WVCompositeFixedStepRK4 interruptedIntegrator(context.system, true);
  require(static_cast<bool>(interruptedIntegrator.prepareStateAfterRestart(
              interrupted.state)),
          "interruption preparation");
  RecordingSink interruptedSink;
  interruptedSink.failAtAttempt = 4;
  interruptedSink.failureMessage = "interrupted";
  WVCompositeOutputDriver interruptedDriver(interruptedIntegrator, plan);
  status = interruptedDriver.advanceToTime(interrupted.state, 1.0, 0.2,
                                           interruptedSink);
  require(!status && interrupted.state.waveVortex.t == 0.4 &&
              std::abs(interrupted.coefficients[0].real -
                       std::exp(-0.4)) < 1e-5 &&
              interruptedDriver.metrics().committedDeliveryCount == 3 &&
              interruptedDriver.metrics().failureCount == 1,
          "interruption preserves the latest accepted state and partial records");
}

struct RunResult {
  std::vector<double> values;
  std::size_t accepted = 0;
  std::size_t rejected = 0;
};

RunResult fixedRun(Context &context, bool withOutput) {
  StateFixture fixture(context.system.stateLayout());
  WVCompositeFixedStepRK4 integrator(context.system, true);
  require(static_cast<bool>(integrator.prepareStateAfterRestart(fixture.state)),
          "fixed invariance preparation");
  if (withOutput) {
    WVCompositeOutputPlan plan;
    require(static_cast<bool>(WVCompositeOutputPlan::create(
                context.descriptor, 0.0, 1.0, {}, plan)),
            "fixed invariance plan");
    RecordingSink sink;
    WVCompositeOutputDriver driver(integrator, plan);
    require(static_cast<bool>(
                driver.advanceToTime(fixture.state, 1.0, 0.2, sink)),
            "fixed output invariance run");
  } else {
    require(static_cast<bool>(
                integrator.advanceToTime(fixture.state, 1.0, 0.2)),
            "fixed control run");
  }
  return {fixture.values(), integrator.metrics().acceptedStepCount,
          integrator.metrics().rejectedStepCount};
}

RunResult adaptiveRun(Context &context, bool withOutput) {
  StateFixture fixture(context.system.stateLayout());
  WVCompositeAdaptiveRK23Options options;
  options.relativeTolerance = 1e-7;
  options.absoluteToleranceScale = 1.0;
  options.maximumStepFactor = 2.0;
  WVCompositeAdaptiveRK23 integrator(context.system, options);
  require(static_cast<bool>(integrator.prepareStateAfterRestart(fixture.state)),
          "adaptive invariance preparation");
  if (withOutput) {
    WVCompositeOutputPlan plan;
    require(static_cast<bool>(WVCompositeOutputPlan::create(
                context.descriptor, 0.0, 1.0, {}, plan)),
            "adaptive invariance plan");
    RecordingSink sink;
    WVCompositeOutputDriver driver(integrator, plan);
    require(static_cast<bool>(
                driver.advanceToTime(fixture.state, 1.0, 0.5, sink)),
            "adaptive output invariance run");
  } else {
    require(static_cast<bool>(
                integrator.advanceToTime(fixture.state, 1.0, 0.5)),
            "adaptive control run");
  }
  return {fixture.values(), integrator.metrics().acceptedStepCount,
          integrator.metrics().rejectedStepCount};
}

void testSolverInvariance(Context &context) {
  const auto fixedControl = fixedRun(context, false);
  const auto fixedOutput = fixedRun(context, true);
  require(fixedControl.values == fixedOutput.values &&
              fixedControl.accepted == fixedOutput.accepted &&
              fixedControl.rejected == fixedOutput.rejected,
          "fixed RK4 output does not change steps or final state");
  const auto adaptiveControl = adaptiveRun(context, false);
  const auto adaptiveOutput = adaptiveRun(context, true);
  require(adaptiveControl.values == adaptiveOutput.values &&
              adaptiveControl.accepted == adaptiveOutput.accepted &&
              adaptiveControl.rejected == adaptiveOutput.rejected &&
              adaptiveOutput.rejected > 0,
          "adaptive RK3(2) output does not change acceptance or final state");
  std::cout << "SOLVER_METRICS fixed_accepted=" << fixedOutput.accepted
            << " fixed_rejected=" << fixedOutput.rejected
            << " adaptive_accepted=" << adaptiveOutput.accepted
            << " adaptive_rejected=" << adaptiveOutput.rejected << '\n';
}

} // namespace

int main() {
  Context context;
  testPlanningOrderingIdentityAndMetrics(context);
  testFixedDeliveryAndExactMetrics(context);
  testSegmentedContinuation(context);
  testPreflightAndMalformedProgress(context);
  testTerminationInterruptionAndLaterRouteFailure(context);
  testSolverInvariance(context);
  std::cout << "PASS: composite multi-file/multi-group output orchestration\n";
  return 0;
}
