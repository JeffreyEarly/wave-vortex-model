#pragma once

#include "WVFFTEngine.hpp"

namespace wavevortex {

class WVTransformConstantStratificationKernel {
public:
    virtual ~WVTransformConstantStratificationKernel() = default;
    WVTransformConstantStratificationKernel(const WVTransformConstantStratificationKernel&) = delete;
    WVTransformConstantStratificationKernel& operator=(const WVTransformConstantStratificationKernel&) = delete;
    WVTransformConstantStratificationKernel(WVTransformConstantStratificationKernel&&) = delete;
    WVTransformConstantStratificationKernel& operator=(WVTransformConstantStratificationKernel&&) = delete;

    virtual const WVTransformConstantStratificationDescriptor& descriptor() const noexcept = 0;
    virtual std::size_t persistentBytes() const noexcept = 0;
    virtual std::size_t scratchBytes() const noexcept = 0;
    virtual WVKernelStatus nonlinearFluxWithGradientMasks(const WVState& state, const WVGradientMasks& masks, WVFlux& flux) = 0;

protected:
    WVTransformConstantStratificationKernel() = default;
};

} // namespace wavevortex

