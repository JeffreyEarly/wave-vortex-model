#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVConstantStratificationCompositeSystem.hpp"

#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <iomanip>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

void printArray(const double *values, std::size_t count) {
  std::cout << '[';
  for (std::size_t index = 0; index < count; ++index) {
    if (index != 0)
      std::cout << ',';
    std::cout << values[index];
  }
  std::cout << ']';
}

WVPortableObserverDescriptor descriptorFor(
    const WVTransformConstantStratificationConfiguration &configuration,
    WVShape2D shape) {
  WVPortableObserverRecord record;
  const std::vector<std::size_t> coefficientShape{shape.rows, shape.columns};
  for (const auto *name : {"Ap", "Am", "A0"})
    record.stateBlocks.push_back(
        {name, WVStateScalarType::complex64, coefficientShape,
         WVToleranceKind::coefficientEnergyScaled, 1e-6,
         WVStateOwnership::integratorOwned,
         WVRestartRequirement::requiredDynamicState});
  const auto addReal = [&](const char *name, double tolerance) {
    record.stateBlocks.push_back(
        {name, WVStateScalarType::real64, {2},
         WVToleranceKind::uniformAbsolute, tolerance,
         WVStateOwnership::integratorOwned,
         WVRestartRequirement::requiredDynamicState});
  };
  addReal("surface-x", 1e-5);
  addReal("surface-y", 1e-5);
  addReal("volume-x", 1e-5);
  addReal("volume-y", 1e-5);
  addReal("volume-z", 1e-6);

  const double dx = configuration.Lx / static_cast<double>(configuration.Nx);
  const double dy = configuration.Ly / static_cast<double>(configuration.Ny);
  const double dz = configuration.Lz /
                    static_cast<double>(configuration.Nz - 1);
  WVObserverRecord surface;
  surface.identifier = "surface";
  surface.name = "surfaceParticles";
  surface.kind = WVObserverKind::lagrangianParticles;
  surface.stateBlockIdentifiers = {"surface-x", "surface-y"};
  surface.x = {-0.35 * dx, configuration.Lx + 0.4 * dx};
  surface.y = {configuration.Ly + 0.55 * dy, -0.3 * dy};
  surface.z = {-configuration.Lz + 0.4 * dz,
               -configuration.Lz + 2.25 * dz};
  surface.isXYOnly = true;
  surface.advectionInterpolation = WVPositionInterpolation::linear;
  surface.horizontalAbsoluteTolerance = 1e-5;
  record.observers.push_back(surface);

  WVObserverRecord volume;
  volume.identifier = "volume";
  volume.name = "volumeParticles";
  volume.kind = WVObserverKind::lagrangianParticles;
  volume.stateBlockIdentifiers = {"volume-x", "volume-y", "volume-z"};
  volume.x = {2.35 * dx, configuration.Lx - 0.2 * dx};
  volume.y = {1.7 * dy, configuration.Ly - 0.1 * dy};
  volume.z = {-1.3 * dz, -configuration.Lz + 1.6 * dz};
  volume.isXYOnly = false;
  volume.advectionInterpolation = WVPositionInterpolation::spline;
  volume.horizontalAbsoluteTolerance = 1e-5;
  volume.verticalAbsoluteTolerance = 1e-6;
  record.observers.push_back(volume);

  WVPortableObserverDescriptor descriptor;
  const auto status = WVPortableObserverDescriptor::create(record, descriptor);
  if (!status)
    throw std::runtime_error(status.message);
  return descriptor;
}

struct Fixture {
  std::vector<WVComplex64> coefficients;
  WVAdditionalStateStorage storage;
  WVMutableCompositeState state;

  Fixture(const WVCheckpoint &checkpoint,
          const WVCompositeStateLayout &layout)
      : coefficients(3 * checkpoint.state.coefficients.shape.elementCount()) {
    const auto count = checkpoint.state.coefficients.shape.elementCount();
    std::copy(checkpoint.state.coefficients.Ap.begin(),
              checkpoint.state.coefficients.Ap.end(), coefficients.begin());
    std::copy(checkpoint.state.coefficients.Am.begin(),
              checkpoint.state.coefficients.Am.end(),
              coefficients.begin() + count);
    std::copy(checkpoint.state.coefficients.A0.begin(),
              checkpoint.state.coefficients.A0.end(),
              coefficients.begin() + 2 * count);
    const auto status = storage.initialize(layout);
    if (!status)
      throw std::runtime_error(status.message);
    state = {{checkpoint.state.t,
              checkpoint.state.t0,
              {{coefficients.data(), checkpoint.state.coefficients.shape},
               {coefficients.data() + count,
                checkpoint.state.coefficients.shape},
               {coefficients.data() + 2 * count,
                checkpoint.state.coefficients.shape}}},
             storage.mutableBlocks(), storage.blockCount()};
  }
};

const WVAdditionalStateBlockView &block(const WVMutableCompositeState &state,
                                        const std::string &identifier) {
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index)
    if (state.additionalBlocks[index].layout->identifier == identifier)
      return state.additionalBlocks[index];
  throw std::runtime_error("missing particle block " + identifier);
}

void printState(const WVMutableCompositeState &state) {
  std::cout << '{';
  bool first = true;
  const std::vector<std::pair<const char *, const char *>> blocks{
      {"surfaceX", "surface-x"}, {"surfaceY", "surface-y"},
      {"volumeX", "volume-x"},   {"volumeY", "volume-y"},
      {"volumeZ", "volume-z"}};
  for (const auto &[name, identifier] : blocks) {
    if (!first)
      std::cout << ',';
    first = false;
    const auto &values = block(state, identifier);
    std::cout << '"' << name << "\":";
    printArray(values.realData, values.layout->elementCount);
  }
  std::cout << '}';
}

} // namespace

int main(int argc, char **argv) {
  try {
    if (argc != 2) {
      std::cerr << "usage: wv_lagrangian_particle_inspect checkpoint.nc\n";
      return 2;
    }
    WVCheckpoint checkpoint;
    const auto read = WVCheckpointReader::read(argv[1], checkpoint);
    if (!read) {
      std::cerr << read.message << '\n';
      return 3;
    }
    const auto descriptor = descriptorFor(
        checkpoint.configuration, checkpoint.state.coefficients.shape);
    std::unique_ptr<WVConstantStratificationCompositeSystem> system;
    auto status = WVConstantStratificationCompositeSystem::create(
        checkpoint.configuration, {}, descriptor,
        std::make_unique<WVReferenceFFTEngine>(), 1e-6, system);
    if (!status)
      throw std::runtime_error(status.message);

    Fixture initial(checkpoint, system->stateLayout());
    status = system->initializeParticleState(initial.state);
    if (!status)
      throw std::runtime_error(status.message);
    WVAdditionalStateStorage rhsStorage;
    status = rhsStorage.initialize(system->stateLayout());
    if (!status)
      throw std::runtime_error(status.message);
    const auto shape = checkpoint.state.coefficients.shape;
    std::vector<WVComplex64> coefficientRhs(3 * shape.elementCount());
    WVCompositeFlux rhs{
        {{coefficientRhs.data(), shape},
         {coefficientRhs.data() + shape.elementCount(), shape},
         {coefficientRhs.data() + 2 * shape.elementCount(), shape}},
        rhsStorage.mutableBlocks(), rhsStorage.blockCount()};
    std::vector<WVAdditionalStateBlockConstView> initialViews;
    status = system->evaluateRightHandSide(
        compositeConstView(initial.state, initialViews), rhs);
    if (!status)
      throw std::runtime_error(status.message);
    WVMutableCompositeState rhsState{
        {initial.state.waveVortex.t, initial.state.waveVortex.t0,
         {{coefficientRhs.data(), shape},
          {coefficientRhs.data() + shape.elementCount(), shape},
          {coefficientRhs.data() + 2 * shape.elementCount(), shape}}},
        rhsStorage.mutableBlocks(), rhsStorage.blockCount()};

    constexpr double stepSize = 0.1;
    Fixture fixed(checkpoint, system->stateLayout());
    status = system->initializeParticleState(fixed.state);
    if (!status)
      throw std::runtime_error(status.message);
    WVCompositeFixedStepRK4 fixedIntegrator(*system, true);
    status = fixedIntegrator.prepareStateAfterRestart(fixed.state);
    if (status)
      status = fixedIntegrator.step(fixed.state, stepSize);
    if (!status)
      throw std::runtime_error(status.message);
    Fixture midpoint(checkpoint, system->stateLayout());
    status = fixedIntegrator.evaluateDenseOutput(
        checkpoint.state.t + 0.5 * stepSize, midpoint.state);
    if (!status)
      throw std::runtime_error(status.message);

    Fixture adaptive(checkpoint, system->stateLayout());
    status = system->initializeParticleState(adaptive.state);
    if (!status)
      throw std::runtime_error(status.message);
    WVCompositeAdaptiveRK23Options adaptiveOptions;
    adaptiveOptions.relativeTolerance = 1e-9;
    adaptiveOptions.absoluteToleranceScale = 1e-9;
    WVCompositeAdaptiveRK23 adaptiveIntegrator(*system, adaptiveOptions);
    status = adaptiveIntegrator.prepareStateAfterRestart(adaptive.state);
    if (status)
      status = adaptiveIntegrator.step(adaptive.state, 100.0);
    if (!status)
      throw std::runtime_error(status.message);

    std::cout << std::setprecision(17);
    std::cout << "{\"initialTime\":" << checkpoint.state.t
              << ",\"stepSize\":" << stepSize << ",\"initial\":";
    printState(initial.state);
    std::cout << ",\"rightHandSide\":";
    printState(rhsState);
    std::cout << ",\"fixedEndpoint\":";
    printState(fixed.state);
    std::cout << ",\"denseMidpoint\":";
    printState(midpoint.state);
    std::cout << ",\"adaptiveTime\":" << adaptive.state.waveVortex.t
              << ",\"adaptiveEndpoint\":";
    printState(adaptive.state);
    std::cout << ",\"adaptiveRejectedSteps\":"
              << adaptiveIntegrator.metrics().rejectedStepCount
              << ",\"systemMetrics\":{\"rhsEvaluations\":"
              << system->metrics().rightHandSideEvaluationCount
              << ",\"velocityTransforms\":"
              << system->metrics().velocityFieldEvaluationCount
              << ",\"persistentBytes\":" << system->persistentBytes()
              << "}}\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 4;
  }
}
