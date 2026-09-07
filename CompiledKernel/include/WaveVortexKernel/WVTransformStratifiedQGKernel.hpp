#pragma once
#include "WVStratifiedModalSource.hpp"
#include <array>
#include <atomic>
#include <functional>

namespace wavevortex {
inline constexpr const char* WVStratifiedQGKernelContract = "wave-vortex-stratified-qg-kernel-v1";
enum class WVStratifiedQGField { u, v, w, eta, pi, p, psi, qgpv, rhoE, rhoTotal, zetaZ, ssh, ssu, ssv };
enum class WVStratifiedQGDerivative { value, x, y, z };
struct WVStratifiedQGModeFactors {
    double f = 0, beta = 0;
    std::vector<WVComplex64> u, v;
    std::vector<double> eta, pi, psi, qgpv, zetaZ, energy, enstrophy, kineticEnergy, potentialEnergy;
};
struct WVStratifiedQGStorage {
    std::size_t sharedScientificBytes = 0, preparedBytes = 0, workspaceBytes = 0;
    std::size_t spectralScratchBytes = 0, realScratchBytes = 0, factorBytes = 0;
    std::size_t providerBytesLowerBound = 0, planBytesLowerBound = 0;
};

// One owned mutable workspace, canonical interleaved [Nj,Nkl] coefficients and
// column-major [Nx,Ny,Nz] fields. No wave coefficient arrays or eigenproblem.
// Calls on one kernel must not overlap; create separate kernels for concurrency.
class WVTransformStratifiedQGKernel final {
public:
    using MatrixBackendFactory = std::function<WVKernelStatus(std::unique_ptr<WVVerticalMatrixBackend>&)>;
    static WVKernelStatus create(std::shared_ptr<const WVStratifiedModalSource>,
        std::unique_ptr<WVFFTEngine>, std::unique_ptr<WVTransformStratifiedQGKernel>&,
        MatrixBackendFactory = WVCreateScalarMatrixBackend);
    const WVStratifiedModalGeometry& geometry() const noexcept { return source_->geometry(); }
    const WVStratifiedQGModeFactors& factors() const noexcept { return factors_; }
    const WVStratifiedQGStorage& storage() const noexcept { return storage_; }
    const std::string& engineIdentifier() const noexcept { return engineIdentifier_; }
    WVShape2D spectralShape() const noexcept { return {geometry().Nj,geometry().Nkl}; }
    WVShape3D spatialShape() const noexcept { return {geometry().Nx,geometry().Ny,geometry().Nz}; }

    // Projection preserves the horizontal mean just as MATLAB's raw transform
    // does. Reconstructed QG fields mask all horizontal means as MATLAB does.
    WVKernelStatus transformQGPVToA0(WVRealVolumeConstView, WVComplexView);
    WVKernelStatus transformUVEtaToA0(WVRealVolumeConstView u, WVRealVolumeConstView v,
        WVRealVolumeConstView eta, WVComplexView);
    WVKernelStatus transformA0ToField(WVComplexConstView, WVStratifiedQGField,
        WVRealVolumeView, WVStratifiedQGDerivative = WVStratifiedQGDerivative::value);
    // Surface fields use [Nx,Ny,1]; other fields use [Nx,Ny,Nz].
    WVKernelStatus nonlinearFlux(WVComplexConstView, WVComplexView, double beta = 0);
    WVKernelStatus linearFlux(WVComplexConstView, WVComplexView, double beta = 0) const;
    // F-plane A0 is stationary. An explicit beta gives exact linear Rossby evolution.
    WVKernelStatus evolveA0(WVComplexConstView, double elapsedTime, WVComplexView, double beta = 0) const;
    WVKernelStatus totalEnergy(WVComplexConstView, double&) const;
    WVKernelStatus totalEnstrophy(WVComplexConstView, double&) const;
    WVKernelStatus totalEnergySpatiallyIntegrated(WVComplexConstView, double&);
    WVKernelStatus totalEnstrophySpatiallyIntegrated(WVComplexConstView, double&);
    WVKernelStatus uvMax(WVComplexConstView, double&);
private:
    WVTransformStratifiedQGKernel() = default;
    WVKernelStatus spectral(WVComplexConstView) const;
    WVKernelStatus volume(WVRealVolumeConstView, bool surface = false) const;
    WVKernelStatus disjoint(const void*, std::size_t, const void*, std::size_t) const;
    WVKernelStatus project(const double*, WVComplex64*, std::size_t operation = 1);
    WVKernelStatus reconstruct(WVComplexConstView, WVStratifiedQGField, WVStratifiedQGDerivative, double*);
    WVKernelStatus vertical(std::size_t operation, const WVComplex64*, WVComplex64*);
    std::shared_ptr<const WVStratifiedModalSource> source_;
    WVStratifiedQGModeFactors factors_;
    WVStratifiedQGStorage storage_;
    std::string engineIdentifier_;
    std::unique_ptr<WVRetainedHorizontalOperator> horizontal_;
    std::unique_ptr<WVRetainedHorizontalWorkspace> horizontalWorkspace_;
    std::array<std::unique_ptr<WVPreparedVerticalOperator>,4> vertical_;
    std::array<std::unique_ptr<WVVerticalWorkspace>,4> verticalWorkspace_;
    std::vector<WVComplex64> modal_, auxiliary_, gridSpectral_;
    std::vector<double> real_;
    std::size_t S_ = 0, R_ = 0, H_ = 0;
    std::atomic<bool> active_{false};
};
} // namespace wavevortex
