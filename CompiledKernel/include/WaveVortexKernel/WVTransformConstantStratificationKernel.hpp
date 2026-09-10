#pragma once

#include "WVFFTEngine.hpp"

#include <memory>
#include <vector>

namespace wavevortex {
namespace kernel_detail { class WVPreparedModeExecutor; struct WVCompactConstantSchedule; }

// Experimental schedule selection is an explicit construction policy, never
// mutable process state or part of the scientific checkpoint identity.
enum class WVConstantNonlinearFluxSchedule { frozenStreamed, compactCandidate };
struct WVConstantKernelExecutionOptions {
#if defined(WV_KERNEL_COMPACT_CONSTANT_CANDIDATE) && WV_KERNEL_COMPACT_CONSTANT_CANDIDATE
    WVConstantNonlinearFluxSchedule schedule = WVConstantNonlinearFluxSchedule::compactCandidate;
#else
    WVConstantNonlinearFluxSchedule schedule = WVConstantNonlinearFluxSchedule::frozenStreamed;
#endif
#if defined(WV_KERNEL_COMPACT_HORIZONTAL_WORKERS)
    std::size_t horizontalOuterWorkers = WV_KERNEL_COMPACT_HORIZONTAL_WORKERS;
#else
    std::size_t horizontalOuterWorkers = 12;
#endif
#if defined(WV_KERNEL_COMPACT_POINTWISE_WORKERS)
    std::size_t pointwiseWorkers = WV_KERNEL_COMPACT_POINTWISE_WORKERS;
#else
    std::size_t pointwiseWorkers = 12;
#endif
};

enum class WVLaplacianDirection : std::uint8_t { horizontal, vertical };

enum class WVDynamicalField : std::uint8_t { u, v, w, eta };

struct WVKernelMetrics {
    std::size_t descriptorBytes = 0;
    std::size_t planBytes = 0;
    std::size_t engineBytes = 0;
    std::size_t kernelManagementBytes = 0;
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
    std::size_t advectionVelocityReconstructionCount = 0;
    std::size_t scalarAdvectionCount = 0;
    std::size_t scalarAntialiasCount = 0;
    std::size_t bytesCopied = 0;
    double phaseSeconds = 0.0;
    double reconstructionSeconds = 0.0;
    double derivativeReconstructionSeconds = 0.0;
    double productSeconds = 0.0;
    double projectionSeconds = 0.0;
    double coefficientAssemblySeconds = 0.0;
    double derivativeCoefficientAssemblySeconds = 0.0;
    double coefficientProjectionSeconds = 0.0;
    double scalarForwardSeconds = 0.0;
    double scalarDerivativeAssemblySeconds = 0.0;
    double scalarVerticalDerivativeSeconds = 0.0;
    double scalarInverseSeconds = 0.0;
    double scalarProductSeconds = 0.0;
    double scalarAntialiasSeconds = 0.0;
};

class WVTransformConstantStratificationKernel {
public:
    static WVKernelStatus create(const WVTransformConstantStratificationConfiguration& configuration, std::unique_ptr<WVFFTEngine> engine, std::unique_ptr<WVTransformConstantStratificationKernel>& kernel, WVConstantKernelExecutionOptions options = {});

    ~WVTransformConstantStratificationKernel();
    WVTransformConstantStratificationKernel(const WVTransformConstantStratificationKernel&) = delete;
    WVTransformConstantStratificationKernel& operator=(const WVTransformConstantStratificationKernel&) = delete;
    WVTransformConstantStratificationKernel(WVTransformConstantStratificationKernel&&) = delete;
    WVTransformConstantStratificationKernel& operator=(WVTransformConstantStratificationKernel&&) = delete;

    const WVTransformConstantStratificationDescriptor& descriptor() const noexcept { return descriptor_; }
    const WVKernelMetrics& metrics() const noexcept;
    const std::string& engineIdentifier() const noexcept { return engineIdentifier_; }
    const std::string& engineLibraryIdentity() const noexcept { return engineLibraryIdentity_; }
    const char* nonlinearFluxScheduleIdentifier() const noexcept;
    const char* phaseImplementationIdentifier() const noexcept;
    const char* coefficientArithmeticModeIdentifier() const noexcept;
    const char* inverseNormalizationPlacementIdentifier() const noexcept;
    const char* optimizationImplementationIdentifier() const noexcept;
    std::size_t coefficientWorkerCount() const noexcept;
    std::size_t pointwiseWorkerCount() const noexcept;
    std::size_t retainedHorizontalWorkerCount() const noexcept;
    const char* retainedHorizontalScheduleIdentifier() const noexcept;
    std::size_t verticalExecutionRowCount() const noexcept;
    std::size_t phaseReservationBytes() const noexcept;
    void setStageInstrumentation(bool enabled) noexcept;
    std::size_t persistentBytes() const noexcept;
    std::size_t scratchBytes() const noexcept { return (halfSpectrumScratch_.size() + realScratch_.size()) * sizeof(double); }

    WVKernelStatus transformUVEtaToWaveVortex(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformUVWEtaToWaveVortex(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients);
    WVKernelStatus transformWaveVortexToUVWEta(const WVState& state, WVRealFieldBundleView& fields);
    WVKernelStatus transformWaveVortexToUVW(const WVState& state, WVRealFieldBundleView& fields);
    WVKernelStatus transformStateFieldDerivatives(const WVState& state, WVDynamicalField field, WVRealFieldBundleView& derivatives);
    WVKernelStatus transformToSpatialDomainWithFAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields);
    WVKernelStatus transformToSpatialDomainWithGAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields);
    // Add physical velocity/displacement Laplacian forcing in coefficient space.
    // Reuses the descriptor's field/projection factors and caller-owned flux.
    WVKernelStatus addLaplacianDamping(const WVState& state, double nu, double kappa,
        WVLaplacianDirection direction, WVFlux& flux);
    WVKernelStatus nonlinearFlux(const WVState& state, WVFlux& flux);
    WVKernelStatus nonlinearFluxWithAdvectionFields(const WVState& state, WVFlux& flux, WVRealFieldBundleView& advectionFields);
    // Optional observation output receives raw spatial tendencies before modal
    // projection, in [u,v,eta] or [u,v,w,eta] order. Storage is caller owned.
    // With projectFlux=false, spatialTendency is required and flux is untouched.
    WVKernelStatus nonlinearFluxUsingAdvectionFields(const WVState& state, WVFlux& flux, const WVRealFieldBundleConstView& advectionFields,
        WVRealFieldBundleView* spatialTendency = nullptr, bool projectFlux = true);
    // Call at setup when scalar advection is configured, before repeated RHS calls.
    WVKernelStatus prepareScalarAdvection();
    // MATLAB diffX/diffY/diffZG of an arbitrary full-grid G scalar. Horizontal
    // derivatives retain all non-Nyquist modes; vertical calculus retains Nj.
    // Reuses existing plans/scratch and publishes [dx,dy,dz] only on success.
    WVKernelStatus transformGGridScalarDerivatives(const WVRealVolumeConstView& scalar, WVRealFieldBundleView& derivatives);
    WVKernelStatus advectFGridScalar(const WVRealVolumeConstView& scalar, const WVRealFieldBundleConstView& advectionFields, bool shouldAntialias, WVRealVolumeView& rightHandSide);

private:
    WVTransformConstantStratificationKernel();
    WVKernelStatus preparePlans();
    WVKernelStatus transformUVEtaToWaveVortexImpl(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients, WVComplexConstView phaseValues = {});
    WVKernelStatus transformUVWEtaToWaveVortexImpl(const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients, WVComplexConstView phaseValues = {});
    WVKernelStatus transformWaveVortexToUVWEtaImpl(const WVState& state, WVRealFieldBundleView& fields, const WVCoefficients* evolvedCoefficients = nullptr);
    WVKernelStatus transformWaveVortexToUVWImpl(const WVState& state, WVRealFieldBundleView& fields, const WVCoefficients* evolvedCoefficients, WVComplexConstView phaseValues = {}, WVComplex64* generatedPhase = nullptr);
    WVKernelStatus transformToSpatialDomainWithDerivativesImpl(const WVCoefficients& evolvedCoefficients, std::size_t target, WVRealFieldBundleView& derivatives);
    WVKernelStatus transformToSpatialDomainWithDerivativesFromStateImpl(const WVState& state, WVComplexConstView phaseValues, std::size_t target, WVRealFieldBundleView& derivatives, WVComplex64* generatedPhase = nullptr);
    WVKernelStatus projectSingleFluxTargetImpl(const WVRealFieldBundleConstView& field, std::size_t target, WVComplexConstView phaseValues, WVFlux& flux);
    WVKernelStatus nonlinearFluxImpl(const WVState& state, WVFlux& flux, WVRealFieldBundleView* advectionFields, bool advectionFieldsPrepared = false,
        WVRealFieldBundleView* spatialTendency = nullptr, bool projectFlux = true);
    WVKernelStatus ensureScalarInversePlan();
    WVKernelStatus ensureScalarPlans();
    WVKernelStatus prepareCompactScalarDerivatives(const WVRealVolumeConstView& scalar, bool sine);
    WVFFTPlan* scalarPlan(std::size_t index) const noexcept;
    const WVHalfSpectrumMappings& executionMapping() const noexcept;
    std::size_t executionRowCount() const noexcept;
    WVKernelStatus antialiasScalarInPlace(WVRealVolumeView& scalar);
    WVTransformConstantStratificationDescriptor descriptor_;
    std::shared_ptr<WVFFTEngine> engine_;
    std::string engineIdentifier_;
    std::string engineLibraryIdentity_;
    std::vector<std::unique_ptr<WVFFTPlan>> plans_;
    std::unique_ptr<WVFFTPlan> scalarInversePlan_;
    std::unique_ptr<kernel_detail::WVCompactConstantSchedule> compact_;
    std::vector<std::uint8_t> scalarAntialiasRows_;
    std::vector<double> halfSpectrumScratch_;
    std::vector<double> realScratch_;
    mutable WVKernelMetrics metrics_;
    std::unique_ptr<kernel_detail::WVPreparedModeExecutor> coefficientExecutor_;
    bool executing_ = false;
    bool stageInstrumentationEnabled_ = false;
};

} // namespace wavevortex
