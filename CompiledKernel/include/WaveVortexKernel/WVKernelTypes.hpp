#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <type_traits>
#include <vector>

namespace wavevortex {

inline constexpr std::uint32_t WVKernelContractVersion = 1;

struct WVComplex64 {
    double real = 0.0;
    double imag = 0.0;
};

static_assert(std::is_standard_layout<WVComplex64>::value, "WVComplex64 must be standard layout");
static_assert(std::is_trivially_copyable<WVComplex64>::value, "WVComplex64 must be trivially copyable");
static_assert(sizeof(WVComplex64) == 2 * sizeof(double), "WVComplex64 must contain two doubles without padding");

enum class WVKernelStatusCode : std::uint32_t {
    success = 0,
    invalidConfiguration,
    invalidShape,
    invalidPointer,
    overlappingArrays,
    sizeOverflow,
    allocationFailure,
    fftPlanFailure,
    fftExecutionFailure,
    numericalFailure,
    unsupportedOperation
};

struct WVKernelStatus {
    WVKernelStatusCode code = WVKernelStatusCode::success;
    std::string message;

    explicit operator bool() const noexcept { return code == WVKernelStatusCode::success; }
    static WVKernelStatus ok() { return {}; }
};

struct WVShape2D {
    std::size_t rows = 0;
    std::size_t columns = 0;

    std::size_t elementCount() const;
};

template <typename T>
struct WVMatrixView {
    T* data = nullptr;
    WVShape2D shape;

    bool empty() const noexcept { return shape.rows == 0 || shape.columns == 0; }
};

using WVRealConstView = WVMatrixView<const double>;
using WVComplexConstView = WVMatrixView<const WVComplex64>;
using WVComplexView = WVMatrixView<WVComplex64>;

struct WVCoefficients {
    WVComplexConstView Ap;
    WVComplexConstView Am;
    WVComplexConstView A0;
};

struct WVState {
    double t = 0.0;
    double t0 = 0.0;
    WVCoefficients coefficients;
};

struct WVGradientMasks {
    WVRealConstView ApUMask;
    WVRealConstView AmUMask;
    WVRealConstView A0UMask;
    WVRealConstView ApUxMask;
    WVRealConstView AmUxMask;
    WVRealConstView A0UxMask;
};

struct WVFlux {
    WVComplexView Fp;
    WVComplexView Fm;
    WVComplexView F0;
};

struct WVTransformConstantStratificationConfiguration {
    std::uint32_t contractVersion = WVKernelContractVersion;
    std::size_t Nx = 0;
    std::size_t Ny = 0;
    std::size_t Nz = 0;
    std::size_t Nj = 0;
    double Lx = 0.0;
    double Ly = 0.0;
    double Lz = 0.0;
    double N0 = 0.0;
    double rho0 = 0.0;
    double g = 0.0;
    double planetaryRadius = 0.0;
    double rotationRate = 0.0;
    double latitude = 0.0;
    bool isHydrostatic = false;
    bool shouldAntialias = true;
};

struct WVFourierMode {
    std::int64_t kMode = 0;
    std::int64_t lMode = 0;
    double k = 0.0;
    double l = 0.0;
    std::size_t dftPrimaryIndex = 0;
    std::size_t dftConjugateIndex = 0;
};

struct WVConstantStratificationModes {
    double coriolisFrequency = 0.0;
    std::vector<double> z;
    std::vector<double> j;
    std::vector<double> h0;
    // The following arrays use column-major [Nj,Nkl] ordering.
    std::vector<double> hpm;
    std::vector<double> omega;
    std::vector<double> Fg;
    std::vector<double> Gg;
    std::vector<double> Fwg;
    std::vector<double> Gwg;
};

class WVTransformConstantStratificationDescriptor {
public:
    static WVKernelStatus create(
        const WVTransformConstantStratificationConfiguration& configuration,
        WVTransformConstantStratificationDescriptor& descriptor);

    const WVTransformConstantStratificationConfiguration& configuration() const noexcept { return configuration_; }
    const std::vector<WVFourierMode>& fourierModes() const noexcept { return fourierModes_; }
    const WVConstantStratificationModes& verticalModes() const noexcept { return verticalModes_; }
    std::size_t Nkl() const noexcept { return fourierModes_.size(); }
    WVShape2D spectralShape() const noexcept { return {configuration_.Nz, Nkl()}; }
    WVShape2D spatialPlaneShape() const noexcept { return {configuration_.Nx, configuration_.Ny}; }

private:
    WVTransformConstantStratificationConfiguration configuration_;
    std::vector<WVFourierMode> fourierModes_;
    WVConstantStratificationModes verticalModes_;
};

WVKernelStatus validateStateAndFlux(
    const WVTransformConstantStratificationDescriptor& descriptor,
    const WVState& state,
    const WVGradientMasks& masks,
    const WVFlux& flux);

} // namespace wavevortex
