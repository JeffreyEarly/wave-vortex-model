#include "WaveVortexKernel/WVTransformHydrostaticKernel.hpp"
#include "WVSpectralValidation.hpp"
#include <algorithm>
#include <cmath>

namespace wavevortex {
namespace {
using namespace spectral_detail;
constexpr double pi = 3.1415926535897932384626433832795;
WVComplex64 add(WVComplex64 a,WVComplex64 b) { return {a.real+b.real,a.imag+b.imag}; }
WVComplex64 subtract(WVComplex64 a,WVComplex64 b) { return {a.real-b.real,a.imag-b.imag}; }
WVComplex64 scale(WVComplex64 a,double b) { return {a.real*b,a.imag*b}; }
WVComplex64 conjugate(WVComplex64 a) { return {a.real,-a.imag}; }
WVComplex64 multiply(WVComplex64 a,WVComplex64 b) { return {a.real*b.real-a.imag*b.imag,a.real*b.imag+a.imag*b.real}; }
WVComplexInput input(const WVComplex64* p,std::size_t n) { return {p,nullptr,nullptr,n*sizeof(WVComplex64)}; }
WVComplexOutput output(WVComplex64* p,std::size_t n) { return {p,nullptr,nullptr,n*sizeof(WVComplex64)}; }
WVCoefficients view(WVMutableCoefficients a) { return {{a.Ap.data,a.Ap.shape},{a.Am.data,a.Am.shape},{a.A0.data,a.A0.shape}}; }
bool valid(WVHydrostaticFamily f) { return f==WVHydrostaticFamily::F || f==WVHydrostaticFamily::G; }
bool valid(WVHydrostaticComponent c) { return c>=WVHydrostaticComponent::all && c<=WVHydrostaticComponent::meanDensityAnomaly; }
bool surface(WVHydrostaticField f) { return f>=WVHydrostaticField::ssh && f<=WVHydrostaticField::ssv; }
bool selected(const WVHydrostaticModeFactors& f,WVHydrostaticComponent c,bool wave) {
    if (c==WVHydrostaticComponent::all) return wave ? f.wave || f.inertial : f.geostrophic || f.meanDensityAnomaly;
    if (wave) return c==WVHydrostaticComponent::wave ? f.wave : c==WVHydrostaticComponent::inertial && f.inertial;
    return c==WVHydrostaticComponent::geostrophic ? f.geostrophic : c==WVHydrostaticComponent::meanDensityAnomaly && f.meanDensityAnomaly;
}
WVKernelStatus unsupported() { return {WVKernelStatusCode::unsupportedOperation,"Unsupported hydrostatic field, derivative, family or component."}; }
WVKernelStatus reentrant() { return {WVKernelStatusCode::reentrantExecution,"Hydrostatic workspace is already active."}; }
}

WVKernelStatus WVTransformHydrostaticKernel::create(std::shared_ptr<const WVStratifiedModalSource> source,
    std::unique_ptr<WVFFTEngine> engine,std::unique_ptr<WVTransformHydrostaticKernel>& result,MatrixBackendFactory factory) {
    try {
        if (!source || !engine || !factory) return {WVKernelStatusCode::invalidConfiguration,"Scientific source, FFT engine and matrix backend factory are required."};
        const auto& g=source->geometry();
        if (g.transformClass!="WVTransformHydrostatic" || g.Nx<2 || g.Ny<2 || g.Nz<3 || !g.Nj || g.Nj>=g.Nz || !g.Nkl ||
            g.j.size()!=g.Nj || g.h_0.size()!=g.Nj || g.k.size()!=g.Nkl || g.l.size()!=g.Nkl || g.modes.size()!=g.Nkl ||
            g.z.size()!=g.Nz || g.N2.size()!=g.Nz || g.rho_nm0.size()!=g.Nz || g.dLnN2.size()!=g.Nz || g.z_int.size()!=g.Nz ||
            source->sourceIdentity().empty() || source->modeSetIdentity().empty())
            return {WVKernelStatusCode::invalidConfiguration,"Invalid hydrostatic scientific source."};
        auto candidate=std::unique_ptr<WVTransformHydrostaticKernel>(new WVTransformHydrostaticKernel);
        auto& c=*candidate; c.source_=std::move(source);
        c.S_=product(g.Nj,g.Nkl); c.H_=product(g.Nz,g.Nkl); c.R_=product(product(g.Nx,g.Ny),g.Nz);
        product(product(3,c.S_),sizeof(WVComplex64)); product(product(2,c.H_),sizeof(WVComplex64));
        product(product(10,c.R_),sizeof(double)); product(c.S_,sizeof(WVHydrostaticModeFactors));
        c.engineIdentifier_=engine->identifier(); c.engineLibraryIdentity_=engine->libraryIdentity();
        WVRetainedHorizontalSpecification horizontal;
        auto status=c.source_->horizontalSpecification(g.Nz,WVComplexRepresentation::interleaved,"hydrostatic-grid",horizontal); if (!status) return status;
        status=WVRetainedHorizontalOperator::create(horizontal,std::move(engine),c.horizontal_); if (!status) return status;
        status=c.horizontal_->createWorkspace(c.horizontalWorkspace_); if (!status) return status;
        const WVStratifiedModalOperator operations[]={WVStratifiedModalOperator::reconstructF,WVStratifiedModalOperator::projectF,WVStratifiedModalOperator::reconstructG,WVStratifiedModalOperator::projectG};
        for (std::size_t i=0;i<4;++i) {
            const bool reconstruction=i%2==0; const std::string family=i<2 ? "F" : "G";
            const auto rows=reconstruction ? g.Nj : g.Nz, outRows=reconstruction ? g.Nz : g.Nj;
            WVComplexLayout in{rows,g.Nkl,1,rows,WVComplexRepresentation::interleaved,family+(reconstruction ? "-modal" : "-grid"),c.source_->modeSetIdentity()};
            WVComplexLayout out{outRows,g.Nkl,1,outRows,WVComplexRepresentation::interleaved,family+(reconstruction ? "-grid" : "-modal"),c.source_->modeSetIdentity()};
            std::unique_ptr<WVVerticalMatrixBackend> backend; status=factory(backend); if (!status) return status;
            status=c.source_->prepareVertical(operations[i],in,out,std::move(backend),c.vertical_[i]); if (!status) return status;
            status=c.vertical_[i]->createWorkspace(c.verticalWorkspace_[i]); if (!status) return status;
        }
        const double f=2*g.rotationRate*std::sin(g.latitude*pi/180);
        if (!std::isfinite(f) || f==0 || !std::isfinite(g.g) || !(g.g>0) || !std::isfinite(g.Lz) || !(g.Lz>0) || !std::isfinite(g.rho0) || !(g.rho0>0))
            return {WVKernelStatusCode::invalidConfiguration,"Invalid hydrostatic physical constants."};
        c.factors_.resize(c.S_);
        for (std::size_t i=0;i<c.S_;++i) {
            const auto j=i%g.Nj,mode=i/g.Nj; auto& a=c.factors_[i];
            const double k=g.k[mode],l=g.l[mode],K2=k*k+l*l,h=g.h_0[j];
            if (!std::isfinite(K2) || !std::isfinite(h) || !(h>0) || !std::isfinite(g.j[j]) || g.j[j]<0)
                return {WVKernelStatusCode::invalidConfiguration,"Invalid hydrostatic mode or equivalent depth."};
            const bool barotropic=g.j[j]==0;
            a.omega=std::sqrt(g.g*h*K2+f*f);
            if (!std::isfinite(a.omega) || !(a.omega>0)) return {WVKernelStatusCode::numericalFailure,"Hydrostatic frequency overflow."};
            a.wave=K2>0 && !barotropic; a.inertial=K2==0;
            a.geostrophic=K2>0; a.meanDensityAnomaly=K2==0 && !barotropic;
            if (a.wave) {
                const double K=std::sqrt(K2),alpha=std::atan2(l,k);
                a.UAp={std::cos(alpha),-f/a.omega*std::sin(alpha)};
                a.VAp={std::sin(alpha),f/a.omega*std::cos(alpha)};
                a.WAp={0,-K*h}; a.NAp=-K*h/a.omega;
                a.ApmD={0,-1/(2*K*h)}; a.ApmN=-a.omega/(2*K*h); a.waveEnergy=2*h;
            }
            if (a.inertial) { a.UAp={1,0}; a.VAp={0,1}; a.waveEnergy=barotropic ? g.Lz : h; }
            if (a.geostrophic) {
                const double denominator=K2+(barotropic ? 0 : f*f/(g.g*h));
                a.UA0={0,l/denominator}; a.VA0={0,-k/denominator};
                a.PA0=-(f/g.g)/denominator; a.NA0=barotropic ? 0 : a.PA0;
                a.A0Z=1; a.A0N=barotropic ? 0 : -f/h;
                a.psi=-1/denominator; a.qgpv=1; a.enstrophy=barotropic ? g.Lz : h;
                a.balancedEnergy=((barotropic ? g.Lz : h)*K2+(barotropic ? 0 : f*f/g.g))/(denominator*denominator);
            }
            if (a.meanDensityAnomaly) {
                a.NA0=1; a.PA0=1; a.A0N=1; a.A0Z=f*f/(2*h);
                a.psi=g.g/f; a.qgpv=-f/h; a.enstrophy=f*f/(2*h); a.balancedEnergy=g.g/2;
            }
            for (double x : {a.UAp.real,a.UAp.imag,a.VAp.real,a.VAp.imag,a.WAp.imag,a.NAp,a.UA0.imag,a.VA0.imag,
                a.NA0,a.PA0,a.ApmD.imag,a.ApmN,a.A0Z,a.A0N,a.waveEnergy,a.balancedEnergy,a.psi,a.qgpv,a.enstrophy})
                if (!std::isfinite(x)) return {WVKernelStatusCode::numericalFailure,"Hydrostatic coefficient factor overflow."};
        }
        c.modal_.resize(3*c.S_); c.gridSpectral_.resize(2*c.H_); c.phase_.resize(c.S_); c.real_.resize(10*c.R_);
        auto& s=c.storage_; s.sharedScientificBytes=c.source_->persistentBytes(); s.preparedBytes=c.horizontal_->persistentBytes();
        s.workspaceBytes=c.horizontalWorkspace_->persistentBytes(); s.providerBytesLowerBound=c.horizontal_->providerBytesLowerBound(); s.planBytesLowerBound=c.horizontalWorkspace_->planBytesLowerBound();
        for (std::size_t i=0;i<4;++i) { s.preparedBytes+=c.vertical_[i]->persistentBytes(); s.workspaceBytes+=c.verticalWorkspace_[i]->persistentBytes(); }
        s.spectralScratchBytes=(c.modal_.capacity()+c.gridSpectral_.capacity()+c.phase_.capacity())*sizeof(WVComplex64);
        s.realScratchBytes=c.real_.capacity()*sizeof(double); s.factorBytes=c.factors_.capacity()*sizeof(WVHydrostaticModeFactors);
        result=std::move(candidate); return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Hydrostatic setup allocation failed."}; }
      catch (const std::overflow_error& e) { return {WVKernelStatusCode::sizeOverflow,e.what()}; }
}
std::size_t WVTransformHydrostaticKernel::persistentBytes() const noexcept {
    const auto& s=storage_; return sizeof(*this)+s.sharedScientificBytes+s.preparedBytes+s.workspaceBytes+s.spectralScratchBytes+s.realScratchBytes+s.factorBytes;
}
WVKernelStatus WVTransformHydrostaticKernel::spectral(WVComplexConstView a) const {
    if (a.shape.rows!=geometry().Nj || a.shape.columns!=geometry().Nkl) return {WVKernelStatusCode::invalidShape,"Expected canonical [Nj,Nkl] coefficients."};
    if (!addressFits(a.data,S_*sizeof(WVComplex64),alignof(WVComplex64))) return {WVKernelStatusCode::invalidPointer,"Invalid coefficient storage."};
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::volume(WVRealVolumeConstView a,bool isSurface) const {
    const auto& g=geometry(); const auto nz=isSurface ? 1 : g.Nz;
    if (a.shape.first!=g.Nx || a.shape.second!=g.Ny || a.shape.third!=nz) return {WVKernelStatusCode::invalidShape,"Unexpected hydrostatic field shape."};
    if (!addressFits(a.data,(R_/g.Nz)*nz*sizeof(double),alignof(double))) return {WVKernelStatusCode::invalidPointer,"Invalid field storage."};
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::disjoint(const void* a,std::size_t an,const void* b,std::size_t bn) const {
    if (overlap(a,an,b,bn)) return {WVKernelStatusCode::overlappingArrays,"Hydrostatic arrays must not overlap."};
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::outputs(WVMutableCoefficients a) const {
    for (auto x : {a.Ap,a.Am,a.A0}) { auto s=spectral({x.data,x.shape}); if (!s) return s; }
    auto s=disjoint(a.Ap.data,S_*sizeof(WVComplex64),a.Am.data,S_*sizeof(WVComplex64)); if (!s) return s;
    s=disjoint(a.Ap.data,S_*sizeof(WVComplex64),a.A0.data,S_*sizeof(WVComplex64)); if (!s) return s;
    return disjoint(a.Am.data,S_*sizeof(WVComplex64),a.A0.data,S_*sizeof(WVComplex64));
}
WVKernelStatus WVTransformHydrostaticKernel::coefficients(const WVCoefficients& a) const {
    for (auto x : {a.Ap,a.Am,a.A0}) {
        auto s=spectral(x); if (!s) return s;
        for (std::size_t i=0;i<S_;++i) if (!std::isfinite(x.data[i].real) || !std::isfinite(x.data[i].imag))
            return {WVKernelStatusCode::numericalFailure,"Nonfinite hydrostatic coefficient."};
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::state(const WVState& a) const {
    auto s=coefficients(a.coefficients); if (!s) return s;
    if (!std::isfinite(a.t) || !std::isfinite(a.t0) || !std::isfinite(a.t-a.t0)) return {WVKernelStatusCode::invalidConfiguration,"Nonfinite hydrostatic time or elapsed time."};
    for (const auto& f:factors_) if (!std::isfinite(f.omega*(a.t-a.t0))) return {WVKernelStatusCode::numericalFailure,"Hydrostatic phase overflow."};
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::preparePhase(double t,double t0) {
    if (!std::isfinite(t) || !std::isfinite(t0) || !std::isfinite(t-t0)) return {WVKernelStatusCode::invalidConfiguration,"Nonfinite hydrostatic time or elapsed time."};
    for (const auto& f:factors_) if (!std::isfinite(f.omega*(t-t0))) return {WVKernelStatusCode::numericalFailure,"Hydrostatic phase overflow."};
    for (std::size_t i=0;i<S_;++i) { const double a=factors_[i].omega*(t-t0); phase_[i]={std::cos(a),std::sin(a)}; }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::vertical(std::size_t operation,const WVComplex64* a,WVComplex64* b) {
    return vertical_[operation]->execute(*verticalWorkspace_[operation],input(a,operation%2 ? H_ : S_),output(b,operation%2 ? S_ : H_));
}
WVKernelStatus WVTransformHydrostaticKernel::project(const double* a,WVComplex64* b,WVHydrostaticFamily family) {
    auto s=horizontal_->forward(*horizontalWorkspace_,{a,R_*sizeof(double)},output(gridSpectral_.data(),H_)); if (!s) return s;
    return vertical(family==WVHydrostaticFamily::F ? 1 : 3,gridSpectral_.data(),b);
}
WVKernelStatus WVTransformHydrostaticKernel::transformToSpatial(WVComplexConstView a,WVHydrostaticFamily family,WVRealVolumeView b) {
    if (!valid(family)) return unsupported();
    auto s=spectral(a); if (!s) return s; s=volume({b.data,b.shape}); if (!s) return s;
    s=disjoint(a.data,S_*sizeof(WVComplex64),b.data,R_*sizeof(double)); if (!s) return s;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    s=vertical(family==WVHydrostaticFamily::F ? 0 : 2,a.data,gridSpectral_.data()); if (!s) return s;
    return horizontal_->inverse(*horizontalWorkspace_,input(gridSpectral_.data(),H_),{b.data,R_*sizeof(double)});
}
WVKernelStatus WVTransformHydrostaticKernel::transformFromSpatial(WVRealVolumeConstView a,WVHydrostaticFamily family,WVComplexView b) {
    if (!valid(family)) return unsupported();
    auto s=volume(a); if (!s) return s; s=spectral({b.data,b.shape}); if (!s) return s;
    s=disjoint(a.data,R_*sizeof(double),b.data,S_*sizeof(WVComplex64)); if (!s) return s;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    return project(a.data,b.data,family);
}
WVKernelStatus WVTransformHydrostaticKernel::projectFields(const double* u,const double* v,const double* eta,WVMutableCoefficients b) {
    auto* U=modal_.data(); auto* V=U+S_; auto* N=V+S_;
    auto s=project(u,U,WVHydrostaticFamily::F); if (!s) return s;
    s=project(v,V,WVHydrostaticFamily::F); if (!s) return s;
    s=project(eta,N,WVHydrostaticFamily::G); if (!s) return s;
    for (std::size_t i=0;i<S_;++i) {
        const auto& f=factors_[i]; const auto mode=i/geometry().Nj; const double k=geometry().k[mode],l=geometry().l[mode];
        const auto zeta=subtract(multiply(V[i],{0,k}),multiply(U[i],{0,l}));
        const auto delta=scale(add(multiply(U[i],{0,k}),multiply(V[i],{0,l})),geometry().h_0[i%geometry().Nj]);
        const auto a0=add(scale(zeta,f.A0Z),scale(N[i],f.A0N));
        const auto density=scale(subtract(N[i],scale(a0,f.NA0)),f.ApmN),divergence=multiply(delta,f.ApmD);
        auto ap=add(divergence,density),am=subtract(divergence,density);
        if (f.inertial) { ap=scale(subtract(U[i],multiply(V[i],{0,1})),.5); am=conjugate(ap); }
        b.Ap.data[i]=multiply(ap,conjugate(phase_[i])); b.Am.data[i]=multiply(am,phase_[i]); b.A0.data[i]=a0;
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::transformUVEtaToWaveVortex(WVRealVolumeConstView u,WVRealVolumeConstView v,WVRealVolumeConstView eta,double t,double t0,WVMutableCoefficients b) {
    auto s=outputs(b); if (!s) return s;
    for (auto a : {u,v,eta}) { s=volume(a); if (!s) return s; for (auto out : {b.Ap,b.Am,b.A0}) { s=disjoint(a.data,R_*sizeof(double),out.data,S_*sizeof(WVComplex64)); if (!s) return s; } }
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    s=preparePhase(t,t0); if (!s) return s;
    return projectFields(u.data,v.data,eta.data,b);
}

WVKernelStatus WVTransformHydrostaticKernel::reconstruct(const WVCoefficients& a,WVHydrostaticField field,
    WVHydrostaticDerivative derivative,WVHydrostaticComponent component,double* b) {
    const auto& g=geometry();
    if (field==WVHydrostaticField::zetaX || field==WVHydrostaticField::zetaY) {
        const bool x=field==WVHydrostaticField::zetaX;
        auto s=reconstruct(a,x ? WVHydrostaticField::w : WVHydrostaticField::u,x ? WVHydrostaticDerivative::y : WVHydrostaticDerivative::z,component,b); if (!s) return s;
        s=reconstruct(a,x ? WVHydrostaticField::v : WVHydrostaticField::w,x ? WVHydrostaticDerivative::z : WVHydrostaticDerivative::x,component,real_.data()+8*R_); if (!s) return s;
        for (std::size_t i=0;i<R_;++i) b[i]-=real_[8*R_+i];
        return WVKernelStatus::ok();
    }
    const bool density=field==WVHydrostaticField::rhoE || field==WVHydrostaticField::rhoTotal;
    const bool totalDensity=field==WVHydrostaticField::rhoTotal;
    if (density) field=WVHydrostaticField::eta;
    if (field==WVHydrostaticField::ssh) field=WVHydrostaticField::pi;
    if (field==WVHydrostaticField::ssu) field=WVHydrostaticField::u;
    if (field==WVHydrostaticField::ssv) field=WVHydrostaticField::v;
    const bool G=field==WVHydrostaticField::w || field==WVHydrostaticField::eta;
    const bool dz=derivative==WVHydrostaticDerivative::z;
    for (std::size_t i=0;i<S_;++i) {
        const auto& f=factors_[i]; const auto mode=i/g.Nj; WVComplex64 p{},m{},z{};
        switch(field) {
            case WVHydrostaticField::u: p=f.UAp; m=conjugate(p); z=f.UA0; break;
            case WVHydrostaticField::v: p=f.VAp; m=conjugate(p); z=f.VA0; break;
            case WVHydrostaticField::w: p=f.WAp; m=p; break;
            case WVHydrostaticField::eta: p={f.NAp,0}; m={-f.NAp,0}; z={f.NA0,0}; break;
            case WVHydrostaticField::pi: p={f.NAp,0}; m={-f.NAp,0}; z={f.PA0,0}; break;
            case WVHydrostaticField::p: p={g.rho0*g.g*f.NAp,0}; m=scale(p,-1); z={g.rho0*g.g*f.PA0,0}; break;
            case WVHydrostaticField::psi: z={f.psi,0}; break;
            case WVHydrostaticField::qgpv: z={f.qgpv,0}; break;
            case WVHydrostaticField::zetaZ:
                p=subtract(multiply(f.VAp,{0,g.k[mode]}),multiply(f.UAp,{0,g.l[mode]}));
                m=subtract(multiply(conjugate(f.VAp),{0,g.k[mode]}),multiply(conjugate(f.UAp),{0,g.l[mode]}));
                z=subtract(multiply(f.VA0,{0,g.k[mode]}),multiply(f.UA0,{0,g.l[mode]})); break;
            default: return unsupported();
        }
        WVComplex64 value{};
        if (selected(f,component,true)) value=add(multiply(multiply(p,a.Ap.data[i]),phase_[i]),multiply(multiply(m,a.Am.data[i]),conjugate(phase_[i])));
        if (selected(f,component,false)) value=add(value,multiply(z,a.A0.data[i]));
        if (derivative==WVHydrostaticDerivative::x) value=multiply(value,{0,g.k[mode]});
        if (derivative==WVHydrostaticDerivative::y) value=multiply(value,{0,g.l[mode]});
        if (dz && G) value=scale(value,1/g.h_0[i%g.Nj]);
        modal_[i]=value;
    }
    auto s=vertical(G!=dz ? 2 : 0,modal_.data(),gridSpectral_.data()); if (!s) return s;
    if (dz && !G) for (std::size_t mode=0;mode<g.Nkl;++mode) for (std::size_t z=0;z<g.Nz;++z)
        gridSpectral_[z+g.Nz*mode]=scale(gridSpectral_[z+g.Nz*mode],-g.N2[z]/g.g);
    s=horizontal_->inverse(*horizontalWorkspace_,input(gridSpectral_.data(),H_),{b,R_*sizeof(double)}); if (!s) return s;
    if (density) {
        const double* eta=nullptr;
        if (dz) { s=reconstruct(a,WVHydrostaticField::eta,WVHydrostaticDerivative::value,component,real_.data()+8*R_); if (!s) return s; eta=real_.data()+8*R_; }
        const auto plane=R_/g.Nz;
        for (std::size_t z=0;z<g.Nz;++z) for (std::size_t xy=0;xy<plane;++xy) {
            const auto i=xy+plane*z;
            b[i]=(g.rho0/g.g)*g.N2[z]*(b[i]+(dz ? g.dLnN2[z]*eta[i] : 0));
            if (totalDensity && derivative==WVHydrostaticDerivative::value) b[i]+=g.rho_nm0[z];
            if (totalDensity && dz) b[i]-=(g.rho0/g.g)*g.N2[z];
        }
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::transformStateField(const WVState& a,WVHydrostaticField field,WVRealVolumeView b,WVHydrostaticDerivative derivative,WVHydrostaticComponent component) {
    if (field<WVHydrostaticField::u || field>WVHydrostaticField::ssv || derivative<WVHydrostaticDerivative::value || derivative>WVHydrostaticDerivative::z || !valid(component) ||
        ((field==WVHydrostaticField::zetaX || field==WVHydrostaticField::zetaY) && derivative!=WVHydrostaticDerivative::value) ||
        (field==WVHydrostaticField::rhoTotal && component!=WVHydrostaticComponent::all)) return unsupported();
    auto s=state(a); if (!s) return s; s=volume({b.data,b.shape},surface(field)); if (!s) return s;
    const auto bytes=(surface(field) ? R_/geometry().Nz : R_)*sizeof(double);
    for (auto x : {a.coefficients.Ap,a.coefficients.Am,a.coefficients.A0}) { s=disjoint(x.data,S_*sizeof(WVComplex64),b.data,bytes); if (!s) return s; }
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    s=preparePhase(a.t,a.t0); if (!s) return s;
    s=reconstruct(a.coefficients,field,derivative,component,surface(field) ? real_.data()+9*R_ : b.data); if (!s) return s;
    if (surface(field)) { const auto plane=R_/geometry().Nz; std::copy_n(real_.data()+10*R_-plane,plane,b.data); }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::evolveCoefficients(const WVState& a,WVMutableCoefficients b) {
    auto s=state(a); if (!s) return s; s=outputs(b); if (!s) return s;
    const WVComplexConstView inputs[]={a.coefficients.Ap,a.coefficients.Am,a.coefficients.A0}; const WVComplexView targets[]={b.Ap,b.Am,b.A0};
    for (std::size_t i=0;i<3;++i) for (std::size_t j=0;j<3;++j) if (i!=j || inputs[i].data!=targets[j].data) {
        s=disjoint(inputs[i].data,S_*sizeof(WVComplex64),targets[j].data,S_*sizeof(WVComplex64)); if (!s) return s;
    }
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    s=preparePhase(a.t,a.t0); if (!s) return s;
    for (std::size_t i=0;i<S_;++i) {
        b.Ap.data[i]=multiply(a.coefficients.Ap.data[i],phase_[i]); b.Am.data[i]=multiply(a.coefficients.Am.data[i],conjugate(phase_[i])); b.A0.data[i]=a.coefficients.A0.data[i];
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::constrainCoefficients(WVMutableCoefficients a) const {
    auto s=outputs(a); if (!s) return s; s=coefficients(view(a)); if (!s) return s;
    for (std::size_t i=0;i<S_;++i) {
        const auto& f=factors_[i];
        if (!f.wave && !f.inertial) { a.Ap.data[i]={}; a.Am.data[i]={}; }
        if (f.inertial) a.Am.data[i]=conjugate(a.Ap.data[i]);
        if (!f.geostrophic && !f.meanDensityAnomaly) a.A0.data[i]={};
        if (f.meanDensityAnomaly) a.A0.data[i].imag=0;
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::nonlinearFlux(const WVState& a,WVFlux& b,
    WVRealFieldBundleView* spatialTendency,const WVRealFieldBundleConstView* preparedFields,bool projectFlux) {
    if (!projectFlux && !spatialTendency)
        return {WVKernelStatusCode::invalidConfiguration,"Spatial-only nonlinear evaluation requires output storage."};
    auto s=state(a); if (!s) return s; WVMutableCoefficients target{b.Fp,b.Fm,b.F0}; s=outputs(target); if (!s) return s;
    for (auto x : {a.coefficients.Ap,a.coefficients.Am,a.coefficients.A0}) for (auto y : {b.Fp,b.Fm,b.F0}) { s=disjoint(x.data,S_*sizeof(WVComplex64),y.data,S_*sizeof(WVComplex64)); if (!s) return s; }
    const auto validateBundle = [&](const double* data,WVShape4D shape,std::size_t count) {
        if (shape.first!=geometry().Nx || shape.second!=geometry().Ny ||
            shape.third!=geometry().Nz || shape.fourth!=count)
            return WVKernelStatus{WVKernelStatusCode::invalidShape,"Forcing field bundle shape mismatch."};
        for (std::size_t channel=0;channel<count;++channel) {
            auto status=volume({data ? data+channel*R_ : nullptr,spatialShape()});
            if (!status) return status;
        }
        return WVKernelStatus::ok();
    };
    if (preparedFields) {
        s=validateBundle(preparedFields->data,preparedFields->shape,4); if (!s) return s;
        for (auto output:{b.Fp,b.Fm,b.F0}) {
            s=disjoint(preparedFields->data,4*R_*sizeof(double),output.data,S_*sizeof(WVComplex64)); if (!s) return s;
        }
    }
    if (spatialTendency) {
        s=validateBundle(spatialTendency->data,spatialTendency->shape,3); if (!s) return s;
        for (auto input:{a.coefficients.Ap,a.coefficients.Am,a.coefficients.A0}) {
            s=disjoint(spatialTendency->data,3*R_*sizeof(double),input.data,S_*sizeof(WVComplex64)); if (!s) return s;
        }
        for (auto output:{b.Fp,b.Fm,b.F0}) {
            s=disjoint(spatialTendency->data,3*R_*sizeof(double),output.data,S_*sizeof(WVComplex64)); if (!s) return s;
        }
        if (preparedFields) {
            s=disjoint(spatialTendency->data,3*R_*sizeof(double),preparedFields->data,4*R_*sizeof(double)); if (!s) return s;
        }
    }
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    s=preparePhase(a.t,a.t0); if (!s) return s;
    const WVHydrostaticField fields[]={WVHydrostaticField::u,WVHydrostaticField::v,WVHydrostaticField::w,WVHydrostaticField::eta};
    if (preparedFields) std::copy_n(preparedFields->data,4*R_,real_.data());
    else for (std::size_t i=0;i<4;++i) { s=reconstruct(a.coefficients,fields[i],WVHydrostaticDerivative::value,WVHydrostaticComponent::all,real_.data()+i*R_); if (!s) return s; }
    for (std::size_t targetIndex=0;targetIndex<3;++targetIndex) {
        const auto field=fields[targetIndex==2 ? 3 : targetIndex]; auto* flux=real_.data()+(4+targetIndex)*R_;
        std::fill_n(flux,R_,0);
        for (std::size_t axis=0;axis<3;++axis) {
            s=reconstruct(a.coefficients,field,static_cast<WVHydrostaticDerivative>(axis+1),WVHydrostaticComponent::all,real_.data()+7*R_); if (!s) return s;
            for (std::size_t i=0;i<R_;++i) {
                const double correction=targetIndex==2 && axis==2 ? real_[3*R_+i]*geometry().dLnN2[i/(R_/geometry().Nz)] : 0;
                flux[i]-=real_[axis*R_+i]*(real_[7*R_+i]+correction);
            }
        }
    }
    if (spatialTendency) std::copy_n(real_.data()+4*R_,3*R_,spatialTendency->data);
    if (!projectFlux) return WVKernelStatus::ok();
    return projectFields(real_.data()+4*R_,real_.data()+5*R_,real_.data()+6*R_,target);
}
WVKernelStatus WVTransformHydrostaticKernel::totalEnergy(const WVCoefficients& a,double& value,WVHydrostaticComponent component) const {
    if (!valid(component)) return unsupported();
    auto s=coefficients(a); if (!s) return s;
    const auto norm=[](WVComplex64 x) { return x.real*x.real+x.imag*x.imag; }; double sum=0;
    for (std::size_t i=0;i<S_;++i) {
        if (selected(factors_[i],component,true)) sum+=factors_[i].waveEnergy*(norm(a.Ap.data[i])+norm(a.Am.data[i]));
        if (selected(factors_[i],component,false)) sum+=factors_[i].balancedEnergy*norm(a.A0.data[i]);
    }
    if (!std::isfinite(sum)) return {WVKernelStatusCode::numericalFailure,"Hydrostatic energy overflow."};
    value=sum; return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::totalEnstrophy(const WVCoefficients& a,double& value) const {
    auto s=coefficients(a); if (!s) return s; double sum=0;
    for (std::size_t i=0;i<S_;++i) sum+=factors_[i].enstrophy*(a.A0.data[i].real*a.A0.data[i].real+a.A0.data[i].imag*a.A0.data[i].imag);
    if (!std::isfinite(sum)) return {WVKernelStatusCode::numericalFailure,"Hydrostatic enstrophy overflow."};
    value=sum; return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::totalEnergySpatiallyIntegrated(const WVState& a,double& value,WVHydrostaticComponent component) {
    if (!valid(component)) return unsupported();
    auto s=state(a); if (!s) return s;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    s=preparePhase(a.t,a.t0); if (!s) return s;
    const WVHydrostaticField fields[]={WVHydrostaticField::u,WVHydrostaticField::v,WVHydrostaticField::eta};
    for (std::size_t i=0;i<3;++i) { s=reconstruct(a.coefficients,fields[i],WVHydrostaticDerivative::value,component,real_.data()+i*R_); if (!s) return s; }
    double sum=0; const auto plane=R_/geometry().Nz;
    for (std::size_t i=0;i<R_;++i) sum+=geometry().z_int[i/plane]*(real_[i]*real_[i]+real_[R_+i]*real_[R_+i]+geometry().N2[i/plane]*real_[2*R_+i]*real_[2*R_+i])/(2*plane);
    if (!std::isfinite(sum)) return {WVKernelStatusCode::numericalFailure,"Hydrostatic spatial energy overflow."};
    value=sum; return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::verticalCalculus(const double* values,WVHydrostaticFamily family,unsigned order,bool integral,double* result) {
    const auto& g=geometry(); const auto plane=R_/g.Nz;
    // Hydrostatic F/G matrices are independent of horizontal mode. Batch full
    // physical columns through the same prepared matrices without a Fourier cut.
    for (std::size_t begin=0;begin<plane;begin+=g.Nkl) {
        auto* a=gridSpectral_.data(); auto* b=a+H_; const auto count=std::min(g.Nkl,plane-begin);
        std::fill_n(a,H_,WVComplex64{});
        for (std::size_t column=0;column<count;++column) for (std::size_t z=0;z<g.Nz;++z) {
            double x=values[begin+column+plane*z];
            if (integral && family==WVHydrostaticFamily::G) x/=g.N2[z];
            a[z+g.Nz*column]={x,0};
        }
        // 0: DzF, 1: DzG, 2: DzzG, 3: IntF, 4: IntG after N2 division.
        const auto apply=[&](unsigned operation) -> WVKernelStatus {
            auto s=vertical(operation==0 || operation==3 ? 1 : 3,a,modal_.data()); if (!s) return s;
            for (std::size_t i=0;i<S_;++i) {
                if (operation==1 || operation==2) modal_[i]=scale(modal_[i],1/g.h_0[i%g.Nj]);
                if (operation==3) modal_[i]=scale(modal_[i],g.h_0[i%g.Nj]);
            }
            s=vertical(operation==1 || operation==4 ? 0 : 2,modal_.data(),b); if (!s) return s;
            for (std::size_t column=0;column<g.Nkl;++column) {
                const auto bottom=b[g.Nz*column];
                for (std::size_t z=0;z<g.Nz;++z) {
                    auto& x=b[z+g.Nz*column];
                    if (operation==0 || operation==2) x=scale(x,-g.N2[z]/g.g);
                    if (operation==4) x=scale(subtract(x,bottom),-g.g);
                }
            }
            std::swap(a,b); return WVKernelStatus::ok();
        };
        WVKernelStatus s;
        if (integral) s=apply(family==WVHydrostaticFamily::F ? 3 : 4);
        else if (family==WVHydrostaticFamily::F) {
            s=apply(0); if (!s) return s;
            if (order>=3) { s=apply(2); if (!s) return s; }
            if (order==2 || order==4) s=apply(1);
        } else {
            if (order==1) s=apply(1);
            else { s=apply(2); if (!s) return s; if (order==3) s=apply(1); if (order==4) s=apply(2); }
        }
        if (!s) return s;
        for (std::size_t column=0;column<count;++column) for (std::size_t z=0;z<g.Nz;++z) result[begin+column+plane*z]=a[z+g.Nz*column].real;
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformHydrostaticKernel::differentiateVertical(WVRealVolumeConstView a,WVHydrostaticFamily family,unsigned order,WVRealVolumeView b) {
    if (!valid(family) || order<1 || order>4) return unsupported();
    auto s=volume(a); if (!s) return s; s=volume({b.data,b.shape}); if (!s) return s;
    s=disjoint(a.data,R_*sizeof(double),b.data,R_*sizeof(double)); if (!s) return s;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    return verticalCalculus(a.data,family,order,false,b.data);
}
WVKernelStatus WVTransformHydrostaticKernel::integrateVertical(WVRealVolumeConstView a,WVHydrostaticFamily family,WVRealVolumeView b) {
    if (!valid(family)) return unsupported();
    auto s=volume(a); if (!s) return s; s=volume({b.data,b.shape}); if (!s) return s;
    s=disjoint(a.data,R_*sizeof(double),b.data,R_*sizeof(double)); if (!s) return s;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    return verticalCalculus(a.data,family,1,true,b.data);
}
WVKernelStatus WVTransformHydrostaticKernel::differentiateHorizontal(WVRealVolumeConstView a,bool xDerivative,WVRealVolumeView b) {
    auto s=volume(a); if (!s) return s; s=volume({b.data,b.shape}); if (!s) return s;
    s=disjoint(a.data,R_*sizeof(double),b.data,R_*sizeof(double)); if (!s) return s;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    return horizontal_->spatialDerivative(*horizontalWorkspace_,{a.data,R_*sizeof(double)},{b.data,R_*sizeof(double)},xDerivative);
}
WVKernelStatus WVTransformHydrostaticKernel::advectScalarWithAdvectionFields(WVRealVolumeConstView a,WVRealFieldBundleConstView fields,bool antialias,WVRealVolumeView b,bool xyOnly) {
    auto s=volume(a); if (!s) return s; s=volume({b.data,b.shape}); if (!s) return s;
    const auto& g=geometry();
    if (fields.shape.first!=g.Nx || fields.shape.second!=g.Ny || fields.shape.third!=g.Nz || fields.shape.fourth!=3)
        return {WVKernelStatusCode::invalidShape,"Hydrostatic advection requires [Nx,Ny,Nz,3] velocity fields."};
    if (!addressFits(fields.data,3*R_*sizeof(double),alignof(double))) return {WVKernelStatusCode::invalidPointer,"Invalid advection field storage."};
    s=disjoint(a.data,R_*sizeof(double),b.data,R_*sizeof(double)); if (!s) return s;
    s=disjoint(fields.data,3*R_*sizeof(double),b.data,R_*sizeof(double)); if (!s) return s;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    s=horizontal_->spatialDerivative(*horizontalWorkspace_,{a.data,R_*sizeof(double)},{real_.data(),R_*sizeof(double)},true); if (!s) return s;
    s=horizontal_->spatialDerivative(*horizontalWorkspace_,{a.data,R_*sizeof(double)},{real_.data()+R_,R_*sizeof(double)},false); if (!s) return s;
    if (!xyOnly) { s=verticalCalculus(a.data,WVHydrostaticFamily::F,1,false,real_.data()+2*R_); if (!s) return s; }
    for (std::size_t i=0;i<R_;++i) b.data[i]=-fields.data[i]*real_[i]-fields.data[R_+i]*real_[R_+i]-(xyOnly ? 0.0 : fields.data[2*R_+i]*real_[2*R_+i]);
    if (antialias) {
        s=horizontal_->forward(*horizontalWorkspace_,{b.data,R_*sizeof(double)},output(gridSpectral_.data(),H_)); if (!s) return s;
        s=horizontal_->inverse(*horizontalWorkspace_,input(gridSpectral_.data(),H_),{b.data,R_*sizeof(double)});
    }
    return s;
}
} // namespace wavevortex
