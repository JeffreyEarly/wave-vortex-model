#pragma once

#include "WaveVortexRuntime/WVIntegrationContracts.hpp"
#include "WaveVortexKernel/WVTransformBarotropicQGKernel.hpp"

#include <memory>

namespace wavevortex::runtime {

// Allocation-light numerical record decoded by a transform-specific
// persistence adapter before compact coefficient storage is loaded. A later
// composition layer may connect it to NetCDF without changing this API.
struct WVBarotropicQGPersistedNumericalRecord {
  std::vector<double> x;
  std::vector<double> y;
  double Lx = 0.0;
  double Ly = 0.0;
  double h = 0.0;
  std::uint32_t j = 1;
  double g = 0.0;
  double planetaryRadius = 0.0;
  double rotationRate = 0.0;
  double latitude = 0.0;
  bool shouldAntialias = true;
  double t = 0.0;
  double t0 = 0.0;
};

struct WVBarotropicQGNumericalConfiguration {
  WVTransformBarotropicQGConfiguration transform;
  WVTransformStateDescription stateDescription;
  double t = 0.0;
  double t0 = 0.0;
  std::size_t persistentBytes() const noexcept;
};

WVKernelStatus decodeBarotropicQGNumericalConfiguration(
    const WVBarotropicQGPersistedNumericalRecord &record,
    WVBarotropicQGNumericalConfiguration &configuration);

// Transform-specific numerical system over the #279 coefficient-family
// boundary. It owns only the compact A0 family declared by stateLayout().
class WVBarotropicQGIntegrationSystem final : public WVIntegrationSystem {
public:
  static WVKernelStatus create(
      const WVTransformBarotropicQGConfiguration &configuration,
      std::unique_ptr<WVFFTEngine> engine,
      std::unique_ptr<WVBarotropicQGIntegrationSystem> &system);

  ~WVBarotropicQGIntegrationSystem() override = default;
  WVBarotropicQGIntegrationSystem(const WVBarotropicQGIntegrationSystem &) =
      delete;
  WVBarotropicQGIntegrationSystem &operator=(
      const WVBarotropicQGIntegrationSystem &) = delete;

  const WVIntegrationStateLayout &stateLayout() const noexcept override {
    return layout_;
  }
  WVKernelStatus evaluateRightHandSide(
      const WVIntegrationState &state,
      WVIntegrationFlux &rightHandSide) override;
  WVStateConstraintResult enforceStateConstraints(
      WVMutableIntegrationState &state) override;
  WVKernelStatus createErrorPolicy(
      double absoluteToleranceScale,
      std::unique_ptr<WVIntegrationErrorPolicy> &policy) const override;
  std::size_t persistentBytes() const noexcept override;

  const WVTransformBarotropicQGKernel &kernel() const noexcept {
    return *kernel_;
  }
  WVTransformBarotropicQGKernel &kernel() noexcept { return *kernel_; }

private:
  WVBarotropicQGIntegrationSystem() = default;
  WVIntegrationStateLayout layout_;
  std::unique_ptr<WVTransformBarotropicQGKernel> kernel_;
  bool executing_ = false;
};

} // namespace wavevortex::runtime
