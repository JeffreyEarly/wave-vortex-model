#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"

#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <iostream>
#include <memory>
#include <numeric>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

void require(bool condition, const std::string &message) {
  if (!condition)
    throw std::runtime_error(message);
}

void requireClose(double actual, double expected, const std::string &message) {
  const double scale = std::max({1.0, std::abs(actual), std::abs(expected)});
  require(std::abs(actual - expected) <= 2.0e-12 * scale, message);
}

WVTransformConstantStratificationConfiguration
configuration(std::size_t nx, std::size_t ny, bool hydrostatic,
              bool antialias) {
  WVTransformConstantStratificationConfiguration value;
  value.Nx = nx;
  value.Ny = ny;
  value.Nz = 7;
  value.Nj = 6;
  value.Lx = 15000.0;
  value.Ly = 12000.0;
  value.Lz = 1300.0;
  value.N0 = 5.2e-3;
  value.rho0 = 1025.0;
  value.g = 9.81;
  value.planetaryRadius = 6.371e6;
  value.rotationRate = 7.2921e-5;
  value.latitude = 33.0;
  value.isHydrostatic = hydrostatic;
  value.shouldAntialias = antialias;
  return value;
}

struct OwnedState {
  WVShape2D shape;
  std::vector<WVComplex64> Ap;
  std::vector<WVComplex64> Am;
  std::vector<WVComplex64> A0;

  WVState view(double t = 37.25, double t0 = -3.5) const noexcept {
    return {t,
            t0,
            {{Ap.data(), shape}, {Am.data(), shape}, {A0.data(), shape}}};
  }
};

OwnedState stateFor(
    const WVTransformConstantStratificationConfiguration &configuration) {
  WVTransformConstantStratificationDescriptor descriptor;
  const auto status = WVTransformConstantStratificationDescriptor::create(
      configuration, descriptor);
  require(static_cast<bool>(status), "unable to create state descriptor");
  OwnedState state;
  state.shape = descriptor.spectralShape();
  const auto count = state.shape.elementCount();
  state.Ap.resize(count);
  state.Am.resize(count);
  state.A0.resize(count);
  for (std::size_t index = 0; index < count; ++index) {
    const double value = static_cast<double>(index + 1);
    state.Ap[index] = {2.3e-3 * std::sin(0.37 * value),
                       -1.7e-3 * std::cos(0.19 * value)};
    state.Am[index] = {-1.1e-3 * std::cos(0.23 * value),
                       1.9e-3 * std::sin(0.41 * value)};
    state.A0[index] = {1.3e-3 * std::sin(0.29 * value),
                       0.7e-3 * std::cos(0.31 * value)};
  }
  return state;
}

WVFieldRequest full(std::string name) {
  return {"full_" + name, std::move(name), {}};
}

std::size_t outputIndex(const WVFieldEvaluationPlan &plan,
                        const std::string &identifier) {
  const auto &outputs = plan.outputs();
  const auto iterator =
      std::find_if(outputs.begin(), outputs.end(), [&](const auto &output) {
        return output.identifier == identifier;
      });
  require(iterator != outputs.end(), "missing output " + identifier);
  return static_cast<std::size_t>(iterator - outputs.begin());
}

class WrappedPlan final : public WVFFTPlan {
public:
  WrappedPlan(std::unique_ptr<WVFFTPlan> plan,
              std::shared_ptr<std::size_t> active)
      : plan_(std::move(plan)), active_(std::move(active)) {
    ++*active_;
  }
  ~WrappedPlan() override { --*active_; }
  WVKernelStatus execute(const void *input, void *output) override {
    return plan_->execute(input, output);
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this) + plan_->persistentBytes();
  }

private:
  std::unique_ptr<WVFFTPlan> plan_;
  std::shared_ptr<std::size_t> active_;
};

class CountingEngine final : public WVFFTEngine {
public:
  explicit CountingEngine(std::shared_ptr<std::size_t> active)
      : active_(std::move(active)) {}
  std::string identifier() const override { return "counting-reference"; }
  WVKernelStatus createPlan(const WVFFTPlanSpecification &specification,
                            std::unique_ptr<WVFFTPlan> &plan) override {
    std::unique_ptr<WVFFTPlan> referencePlan;
    auto status = reference_.createPlan(specification, referencePlan);
    if (!status)
      return status;
    plan = std::make_unique<WrappedPlan>(std::move(referencePlan), active_);
    return WVKernelStatus::ok();
  }

private:
  WVReferenceFFTEngine reference_;
  std::shared_ptr<std::size_t> active_;
};

class FailurePlan final : public WVFFTPlan {
public:
  WVKernelStatus execute(const void *, void *) override {
    return {WVKernelStatusCode::fftExecutionFailure,
            "injected field-evaluation FFT failure"};
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }
};

class FailureEngine final : public WVFFTEngine {
public:
  explicit FailureEngine(WVKernelStatusCode creationCode)
      : creationCode_(creationCode) {}
  std::string identifier() const override { return "failure-injection"; }
  WVKernelStatus createPlan(const WVFFTPlanSpecification &,
                            std::unique_ptr<WVFFTPlan> &plan) override {
    if (creationCode_ != WVKernelStatusCode::success)
      return {creationCode_, "injected field-evaluation planning failure"};
    plan = std::make_unique<FailurePlan>();
    return WVKernelStatus::ok();
  }

private:
  WVKernelStatusCode creationCode_;
};

void verifyCatalog() {
  const std::vector<std::string> expected = {
      "u",       "v",         "w",       "eta",    "pi",
      "p",       "psi",       "qgpv",    "rho_e",  "rho_total",
      "rho_bar", "zeta_x",    "zeta_y",  "zeta_z", "ssu",
      "ssv",     "ssh",       "energy",  "uvMax",  "wMax"};
  require(WVFieldEvaluationService::supportedFieldNames() == expected,
          "field catalog changed");
}

void verifyPlanValidation() {
  std::unique_ptr<WVFieldEvaluationService> service;
  auto status = WVFieldEvaluationService::create(
      configuration(6, 5, true, true),
      std::make_unique<WVReferenceFFTEngine>(), service);
  require(static_cast<bool>(status), "validation service creation failed");
  WVFieldEvaluationPlan plan;
  status = service->createPlan({{"bad", "not_a_field", {}}}, plan);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "unknown field was accepted");
  status = service->createPlan({full("u"), {"full_u", "v", {}}}, plan);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "duplicate identifier was accepted");
  WVFieldSamplingRequest profiles;
  profiles.kind = WVFieldSamplingKind::fixedVerticalProfiles;
  profiles.xIndices = {0};
  profiles.yIndices = {1};
  status = service->createPlan({{"profile", "u", profiles}}, plan);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "zero-based profile index was accepted");
  WVFieldSamplingRequest positions;
  positions.kind = WVFieldSamplingKind::positions;
  positions.x = {0.0};
  positions.y = {0.0};
  positions.z = {0.0};
  status = service->createPlan({{"energy_at_position", "energy", positions}},
                               plan);
  require(status.code == WVKernelStatusCode::invalidConfiguration,
          "scalar position sampling was accepted");

  auto equatorial = configuration(6, 5, true, true);
  equatorial.latitude = 0.0;
  status = WVFieldEvaluationService::create(
      equatorial, std::make_unique<WVReferenceFFTEngine>(), service);
  require(static_cast<bool>(status), "equatorial service creation failed");
  status = service->createPlan({full("psi")}, plan);
  require(status.code == WVKernelStatusCode::unsupportedOperation,
          "undefined equatorial streamfunction was not rejected by planning");
}

void verifyFailureAndLifecycleContracts() {
  const auto config = configuration(6, 5, false, false);
  std::unique_ptr<WVFieldEvaluationService> service;
  auto status = WVFieldEvaluationService::create(
      config,
      std::make_unique<FailureEngine>(WVKernelStatusCode::allocationFailure),
      service);
  require(status.code == WVKernelStatusCode::allocationFailure,
          "allocation failure was not propagated");
  status = WVFieldEvaluationService::create(
      config, std::make_unique<FailureEngine>(WVKernelStatusCode::success),
      service);
  require(static_cast<bool>(status), "execution-failure service creation failed");
  WVFieldEvaluationPlan plan;
  status = service->createPlan({full("u")}, plan);
  require(static_cast<bool>(status), "execution-failure plan creation failed");
  const auto state = stateFor(config);
  std::vector<double> output(plan.outputs()[0].elementCount, 19.0);
  WVFieldOutputView view{output.data(), output.size()};
  status = service->evaluate(plan, state.view(), &view, 1);
  require(status.code == WVKernelStatusCode::fftExecutionFailure,
          "FFT execution failure was not propagated");

  const auto activePlans = std::make_shared<std::size_t>(0);
  status = WVFieldEvaluationService::create(
      config, std::make_unique<CountingEngine>(activePlans), service);
  require(static_cast<bool>(status), "counting service creation failed");
  require(*activePlans > 0, "service did not retain its private FFT plans");
  service.reset();
  require(*activePlans == 0, "service destruction leaked FFT plans");
}

void verifyEvaluation(std::size_t nx, std::size_t ny, bool hydrostatic,
                      bool antialias) {
  const auto config = configuration(nx, ny, hydrostatic, antialias);
  std::unique_ptr<WVFieldEvaluationService> service;
  auto status = WVFieldEvaluationService::create(
      config, std::make_unique<WVReferenceFFTEngine>(), service);
  require(static_cast<bool>(status), "field service creation failed");

  std::vector<WVFieldRequest> requests;
  for (const auto &name : WVFieldEvaluationService::supportedFieldNames())
    requests.push_back(full(name));
  WVFieldSamplingRequest profiles;
  profiles.kind = WVFieldSamplingKind::fixedVerticalProfiles;
  profiles.xIndices = {1, nx};
  profiles.yIndices = {1, ny};
  requests.push_back({"u_profiles", "u", profiles});

  const double dx = config.Lx / static_cast<double>(nx);
  const double dy = config.Ly / static_cast<double>(ny);
  const double dz = config.Lz / static_cast<double>(config.Nz - 1);
  WVFieldSamplingRequest linear;
  linear.kind = WVFieldSamplingKind::positions;
  linear.interpolation = WVPositionInterpolation::linear;
  linear.x = {0.35 * dx, config.Lx + 0.35 * dx, 2.0 * dx};
  linear.y = {0.6 * dy, -config.Ly + 0.6 * dy, 3.0 * dy};
  linear.z = {-config.Lz + 1.4 * dz, -config.Lz + 1.4 * dz,
              -config.Lz + 2.0 * dz};
  requests.push_back({"u_linear", "u", linear});
  WVFieldSamplingRequest spline = linear;
  spline.interpolation = WVPositionInterpolation::spline;
  requests.push_back({"u_spline", "u", spline});

  WVFieldEvaluationPlan plan;
  status = service->createPlan(requests, plan);
  require(static_cast<bool>(status), "field plan creation failed: " + status.message);
  require(plan.outputCount() == requests.size(), "wrong plan output count");
  const auto planBytes = plan.persistentBytes();
  require(planBytes > sizeof(plan), "plan storage metric omitted payloads");

  std::vector<std::vector<double>> storage;
  std::vector<WVFieldOutputView> views;
  storage.reserve(plan.outputCount());
  views.reserve(plan.outputCount());
  std::size_t expectedWrites = 0;
  for (const auto &output : plan.outputs()) {
    storage.emplace_back(output.elementCount, -9.87654321e250);
    expectedWrites += output.elementCount;
  }
  for (auto &output : storage)
    views.push_back({output.data(), output.size()});
  const auto state = stateFor(config);
  status = service->evaluate(plan, state.view(), views.data(), views.size());
  require(static_cast<bool>(status), "field evaluation failed: " + status.message);
  for (const auto &output : storage)
    require(std::none_of(output.begin(), output.end(), [](double value) {
              return value == -9.87654321e250;
            }),
            "field evaluation left caller-owned elements unwritten");

  const auto &u = storage[outputIndex(plan, "full_u")];
  const auto &v = storage[outputIndex(plan, "full_v")];
  const auto &w = storage[outputIndex(plan, "full_w")];
  const auto &eta = storage[outputIndex(plan, "full_eta")];
  const auto &piField = storage[outputIndex(plan, "full_pi")];
  const auto &pressure = storage[outputIndex(plan, "full_p")];
  const auto &rhoE = storage[outputIndex(plan, "full_rho_e")];
  const auto &rhoTotal = storage[outputIndex(plan, "full_rho_total")];
  const auto &rhoBar = storage[outputIndex(plan, "full_rho_bar")];
  const auto &ssu = storage[outputIndex(plan, "full_ssu")];
  const auto &ssv = storage[outputIndex(plan, "full_ssv")];
  const auto &ssh = storage[outputIndex(plan, "full_ssh")];
  const auto horizontalCount = nx * ny;
  const auto fieldCount = horizontalCount * config.Nz;
  const double densityScale = config.rho0 * config.N0 * config.N0 / config.g;
  for (std::size_t index = 0; index < fieldCount; ++index) {
    requireClose(pressure[index], config.rho0 * config.g * piField[index],
                 "pressure scaling mismatch");
    requireClose(rhoE[index], densityScale * eta[index],
                 "density anomaly scaling mismatch");
  }
  for (std::size_t z = 0; z < config.Nz; ++z) {
    const double zCoordinate = -config.Lz + dz * static_cast<double>(z);
    double meanEta = 0.0;
    for (std::size_t horizontal = 0; horizontal < horizontalCount;
         ++horizontal) {
      const auto index = horizontal + horizontalCount * z;
      meanEta += eta[index];
      requireClose(rhoTotal[index],
                   config.rho0 - densityScale * zCoordinate +
                       densityScale * eta[index],
                   "total density mismatch");
    }
    meanEta /= static_cast<double>(horizontalCount);
    requireClose(rhoBar[z],
                 config.rho0 - densityScale * zCoordinate +
                     densityScale * meanEta,
                 "mean density mismatch");
  }
  const auto surfaceOffset = fieldCount - horizontalCount;
  for (std::size_t index = 0; index < horizontalCount; ++index) {
    requireClose(ssu[index], u[surfaceOffset + index],
                 "surface u mismatch");
    requireClose(ssv[index], v[surfaceOffset + index],
                 "surface v mismatch");
    requireClose(ssh[index], piField[surfaceOffset + index],
                 "surface height mismatch");
  }
  double expectedUVMax = 0.0;
  double expectedWMax = 0.0;
  for (std::size_t index = 0; index < fieldCount; ++index) {
    expectedUVMax = std::max(
        expectedUVMax, std::sqrt(u[index] * u[index] + v[index] * v[index]));
    expectedWMax = std::max(expectedWMax, std::abs(w[index]));
  }
  requireClose(storage[outputIndex(plan, "full_uvMax")][0], expectedUVMax,
               "uvMax mismatch");
  requireClose(storage[outputIndex(plan, "full_wMax")][0], expectedWMax,
               "wMax mismatch");

  const auto &profile = storage[outputIndex(plan, "u_profiles")];
  for (std::size_t z = 0; z < config.Nz; ++z) {
    requireClose(profile[z], u[horizontalCount * z],
                 "first one-based profile mismatch");
    requireClose(profile[z + config.Nz],
                 u[(nx - 1) + nx * (ny - 1) + horizontalCount * z],
                 "last one-based profile mismatch");
  }
  const auto &linearOutput = storage[outputIndex(plan, "u_linear")];
  const auto &splineOutput = storage[outputIndex(plan, "u_spline")];
  requireClose(linearOutput[0], linearOutput[1],
               "linear horizontal wrapping mismatch");
  requireClose(splineOutput[0], splineOutput[1],
               "spline horizontal wrapping mismatch");
  requireClose(linearOutput[2],
               u[2 + nx * 3 + horizontalCount * 2],
               "linear interpolation did not reproduce a grid knot");
  requireClose(splineOutput[2],
               u[2 + nx * 3 + horizontalCount * 2],
               "spline interpolation did not reproduce a grid knot");

  std::unique_ptr<WVTransformConstantStratificationKernel> derivativeKernel;
  status = WVTransformConstantStratificationKernel::create(
      config, std::make_unique<WVReferenceFFTEngine>(), derivativeKernel);
  require(static_cast<bool>(status), "derivative reference creation failed");
  std::vector<double> derivatives(3 * fieldCount);
  std::vector<double> expectedZetaX(fieldCount, 0.0);
  std::vector<double> expectedZetaY(fieldCount, 0.0);
  std::vector<double> expectedZetaZ(fieldCount, 0.0);
  WVRealFieldBundleView derivativeView{
      derivatives.data(), {nx, ny, config.Nz, 3}};
  status = derivativeKernel->transformStateFieldDerivatives(
      state.view(), WVDynamicalField::u, derivativeView);
  require(static_cast<bool>(status), "u derivative reference failed");
  for (std::size_t index = 0; index < fieldCount; ++index) {
    expectedZetaY[index] += derivatives[2 * fieldCount + index];
    expectedZetaZ[index] -= derivatives[fieldCount + index];
  }
  status = derivativeKernel->transformStateFieldDerivatives(
      state.view(), WVDynamicalField::v, derivativeView);
  require(static_cast<bool>(status), "v derivative reference failed");
  for (std::size_t index = 0; index < fieldCount; ++index) {
    expectedZetaX[index] -= derivatives[2 * fieldCount + index];
    expectedZetaZ[index] += derivatives[index];
  }
  status = derivativeKernel->transformStateFieldDerivatives(
      state.view(), WVDynamicalField::w, derivativeView);
  require(static_cast<bool>(status), "w derivative reference failed");
  for (std::size_t index = 0; index < fieldCount; ++index) {
    expectedZetaX[index] += derivatives[fieldCount + index];
    expectedZetaY[index] -= derivatives[index];
  }
  const auto &zetaX = storage[outputIndex(plan, "full_zeta_x")];
  const auto &zetaY = storage[outputIndex(plan, "full_zeta_y")];
  const auto &zetaZ = storage[outputIndex(plan, "full_zeta_z")];
  for (std::size_t index = 0; index < fieldCount; ++index) {
    requireClose(zetaX[index], expectedZetaX[index], "zeta_x mismatch");
    requireClose(zetaY[index], expectedZetaY[index], "zeta_y mismatch");
    requireClose(zetaZ[index], expectedZetaZ[index], "zeta_z mismatch");
  }

  const auto firstOutputs = storage;
  status = service->evaluate(plan, state.view(), views.data(), views.size());
  require(static_cast<bool>(status), "repeated evaluation failed");
  require(storage == firstOutputs, "repeated evaluation changed exact outputs");
  require(plan.persistentBytes() == planBytes,
          "evaluation mutated immutable plan storage");
  const auto &metrics = service->metrics();
  const auto coefficientCount = state.shape.elementCount();
  const auto expectedCapacity =
      6 * fieldCount * sizeof(double) +
      2 * coefficientCount * sizeof(WVComplex64);
  const auto expectedHighWater = std::max(
      6 * fieldCount * sizeof(double),
      5 * fieldCount * sizeof(double) +
          2 * coefficientCount * sizeof(WVComplex64));
  require(metrics.evaluationCount == 2, "wrong repeated evaluation count");
  require(metrics.coincidentBatchCount == 2, "wrong coincident batch count");
  require(metrics.transformCount == 14, "coincident transforms were not reused");
  require(metrics.primitiveFieldEvaluationCount == 20,
          "wrong primitive evaluation count");
  require(metrics.primitiveFieldReuseCount >= 6,
          "repeated field consumers did not register reuse");
  require(metrics.outputElementWriteCount == 2 * expectedWrites,
          "output write metric is not exact");
  require(metrics.scratchCapacityBytes == expectedCapacity,
          "scratch capacity metric is not exact");
  require(metrics.scratchHighWaterBytes == expectedHighWater,
          "scratch high-water metric is not exact");
  require(metrics.lastPlanBytes == planBytes &&
              metrics.maximumPlanBytes == planBytes,
          "plan storage metrics are not exact");
  require(metrics.servicePersistentBytes == service->persistentBytes(),
          "service persistent storage metric is not exact");
  require(metrics.scratchHighWaterBytes <= metrics.scratchCapacityBytes,
          "scratch high-water exceeds bounded capacity");

  WVFieldOutputView badShape{views[0].data, views[0].elementCount - 1};
  status = service->evaluate(plan, state.view(), &badShape, 1);
  require(status.code == WVKernelStatusCode::invalidShape,
          "wrong output-view count/shape was accepted");
  std::vector<WVFieldOutputView> overlapping = views;
  overlapping[1].data = overlapping[0].data;
  status = service->evaluate(plan, state.view(), overlapping.data(),
                             overlapping.size());
  require(status.code == WVKernelStatusCode::overlappingArrays,
          "overlapping outputs were accepted");
}

} // namespace

int main() {
  try {
    verifyCatalog();
    verifyPlanValidation();
    verifyFailureAndLifecycleContracts();
    verifyEvaluation(6, 5, true, true);
    verifyEvaluation(7, 6, false, false);
    std::cout << "WVFieldEvaluationService portable contracts passed: "
                 "hydrostatic/nonhydrostatic, odd/even, antialiasing, "
                 "zero/Nyquist, wrapping, profiles, linear/spline, reuse, "
                 "storage, lifecycle, and failures.\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
