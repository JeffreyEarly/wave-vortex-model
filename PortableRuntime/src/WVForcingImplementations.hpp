#pragma once

#include "WaveVortexRuntime/WVForcingContracts.hpp"

namespace wavevortex::runtime::detail {

WVKernelStatus createNonlinearAdvectionForcing(
    const WVFrozenForcingEntry &,
    const WVTransformConstantStratificationDescriptor &, bool,
    std::unique_ptr<WVForcing> &);
WVKernelStatus createAdaptiveDampingForcing(
    const WVFrozenForcingEntry &,
    const WVTransformConstantStratificationDescriptor &, bool,
    std::unique_ptr<WVForcing> &);
WVKernelStatus createFixedAmplitudeForcing(
    const WVFrozenForcingEntry &,
    const WVTransformConstantStratificationDescriptor &, bool,
    std::unique_ptr<WVForcing> &);
WVKernelStatus createQuadraticBottomFriction(
    const WVFrozenForcingEntry &,
    const WVTransformConstantStratificationDescriptor &, bool,
    std::unique_ptr<WVForcing> &);
WVKernelStatus createPseudoTopographicForcing(
    const WVFrozenForcingEntry &,
    const WVTransformConstantStratificationDescriptor &, bool,
    std::unique_ptr<WVForcing> &);
WVKernelStatus createBetaPlaneForcing(
    const WVFrozenForcingEntry &,
    const WVTransformConstantStratificationDescriptor &, bool,
    std::unique_ptr<WVForcing> &);

} // namespace wavevortex::runtime::detail
