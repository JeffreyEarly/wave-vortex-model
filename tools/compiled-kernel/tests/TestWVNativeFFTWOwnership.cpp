#include "WVNativeFFTWEngine.hpp"
#include <WVReferenceFFTEngine.hpp>
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"
#include "WVAllocationProbe.hpp"
#include <fftw3.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <thread>
#include <vector>

namespace {
std::atomic<int> failBuffer{-1}, failPlan{-1}, buffers{0}, rawPlans{0}, insidePlanner{0};
std::atomic<bool> failWrapper{false}, plannerOverlap{false};
bool fail(std::atomic<int>& countdown) {
    return countdown >= 0 && countdown.fetch_sub(1) == 0;
}
struct PlannerCall {
    PlannerCall() { if (insidePlanner.fetch_add(1) != 0) plannerOverlap = true; }
    ~PlannerCall() { --insidePlanner; }
};
fftw_plan retain(fftw_plan p) {
    if (p) {
        ++rawPlans;
        if (failWrapper.exchange(false)) allocationProbe::failAfter = 0;
    }
    return p;
}
}
extern "C" void* wv_test_malloc(std::size_t n) {
    if (fail(failBuffer)) return nullptr;
    auto p = fftw_malloc(n);
    if (p) ++buffers;
    return p;
}
extern "C" void wv_test_free(void* p) { if (p) --buffers; fftw_free(p); }
extern "C" void wv_test_destroy(fftw_plan p) {
    PlannerCall call;
    fftw_destroy_plan(p);
    --rawPlans;
}
extern "C" fftw_plan wv_test_r2c(int rank, const fftw_iodim64* dims, int howmany, const fftw_iodim64* batch, double* in, fftw_complex* out, unsigned flags) {
    PlannerCall call;
    return fail(failPlan) ? nullptr : retain(fftw_plan_guru64_dft_r2c(rank,dims,howmany,batch,in,out,flags));
}
extern "C" fftw_plan wv_test_c2r(int rank, const fftw_iodim64* dims, int howmany, const fftw_iodim64* batch, fftw_complex* in, double* out, unsigned flags) {
    PlannerCall call;
    return fail(failPlan) ? nullptr : retain(fftw_plan_guru64_dft_c2r(rank,dims,howmany,batch,in,out,flags));
}
extern "C" fftw_plan wv_test_c2c(int rank, const fftw_iodim64* dims, int howmany, const fftw_iodim64* batch, fftw_complex* in, fftw_complex* out, int sign, unsigned flags) {
    PlannerCall call;
    return fail(failPlan) ? nullptr : retain(fftw_plan_guru64_dft(rank,dims,howmany,batch,in,out,sign,flags));
}
extern "C" fftw_plan wv_test_r2r(int rank, const fftw_iodim64* dims, int howmany, const fftw_iodim64* batch, double* in, double* out, const fftw_r2r_kind* kinds, unsigned flags) {
    PlannerCall call;
    return fail(failPlan) ? nullptr : retain(fftw_plan_guru64_r2r(rank,dims,howmany,batch,in,out,kinds,flags));
}

using namespace wavevortex;
namespace {
void require(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
void require(WVKernelStatus status) { if (!status) throw std::runtime_error(status.message); }
void balanced() {
    const auto m = WVFFTWEngine::lifetimeMetrics();
    require(m.activePlans == 0 && m.totalPlansCreated == m.totalPlansDestroyed &&
            m.outstandingPlanningBytes == 0 && buffers == 0 && rawPlans == 0, "unbalanced provider ownership");
}
std::unique_ptr<WVFFTEngine> engine() {
    std::unique_ptr<WVFFTEngine> result;
    require(WVFFTWEngine::create(1,result));
    return result;
}
WVFFTPlanSpecification forward() {
    WVFFTPlanSpecification s;
    s.transformDimensions = {{6,8,5},{8,1,1}};
    s.inputBytes = 48*sizeof(double); s.outputBytes = 30*sizeof(WVComplex64);
    return s;
}
WVFFTPlanSpecification vertical(WVFFTPlanKind kind, bool inPlace) {
    WVFFTPlanSpecification s;
    s.kind = kind; s.transformDimensions = {{7,2,2}};
    s.batchDimensions = {{2,1,1}};
    s.inputBytes = s.outputBytes = 14*sizeof(double); s.inPlace = inPlace;
    return s;
}
void preservationAndAliasing() {
    auto e = engine();
    auto f = forward(), inverse = f;
    inverse.kind = WVFFTPlanKind::horizontalComplexToReal2D;
    inverse.transformDimensions = {{6,5,8},{8,1,1}};
    std::swap(inverse.inputBytes,inverse.outputBytes);
    std::unique_ptr<WVFFTPlan> p, q;
    require(e->createPlan(f,p));
    require(e->createPlan(inverse,q).code == WVKernelStatusCode::unsupportedOperation && !q, "preserving c2r was accepted");
    inverse.destroysInput = true;
    require(e->createPlan(inverse,q));
    std::vector<double> in(48), out(48);
    std::vector<WVComplex64> spectrum(30);
    for (std::size_t i = 0; i < in.size(); ++i) in[i] = std::sin(0.17*i);
    const auto saved = in;
    require(p->execute(in.data(),spectrum.data()));
    require(in == saved, "r2c modified immutable input");
    require(p->execute(in.data(),in.data()).code == WVKernelStatusCode::overlappingArrays, "r2c alias accepted");
    require(p->execute(in.data(),in.data()+1).code == WVKernelStatusCode::overlappingArrays, "partial overlap accepted");
    require(p->execute(in.data()+1,in.data()).code == WVKernelStatusCode::overlappingArrays, "reverse overlap accepted");
    require(p->execute(nullptr,out.data()).code == WVKernelStatusCode::invalidPointer, "null input accepted");
    require(q->execute(spectrum.data(),out.data()));
    for (std::size_t i = 0; i < in.size(); ++i) require(std::abs(out[i]/48-in[i]) < 1e-12, "horizontal roundtrip");
    require(q->execute(spectrum.data(),spectrum.data()).code == WVKernelStatusCode::overlappingArrays, "c2r alias accepted");
    f.inPlace = true;
    auto* retained = p.get();
    require(e->createPlan(f,p).code == WVKernelStatusCode::unsupportedOperation && p.get() == retained, "failed setup replaced existing plan");
    f = forward(); f.inputBytes = 1;
    require(e->createPlan(f,p).code == WVKernelStatusCode::invalidShape, "undersized planning buffer accepted");
    f = forward(); f.transformDimensions[0].inputStride = PTRDIFF_MAX;
    require(e->createPlan(f,p).code == WVKernelStatusCode::sizeOverflow, "span overflow accepted");
    f = forward(); f.transformDimensions[0].inputStride = -1;
    require(e->createPlan(f,p).code == WVKernelStatusCode::invalidConfiguration, "negative stride accepted");
    for (auto kind : {WVFFTPlanKind::verticalDCTI,WVFFTPlanKind::verticalDSTI}) {
        auto s = vertical(kind,false);
        require(e->createPlan(s,p));
        require(e->createPlan(vertical(kind,true),q));
        std::vector<double> values(14), result(14), shared(14);
        for (std::size_t i = 0; i < values.size(); ++i) values[i] = std::cos(0.19*i);
        const auto original = values;
        require(p->execute(values.data(),result.data()));
        require(values == original, "r2r modified immutable input");
        shared = values;
        require(q->execute(shared.data(),shared.data()));
        require(shared == result, "in-place/out-of-place r2r mismatch");
        require(q->execute(values.data(),result.data()).code == WVKernelStatusCode::invalidPointer, "in-place disjoint pointers accepted");
        require(p->execute(values.data(),values.data()).code == WVKernelStatusCode::overlappingArrays, "r2r alias accepted");
        require(q->execute(shared.data(),shared.data()));
        const double scale = kind == WVFFTPlanKind::verticalDCTI ? 12 : 16;
        for (std::size_t i = 0; i < values.size(); ++i) require(std::abs(shared[i]/scale-values[i]) < 1e-12, "vertical roundtrip");
    }
}
void failurePaths() {
    auto e = engine();
    for (const auto& s : {forward(),vertical(WVFFTPlanKind::verticalDCTI,false),vertical(WVFFTPlanKind::verticalDSTI,true)}) {
        for (int i = 0; i < (s.inPlace ? 1 : 2); ++i) {
            failBuffer = i;
            std::unique_ptr<WVFFTPlan> p;
            require(e->createPlan(s,p).code == WVKernelStatusCode::allocationFailure && !p, "surrogate allocation failure");
            balanced(); failBuffer = -1;
        }
        failPlan = 0;
        std::unique_ptr<WVFFTPlan> p;
        require(e->createPlan(s,p).code == WVKernelStatusCode::fftPlanFailure && !p, "raw plan failure");
        balanced(); failPlan = -1;
        failWrapper = true;
        require(e->createPlan(s,p).code == WVKernelStatusCode::allocationFailure && !p, "wrapper allocation failure");
        balanced();
        int failures = 0;
        for (long i = 0; i < 16; ++i) {
            allocationProbe::failAfter = i;
            const auto status = e->createPlan(s,p);
            allocationProbe::failAfter = -1;
            if (status) { p.reset(); balanced(); break; }
            require(status.code == WVKernelStatusCode::allocationFailure && !p, "unexpected allocation failure result");
            ++failures; balanced();
        }
        require(failures >= 3, "allocation sweep missed setup stages");
    }
    std::vector<std::thread> workers;
    for (int i = 0; i < 4; ++i) workers.emplace_back([] {
        auto provider = engine();
        const auto s = forward();
        for (int j = 0; j < 20; ++j) {
            std::unique_ptr<WVFFTPlan> p;
            require(provider->createPlan(s,p));
        }
    });
    for (auto& worker : workers) worker.join();
    require(!plannerOverlap, "FFTW planning/destruction overlapped");
    balanced();
}
WVTransformConstantStratificationConfiguration configuration(bool hydro) {
    WVTransformConstantStratificationConfiguration c;
    c.Nx=8; c.Ny=6; c.Nz=7; c.Nj=4;
    c.Lx=15000; c.Ly=12000; c.Lz=1300; c.N0=5.2e-3;
    c.rho0=1025; c.g=9.81; c.planetaryRadius=6.371e6;
    c.rotationRate=7.2921e-5; c.latitude=33; c.isHydrostatic=hydro;
    return c;
}
void parity(const std::vector<WVComplex64>& a, const std::vector<WVComplex64>& b, double relativeTolerance = 2e-12) {
    double error = 0, scale = 0;
    for (std::size_t i = 0; i < a.size(); ++i) {
        error = std::max(error,std::hypot(a[i].real-b[i].real,a[i].imag-b[i].imag));
        scale = std::max(scale,std::hypot(b[i].real,b[i].imag));
    }
    if (error > relativeTolerance*scale + 1e-25) std::cerr << "coefficient error=" << error << " scale=" << scale << " relative=" << error/scale << "\n";
    require(error <= relativeTolerance*scale + 1e-25, "native/reference coefficient mismatch");
}
void parity(const std::vector<double>& a, const std::vector<double>& b) {
    double error = 0, scale = 0;
    for (std::size_t i = 0; i < a.size(); ++i) { error = std::max(error,std::abs(a[i]-b[i])); scale = std::max(scale,std::abs(b[i])); }
    require(error <= 2e-12*scale + 1e-25, "native/reference real field mismatch");
}
std::size_t configuredScalarPlanCount() {
    return WVConstantKernelExecutionOptions{}.schedule == WVConstantNonlinearFluxSchedule::compactCandidate ? 21 : 18;
}
void kernelExecution(bool hydro, bool odd) {
    auto c = configuration(hydro);
    if (odd) { c.Nx = 9; c.Ny = 7; c.Nz = 8; c.shouldAntialias = false; }
    std::unique_ptr<WVTransformConstantStratificationKernel> k, ref;
    require(WVTransformConstantStratificationKernel::create(c,engine(),k));
    require(WVTransformConstantStratificationKernel::create(c,std::make_unique<WVReferenceFFTEngine>(),ref));
    require(k->prepareScalarAdvection()); require(ref->prepareScalarAdvection());
    require(k->metrics().planCount == configuredScalarPlanCount(), "scalar plan not prepared");
    const auto shape = k->descriptor().spectralShape();
    const auto spatial = k->descriptor().spatialShape();
    const auto n = shape.elementCount(), r = spatial.elementCount();
    std::vector<WVComplex64> ap(n),am(n),a0(n),fp(n),fm(n),f0(n),rp(n),rm(n),r0(n);
    for (std::size_t i = 0; i < n; ++i) {
        ap[i] = {1e-4*std::sin(i+1),1e-4*std::cos(i+2)};
        am[i] = {ap[i].real,-ap[i].imag}; a0[i] = {1e-4*std::sin(i+3),0};
    }
    const auto originalAp=ap, originalAm=am, originalA0=a0;
    WVState state{0.5,0,{{ap.data(),shape},{am.data(),shape},{a0.data(),shape}}};
    WVFlux flux{{fp.data(),shape},{fm.data(),shape},{f0.data(),shape}};
    WVFlux expected{{rp.data(),shape},{rm.data(),shape},{r0.data(),shape}};
    std::vector<double> uvw(3*r), refUVW(3*r), fields(4*r), refFields(4*r), scalar(r), rhs(r), refRHS(r);
    WVRealFieldBundleView velocity{uvw.data(),{c.Nx,c.Ny,c.Nz,3}};
    WVRealFieldBundleView referenceVelocity{refUVW.data(),velocity.shape};
    WVRealFieldBundleConstView velocityInput{uvw.data(),velocity.shape}, referenceVelocityInput{refUVW.data(),velocity.shape};
    WVRealFieldBundleView fieldView{fields.data(),{c.Nx,c.Ny,c.Nz,4}}, referenceFields{refFields.data(),fieldView.shape};
    for (std::size_t i = 0; i < r; ++i) scalar[i] = std::cos(0.27*i);
    const auto originalScalar = scalar;
    WVRealVolumeConstView scalarInput{scalar.data(),spatial};
    WVRealVolumeView tendency{rhs.data(),spatial}, referenceTendency{refRHS.data(),spatial};
    require(k->transformWaveVortexToUVWEta(state,fieldView));
    require(ref->transformWaveVortexToUVWEta(state,referenceFields)); parity(fields,refFields);
    require(ref->nonlinearFluxWithAdvectionFields(state,expected,referenceVelocity));
    require(k->nonlinearFluxWithAdvectionFields(state,flux,velocity));
    parity(fp,rp); parity(fm,rm); parity(f0,r0); parity(uvw,refUVW);
    const auto originalUVW = uvw;
    require(k->nonlinearFluxUsingAdvectionFields(state,flux,velocityInput));
    parity(fp,rp); parity(fm,rm); parity(f0,r0);
    for (bool antialias : {false,true}) {
        require(k->advectFGridScalar(scalarInput,velocityInput,antialias,tendency));
        require(ref->advectFGridScalar(scalarInput,referenceVelocityInput,antialias,referenceTendency));
        parity(rhs,refRHS);
    }
    WVMutableCoefficients projected{{fp.data(),shape},{fm.data(),shape},{f0.data(),shape}};
    WVRealFieldBundleConstView physicalInput{fields.data(),fieldView.shape};
    std::vector<double> hydroFields(3*r);
    std::copy_n(fields.data(),2*r,hydroFields.data());
    std::copy_n(fields.data()+3*r,r,hydroFields.data()+2*r);
    WVRealFieldBundleConstView hydroInput{hydroFields.data(),velocity.shape};
    const auto originalHydroFields = hydroFields, originalPhysicalFields = fields;
    WVMutableCoefficients referenceProjection{{rp.data(),shape},{rm.data(),shape},{r0.data(),shape}};
    if (hydro) {
        require(k->transformUVEtaToWaveVortex(hydroInput,state.t,state.t0,projected));
        require(ref->transformUVEtaToWaveVortex(hydroInput,state.t,state.t0,referenceProjection));
    } else {
        require(k->transformUVWEtaToWaveVortex(physicalInput,state.t,state.t0,projected));
        require(ref->transformUVWEtaToWaveVortex(physicalInput,state.t,state.t0,referenceProjection));
    }
    require(hydroFields == originalHydroFields && fields == originalPhysicalFields, "forward transform modified input");
    // These deliberately large balanced coefficients make recovering the tiny
    // wave component ill-conditioned for the direct-summation reference FFT.
    // The unchanged v4 baseline also differs by 7.23e-12 relatively here.
    parity(fp,rp,1e-10); parity(fm,rm,1e-10); parity(f0,r0,1e-10);
    require(k->transformToSpatialDomainWithFAllDerivatives(state.coefficients.Ap,state.coefficients.A0,fieldView));
    require(ref->transformToSpatialDomainWithFAllDerivatives(state.coefficients.Ap,state.coefficients.A0,referenceFields));
    parity(fields,refFields);
    require(k->transformToSpatialDomainWithGAllDerivatives(state.coefficients.Ap,state.coefficients.A0,fieldView));
    require(ref->transformToSpatialDomainWithGAllDerivatives(state.coefficients.Ap,state.coefficients.A0,referenceFields));
    parity(fields,refFields);
    WVRealFieldBundleView overlappingDerivatives{reinterpret_cast<double*>(ap.data()),fieldView.shape};
    require(k->transformToSpatialDomainWithFAllDerivatives(state.coefficients.Ap,state.coefficients.A0,overlappingDerivatives).code == WVKernelStatusCode::overlappingArrays, "F derivative overlap accepted");
    const WVComplexConstView nullCoefficient{nullptr,shape};
    require(k->transformToSpatialDomainWithGAllDerivatives(nullCoefficient,state.coefficients.A0,fieldView).code == WVKernelStatusCode::invalidPointer, "G derivative null input accepted");
    const auto plansBefore = WVFFTWEngine::lifetimeMetrics();
    const auto bytesBefore = k->persistentBytes();
    const auto reconstructions = k->metrics().advectionVelocityReconstructionCount;
    allocationProbe::calls = 0; allocationProbe::counting = true;
    for (int i = 0; i < 10; ++i) {
        require(k->nonlinearFlux(state,flux));
        require(k->nonlinearFluxWithAdvectionFields(state,flux,velocity));
        require(k->nonlinearFluxUsingAdvectionFields(state,flux,velocityInput));
        require(k->transformWaveVortexToUVWEta(state,fieldView));
        if (hydro) require(k->transformUVEtaToWaveVortex(hydroInput,state.t,state.t0,projected));
        else require(k->transformUVWEtaToWaveVortex(physicalInput,state.t,state.t0,projected));
        require(k->transformToSpatialDomainWithFAllDerivatives(state.coefficients.Ap,state.coefficients.A0,fieldView));
        require(k->transformToSpatialDomainWithGAllDerivatives(state.coefficients.Ap,state.coefficients.A0,fieldView));
        require(k->advectFGridScalar(scalarInput,velocityInput,false,tendency));
        require(k->advectFGridScalar(scalarInput,velocityInput,true,tendency));
        require(k->prepareScalarAdvection());
    }
    allocationProbe::counting = false;
    require(allocationProbe::calls == 0, "prepared kernel execution allocated");
    require(k->metrics().advectionVelocityReconstructionCount == reconstructions+20, "velocity consuming RHS reconstructed velocity");
    require(WVFFTWEngine::lifetimeMetrics().totalPlansCreated == plansBefore.totalPlansCreated && k->persistentBytes() == bytesBefore, "prepared kernel execution created plans/storage");
    require(scalar == originalScalar && uvw == originalUVW, "scalar/velocity caller data changed");
    require(std::memcmp(ap.data(),originalAp.data(),n*sizeof(WVComplex64)) == 0 &&
            std::memcmp(am.data(),originalAm.data(),n*sizeof(WVComplex64)) == 0 &&
            std::memcmp(a0.data(),originalA0.data(),n*sizeof(WVComplex64)) == 0, "caller coefficients changed");
    std::cout << "hydrostatic=" << hydro << " odd=" << odd << " prepared application allocations=0 logical plans=" << k->metrics().planCount << " velocity reuse verified\n";
}
void kernelSetupFailures() {
    // Measure the selected schedule, including all wrapped complex column
    // plans. Logical operation slots need not equal actual FFTW handles.
    std::unique_ptr<WVTransformConstantStratificationKernel> measured;
    auto measuredProvider = engine(); // Provider construction is outside injection.
    const auto lifetimeBefore = WVFFTWEngine::lifetimeMetrics();
    allocationProbe::calls = 0;
    allocationProbe::counting = true;
    const auto measuredStatus = WVTransformConstantStratificationKernel::create(configuration(true),std::move(measuredProvider),measured);
    allocationProbe::counting = false;
    const auto setupAllocations = allocationProbe::calls.load();
    require(measuredStatus);
    const auto actualPlanCount = WVFFTWEngine::lifetimeMetrics().totalPlansCreated-lifetimeBefore.totalPlansCreated;
    require(actualPlanCount > 0 && actualPlanCount <= static_cast<std::size_t>(std::numeric_limits<int>::max()), "raw plan sweep bound");
    require(static_cast<std::size_t>(rawPlans.load()) == actualPlanCount, "raw FFTW acquisition bypassed test instrumentation");
    require(setupAllocations > 0 && setupAllocations < static_cast<std::size_t>(std::numeric_limits<long>::max()), "allocation sweep bound");
    measured.reset(); balanced();
    for (int i = 0; i < static_cast<int>(actualPlanCount); ++i) {
        std::unique_ptr<WVTransformConstantStratificationKernel> k;
        failPlan = i;
        require(WVTransformConstantStratificationKernel::create(configuration(true),engine(),k).code == WVKernelStatusCode::fftPlanFailure && !k, "partial kernel planning failure");
        failPlan = -1; balanced();
    }
    // Sweep all application allocations through descriptor, scratch, plan and
    // executor setup, including std::thread's launch allocation.
    bool completed = false;
    for (long i = 0; i <= static_cast<long>(setupAllocations); ++i) {
        auto provider = engine();
        std::unique_ptr<WVTransformConstantStratificationKernel> candidate;
        allocationProbe::failAfter = i;
        const auto status = WVTransformConstantStratificationKernel::create(configuration(true),std::move(provider),candidate);
        allocationProbe::failAfter = -1;
        if (status) {
            require(i == static_cast<long>(setupAllocations), "allocation sweep completed before measured setup boundary");
            candidate.reset(); balanced(); completed = true;
            continue;
        }
        require(status.code == WVKernelStatusCode::allocationFailure && !candidate, "kernel allocation failure status");
        balanced();
    }
    require(completed, "kernel allocation sweep did not reach successful startup");
    std::unique_ptr<WVTransformConstantStratificationKernel> k;
    require(WVTransformConstantStratificationKernel::create(configuration(true),engine(),k));
    failPlan = 0;
    require(k->prepareScalarAdvection().code == WVKernelStatusCode::fftPlanFailure && k->metrics().planCount == 17, "scalar preparation failure");
    failPlan = -1;
    require(k->prepareScalarAdvection());
    require(k->metrics().planCount == configuredScalarPlanCount(), "scalar preparation retry");
}
}
int main() {
    try {
        preservationAndAliasing(); balanced();
        failurePaths(); balanced();
        kernelSetupFailures(); balanced();
        for (bool hydro : {true,false}) for (bool odd : {false,true}) { kernelExecution(hydro,odd); balanced(); }
        std::cout << "Native FFTW preservation, aliasing, RAII failures and prepared execution passed.\n";
        return 0;
    } catch (const std::exception& error) {
        allocationProbe::counting = false; allocationProbe::failAfter = -1;
        std::cerr << error.what() << '\n'; return 1;
    }
}
