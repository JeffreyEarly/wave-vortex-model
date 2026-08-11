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
    std::size_t halfSpectrumScratchCapacityBytes = 0;
    std::size_t realScratchCapacityBytes = 0;
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
    const char* nonlinearFluxScheduleIdentifier() const noexcept;
    std::size_t persistentBytes() const noexcept;
    std::size_t scratchBytes() const noexcept { return (halfSpectrumScratch_.size() + realScratch_.size()) * sizeof(double); }

    WVKernelStatus transformUVEtaToWaveVortex(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformUVWEtaToWaveVortex(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformWaveVortexToUVWEta(const WVState& state, WVRealFieldBundleView& fields);
    WVKernelStatus transformToSpatialDomainWithFAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields);
    WVKernelStatus transformToSpatialDomainWithGAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields);
    WVKernelStatus nonlinearFlux(const WVState& state, WVFlux& flux);

private:
    WVTransformConstantStratificationKernel() = default;
    WVKernelStatus preparePlans();
    WVKernelStatus transformUVEtaToWaveVortexImpl(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformUVWEtaToWaveVortexImpl(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformWaveVortexToUVWEtaImpl(const WVState& state, WVRealFieldBundleView& fields);
    WVKernelStatus transformToSpatialDomainWithDerivativesImpl(const WVState& state, std::size_t target, WVRealFieldBundleView& derivatives);
#if defined(WV_KERNEL_PAIRED_SCHEDULE)
    WVKernelStatus transformToSpatialDomainWithPairedDerivativesImpl(const WVState& state, std::size_t firstTarget, std::size_t secondTarget, WVRealFieldBundleView& derivatives);
#endif

    WVTransformConstantStratificationDescriptor descriptor_;
    std::unique_ptr<WVFFTEngine> engine_;
    std::string engineIdentifier_;
    std::string engineLibraryIdentity_;
    std::vector<std::unique_ptr<WVFFTPlan>> plans_;
    std::vector<double> halfSpectrumScratch_;
    std::vector<double> realScratch_;
    WVKernelMetrics metrics_;
    bool executing_ = false;
};

} // namespace wavevortex
