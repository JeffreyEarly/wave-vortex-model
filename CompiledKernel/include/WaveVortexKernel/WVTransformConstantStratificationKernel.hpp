#pragma once

#include "WVFFTEngine.hpp"

#include <memory>
#include <vector>

namespace wavevortex {

struct WVKernelMetrics {
    std::size_t descriptorBytes = 0;
    std::size_t planBytes = 0;
    std::size_t scratchCapacityBytes = 0;
    std::size_t scratchHighWaterBytes = 0;
    std::size_t planCount = 0;
    std::size_t executionCount = 0;
    std::size_t horizontalExecutionCount = 0;
    std::size_t verticalExecutionCount = 0;
    std::size_t bytesCopied = 0;
};

class WVTransformConstantStratificationKernel {
public:
    static WVKernelStatus create(const WVTransformConstantStratificationConfiguration& configuration, std::unique_ptr<WVFFTEngine> engine, std::unique_ptr<WVTransformConstantStratificationKernel>& kernel);

    ~WVTransformConstantStratificationKernel() = default;
    WVTransformConstantStratificationKernel(const WVTransformConstantStratificationKernel&) = delete;
    WVTransformConstantStratificationKernel& operator=(const WVTransformConstantStratificationKernel&) = delete;
    WVTransformConstantStratificationKernel(WVTransformConstantStratificationKernel&&) = delete;
    WVTransformConstantStratificationKernel& operator=(WVTransformConstantStratificationKernel&&) = delete;

    const WVTransformConstantStratificationDescriptor& descriptor() const noexcept { return descriptor_; }
    const WVKernelMetrics& metrics() const noexcept { return metrics_; }
    const std::string& engineIdentifier() const noexcept { return engineIdentifier_; }
    const std::string& engineLibraryIdentity() const noexcept { return engineLibraryIdentity_; }
    std::size_t persistentBytes() const noexcept;
    std::size_t scratchBytes() const noexcept { return scratch_.size() * sizeof(double); }

    WVKernelStatus transformUVEtaToWaveVortex(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformUVWEtaToWaveVortex(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformWaveVortexToUVWEta(const WVState& state, WVRealFieldBundleView& fields);
    WVKernelStatus transformToSpatialDomainWithFAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields);
    WVKernelStatus transformToSpatialDomainWithGAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields);
    WVKernelStatus nonlinearFluxWithGradientMasks(const WVState&, const WVGradientMasks&, WVFlux&) { return {WVKernelStatusCode::unsupportedOperation, "nonlinearFluxWithGradientMasks is implemented by issue #51."}; }

private:
    WVTransformConstantStratificationKernel() = default;
    WVKernelStatus preparePlans();

    WVTransformConstantStratificationDescriptor descriptor_;
    std::unique_ptr<WVFFTEngine> engine_;
    std::string engineIdentifier_;
    std::string engineLibraryIdentity_;
    std::vector<std::unique_ptr<WVFFTPlan>> plans_;
    std::vector<double> scratch_;
    WVKernelMetrics metrics_;
    bool executing_ = false;
};

} // namespace wavevortex
