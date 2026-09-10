#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"
#include "../../../CompiledKernel/adapters/reference/WVReferenceFFTEngine.hpp"
#include "WVAllocationProbe.hpp"
#if defined(WV_TEST_NATIVE_FFTW)
#include "WVNativeFFTWEngine.hpp"
#endif
#include <algorithm>
#include <cmath>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <vector>

using namespace wavevortex;
namespace {
void check(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
void checked(WVKernelStatus status) { if (!status) throw std::runtime_error(status.message); }
void compare(const double* a, const double* b, std::size_t count, const char* label) {
    double maximum=0, scale=0, error2=0, reference2=0;
    for (std::size_t i=0;i<count;++i) {
        check(std::isfinite(a[i]) && std::isfinite(b[i]),"nonfinite comparison");
        const double error=std::abs(a[i]-b[i]);
        maximum=std::max(maximum,error); scale=std::max(scale,std::abs(a[i]));
        error2+=error*error; reference2+=a[i]*a[i];
    }
    if (maximum>2e-12*std::max(1.0,scale) || std::sqrt(error2)>1e-12*std::max(1.0,std::sqrt(reference2))) {
        std::cerr<<label<<" max="<<maximum<<" scale="<<scale<<" relativeL2="<<std::sqrt(error2)/std::max(1.0,std::sqrt(reference2))<<'\n';
        throw std::runtime_error(label);
    }
}
struct Buffers {
    WVShape2D spectral;
    WVShape3D spatial;
    std::vector<WVComplex64> Ap,Am,A0,Fp,Fm,F0;
    std::vector<double> fields,velocity,derivative,tendency,scalar,rhs;
    explicit Buffers(const WVTransformConstantStratificationDescriptor& d):spectral(d.spectralShape()),spatial(d.spatialShape()),
        Ap(spectral.elementCount()),Am(Ap.size()),A0(Ap.size()),Fp(Ap.size()),Fm(Ap.size()),F0(Ap.size()),
        fields(4*spatial.elementCount()),velocity(3*spatial.elementCount()),derivative(4*spatial.elementCount()),
        tendency(4*spatial.elementCount()),scalar(spatial.elementCount()),rhs(scalar.size()) {}
    WVState state() const { return {179.0,31.0,{{Ap.data(),spectral},{Am.data(),spectral},{A0.data(),spectral}}}; }
    WVFlux flux() { return {{Fp.data(),spectral},{Fm.data(),spectral},{F0.data(),spectral}}; }
    WVMutableCoefficients output() { return {{Fp.data(),spectral},{Fm.data(),spectral},{F0.data(),spectral}}; }
    WVRealFieldBundleView view(std::vector<double>& values,std::size_t channels) { return {values.data(),{spatial.first,spatial.second,spatial.third,channels}}; }
    WVRealFieldBundleConstView input(const std::vector<double>& values,std::size_t channels) const { return {values.data(),{spatial.first,spatial.second,spatial.third,channels}}; }
};
std::unique_ptr<WVFFTEngine> engine(bool native) {
#if defined(WV_TEST_NATIVE_FFTW)
    if(native) { std::unique_ptr<WVFFTEngine> value; checked(WVFFTWEngine::create(2,value)); return value; }
#else
    (void)native;
#endif
    return std::make_unique<WVReferenceFFTEngine>();
}
void compareFlux(Buffers& a,Buffers& b) {
    compare(reinterpret_cast<const double*>(a.Fp.data()),reinterpret_cast<const double*>(b.Fp.data()),2*a.Fp.size(),"Fp");
    compare(reinterpret_cast<const double*>(a.Fm.data()),reinterpret_cast<const double*>(b.Fm.data()),2*a.Fm.size(),"Fm");
    compare(reinterpret_cast<const double*>(a.F0.data()),reinterpret_cast<const double*>(b.F0.data()),2*a.F0.size(),"F0");
}
template <typename T>
bool sameBits(const std::vector<T>& expected,const std::vector<T>& actual) {
    return expected.size()==actual.size() &&
        std::memcmp(expected.data(),actual.data(),expected.size()*sizeof(T))==0;
}
void restoredStageReuse(WVTransformConstantStratificationKernel& control,
    WVTransformConstantStratificationKernel& candidate,Buffers& a,Buffers& b) {
    // A valid trial RHS at B models a rejected integration stage. Restore A
    // into the SAME coefficient allocations, rather than constructing a new
    // kernel/state, so cached pointer identity cannot hide stale phase/state.
    // Earlier matrix operations intentionally exercise arbitrary coefficient
    // payloads. Canonicalize only this late restoration experiment's A/B state.
    const auto& realityMapping=control.descriptor().halfSpectrumMappings();
    for (std::size_t mode=0;mode<control.descriptor().Nkl();++mode) {
        const auto row=realityMapping.storageRowsByWVIndex[mode];
        if (std::find(realityMapping.selfConjugateRows.begin(),realityMapping.selfConjugateRows.end(),row)==realityMapping.selfConjugateRows.end()) continue;
        for (std::size_t j=0;j<a.spectral.rows;++j) {
            const auto index=j+a.spectral.rows*mode;
            a.Am[index]={a.Ap[index].real,-a.Ap[index].imag};
            a.A0[index].imag=0;
        }
    }
    std::copy(a.Ap.begin(),a.Ap.end(),b.Ap.begin());
    std::copy(a.Am.begin(),a.Am.end(),b.Am.begin());
    std::copy(a.A0.begin(),a.A0.end(),b.A0.begin());
    const auto sa=a.state(); auto sb=b.state(); auto fa=a.flux(),fb=b.flux();
    const auto R=a.spatial.elementCount();
    const auto channels=control.descriptor().configuration().isHydrostatic?3u:4u;
    auto au=a.view(a.velocity,3),at=a.view(a.tendency,channels),bt=b.view(b.tendency,channels);
    WVRealVolumeView ar{a.rhs.data(),a.spatial},br{b.rhs.data(),b.spatial};
    auto perturb=[&] {
        for (std::size_t i=0;i<b.Ap.size();++i) {
            b.Ap[i]={1.3*a.Ap[i].real+.007*std::sin(.2*i),.8*a.Ap[i].imag-.005*std::cos(.4*i)};
            b.Am[i]={.7*a.Am[i].real-.004*std::cos(.3*i),1.2*a.Am[i].imag+.003*std::sin(.6*i)};
            b.A0[i]={1.1*a.A0[i].real+.006*std::sin(.5*i),.9*a.A0[i].imag-.002*std::cos(.7*i)};
        }
        // A self-conjugate stored horizontal orbit has real A0 and a
        // conjugate wave pair at every vertical index (including DC).
        const auto& mapping=control.descriptor().halfSpectrumMappings();
        for (std::size_t mode=0;mode<control.descriptor().Nkl();++mode) {
            const auto row=mapping.storageRowsByWVIndex[mode];
            if (std::find(mapping.selfConjugateRows.begin(),mapping.selfConjugateRows.end(),row)==mapping.selfConjugateRows.end()) continue;
            for (std::size_t j=0;j<b.spectral.rows;++j) {
                const auto index=j+b.spectral.rows*mode;
                b.Am[index]={b.Ap[index].real,-b.Ap[index].imag};
                b.A0[index].imag=0;
            }
        }
        sb.t=sa.t+73.25; sb.t0=sa.t0-11.5;
    };
    auto restore=[&] {
        std::copy(a.Ap.begin(),a.Ap.end(),b.Ap.begin());
        std::copy(a.Am.begin(),a.Am.end(),b.Am.begin());
        std::copy(a.A0.begin(),a.A0.end(),b.A0.begin());
        sb.t=sa.t; sb.t0=sa.t0;
    };
    checked(control.nonlinearFlux(sa,fa)); checked(candidate.nonlinearFlux(sb,fb)); compareFlux(a,b);
    const auto originalFp=b.Fp,originalFm=b.Fm,originalF0=b.F0;
    perturb();
    checked(control.nonlinearFlux(sb,fa)); checked(candidate.nonlinearFlux(sb,fb)); compareFlux(a,b);
    check(!sameBits(originalFp,b.Fp) || !sameBits(originalFm,b.Fm) || !sameBits(originalF0,b.F0),"trial B did not change ordinary RHS");
    restore();
    checked(control.nonlinearFlux(sa,fa)); checked(candidate.nonlinearFlux(sb,fb)); compareFlux(a,b);
    check(sameBits(originalFp,b.Fp) && sameBits(originalFm,b.Fm) && sameBits(originalF0,b.F0),"restored A ordinary RHS differs from saved A");

    // The external-velocity route generates its phase during the first
    // derivative target. A subsequent scalar call reuses full-grid scratch;
    // exercise both at B before restoring the original state and input data.
    checked(control.transformWaveVortexToUVW(sa,au));
    const auto originalVelocity=a.velocity;
    std::copy(a.scalar.begin(),a.scalar.end(),b.scalar.begin());
    checked(control.nonlinearFluxUsingAdvectionFields(sa,fa,a.input(a.velocity,3),&at));
    checked(candidate.nonlinearFluxUsingAdvectionFields(sb,fb,a.input(a.velocity,3),&bt)); compareFlux(a,b);
    compare(a.tendency.data(),b.tendency.data(),channels*R,"A external-velocity tendency");
    const auto externalFp=b.Fp,externalFm=b.Fm,externalF0=b.F0;
    const auto originalTendency=b.tendency;
    checked(control.advectFGridScalar({a.scalar.data(),a.spatial},a.input(a.velocity,3),true,ar));
    checked(candidate.advectFGridScalar({b.scalar.data(),b.spatial},a.input(a.velocity,3),true,br));
    compare(a.rhs.data(),b.rhs.data(),R,"A configured scalar RHS");
    const auto originalScalarRhs=b.rhs;
    perturb();
    for (std::size_t i=0;i<R;++i) b.scalar[i]=.4*a.scalar[i]+.13*std::sin(.37*i);
    checked(control.transformWaveVortexToUVW(sb,au));
    checked(control.nonlinearFluxUsingAdvectionFields(sb,fa,a.input(a.velocity,3),&at));
    checked(candidate.nonlinearFluxUsingAdvectionFields(sb,fb,a.input(a.velocity,3),&bt)); compareFlux(a,b);
    compare(a.tendency.data(),b.tendency.data(),channels*R,"B external-velocity tendency");
    checked(control.advectFGridScalar({b.scalar.data(),b.spatial},a.input(a.velocity,3),true,ar));
    checked(candidate.advectFGridScalar({b.scalar.data(),b.spatial},a.input(a.velocity,3),true,br));
    compare(a.rhs.data(),b.rhs.data(),R,"B configured scalar RHS");
    check(!sameBits(originalScalarRhs,b.rhs),"trial B did not change scalar RHS");
    restore();
    std::copy(originalVelocity.begin(),originalVelocity.end(),a.velocity.begin());
    std::copy(a.scalar.begin(),a.scalar.end(),b.scalar.begin());
    checked(control.nonlinearFluxUsingAdvectionFields(sa,fa,a.input(a.velocity,3),&at));
    checked(candidate.nonlinearFluxUsingAdvectionFields(sb,fb,a.input(a.velocity,3),&bt)); compareFlux(a,b);
    compare(a.tendency.data(),b.tendency.data(),channels*R,"restored A external-velocity tendency");
    check(sameBits(externalFp,b.Fp) && sameBits(externalFm,b.Fm) && sameBits(externalF0,b.F0),"restored A external RHS differs from saved A");
    check(sameBits(originalTendency,b.tendency),"restored A tendency differs from saved A");
    checked(control.advectFGridScalar({a.scalar.data(),a.spatial},a.input(a.velocity,3),true,ar));
    checked(candidate.advectFGridScalar({b.scalar.data(),b.spatial},a.input(a.velocity,3),true,br));
    compare(a.rhs.data(),b.rhs.data(),R,"restored A configured scalar RHS");
    check(sameBits(originalScalarRhs,b.rhs),"restored A scalar RHS differs from saved A");
    check(sameBits(a.Ap,b.Ap) && sameBits(a.Am,b.Am) && sameBits(a.A0,b.A0),"restored coefficient bytes changed");
}
void testCase(std::size_t nx,std::size_t ny,bool hydro,bool antialias,bool native,std::size_t retainedVertical=0) {
    WVTransformConstantStratificationConfiguration c;
    c.Nx=nx;c.Ny=ny;c.Nz=7;c.Nj=retainedVertical?retainedVertical:(antialias?4:6);
    c.Lx=15000;c.Ly=12000;c.Lz=1300;c.N0=5.2e-3;c.rho0=1025;c.g=9.81;
    c.planetaryRadius=6.371e6;c.rotationRate=7.2921e-5;c.latitude=33;
    c.isHydrostatic=hydro;c.shouldAntialias=antialias;
    std::unique_ptr<WVTransformConstantStratificationKernel> control,candidate;
    WVConstantKernelExecutionOptions options;
    options.schedule=WVConstantNonlinearFluxSchedule::frozenStreamed;
    checked(WVTransformConstantStratificationKernel::create(c,engine(native),control,options));
    options.schedule=WVConstantNonlinearFluxSchedule::compactCandidate;
    options.horizontalOuterWorkers=2;options.pointwiseWorkers=2;
    checked(WVTransformConstantStratificationKernel::create(c,engine(native),candidate,options));
    check(candidate->verticalExecutionRowCount()==candidate->descriptor().Nkl(),"vertical rows not compact");
    Buffers a(control->descriptor()),b(candidate->descriptor());
    // Every stored orbit participates, including the mean, inertial, boundary,
    // conjugated and Nyquist representatives on the unfiltered even grids.
    for(std::size_t i=0;i<a.Ap.size();++i) {
        a.Ap[i]={0.02*std::sin(0.7*i),0.01*std::cos(0.3*i)};
        a.Am[i]={0.017*std::cos(0.4*i),-0.012*std::sin(0.2*i)};
        a.A0[i]={0.011*std::cos(0.6*i),0.014*std::sin(0.8*i)};
    }
    b.Ap=a.Ap;b.Am=a.Am;b.A0=a.A0;
    const auto R=a.spatial.elementCount();
    auto sa=a.state(),sb=b.state();auto fa=a.flux(),fb=b.flux();
    auto alias=b.view(b.velocity,3);
    WVState overlapping=sb;
    overlapping.coefficients.Ap.data=reinterpret_cast<const WVComplex64*>(alias.data);
    check(candidate->transformWaveVortexToUVW(overlapping,alias).code==WVKernelStatusCode::overlappingArrays,"inverse alias must reject");
    auto invalidFlux=fb;invalidFlux.Fm=invalidFlux.Fp;
    check(candidate->nonlinearFlux(sb,invalidFlux).code==WVKernelStatusCode::overlappingArrays,"flux alias must reject");
    auto av=a.view(a.fields,4),bv=b.view(b.fields,4);
    checked(control->transformWaveVortexToUVWEta(sa,av));checked(candidate->transformWaveVortexToUVWEta(sb,bv));
    compare(a.fields.data(),b.fields.data(),4*R,"inverse UVWEta");
    auto au=a.view(a.velocity,3),bu=b.view(b.velocity,3);
    checked(control->transformWaveVortexToUVW(sa,au));checked(candidate->transformWaveVortexToUVW(sb,bu));
    compare(a.velocity.data(),b.velocity.data(),3*R,"inverse UVW");
    auto ad=a.view(a.derivative,3),bd=b.view(b.derivative,3);
    for(auto field:{WVDynamicalField::u,WVDynamicalField::v,WVDynamicalField::w,WVDynamicalField::eta}) {
        checked(control->transformStateFieldDerivatives(sa,field,ad));checked(candidate->transformStateFieldDerivatives(sb,field,bd));
        compare(a.derivative.data(),b.derivative.data(),3*R,"state derivatives");
    }
    ad=a.view(a.derivative,4);bd=b.view(b.derivative,4);
    checked(control->transformToSpatialDomainWithFAllDerivatives({a.Ap.data(),a.spectral},{a.A0.data(),a.spectral},ad));
    checked(candidate->transformToSpatialDomainWithFAllDerivatives({b.Ap.data(),b.spectral},{b.A0.data(),b.spectral},bd));
    compare(a.derivative.data(),b.derivative.data(),4*R,"F derivatives");
    checked(control->transformToSpatialDomainWithGAllDerivatives({a.Ap.data(),a.spectral},{a.A0.data(),a.spectral},ad));
    checked(candidate->transformToSpatialDomainWithGAllDerivatives({b.Ap.data(),b.spectral},{b.A0.data(),b.spectral},bd));
    compare(a.derivative.data(),b.derivative.data(),4*R,"G derivatives");
    auto oa=a.output(),ob=b.output();
    if(hydro) {
        std::copy_n(a.fields.data()+3*R,R,a.fields.data()+2*R);
        // Identical arbitrary physical input isolates projection from inverse roundoff.
        checked(control->transformUVEtaToWaveVortex(a.input(a.fields,3),sa.t,sa.t0,oa));
        checked(candidate->transformUVEtaToWaveVortex(a.input(a.fields,3),sa.t,sa.t0,ob));
    } else {
        checked(control->transformUVWEtaToWaveVortex(a.input(a.fields,4),sa.t,sa.t0,oa));
        checked(candidate->transformUVWEtaToWaveVortex(a.input(a.fields,4),sa.t,sa.t0,ob));
    }
    compareFlux(a,b);
    checked(control->nonlinearFlux(sa,fa));checked(candidate->nonlinearFlux(sb,fb));compareFlux(a,b);
    checked(control->nonlinearFluxWithAdvectionFields(sa,fa,au));checked(candidate->nonlinearFluxWithAdvectionFields(sb,fb,bu));
    compareFlux(a,b);compare(a.velocity.data(),b.velocity.data(),3*R,"produced velocity");
    auto at=a.view(a.tendency,hydro?3:4),bt=b.view(b.tendency,hydro?3:4);
    checked(control->nonlinearFluxUsingAdvectionFields(sa,fa,a.input(a.velocity,3),&at));
    checked(candidate->nonlinearFluxUsingAdvectionFields(sb,fb,a.input(a.velocity,3),&bt));
    compareFlux(a,b);compare(a.tendency.data(),b.tendency.data(),(hydro?3:4)*R,"raw tendency");
    const auto fp=b.Fp,fm=b.Fm,f0=b.F0;
    checked(candidate->nonlinearFluxUsingAdvectionFields(sb,fb,a.input(a.velocity,3),&bt,false));
    check(std::memcmp(fp.data(),b.Fp.data(),fp.size()*sizeof(WVComplex64))==0,"spatial-only Fp unchanged");
    check(std::memcmp(fm.data(),b.Fm.data(),fm.size()*sizeof(WVComplex64))==0,"spatial-only Fm unchanged");
    check(std::memcmp(f0.data(),b.F0.data(),f0.size()*sizeof(WVComplex64))==0,"spatial-only F0 unchanged");
    compare(a.tendency.data(),b.tendency.data(),(hydro?3:4)*R,"spatial-only tendency");
    // Arbitrary scalar deliberately contains vertical/horizontal modes outside
    // the retained WV set; this operation must use the full-grid scalar path.
    for(std::size_t z=0;z<c.Nz;++z)for(std::size_t y=0;y<ny;++y)for(std::size_t x=0;x<nx;++x)
        a.scalar[x+nx*(y+ny*z)]=std::cos(2.7*x)+std::sin(1.9*y)+std::cos(3.141592653589793*5*z/(c.Nz-1))+
            .3*std::cos(1.2*x)*std::cos(3.141592653589793*y)*std::sin(1.1*z);
    checked(control->prepareScalarAdvection());checked(candidate->prepareScalarAdvection());
    const auto scalarBefore=a.scalar,velocityBefore=a.velocity;
    const auto C=c.Nz*candidate->descriptor().Nkl();
    const auto H=c.Nz*(nx/2+1)*ny;
    const auto scalarMetrics=candidate->metrics();
    check(scalarMetrics.halfSpectrumScratchCapacityBytes==sizeof(WVComplex64)*std::max(4*C,H),
        "configured scalar arena must be max(4C,H)");
    check(scalarMetrics.realScratchCapacityBytes==6*R*sizeof(double),"scalar must preserve six real volumes");
    ad=a.view(a.derivative,3);bd=b.view(b.derivative,3);
    checked(control->transformGGridScalarDerivatives({a.scalar.data(),a.spatial},ad));
    checked(candidate->transformGGridScalarDerivatives({a.scalar.data(),a.spatial},bd));
    compare(a.derivative.data(),b.derivative.data(),3*R,"full-grid G scalar derivatives");
    WVRealVolumeView ar{a.rhs.data(),a.spatial},br{b.rhs.data(),b.spatial};
    for(bool filter:{false,true}) {
        checked(control->advectFGridScalar({a.scalar.data(),a.spatial},a.input(a.velocity,3),filter,ar));
        checked(candidate->advectFGridScalar({a.scalar.data(),a.spatial},a.input(a.velocity,3),filter,br));
        compare(a.rhs.data(),b.rhs.data(),R,"full-grid F scalar advection");
    }
    check(std::memcmp(a.scalar.data(),scalarBefore.data(),R*sizeof(double))==0,"scalar input changed");
    check(std::memcmp(a.velocity.data(),velocityBefore.data(),3*R*sizeof(double))==0,"scalar velocity input changed");
    // Re-enter compact operations after scalar scratch expansion, then repeat
    // every configured operation while global allocation interposition is live.
    checked(control->nonlinearFlux(sa,fa));checked(candidate->nonlinearFlux(sb,fb));compareFlux(a,b);
    if (nx==6 && ny==5 && antialias) restoredStageReuse(*control,*candidate,a,b);
    const auto bytes=candidate->persistentBytes(),plans=candidate->metrics().planCount;
    // The direct reference provider intentionally allocates a vertical temporary.
    // The native configured path is the allocation-free performance contract.
    allocationProbe::calls=0;allocationProbe::counting=native;
    checked(candidate->transformWaveVortexToUVWEta(sb,bv));
    checked(candidate->transformWaveVortexToUVW(sb,bu));
    checked(candidate->transformStateFieldDerivatives(sb,WVDynamicalField::eta,bd));
    auto family=b.view(b.derivative,4);
    checked(candidate->transformToSpatialDomainWithFAllDerivatives({b.Ap.data(),b.spectral},{b.A0.data(),b.spectral},family));
    checked(candidate->transformToSpatialDomainWithGAllDerivatives({b.Ap.data(),b.spectral},{b.A0.data(),b.spectral},family));
    if(hydro) checked(candidate->transformUVEtaToWaveVortex(a.input(a.fields,3),sa.t,sa.t0,ob));
    else checked(candidate->transformUVWEtaToWaveVortex(a.input(a.fields,4),sa.t,sa.t0,ob));
    checked(candidate->nonlinearFlux(sb,fb));
    checked(candidate->nonlinearFluxWithAdvectionFields(sb,fb,bu));
    checked(candidate->nonlinearFluxUsingAdvectionFields(sb,fb,a.input(a.velocity,3),&bt,false));
    checked(candidate->transformGGridScalarDerivatives({a.scalar.data(),a.spatial},bd));
    checked(candidate->advectFGridScalar({a.scalar.data(),a.spatial},a.input(a.velocity,3),true,br));
    allocationProbe::counting=false;
    check(allocationProbe::calls==0,"warmed candidate allocated");
    check(bytes==candidate->persistentBytes() && plans==candidate->metrics().planCount,"warmed ownership changed");
    compare(reinterpret_cast<const double*>(a.Ap.data()),reinterpret_cast<const double*>(b.Ap.data()),2*a.Ap.size(),"input Ap unchanged");
    compare(reinterpret_cast<const double*>(a.Am.data()),reinterpret_cast<const double*>(b.Am.data()),2*a.Am.size(),"input Am unchanged");
    compare(reinterpret_cast<const double*>(a.A0.data()),reinterpret_cast<const double*>(b.A0.data()),2*a.A0.size(),"input A0 unchanged");
    std::cout<<"compact case "<<nx<<'x'<<ny<<" hydro="<<hydro<<" aa="<<antialias<<" native="<<native
        <<" owned="<<candidate->persistentBytes()<<" controlOwned="<<control->persistentBytes()<<" rows="<<candidate->verticalExecutionRowCount()<<" schedule="<<candidate->retainedHorizontalScheduleIdentifier()<<" passed\n";
}
}
int main() {
    try {
        for(bool native:{false,true}) {
#if !defined(WV_TEST_NATIVE_FFTW)
            if(native)continue;
#endif
            for(bool hydro:{false,true})testCase(2,2,hydro,false,native,1);
            for(bool hydro:{false,true})for(bool aa:{false,true}) {
                testCase(6,5,hydro,aa,native);testCase(5,6,hydro,aa,native);
                if(native && aa)testCase(26,24,hydro,aa,native);
            }
        }
        return 0;
    } catch(const std::exception& error) {
        allocationProbe::counting=false;
        std::cerr<<error.what()<<'\n';return 1;
    }
}
