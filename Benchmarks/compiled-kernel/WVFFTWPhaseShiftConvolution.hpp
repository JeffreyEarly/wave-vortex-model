#pragma once

#include "WaveVortexKernel/WVHorizontalConvolutionEngine.hpp"

#include <cstddef>
#include <memory>

namespace wavevortex {

struct WVPhaseShiftLifetimeMetrics {
    std::size_t activePlans = 0;
    std::size_t totalPlansCreated = 0;
    std::size_t totalPlansDestroyed = 0;
};

class WVFFTWPhaseShiftConvolutionFactory final : public WVHorizontalConvolutionFactory {
public:
    explicit WVFFTWPhaseShiftConvolutionFactory(std::size_t threadCount);
    WVKernelStatus create(const WVTransformConstantStratificationDescriptor& descriptor, std::unique_ptr<WVHorizontalConvolutionEngine>& engine) override;
    static WVPhaseShiftLifetimeMetrics lifetimeMetrics() noexcept;

private:
    std::size_t threadCount_ = 1;
};

} // namespace wavevortex
