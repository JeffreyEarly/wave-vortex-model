#pragma once

#include "WaveVortexRuntime/WVModel.hpp"

namespace wavevortex::runtime::detail {

// Runtime-owned adapters use this source-private boundary when they need
// services below WVModel's stable façade. It is intentionally unavailable to
// source-linked extensions through the public include tree.
class WVModelInternalAccess final {
public:
  static WVConstantStratificationIntegrationSystem &
  integrationSystem(WVModel &model) noexcept;
  static WVTimeIntegrator &integrator(WVModel &model) noexcept;
};

} // namespace wavevortex::runtime::detail
