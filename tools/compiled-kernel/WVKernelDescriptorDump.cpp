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
    std::vector<double> Kh;
    std::vector<double> cosAlpha;
    std::vector<double> sinAlpha;
    std::vector<std::size_t> primary;
    std::vector<std::size_t> conjugate;
    for (const auto& mode : descriptor.fourierModes()) {
        kMode.push_back(mode.kMode);
        lMode.push_back(mode.lMode);
        k.push_back(mode.k);
        l.push_back(mode.l);
        Kh.push_back(mode.Kh);
        cosAlpha.push_back(mode.cosAlpha);
        sinAlpha.push_back(mode.sinAlpha);
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
    std::cout << ",\"Kh\":"; numericArray(Kh);
    std::cout << ",\"cosAlpha\":"; numericArray(cosAlpha);
    std::cout << ",\"sinAlpha\":"; numericArray(sinAlpha);
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
    std::cout << ",\"verticalWavenumber\":"; numericArray(descriptor.verticalModes().verticalWavenumber);
    std::cout << ",\"omega\":"; numericArray(descriptor.verticalModes().omega);
    std::cout << ",\"Fg\":"; numericArray(descriptor.verticalModes().Fg);
    std::cout << ",\"Gg\":"; numericArray(descriptor.verticalModes().Gg);
    std::cout << ",\"inertialScale\":"; numericArray(descriptor.verticalModes().inertialScale);
    std::cout << ",\"fWaveScale\":"; numericArray(descriptor.verticalModes().fWaveScale);
    std::cout << ",\"gWaveScale\":"; numericArray(descriptor.verticalModes().gWaveScale);
    std::cout << ",\"UApFieldReal\":"; complexComponent(descriptor.verticalModes().UApField,false);
    std::cout << ",\"UApFieldImag\":"; complexComponent(descriptor.verticalModes().UApField,true);
    std::cout << ",\"UAmFieldReal\":"; complexComponent(descriptor.verticalModes().UAmField,false);
    std::cout << ",\"UAmFieldImag\":"; complexComponent(descriptor.verticalModes().UAmField,true);
    std::cout << ",\"VApFieldReal\":"; complexComponent(descriptor.verticalModes().VApField,false);
    std::cout << ",\"VApFieldImag\":"; complexComponent(descriptor.verticalModes().VApField,true);
    std::cout << ",\"VAmFieldReal\":"; complexComponent(descriptor.verticalModes().VAmField,false);
    std::cout << ",\"VAmFieldImag\":"; complexComponent(descriptor.verticalModes().VAmField,true);
    std::cout << ",\"WApFieldReal\":"; complexComponent(descriptor.verticalModes().WApField,false);
    std::cout << ",\"WApFieldImag\":"; complexComponent(descriptor.verticalModes().WApField,true);
    std::cout << ",\"WAmFieldReal\":"; complexComponent(descriptor.verticalModes().WAmField,false);
    std::cout << ",\"WAmFieldImag\":"; complexComponent(descriptor.verticalModes().WAmField,true);
    std::cout << ",\"NApField\":"; numericArray(descriptor.verticalModes().NApField);
    std::cout << ",\"NAmField\":"; numericArray(descriptor.verticalModes().NAmField);
    std::cout << ",\"UA0FieldReal\":"; complexComponent(descriptor.verticalModes().UA0Field,false);
    std::cout << ",\"UA0FieldImag\":"; complexComponent(descriptor.verticalModes().UA0Field,true);
    std::cout << ",\"VA0FieldReal\":"; complexComponent(descriptor.verticalModes().VA0Field,false);
    std::cout << ",\"VA0FieldImag\":"; complexComponent(descriptor.verticalModes().VA0Field,true);
    std::cout << ",\"NA0Field\":"; numericArray(descriptor.verticalModes().NA0Field);
    std::cout << ",\"A0FromVorticity\":"; numericArray(descriptor.verticalModes().A0FromVorticity);
    std::cout << ",\"A0FromBuoyancy\":"; numericArray(descriptor.verticalModes().A0FromBuoyancy);
    std::cout << ",\"ApmDProjectionReal\":"; complexComponent(descriptor.verticalModes().ApmDProjection,false);
    std::cout << ",\"ApmDProjectionImag\":"; complexComponent(descriptor.verticalModes().ApmDProjection,true);
    std::cout << ",\"ApmNProjection\":"; numericArray(descriptor.verticalModes().ApmNProjection);
    std::cout << ",\"ApmDScaled\":"; numericArray(descriptor.verticalModes().ApmDScaled);
    std::cout << ",\"ApmWScaledReal\":"; complexComponent(descriptor.verticalModes().ApmWScaled,false);
    std::cout << ",\"ApmWScaledImag\":"; complexComponent(descriptor.verticalModes().ApmWScaled,true);
    std::cout << "}\n";
    return 0;
}
