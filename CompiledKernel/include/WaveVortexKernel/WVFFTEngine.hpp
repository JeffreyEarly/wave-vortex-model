#pragma once

#include "WVKernelTypes.hpp"

#include <memory>
#include <string>

namespace wavevortex {

enum class WVFFTPlanKind : std::uint32_t {
    horizontalRealToComplex2D,
    horizontalComplexToReal2D,
    verticalDCTI,
    verticalDSTI
};

struct WVFFTPlanSpecification {
    WVFFTPlanKind kind = WVFFTPlanKind::horizontalRealToComplex2D;
    std::vector<std::size_t> dimensions;
    std::size_t batchCount = 0;
    std::vector<std::ptrdiff_t> inputStrides;
    std::vector<std::ptrdiff_t> outputStrides;
    bool destroysInput = false;
};

class WVFFTPlan {
public:
    virtual ~WVFFTPlan() = default;
    virtual WVKernelStatus execute(const void* input, void* output) = 0;
    virtual std::size_t persistentBytes() const noexcept = 0;
};

class WVFFTEngine {
public:
    virtual ~WVFFTEngine() = default;
    virtual std::string identifier() const = 0;
    virtual WVKernelStatus createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) = 0;
};

} // namespace wavevortex

