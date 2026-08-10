#pragma once

#include "WaveVortexKernel/WVFFTEngine.hpp"

namespace wavevortex::test {

class WVReferenceFFTEngine final : public WVFFTEngine {
public:
    std::string identifier() const override { return "reference-direct"; }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) override;
};

} // namespace wavevortex::test
