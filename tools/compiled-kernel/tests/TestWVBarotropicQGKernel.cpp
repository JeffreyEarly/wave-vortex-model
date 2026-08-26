#include "WaveVortexKernel/WVTransformBarotropicQGKernel.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <memory>
#include <string>
#include <vector>

using namespace wavevortex;

namespace {

constexpr double tolerance = 5e-12;

void require(bool condition, const std::string& message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}

WVTransformBarotropicQGConfiguration configuration(
    std::size_t Nx, std::size_t Ny, std::uint32_t j,
    bool shouldAntialias) {
    WVTransformBarotropicQGConfiguration value;
    value.Nx = Nx;
    value.Ny = Ny;
    value.Lx = 17000.0;
    value.Ly = 11000.0;
    value.h = 0.8;
    value.j = j;
    value.g = 9.81;
    value.planetaryRadius = 6.371e6;
    value.rotationRate = 7.2921e-5;
    value.latitude = 33.0;
    value.shouldAntialias = shouldAntialias;
    return value;
}

double relativeError(double actual, double expected) {
    return std::abs(actual - expected) /
           std::max(std::abs(expected), std::numeric_limits<double>::min());
}

double relativeError(const std::vector<double>& actual,
                     const std::vector<double>& expected) {
    double numerator = 0.0;
    double denominator = 0.0;
    for (std::size_t index = 0; index < actual.size(); ++index) {
        numerator = std::max(numerator,
                             std::abs(actual[index] - expected[index]));
        denominator = std::max(denominator, std::abs(expected[index]));
    }
    return numerator / std::max(denominator,
                                std::numeric_limits<double>::min());
}

double relativeError(const std::vector<WVComplex64>& actual,
                     const std::vector<WVComplex64>& expected) {
    double numerator = 0.0;
    double denominator = 0.0;
    for (std::size_t index = 0; index < actual.size(); ++index) {
        const std::complex<double> difference{
            actual[index].real - expected[index].real,
            actual[index].imag - expected[index].imag};
        numerator = std::max(numerator, std::abs(difference));
        denominator = std::max(
            denominator,
            std::abs(std::complex<double>{expected[index].real,
                                          expected[index].imag}));
    }
    return numerator / std::max(denominator,
                                std::numeric_limits<double>::min());
}

std::vector<WVComplex64> coefficients(
    const WVTransformBarotropicQGDescriptor& descriptor) {
    std::vector<WVComplex64> values(descriptor.Nkl());
    for (std::size_t index = 0; index < values.size(); ++index) {
        values[index] = {
            2e-5 * std::sin(0.31 * static_cast<double>(index + 1)),
            1e-5 * std::cos(0.17 * static_cast<double>(index + 3))};
        const auto& mode = descriptor.fourierModes()[index];
        if (mode.dftPrimaryIndex == mode.dftConjugateIndex)
            values[index].imag = 0.0;
    }
    return values;
}

std::complex<double> factor(const WVTransformBarotropicQGDescriptor& descriptor,
                            WVBarotropicQGField field,
                            std::size_t index) {
    const auto& modes = descriptor.modes();
    switch (field) {
        case WVBarotropicQGField::u:
            return {modes.uFactor[index].real, modes.uFactor[index].imag};
        case WVBarotropicQGField::v:
            return {modes.vFactor[index].real, modes.vFactor[index].imag};
        case WVBarotropicQGField::eta:
            return {modes.etaFactor[index], 0.0};
        case WVBarotropicQGField::pi:
        case WVBarotropicQGField::ssh:
            return {modes.piFactor[index], 0.0};
        case WVBarotropicQGField::psi:
            return {modes.psiFactor[index], 0.0};
        case WVBarotropicQGField::qgpv:
            return {modes.qgpvFactor[index], 0.0};
        case WVBarotropicQGField::zetaZ:
            return {modes.zetaZFactor[index], 0.0};
    }
    return {};
}

std::vector<double> directField(
    const WVTransformBarotropicQGDescriptor& descriptor,
    const std::vector<WVComplex64>& A0,
    WVBarotropicQGField field, int derivative = 0) {
    const auto& configuration = descriptor.configuration();
    std::vector<double> values(configuration.Nx * configuration.Ny);
    for (std::size_t y = 0; y < configuration.Ny; ++y) {
        for (std::size_t x = 0; x < configuration.Nx; ++x) {
            std::complex<double> sum;
            for (std::size_t index = 0; index < descriptor.Nkl(); ++index) {
                const auto& mode = descriptor.fourierModes()[index];
                std::complex<double> multiplier = factor(descriptor, field,
                                                         index);
                if (derivative == 1)
                    multiplier *= std::complex<double>(0.0, mode.k);
                else if (derivative == 2)
                    multiplier *= std::complex<double>(0.0, mode.l);
                const std::complex<double> coefficient(A0[index].real,
                                                       A0[index].imag);
                const double angle = 2.0 * 3.14159265358979323846 *
                    (static_cast<double>(mode.kMode *
                                         static_cast<std::int64_t>(x)) /
                         static_cast<double>(configuration.Nx) +
                     static_cast<double>(mode.lMode *
                                         static_cast<std::int64_t>(y)) /
                         static_cast<double>(configuration.Ny));
                const auto contribution = coefficient * multiplier *
                    std::complex<double>(std::cos(angle), std::sin(angle));
                sum += mode.dftPrimaryIndex == mode.dftConjugateIndex
                    ? contribution : 2.0 * std::real(contribution);
            }
            values[x + configuration.Nx * y] = sum.real();
        }
    }
    return values;
}

std::vector<WVComplex64> directForward(
    const WVTransformBarotropicQGDescriptor& descriptor,
    const std::vector<double>& values) {
    const auto& configuration = descriptor.configuration();
    const double normalization = 1.0 /
        static_cast<double>(configuration.Nx * configuration.Ny);
    std::vector<WVComplex64> result(descriptor.Nkl());
    for (std::size_t index = 0; index < descriptor.Nkl(); ++index) {
        const auto& mode = descriptor.fourierModes()[index];
        std::complex<double> sum;
        for (std::size_t y = 0; y < configuration.Ny; ++y) {
            for (std::size_t x = 0; x < configuration.Nx; ++x) {
                const double angle = -2.0 * 3.14159265358979323846 *
                    (static_cast<double>(mode.kMode *
                                         static_cast<std::int64_t>(x)) /
                         static_cast<double>(configuration.Nx) +
                     static_cast<double>(mode.lMode *
                                         static_cast<std::int64_t>(y)) /
                         static_cast<double>(configuration.Ny));
                sum += values[x + configuration.Nx * y] *
                       std::complex<double>(std::cos(angle), std::sin(angle));
            }
        }
        sum *= normalization;
        result[index] = {sum.real(), sum.imag()};
    }
    return result;
}

void testDescriptor(std::size_t Nx, std::size_t Ny,
                    std::uint32_t j, bool shouldAntialias) {
    const auto config = configuration(Nx, Ny, j, shouldAntialias);
    WVTransformBarotropicQGDescriptor descriptor;
    auto status = WVTransformBarotropicQGDescriptor::create(config, descriptor);
    require(static_cast<bool>(status), "descriptor creation");
    require(descriptor.spectralShape().rows == 1 && descriptor.Nkl() > 1,
            "compact rank-one spectral shape");
    require(descriptor.spatialShape().rows == Nx &&
                descriptor.spatialShape().columns == Ny,
            "nonsquare spatial shape");
    require(descriptor.halfSpectrumMappings().NxHalf == Nx / 2 + 1,
            "half-spectrum shape");
    for (const auto& mode : descriptor.fourierModes()) {
        require(!(Nx % 2 == 0 &&
                  mode.kMode == -static_cast<std::int64_t>(Nx / 2)),
                "x Nyquist excluded");
        require(!(Ny % 2 == 0 &&
                  mode.lMode == -static_cast<std::int64_t>(Ny / 2)),
                "y Nyquist excluded");
    }
    const auto& modes = descriptor.modes();
    require((j == 0 && modes.deformationWavenumberSquared == 0.0) ||
                (j == 1 && modes.deformationWavenumberSquared > 0.0),
            "j-dependent deformation scale");
    for (std::size_t index = 0; index < descriptor.Nkl(); ++index) {
        const auto& mode = descriptor.fourierModes()[index];
        const double K2 = mode.k * mode.k + mode.l * mode.l;
        if (K2 == 0.0) {
            require(modes.qgpvFactor[index] == 0.0 &&
                        modes.energyFactor[index] == 0.0,
                    "zero mode excluded from geostrophic fields");
            continue;
        }
        const double denominator =
            K2 + modes.deformationWavenumberSquared;
        require(relativeError(modes.energyFactor[index],
                              config.h / denominator) < 1e-15 &&
                    modes.enstrophyFactor[index] == config.h &&
                    modes.qgpvFactor[index] == 1.0,
                "MATLAB QGPV energy and enstrophy normalization");
        require((j == 0 && modes.etaFactor[index] == 0.0) ||
                    (j == 1 && modes.etaFactor[index] != 0.0),
                "j-dependent eta reconstruction");
    }
}

void testNumerics(std::size_t Nx, std::size_t Ny,
                  std::uint32_t j, bool shouldAntialias) {
    const auto config = configuration(Nx, Ny, j, shouldAntialias);
    std::unique_ptr<WVTransformBarotropicQGKernel> kernel;
    auto status = WVTransformBarotropicQGKernel::create(
        config, std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),
        kernel);
    require(static_cast<bool>(status) && kernel, "kernel creation");
    require(kernel->engineIdentifier() == "reference-direct" &&
                kernel->metrics().planCount == 3 &&
                kernel->metrics().persistentFullHermitianBytes == 0,
            "reference provider and compact plan contract");
    const auto expectedScratch =
        4 * (Nx / 2 + 1) * Ny * sizeof(WVComplex64) +
        5 * Nx * Ny * sizeof(double);
    const auto& accounting = kernel->metrics();
    const auto expectedPersistent = accounting.descriptorBytes +
        accounting.planBytes + accounting.engineBytes +
        accounting.kernelManagementBytes + accounting.scratchCapacityBytes;
    require(kernel->scratchBytes() == expectedScratch &&
                kernel->metrics().scratchCapacityBytes == expectedScratch &&
                kernel->persistentBytes() == expectedPersistent,
            "bounded exact persistent and scratch accounting");

    const auto A0 = coefficients(kernel->descriptor());
    const WVComplexConstView input{A0.data(), kernel->descriptor().spectralShape()};
    for (const auto field : {
             WVBarotropicQGField::u, WVBarotropicQGField::v,
             WVBarotropicQGField::eta, WVBarotropicQGField::pi,
             WVBarotropicQGField::psi, WVBarotropicQGField::qgpv,
             WVBarotropicQGField::zetaZ, WVBarotropicQGField::ssh}) {
        std::vector<double> actual(Nx * Ny);
        WVRealView output{actual.data(), kernel->descriptor().spatialShape()};
        status = kernel->transformA0ToField(input, field, output);
        require(static_cast<bool>(status), "field reconstruction");
        const auto expected = directField(kernel->descriptor(), A0, field);
        require(relativeError(actual, expected) < tolerance,
                "direct field parity");
    }

    std::vector<double> derivativeValues(3 * Nx * Ny);
    WVRealFieldBundleView derivatives{
        derivativeValues.data(), {Nx, Ny, 1, 3}};
    status = kernel->transformA0ToFieldWithDerivatives(
        input, WVBarotropicQGField::psi, derivatives);
    require(static_cast<bool>(status), "field derivative reconstruction");
    for (int derivative = 0; derivative < 3; ++derivative) {
        const auto expected = directField(kernel->descriptor(), A0,
                                          WVBarotropicQGField::psi,
                                          derivative);
        const std::vector<double> actual(
            derivativeValues.begin() + derivative * Nx * Ny,
            derivativeValues.begin() + (derivative + 1) * Nx * Ny);
        require(relativeError(actual, expected) < tolerance,
                "direct derivative parity");
    }

    const auto qgpv = directField(kernel->descriptor(), A0,
                                  WVBarotropicQGField::qgpv);
    std::vector<WVComplex64> projected(kernel->descriptor().Nkl());
    WVComplexView projectedView{projected.data(),
                                kernel->descriptor().spectralShape()};
    status = kernel->transformQGPVToA0(
        {qgpv.data(), kernel->descriptor().spatialShape()}, projectedView);
    require(static_cast<bool>(status), "QGPV to A0 projection");
    auto expectedProjected = A0;
    for (std::size_t index = 0; index < expectedProjected.size(); ++index)
        if (kernel->descriptor().modes().qgpvFactor[index] == 0.0)
            expectedProjected[index] = {};
    require(relativeError(projected, expectedProjected) < tolerance,
            "compact A0/QGPV round trip");

    const auto u = directField(kernel->descriptor(), A0,
                               WVBarotropicQGField::u);
    const auto v = directField(kernel->descriptor(), A0,
                               WVBarotropicQGField::v);
    const auto qx = directField(kernel->descriptor(), A0,
                                WVBarotropicQGField::qgpv, 1);
    const auto qy = directField(kernel->descriptor(), A0,
                                WVBarotropicQGField::qgpv, 2);
    std::vector<double> spatialFlux(Nx * Ny);
    for (std::size_t index = 0; index < spatialFlux.size(); ++index)
        spatialFlux[index] = -(u[index] * qx[index] +
                               v[index] * qy[index]);
    const auto expectedFlux = directForward(kernel->descriptor(), spatialFlux);
    std::vector<WVComplex64> actualFlux(kernel->descriptor().Nkl());
    WVComplexView fluxView{actualFlux.data(),
                           kernel->descriptor().spectralShape()};
    status = kernel->nonlinearFlux(input, fluxView);
    require(static_cast<bool>(status), "nonlinear PV tendency");
    require(relativeError(actualFlux, expectedFlux) < tolerance,
            "ordinary nonlinear PV advection parity");
    require(kernel->metrics().nonlinearFluxCallCount == 1 &&
                kernel->metrics().antialiasedNonlinearFluxCallCount ==
                    (shouldAntialias ? 1U : 0U),
            "transform-level antialias accounting");

    double spectralEnergy = 0.0;
    double spatialEnergy = 0.0;
    double spectralEnstrophy = 0.0;
    double spatialEnstrophy = 0.0;
    require(static_cast<bool>(kernel->totalEnergy(input, spectralEnergy)) &&
                static_cast<bool>(kernel->totalEnergySpatiallyIntegrated(
                    input, spatialEnergy)) &&
                static_cast<bool>(kernel->totalEnstrophy(
                    input, spectralEnstrophy)) &&
                static_cast<bool>(kernel->totalEnstrophySpatiallyIntegrated(
                    input, spatialEnstrophy)),
            "energy and enstrophy evaluation");
    require(relativeError(spatialEnergy, spectralEnergy) < tolerance &&
                relativeError(spatialEnstrophy, spectralEnstrophy) < tolerance,
            "spectral/spatial invariant parity");

    std::vector<WVComplex64> evolved(A0.size());
    WVComplexView evolvedView{evolved.data(),
                              kernel->descriptor().spectralShape()};
    status = kernel->evolveA0(input, 817.0, evolvedView);
    require(static_cast<bool>(status) && relativeError(evolved, A0) == 0.0,
            "zero-frequency linear evolution");
}

struct Lifetime {
    std::size_t active = 0;
    std::size_t created = 0;
    std::size_t destroyed = 0;
};

class CountingPlan final : public WVFFTPlan {
public:
    explicit CountingPlan(Lifetime& lifetime) : lifetime_(lifetime) {
        ++lifetime_.active;
        ++lifetime_.created;
    }
    ~CountingPlan() override {
        --lifetime_.active;
        ++lifetime_.destroyed;
    }
    WVKernelStatus execute(const void*, void*) override {
        return WVKernelStatus::ok();
    }
    std::size_t persistentBytes() const noexcept override {
        return sizeof(*this);
    }
private:
    Lifetime& lifetime_;
};

class FailingEngine final : public WVFFTEngine {
public:
    explicit FailingEngine(Lifetime& lifetime) : lifetime_(lifetime) {}
    std::string identifier() const override { return "failing"; }
    std::size_t persistentBytes() const noexcept override {
        return sizeof(*this);
    }
    WVKernelStatus createPlan(const WVFFTPlanSpecification&,
                              std::unique_ptr<WVFFTPlan>& plan) override {
        if (created_++ == 2)
            return {WVKernelStatusCode::fftPlanFailure,
                    "injected plan failure"};
        plan = std::make_unique<CountingPlan>(lifetime_);
        return WVKernelStatus::ok();
    }
private:
    Lifetime& lifetime_;
    std::size_t created_ = 0;
};

void testFailureCleanup() {
    Lifetime lifetime;
    std::unique_ptr<WVTransformBarotropicQGKernel> kernel;
    const auto status = WVTransformBarotropicQGKernel::create(
        configuration(8, 6, 1, true),
        std::make_unique<FailingEngine>(lifetime), kernel);
    require(status.code == WVKernelStatusCode::fftPlanFailure && !kernel &&
                lifetime.created == 2 && lifetime.destroyed == 2 &&
                lifetime.active == 0,
            "partial plan-construction cleanup");
}

} // namespace

int main() {
    for (const auto Nx : {8U, 9U})
        for (const auto Ny : {6U, 7U})
            for (const auto j : {0U, 1U})
                for (const auto antialias : {false, true}) {
                    testDescriptor(Nx, Ny, j, antialias);
                    testNumerics(Nx, Ny, j, antialias);
                }
    testFailureCleanup();
    std::cout << "Barotropic QG kernel contract tests passed\n";
    return 0;
}
