#include "WaveVortexRuntime/WVObserverOutputEvaluationService.hpp"

#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <iostream>
#include <map>
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

class WVTestPortablePointDiagnosticImplementation final
    : public WVObservingSystem {
public:
  const std::string &typeIdentifier() const noexcept override {
    static const std::string value = "WVTestPortablePointDiagnostic";
    return value;
  }
  std::uint32_t contractVersion() const noexcept override { return 1; }
  const std::string &fieldListAttribute() const noexcept override {
    static const std::string value = "fieldNames";
    return value;
  }
  bool recordsFixedPoints() const noexcept override { return true; }
  WVKernelStatus validate(
      const WVObserverRecord &record,
      const std::map<std::string, const WVStateBlockRecord *> &,
      std::map<std::string, std::size_t> &) const override {
    if (!record.stateBlockIdentifiers.empty() || record.fieldNames.size() != 1 ||
        record.x.empty() || record.x.size() != record.y.size() ||
        record.x.size() != record.z.size() ||
        !std::isfinite(record.outputScale) ||
        !std::isfinite(record.outputOffset))
      return {WVKernelStatusCode::invalidConfiguration,
              "Point diagnostic configuration is invalid."};
    return WVKernelStatus::ok();
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }
};

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
  for (const char *name : {"particle-x", "particle-y"})
    record.stateBlocks.push_back(
        {name, WVStateScalarType::real64, {2},
         WVToleranceKind::uniformAbsolute, 1e-5,
         WVStateOwnership::integratorOwned,
         WVRestartRequirement::requiredDynamicState});
  WVObserverRecord coefficients;
  coefficients.identifier = "coefficients";
  coefficients.name = "WVCoefficients";
  coefficients.typeIdentifier = "WVCoefficients";
  coefficients.stateBlockIdentifiers = {"Ap", "Am", "A0"};
  record.observers.push_back(coefficients);
  WVObserverRecord fields;
  fields.identifier = "fields-a";
  fields.name = "WVEulerianFields";
  fields.typeIdentifier = "WVEulerianFields";
  fields.fieldNames = {"Ap", "u", "psi"};
  record.observers.push_back(fields);
  fields.identifier = "fields-b";
  fields.fieldNames = {"u"};
  record.observers.push_back(fields);
  WVObserverRecord mooring;
  mooring.identifier = "mooring";
  mooring.name = "central";
  mooring.typeIdentifier = "WVMooring";
  mooring.fieldNames = {"u", "eta"};
  mooring.x = {-1.0, 8000.0};
  mooring.y = {6000.0, 2999.0};
  record.observers.push_back(mooring);
  WVObserverRecord particles;
  particles.identifier = "particles";
  particles.name = "drifters";
  particles.typeIdentifier = "WVLagrangianParticles";
  particles.stateBlockIdentifiers = {"particle-x", "particle-y"};
  particles.fieldNames = {"u", "rho_e"};
  particles.x = {-10.0, 8100.0};
  particles.y = {20.0, -30.0};
  particles.z = {-200.0, -600.0};
  particles.isXYOnly = true;
  particles.horizontalAbsoluteTolerance = 1e-5;
  particles.trackedFieldInterpolation = WVPositionInterpolation::spline;
  record.observers.push_back(particles);
  WVObserverRecord diagnostic;
  diagnostic.identifier = "point-diagnostic";
  diagnostic.name = "diagnostic";
  diagnostic.typeIdentifier = "WVTestPortablePointDiagnostic";
  diagnostic.fieldNames = {"u"};
  diagnostic.x = {1000.0, 3500.0};
  diagnostic.y = {1200.0, 4200.0};
  diagnostic.z = {-250.0, -750.0};
  diagnostic.outputScale = 2.5;
  diagnostic.outputOffset = -1.25;
  record.observers.push_back(diagnostic);
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
  std::unique_ptr<WVFieldEvaluationService> sharedFields;
  status = WVFieldEvaluationService::create(
      config, std::make_unique<WVReferenceFFTEngine>(), sharedFields);
  require(static_cast<bool>(status), "shared field service creation failed");
  status = service->useFieldEvaluationService(*sharedFields);
  require(static_cast<bool>(status), "shared field service binding failed");
  const auto requireRejectedConfiguration = [&](auto mutation,
                                                const char *message) {
    auto incompatibleConfiguration = config;
    mutation(incompatibleConfiguration);
    std::unique_ptr<WVFieldEvaluationService> incompatibleFields;
    auto incompatibleStatus = WVFieldEvaluationService::create(
        incompatibleConfiguration, std::make_unique<WVReferenceFFTEngine>(),
        incompatibleFields);
    require(static_cast<bool>(incompatibleStatus),
            "incompatible field service construction failed");
    incompatibleStatus =
        service->useFieldEvaluationService(*incompatibleFields);
    require(incompatibleStatus.code ==
                WVKernelStatusCode::invalidConfiguration,
            message);
  };
  requireRejectedConfiguration(
      [](auto &value) { value.planetaryRadius += 1.0; },
      "borrowed field service accepted a different planetary radius");
  requireRejectedConfiguration(
      [](auto &value) { value.rotationRate += 1e-8; },
      "borrowed field service accepted a different rotation rate");
  requireRejectedConfiguration(
      [](auto &value) { value.latitude += 1.0; },
      "borrowed field service accepted a different latitude");
  require(service->metrics().uniqueFieldOutputCount == 5,
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
  WVOutputEvent event;
  event.eventOrdinal = 2;
  event.scheduledTime = 3.0;
  event.state.waveVortex = owned.view();
  WVAdditionalStateBlockLayout xLayout;
  xLayout.identifier = "particle-x";
  xLayout.scalarType = WVStateScalarType::real64;
  xLayout.elementCount = 2;
  WVAdditionalStateBlockLayout yLayout = xLayout;
  yLayout.identifier = "particle-y";
  const std::array<double, 2> particleX{{-10.0, 8100.0}};
  const std::array<double, 2> particleY{{20.0, -30.0}};
  const std::array<WVAdditionalStateBlockConstView, 2> particleBlocks{{
      {&xLayout, particleX.data(), nullptr},
      {&yLayout, particleY.data(), nullptr}}};
  event.state.additionalBlocks = particleBlocks.data();
  event.state.additionalBlockCount = particleBlocks.size();
  status = service->prepare(event);
  require(static_cast<bool>(status), "observer preparation failed");
  require(service->metrics().fieldEvaluationCount == (linear ? 3U : 2U),
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

  status = service->specifications(observers.observers()[4], specifications);
  require(static_cast<bool>(status), "particle specification query failed");
  const auto particleU = find(specifications, "u");
  require(particleU.name == "drifters_u" &&
              particleU.dimensions == std::vector<std::size_t>({2}) &&
              particleU.attributes.size() == 3,
          "particle tracked-field schema mismatch");
  status = service->value(observers.observers()[4], particleU, value);
  require(static_cast<bool>(status) && value.elementCount == 2 &&
              std::isfinite(value.realData[0]) &&
              std::isfinite(value.realData[1]),
          "particle tracked-field value mismatch");

  status = service->specifications(observers.observers()[5], specifications);
  require(static_cast<bool>(status),
          "point-diagnostic specification query failed");
  const auto diagnosticU = find(specifications, "u");
  require(diagnosticU.name == "diagnostic_value" &&
              diagnosticU.dimensions == std::vector<std::size_t>({2}),
          "point-diagnostic schema mismatch");
  status = service->value(observers.observers()[5], diagnosticU, value);
  require(static_cast<bool>(status) && value.elementCount == 2,
          "point-diagnostic value failed");
  WVFieldSamplingRequest sampling;
  sampling.kind = WVFieldSamplingKind::positions;
  sampling.x = observers.observers()[5].x;
  sampling.y = observers.observers()[5].y;
  sampling.z = observers.observers()[5].z;
  WVFieldEvaluationPlan diagnosticPlan;
  status = sharedFields->createPlan({{"diagnostic-u", "u", sampling}},
                                    diagnosticPlan);
  require(static_cast<bool>(status),
          "point-diagnostic reference plan failed");
  std::array<double, 2> raw{};
  WVFieldOutputView rawView{raw.data(), raw.size()};
  status = sharedFields->evaluate(diagnosticPlan, owned.view(), &rawView, 1);
  require(static_cast<bool>(status),
          "point-diagnostic reference evaluation failed");
  for (std::size_t index = 0; index < raw.size(); ++index)
    require(std::abs(value.realData[index] - (2.5 * raw[index] - 1.25)) < 1e-12,
            "point-diagnostic affine output changed");
  WVOutputObserverView routedObserver{
      1, &observers.observers()[1],
      observers.implementation(observers.observers()[1])};
  WVOutputRouteView passiveRoute;
  passiveRoute.observers = &routedObserver;
  passiveRoute.observerCount = 1;
  event.eventOrdinal = 3;
  event.routes = &passiveRoute;
  event.routeCount = 1;
  status = service->prepare(event);
  require(static_cast<bool>(status) &&
              service->metrics().skippedParticleEvaluationCount == 1,
          "route-aware preparation evaluated unrouted particles");
}

} // namespace

int main() {
  try {
    require(static_cast<bool>(WVObserverFactoryRegistry::registerImplementation(
                std::make_shared<WVTestPortablePointDiagnosticImplementation>())),
            "point-diagnostic registration failed");
    testService(false);
    testService(true);
    std::cout << "Passive observer output evaluation contracts passed.\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
