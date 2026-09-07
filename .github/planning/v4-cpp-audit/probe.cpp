// Read-only audit probe for the v4.3 native kernel. This is not a production test.
// Counts C++ new/new[] calls, not malloc, FFTW-internal allocations, or RSS.
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"
#include "WVNativeFFTWEngine.hpp"
#include <atomic>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <new>
#include <stdexcept>
#include <vector>

namespace {
std::atomic<bool> counting{false};
std::atomic<std::size_t> calls{0}, bytes{0};
void record(std::size_t n) {
    if (counting.load()) { ++calls; bytes += n; }
}
}
void* operator new(std::size_t n) {
    void* p = std::malloc(n == 0 ? 1 : n);
    if (!p) throw std::bad_alloc();
    record(n); return p;
}
void* operator new[](std::size_t n) { return ::operator new(n); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t) noexcept { std::free(p); }
void* operator new(std::size_t n, std::align_val_t a) {
    void* p = nullptr;
    if (posix_memalign(&p, static_cast<std::size_t>(a), n == 0 ? 1 : n))
        throw std::bad_alloc();
    record(n); return p;
}
void* operator new[](std::size_t n, std::align_val_t a) { return ::operator new(n,a); }
void operator delete(void* p, std::align_val_t) noexcept { std::free(p); }
void operator delete[](void* p, std::align_val_t) noexcept { std::free(p); }
void operator delete(void* p, std::size_t, std::align_val_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t, std::align_val_t) noexcept { std::free(p); }

using namespace wavevortex;
void require(WVKernelStatus s) { if (!s) throw std::runtime_error(s.message); }

void fluxProbe(bool hydrostatic) {
    WVTransformConstantStratificationConfiguration c;
    c.Nx=16; c.Ny=12; c.Nz=9; c.Nj=5;
    c.Lx=15000; c.Ly=12000; c.Lz=1300; c.N0=5.2e-3;
    c.rho0=1025; c.g=9.81; c.planetaryRadius=6.371e6;
    c.rotationRate=7.2921e-5; c.latitude=33; c.isHydrostatic=hydrostatic;
    std::unique_ptr<WVFFTEngine> engine;
    require(WVFFTWEngine::create(1,engine));
    std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
    require(WVTransformConstantStratificationKernel::create(c,std::move(engine),kernel));
    const auto shape=kernel->descriptor().spectralShape();
    const auto n=shape.elementCount();
    std::vector<WVComplex64> ap(n),am(n),a0(n),fp(n),fm(n),f0(n);
    for (std::size_t i=0;i<n;++i) {
        ap[i]={1e-4*std::sin(i+1),1e-4*std::cos(i+2)};
        am[i]={ap[i].real,-ap[i].imag};
        a0[i]={1e-4*std::sin(i+3),0};
    }
    const auto originalAp=ap, originalAm=am, originalA0=a0;
    WVState state{0.5,0,{{ap.data(),shape},{am.data(),shape},{a0.data(),shape}}};
    WVFlux flux{{fp.data(),shape},{fm.data(),shape},{f0.data(),shape}};
    require(kernel->nonlinearFlux(state,flux));
    calls=0; bytes=0; counting=true;
    auto status=kernel->nonlinearFlux(state,flux);
    counting=false;
    const auto measuredCalls=calls.load(), measuredBytes=bytes.load();
    require(status);
    const bool preserved=std::memcmp(ap.data(),originalAp.data(),n*sizeof(WVComplex64))==0
        && std::memcmp(am.data(),originalAm.data(),n*sizeof(WVComplex64))==0
        && std::memcmp(a0.data(),originalA0.data(),n*sizeof(WVComplex64))==0;
    std::cout << "flux hydrostatic=" << hydrostatic << " Nkl=" << shape.columns
              << " warmed_new_calls=" << measuredCalls << " requested_new_bytes=" << measuredBytes
              << " caller_inputs_preserved=" << preserved << '\n';
}

void preservationProbe() {
    constexpr std::size_t nx=8,ny=6,half=nx/2+1;
    std::unique_ptr<WVFFTEngine> engine;
    require(WVFFTWEngine::create(1,engine));
    WVFFTPlanSpecification forward;
    forward.kind=WVFFTPlanKind::horizontalRealToComplex2D;
    forward.transformDimensions={{ny,nx,half},{nx,1,1}};
    forward.inputBytes=nx*ny*sizeof(double);
    forward.outputBytes=half*ny*sizeof(WVComplex64);
    auto inverse=forward;
    inverse.kind=WVFFTPlanKind::horizontalComplexToReal2D;
    inverse.transformDimensions={{ny,half,nx},{nx,1,1}};
    inverse.inputBytes=forward.outputBytes; inverse.outputBytes=forward.inputBytes;
    inverse.destroysInput=false;
    std::unique_ptr<WVFFTPlan> f,b;
    require(engine->createPlan(forward,f));
    require(engine->createPlan(inverse,b));
    std::vector<double> input(nx*ny),output(nx*ny);
    std::vector<WVComplex64> spectrum(half*ny);
    for (std::size_t i=0;i<input.size();++i) input[i]=std::sin(0.17*(i+1));
    require(f->execute(input.data(),spectrum.data()));
    const auto original=spectrum;
    require(b->execute(spectrum.data(),output.data()));
    const bool preserved=std::memcmp(original.data(),spectrum.data(),inverse.inputBytes)==0;
    double error=0;
    for (std::size_t i=0;i<input.size();++i)
        error=std::max(error,std::abs(output[i]/(nx*ny)-input[i]));
    std::cout << "provider inverse_requested_destroysInput=false input_preserved=" << preserved
              << " roundtrip_max_error=" << error << '\n';
}

int main() {
    try {
        std::cout << "provider=" << WVFFTWEngine::linkedLibraries().baseLibrary << '\n';
        fluxProbe(true); fluxProbe(false); preservationProbe();
        const auto lifetime=WVFFTWEngine::lifetimeMetrics();
        std::cout << "active_plans=" << lifetime.activePlans
                  << " outstanding_planning_bytes=" << lifetime.outstandingPlanningBytes << '\n';
        return 0;
    } catch (const std::exception& e) {
        counting=false;
        std::cerr << e.what() << '\n'; return 1;
    }
}
