#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <set>
#include <stdexcept>

namespace {

using wavevortex::WVTransformConstantStratificationConfiguration;
using wavevortex::WVTransformConstantStratificationDescriptor;

WVTransformConstantStratificationConfiguration configuration(std::size_t nx, std::size_t ny, std::size_t nz, std::size_t nj, bool hydrostatic) {
    WVTransformConstantStratificationConfiguration value;
    value.Nx = nx;
    value.Ny = ny;
    value.Nz = nz;
    value.Nj = nj;
    value.Lx = 15000.0;
    value.Ly = 15000.0;
    value.Lz = 1300.0;
    value.N0 = 5.2e-3;
    value.rho0 = 1025.0;
    value.g = 9.81;
    value.planetaryRadius = 6.371e6;
    value.rotationRate = 7.2921e-5;
    value.latitude = 33.0;
    value.isHydrostatic = hydrostatic;
    value.shouldAntialias = true;
    return value;
}

void report(std::size_t nx, std::size_t ny, std::size_t nz, std::size_t nj, bool hydrostatic) {
    WVTransformConstantStratificationDescriptor descriptor;
    const auto status = WVTransformConstantStratificationDescriptor::create(configuration(nx,ny,nz,nj,hydrostatic),descriptor);
    if (!status) throw std::runtime_error(status.message);
    const auto& mapping = descriptor.halfSpectrumMappings();
    const auto& modes = descriptor.fourierModes();
    const auto denseRows = mapping.NxHalf * ny;
    std::set<std::size_t> represented(mapping.storageRowsByWVIndex.begin(),mapping.storageRowsByWVIndex.end());
    if (represented.size() != modes.size()) throw std::runtime_error("A retained Fourier mode aliases another half-spectrum row.");
    std::size_t maximumK = 0;
    std::size_t maximumL = 0;
    for (const auto& mode : modes) {
        maximumK = std::max(maximumK,static_cast<std::size_t>(std::abs(mode.kMode)));
        maximumL = std::max(maximumL,static_cast<std::size_t>(std::abs(mode.lMode)));
    }
    const auto retainedCoefficients = modes.size() * nj;
    const auto denseCoefficients = denseRows * nj;
    std::cout << "{\"Nx\":" << nx
              << ",\"Ny\":" << ny
              << ",\"Nz\":" << nz
              << ",\"Nj\":" << nj
              << ",\"hydrostatic\":" << (hydrostatic ? "true" : "false")
              << ",\"denseHalfRows\":" << denseRows
              << ",\"retainedHalfRows\":" << represented.size()
              << ",\"knownZeroHalfRows\":" << denseRows - represented.size()
              << ",\"retainedHalfFraction\":" << static_cast<double>(represented.size()) / static_cast<double>(denseRows)
              << ",\"retainedCoefficients\":" << retainedCoefficients
              << ",\"denseCoefficients\":" << denseCoefficients
              << ",\"knownZeroCoefficients\":" << denseCoefficients - retainedCoefficients
              << ",\"maximumKMode\":" << maximumK
              << ",\"maximumLMode\":" << maximumL
              << ",\"denseKColumns\":" << mapping.NxHalf
              << ",\"liveKColumns\":" << maximumK + 1
              << ",\"discardedR2COutputs\":" << denseCoefficients - retainedCoefficients
              << "}\n";
}

} // namespace

int main() {
    try {
        // Repeat construction to exercise descriptor ownership without invoking MATLAB or an FFT provider.
        for (std::size_t iteration = 0; iteration < 16; ++iteration) {
            report(128,128,33,21,true);
            report(128,128,33,21,false);
            report(256,256,65,42,true);
            report(256,256,65,42,false);
        }
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
