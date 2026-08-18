#include "WaveVortexRuntime/WVRungeKutta.hpp"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>
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

WVPortableObserverRecord record() {
  WVPortableObserverRecord result;
  const std::vector<std::size_t> coefficientShape{2, 3};
  for (const auto *identifier : {"Ap", "Am", "A0"})
    result.stateBlocks.push_back({identifier, WVStateScalarType::complex64,
                                  coefficientShape,
                                  WVToleranceKind::coefficientEnergyScaled, 0.0,
                                  WVStateOwnership::integratorOwned,
                                  WVRestartRequirement::requiredDynamicState});
  result.stateBlocks.push_back({"particleX",
                                WVStateScalarType::real64,
                                {3},
                                WVToleranceKind::uniformAbsolute,
                                1e-10,
                                WVStateOwnership::integratorOwned,
                                WVRestartRequirement::requiredDynamicState});
  result.stateBlocks.push_back({"particleY",
                                WVStateScalarType::real64,
                                {3},
                                WVToleranceKind::uniformAbsolute,
                                1e-10,
                                WVStateOwnership::integratorOwned,
                                WVRestartRequirement::requiredDynamicState});
  result.stateBlocks.push_back({"tracerAmplitude",
                                WVStateScalarType::real64,
                                {1, 2, 2},
                                WVToleranceKind::uniformAbsolute,
                                1e-10,
                                WVStateOwnership::integratorOwned,
                                WVRestartRequirement::requiredDynamicState});
  result.stateBlocks.push_back({"complexAuxiliary",
                                WVStateScalarType::complex64,
                                {2, 2},
                                WVToleranceKind::uniformAbsolute,
                                1e-10,
                                WVStateOwnership::observerDerived,
                                WVRestartRequirement::derivedState});
  result.stateBlocks.push_back({"sampledVelocity",
                                WVStateScalarType::real64,
                                {3, 2},
                                WVToleranceKind::uniformAbsolute,
                                1e-10,
                                WVStateOwnership::observerDerived,
                                WVRestartRequirement::derivedState});
  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "Wave-vortex coefficients";
  coefficients.typeIdentifier = "WVCoefficients";
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  result.observers.push_back(coefficients);
  WVObserverRecord particles;
  particles.identifier = "particles";
  particles.name = "Particles";
  particles.typeIdentifier = "WVLagrangianParticles";
  particles.stateBlockIdentifiers = {"particleX", "particleY"};
  particles.x = {0, 1, 2};
  particles.y = {3, 4, 5};
  particles.isXYOnly = true;
  particles.horizontalAbsoluteTolerance = 1e-8;
  result.observers.push_back(particles);
  WVObserverRecord tracer;
  tracer.identifier = "tracer";
  tracer.name = "Tracer";
  tracer.typeIdentifier = "WVTracer";
  tracer.stateBlockIdentifiers = {"tracerAmplitude"};
  result.observers.push_back(tracer);
  result.outputFiles.push_back({"history",
                                "history.nc",
                                {{"state",
                                  "State",
                                  {1.0, 0.0, 10.0},
                                  {"coefficients", "particles", "tracer"},
                                  true}}});
  return result;
}

class LinearIntegrationSystem final : public WVIntegrationSystem {
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
  explicit LinearIntegrationSystem(WVIntegrationStateLayout layout,
                                   bool zeroDerivative = false)
      : layout_(std::move(layout)), zeroDerivative_(zeroDerivative) {}
  const WVIntegrationStateLayout &stateLayout() const noexcept override {
    return layout_;
  }
  WVKernelStatus evaluateRightHandSide(const WVIntegrationState &state,
                                       WVIntegrationFlux &rhs) override {
    if (rhs.additionalBlockCount != state.additionalBlockCount)
      return {WVKernelStatusCode::invalidShape, "RHS layout mismatch."};
    const WVComplexConstView source[] = {state.waveVortex.coefficients.Ap,
                                         state.waveVortex.coefficients.Am,
                                         state.waveVortex.coefficients.A0};
    WVComplexView destination[] = {rhs.waveVortex.Fp, rhs.waveVortex.Fm,
                                   rhs.waveVortex.F0};
    if (zeroDerivative_) {
      for (auto &component : destination)
        std::fill_n(component.data, component.shape.elementCount(),
                    WVComplex64{});
      for (std::size_t block = 0; block < state.additionalBlockCount; ++block) {
        const auto &metadata = *state.additionalBlocks[block].layout;
        if (metadata.scalarType == WVStateScalarType::real64)
          std::fill_n(rhs.additionalBlocks[block].realData,
                      metadata.elementCount, 0.0);
        else
          std::fill_n(rhs.additionalBlocks[block].complexData,
                      metadata.elementCount, WVComplex64{});
      }
      ++evaluations;
      return WVKernelStatus::ok();
    }
    for (std::size_t component = 0; component < 3; ++component)
      for (std::size_t i = 0; i < source[component].shape.elementCount(); ++i)
        destination[component].data[i] = {-source[component].data[i].real,
                                          -source[component].data[i].imag};
    for (std::size_t block = 0; block < state.additionalBlockCount; ++block) {
      const auto &metadata = *state.additionalBlocks[block].layout;
      if (metadata.scalarType == WVStateScalarType::real64)
        for (std::size_t i = 0; i < metadata.elementCount; ++i)
          rhs.additionalBlocks[block].realData[i] =
              -2.0 * state.additionalBlocks[block].realData[i];
      else
        for (std::size_t i = 0; i < metadata.elementCount; ++i) {
          const auto value = state.additionalBlocks[block].complexData[i];
          rhs.additionalBlocks[block].complexData[i] = {-value.imag,
                                                        value.real};
        }
    }
    ++evaluations;
    return WVKernelStatus::ok();
  }
  WVStateConstraintResult
  enforceStateConstraints(WVMutableIntegrationState &state) override {
    std::size_t modified = 0;
    for (std::size_t block = 0; block < state.additionalBlockCount; ++block)
      if (state.additionalBlocks[block].layout->identifier == "particleX" ||
          state.additionalBlocks[block].layout->identifier == "particleY")
        for (std::size_t i = 0;
             i < state.additionalBlocks[block].layout->elementCount; ++i)
          if (state.additionalBlocks[block].realData[i] < 0) {
            state.additionalBlocks[block].realData[i] = 0;
            ++modified;
          }
    return {WVKernelStatus::ok(), modified, modified == 0};
  }
  WVKernelStatus createErrorPolicy(
      double, std::unique_ptr<WVIntegrationErrorPolicy> &policy) const override {
    policy = std::make_unique<ErrorPolicy>(layout_);
    return WVKernelStatus::ok();
  }
  std::size_t evaluations = 0;

private:
  WVIntegrationStateLayout layout_;
  bool zeroDerivative_ = false;
};

struct StateFixture {
  WVShape2D shape{2, 3};
  std::vector<WVComplex64> coefficients =
      std::vector<WVComplex64>(18, {1.0, 0.5});
  WVAdditionalStateStorage extra;
  WVMutableIntegrationState state;
  std::vector<WVComplex64> outputCoefficients = std::vector<WVComplex64>(18);
  WVAdditionalStateStorage outputExtra;
  WVMutableIntegrationState output;
  explicit StateFixture(const WVIntegrationStateLayout &layout) {
    require(static_cast<bool>(extra.initialize(layout)),
            "initialize additional state");
    require(static_cast<bool>(outputExtra.initialize(layout)),
            "initialize output state");
    state = {{0.0,
              0.0,
              {{coefficients.data(), shape},
               {coefficients.data() + 6, shape},
               {coefficients.data() + 12, shape}}},
             extra.mutableBlocks(),
             extra.blockCount()};
    output = {{0.0,
               0.0,
               {{outputCoefficients.data(), shape},
                {outputCoefficients.data() + 6, shape},
                {outputCoefficients.data() + 12, shape}}},
              outputExtra.mutableBlocks(),
              outputExtra.blockCount()};
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
};

void testContracts(WVPortableObserverDescriptor &descriptor,
                   WVIntegrationStateLayout &layout) {
  auto source = record();
  require(static_cast<bool>(
              WVPortableObserverDescriptor::create(source, descriptor)),
          "valid observer descriptor");
  const auto roundTrip = descriptor.record();
  require(roundTrip.schemaIdentifier == source.schemaIdentifier &&
              roundTrip.stateBlocks.size() == source.stateBlocks.size() &&
              roundTrip.outputFiles[0].groups[0].observerIdentifiers ==
                  source.outputFiles[0].groups[0].observerIdentifiers,
          "deterministic descriptor record");
  require(WVObserverFactoryRegistry::supports("WVLagrangianParticles"),
          "factory identity");
  require(!WVObserverFactoryRegistry::supports("WVUnknownObserver"),
          "unknown identity rejected");
  auto duplicate = source;
  duplicate.stateBlocks.push_back(duplicate.stateBlocks.front());
  WVPortableObserverDescriptor ignored;
  require(!WVPortableObserverDescriptor::create(duplicate, ignored),
          "duplicate block rejected");
  auto badReference = source;
  badReference.observers.back().stateBlockIdentifiers = {"missing"};
  require(!WVPortableObserverDescriptor::create(badReference, ignored),
          "unknown state reference rejected");
  auto orphan = source;
  orphan.observers.erase(orphan.observers.begin() + 2);
  require(!WVPortableObserverDescriptor::create(orphan, ignored),
          "orphan integrator-owned block rejected");
  auto sharedTracer = source;
  auto secondTracer = sharedTracer.observers[2];
  secondTracer.identifier = "secondTracer";
  secondTracer.name = "Second tracer";
  sharedTracer.observers.push_back(secondTracer);
  require(!WVPortableObserverDescriptor::create(sharedTracer, ignored),
          "state block shared by two tracers rejected");
  auto sharedParticles = source;
  auto secondParticles = sharedParticles.observers[1];
  secondParticles.identifier = "secondParticles";
  secondParticles.name = "Second particles";
  sharedParticles.observers.push_back(secondParticles);
  require(!WVPortableObserverDescriptor::create(sharedParticles, ignored),
          "state blocks shared by two particle systems rejected");
  auto mixedOwners = source;
  mixedOwners.observers[2].stateBlockIdentifiers = {"particleX"};
  require(!WVPortableObserverDescriptor::create(mixedOwners, ignored),
          "state block shared by particle and tracer observers rejected");
  require(static_cast<bool>(
              WVIntegrationStateLayout::create({2, 3}, descriptor, layout)),
          "integration layout");
  require(layout.additionalBlocks().size() == 3 &&
              layout.additionalBlocks()[0].identifier == "particleX" &&
              layout.additionalBlocks()[1].identifier == "particleY" &&
              layout.additionalBlocks()[2].identifier == "tracerAmplitude",
          "derived block excluded and order frozen");
  require(layout.realElementCount() == 10 && layout.complexElementCount() == 0,
          "integration-state counts");
  WVIntegrationStateLayout badLayout;
  require(!WVIntegrationStateLayout::create({3, 2}, descriptor, badLayout),
          "coefficient shape mismatch rejected");
}

void testRK4(LinearIntegrationSystem &system) {
  StateFixture leanFixture(system.stateLayout());
  WVFixedStepRK4 leanRK4(system, {false});
  leanFixture.state.additionalBlocks[0].realData[0] = -1.0;
  require(
      static_cast<bool>(leanRK4.prepareStateAfterRestart(leanFixture.state)),
      "lean RK4 restart preparation");
  require(leanFixture.state.additionalBlocks[0].realData[0] == 0.0,
          "restart reconstruction applies integration-state constraints");
  StateFixture fixture(system.stateLayout());
  WVFixedStepRK4 rk4(system, {true});
  require(static_cast<bool>(rk4.prepareStateAfterRestart(fixture.state)),
          "RK4 restart preparation");
  require(static_cast<bool>(rk4.step(fixture.state, 0.01)), "RK4 step");
  require(std::abs(fixture.coefficients[0].real - std::exp(-0.01)) < 1e-10,
          "RK4 coefficient result");
  require(std::abs(fixture.state.additionalBlocks[0].realData[0] -
                   std::exp(-0.02)) < 1e-9,
          "RK4 real block result");
  require(static_cast<bool>(rk4.evaluateDenseOutput(0.005, fixture.output)),
          "RK4 integration-state dense output");
  require(std::abs(fixture.outputCoefficients[0].real - std::exp(-0.005)) <
              1e-7,
          "RK4 dense coefficient result");
  require(rk4.metrics().workspaceCapacityBytes > 0 &&
              rk4.metrics().workspaceMaximumLiveBytes ==
                  rk4.metrics().workspaceCapacityBytes,
          "RK4 storage accounting");
  require(leanRK4.metrics().workspaceCapacityBytes <
              rk4.metrics().workspaceCapacityBytes,
          "RK4 dense history allocated only when requested");
}

void testRK23(LinearIntegrationSystem &system) {
  StateFixture fixture(system.stateLayout());
  WVAdaptiveRK23Options options;
  options.relativeTolerance = 1e-8;
  options.absoluteToleranceScale = 1.0;
  options.maximumStepFactor = 2.0;
  WVAdaptiveRK23 rk23(system, options);
  require(static_cast<bool>(rk23.prepareStateAfterRestart(fixture.state)),
          "RK23 restart preparation");
  require(static_cast<bool>(rk23.step(fixture.state, 0.5)),
          "RK23 adaptive step");
  require(rk23.metrics().rejectedStepCount > 0, "RK23 rejection");
  const auto accepted = rk23.lastAcceptedStep();
  require(accepted && accepted->finalTime > 0, "RK23 accepted step");
  require(accepted->methodStatistics.rejectedStepCount > 0 &&
              std::abs(accepted->methodStatistics.nextStepSize -
                       accepted->methodStatistics.stepSize) < 1e-15,
          "RK23 MATLAB controller does not grow immediately after rejection");
  const auto midpoint = 0.5 * (accepted->initialTime + accepted->finalTime);
  require(static_cast<bool>(rk23.evaluateDenseOutput(midpoint, fixture.output)),
          "RK23 integration-state dense output");
  require(std::abs(fixture.outputCoefficients[0].real - std::exp(-midpoint)) <
              1e-6,
          "RK23 dense coefficient result");
  require(rk23.metrics().workspaceCapacityBytes > 0, "RK23 storage accounting");
}

void testRK23MatlabControllerWork() {
  WVIntegrationStateLayout layout;
  require(static_cast<bool>(WVIntegrationStateLayout::createCoefficientOnly(
              {2, 3}, layout)),
          "coefficient-only parity layout");
  LinearIntegrationSystem system(std::move(layout), true);
  StateFixture fixture(system.stateLayout());
  WVAdaptiveRK23Options options;
  options.maximumStepSize = 0.1;
  WVAdaptiveRK23 rk23(system, options);
  require(static_cast<bool>(rk23.prepareStateAfterRestart(fixture.state)),
          "RK23 MATLAB-controller restart preparation");
  require(static_cast<bool>(rk23.advanceToTime(fixture.state, 1.0, 0.5)),
          "RK23 MATLAB-controller interval");
  require(rk23.metrics().acceptedStepCount == 10,
          "RK23 MATLAB-controller maximum-step count");
  require(rk23.metrics().rejectedStepCount == 0,
          "RK23 MATLAB-controller rejection count");
  require(rk23.metrics().rightHandSideEvaluationCount == 31,
          "RK23 MATLAB-controller FSAL work count");
  require(rk23.stepDiagnostics().size() == 10,
          "RK23 MATLAB-controller step diagnostics");
  for (const auto &diagnostic : rk23.stepDiagnostics()) {
    require(std::abs(diagnostic.acceptedStepSize - 0.1) < 1e-14,
            "RK23 MATLAB-controller accepted step size");
    require(diagnostic.rejectedAttemptCount == 0 &&
                diagnostic.normalizedError == 0.0,
            "RK23 MATLAB-controller accepted-step metadata");
  }
  require(!rk23.stepDiagnostics().front().reusedFSALDerivative &&
              rk23.stepDiagnostics().back().reusedFSALDerivative,
          "RK23 MATLAB-controller FSAL metadata");
  require(std::string(WVAdaptiveRK23::controllerIdentifier()) ==
              "matlab-ode23-v1",
          "RK23 MATLAB controller identity");
}

void testRK23MatlabOde23ParityFixture() {
  WVIntegrationStateLayout layout;
  require(static_cast<bool>(WVIntegrationStateLayout::createCoefficientOnly(
              {1, 1}, layout)),
          "MATLAB ode23 parity layout");
  LinearIntegrationSystem system(std::move(layout));
  std::vector<WVComplex64> coefficients(3, {1.0, 0.5});
  WVMutableIntegrationState state{
      {0.0,
       0.0,
       {{coefficients.data(), {1, 1}},
        {coefficients.data() + 1, {1, 1}},
        {coefficients.data() + 2, {1, 1}}}},
      nullptr,
      0};
  WVAdaptiveRK23Options options;
  options.relativeTolerance = 1e-8;
  options.absoluteToleranceScale = 1e-10;
  options.maximumStepSize = 0.5;
  WVAdaptiveRK23 rk23(system, options);
  require(static_cast<bool>(rk23.prepareStateAfterRestart(state)),
          "MATLAB ode23 parity restart preparation");
  require(static_cast<bool>(rk23.advanceToTime(state, 1.0, 0.5)),
          "MATLAB ode23 parity interval");
  require(rk23.metrics().acceptedStepCount == 159 &&
              rk23.metrics().rejectedStepCount == 6 &&
              rk23.metrics().rightHandSideEvaluationCount == 496,
          "MATLAB ode23 parity work counts");
  require(rk23.stepDiagnosticsComplete() &&
              rk23.stepDiagnostics().size() == 159,
          "MATLAB ode23 parity diagnostics");
  require(rk23.toleranceComponentHashes().size() == 3 &&
              rk23.toleranceHash() != 0,
          "MATLAB ode23 parity tolerance audit");
  require(std::abs(rk23.stepDiagnostics().front().acceptedStepSize -
                   0.0078125) < 1e-15,
          "MATLAB ode23 parity first accepted step");
  constexpr double matlabReal = 0.36787943731476008;
  constexpr double matlabImaginary = 0.18393971865738004;
  require(std::abs(coefficients[0].real - matlabReal) < 1e-14 &&
              std::abs(coefficients[0].imag - matlabImaginary) < 1e-14,
          "MATLAB ode23 parity endpoint");
}

} // namespace

int main() {
  WVPortableObserverDescriptor descriptor;
  WVIntegrationStateLayout layout;
  testContracts(descriptor, layout);
  LinearIntegrationSystem system(std::move(layout));
  testRK4(system);
  testRK23(system);
  testRK23MatlabControllerWork();
  testRK23MatlabOde23ParityFixture();
  std::cout << "PASS: portable observer contracts and unified RK4/RK23 "
               "integration\n";
  return 0;
}
