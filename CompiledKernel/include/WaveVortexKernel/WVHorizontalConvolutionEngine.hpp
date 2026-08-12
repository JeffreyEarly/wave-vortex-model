#pragma once

#include "WVKernelTypes.hpp"

#include <cstddef>
#include <memory>

namespace wavevortex {

struct WVHorizontalConvolutionGeometry {
    std::size_t maximumKMode = 0;
    std::size_t maximumLMode = 0;
    std::size_t hermitianKCount = 0;
    std::size_t centeredLCount = 0;
    std::size_t verticalLevelCount = 0;
    std::size_t inputCount = 0;
    std::size_t outputCount = 0;

    std::size_t elementsPerLevel() const noexcept { return hermitianKCount * centeredLCount; }
    std::size_t elementsPerChannel() const noexcept { return elementsPerLevel() * verticalLevelCount; }
};

struct WVHorizontalConvolutionMetrics {
    std::size_t retainedSpectrumBytes = 0;
    std::size_t exactWorkBytes = 0;
    std::size_t planWrapperLowerBoundBytes = 0;
    std::size_t opaquePlanBytes = 0;
    std::size_t executionCount = 0;
    std::size_t outerOpenMPThreads = 1;
    std::size_t maximumFFTWThreads = 1;
    std::size_t maximumObservedMultiplierThreads = 1;
    std::size_t maximumObservedOpenMPLevel = 0;
    std::size_t centeredInnerLength = 0;
    std::size_t centeredInputFactor = 0;
    std::size_t centeredPaddedFactor = 0;
    std::size_t centeredLogicalPadding = 0;
    std::size_t hermitianInnerLength = 0;
    std::size_t hermitianInputFactor = 0;
    std::size_t hermitianPaddedFactor = 0;
    std::size_t hermitianLogicalPadding = 0;
    bool workerRegionsDisjoint = true;
    double planningSeconds = 0.0;
    double executionSeconds = 0.0;
    double multiplierSeconds = 0.0;
};

class WVHorizontalConvolutionEngine {
public:
    virtual ~WVHorizontalConvolutionEngine() = default;
    virtual const char* identifier() const noexcept = 0;
    virtual const WVHorizontalConvolutionGeometry& geometry() const noexcept = 0;
    virtual WVComplex64* channelData(std::size_t channel) noexcept = 0;
    virtual const WVComplex64* channelData(std::size_t channel) const noexcept = 0;
    virtual WVKernelStatus execute() = 0;
    virtual std::size_t persistentBytes() const noexcept = 0;
    virtual WVHorizontalConvolutionMetrics metrics() const noexcept = 0;
};

class WVHorizontalConvolutionFactory {
public:
    virtual ~WVHorizontalConvolutionFactory() = default;
    virtual WVKernelStatus create(const WVTransformConstantStratificationDescriptor& descriptor, std::unique_ptr<WVHorizontalConvolutionEngine>& engine) = 0;
};

} // namespace wavevortex
