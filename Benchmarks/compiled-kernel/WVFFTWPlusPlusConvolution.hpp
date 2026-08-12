#pragma once

#include "WaveVortexKernel/WVHorizontalConvolutionEngine.hpp"

#include <cstddef>
#include <memory>
#include <string>

namespace wavevortex {

class WVFFTWPlusPlusConvolutionFactory final : public WVHorizontalConvolutionFactory {
public:
    WVFFTWPlusPlusConvolutionFactory(std::string variant, std::size_t threadCount);
    WVKernelStatus create(const WVTransformConstantStratificationDescriptor& descriptor, std::unique_ptr<WVHorizontalConvolutionEngine>& engine) override;

private:
    std::string variant_;
    std::size_t threadCount_ = 1;
};

} // namespace wavevortex
