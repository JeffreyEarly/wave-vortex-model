#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"

#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

void require(bool condition, const std::string &message) {
  if (!condition)
    throw std::runtime_error(message);
}

WVTransformConstantStratificationConfiguration configuration() {
  WVTransformConstantStratificationConfiguration value;
  value.Nx = 8;
  value.Ny = 6;
  value.Nz = 7;
  value.Nj = 6;
  value.Lx = 8000.0;
  value.Ly = 6000.0;
  value.Lz = 1200.0;
  value.N0 = 5.2e-3;
  value.rho0 = 1025.0;
  value.g = 9.81;
  value.planetaryRadius = 6.371e6;
  value.rotationRate = 7.2921e-5;
  value.latitude = 35.0;
  value.shouldAntialias = true;
  return value;
}

struct OwnedState {
  WVShape2D shape;
  std::vector<WVComplex64> Ap;
  std::vector<WVComplex64> Am;
  std::vector<WVComplex64> A0;
  WVState view() const {
    return {3.0,
            0.0,
            {{Ap.data(), shape}, {Am.data(), shape}, {A0.data(), shape}}};
  }
};

OwnedState state(const WVTransformConstantStratificationConfiguration &config) {
  WVTransformConstantStratificationDescriptor descriptor;
  require(static_cast<bool>(
              WVTransformConstantStratificationDescriptor::create(config,
                                                                   descriptor)),
          "descriptor construction failed");
  OwnedState result;
  result.shape = descriptor.spectralShape();
  result.Ap.resize(result.shape.elementCount());
  result.Am.resize(result.shape.elementCount());
  result.A0.resize(result.shape.elementCount());
  for (std::size_t index = 0; index < result.Ap.size(); ++index) {
    const double x = static_cast<double>(index + 1);
    result.Ap[index] = {1e-3 * std::sin(x), 8e-4 * std::cos(x)};
    result.Am[index] = {-7e-4 * std::cos(0.3 * x), 9e-4 * std::sin(0.2 * x)};
    result.A0[index] = {6e-4 * std::sin(0.4 * x), 5e-4 * std::cos(0.7 * x)};
  }
  return result;
}

WVPortableObserverDescriptor descriptor() {
  WVPortableObserverRecord record;
  for (const char *name : {"Ap", "Am", "A0"})
    record.stateBlocks.push_back(
        {name,
         WVStateScalarType::complex64,
         {6, 1},
         WVToleranceKind::coefficientEnergyScaled,
         1e-6,
         WVStateOwnership::integratorOwned,
         WVRestartRequirement::requiredDynamicState});
  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "WVCoefficients";
  coefficients.kind = WVObserverKind::coefficients;
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  record.observers.push_back(coefficients);
  WVObserverRecord fields;
  fields.identifier = "fields-a";
  fields.name = "WVEulerianFields";
  fields.kind = WVObserverKind::eulerianFields;
  fields.fieldNames = {"Ap", "u", "psi"};
  record.observers.push_back(fields);
  fields.identifier = "fields-b";
  fields.fieldNames = {"u"};
  record.observers.push_back(fields);
  WVObserverRecord mooring;
  mooring.identifier = "mooring";
  mooring.name = "central";
  mooring.kind = WVObserverKind::mooring;
  mooring.fieldNames = {"u", "eta"};
  mooring.x = {-1.0, 8000.0};
  mooring.y = {6000.0, 2999.0};
  record.observers.push_back(mooring);
  WVPortableObserverDescriptor result;
  require(static_cast<bool>(WVPortableObserverDescriptor::create(record, result)),
          "observer descriptor construction failed");
  return result;
}

const WVObserverOutputVariableSpecification &
find(const std::vector<WVObserverOutputVariableSpecification> &values,
     const std::string &identifier) {
  const auto found =
      std::find_if(values.begin(), values.end(), [&](const auto &value) {
        return value.identifier == identifier;
      });
  require(found != values.end(), "missing specification " + identifier);
  return *found;
}

void testService(bool linear) {
  auto config = configuration();
  auto observers = descriptor();
  std::unique_ptr<WVObserverOutputEvaluationService> service;
  auto status = WVObserverOutputEvaluationService::create(
      config, linear, observers, std::make_unique<WVReferenceFFTEngine>(),
      service);
  require(static_cast<bool>(status), "service construction failed");
  require(service->metrics().uniqueFieldOutputCount == 4,
          "field requests were not deduplicated");
  require(service->metrics().sharedFieldReuseCount == 1,
          "shared full-grid field was not recorded");

  std::vector<WVObserverOutputVariableSpecification> specifications;
  status = service->specifications(observers.observers()[1], specifications);
  require(static_cast<bool>(status), "specification query failed");
  require(find(specifications, "Ap").valueType == WVOutputValueType::complex64,
          "coefficient type mismatch");
  require(find(specifications, "Ap").cadence ==
              (linear ? WVObserverOutputCadence::initialOnly
                      : WVObserverOutputCadence::timeSeries),
          "coefficient cadence mismatch");
  require(find(specifications, "psi").cadence ==
              (linear ? WVObserverOutputCadence::initialOnly
                      : WVObserverOutputCadence::timeSeries),
          "psi cadence mismatch");
  require(find(specifications, "u").cadence ==
              WVObserverOutputCadence::timeSeries,
          "u must remain a time series");

  auto owned = state(config);
  if (linear) {
    status = service->prepareInitial(owned.view());
    require(static_cast<bool>(status), "initial observer preparation failed");
    WVObserverOutputValueView initialValue;
    status = service->value(observers.observers()[1],
                            find(specifications, "psi"), initialValue);
    require(static_cast<bool>(status) && initialValue.realData != nullptr,
            "initial-only field value failed");
  }
  WVCompositeOutputEvent event;
  event.eventOrdinal = 2;
  event.scheduledTime = 3.0;
  event.state.waveVortex = owned.view();
  status = service->prepare(event);
  require(static_cast<bool>(status), "observer preparation failed");
  require(service->metrics().fieldEvaluationCount == (linear ? 2U : 1U),
          "initial and time-series plans were not evaluated independently");

  WVObserverOutputValueView value;
  status = service->value(observers.observers()[1], find(specifications, "Ap"),
                          value);
  require(static_cast<bool>(status), "coefficient value failed");
  require(value.complexData == owned.Ap.data(),
          "coefficient output must remain a borrowed view");
  status = service->value(observers.observers()[1], find(specifications, "u"),
                          value);
  require(static_cast<bool>(status), "field value failed");
  require(value.realData != nullptr &&
              value.elementCount == config.Nx * config.Ny * config.Nz,
          "Eulerian field shape mismatch");

  status = service->specifications(observers.observers()[3], specifications);
  require(static_cast<bool>(status), "mooring specification query failed");
  require(find(specifications, "u").name == "central_u" &&
              find(specifications, "u").dimensions ==
                  std::vector<std::size_t>({config.Nz, 2}),
          "mooring schema mismatch");
  status = service->value(observers.observers()[3], find(specifications, "u"),
                          value);
  require(static_cast<bool>(status) && value.elementCount == config.Nz * 2,
          "mooring value mismatch");
}

} // namespace

int main() {
  try {
    testService(false);
    testService(true);
    std::cout << "Passive observer output evaluation contracts passed.\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
