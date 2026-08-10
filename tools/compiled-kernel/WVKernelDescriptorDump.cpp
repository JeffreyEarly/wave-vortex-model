#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>

using namespace wavevortex;

namespace {

template <typename T>
void numericArray(const std::vector<T>& values) {
    std::cout << '[';
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i != 0) std::cout << ',';
        std::cout << values[i];
    }
    std::cout << ']';
}

void complexComponent(const std::vector<WVComplex64>& values, bool imaginary) {
    std::cout << '[';
    for (std::size_t i = 0; i < values.size(); ++i) {
        if (i != 0) std::cout << ',';
        std::cout << (imaginary ? values[i].imag : values[i].real);
    }
    std::cout << ']';
}

double argument(char** values, int index) {
    return std::stod(values[index]);
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 15) {
        std::cerr << "usage: descriptor Nx Ny Nz Nj Lx Ly Lz N0 rho0 g rotationRate latitude isHydrostatic shouldAntialias\n";
        return 2;
    }
    WVTransformConstantStratificationConfiguration configuration;
    configuration.Nx = static_cast<std::size_t>(argument(argv, 1));
    configuration.Ny = static_cast<std::size_t>(argument(argv, 2));
    configuration.Nz = static_cast<std::size_t>(argument(argv, 3));
    configuration.Nj = static_cast<std::size_t>(argument(argv, 4));
    configuration.Lx = argument(argv, 5);
    configuration.Ly = argument(argv, 6);
    configuration.Lz = argument(argv, 7);
    configuration.N0 = argument(argv, 8);
    configuration.rho0 = argument(argv, 9);
    configuration.g = argument(argv, 10);
    configuration.planetaryRadius = 6.371e6;
    configuration.rotationRate = argument(argv, 11);
    configuration.latitude = argument(argv, 12);
    configuration.isHydrostatic = argument(argv, 13) != 0.0;
    configuration.shouldAntialias = argument(argv, 14) != 0.0;

    WVTransformConstantStratificationDescriptor descriptor;
    const auto status = WVTransformConstantStratificationDescriptor::create(configuration, descriptor);
    if (!status) {
        std::cerr << status.message << '\n';
        return 3;
    }

    std::vector<std::int64_t> kMode;
    std::vector<std::int64_t> lMode;
    std::vector<double> k;
    std::vector<double> l;
    std::vector<std::size_t> primary;
    std::vector<std::size_t> conjugate;
    for (const auto& mode : descriptor.fourierModes()) {
        kMode.push_back(mode.kMode);
        lMode.push_back(mode.lMode);
        k.push_back(mode.k);
        l.push_back(mode.l);
        primary.push_back(mode.dftPrimaryIndex + 1);
        conjugate.push_back(mode.dftConjugateIndex + 1);
    }

    std::cout << std::setprecision(17);
    std::cout << "{\"contractVersion\":" << WVKernelContractVersion << ",\"Nkl\":" << descriptor.Nkl();
    std::cout << ",\"spectralShape\":[" << descriptor.spectralShape().rows << ',' << descriptor.spectralShape().columns << ']';
    std::cout << ",\"coriolisFrequency\":" << descriptor.verticalModes().coriolisFrequency;
    std::cout << ",\"kMode\":"; numericArray(kMode);
    std::cout << ",\"lMode\":"; numericArray(lMode);
    std::cout << ",\"k\":"; numericArray(k);
    std::cout << ",\"l\":"; numericArray(l);
    std::cout << ",\"dftPrimaryIndices2D\":"; numericArray(primary);
    std::cout << ",\"dftConjugateIndices2D\":"; numericArray(conjugate);
    std::cout << ",\"halfDirectRows\":"; numericArray(descriptor.halfSpectrumMappings().directRows);
    std::cout << ",\"halfDirectWVIndices\":"; numericArray(descriptor.halfSpectrumMappings().directWVIndices);
    std::cout << ",\"halfConjugatedRows\":"; numericArray(descriptor.halfSpectrumMappings().conjugatedRows);
    std::cout << ",\"halfConjugatedWVIndices\":"; numericArray(descriptor.halfSpectrumMappings().conjugatedWVIndices);
    std::cout << ",\"halfCompletionRows\":"; numericArray(descriptor.halfSpectrumMappings().hermitianCompletionRows);
    std::cout << ",\"halfCompletionSourceRows\":"; numericArray(descriptor.halfSpectrumMappings().hermitianSourceRows);
    std::cout << ",\"halfSelfConjugateRows\":"; numericArray(descriptor.halfSpectrumMappings().selfConjugateRows);
    std::cout << ",\"z\":"; numericArray(descriptor.verticalModes().z);
    std::cout << ",\"j\":"; numericArray(descriptor.verticalModes().j);
    std::cout << ",\"h0\":"; numericArray(descriptor.verticalModes().h0);
    std::cout << ",\"hpm\":"; numericArray(descriptor.verticalModes().hpm);
    std::cout << ",\"omega\":"; numericArray(descriptor.verticalModes().omega);
    std::cout << ",\"Fg\":"; numericArray(descriptor.verticalModes().Fg);
    std::cout << ",\"Gg\":"; numericArray(descriptor.verticalModes().Gg);
    std::cout << ",\"Fwg\":"; numericArray(descriptor.verticalModes().Fwg);
    std::cout << ",\"Gwg\":"; numericArray(descriptor.verticalModes().Gwg);
    std::cout << ",\"UApReal\":"; complexComponent(descriptor.verticalModes().UAp,false);
    std::cout << ",\"UApImag\":"; complexComponent(descriptor.verticalModes().UAp,true);
    std::cout << ",\"UAmReal\":"; complexComponent(descriptor.verticalModes().UAm,false);
    std::cout << ",\"UAmImag\":"; complexComponent(descriptor.verticalModes().UAm,true);
    std::cout << ",\"VApReal\":"; complexComponent(descriptor.verticalModes().VAp,false);
    std::cout << ",\"VApImag\":"; complexComponent(descriptor.verticalModes().VAp,true);
    std::cout << ",\"VAmReal\":"; complexComponent(descriptor.verticalModes().VAm,false);
    std::cout << ",\"VAmImag\":"; complexComponent(descriptor.verticalModes().VAm,true);
    std::cout << ",\"WApReal\":"; complexComponent(descriptor.verticalModes().WAp,false);
    std::cout << ",\"WApImag\":"; complexComponent(descriptor.verticalModes().WAp,true);
    std::cout << ",\"WAmReal\":"; complexComponent(descriptor.verticalModes().WAm,false);
    std::cout << ",\"WAmImag\":"; complexComponent(descriptor.verticalModes().WAm,true);
    std::cout << ",\"NAp\":"; numericArray(descriptor.verticalModes().NAp);
    std::cout << ",\"NAm\":"; numericArray(descriptor.verticalModes().NAm);
    std::cout << ",\"UA0Real\":"; complexComponent(descriptor.verticalModes().UA0,false);
    std::cout << ",\"UA0Imag\":"; complexComponent(descriptor.verticalModes().UA0,true);
    std::cout << ",\"VA0Real\":"; complexComponent(descriptor.verticalModes().VA0,false);
    std::cout << ",\"VA0Imag\":"; complexComponent(descriptor.verticalModes().VA0,true);
    std::cout << ",\"NA0\":"; numericArray(descriptor.verticalModes().NA0);
    std::cout << ",\"A0Z\":"; numericArray(descriptor.verticalModes().A0Z);
    std::cout << ",\"A0N\":"; numericArray(descriptor.verticalModes().A0N);
    std::cout << ",\"ApmDReal\":"; complexComponent(descriptor.verticalModes().ApmD,false);
    std::cout << ",\"ApmDImag\":"; complexComponent(descriptor.verticalModes().ApmD,true);
    std::cout << ",\"ApmN\":"; numericArray(descriptor.verticalModes().ApmN);
    std::cout << ",\"ApmDScaled\":"; numericArray(descriptor.verticalModes().ApmDScaled);
    std::cout << ",\"ApmWScaledReal\":"; complexComponent(descriptor.verticalModes().ApmWScaled,false);
    std::cout << ",\"ApmWScaledImag\":"; complexComponent(descriptor.verticalModes().ApmWScaled,true);
    std::cout << "}\n";
    return 0;
}
