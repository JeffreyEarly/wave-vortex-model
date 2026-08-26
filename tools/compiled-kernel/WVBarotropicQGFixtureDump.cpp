#include "WaveVortexKernel/WVTransformBarotropicQGKernel.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

using namespace wavevortex;

namespace {

double argument(char** values, int index) {
    return std::stod(values[index]);
}

template <typename T>
void numericArray(const std::vector<T>& values) {
    std::cout << '[';
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) std::cout << ',';
        std::cout << values[index];
    }
    std::cout << ']';
}

void complexComponent(const std::vector<WVComplex64>& values,
                      bool imaginary) {
    std::cout << '[';
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) std::cout << ',';
        std::cout << (imaginary ? values[index].imag : values[index].real);
    }
    std::cout << ']';
}

void namedArray(const char* name, const std::vector<double>& values) {
    std::cout << ",\"" << name << "\":";
    numericArray(values);
}

void namedComplex(const char* name,
                  const std::vector<WVComplex64>& values) {
    std::cout << ",\"" << name << "Real\":";
    complexComponent(values, false);
    std::cout << ",\"" << name << "Imag\":";
    complexComponent(values, true);
}

void require(const WVKernelStatus& status) {
    if (!status) throw std::runtime_error(status.message);
}

std::vector<WVComplex64> deterministicCoefficients(
    const WVTransformBarotropicQGDescriptor& descriptor) {
    std::vector<WVComplex64> values(descriptor.Nkl());
    for (std::size_t index = 0; index < values.size(); ++index) {
        values[index] = {
            2e-5 * std::sin(0.31 * static_cast<double>(index + 1)),
            1e-5 * std::cos(0.17 * static_cast<double>(index + 3))};
        const auto& mode = descriptor.fourierModes()[index];
        if (mode.Kh == 0.0) values[index] = {};
        if (mode.dftPrimaryIndex == mode.dftConjugateIndex)
            values[index].imag = 0.0;
    }
    return values;
}

std::vector<double> field(WVTransformBarotropicQGKernel& kernel,
                          const std::vector<WVComplex64>& A0,
                          WVBarotropicQGField name) {
    std::vector<double> output(
        kernel.descriptor().spatialShape().elementCount());
    const WVComplexConstView input{
        A0.data(), kernel.descriptor().spectralShape()};
    WVRealView destination{
        output.data(), kernel.descriptor().spatialShape()};
    require(kernel.transformA0ToField(input, name, destination));
    return output;
}

std::vector<double> fieldWithDerivatives(
    WVTransformBarotropicQGKernel& kernel,
    const std::vector<WVComplex64>& A0,
    WVBarotropicQGField name) {
    const auto& configuration = kernel.descriptor().configuration();
    std::vector<double> output(3 * configuration.Nx * configuration.Ny);
    const WVComplexConstView input{
        A0.data(), kernel.descriptor().spectralShape()};
    WVRealFieldBundleView destination{
        output.data(), {configuration.Nx, configuration.Ny, 1, 3}};
    require(kernel.transformA0ToFieldWithDerivatives(input, name,
                                                     destination));
    return output;
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 12) {
        std::cerr << "usage: fixture Nx Ny Lx Ly h j g rotationRate "
                     "latitude shouldAntialias planetaryRadius\n";
        return 2;
    }
    try {
        WVTransformBarotropicQGConfiguration configuration;
        configuration.Nx = static_cast<std::size_t>(argument(argv, 1));
        configuration.Ny = static_cast<std::size_t>(argument(argv, 2));
        configuration.Lx = argument(argv, 3);
        configuration.Ly = argument(argv, 4);
        configuration.h = argument(argv, 5);
        configuration.j = static_cast<std::uint32_t>(argument(argv, 6));
        configuration.g = argument(argv, 7);
        configuration.rotationRate = argument(argv, 8);
        configuration.latitude = argument(argv, 9);
        configuration.shouldAntialias = argument(argv, 10) != 0.0;
        configuration.planetaryRadius = argument(argv, 11);

        std::unique_ptr<WVTransformBarotropicQGKernel> kernel;
        require(WVTransformBarotropicQGKernel::create(
            configuration,
            std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),
            kernel));
        const auto& descriptor = kernel->descriptor();
        const auto& modes = descriptor.modes();
        const auto A0 = deterministicCoefficients(descriptor);
        const WVComplexConstView input{A0.data(), descriptor.spectralShape()};

        std::vector<std::int64_t> kMode;
        std::vector<std::int64_t> lMode;
        std::vector<double> k;
        std::vector<double> l;
        std::vector<double> Kh;
        std::vector<std::size_t> primary;
        std::vector<std::size_t> conjugate;
        for (const auto& mode : descriptor.fourierModes()) {
            kMode.push_back(mode.kMode);
            lMode.push_back(mode.lMode);
            k.push_back(mode.k);
            l.push_back(mode.l);
            Kh.push_back(mode.Kh);
            primary.push_back(mode.dftPrimaryIndex + 1);
            conjugate.push_back(mode.dftConjugateIndex + 1);
        }

        const auto u = field(*kernel, A0, WVBarotropicQGField::u);
        const auto v = field(*kernel, A0, WVBarotropicQGField::v);
        const auto eta = field(*kernel, A0, WVBarotropicQGField::eta);
        const auto pi = field(*kernel, A0, WVBarotropicQGField::pi);
        const auto psi = field(*kernel, A0, WVBarotropicQGField::psi);
        const auto qgpv = field(*kernel, A0, WVBarotropicQGField::qgpv);
        const auto zetaZ = field(*kernel, A0, WVBarotropicQGField::zetaZ);
        const auto ssh = field(*kernel, A0, WVBarotropicQGField::ssh);
        const auto qgpvDerivatives = fieldWithDerivatives(
            *kernel, A0, WVBarotropicQGField::qgpv);
        const auto psiDerivatives = fieldWithDerivatives(
            *kernel, A0, WVBarotropicQGField::psi);

        std::vector<WVComplex64> projectedA0(descriptor.Nkl());
        WVRealConstView qgpvInput{qgpv.data(), descriptor.spatialShape()};
        WVComplexView projectedOutput{
            projectedA0.data(), descriptor.spectralShape()};
        require(kernel->transformQGPVToA0(qgpvInput, projectedOutput));

        std::vector<WVComplex64> evolvedA0(descriptor.Nkl());
        WVComplexView evolvedOutput{
            evolvedA0.data(), descriptor.spectralShape()};
        require(kernel->evolveA0(input, 37.0, evolvedOutput));

        std::vector<WVComplex64> nonlinear(descriptor.Nkl());
        WVComplexView nonlinearOutput{
            nonlinear.data(), descriptor.spectralShape()};
        require(kernel->nonlinearFlux(input, nonlinearOutput));

        double energy = 0.0;
        double spatialEnergy = 0.0;
        double enstrophy = 0.0;
        double spatialEnstrophy = 0.0;
        double maximumSpeed = 0.0;
        require(kernel->totalEnergy(input, energy));
        require(kernel->totalEnergySpatiallyIntegrated(input,
                                                       spatialEnergy));
        require(kernel->totalEnstrophy(input, enstrophy));
        require(kernel->totalEnstrophySpatiallyIntegrated(
            input, spatialEnstrophy));
        require(kernel->uvMax(input, maximumSpeed));

        std::cout << std::setprecision(17);
        std::cout << "{\"contractVersion\":" << WVKernelContractVersion
                  << ",\"Nkl\":" << descriptor.Nkl()
                  << ",\"spatialShape\":[" << configuration.Nx << ','
                  << configuration.Ny << ']'
                  << ",\"spectralShape\":[1," << descriptor.Nkl() << ']'
                  << ",\"j\":" << configuration.j
                  << ",\"shouldAntialias\":"
                  << (configuration.shouldAntialias ? "true" : "false")
                  << ",\"coriolisFrequency\":"
                  << modes.coriolisFrequency
                  << ",\"deformationWavenumberSquared\":"
                  << modes.deformationWavenumberSquared;
        std::cout << ",\"kMode\":"; numericArray(kMode);
        std::cout << ",\"lMode\":"; numericArray(lMode);
        namedArray("k", k);
        namedArray("l", l);
        namedArray("Kh", Kh);
        std::cout << ",\"dftPrimaryIndices2D\":"; numericArray(primary);
        std::cout << ",\"dftConjugateIndices2D\":"; numericArray(conjugate);
        std::cout << ",\"halfDirectRows\":";
        numericArray(descriptor.halfSpectrumMappings().directRows);
        std::cout << ",\"halfDirectWVIndices\":";
        numericArray(descriptor.halfSpectrumMappings().directWVIndices);
        std::cout << ",\"halfConjugatedRows\":";
        numericArray(descriptor.halfSpectrumMappings().conjugatedRows);
        std::cout << ",\"halfConjugatedWVIndices\":";
        numericArray(descriptor.halfSpectrumMappings().conjugatedWVIndices);
        std::cout << ",\"halfCompletionRows\":";
        numericArray(descriptor.halfSpectrumMappings().hermitianCompletionRows);
        std::cout << ",\"halfCompletionSourceRows\":";
        numericArray(descriptor.halfSpectrumMappings().hermitianSourceRows);
        std::cout << ",\"halfSelfConjugateRows\":";
        numericArray(descriptor.halfSpectrumMappings().selfConjugateRows);
        namedComplex("uFactor", modes.uFactor);
        namedComplex("vFactor", modes.vFactor);
        namedArray("etaFactor", modes.etaFactor);
        namedArray("piFactor", modes.piFactor);
        namedArray("psiFactor", modes.psiFactor);
        namedArray("qgpvFactor", modes.qgpvFactor);
        namedArray("zetaZFactor", modes.zetaZFactor);
        namedArray("energyFactor", modes.energyFactor);
        namedArray("enstrophyFactor", modes.enstrophyFactor);
        namedComplex("A0", A0);
        namedComplex("projectedA0", projectedA0);
        namedComplex("evolvedA0", evolvedA0);
        namedComplex("nonlinearF0", nonlinear);
        namedArray("u", u);
        namedArray("v", v);
        namedArray("eta", eta);
        namedArray("pi", pi);
        namedArray("psi", psi);
        namedArray("qgpv", qgpv);
        namedArray("zetaZ", zetaZ);
        namedArray("ssh", ssh);
        namedArray("qgpvWithDerivatives", qgpvDerivatives);
        namedArray("psiWithDerivatives", psiDerivatives);
        std::cout << ",\"totalEnergy\":" << energy
                  << ",\"totalEnergySpatiallyIntegrated\":"
                  << spatialEnergy
                  << ",\"totalEnstrophy\":" << enstrophy
                  << ",\"totalEnstrophySpatiallyIntegrated\":"
                  << spatialEnstrophy
                  << ",\"uvMax\":" << maximumSpeed
                  << ",\"coefficientOrderingIdentifier\":\""
                  << kernel->coefficientOrderingIdentifier() << '\"'
                  << ",\"normalizationIdentifier\":\""
                  << kernel->normalizationIdentifier() << '\"'
                  << ",\"antialiasImplementationIdentifier\":\""
                  << kernel->antialiasImplementationIdentifier() << '\"'
                  << ",\"providerIdentifier\":\""
                  << kernel->engineIdentifier() << '\"'
                  << ",\"providerLibraryIdentity\":\""
                  << kernel->engineLibraryIdentity() << '\"'
                  << ",\"persistentBytes\":" << kernel->persistentBytes()
                  << ",\"scratchBytes\":" << kernel->scratchBytes()
                  << ",\"persistentFullHermitianBytes\":"
                  << kernel->metrics().persistentFullHermitianBytes
                  << ",\"planCount\":" << kernel->metrics().planCount
                  << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 3;
    }
}
