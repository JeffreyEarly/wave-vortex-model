#include "WaveVortexRuntime/WVCompositeIntegration.hpp"

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
  coefficients.kind = WVObserverKind::coefficients;
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  result.observers.push_back(coefficients);
  WVObserverRecord particles;
  particles.identifier = "particles";
  particles.name = "Particles";
  particles.kind = WVObserverKind::lagrangianParticles;
  particles.stateBlockIdentifiers = {"particleX", "particleY"};
  particles.x = {0, 1, 2};
  particles.y = {3, 4, 5};
  particles.isXYOnly = true;
  particles.horizontalAbsoluteTolerance = 1e-8;
  result.observers.push_back(particles);
  WVObserverRecord tracer;
  tracer.identifier = "tracer";
  tracer.name = "Tracer";
  tracer.kind = WVObserverKind::tracer;
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

class LinearCompositeSystem final : public WVCompositeIntegrationSystem {
public:
  explicit LinearCompositeSystem(WVCompositeStateLayout layout)
      : layout_(std::move(layout)) {}
  const WVCompositeStateLayout &stateLayout() const noexcept override {
    return layout_;
  }
  WVKernelStatus evaluateRightHandSide(const WVCompositeState &state,
                                       WVCompositeFlux &rhs) override {
    if (rhs.additionalBlockCount != state.additionalBlockCount)
      return {WVKernelStatusCode::invalidShape, "RHS layout mismatch."};
    const WVComplexConstView source[] = {state.waveVortex.coefficients.Ap,
                                         state.waveVortex.coefficients.Am,
                                         state.waveVortex.coefficients.A0};
    WVComplexView destination[] = {rhs.waveVortex.Fp, rhs.waveVortex.Fm,
                                   rhs.waveVortex.F0};
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
  enforceStateConstraints(WVMutableCompositeState &state) override {
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
  double coefficientAbsoluteTolerance(std::size_t,
                                      std::size_t) const noexcept override {
    return 1e-10;
  }
  std::size_t evaluations = 0;

private:
  WVCompositeStateLayout layout_;
};

struct StateFixture {
  WVShape2D shape{2, 3};
  std::vector<WVComplex64> coefficients =
      std::vector<WVComplex64>(18, {1.0, 0.5});
  WVAdditionalStateStorage extra;
  WVMutableCompositeState state;
  std::vector<WVComplex64> outputCoefficients = std::vector<WVComplex64>(18);
  WVAdditionalStateStorage outputExtra;
  WVMutableCompositeState output;
  explicit StateFixture(const WVCompositeStateLayout &layout) {
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
                   WVCompositeStateLayout &layout) {
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
  require(std::string(WVObserverFactoryRegistry::portableTag(
              WVObserverKind::lagrangianParticles)) == "WVLagrangianParticles",
          "factory tag");
  require(!WVObserverFactoryRegistry::supports(static_cast<WVObserverKind>(99)),
          "unknown tag rejected");
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
              WVCompositeStateLayout::create({2, 3}, descriptor, layout)),
          "composite layout");
  require(layout.additionalBlocks().size() == 3 &&
              layout.additionalBlocks()[0].identifier == "particleX" &&
              layout.additionalBlocks()[1].identifier == "particleY" &&
              layout.additionalBlocks()[2].identifier == "tracerAmplitude",
          "derived block excluded and order frozen");
  require(layout.realElementCount() == 10 && layout.complexElementCount() == 0,
          "composite counts");
  WVCompositeStateLayout badLayout;
  require(!WVCompositeStateLayout::create({3, 2}, descriptor, badLayout),
          "coefficient shape mismatch rejected");
}

void testRK4(LinearCompositeSystem &system) {
  StateFixture leanFixture(system.stateLayout());
  WVCompositeFixedStepRK4 leanRK4(system, false);
  leanFixture.state.additionalBlocks[0].realData[0] = -1.0;
  require(
      static_cast<bool>(leanRK4.prepareStateAfterRestart(leanFixture.state)),
      "lean RK4 restart preparation");
  require(leanFixture.state.additionalBlocks[0].realData[0] == 0.0,
          "restart reconstruction applies composite constraints");
  StateFixture fixture(system.stateLayout());
  WVCompositeFixedStepRK4 rk4(system, true);
  require(static_cast<bool>(rk4.prepareStateAfterRestart(fixture.state)),
          "RK4 restart preparation");
  require(static_cast<bool>(rk4.step(fixture.state, 0.01)), "RK4 step");
  require(std::abs(fixture.coefficients[0].real - std::exp(-0.01)) < 1e-10,
          "RK4 coefficient result");
  require(std::abs(fixture.state.additionalBlocks[0].realData[0] -
                   std::exp(-0.02)) < 1e-9,
          "RK4 real block result");
  require(static_cast<bool>(rk4.evaluateDenseOutput(0.005, fixture.output)),
          "RK4 composite dense output");
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

void testRK23(LinearCompositeSystem &system) {
  StateFixture fixture(system.stateLayout());
  WVCompositeAdaptiveRK23Options options;
  options.relativeTolerance = 1e-8;
  options.absoluteToleranceScale = 1.0;
  options.maximumStepFactor = 2.0;
  WVCompositeAdaptiveRK23 rk23(system, options);
  require(static_cast<bool>(rk23.prepareStateAfterRestart(fixture.state)),
          "RK23 restart preparation");
  require(static_cast<bool>(rk23.step(fixture.state, 0.5)),
          "RK23 adaptive step");
  require(rk23.metrics().rejectedStepCount > 0, "RK23 rejection");
  const auto accepted = rk23.lastAcceptedStep();
  require(accepted && accepted->finalTime > 0, "RK23 accepted step");
  const auto midpoint = 0.5 * (accepted->initialTime + accepted->finalTime);
  require(static_cast<bool>(rk23.evaluateDenseOutput(midpoint, fixture.output)),
          "RK23 composite dense output");
  require(std::abs(fixture.outputCoefficients[0].real - std::exp(-midpoint)) <
              1e-6,
          "RK23 dense coefficient result");
  require(rk23.metrics().workspaceCapacityBytes > 0, "RK23 storage accounting");
}

} // namespace

int main() {
  WVPortableObserverDescriptor descriptor;
  WVCompositeStateLayout layout;
  testContracts(descriptor, layout);
  LinearCompositeSystem system(std::move(layout));
  testRK4(system);
  testRK23(system);
  std::cout << "PASS: portable observer contracts and composite RK4/RK23 "
               "integration\n";
  return 0;
}
