#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <type_traits>
#include <vector>

namespace wavevortex {

inline constexpr std::uint32_t WVKernelContractVersion = 3;

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
    unsupportedOperation,
    reentrantExecution
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

struct WVShape3D {
    std::size_t first = 0;
    std::size_t second = 0;
    std::size_t third = 0;
    std::size_t elementCount() const;
};

struct WVShape4D {
    std::size_t first = 0;
    std::size_t second = 0;
    std::size_t third = 0;
    std::size_t fourth = 0;
    std::size_t elementCount() const;
};

template <typename T>
struct WVMatrixView {
    T* data = nullptr;
    WVShape2D shape;
    bool empty() const noexcept { return shape.rows == 0 || shape.columns == 0; }
};

template <typename T>
struct WVFieldBundleView {
    T* data = nullptr;
    WVShape4D shape;
    bool empty() const noexcept { return shape.first == 0 || shape.second == 0 || shape.third == 0 || shape.fourth == 0; }
};

using WVRealConstView = WVMatrixView<const double>;
using WVComplexConstView = WVMatrixView<const WVComplex64>;
using WVComplexView = WVMatrixView<WVComplex64>;
using WVRealFieldBundleConstView = WVFieldBundleView<const double>;
using WVRealFieldBundleView = WVFieldBundleView<double>;

struct WVCoefficients {
    WVComplexConstView Ap;
    WVComplexConstView Am;
    WVComplexConstView A0;
};

struct WVMutableCoefficients {
    WVComplexView Ap;
    WVComplexView Am;
    WVComplexView A0;
};

struct WVState {
    double t = 0.0;
    double t0 = 0.0;
    WVCoefficients coefficients;
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

struct WVHalfSpectrumMappings {
    std::size_t NxHalf = 0;
    std::vector<std::size_t> directRows;
    std::vector<std::size_t> directWVIndices;
    std::vector<std::size_t> conjugatedRows;
    std::vector<std::size_t> conjugatedWVIndices;
    std::vector<std::size_t> storageRowsByWVIndex;
    std::vector<std::uint8_t> conjugatesStoredValueByWVIndex;
    std::vector<std::size_t> hermitianCompletionRows;
    std::vector<std::size_t> hermitianSourceRows;
    std::vector<std::size_t> selfConjugateRows;
    std::size_t persistentBytes() const noexcept;
};

struct WVConstantStratificationModes {
    double coriolisFrequency = 0.0;
    std::vector<double> z;
    std::vector<double> j;
    std::vector<double> h0;
    // Modal arrays use column-major [Nj,Nkl] ordering.
    std::vector<double> hpm;
    std::vector<double> omega;
    std::vector<double> Fg;
    std::vector<double> Gg;
    std::vector<double> Fwg;
    std::vector<double> Gwg;
    std::vector<WVComplex64> UAp;
    std::vector<WVComplex64> UAm;
    std::vector<WVComplex64> VAp;
    std::vector<WVComplex64> VAm;
    std::vector<WVComplex64> WAp;
    std::vector<WVComplex64> WAm;
    std::vector<double> NAp;
    std::vector<double> NAm;
    std::vector<WVComplex64> UA0;
    std::vector<WVComplex64> VA0;
    std::vector<double> NA0;
    std::vector<double> A0Z;
    std::vector<double> A0N;
    std::vector<WVComplex64> ApmD;
    std::vector<double> ApmN;
    std::vector<double> ApmDScaled;
    std::vector<WVComplex64> ApmWScaled;
};

class WVTransformConstantStratificationDescriptor {
public:
    static WVKernelStatus create(const WVTransformConstantStratificationConfiguration& configuration, WVTransformConstantStratificationDescriptor& descriptor);

    const WVTransformConstantStratificationConfiguration& configuration() const noexcept { return configuration_; }
    const std::vector<WVFourierMode>& fourierModes() const noexcept { return fourierModes_; }
    const WVHalfSpectrumMappings& halfSpectrumMappings() const noexcept { return halfSpectrumMappings_; }
    const WVConstantStratificationModes& verticalModes() const noexcept { return verticalModes_; }
    std::size_t Nkl() const noexcept { return fourierModes_.size(); }
    WVShape2D spectralShape() const noexcept { return {configuration_.Nj, Nkl()}; }
    WVShape3D spatialShape() const noexcept { return {configuration_.Nx, configuration_.Ny, configuration_.Nz}; }
    std::size_t persistentBytes() const noexcept;

private:
    WVTransformConstantStratificationConfiguration configuration_;
    std::vector<WVFourierMode> fourierModes_;
    WVHalfSpectrumMappings halfSpectrumMappings_;
    WVConstantStratificationModes verticalModes_;
};

WVKernelStatus validateStateAndFlux(const WVTransformConstantStratificationDescriptor& descriptor, const WVState& state, const WVFlux& flux);

} // namespace wavevortex
