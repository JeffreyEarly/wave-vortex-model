#include "WaveVortexRuntime/WVBarotropicQGIntegrationSystem.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
#include <utility>
#include <vector>

namespace wavevortex::runtime {
namespace {

template <typename T>
std::size_t vectorBytes(const std::vector<T> &values) noexcept {
  return values.capacity() * sizeof(T);
}

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

bool validCoordinate(const std::vector<double> &coordinate,
                     double length) noexcept {
  if (coordinate.size() < 2 || !std::isfinite(length) || length <= 0.0)
    return false;
  const double spacing = length / static_cast<double>(coordinate.size());
  const double scale = std::max(1.0, std::abs(length));
  const double tolerance =
      64.0 * std::numeric_limits<double>::epsilon() * scale;
  for (std::size_t index = 0; index < coordinate.size(); ++index) {
    if (!std::isfinite(coordinate[index]) ||
        (index > 0 && !(coordinate[index] > coordinate[index - 1])) ||
        std::abs(coordinate[index] - spacing * static_cast<double>(index)) >
            tolerance)
      return false;
  }
  return true;
}

class BarotropicQGErrorPolicy final : public WVIntegrationErrorPolicy {
public:
  static WVKernelStatus create(
      const WVTransformBarotropicQGDescriptor &descriptor,
      double absoluteToleranceScale,
      std::unique_ptr<WVIntegrationErrorPolicy> &result) {
    result.reset();
    if (!std::isfinite(absoluteToleranceScale) ||
        absoluteToleranceScale <= 0.0)
      return invalid(
          "Adaptive absolute-tolerance scale must be finite and positive.");
    try {
      auto policy = std::unique_ptr<BarotropicQGErrorPolicy>(
          new BarotropicQGErrorPolicy());
      const auto &horizontal = descriptor.fourierModes();
      policy->tolerances_.assign(horizontal.size(), 1.0);
      std::vector<double> uniqueKh;
      uniqueKh.reserve(horizontal.size());
      for (const auto &mode : horizontal)
        uniqueKh.push_back(std::abs(mode.Kh));
      std::sort(uniqueKh.begin(), uniqueKh.end());
      uniqueKh.erase(std::unique(uniqueKh.begin(), uniqueKh.end()),
                     uniqueKh.end());
      if (uniqueKh.size() < 2)
        return invalid("Adaptive Barotropic QG tolerances require at least "
                       "two horizontal radial wavenumbers.");
      double deltaK = 0.0;
      for (std::size_t index = 1; index < uniqueKh.size(); ++index)
        deltaK = std::max(deltaK, uniqueKh[index] - uniqueKh[index - 1]);
      if (!(deltaK > 0.0) || !std::isfinite(deltaK))
        return invalid("Adaptive Barotropic QG radial spacing is invalid.");
      std::vector<double> centers;
      for (double center = 0.0;
           center <= uniqueKh.back() + 0.5 * deltaK; center += deltaK)
        centers.push_back(center);
      std::vector<std::size_t> bins(horizontal.size(), centers.size());
      std::vector<std::size_t> counts(centers.size(), 0);
      for (std::size_t mode = 0; mode < horizontal.size(); ++mode) {
        for (std::size_t bin = 0; bin < centers.size(); ++bin) {
          if (centers[bin] - 0.5 * deltaK < horizontal[mode].Kh &&
              horizontal[mode].Kh <= centers[bin] + 0.5 * deltaK) {
            bins[mode] = bin;
            ++counts[bin];
            break;
          }
        }
        if (bins[mode] == centers.size())
          return invalid("A Barotropic QG mode was not assigned to an "
                         "adaptive radial bin.");
      }
      const auto &energy = descriptor.modes().energyFactor;
      for (std::size_t mode = 0; mode < horizontal.size(); ++mode) {
        if (!(energy[mode] > 0.0) || !std::isfinite(energy[mode]))
          continue;
        const auto bin = bins[mode];
        const double radialEnergy =
            centers[bin] + 0.5 * deltaK -
            std::max(centers[bin] - 0.5 * deltaK, 0.0);
        const double energyPerCoefficient =
            radialEnergy / static_cast<double>(counts[bin]);
        policy->tolerances_[mode] =
            absoluteToleranceScale *
            std::sqrt(energyPerCoefficient / energy[mode]);
      }
      result = std::move(policy);
      return WVKernelStatus::ok();
    } catch (const std::bad_alloc &) {
      return {WVKernelStatusCode::allocationFailure,
              "Unable to allocate Barotropic QG adaptive tolerances."};
    }
  }

  std::size_t componentCount() const noexcept override { return 1; }
  std::size_t elementCount(std::size_t component) const noexcept override {
    return component == 0 ? tolerances_.size() : 0;
  }
  double absoluteTolerance(std::size_t component,
                           std::size_t index) const noexcept override {
    return component == 0 && index < tolerances_.size()
               ? tolerances_[index]
               : std::numeric_limits<double>::quiet_NaN();
  }
  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this) + vectorBytes(tolerances_);
  }

private:
  std::vector<double> tolerances_;
};

} // namespace

std::size_t
WVBarotropicQGNumericalConfiguration::persistentBytes() const noexcept {
  std::size_t bytes = sizeof(*this) +
                      stateDescription.transformIdentifier.capacity() +
                      vectorBytes(stateDescription.spatialDimensions) +
                      stateDescription.coefficientFamilies.capacity() *
                          sizeof(WVCoefficientFamilyDescription);
  for (const auto &family : stateDescription.coefficientFamilies)
    bytes += family.identifier.capacity() +
             vectorBytes(family.spectralDimensions);
  return bytes;
}

WVKernelStatus decodeBarotropicQGNumericalConfiguration(
    const WVBarotropicQGPersistedNumericalRecord &record,
    WVBarotropicQGNumericalConfiguration &configuration) {
  if (!validCoordinate(record.x, record.Lx) ||
      !validCoordinate(record.y, record.Ly))
    return invalid("Persisted Barotropic QG x and y coordinates must be "
                   "finite, strictly increasing, uniformly periodic axes.");
  if (!std::isfinite(record.t) || !std::isfinite(record.t0))
    return invalid("Persisted Barotropic QG times must be finite.");
  WVTransformBarotropicQGConfiguration transform;
  transform.Nx = record.x.size();
  transform.Ny = record.y.size();
  transform.Lx = record.Lx;
  transform.Ly = record.Ly;
  transform.h = record.h;
  transform.j = record.j;
  transform.g = record.g;
  transform.planetaryRadius = record.planetaryRadius;
  transform.rotationRate = record.rotationRate;
  transform.latitude = record.latitude;
  transform.shouldAntialias = record.shouldAntialias;
  WVTransformBarotropicQGDescriptor descriptor;
  auto status = WVTransformBarotropicQGDescriptor::create(transform,
                                                           descriptor);
  if (!status)
    return status;
  try {
    WVBarotropicQGNumericalConfiguration candidate;
    candidate.transform = transform;
    candidate.t = record.t;
    candidate.t0 = record.t0;
    candidate.stateDescription = {
        "WVTransformBarotropicQG", {transform.Nx, transform.Ny},
        {{"A0", {descriptor.Nkl()},
          WVToleranceKind::coefficientEnergyScaled}}};
    configuration = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to retain decoded Barotropic QG configuration."};
  }
}

WVKernelStatus WVBarotropicQGIntegrationSystem::create(
    const WVTransformBarotropicQGConfiguration &configuration,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVBarotropicQGIntegrationSystem> &system) {
  std::shared_ptr<const WVExtensionCatalog> catalog;
  auto status = makeBuiltInExtensionCatalog(catalog);
  if (!status)
    return status;
  return create(configuration, defaultNonlinearAdvectionSchedule(),
                std::move(catalog), std::move(engine), system);
}

WVKernelStatus WVBarotropicQGIntegrationSystem::create(
    const WVTransformBarotropicQGConfiguration &configuration,
    const WVFrozenForcingSchedule &schedule,
    std::shared_ptr<const WVExtensionCatalog> catalog,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVBarotropicQGIntegrationSystem> &system) {
  system.reset();
  try {
    auto candidate = std::unique_ptr<WVBarotropicQGIntegrationSystem>(
        new WVBarotropicQGIntegrationSystem());
    auto status = WVBarotropicQGForcingEngine::create(
        configuration, schedule, std::move(catalog), std::move(engine),
        candidate->forcingEngine_);
    if (!status)
      return status;
    WVTransformStateDescription stateDescription{
        "WVTransformBarotropicQG", {configuration.Nx, configuration.Ny},
        {{"A0", {candidate->kernel().descriptor().Nkl()},
          WVToleranceKind::coefficientEnergyScaled}}};
    status = WVIntegrationStateLayout::createCoefficientOnly(
        std::move(stateDescription), candidate->layout_);
    if (!status)
      return status;
    system = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate the Barotropic QG integration system."};
  }
}

WVKernelStatus WVBarotropicQGIntegrationSystem::evaluateRightHandSide(
    const WVIntegrationState &state,
    WVIntegrationFlux &rightHandSide) {
  if (executing_)
    return {WVKernelStatusCode::reentrantExecution,
            "The Barotropic QG integration system is not reentrant."};
  auto status = validateIntegrationState(layout_, state);
  if (!status)
    return status;
  if (rightHandSide.coefficientFamilyCount != 1 ||
      rightHandSide.coefficientFamilies == nullptr ||
      rightHandSide.coefficientFamilies[0].layout !=
          &layout_.coefficientFamilies()[0] ||
      rightHandSide.additionalBlockCount != 0)
    return {WVKernelStatusCode::invalidShape,
            "Barotropic QG RHS storage must contain only compact F0."};
  executing_ = true;
  struct Guard {
    bool &value;
    ~Guard() { value = false; }
  } guard{executing_};
  const auto A0 = coefficientFamilyView(layout_, state, 0);
  auto F0 = coefficientFamilyView(layout_, rightHandSide, 0);
  const WVComplexConstView A0View{
      A0.data, {1, A0.layout->elementCount}};
  WVComplexView F0View{F0.data, {1, F0.layout->elementCount}};
  return forcingEngine_->evaluateRightHandSide(A0View, F0View);
}

WVStateConstraintResult
WVBarotropicQGIntegrationSystem::enforceStateConstraints(
    WVMutableIntegrationState &state) {
  const auto status = validateMutableIntegrationState(layout_, state);
  if (!status)
    return {status, 0, false};
  auto A0 = coefficientFamilyView(layout_, state, 0);
  WVComplexView A0View{A0.data, {1, A0.layout->elementCount}};
  auto result = forcingEngine_->restoreForcingAmplitudes(A0View);
  if (!result)
    return result;
  const auto realityModified = kernel().enforceReality(A0View);
  result.modifiedCoefficientCount += realityModified;
  result.fsalCompatible = result.fsalCompatible && realityModified == 0;
  return result;
}

WVKernelStatus WVBarotropicQGIntegrationSystem::createErrorPolicy(
    double absoluteToleranceScale,
    std::unique_ptr<WVIntegrationErrorPolicy> &policy) const {
  return BarotropicQGErrorPolicy::create(kernel().descriptor(),
                                         absoluteToleranceScale, policy);
}

std::size_t
WVBarotropicQGIntegrationSystem::persistentBytes() const noexcept {
  return sizeof(*this) + layout_.persistentBytes() +
         (forcingEngine_ == nullptr ? 0 : forcingEngine_->persistentBytes());
}

} // namespace wavevortex::runtime
