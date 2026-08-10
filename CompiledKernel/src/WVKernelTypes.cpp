#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
#include <stdexcept>

namespace wavevortex {
namespace {

constexpr double pi = 3.141592653589793238462643383279502884;

bool finitePositive(double value) {
    return std::isfinite(value) && value > 0.0;
}

std::vector<std::int64_t> dftModes(std::size_t n) {
    std::vector<std::int64_t> modes;
    modes.reserve(n);
    const auto positiveCount = (n + 1) / 2;
    for (std::size_t value = 0; value < positiveCount; ++value) {
        modes.push_back(static_cast<std::int64_t>(value));
    }
    const auto negativeCount = n / 2;
    for (std::size_t value = negativeCount; value > 0; --value) {
        modes.push_back(-static_cast<std::int64_t>(value));
    }
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

bool overlaps(const void* a, std::size_t aBytes, const void* b, std::size_t bBytes) {
    if (a == nullptr || b == nullptr || aBytes == 0 || bBytes == 0) {
        return false;
    }
    const auto aBegin = reinterpret_cast<std::uintptr_t>(a);
    const auto bBegin = reinterpret_cast<std::uintptr_t>(b);
    return aBegin < bBegin + bBytes && bBegin < aBegin + aBytes;
}

template <typename T>
WVKernelStatus validateView(const WVMatrixView<T>& view, WVShape2D expected, const char* name) {
    if (view.shape.rows != expected.rows || view.shape.columns != expected.columns) {
        return {WVKernelStatusCode::invalidShape, std::string(name) + " must have shape [Nz,Nkl]."};
    }
    if (view.data == nullptr && expected.elementCount() != 0) {
        return {WVKernelStatusCode::invalidPointer, std::string(name) + " has a null data pointer."};
    }
    return WVKernelStatus::ok();
}

} // namespace

std::size_t WVShape2D::elementCount() const {
    if (rows != 0 && columns > std::numeric_limits<std::size_t>::max() / rows) {
        throw std::overflow_error("WVShape2D element count overflow");
    }
    return rows * columns;
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
    if (configuration.Nx > std::numeric_limits<std::size_t>::max() / configuration.Ny) {
        return {WVKernelStatusCode::sizeOverflow, "Horizontal grid element count overflow."};
    }
    if (!finitePositive(configuration.Lx) || !finitePositive(configuration.Ly) || !finitePositive(configuration.Lz) ||
        !finitePositive(configuration.N0) || !finitePositive(configuration.rho0) || !finitePositive(configuration.g) ||
        !finitePositive(configuration.planetaryRadius) || !finitePositive(configuration.rotationRate) ||
        !std::isfinite(configuration.latitude) || std::abs(configuration.latitude) > 90.0) {
        return {WVKernelStatusCode::invalidConfiguration, "Physical lengths and constants must be finite and positive, and latitude must lie in [-90,90]."};
    }

    try {
        WVTransformConstantStratificationDescriptor candidate;
        candidate.configuration_ = configuration;
        const auto kModes = dftModes(configuration.Nx);
        const auto lModes = dftModes(configuration.Ny);
        const double maxAbsK = 2.0 * pi * (static_cast<double>(configuration.Nx / 2) / configuration.Lx);

        for (const auto lMode : lModes) {
            for (const auto kMode : kModes) {
                if (!isPrimary(kMode, lMode, configuration.Nx, configuration.Ny) || nyquist(kMode, lMode, configuration.Nx, configuration.Ny)) {
                    continue;
                }
                const double k = 2.0 * pi * (static_cast<double>(kMode) / configuration.Lx);
                const double l = 2.0 * pi * (static_cast<double>(lMode) / configuration.Ly);
                if (configuration.shouldAntialias && std::sqrt(k * k + l * l) > 2.0 * maxAbsK / 3.0) {
                    continue;
                }
                const auto iK = dftIndexForMode(kMode, configuration.Nx);
                const auto iL = dftIndexForMode(lMode, configuration.Ny);
                const auto conjugateK = dftIndexForMode(-kMode, configuration.Nx);
                const auto conjugateL = dftIndexForMode(-lMode, configuration.Ny);
                candidate.fourierModes_.push_back({kMode, lMode, k, l, iK + configuration.Nx * iL, conjugateK + configuration.Nx * conjugateL});
            }
        }
        std::stable_sort(candidate.fourierModes_.begin(), candidate.fourierModes_.end(), [](const WVFourierMode& a, const WVFourierMode& b) {
            const double aKh = std::sqrt(a.k * a.k + a.l * a.l);
            const double bKh = std::sqrt(b.k * b.k + b.l * b.l);
            if (aKh != bKh) return aKh < bKh;
            if (a.k != b.k) return a.k < b.k;
            return a.l < b.l;
        });

        candidate.verticalModes_.coriolisFrequency = 2.0 * configuration.rotationRate * std::sin(configuration.latitude * pi / 180.0);
        candidate.verticalModes_.z.resize(configuration.Nz);
        candidate.verticalModes_.j.resize(configuration.Nj);
        candidate.verticalModes_.h0.resize(configuration.Nj);
        const double dz = configuration.Lz / static_cast<double>(configuration.Nz - 1);
        for (std::size_t i = 0; i < configuration.Nz; ++i) {
            candidate.verticalModes_.z[i] = dz * static_cast<double>(i) - configuration.Lz;
        }
        for (std::size_t i = 0; i < configuration.Nj; ++i) {
            candidate.verticalModes_.j[i] = static_cast<double>(i);
            if (i == 0) {
                candidate.verticalModes_.h0[i] = configuration.Lz;
            } else {
                const double m = static_cast<double>(i) * pi / configuration.Lz;
                candidate.verticalModes_.h0[i] = configuration.N0 * configuration.N0 / (configuration.g * m * m);
            }
        }

        if (!candidate.fourierModes_.empty() && configuration.Nj > std::numeric_limits<std::size_t>::max() / candidate.fourierModes_.size()) {
            return {WVKernelStatusCode::sizeOverflow, "Modal descriptor element count overflow."};
        }
        const auto modalCount = configuration.Nj * candidate.fourierModes_.size();
        candidate.verticalModes_.hpm.resize(modalCount);
        candidate.verticalModes_.omega.resize(modalCount);
        candidate.verticalModes_.Fg.resize(modalCount);
        candidate.verticalModes_.Gg.resize(modalCount);
        candidate.verticalModes_.Fwg.resize(modalCount);
        candidate.verticalModes_.Gwg.resize(modalCount);
        const double N02 = configuration.N0 * configuration.N0;
        const double f2 = candidate.verticalModes_.coriolisFrequency * candidate.verticalModes_.coriolisFrequency;
        if (!configuration.isHydrostatic && N02 <= f2) {
            return {WVKernelStatusCode::invalidConfiguration, "Nonhydrostatic constant stratification requires N0 squared greater than f squared."};
        }
        for (std::size_t iMode = 0; iMode < candidate.fourierModes_.size(); ++iMode) {
            const auto& horizontalMode = candidate.fourierModes_[iMode];
            const double Kh2 = horizontalMode.k * horizontalMode.k + horizontalMode.l * horizontalMode.l;
            for (std::size_t iJ = 0; iJ < configuration.Nj; ++iJ) {
                const auto index = iJ + configuration.Nj * iMode;
                const double M = static_cast<double>(iJ) * pi / configuration.Lz;
                const double signNorm = iJ % 2 == 0 ? 1.0 : -1.0;
                double hpm = 1.0;
                if (iJ > 0) {
                    hpm = configuration.isHydrostatic ? N02 / (configuration.g * M * M) : (N02 - f2) / (configuration.g * (M * M + Kh2));
                }
                const double Fg = iJ == 0 ? 2.0 : signNorm * candidate.verticalModes_.h0[iJ] * M * std::sqrt(2.0 * configuration.g / (configuration.Lz * N02));
                const double Gg = iJ == 0 ? 1.0 : signNorm * std::sqrt(2.0 * configuration.g / (configuration.Lz * N02));
                double Fw = Fg;
                double Gw = Gg;
                if (!configuration.isHydrostatic) {
                    Fw = iJ == 0 ? 2.0 : signNorm * hpm * M * std::sqrt(2.0 * configuration.g / (configuration.Lz * (N02 - f2)));
                    Gw = iJ == 0 ? 1.0 : signNorm * std::sqrt(2.0 * configuration.g / (configuration.Lz * (N02 - f2)));
                }
                candidate.verticalModes_.hpm[index] = hpm;
                candidate.verticalModes_.omega[index] = std::sqrt(configuration.g * hpm * Kh2 + f2);
                candidate.verticalModes_.Fg[index] = Fg;
                candidate.verticalModes_.Gg[index] = Gg;
                candidate.verticalModes_.Fwg[index] = Fg / Fw;
                candidate.verticalModes_.Gwg[index] = Gg / Gw;
            }
        }
        descriptor = std::move(candidate);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure, "Unable to allocate immutable kernel descriptor storage."};
    } catch (const std::overflow_error& error) {
        return {WVKernelStatusCode::sizeOverflow, error.what()};
    }
}

WVKernelStatus validateStateAndFlux(
    const WVTransformConstantStratificationDescriptor& descriptor,
    const WVState& state,
    const WVGradientMasks& masks,
    const WVFlux& flux) {
    if (!std::isfinite(state.t) || !std::isfinite(state.t0)) {
        return {WVKernelStatusCode::invalidConfiguration, "State times must be finite."};
    }
    const auto expected = descriptor.spectralShape();
    const WVKernelStatus statuses[] = {
        validateView(state.coefficients.Ap, expected, "Ap"), validateView(state.coefficients.Am, expected, "Am"), validateView(state.coefficients.A0, expected, "A0"),
        validateView(masks.ApUMask, expected, "ApUMask"), validateView(masks.AmUMask, expected, "AmUMask"), validateView(masks.A0UMask, expected, "A0UMask"),
        validateView(masks.ApUxMask, expected, "ApUxMask"), validateView(masks.AmUxMask, expected, "AmUxMask"), validateView(masks.A0UxMask, expected, "A0UxMask"),
        validateView(flux.Fp, expected, "Fp"), validateView(flux.Fm, expected, "Fm"), validateView(flux.F0, expected, "F0")
    };
    for (const auto& status : statuses) {
        if (!status) return status;
    }

    const auto complexBytes = expected.elementCount() * sizeof(WVComplex64);
    const auto realBytes = expected.elementCount() * sizeof(double);
    const void* inputs[] = {state.coefficients.Ap.data, state.coefficients.Am.data, state.coefficients.A0.data,
        masks.ApUMask.data, masks.AmUMask.data, masks.A0UMask.data, masks.ApUxMask.data, masks.AmUxMask.data, masks.A0UxMask.data};
    const std::size_t inputBytes[] = {complexBytes, complexBytes, complexBytes, realBytes, realBytes, realBytes, realBytes, realBytes, realBytes};
    const void* outputs[] = {flux.Fp.data, flux.Fm.data, flux.F0.data};
    for (std::size_t i = 0; i < 3; ++i) {
        for (std::size_t j = i + 1; j < 3; ++j) {
            if (overlaps(outputs[i], complexBytes, outputs[j], complexBytes)) {
                return {WVKernelStatusCode::overlappingArrays, "Flux outputs must not overlap."};
            }
        }
        for (std::size_t j = 0; j < 9; ++j) {
            if (overlaps(outputs[i], complexBytes, inputs[j], inputBytes[j])) {
                return {WVKernelStatusCode::overlappingArrays, "Flux outputs must not overlap state or mask inputs."};
            }
        }
    }
    return WVKernelStatus::ok();
}

} // namespace wavevortex
