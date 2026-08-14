#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVConstantStratificationCompositeSystem.hpp"

#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <memory>
#include <stdexcept>
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
  record.stateBlocks.push_back(
      {"dye", WVStateScalarType::real64,
       {configuration.Nx, configuration.Ny, configuration.Nz},
       WVToleranceKind::uniformAbsolute, 1e-8,
       WVStateOwnership::integratorOwned,
       WVRestartRequirement::requiredDynamicState});
  WVObserverRecord tracer;
  tracer.identifier = "dye";
  tracer.name = "dye";
  tracer.kind = WVObserverKind::tracer;
  tracer.stateBlockIdentifiers = {"dye"};
  tracer.shouldAntialias = true;
  record.observers.push_back(std::move(tracer));
  WVPortableObserverDescriptor descriptor;
  const auto status = WVPortableObserverDescriptor::create(record, descriptor);
  if (!status)
    throw std::runtime_error(status.message);
  return descriptor;
}

} // namespace

int main(int argc, char **argv) {
  try {
    if (argc != 2) {
      std::cerr << "usage: wv_tracer_inspect checkpoint.nc\n";
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

    const auto shape = checkpoint.state.coefficients.shape;
    const auto M = shape.elementCount();
    std::vector<WVComplex64> coefficients(3 * M);
    std::copy(checkpoint.state.coefficients.Ap.begin(),
              checkpoint.state.coefficients.Ap.end(), coefficients.begin());
    std::copy(checkpoint.state.coefficients.Am.begin(),
              checkpoint.state.coefficients.Am.end(), coefficients.begin() + M);
    std::copy(checkpoint.state.coefficients.A0.begin(),
              checkpoint.state.coefficients.A0.end(),
              coefficients.begin() + 2 * M);
    WVAdditionalStateStorage stateStorage;
    WVAdditionalStateStorage fluxStorage;
    status = stateStorage.initialize(system->stateLayout());
    if (status)
      status = fluxStorage.initialize(system->stateLayout());
    if (!status)
      throw std::runtime_error(status.message);
    WVMutableCompositeState state{
        {checkpoint.state.t, checkpoint.state.t0,
         {{coefficients.data(), shape}, {coefficients.data() + M, shape},
          {coefficients.data() + 2 * M, shape}}},
        stateStorage.mutableBlocks(), stateStorage.blockCount()};
    auto &tracer = state.additionalBlocks[0];
    const auto &configuration = checkpoint.configuration;
    const double pi = std::acos(-1.0);
    for (std::size_t z = 0; z < configuration.Nz; ++z)
      for (std::size_t y = 0; y < configuration.Ny; ++y)
        for (std::size_t x = 0; x < configuration.Nx; ++x) {
          const auto index = x + configuration.Nx * (y + configuration.Ny * z);
          tracer.realData[index] =
              std::sin(2.0 * pi * static_cast<double>(x) /
                       static_cast<double>(configuration.Nx)) +
              0.25 * std::cos(2.0 * pi * static_cast<double>(y) /
                              static_cast<double>(configuration.Ny)) +
              0.1 * std::cos(pi * static_cast<double>(z) /
                             static_cast<double>(configuration.Nz - 1));
        }
    std::vector<WVComplex64> coefficientFlux(3 * M);
    WVCompositeFlux flux{
        {{coefficientFlux.data(), shape}, {coefficientFlux.data() + M, shape},
         {coefficientFlux.data() + 2 * M, shape}},
        fluxStorage.mutableBlocks(), fluxStorage.blockCount()};
    std::vector<WVAdditionalStateBlockConstView> views;
    status = system->evaluateRightHandSide(compositeConstView(state, views), flux);
    if (!status)
      throw std::runtime_error(status.message);

    std::cout << std::setprecision(17);
    std::cout << "{\"initial\":";
    printArray(tracer.realData, tracer.layout->elementCount);
    std::cout << ",\"rightHandSide\":";
    printArray(flux.additionalBlocks[0].realData,
               flux.additionalBlocks[0].layout->elementCount);
    std::cout << ",\"metrics\":{\"rhsEvaluations\":"
              << system->metrics().rightHandSideEvaluationCount
              << ",\"tracerEvaluations\":"
              << system->metrics().tracerEvaluationCount
              << ",\"velocityReconstructions\":"
              << system->kernelMetrics().advectionVelocityReconstructionCount
              << ",\"scalarAdvections\":"
              << system->kernelMetrics().scalarAdvectionCount
              << ",\"scalarAntialiases\":"
              << system->kernelMetrics().scalarAntialiasCount << "}}\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 4;
  }
}
