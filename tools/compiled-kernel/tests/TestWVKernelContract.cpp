#include "WaveVortexKernel/WVFFTEngine.hpp"
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <cmath>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <vector>

using namespace wavevortex;

namespace {

void require(bool condition, const char* message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

WVTransformConstantStratificationConfiguration configuration(std::size_t Nx, std::size_t Ny, bool hydrostatic) {
    WVTransformConstantStratificationConfiguration value;
    value.Nx = Nx;
    value.Ny = Ny;
    value.Nz = 9;
    value.Nj = 5;
    value.Lx = 15000.0;
    value.Ly = 12000.0;
    value.Lz = 1300.0;
    value.N0 = 5.2e-3;
    value.rho0 = 1025.0;
    value.g = 9.81;
    value.planetaryRadius = 6.371e6;
    value.rotationRate = 7.2921e-5;
    value.latitude = 33.0;
    value.isHydrostatic = hydrostatic;
    return value;
}

class FakePlan final : public WVFFTPlan {
public:
    WVKernelStatus execute(const void* input, void* output) override {
        return input != nullptr && output != nullptr ? WVKernelStatus::ok() : WVKernelStatus{WVKernelStatusCode::invalidPointer, "fake pointer"};
    }
    std::size_t persistentBytes() const noexcept override { return 64; }
};

class FakeEngine final : public WVFFTEngine {
public:
    std::string identifier() const override { return "fake"; }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) override {
        last = specification;
        plan = std::make_unique<FakePlan>();
        return WVKernelStatus::ok();
    }
    WVFFTPlanSpecification last;
};

void testDescriptor() {
    WVTransformConstantStratificationDescriptor even;
    auto status = WVTransformConstantStratificationDescriptor::create(configuration(16, 12, false), even);
    require(static_cast<bool>(status), "even descriptor construction failed");
    require(even.spectralShape().rows == 9, "unexpected spectral rows");
    require(even.Nkl() > 0, "empty Fourier modes");
    require(even.fourierModes().front().kMode == 0 && even.fourierModes().front().lMode == 0, "zero mode must be first");
    require(even.verticalModes().z.front() == -1300.0, "unexpected bottom coordinate");
    require(even.verticalModes().z.back() == 0.0, "unexpected surface coordinate");
    require(even.verticalModes().h0.front() == 1300.0, "unexpected barotropic equivalent depth");
    require(std::isfinite(even.verticalModes().coriolisFrequency), "non-finite Coriolis frequency");

    WVTransformConstantStratificationDescriptor odd;
    status = WVTransformConstantStratificationDescriptor::create(configuration(15, 13, true), odd);
    require(static_cast<bool>(status) && odd.Nkl() > 0, "odd descriptor construction failed");

    auto invalid = configuration(16, 12, false);
    invalid.Nj = invalid.Nz;
    status = WVTransformConstantStratificationDescriptor::create(invalid, odd);
    require(status.code == WVKernelStatusCode::invalidConfiguration, "invalid Nj was accepted");

    invalid = configuration(16, 12, false);
    invalid.Nx = static_cast<std::size_t>(-1);
    status = WVTransformConstantStratificationDescriptor::create(invalid, odd);
    require(status.code == WVKernelStatusCode::sizeOverflow, "overflowing horizontal shape was accepted");
}

void testViewsAndAliasing() {
    WVTransformConstantStratificationDescriptor descriptor;
    auto status = WVTransformConstantStratificationDescriptor::create(configuration(8, 8, false), descriptor);
    require(static_cast<bool>(status), "descriptor construction failed");
    const auto shape = descriptor.spectralShape();
    const auto count = shape.elementCount();
    std::vector<WVComplex64> Ap(count), Am(count), A0(count), Fp(count), Fm(count), F0(count);
    std::vector<double> mask(count, 1.0);
    WVState state{0.5, 0.0, {{Ap.data(), shape}, {Am.data(), shape}, {A0.data(), shape}}};
    WVGradientMasks masks{{mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}};
    WVFlux flux{{Fp.data(), shape}, {Fm.data(), shape}, {F0.data(), shape}};
    require(static_cast<bool>(validateStateAndFlux(descriptor, state, masks, flux)), "valid views were rejected");
    flux.Fp.data = Ap.data();
    status = validateStateAndFlux(descriptor, state, masks, flux);
    require(status.code == WVKernelStatusCode::overlappingArrays, "overlapping state and flux were accepted");
}

void testEngineContract() {
    FakeEngine engine;
    WVFFTPlanSpecification specification;
    specification.kind = WVFFTPlanKind::horizontalRealToComplex2D;
    specification.dimensions = {16, 12};
    specification.batchCount = 9;
    specification.inputStrides = {1, 16, 16 * 12};
    specification.outputStrides = {1, 9, 9 * 9};
    std::unique_ptr<WVFFTPlan> plan;
    const auto status = engine.createPlan(specification, plan);
    require(static_cast<bool>(status) && plan && engine.last.batchCount == 9, "fake plan contract failed");
    double input = 0.0;
    double output = 0.0;
    require(static_cast<bool>(plan->execute(&input, &output)), "fake plan execution failed");
}

} // namespace

int main() {
    testDescriptor();
    testViewsAndAliasing();
    testEngineContract();
    std::cout << "WaveVortex kernel contract tests passed\n";
    return 0;
}
