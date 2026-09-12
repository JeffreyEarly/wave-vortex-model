#pragma once

#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <utility>
#include <vector>

namespace tile_screen {

inline constexpr std::size_t u = 0;
inline constexpr std::size_t v = 1;
inline constexpr std::size_t w = 2;
inline constexpr std::size_t eta = 3;

namespace detail {

inline std::uint64_t mix(std::uint64_t value) noexcept {
  value += 0x9e3779b97f4a7c15ULL;
  value = (value ^ (value >> 30U)) * 0xbf58476d1ce4e5b9ULL;
  value = (value ^ (value >> 27U)) * 0x94d049bb133111ebULL;
  return value ^ (value >> 31U);
}

inline std::uint64_t hash(std::size_t field, std::int64_t k, std::int64_t l,
                          std::uint64_t salt) noexcept {
  auto value = mix(static_cast<std::uint64_t>(field) ^ salt);
  value ^= mix(static_cast<std::uint64_t>(k) + 0x243f6a8885a308d3ULL);
  value ^= mix(static_cast<std::uint64_t>(l) + 0x13198a2e03707344ULL);
  return mix(value);
}

inline double signedAmplitude(std::uint64_t value) noexcept {
  const double magnitude = static_cast<double>(1U + value % 1021U) / 1021.0;
  return (value & (std::uint64_t{1} << 63U)) == 0 ? magnitude : -magnitude;
}

inline double coordinate(std::size_t z, std::size_t Nz) noexcept {
  return Nz > 1 ? static_cast<double>(z) / static_cast<double>(Nz - 1) : 0.0;
}

inline std::pair<double, double> envelope(std::size_t field, std::int64_t k,
                                          std::int64_t l, double coordinate) noexcept {
  const auto shape = hash(field, k, l, 0xa4093822299f31d0ULL);
  const double linear = 0.04 * static_cast<double>(1U + shape % 7U);
  const double quadratic = -0.015 * static_cast<double>(1U + (shape >> 8U) % 5U);
  return {1.0 + linear * coordinate + quadratic * coordinate * coordinate,
          linear + 2.0 * quadratic * coordinate};
}

inline wavevortex::WVComplex64 multiplyByI(
    wavevortex::WVComplex64 value, double wavenumber) noexcept {
  return {-wavenumber * value.imag, wavenumber * value.real};
}

} // namespace detail

inline wavevortex::WVComplex64 coefficient(std::size_t field, std::int64_t k,
                                            std::int64_t l, std::size_t z,
                                            std::size_t Nz, bool dz) noexcept {
  const auto shape = detail::envelope(field, k, l, detail::coordinate(z, Nz));
  const double vertical = dz ? shape.second : shape.first;
  const double real = detail::signedAmplitude(
      detail::hash(field, k, l, 0x082efa98ec4e6c89ULL));
  const double imag = k == 0 && l == 0
                          ? 0.0
                          : detail::signedAmplitude(
                                detail::hash(field, k, l, 0x452821e638d01377ULL));
  return {real * vertical, imag * vertical};
}

inline double directValue(
    std::size_t field, std::size_t x, std::size_t y, std::size_t z,
    std::size_t Nx, std::size_t Ny, std::size_t Nz,
    const std::vector<std::pair<std::int64_t, std::int64_t>> &modes,
    unsigned derivative) noexcept {
  if (modes.empty() || Nx == 0 || Ny == 0 || derivative > 3) return 0.0;
  constexpr double pi = 3.141592653589793238462643383279502884;
  const double xPhase = 2.0 * pi * static_cast<double>(x) / static_cast<double>(Nx);
  const double yPhase = 2.0 * pi * static_cast<double>(y) / static_cast<double>(Ny);
  double result = 0.0;
  for (const auto &mode : modes) {
    auto value = coefficient(field, mode.first, mode.second, z, Nz,
                             derivative == 3);
    if (derivative == 1)
      value = detail::multiplyByI(value, static_cast<double>(mode.first));
    else if (derivative == 2)
      value = detail::multiplyByI(value, static_cast<double>(mode.second));
    const double phase = static_cast<double>(mode.first) * xPhase +
                         static_cast<double>(mode.second) * yPhase;
    const double weight = mode.first == 0 && mode.second == 0 ? 1.0 : 2.0;
    result += weight * (value.real * std::cos(phase) - value.imag * std::sin(phase));
  }
  return result / static_cast<double>(modes.size());
}

inline double densityCorrection(std::size_t z, std::size_t Nz) noexcept {
  return 0.1 * std::cos(detail::coordinate(z, Nz));
}

inline double directFlux(
    std::size_t target, std::size_t x, std::size_t y, std::size_t z,
    std::size_t Nx, std::size_t Ny, std::size_t Nz,
    const std::vector<std::pair<std::int64_t, std::int64_t>> &modes,
    bool) noexcept {
  const double velocityU = directValue(u, x, y, z, Nx, Ny, Nz, modes, 0);
  const double velocityV = directValue(v, x, y, z, Nx, Ny, Nz, modes, 0);
  const double velocityW = directValue(w, x, y, z, Nx, Ny, Nz, modes, 0);
  const double derivativeX = directValue(target, x, y, z, Nx, Ny, Nz, modes, 1);
  const double derivativeY = directValue(target, x, y, z, Nx, Ny, Nz, modes, 2);
  const double derivativeZ = directValue(target, x, y, z, Nx, Ny, Nz, modes, 3);
  const double correction = target == eta
                                ? directValue(eta, x, y, z, Nx, Ny, Nz, modes, 0) *
                                      densityCorrection(z, Nz)
                                : 0.0;
  double flux = 0.0;
  flux -= velocityU * derivativeX;
  flux -= velocityV * derivativeY;
  flux -= velocityW * (derivativeZ + correction);
  return flux;
}

} // namespace tile_screen
