#include "WaveVortexKernel/WVFFTEngine.hpp"
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <cassert>
#include <cmath>
#include <iostream>
#include <memory>
#include <vector>

using namespace wavevortex;

namespace {

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
    assert(status);
    assert(even.spectralShape().rows == 9);
    assert(even.Nkl() > 0);
    assert(even.fourierModes().front().kMode == 0 && even.fourierModes().front().lMode == 0);
    assert(even.verticalModes().z.front() == -1300.0);
    assert(even.verticalModes().z.back() == 0.0);
    assert(even.verticalModes().h0.front() == 1300.0);
    assert(std::isfinite(even.verticalModes().coriolisFrequency));

    WVTransformConstantStratificationDescriptor odd;
    status = WVTransformConstantStratificationDescriptor::create(configuration(15, 13, true), odd);
    assert(status && odd.Nkl() > 0);

    auto invalid = configuration(16, 12, false);
    invalid.Nj = invalid.Nz;
    status = WVTransformConstantStratificationDescriptor::create(invalid, odd);
    assert(status.code == WVKernelStatusCode::invalidConfiguration);

    invalid = configuration(16, 12, false);
    invalid.Nx = static_cast<std::size_t>(-1);
    status = WVTransformConstantStratificationDescriptor::create(invalid, odd);
    assert(status.code == WVKernelStatusCode::sizeOverflow);
}

void testViewsAndAliasing() {
    WVTransformConstantStratificationDescriptor descriptor;
    auto status = WVTransformConstantStratificationDescriptor::create(configuration(8, 8, false), descriptor);
    assert(status);
    const auto shape = descriptor.spectralShape();
    const auto count = shape.elementCount();
    std::vector<WVComplex64> Ap(count), Am(count), A0(count), Fp(count), Fm(count), F0(count);
    std::vector<double> mask(count, 1.0);
    WVState state{0.5, 0.0, {{Ap.data(), shape}, {Am.data(), shape}, {A0.data(), shape}}};
    WVGradientMasks masks{{mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}, {mask.data(), shape}};
    WVFlux flux{{Fp.data(), shape}, {Fm.data(), shape}, {F0.data(), shape}};
    assert(validateStateAndFlux(descriptor, state, masks, flux));
    flux.Fp.data = Ap.data();
    status = validateStateAndFlux(descriptor, state, masks, flux);
    assert(status.code == WVKernelStatusCode::overlappingArrays);
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
    assert(status && plan && engine.last.batchCount == 9);
    double input = 0.0;
    double output = 0.0;
    assert(plan->execute(&input, &output));
}

} // namespace

int main() {
    testDescriptor();
    testViewsAndAliasing();
    testEngineContract();
    std::cout << "WaveVortex kernel contract tests passed\n";
    return 0;
}
