#pragma once
#include "WVStratifiedModalSource.hpp"
#include <array>
#include <atomic>
#include <functional>

namespace wavevortex {
inline constexpr const char* WVHydrostaticKernelContract = "wave-vortex-hydrostatic-kernel-v1";
enum class WVHydrostaticField { u, v, w, eta, pi, p, psi, qgpv, rhoE, rhoTotal, zetaX, zetaY, zetaZ, ssh, ssu, ssv };
enum class WVHydrostaticDerivative { value, x, y, z };
enum class WVHydrostaticComponent { all, wave, inertial, geostrophic, meanDensityAnomaly };
enum class WVHydrostaticFamily { F, G };

struct WVHydrostaticModeFactors {
    double omega = 0;
    WVComplex64 UAp{}, VAp{}, WAp{}, UA0{}, VA0{}, ApmD{};
    double NAp = 0, NA0 = 0, PA0 = 0, ApmN = 0, A0Z = 0, A0N = 0;
    double waveEnergy = 0, balancedEnergy = 0, psi = 0, qgpv = 0, enstrophy = 0;
    bool wave = false, inertial = false, geostrophic = false, meanDensityAnomaly = false;
};
struct WVHydrostaticStorage {
    std::size_t sharedScientificBytes = 0, preparedBytes = 0, workspaceBytes = 0;
    std::size_t spectralScratchBytes = 0, realScratchBytes = 0, factorBytes = 0;
    std::size_t providerBytesLowerBound = 0, planBytesLowerBound = 0;
};

// Immutable scientific source plus one owned mutable workspace. Coefficients
// are interleaved [Nj,Nkl]; fields are column-major [Nx,Ny,Nz]. Separate kernel
// instances are required for concurrent calls. No eigensolver or persistence I/O.
class WVTransformHydrostaticKernel final {
public:
    using MatrixBackendFactory = std::function<WVKernelStatus(std::unique_ptr<WVVerticalMatrixBackend>&)>;
    static WVKernelStatus create(std::shared_ptr<const WVStratifiedModalSource>,
        std::unique_ptr<WVFFTEngine>, std::unique_ptr<WVTransformHydrostaticKernel>&,
        MatrixBackendFactory = WVCreateScalarMatrixBackend);
    const WVStratifiedModalGeometry& geometry() const noexcept { return source_->geometry(); }
    const std::vector<WVHydrostaticModeFactors>& factors() const noexcept { return factors_; }
    const WVHydrostaticStorage& storage() const noexcept { return storage_; }
    const std::string& engineIdentifier() const noexcept { return engineIdentifier_; }
    const std::string& engineLibraryIdentity() const noexcept { return engineLibraryIdentity_; }
    const char* matrixBackendIdentifier() const noexcept { return vertical_[0]->backendIdentifier(); }
    WVShape2D spectralShape() const noexcept { return {geometry().Nj,geometry().Nkl}; }
    WVShape3D spatialShape() const noexcept { return {geometry().Nx,geometry().Ny,geometry().Nz}; }
    std::size_t persistentBytes() const noexcept;

    WVKernelStatus transformToSpatial(WVComplexConstView, WVHydrostaticFamily, WVRealVolumeView);
    WVKernelStatus transformFromSpatial(WVRealVolumeConstView, WVHydrostaticFamily, WVComplexView);
    WVKernelStatus transformUVEtaToWaveVortex(WVRealVolumeConstView u, WVRealVolumeConstView v,
        WVRealVolumeConstView eta, double t, double t0, WVMutableCoefficients);
    // Surface fields use [Nx,Ny,1]. Horizontal vorticity supports value only;
    // other fields support first derivatives. rhoTotal belongs to the full flow.
    WVKernelStatus transformStateField(const WVState&, WVHydrostaticField, WVRealVolumeView,
        WVHydrostaticDerivative = WVHydrostaticDerivative::value,
        WVHydrostaticComponent = WVHydrostaticComponent::all);
    // Linear phase evolution gives current-time coefficients; stored amplitudes
    // are stationary under the f-plane linear dynamics. Exact in-place allowed.
    WVKernelStatus evolveCoefficients(const WVState&, WVMutableCoefficients);
    // Remove inactive modes and enforce real A0 means / conjugate inertial Am.
    WVKernelStatus constrainCoefficients(WVMutableCoefficients) const;
    // Caller-owned observation output captures the raw spatial contribution.
    // Prepared [u,v,w,eta] fields may be shared within one observation event.
    // With projectFlux=false, spatialTendency is required and flux is untouched.
    WVKernelStatus nonlinearFlux(const WVState&, WVFlux&,
        WVRealFieldBundleView* spatialTendency = nullptr,
        const WVRealFieldBundleConstView* preparedFields = nullptr, bool projectFlux = true);
    WVKernelStatus totalEnergy(const WVCoefficients&, double&,
        WVHydrostaticComponent = WVHydrostaticComponent::all) const;
    WVKernelStatus totalEnstrophy(const WVCoefficients&, double&) const;
    WVKernelStatus totalEnergySpatiallyIntegrated(const WVState&, double&,
        WVHydrostaticComponent = WVHydrostaticComponent::all);
    // MATLAB diffZF/diffZG orders 1..4 and intZF/intZG order 1. These preserve
    // all horizontal grid columns rather than truncating through a Fourier map.
    WVKernelStatus differentiateVertical(WVRealVolumeConstView, WVHydrostaticFamily,
        unsigned order, WVRealVolumeView);
    // Full-grid horizontal derivatives and three-dimensional passive advection.
    WVKernelStatus differentiateHorizontal(WVRealVolumeConstView, bool xDerivative, WVRealVolumeView);
    WVKernelStatus advectScalarWithAdvectionFields(WVRealVolumeConstView, WVRealFieldBundleConstView, bool antialias, WVRealVolumeView, bool xyOnly = false);
    WVKernelStatus integrateVertical(WVRealVolumeConstView, WVHydrostaticFamily, WVRealVolumeView);
private:
    WVTransformHydrostaticKernel() = default;
    WVKernelStatus spectral(WVComplexConstView) const;
    WVKernelStatus volume(WVRealVolumeConstView, bool surface = false) const;
    WVKernelStatus coefficients(const WVCoefficients&) const;
    WVKernelStatus outputs(WVMutableCoefficients) const;
    WVKernelStatus state(const WVState&) const;
    WVKernelStatus disjoint(const void*,std::size_t,const void*,std::size_t) const;
    WVKernelStatus preparePhase(double t,double t0);
    WVKernelStatus vertical(std::size_t,const WVComplex64*,WVComplex64*);
    WVKernelStatus project(const double*,WVComplex64*,WVHydrostaticFamily);
    WVKernelStatus reconstruct(const WVCoefficients&,WVHydrostaticField,
        WVHydrostaticDerivative,WVHydrostaticComponent,double*);
    WVKernelStatus projectFields(const double*,const double*,const double*,WVMutableCoefficients);
    WVKernelStatus verticalCalculus(const double*,WVHydrostaticFamily,unsigned,bool,double*);
    std::shared_ptr<const WVStratifiedModalSource> source_;
    std::vector<WVHydrostaticModeFactors> factors_;
    WVHydrostaticStorage storage_;
    std::string engineIdentifier_,engineLibraryIdentity_;
    std::unique_ptr<WVRetainedHorizontalOperator> horizontal_;
    std::unique_ptr<WVRetainedHorizontalWorkspace> horizontalWorkspace_;
    std::array<std::unique_ptr<WVPreparedVerticalOperator>,4> vertical_;
    std::array<std::unique_ptr<WVVerticalWorkspace>,4> verticalWorkspace_;
    std::vector<WVComplex64> modal_,gridSpectral_,phase_;
    std::vector<double> real_;
    std::size_t S_ = 0,R_ = 0,H_ = 0;
    std::atomic<bool> active_{false};
};
} // namespace wavevortex
