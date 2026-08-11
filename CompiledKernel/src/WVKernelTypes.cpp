#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
#include <stdexcept>

namespace wavevortex {
namespace {

constexpr double pi = 3.141592653589793238462643383279502884;

WVComplex64 complexValue(double real, double imag = 0.0) { return {real, imag}; }
#if !WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
WVComplex64 conjugate(WVComplex64 value) { return {value.real, -value.imag}; }
#endif

bool finitePositive(double value) { return std::isfinite(value) && value > 0.0; }

double radialMagnitude(double first, double second) {
    // MATLAB evaluates K.*K and L.*L before adding the arrays. Prevent the
    // compiler from contracting one product into an FMA, which can change a
    // tied shell by one ulp and therefore change canonical WV ordering.
    volatile double firstSquared = first * first;
    volatile double secondSquared = second * second;
    return std::sqrt(firstSquared + secondSquared);
}

std::size_t checkedProduct(std::size_t first, std::size_t second) {
    if (first != 0 && second > std::numeric_limits<std::size_t>::max() / first) {
        throw std::overflow_error("shape element count overflow");
    }
    return first * second;
}

std::vector<std::int64_t> dftModes(std::size_t n) {
    std::vector<std::int64_t> modes;
    modes.reserve(n);
    const auto positiveCount = (n + 1) / 2;
    for (std::size_t value = 0; value < positiveCount; ++value) modes.push_back(static_cast<std::int64_t>(value));
    for (std::size_t value = n / 2; value > 0; --value) modes.push_back(-static_cast<std::int64_t>(value));
    return modes;
}

std::size_t dftIndexForMode(std::int64_t mode, std::size_t n) {
    const auto wrapped = mode >= 0 ? mode : static_cast<std::int64_t>(n) + mode;
    return static_cast<std::size_t>(wrapped);
}

bool isSelfConjugate(std::int64_t mode, std::size_t n) {
    return mode == 0 || (n % 2 == 0 && mode == -static_cast<std::int64_t>(n / 2));
}

bool isPrimary(std::int64_t kMode, std::int64_t lMode, std::size_t Nx, std::size_t Ny) {
    const bool kSelf = isSelfConjugate(kMode, Nx);
    const bool lSelf = isSelfConjugate(lMode, Ny);
    return lMode > 0 || (lSelf && (kMode > 0 || kSelf));
}

bool nyquist(std::int64_t kMode, std::int64_t lMode, std::size_t Nx, std::size_t Ny) {
    return (Nx % 2 == 0 && kMode == -static_cast<std::int64_t>(Nx / 2)) ||
           (Ny % 2 == 0 && lMode == -static_cast<std::int64_t>(Ny / 2));
}

std::size_t halfRow(std::int64_t kMode, std::int64_t lMode, std::size_t NxHalf, std::size_t Ny) {
    return static_cast<std::size_t>(kMode) + NxHalf * dftIndexForMode(lMode, Ny);
}

bool overlaps(const void* a, std::size_t aBytes, const void* b, std::size_t bBytes) {
    if (a == nullptr || b == nullptr || aBytes == 0 || bBytes == 0) return false;
    const auto aBegin = reinterpret_cast<std::uintptr_t>(a);
    const auto bBegin = reinterpret_cast<std::uintptr_t>(b);
    return aBegin < bBegin + bBytes && bBegin < aBegin + aBytes;
}

template <typename T>
WVKernelStatus validateView(const WVMatrixView<T>& view, WVShape2D expected, const char* name) {
    if (view.shape.rows != expected.rows || view.shape.columns != expected.columns) {
        return {WVKernelStatusCode::invalidShape, std::string(name) + " must have shape [Nj,Nkl]."};
    }
    if (view.data == nullptr && expected.elementCount() != 0) {
        return {WVKernelStatusCode::invalidPointer, std::string(name) + " has a null data pointer."};
    }
    return WVKernelStatus::ok();
}

template <typename T>
std::size_t bytes(const std::vector<T>& values) { return values.capacity() * sizeof(T); }

} // namespace

std::size_t WVShape2D::elementCount() const { return checkedProduct(rows, columns); }
std::size_t WVShape3D::elementCount() const { return checkedProduct(checkedProduct(first, second), third); }
std::size_t WVShape4D::elementCount() const { return checkedProduct(checkedProduct(checkedProduct(first, second), third), fourth); }

std::size_t WVHalfSpectrumMappings::persistentBytes() const noexcept {
    return bytes(directRows) + bytes(directWVIndices) + bytes(conjugatedRows) + bytes(conjugatedWVIndices) +
           bytes(storageRowsByWVIndex) + bytes(conjugatesStoredValueByWVIndex) + bytes(hermitianCompletionRows) + bytes(hermitianSourceRows) + bytes(selfConjugateRows);
}

WVKernelStatus WVTransformConstantStratificationDescriptor::create(
    const WVTransformConstantStratificationConfiguration& configuration,
    WVTransformConstantStratificationDescriptor& descriptor) {
    if (configuration.contractVersion != WVKernelContractVersion) {
        return {WVKernelStatusCode::invalidConfiguration, "Unsupported kernel contract version."};
    }
    if (configuration.Nx < 2 || configuration.Ny < 2 || configuration.Nz < 3 || configuration.Nj < 1 || configuration.Nj > configuration.Nz - 1) {
        return {WVKernelStatusCode::invalidConfiguration, "Nx and Ny must be at least 2, Nz at least 3, and Nj must lie in [1,Nz-1]."};
    }
    if (!finitePositive(configuration.Lx) || !finitePositive(configuration.Ly) || !finitePositive(configuration.Lz) ||
        !finitePositive(configuration.N0) || !finitePositive(configuration.rho0) || !finitePositive(configuration.g) ||
        !finitePositive(configuration.planetaryRadius) || !finitePositive(configuration.rotationRate) ||
        !std::isfinite(configuration.latitude) || std::abs(configuration.latitude) > 90.0) {
        return {WVKernelStatusCode::invalidConfiguration, "Physical lengths and constants must be finite and positive, and latitude must lie in [-90,90]."};
    }

    try {
        checkedProduct(configuration.Nx, configuration.Ny);
        WVTransformConstantStratificationDescriptor candidate;
        candidate.configuration_ = configuration;
        const auto kModes = dftModes(configuration.Nx);
        const auto lModes = dftModes(configuration.Ny);
        const double maxAbsK = 2.0 * pi * (static_cast<double>(configuration.Nx / 2) / configuration.Lx);

        for (const auto lMode : lModes) {
            for (const auto kMode : kModes) {
                if (!isPrimary(kMode, lMode, configuration.Nx, configuration.Ny) || nyquist(kMode, lMode, configuration.Nx, configuration.Ny)) continue;
                const double k = 2.0 * pi * (static_cast<double>(kMode) / configuration.Lx);
                const double l = 2.0 * pi * (static_cast<double>(lMode) / configuration.Ly);
                if (configuration.shouldAntialias && radialMagnitude(k,l) > 2.0 * maxAbsK / 3.0) continue;
                const auto iK = dftIndexForMode(kMode, configuration.Nx);
                const auto iL = dftIndexForMode(lMode, configuration.Ny);
                const auto conjugateK = dftIndexForMode(-kMode, configuration.Nx);
                const auto conjugateL = dftIndexForMode(-lMode, configuration.Ny);
                const double Kh = radialMagnitude(k,l);
                const double cosAlpha = Kh == 0.0 ? 0.0 : k / Kh;
                const double sinAlpha = Kh == 0.0 ? 0.0 : l / Kh;
                candidate.fourierModes_.push_back({kMode, lMode, k, l, Kh, cosAlpha, sinAlpha, iK + configuration.Nx * iL, conjugateK + configuration.Nx * conjugateL});
            }
        }
        std::stable_sort(candidate.fourierModes_.begin(), candidate.fourierModes_.end(), [](const WVFourierMode& a, const WVFourierMode& b) {
            // Match sortrows([Kh,K,L]) in WVGeometryDoublyPeriodic. In
            // particular, use sqrt rather than hypot because tied shells
            // can differ by one ulp in MATLAB's elementwise expression.
            if (a.Kh != b.Kh) return a.Kh < b.Kh;
            if (a.kMode != b.kMode) return a.kMode < b.kMode;
            return a.lMode < b.lMode;
        });

        auto& modes = candidate.verticalModes_;
        modes.coriolisFrequency = 2.0 * configuration.rotationRate * std::sin(configuration.latitude * pi / 180.0);
        modes.z.resize(configuration.Nz);
        modes.j.resize(configuration.Nj);
        modes.h0.resize(configuration.Nj);
        modes.verticalWavenumber.resize(configuration.Nj);
        modes.Fg.resize(configuration.Nj); modes.Gg.resize(configuration.Nj);
        modes.inverseFg.resize(configuration.Nj); modes.inverseGg.resize(configuration.Nj);
        modes.Gwg.resize(configuration.Nj); modes.inverseGwg.resize(configuration.Nj); modes.GgOverGwg.resize(configuration.Nj);
        modes.deltaScale.resize(configuration.Nj); modes.inertialScale.resize(configuration.Nj); modes.gWaveScale.resize(configuration.Nj);
        const double dz = configuration.Lz / static_cast<double>(configuration.Nz - 1);
        for (std::size_t i = 0; i < configuration.Nz; ++i) modes.z[i] = dz * static_cast<double>(i) - configuration.Lz;
        for (std::size_t i = 0; i < configuration.Nj; ++i) {
            modes.j[i] = static_cast<double>(i);
            const double m = static_cast<double>(i) * pi / configuration.Lz;
            modes.verticalWavenumber[i] = m;
            modes.h0[i] = i == 0 ? configuration.Lz : configuration.N0 * configuration.N0 / (configuration.g * m * m);
        }

        const auto modalCount = checkedProduct(configuration.Nj, candidate.fourierModes_.size());
        modes.omega.resize(modalCount);
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
        modes.fWaveScale.resize(modalCount);
        modes.UApField.resize(modalCount); modes.UAmField.resize(modalCount); modes.VApField.resize(modalCount); modes.VAmField.resize(modalCount);
        modes.WApField.resize(modalCount); modes.WAmField.resize(modalCount); modes.NApField.resize(modalCount); modes.NAmField.resize(modalCount);
        modes.UA0Field.resize(modalCount); modes.VA0Field.resize(modalCount); modes.NA0Field.resize(modalCount);
        modes.A0FromVorticity.resize(modalCount); modes.A0FromBuoyancy.resize(modalCount);
        modes.ApmDProjection.resize(modalCount); modes.ApmNProjection.resize(modalCount);
#else
        modes.Fwg.resize(modalCount);
        modes.UAp.resize(modalCount); modes.UAm.resize(modalCount); modes.VAp.resize(modalCount); modes.VAm.resize(modalCount);
        modes.WAp.resize(modalCount); modes.WAm.resize(modalCount); modes.NAp.resize(modalCount); modes.NAm.resize(modalCount);
        modes.UA0.resize(modalCount); modes.VA0.resize(modalCount); modes.NA0.resize(modalCount);
        modes.A0Z.resize(modalCount); modes.A0N.resize(modalCount); modes.ApmD.resize(modalCount); modes.ApmN.resize(modalCount);
#endif
        modes.ApmDScaled.resize(modalCount); modes.ApmWScaled.resize(modalCount);

        const double N02 = configuration.N0 * configuration.N0;
        const double f = modes.coriolisFrequency;
        const double f2 = f * f;
        if (!configuration.isHydrostatic && N02 <= f2) {
            return {WVKernelStatusCode::invalidConfiguration, "Nonhydrostatic constant stratification requires N0 squared greater than f squared."};
        }

        for (std::size_t iJ = 0; iJ < configuration.Nj; ++iJ) {
            const double M = modes.verticalWavenumber[iJ];
            const double signNorm = iJ % 2 == 0 ? 1.0 : -1.0;
            const double Fg = iJ == 0 ? 2.0 : signNorm * modes.h0[iJ] * M * std::sqrt(2.0 * configuration.g / (configuration.Lz * N02));
            const double Gg = iJ == 0 ? 1.0 : signNorm * std::sqrt(2.0 * configuration.g / (configuration.Lz * N02));
            const double Gw = configuration.isHydrostatic || iJ == 0 ? Gg : signNorm * std::sqrt(2.0 * configuration.g / (configuration.Lz * (N02 - f2)));
            const double Gwg = Gg / Gw;
            modes.Fg[iJ] = Fg; modes.Gg[iJ] = Gg; modes.inverseFg[iJ] = 1.0 / Fg; modes.inverseGg[iJ] = 1.0 / Gg;
            modes.Gwg[iJ] = Gwg; modes.inverseGwg[iJ] = 1.0 / Gwg; modes.GgOverGwg[iJ] = Gg / Gwg;
            modes.deltaScale[iJ] = modes.h0[iJ] * Gwg / Fg;
            modes.gWaveScale[iJ] = Gg / Gwg;
        }

        for (std::size_t iMode = 0; iMode < candidate.fourierModes_.size(); ++iMode) {
            const auto& horizontal = candidate.fourierModes_[iMode];
            const double Kh = horizontal.Kh;
            const double Kh2 = Kh * Kh;
            const double cosAlpha = horizontal.cosAlpha;
            const double sinAlpha = horizontal.sinAlpha;
            for (std::size_t iJ = 0; iJ < configuration.Nj; ++iJ) {
                const auto index = iJ + configuration.Nj * iMode;
                const double M = modes.verticalWavenumber[iJ];
                const double signNorm = iJ % 2 == 0 ? 1.0 : -1.0;
                const bool isWave = Kh > 0.0 && iJ > 0;
                const bool isInertial = Kh == 0.0;
                const bool isGeostrophic = Kh > 0.0;
                const bool isMDA = Kh == 0.0 && iJ > 0;
                double hpm = 1.0;
                if (iJ > 0) hpm = configuration.isHydrostatic ? N02 / (configuration.g * M * M) : (N02 - f2) / (configuration.g * (M * M + Kh2));
                const double Fg = modes.Fg[iJ];
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                const double Gg = modes.Gg[iJ];
#endif
                double Fw = Fg;
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                double Gw = Gg;
#endif
                if (!configuration.isHydrostatic) {
                    Fw = iJ == 0 ? 2.0 : signNorm * hpm * M * std::sqrt(2.0 * configuration.g / (configuration.Lz * (N02 - f2)));
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                    Gw = iJ == 0 ? 1.0 : signNorm * std::sqrt(2.0 * configuration.g / (configuration.Lz * (N02 - f2)));
#endif
                }
                const double omega = std::sqrt(configuration.g * hpm * Kh2 + f2);
                const double Fwg = Fg / Fw;
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                const double Gwg = Gg / Gw;
#endif
                modes.omega[index] = omega;
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                modes.fWaveScale[index] = Fg / Fwg;
                if (iMode == 0) modes.inertialScale[iJ] = 0.5 * Fwg / Fg;
#else
                modes.Fwg[index] = Fwg;
#endif

                const double prefactor = signNorm * std::sqrt(configuration.g * configuration.Lz / (2.0 * (N02 - f2)));
                modes.ApmDScaled[index] = (M / 2.0) * prefactor;
                modes.ApmWScaled[index] = complexValue(0.0, (Kh / 2.0) * prefactor);

                if (isWave) {
                    const auto UAp = complexValue(cosAlpha, -(f / omega) * sinAlpha);
                    const auto VAp = complexValue(sinAlpha, (f / omega) * cosAlpha);
                    const auto WAp = complexValue(0.0, -Kh * hpm);
                    const double NAp = -Kh * hpm / omega;
                    const auto ApmD = complexValue(0.0, -1.0 / (2.0 * Kh * hpm));
                    const double ApmN = -omega / (2.0 * Kh * hpm);
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                    modes.UApField[index] = complexValue(UAp.real * modes.fWaveScale[index],UAp.imag * modes.fWaveScale[index]);
                    modes.UAmField[index] = complexValue(UAp.real * modes.fWaveScale[index],-UAp.imag * modes.fWaveScale[index]);
                    modes.VApField[index] = complexValue(VAp.real * modes.fWaveScale[index],VAp.imag * modes.fWaveScale[index]);
                    modes.VAmField[index] = complexValue(VAp.real * modes.fWaveScale[index],-VAp.imag * modes.fWaveScale[index]);
                    modes.WApField[index] = complexValue(WAp.real * modes.gWaveScale[iJ],WAp.imag * modes.gWaveScale[iJ]);
                    modes.WAmField[index] = modes.WApField[index];
                    modes.NApField[index] = NAp * modes.gWaveScale[iJ]; modes.NAmField[index] = -modes.NApField[index];
                    modes.ApmDProjection[index] = complexValue(ApmD.real * modes.deltaScale[iJ],ApmD.imag * modes.deltaScale[iJ]);
                    modes.ApmNProjection[index] = ApmN * Gwg / Gg;
#else
                    modes.UAp[index] = UAp; modes.UAm[index] = conjugate(UAp);
                    modes.VAp[index] = VAp; modes.VAm[index] = conjugate(VAp);
                    modes.WAp[index] = WAp; modes.WAm[index] = WAp;
                    modes.NAp[index] = NAp; modes.NAm[index] = -NAp;
                    modes.ApmD[index] = ApmD; modes.ApmN[index] = ApmN;
#endif
                } else if (isInertial) {
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                    modes.UApField[index] = complexValue(modes.fWaveScale[index]); modes.VApField[index] = complexValue(0.0, modes.fWaveScale[index]);
                    modes.UAmField[index] = complexValue(modes.fWaveScale[index]); modes.VAmField[index] = complexValue(0.0, -modes.fWaveScale[index]);
#else
                    modes.UAp[index] = complexValue(1.0); modes.VAp[index] = complexValue(0.0,1.0);
                    modes.UAm[index] = complexValue(1.0); modes.VAm[index] = complexValue(0.0,-1.0);
#endif
                }

                if (isGeostrophic) {
                    double Lr2Inverse = iJ == 0 ? 0.0 : f2 / (configuration.g * modes.h0[iJ]);
                    const double denominator = Kh2 + Lr2Inverse;
                    const auto UA0 = complexValue(0.0, horizontal.l / denominator);
                    const auto VA0 = complexValue(0.0, -horizontal.k / denominator);
                    const double NA0 = iJ == 0 ? 0.0 : -(f / configuration.g) / denominator;
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                    modes.UA0Field[index] = complexValue(UA0.real * Fg,UA0.imag * Fg);
                    modes.VA0Field[index] = complexValue(VA0.real * Fg,VA0.imag * Fg);
                    modes.NA0Field[index] = NA0 * Gg;
                    modes.A0FromVorticity[index] = modes.inverseFg[iJ];
                    modes.A0FromBuoyancy[index] = iJ == 0 ? 0.0 : (-f / modes.h0[iJ]) * modes.inverseGg[iJ];
#else
                    modes.UA0[index] = UA0; modes.VA0[index] = VA0; modes.NA0[index] = NA0;
                    modes.A0Z[index] = 1.0; modes.A0N[index] = iJ == 0 ? 0.0 : -f / modes.h0[iJ];
#endif
                } else if (isMDA) {
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
                    modes.NA0Field[index] = Gg;
                    modes.A0FromBuoyancy[index] = modes.inverseGg[iJ];
                    modes.A0FromVorticity[index] = (f2 / (2.0 * modes.h0[iJ])) * modes.inverseFg[iJ];
#else
                    modes.NA0[index] = 1.0; modes.A0N[index] = 1.0; modes.A0Z[index] = f2 / (2.0 * modes.h0[iJ]);
#endif
                }
            }
        }

        candidate.halfSpectrumMappings_.NxHalf = configuration.Nx / 2 + 1;
        const auto halfRows = candidate.halfSpectrumMappings_.NxHalf * configuration.Ny;
        candidate.halfSpectrumMappings_.storageRowsByWVIndex.resize(candidate.fourierModes_.size());
        candidate.halfSpectrumMappings_.conjugatesStoredValueByWVIndex.resize(candidate.fourierModes_.size());
        std::vector<std::ptrdiff_t> represented(halfRows, -1);
        for (std::size_t iWV = 0; iWV < candidate.fourierModes_.size(); ++iWV) {
            const auto& mode = candidate.fourierModes_[iWV];
            if (mode.kMode >= 0) {
                const auto row = halfRow(mode.kMode, mode.lMode, candidate.halfSpectrumMappings_.NxHalf, configuration.Ny);
                candidate.halfSpectrumMappings_.directRows.push_back(row);
                candidate.halfSpectrumMappings_.directWVIndices.push_back(iWV);
                candidate.halfSpectrumMappings_.storageRowsByWVIndex[iWV] = row;
                represented[row] = static_cast<std::ptrdiff_t>(iWV);
            } else {
                const auto row = halfRow(-mode.kMode, -mode.lMode, candidate.halfSpectrumMappings_.NxHalf, configuration.Ny);
                candidate.halfSpectrumMappings_.conjugatedRows.push_back(row);
                candidate.halfSpectrumMappings_.conjugatedWVIndices.push_back(iWV);
                candidate.halfSpectrumMappings_.storageRowsByWVIndex[iWV] = row;
                candidate.halfSpectrumMappings_.conjugatesStoredValueByWVIndex[iWV] = 1;
                represented[row] = static_cast<std::ptrdiff_t>(iWV);
            }
        }
        for (std::size_t iL = 0; iL < configuration.Ny; ++iL) {
            const std::int64_t lMode = iL <= configuration.Ny / 2 ? static_cast<std::int64_t>(iL) : static_cast<std::int64_t>(iL) - static_cast<std::int64_t>(configuration.Ny);
            const auto destination = halfRow(0, lMode, candidate.halfSpectrumMappings_.NxHalf, configuration.Ny);
            const auto source = halfRow(0, -lMode, candidate.halfSpectrumMappings_.NxHalf, configuration.Ny);
            if (represented[destination] < 0 && represented[source] >= 0) {
                candidate.halfSpectrumMappings_.hermitianCompletionRows.push_back(destination);
                candidate.halfSpectrumMappings_.hermitianSourceRows.push_back(source);
            }
            if (lMode == 0 || (configuration.Ny % 2 == 0 && std::abs(lMode) == static_cast<std::int64_t>(configuration.Ny / 2))) {
                if (represented[destination] >= 0) candidate.halfSpectrumMappings_.selfConjugateRows.push_back(destination);
            }
        }
        std::reverse(candidate.halfSpectrumMappings_.hermitianCompletionRows.begin(),candidate.halfSpectrumMappings_.hermitianCompletionRows.end());
        std::reverse(candidate.halfSpectrumMappings_.hermitianSourceRows.begin(),candidate.halfSpectrumMappings_.hermitianSourceRows.end());

        descriptor = std::move(candidate);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure, "Unable to allocate immutable kernel descriptor storage."};
    } catch (const std::overflow_error& error) {
        return {WVKernelStatusCode::sizeOverflow, error.what()};
    }
}

std::size_t WVTransformConstantStratificationDescriptor::persistentBytes() const noexcept {
    const auto& m = verticalModes_;
    return sizeof(*this) + bytes(fourierModes_) + halfSpectrumMappings_.persistentBytes() + bytes(m.z) + bytes(m.j) + bytes(m.h0) +
           bytes(m.verticalWavenumber) + bytes(m.Fg) + bytes(m.Gg) + bytes(m.inverseFg) + bytes(m.inverseGg) + bytes(m.Gwg) +
           bytes(m.inverseGwg) + bytes(m.GgOverGwg) + bytes(m.deltaScale) + bytes(m.inertialScale) + bytes(m.gWaveScale) +
           bytes(m.omega) +
#if WV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS
           bytes(m.fWaveScale) + bytes(m.UApField) + bytes(m.UAmField) + bytes(m.VApField) + bytes(m.VAmField) +
           bytes(m.WApField) + bytes(m.WAmField) + bytes(m.NApField) + bytes(m.NAmField) + bytes(m.UA0Field) + bytes(m.VA0Field) +
           bytes(m.NA0Field) + bytes(m.A0FromVorticity) + bytes(m.A0FromBuoyancy) + bytes(m.ApmDProjection) + bytes(m.ApmNProjection) +
#else
           bytes(m.Fwg) + bytes(m.UAp) + bytes(m.UAm) + bytes(m.VAp) + bytes(m.VAm) + bytes(m.WAp) + bytes(m.WAm) +
           bytes(m.NAp) + bytes(m.NAm) + bytes(m.UA0) + bytes(m.VA0) + bytes(m.NA0) + bytes(m.A0Z) + bytes(m.A0N) +
           bytes(m.ApmD) + bytes(m.ApmN) +
#endif
           bytes(m.ApmDScaled) + bytes(m.ApmWScaled);
}

WVKernelStatus validateStateAndFlux(
    const WVTransformConstantStratificationDescriptor& descriptor,
    const WVState& state,
    const WVFlux& flux) {
    if (!std::isfinite(state.t) || !std::isfinite(state.t0)) return {WVKernelStatusCode::invalidConfiguration, "State times must be finite."};
    const auto expected = descriptor.spectralShape();
    const WVKernelStatus statuses[] = {
        validateView(state.coefficients.Ap, expected, "Ap"), validateView(state.coefficients.Am, expected, "Am"), validateView(state.coefficients.A0, expected, "A0"),
        validateView(flux.Fp, expected, "Fp"), validateView(flux.Fm, expected, "Fm"), validateView(flux.F0, expected, "F0")};
    for (const auto& status : statuses) if (!status) return status;

    const auto complexBytes = expected.elementCount() * sizeof(WVComplex64);
    const void* inputs[] = {state.coefficients.Ap.data, state.coefficients.Am.data, state.coefficients.A0.data};
    const void* outputs[] = {flux.Fp.data, flux.Fm.data, flux.F0.data};
    for (std::size_t i = 0; i < 3; ++i) {
        for (std::size_t j = i + 1; j < 3; ++j) if (overlaps(outputs[i], complexBytes, outputs[j], complexBytes)) return {WVKernelStatusCode::overlappingArrays, "Flux outputs must not overlap."};
        for (const auto* input : inputs) if (overlaps(outputs[i], complexBytes, input, complexBytes)) return {WVKernelStatusCode::overlappingArrays, "Flux outputs must not overlap state inputs."};
    }
    return WVKernelStatus::ok();
}

} // namespace wavevortex
