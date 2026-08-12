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
    std::size_t nonlinearFluxCallCount = 0;
    std::size_t nonlinearFluxPhaseEvaluationCount = 0;
    std::size_t bytesCopied = 0;
    double phaseSeconds = 0.0;
    double reconstructionSeconds = 0.0;
    double derivativeReconstructionSeconds = 0.0;
    double productSeconds = 0.0;
    double projectionSeconds = 0.0;
    double coefficientAssemblySeconds = 0.0;
    double derivativeCoefficientAssemblySeconds = 0.0;
    double coefficientProjectionSeconds = 0.0;
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
    const char* phaseImplementationIdentifier() const noexcept;
    const char* coefficientArithmeticModeIdentifier() const noexcept;
    const char* inverseNormalizationPlacementIdentifier() const noexcept;
    const char* optimizationImplementationIdentifier() const noexcept;
    std::size_t coefficientWorkerCount() const noexcept;
    std::size_t phaseReservationBytes() const noexcept;
    void setStageInstrumentation(bool enabled) noexcept;
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
    WVKernelStatus transformUVEtaToWaveVortexImpl(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients, WVComplexConstView phaseValues = {});
    WVKernelStatus transformUVWEtaToWaveVortexImpl(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients, WVComplexConstView phaseValues = {});
    WVKernelStatus transformWaveVortexToUVWEtaImpl(const WVState& state, WVRealFieldBundleView& fields, const WVCoefficients* evolvedCoefficients = nullptr);
    WVKernelStatus transformWaveVortexToUVWImpl(const WVState& state, WVRealFieldBundleView& fields, const WVCoefficients* evolvedCoefficients, WVComplexConstView phaseValues = {});
    WVKernelStatus transformToSpatialDomainWithDerivativesImpl(const WVCoefficients& evolvedCoefficients, std::size_t target, WVRealFieldBundleView& derivatives);
    WVKernelStatus transformToSpatialDomainWithDerivativesFromStateImpl(const WVState& state, WVComplexConstView phaseValues, std::size_t target, WVRealFieldBundleView& derivatives);
    WVKernelStatus projectSingleFluxTargetImpl(const WVRealFieldBundleConstView& field, std::size_t target, WVComplexConstView phaseValues, WVFlux& flux);
    WVTransformConstantStratificationDescriptor descriptor_;
    std::unique_ptr<WVFFTEngine> engine_;
    std::string engineIdentifier_;
    std::string engineLibraryIdentity_;
    std::vector<std::unique_ptr<WVFFTPlan>> plans_;
    std::vector<double> halfSpectrumScratch_;
    std::vector<double> realScratch_;
    WVKernelMetrics metrics_;
    bool executing_ = false;
    bool stageInstrumentationEnabled_ = false;
};

} // namespace wavevortex
