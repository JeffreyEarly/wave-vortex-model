#include "WaveVortexRuntime/WVOutputOrchestration.hpp"

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
      {"tracerAmplitude", WVStateScalarType::real64, {1, 1, 2},
       WVToleranceKind::uniformAbsolute, 1e-10,
       WVStateOwnership::integratorOwned,
       WVRestartRequirement::requiredDynamicState});
  record.stateBlocks.push_back(
      {"diagnostic", WVStateScalarType::real64, {1},
       WVToleranceKind::uniformAbsolute, 1e-10,
       WVStateOwnership::observerDerived,
       WVRestartRequirement::derivedState});
  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "Wave-vortex coefficients";
  coefficients.typeIdentifier = "WVCoefficients";
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  record.observers.push_back(coefficients);
  WVObserverRecord tracer;
  tracer.identifier = "sharedTracer";
  tracer.name = "Shared tracer";
  tracer.typeIdentifier = "WVTracer";
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

WVPortableObserverRecord singleScheduleRecord(double interval,
                                              double initialTime,
                                              double finalTime) {
  auto record = outputRecord();
  record.outputFiles = {
      {"single",
       "single.record",
       {{"group", "Single group", {interval, initialTime, finalTime},
         {"coefficients"}, true}}}};
  return record;
}

class LinearSystem final : public WVIntegrationSystem {
public:
  class ErrorPolicy final : public WVIntegrationErrorPolicy {
  public:
    explicit ErrorPolicy(const WVIntegrationStateLayout &layout)
        : layout_(layout) {}
    std::size_t componentCount() const noexcept override {
      return 3 + layout_.additionalBlocks().size();
    }
    std::size_t elementCount(std::size_t component) const noexcept override {
      return component < 3 ? layout_.coefficientShape().elementCount()
                           : layout_.additionalBlocks()[component - 3].elementCount;
    }
    double absoluteTolerance(std::size_t, std::size_t) const noexcept override {
      return 1e-10;
    }
    std::size_t persistentBytes() const noexcept override { return 0; }
  private:
    const WVIntegrationStateLayout &layout_;
  };
  explicit LinearSystem(WVIntegrationStateLayout layout)
      : layout_(std::move(layout)) {}
  const WVIntegrationStateLayout &stateLayout() const noexcept override {
    return layout_;
  }
  WVKernelStatus evaluateRightHandSide(const WVIntegrationState &state,
                                       WVIntegrationFlux &rhs) override {
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
  enforceStateConstraints(WVMutableIntegrationState &) override {
    return {WVKernelStatus::ok(), 0, true};
  }
  WVKernelStatus createErrorPolicy(
      double, std::unique_ptr<WVIntegrationErrorPolicy> &policy) const override {
    policy = std::make_unique<ErrorPolicy>(layout_);
    return WVKernelStatus::ok();
  }

private:
  WVIntegrationStateLayout layout_;
};

struct StateFixture {
  WVShape2D shape{1, 1};
  std::vector<WVComplex64> coefficients{{1.0, 0.5},
                                        {0.8, -0.2},
                                        {0.3, 0.1}};
  WVAdditionalStateStorage additional;
  WVMutableIntegrationState state;

  StateFixture(const WVIntegrationStateLayout &layout, double time = 0.0) {
    require(static_cast<bool>(additional.initialize(layout)),
            "state storage initialization");
    state = {{time,
              0.0,
              {{coefficients.data(), shape},
               {coefficients.data() + 1, shape},
               {coefficients.data() + 2, shape}}},
             additional.mutableBlocks(),
             additional.blockCount()};
    for (std::size_t block = 0; block < state.additionalBlockCount; ++block) {
      const auto &metadata = *state.additionalBlocks[block].layout;
      if (metadata.scalarType == WVStateScalarType::real64)
        std::fill_n(state.additionalBlocks[block].realData,
                    metadata.elementCount, 1.0);
      else
        std::fill_n(state.additionalBlocks[block].complexData,
                    metadata.elementCount, WVComplex64{1.0, 0.0});
    }
  }

  std::vector<double> values() const {
    std::vector<double> result;
    for (const auto value : coefficients) {
      result.push_back(value.real);
      result.push_back(value.imag);
    }
    for (std::size_t block = 0; block < state.additionalBlockCount; ++block) {
      const auto &metadata = *state.additionalBlocks[block].layout;
      for (std::size_t index = 0; index < metadata.elementCount; ++index) {
        if (metadata.scalarType == WVStateScalarType::real64)
          result.push_back(state.additionalBlocks[block].realData[index]);
        else {
          result.push_back(
              state.additionalBlocks[block].complexData[index].real);
          result.push_back(
              state.additionalBlocks[block].complexData[index].imag);
        }
      }
    }
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
  WVOutputEventKind kind =
      WVOutputEventKind::acceptedEndpoint;
  const WVObserverRecord *firstObserver = nullptr;
  double firstCoefficientReal = 0.0;
};

class RecordingSink final : public WVOutputSink {
public:
  WVKernelStatus preflight(const WVOutputPlan &plan) override {
    ++preflightAttempts;
    preflightEventCount = plan.eventCount();
    if (preflightFailure)
      return {WVKernelStatusCode::allocationFailure,
              "simulated staging allocation failure"};
    return WVKernelStatus::ok();
  }
  WVKernelStatus
  deliver(const WVOutputEvent &event,
          const WVOutputRouteView &route,
          WVOutputDeliveryResult &result) override {
    ++attempts;
    delivered.push_back(
        {event.eventOrdinal, route.fileOrdinal, route.groupOrdinal,
         route.scheduleOrdinal, event.scheduledTime, event.kind,
         route.observerCount ? route.observers[0].record : nullptr,
         event.state.waveVortex.coefficients.Ap.data[0].real});
    if (failAtAttempt == attempts)
      return {failureCode, failureMessage};
    result.writeCount = route.observerCount;
    result.writtenBytes = route.observerCount * 16;
    if (terminateAtAttempt == attempts)
      result.action = WVOutputDeliveryResult::Action::terminate;
    return WVKernelStatus::ok();
  }

  bool preflightFailure = false;
  std::size_t failAtAttempt = std::numeric_limits<std::size_t>::max();
  std::size_t terminateAtAttempt = std::numeric_limits<std::size_t>::max();
  WVKernelStatusCode failureCode = WVKernelStatusCode::numericalFailure;
  std::string failureMessage = "simulated interruption";
  std::size_t preflightEventCount = 0;
  std::size_t preflightAttempts = 0;
  std::size_t attempts = 0;
  std::vector<DeliveredRoute> delivered;
};

class ReentrantPreflightSink final : public WVOutputSink {
public:
  WVKernelStatus preflight(const WVOutputPlan &) override {
    ++preflightAttempts;
    nestedStatus =
        driver->advanceToTime(*state, finalTime, stepSize, *this);
    return WVKernelStatus::ok();
  }
  WVKernelStatus
  deliver(const WVOutputEvent &,
          const WVOutputRouteView &route,
          WVOutputDeliveryResult &result) override {
    ++deliveries;
    result.writeCount = route.observerCount;
    return WVKernelStatus::ok();
  }

  WVOutputDriver *driver = nullptr;
  WVMutableIntegrationState *state = nullptr;
  double finalTime = 0.0;
  double stepSize = 0.0;
  WVKernelStatus nestedStatus;
  std::size_t preflightAttempts = 0;
  std::size_t deliveries = 0;
};

// Test-only method proving that output orchestration depends only on the
// method-neutral integrator contract. The method intentionally leaves every
// state value unchanged while advancing accepted endpoints.
class EndpointOnlyIntegrator final : public WVTimeIntegrator {
public:
  explicit EndpointOnlyIntegrator(const WVIntegrationStateLayout &layout)
      : layout_(layout) {}
  const WVIntegrationStateLayout &stateLayout() const noexcept override {
    return layout_;
  }
  WVKernelStatus
  prepareStateAfterRestart(WVMutableIntegrationState &state) override {
    accepted_ = {};
    return validateMutableIntegrationState(layout_, state);
  }
  WVKernelStatus step(WVMutableIntegrationState &state,
                      double stepSize) override {
    auto status = validateMutableIntegrationState(layout_, state);
    if (!status)
      return status;
    if (!(stepSize > 0.0) || !std::isfinite(stepSize))
      return {WVKernelStatusCode::invalidConfiguration,
              "Endpoint-only test step must be finite and positive."};
    const double initial = state.waveVortex.t;
    state.waveVortex.t += stepSize;
    const auto endpoint = integrationConstView(state, views_);
    accepted_ = {initial,
                 state.waveVortex.t,
                 endpoint,
                 {++acceptedCount_, 0, 0, stepSize, stepSize, stepSize, 0.0},
                 nullptr};
    nextStepSize_ = stepSize;
    return WVKernelStatus::ok();
  }
  WVKernelStatus advanceToTime(WVMutableIntegrationState &state,
                               double finalTime,
                               double stepSize) override {
    while (state.waveVortex.t < finalTime) {
      const auto status = step(
          state, std::min(stepSize, finalTime - state.waveVortex.t));
      if (!status)
        return status;
    }
    return WVKernelStatus::ok();
  }
  const WVAcceptedStep *lastAcceptedStep() const noexcept override {
    return acceptedCount_ == 0 ? nullptr : &accepted_;
  }
  double nextStepSize() const noexcept override { return nextStepSize_; }
  std::size_t persistentBytes() const noexcept override { return 0; }

private:
  const WVIntegrationStateLayout &layout_;
  std::vector<WVAdditionalStateBlockConstView> views_;
  WVAcceptedStep accepted_;
  std::size_t acceptedCount_ = 0;
  double nextStepSize_ = 0.0;
};

struct Context {
  WVPortableObserverDescriptor descriptor;
  WVIntegrationStateLayout layout;
  LinearSystem system;

  Context()
      : descriptor(descriptorFrom(outputRecord())),
        layout([&] {
          WVIntegrationStateLayout value;
          require(static_cast<bool>(WVIntegrationStateLayout::create(
                      {1, 1}, descriptor, value)),
                  "integration layout creation");
          return value;
        }()),
        system(std::move(layout)) {}
};

void testPlanningOrderingIdentityAndMetrics(Context &context) {
  WVOutputPlan plan;
  auto status = WVOutputPlan::create(context.descriptor, 0.0, 1.0,
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
  WVOutputPlan empty;
  status = WVOutputPlan::create(emptyDescriptor, 0.0, 1.0, {}, empty);
  require(static_cast<bool>(status) && empty.eventCount() == 0,
          "empty bounded schedules");
  StateFixture emptyFixture(context.system.stateLayout());
  WVFixedStepRK4 emptyIntegrator(context.system, {true});
  require(static_cast<bool>(
              emptyIntegrator.prepareStateAfterRestart(emptyFixture.state)),
          "empty-schedule preparation");
  RecordingSink emptySink;
  WVOutputDriver emptyDriver(emptyIntegrator, empty);
  status = emptyDriver.advanceToTime(emptyFixture.state, 1.0, 0.2, emptySink);
  require(static_cast<bool>(status) && emptySink.attempts == 0 &&
              emptyFixture.state.waveVortex.t == 1.0,
          "empty schedules advance without deliveries");

  const double nextAfterOne =
      std::nextafter(1.0, std::numeric_limits<double>::infinity());
  auto distinctRecord = outputRecord();
  distinctRecord.outputFiles = {
      {"distinct",
       "distinct.record",
       {{"first", "First", {1.0, 1.0, 1.0}, {"coefficients"}, true},
        {"second", "Second", {1.0, nextAfterOne, nextAfterOne},
         {"sharedTracer"}, false}}}};
  auto distinctDescriptor = descriptorFrom(distinctRecord);
  WVOutputPlan distinct;
  status = WVOutputPlan::create(distinctDescriptor, 1.0,
                                         nextAfterOne, {}, distinct);
  require(static_cast<bool>(status) && distinct.eventCount() == 2 &&
              distinct.event(0).routeCount == 1 &&
              distinct.event(1).routeCount == 1,
          "distinct representable times are not tolerance-aggregated");

  const double largeAnchor = 1.0e16;
  auto largeAnchorDescriptor = descriptorFrom(
      singleScheduleRecord(1.0, largeAnchor, largeAnchor + 4.0));
  WVOutputPlan indistinguishable;
  status = WVOutputPlan::create(
      largeAnchorDescriptor, largeAnchor, largeAnchor + 4.0, {},
      indistinguishable);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "large-anchor indistinguishable ordinals are rejected");

  const double tinyInterval =
      std::numeric_limits<double>::epsilon() / 4.0;
  auto tinyDescriptor = descriptorFrom(
      singleScheduleRecord(tinyInterval, 1.0, nextAfterOne));
  status = WVOutputPlan::create(tinyDescriptor, 1.0, nextAfterOne,
                                         {}, indistinguishable);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "tiny-interval indistinguishable ordinals are rejected");
}

void testFixedDeliveryAndExactMetrics(Context &context) {
  StateFixture fixture(context.system.stateLayout());
  WVFixedStepRK4 rk4(context.system, {true});
  require(static_cast<bool>(rk4.prepareStateAfterRestart(fixture.state)),
          "fixed restart preparation");
  WVOutputPlan plan;
  require(static_cast<bool>(WVOutputPlan::create(
              context.descriptor, 0.0, 1.0, {}, plan)),
          "fixed plan");
  RecordingSink sink;
  WVOutputDriver driver(rk4, plan);
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
  WVFixedStepRK4 firstIntegrator(context.system, {true});
  require(static_cast<bool>(
              firstIntegrator.prepareStateAfterRestart(fixture.state)),
          "first segment preparation");
  WVOutputPlan firstPlan;
  require(static_cast<bool>(WVOutputPlan::create(
              context.descriptor, 0.0, 0.5, {}, firstPlan)),
          "first segment plan");
  RecordingSink firstSink;
  WVOutputDriver firstDriver(firstIntegrator, firstPlan);
  require(static_cast<bool>(firstDriver.advanceToTime(fixture.state, 0.5, 0.2,
                                                      firstSink)),
          "first segment delivery");

  WVOutputPlan secondPlan;
  require(static_cast<bool>(WVOutputPlan::create(
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
  WVFixedStepRK4 secondIntegrator(context.system, {true});
  require(static_cast<bool>(
              secondIntegrator.prepareStateAfterRestart(fixture.state)),
          "second segment preparation");
  RecordingSink secondSink;
  WVOutputDriver secondDriver(secondIntegrator, secondPlan);
  require(static_cast<bool>(secondDriver.advanceToTime(
              fixture.state, 1.0, 0.2, secondSink)),
          "second segment delivery");
  require(secondDriver.committedProgress()[0].committedOrdinal == 4 &&
              secondDriver.committedProgress()[1].committedOrdinal == 2 &&
              secondDriver.committedProgress()[2].committedOrdinal == 1,
          "segmented committed progress");
}

void testPreflightAndMalformedProgress(Context &context) {
  WVOutputPlan plan;
  require(static_cast<bool>(WVOutputPlan::create(
              context.descriptor, 0.0, 1.0, {}, plan)),
          "preflight plan");
  StateFixture fixture(context.system.stateLayout());
  const auto before = fixture.values();
  WVFixedStepRK4 rk4(context.system, {true});
  require(static_cast<bool>(rk4.prepareStateAfterRestart(fixture.state)),
          "allocation-failure preparation");
  RecordingSink sink;
  sink.preflightFailure = true;
  WVOutputDriver driver(rk4, plan);
  auto status = driver.advanceToTime(fixture.state, 1.0, 0.2, sink);
  require(status.code == WVKernelStatusCode::allocationFailure &&
              fixture.values() == before && rk4.metrics().acceptedStepCount == 0,
          "allocation failure occurs before state mutation");
  sink.preflightFailure = false;
  status = driver.advanceToTime(fixture.state, 1.0, 0.2, sink);
  require(static_cast<bool>(status) && fixture.state.waveVortex.t == 1.0 &&
              sink.preflightAttempts == 2,
          "ordinary preflight failure permits a later retry");

  auto requireDescriptorMismatch = [&](const WVPortableObserverRecord &record,
                                       const std::string &label) {
    auto mismatchDescriptor = descriptorFrom(record);
    WVIntegrationStateLayout mismatchLayout;
    require(static_cast<bool>(WVIntegrationStateLayout::create(
                {1, 1}, mismatchDescriptor, mismatchLayout)),
            label + " layout creation");
    LinearSystem mismatchSystem(std::move(mismatchLayout));
    StateFixture mismatchFixture(mismatchSystem.stateLayout());
    const auto mismatchBefore = mismatchFixture.values();
    WVFixedStepRK4 mismatchIntegrator(mismatchSystem, {true});
    require(static_cast<bool>(mismatchIntegrator.prepareStateAfterRestart(
                mismatchFixture.state)),
            label + " integrator preparation");
    RecordingSink mismatchSink;
    WVOutputDriver mismatchDriver(mismatchIntegrator, plan);
    const auto mismatchStatus = mismatchDriver.advanceToTime(
        mismatchFixture.state, 1.0, 0.2, mismatchSink);
    require(mismatchStatus.code == WVKernelStatusCode::invalidConfiguration &&
                mismatchSink.preflightAttempts == 0 &&
                mismatchIntegrator.metrics().acceptedStepCount == 0 &&
                mismatchFixture.values() == mismatchBefore,
            label + " fails before callbacks or state mutation");
  };

  auto identifierMismatch = outputRecord();
  identifierMismatch.stateBlocks[3].identifier = "otherTracerAmplitude";
  identifierMismatch.observers[1].stateBlockIdentifiers = {
      "otherTracerAmplitude"};
  requireDescriptorMismatch(identifierMismatch, "state-block identifier mismatch");

  auto orderMismatch = outputRecord();
  std::swap(orderMismatch.stateBlocks[0], orderMismatch.stateBlocks[1]);
  requireDescriptorMismatch(orderMismatch, "state-block order mismatch");

  auto typeMismatch = outputRecord();
  typeMismatch.stateBlocks[4].scalarType = WVStateScalarType::complex64;
  requireDescriptorMismatch(typeMismatch, "state-block scalar-type mismatch");

  auto dimensionMismatch = outputRecord();
  dimensionMismatch.stateBlocks[3].dimensions = {2, 1, 1};
  requireDescriptorMismatch(dimensionMismatch, "state-block dimension mismatch");

  auto observerMismatch = outputRecord();
  observerMismatch.observers[1].name = "Different observer identity";
  requireDescriptorMismatch(observerMismatch, "observer descriptor mismatch");

  StateFixture reentrantFixture(context.system.stateLayout());
  WVFixedStepRK4 reentrantIntegrator(context.system, {true});
  require(static_cast<bool>(reentrantIntegrator.prepareStateAfterRestart(
              reentrantFixture.state)),
          "reentrant-preflight preparation");
  WVOutputDriver reentrantDriver(reentrantIntegrator, plan);
  ReentrantPreflightSink reentrantSink;
  reentrantSink.driver = &reentrantDriver;
  reentrantSink.state = &reentrantFixture.state;
  reentrantSink.finalTime = 1.0;
  reentrantSink.stepSize = 0.2;
  status = reentrantDriver.advanceToTime(reentrantFixture.state, 1.0, 0.2,
                                         reentrantSink);
  require(static_cast<bool>(status) &&
              reentrantSink.nestedStatus.code ==
                  WVKernelStatusCode::reentrantExecution &&
              reentrantSink.preflightAttempts == 1 &&
              reentrantSink.deliveries == plan.metrics().scheduledRouteCount,
          "reentrant sink preflight is rejected while outer run succeeds");

  auto malformed = plan.initialProgress();
  malformed[0].fileIdentifier = "wrong";
  WVOutputPlan ignored;
  status = WVOutputPlan::create(context.descriptor, 0.0, 1.0,
                                         malformed, ignored);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "misnamed progress rejected");
  malformed = plan.initialProgress();
  malformed[0].committedOrdinal = 3;
  status = WVOutputPlan::create(context.descriptor, 0.0, 1.0,
                                         malformed, ignored);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "future progress rejected");
  malformed.pop_back();
  status = WVOutputPlan::create(context.descriptor, 0.0, 1.0,
                                         malformed, ignored);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "incomplete progress rejected");
}

void testTerminationInterruptionAndLaterRouteFailure(Context &context) {
  WVOutputPlan plan;
  require(static_cast<bool>(WVOutputPlan::create(
              context.descriptor, 0.0, 1.0, {}, plan)),
          "failure plan");

  StateFixture terminated(context.system.stateLayout());
  WVFixedStepRK4 terminatingIntegrator(context.system, {true});
  require(static_cast<bool>(
              terminatingIntegrator.prepareStateAfterRestart(terminated.state)),
          "termination preparation");
  RecordingSink terminatingSink;
  terminatingSink.terminateAtAttempt = 1;
  WVOutputDriver terminatingDriver(terminatingIntegrator, plan);
  require(static_cast<bool>(terminatingDriver.advanceToTime(
              terminated.state, 1.0, 0.2, terminatingSink)) &&
              terminated.state.waveVortex.t == 0.0 &&
              terminatingSink.attempts == 2,
          "termination completes coincident routes then stops cleanly");

  StateFixture laterFailure(context.system.stateLayout());
  WVFixedStepRK4 laterIntegrator(context.system, {true});
  require(static_cast<bool>(
              laterIntegrator.prepareStateAfterRestart(laterFailure.state)),
          "later-route failure preparation");
  RecordingSink laterSink;
  laterSink.failAtAttempt = 2;
  laterSink.failureMessage = "later route failed";
  WVOutputDriver laterDriver(laterIntegrator, plan);
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
  WVFixedStepRK4 interruptedIntegrator(context.system, {true});
  require(static_cast<bool>(interruptedIntegrator.prepareStateAfterRestart(
              interrupted.state)),
          "interruption preparation");
  RecordingSink interruptedSink;
  interruptedSink.failAtAttempt = 4;
  interruptedSink.failureMessage = "interrupted";
  WVOutputDriver interruptedDriver(interruptedIntegrator, plan);
  status = interruptedDriver.advanceToTime(interrupted.state, 1.0, 0.2,
                                           interruptedSink);
  require(!status && interrupted.state.waveVortex.t == 0.4 &&
              std::abs(interrupted.coefficients[0].real -
                       std::exp(-0.4)) < 1e-5 &&
              interruptedDriver.metrics().committedDeliveryCount == 3 &&
              interruptedDriver.metrics().failureCount == 1,
          "interruption preserves the latest accepted state and partial records");

  StateFixture resumed(context.system.stateLayout());
  WVFixedStepRK4 resumedIntegrator(context.system, {true});
  require(static_cast<bool>(
              resumedIntegrator.prepareStateAfterRestart(resumed.state)),
          "interior resume preparation");
  RecordingSink resumedSink;
  resumedSink.failAtAttempt = 6;
  resumedSink.failureMessage = "interior sibling failed";
  WVOutputDriver resumedDriver(resumedIntegrator, plan);
  status = resumedDriver.advanceToTime(resumed.state, 1.0, 0.4, resumedSink);
  require(!status && resumed.state.waveVortex.t == 0.8 &&
              resumedDriver.hasPendingDelivery() &&
              resumedDriver.records()[4].committed &&
              resumedDriver.records()[4].attemptCount == 1 &&
              !resumedDriver.records()[5].committed &&
              resumedDriver.records()[5].attemptCount == 1 &&
              resumedDriver.records()[5].failureCount == 1,
          "interior coincident failure retains event state and route cursor");
  resumedSink.failAtAttempt = std::numeric_limits<std::size_t>::max();
  status = resumedDriver.advanceToTime(resumed.state, 1.0, 0.4, resumedSink);
  require(static_cast<bool>(status) && !resumedDriver.hasPendingDelivery() &&
              resumed.state.waveVortex.t == 1.0 &&
              resumedDriver.records()[4].attemptCount == 1 &&
              resumedDriver.records()[5].committed &&
              resumedDriver.records()[5].attemptCount == 2 &&
              resumedDriver.records()[5].failureCount == 1 &&
              resumedDriver.metrics().deliveryAttemptCount == 11 &&
              resumedDriver.metrics().committedDeliveryCount == 10 &&
              resumedDriver.metrics().failureCount == 1 &&
              resumedDriver.metrics().outputStateEvaluationCount == 7 &&
              resumedDriver.metrics().interpolatedStateEvaluationCount == 5,
          "retry replays only failed route and continues without reinterpolation");
  std::size_t committedSiblingDeliveries = 0;
  std::vector<double> failedRouteValues;
  for (const auto &delivery : resumedSink.delivered) {
    if (delivery.fileOrdinal == 0 && delivery.groupOrdinal == 0 &&
        delivery.scheduleOrdinal == 2)
      ++committedSiblingDeliveries;
    if (delivery.fileOrdinal == 0 && delivery.groupOrdinal == 1 &&
        delivery.scheduleOrdinal == 1)
      failedRouteValues.push_back(delivery.firstCoefficientReal);
  }
  require(committedSiblingDeliveries == 1 && failedRouteValues.size() == 2 &&
              failedRouteValues[0] == failedRouteValues[1],
          "resume preserves exact event state without duplicating sibling");

  StateFixture resumeControl(context.system.stateLayout());
  WVFixedStepRK4 resumeControlIntegrator(context.system, {true});
  require(static_cast<bool>(resumeControlIntegrator.prepareStateAfterRestart(
              resumeControl.state)) &&
              static_cast<bool>(resumeControlIntegrator.advanceToTime(
                  resumeControl.state, 1.0, 0.4)) &&
              resumeControl.values() == resumed.values() &&
              resumeControlIntegrator.metrics().acceptedStepCount ==
                  resumedIntegrator.metrics().acceptedStepCount,
          "failed-route resume preserves accepted steps and final state");
}

struct RunResult {
  std::vector<double> values;
  std::size_t accepted = 0;
  std::size_t rejected = 0;
};

RunResult fixedRun(Context &context, bool withOutput) {
  StateFixture fixture(context.system.stateLayout());
  WVFixedStepRK4 integrator(context.system, {true});
  require(static_cast<bool>(integrator.prepareStateAfterRestart(fixture.state)),
          "fixed invariance preparation");
  if (withOutput) {
    WVOutputPlan plan;
    require(static_cast<bool>(WVOutputPlan::create(
                context.descriptor, 0.0, 1.0, {}, plan)),
            "fixed invariance plan");
    RecordingSink sink;
    WVOutputDriver driver(integrator, plan);
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
  WVAdaptiveRK23Options options;
  options.relativeTolerance = 1e-7;
  options.absoluteToleranceScale = 1.0;
  options.maximumStepFactor = 2.0;
  WVAdaptiveRK23 integrator(context.system, options);
  require(static_cast<bool>(integrator.prepareStateAfterRestart(fixture.state)),
          "adaptive invariance preparation");
  if (withOutput) {
    WVOutputPlan plan;
    require(static_cast<bool>(WVOutputPlan::create(
                context.descriptor, 0.0, 1.0, {}, plan)),
            "adaptive invariance plan");
    RecordingSink sink;
    WVOutputDriver driver(integrator, plan);
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

void testIntegratorExtensionBoundary(Context &context) {
  StateFixture fixture(context.system.stateLayout());
  const auto initialValues = fixture.values();
  EndpointOnlyIntegrator integrator(context.system.stateLayout());
  require(static_cast<bool>(integrator.prepareStateAfterRestart(fixture.state)),
          "test-only integrator preparation");
  WVOutputPlan plan;
  require(static_cast<bool>(WVOutputPlan::createExplicit(
              context.system.stateLayout(), 0.0, 0.4,
              {{0.2, "test-method-first"}, {0.4, "test-method-second"}},
              plan)),
          "test-only integrator output plan");
  RecordingSink sink;
  WVOutputDriver driver(integrator, plan);
  require(static_cast<bool>(
              driver.advanceToTime(fixture.state, 0.4, 0.2, sink)) &&
              sink.delivered.size() == 2 &&
              driver.metrics().acceptedStepCount == 2 &&
              fixture.state.additionalBlockCount != 0,
          "test-only integrator works with the unchanged output driver and "
          "additional state blocks");
  auto finalValues = fixture.values();
  require(initialValues.size() == finalValues.size() &&
              std::equal(initialValues.begin(), initialValues.end() - 1,
                         finalValues.begin()),
          "test-only integrator preserves all coefficient and observer state");
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
  testIntegratorExtensionBoundary(context);
  std::cout << "PASS: unified multi-file/multi-group output orchestration\n";
  return 0;
}
