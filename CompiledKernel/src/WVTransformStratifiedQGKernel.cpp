#include "WaveVortexKernel/WVTransformStratifiedQGKernel.hpp"
#include "WVSpectralValidation.hpp"
#include <algorithm>
#include <cmath>

namespace wavevortex {
namespace {
using namespace spectral_detail;
constexpr double pi = 3.1415926535897932384626433832795;
WVComplex64 scale(WVComplex64 a,double b) { return {a.real*b,a.imag*b}; }
WVComplex64 multiply(WVComplex64 a,WVComplex64 b) { return {a.real*b.real-a.imag*b.imag,a.real*b.imag+a.imag*b.real}; }
WVComplexInput input(const WVComplex64* p,std::size_t n) { return {p,nullptr,nullptr,n*sizeof(WVComplex64)}; }
WVComplexOutput output(WVComplex64* p,std::size_t n) { return {p,nullptr,nullptr,n*sizeof(WVComplex64)}; }
bool surface(WVStratifiedQGField f) { return f==WVStratifiedQGField::ssh || f==WVStratifiedQGField::ssu || f==WVStratifiedQGField::ssv; }
bool fieldValid(WVStratifiedQGField f) { return f>=WVStratifiedQGField::u && f<=WVStratifiedQGField::ssv; }
bool derivativeValid(WVStratifiedQGDerivative d) { return d>=WVStratifiedQGDerivative::value && d<=WVStratifiedQGDerivative::z; }
WVKernelStatus reentrant() { return {WVKernelStatusCode::reentrantExecution,"Stratified QG workspace is already active."}; }
}
WVKernelStatus WVTransformStratifiedQGKernel::create(std::shared_ptr<const WVStratifiedModalSource> source,
    std::unique_ptr<WVFFTEngine> engine,std::unique_ptr<WVTransformStratifiedQGKernel>& result,MatrixBackendFactory factory) {
    try {
        if (!source || !engine || !factory) return {WVKernelStatusCode::invalidConfiguration,"Scientific source, FFT engine and matrix backend factory are required."};
        const auto& g=source->geometry();
        if (g.transformClass!="WVTransformStratifiedQG" || g.Nx<2 || g.Ny<2 || g.Nz<3 || !g.Nj || g.Nj>=g.Nz || !g.Nkl ||
            g.j.size()!=g.Nj || g.h_0.size()!=g.Nj || g.k.size()!=g.Nkl || g.l.size()!=g.Nkl || g.modes.size()!=g.Nkl ||
            g.z.size()!=g.Nz || g.N2.size()!=g.Nz || g.rho_nm0.size()!=g.Nz || g.dLnN2.size()!=g.Nz || g.z_int.size()!=g.Nz ||
            source->sourceIdentity().empty() || source->modeSetIdentity().empty())
            return {WVKernelStatusCode::invalidConfiguration,"Invalid Stratified QG scientific source."};
        auto candidate=std::unique_ptr<WVTransformStratifiedQGKernel>(new WVTransformStratifiedQGKernel);
        candidate->source_=std::move(source);
        auto& c=*candidate;
        c.S_=product(g.Nj,g.Nkl); c.H_=product(g.Nz,g.Nkl); c.R_=product(product(g.Nx,g.Ny),g.Nz);
        product(c.S_,sizeof(WVComplex64)); product(c.H_,sizeof(WVComplex64)); product(product(4,c.R_),sizeof(double));
        c.engineIdentifier_=engine->identifier(); c.engineLibraryIdentity_=engine->libraryIdentity();
        WVRetainedHorizontalSpecification horizontal;
        auto status=c.source_->horizontalSpecification(g.Nz,WVComplexRepresentation::interleaved,"QG-grid",horizontal);
        if (!status) return status;
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
        auto& f=c.factors_; f.f=2*g.rotationRate*std::sin(g.latitude*pi/180); f.beta=2*g.rotationRate*std::cos(g.latitude*pi/180)/g.planetaryRadius;
        if (!std::isfinite(f.f) || !std::isfinite(f.beta) || f.f==0 || !(g.g>0) || !(g.Lz>0) || !(g.rho0>0))
            return {WVKernelStatusCode::invalidConfiguration,"Invalid QG physical constants."};
        f.u.resize(c.S_); f.v.resize(c.S_);
        for (auto* v : {&f.eta,&f.pi,&f.psi,&f.qgpv,&f.zetaZ,&f.energy,&f.enstrophy,&f.kineticEnergy,&f.potentialEnergy}) v->resize(c.S_);
        for (std::size_t mode=0;mode<g.Nkl;++mode) for (std::size_t j=0;j<g.Nj;++j) {
            const auto i=j+g.Nj*mode; const double k=g.k[mode], l=g.l[mode], k2=k*k+l*l;
            if (!std::isfinite(k2) || !(g.h_0[j]>0) || !std::isfinite(g.h_0[j])) return {WVKernelStatusCode::invalidConfiguration,"Invalid QG mode or equivalent depth."};
            if (k2==0) continue; // MATLAB's geostrophic mask excludes every horizontal mean.
            const bool barotropic=g.j[j]==0; const double h=barotropic ? g.Lz : g.h_0[j];
            const double denominator=k2+(barotropic ? 0 : f.f*f.f/(g.g*h));
            f.u[i]={0,l/denominator}; f.v[i]={0,-k/denominator};
            f.psi[i]=-1/denominator; f.pi[i]=(f.f/g.g)*f.psi[i]; f.eta[i]=barotropic ? 0 : f.pi[i];
            f.qgpv[i]=1; f.zetaZ[i]=k2/denominator;
            f.kineticEnergy[i]=h*k2/(denominator*denominator);
            f.potentialEnergy[i]=barotropic ? 0 : (f.f*f.f/g.g)/(denominator*denominator);
            f.energy[i]=f.kineticEnergy[i]+f.potentialEnergy[i]; f.enstrophy[i]=h;
        }
        for (const auto* v : {&f.eta,&f.pi,&f.psi,&f.qgpv,&f.zetaZ,&f.energy,&f.enstrophy,&f.kineticEnergy,&f.potentialEnergy})
            for (double x:*v) if (!std::isfinite(x)) return {WVKernelStatusCode::numericalFailure,"QG coefficient factor overflow."};
        c.modal_.resize(c.S_); c.auxiliary_.resize(c.S_); c.gridSpectral_.resize(c.H_); c.real_.resize(4*c.R_);
        auto& s=c.storage_; s.sharedScientificBytes=c.source_->persistentBytes(); s.preparedBytes=c.horizontal_->persistentBytes();
        s.workspaceBytes=c.horizontalWorkspace_->persistentBytes(); s.providerBytesLowerBound=c.horizontal_->providerBytesLowerBound(); s.planBytesLowerBound=c.horizontalWorkspace_->planBytesLowerBound();
        for (std::size_t i=0;i<4;++i) { s.preparedBytes+=c.vertical_[i]->persistentBytes(); s.workspaceBytes+=c.verticalWorkspace_[i]->persistentBytes(); }
        s.spectralScratchBytes=(c.modal_.capacity()+c.auxiliary_.capacity()+c.gridSpectral_.capacity())*sizeof(WVComplex64);
        s.realScratchBytes=c.real_.capacity()*sizeof(double); s.factorBytes=(f.u.capacity()+f.v.capacity())*sizeof(WVComplex64);
        for (const auto* v : {&f.eta,&f.pi,&f.psi,&f.qgpv,&f.zetaZ,&f.energy,&f.enstrophy,&f.kineticEnergy,&f.potentialEnergy}) s.factorBytes+=v->capacity()*sizeof(double);
        result=std::move(candidate); return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"QG setup allocation failed."}; }
      catch (const std::overflow_error& e) { return {WVKernelStatusCode::sizeOverflow,e.what()}; }
}
WVKernelStatus WVTransformStratifiedQGKernel::spectral(WVComplexConstView a) const {
    if (a.shape.rows!=geometry().Nj || a.shape.columns!=geometry().Nkl) return {WVKernelStatusCode::invalidShape,"Expected canonical [Nj,Nkl] coefficients."};
    if (!addressFits(a.data,S_*sizeof(WVComplex64),alignof(WVComplex64))) return {WVKernelStatusCode::invalidPointer,"Invalid coefficient storage."};
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::volume(WVRealVolumeConstView a,bool isSurface) const {
    const auto& g=geometry(); const auto nz=isSurface ? 1 : g.Nz;
    if (a.shape.first!=g.Nx || a.shape.second!=g.Ny || a.shape.third!=nz) return {WVKernelStatusCode::invalidShape,"Unexpected QG field shape."};
    if (!addressFits(a.data,(R_/g.Nz)*nz*sizeof(double),alignof(double))) return {WVKernelStatusCode::invalidPointer,"Invalid field storage."};
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::disjoint(const void* a,std::size_t an,const void* b,std::size_t bn) const {
    if (overlap(a,an,b,bn)) return {WVKernelStatusCode::overlappingArrays,"QG input and output must not overlap."};
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::validateDiagnosticBuffers(
    WVComplexConstView a,WVComplexView b,const WVRealVolumeView* raw,const WVRealFieldBundleConstView* uv) const {
    if (raw) {
        auto status=volume({raw->data,raw->shape}); if (!status) return status;
        status=disjoint(a.data,S_*sizeof(WVComplex64),raw->data,R_*sizeof(double)); if (!status) return status;
        status=disjoint(b.data,S_*sizeof(WVComplex64),raw->data,R_*sizeof(double)); if (!status) return status;
    }
    if (uv) {
        const auto& g=geometry();
        if (uv->shape.first!=g.Nx || uv->shape.second!=g.Ny || uv->shape.third!=g.Nz || uv->shape.fourth!=2)
            return {WVKernelStatusCode::invalidShape,"Prepared QG velocity must have two full-grid channels."};
        if (!addressFits(uv->data,2*R_*sizeof(double),alignof(double)))
            return {WVKernelStatusCode::invalidPointer,"Invalid prepared QG velocity storage."};
        auto status=disjoint(uv->data,2*R_*sizeof(double),b.data,S_*sizeof(WVComplex64)); if (!status) return status;
        if (raw) { status=disjoint(uv->data,2*R_*sizeof(double),raw->data,R_*sizeof(double)); if (!status) return status; }
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::transformSpectralTendencyToSpatial(WVComplexConstView a,WVRealVolumeView b) {
    auto status=spectral(a); if (!status) return status; status=volume({b.data,b.shape}); if (!status) return status;
    status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,R_*sizeof(double)); if (!status) return status;
    for (std::size_t i=0;i<S_;++i) if (!std::isfinite(a.data[i].real) || !std::isfinite(a.data[i].imag))
        return {WVKernelStatusCode::invalidConfiguration,"Diagnostic tendency must be finite."};
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    status=vertical(0,a.data,gridSpectral_.data()); if (!status) return status;
    const auto& g=geometry();
    for (std::size_t mode=0;mode<g.Nkl;++mode) if (g.k[mode]==0 && g.l[mode]==0)
        for (std::size_t z=0;z<g.Nz;++z) gridSpectral_[z+g.Nz*mode].imag=0;
    return horizontal_->inverse(*horizontalWorkspace_,input(gridSpectral_.data(),H_),{b.data,R_*sizeof(double)});
}
WVKernelStatus WVTransformStratifiedQGKernel::vertical(std::size_t operation,const WVComplex64* a,WVComplex64* b) {
    return vertical_[operation]->execute(*verticalWorkspace_[operation],input(a,operation%2 ? H_ : S_),output(b,operation%2 ? S_ : H_));
}
WVKernelStatus WVTransformStratifiedQGKernel::project(const double* a,WVComplex64* b,std::size_t operation) {
    auto status=horizontal_->forward(*horizontalWorkspace_,{a,R_*sizeof(double)},output(gridSpectral_.data(),H_)); if (!status) return status;
    return vertical(operation,gridSpectral_.data(),b);
}
WVKernelStatus WVTransformStratifiedQGKernel::transformQGPVToA0(WVRealVolumeConstView a,WVComplexView b) {
    auto status=volume(a); if (!status) return status; status=spectral({b.data,b.shape}); if (!status) return status;
    status=disjoint(a.data,R_*sizeof(double),b.data,S_*sizeof(WVComplex64)); if (!status) return status;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    return project(a.data,b.data);
}
WVKernelStatus WVTransformStratifiedQGKernel::reconstruct(WVComplexConstView a,WVStratifiedQGField field,WVStratifiedQGDerivative derivative,double* b) {
    const auto& g=geometry(); const bool density=field==WVStratifiedQGField::rhoE || field==WVStratifiedQGField::rhoTotal;
    const bool totalDensity=field==WVStratifiedQGField::rhoTotal;
    if (density) field=WVStratifiedQGField::eta;
    if (field==WVStratifiedQGField::ssh) field=WVStratifiedQGField::pi;
    if (field==WVStratifiedQGField::ssu) field=WVStratifiedQGField::u;
    if (field==WVStratifiedQGField::ssv) field=WVStratifiedQGField::v;
    if (field==WVStratifiedQGField::w) { std::fill_n(b,R_,0); return WVKernelStatus::ok(); }
    const bool gFamily=field==WVStratifiedQGField::eta, dz=derivative==WVStratifiedQGDerivative::z;
    for (std::size_t mode=0;mode<g.Nkl;++mode) for (std::size_t j=0;j<g.Nj;++j) {
        const auto i=j+g.Nj*mode; WVComplex64 factor{};
        switch(field) {
            case WVStratifiedQGField::u: factor=factors_.u[i]; break;
            case WVStratifiedQGField::v: factor=factors_.v[i]; break;
            case WVStratifiedQGField::eta: factor.real=factors_.eta[i]; break;
            case WVStratifiedQGField::pi: factor.real=factors_.pi[i]; break;
            case WVStratifiedQGField::p: factor.real=g.rho0*g.g*factors_.pi[i]; break;
            case WVStratifiedQGField::psi: factor.real=factors_.psi[i]; break;
            case WVStratifiedQGField::qgpv: factor.real=factors_.qgpv[i]; break;
            case WVStratifiedQGField::zetaZ: factor.real=factors_.zetaZ[i]; break;
            default: return {WVKernelStatusCode::unsupportedOperation,"Unknown QG field."};
        }
        if (derivative==WVStratifiedQGDerivative::x) factor=multiply(factor,{0,g.k[mode]});
        if (derivative==WVStratifiedQGDerivative::y) factor=multiply(factor,{0,g.l[mode]});
        if (dz && gFamily) factor=scale(factor,g.j[j]==0 ? 0 : 1/g.h_0[j]);
        modal_[i]=multiply(a.data[i],factor);
    }
    auto status=vertical((gFamily!=dz) ? 2 : 0,modal_.data(),gridSpectral_.data()); if (!status) return status;
    if (dz && !gFamily) for (std::size_t mode=0;mode<g.Nkl;++mode) for (std::size_t z=0;z<g.Nz;++z)
        gridSpectral_[z+g.Nz*mode]=scale(gridSpectral_[z+g.Nz*mode],-g.N2[z]/g.g);
    status=horizontal_->inverse(*horizontalWorkspace_,input(gridSpectral_.data(),H_),{b,R_*sizeof(double)}); if (!status) return status;
    if (density) {
        const double* eta=nullptr;
        if (dz) { status=reconstruct(a,WVStratifiedQGField::eta,WVStratifiedQGDerivative::value,real_.data()+2*R_); if (!status) return status; eta=real_.data()+2*R_; }
        const auto plane=R_/g.Nz;
        for (std::size_t z=0;z<g.Nz;++z) for (std::size_t xy=0;xy<plane;++xy) {
            const auto i=xy+plane*z;
            b[i]=(g.rho0/g.g)*g.N2[z]*(b[i]+(dz ? g.dLnN2[z]*eta[i] : 0));
            if (totalDensity && derivative==WVStratifiedQGDerivative::value) b[i]+=g.rho_nm0[z];
            if (totalDensity && dz) b[i]-=(g.rho0/g.g)*g.N2[z];
        }
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::transformA0ToField(WVComplexConstView a,WVStratifiedQGField field,WVRealVolumeView b,WVStratifiedQGDerivative derivative) {
    if (!fieldValid(field) || !derivativeValid(derivative)) return {WVKernelStatusCode::unsupportedOperation,"Unknown QG field or derivative."};
    auto status=spectral(a); if (!status) return status; status=volume({b.data,b.shape},surface(field)); if (!status) return status;
    status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,(surface(field) ? R_/geometry().Nz : R_)*sizeof(double)); if (!status) return status;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    status=reconstruct(a,field,derivative,surface(field) ? real_.data() : b.data); if (!status) return status;
    if (surface(field)) { const auto plane=R_/geometry().Nz; std::copy_n(real_.data()+R_-plane,plane,b.data); }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::transformUVEtaToA0(WVRealVolumeConstView u,WVRealVolumeConstView v,WVRealVolumeConstView eta,WVComplexView b) {
    auto status=spectral({b.data,b.shape}); if (!status) return status;
    for (const auto& a : {u,v,eta}) { status=volume(a); if (!status) return status; status=disjoint(a.data,R_*sizeof(double),b.data,S_*sizeof(WVComplex64)); if (!status) return status; }
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    status=project(u.data,auxiliary_.data()); if (!status) return status;
    for (std::size_t mode=0;mode<geometry().Nkl;++mode) for (std::size_t j=0;j<geometry().Nj;++j) { auto i=j+geometry().Nj*mode; auxiliary_[i]=multiply(auxiliary_[i],{0,-geometry().l[mode]}); }
    status=project(v.data,modal_.data()); if (!status) return status;
    for (std::size_t mode=0;mode<geometry().Nkl;++mode) for (std::size_t j=0;j<geometry().Nj;++j) { auto i=j+geometry().Nj*mode; const auto x=multiply(modal_[i],{0,geometry().k[mode]}); auxiliary_[i].real+=x.real; auxiliary_[i].imag+=x.imag; }
    status=project(eta.data,modal_.data(),3); if (!status) return status;
    for (std::size_t i=0;i<S_;++i) { const auto j=i%geometry().Nj; const double n=geometry().j[j]==0 ? 0 : -factors_.f/geometry().h_0[j]; b.data[i]=scale({auxiliary_[i].real+n*modal_[i].real,auxiliary_[i].imag+n*modal_[i].imag},factors_.qgpv[i]); }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::nonlinearFlux(WVComplexConstView a,WVComplexView b,double beta,
    WVRealVolumeView* raw,const WVRealFieldBundleConstView* preparedUV) {
    if (!std::isfinite(beta)) return {WVKernelStatusCode::invalidConfiguration,"Beta must be finite."};
    auto status=spectral(a); if (!status) return status; status=spectral({b.data,b.shape}); if (!status) return status;
    status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,S_*sizeof(WVComplex64)); if (!status) return status;
    status=validateDiagnosticBuffers(a,b,raw,preparedUV); if (!status) return status;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    const WVStratifiedQGField fields[]={WVStratifiedQGField::u,WVStratifiedQGField::v,WVStratifiedQGField::qgpv,WVStratifiedQGField::qgpv};
    const WVStratifiedQGDerivative derivatives[]={WVStratifiedQGDerivative::value,WVStratifiedQGDerivative::value,WVStratifiedQGDerivative::x,WVStratifiedQGDerivative::y};
    if (preparedUV) std::copy_n(preparedUV->data,2*R_,real_.data());
    for (std::size_t f=preparedUV ? 2 : 0;f<4;++f) { status=reconstruct(a,fields[f],derivatives[f],real_.data()+f*R_); if (!status) return status; }
    for (std::size_t i=0;i<R_;++i) real_[3*R_+i]=-(real_[i]*real_[2*R_+i]+real_[R_+i]*(real_[3*R_+i]+beta));
    if (raw) { std::copy_n(real_.data()+3*R_,R_,raw->data); return WVKernelStatus::ok(); }
    return project(real_.data()+3*R_,b.data);
}
WVKernelStatus WVTransformStratifiedQGKernel::verticalDiffusivityFlux(WVComplexConstView a,double kappaZ,WVComplexView b,WVRealVolumeView* raw) {
    if (!std::isfinite(kappaZ) || kappaZ<0) return {WVKernelStatusCode::invalidConfiguration,"Vertical diffusivity must be finite and nonnegative."};
    auto status=spectral(a); if (!status) return status; status=spectral({b.data,b.shape}); if (!status) return status;
    status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,S_*sizeof(WVComplex64)); if (!status) return status;
    status=validateDiagnosticBuffers(a,b,raw); if (!status) return status;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    const auto& g=geometry();
    // MATLAB diffZG(eta,n=3) is DzG*DzzG*eta. Preserve its intermediate
    // projection of N2-weighted grid values, including on truncated bases.
    for (std::size_t i=0;i<S_;++i) modal_[i]=scale(a.data[i],factors_.eta[i]);
    status=vertical(2,modal_.data(),gridSpectral_.data()); if (!status) return status;
    status=vertical(3,gridSpectral_.data(),modal_.data()); if (!status) return status;
    for (std::size_t i=0;i<S_;++i) modal_[i]=scale(modal_[i],1/g.h_0[i%g.Nj]);
    status=vertical(2,modal_.data(),gridSpectral_.data()); if (!status) return status;
    for (std::size_t mode=0;mode<g.Nkl;++mode) for (std::size_t z=0;z<g.Nz;++z)
        gridSpectral_[z+g.Nz*mode]=scale(gridSpectral_[z+g.Nz*mode],-g.N2[z]/g.g);
    status=vertical(3,gridSpectral_.data(),modal_.data()); if (!status) return status;
    for (std::size_t i=0;i<S_;++i) modal_[i]=scale(modal_[i],-factors_.f*kappaZ/g.h_0[i%g.Nj]);
    status=vertical(0,modal_.data(),gridSpectral_.data()); if (!status) return status;
    if (raw) return horizontal_->inverse(*horizontalWorkspace_,input(gridSpectral_.data(),H_),{raw->data,R_*sizeof(double)});
    return vertical(1,gridSpectral_.data(),b.data);
}
WVKernelStatus WVTransformStratifiedQGKernel::linearBottomFrictionFlux(WVComplexConstView a,double rate,WVComplexView b,WVRealVolumeView* raw) {
    if (!std::isfinite(rate) || rate<0) return {WVKernelStatusCode::invalidConfiguration,"Bottom friction must be finite and nonnegative."};
    auto status=spectral(a); if (!status) return status; status=spectral({b.data,b.shape}); if (!status) return status;
    status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,S_*sizeof(WVComplex64)); if (!status) return status;
    status=validateDiagnosticBuffers(a,b,raw); if (!status) return status;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    status=reconstruct(a,WVStratifiedQGField::zetaZ,WVStratifiedQGDerivative::value,real_.data()); if (!status) return status;
    const auto plane=R_/geometry().Nz;
    const double scaled=-rate*geometry().Lz/geometry().z_int.front();
    for (std::size_t i=0;i<plane;++i) real_[i]*=scaled;
    std::fill(real_.begin()+plane,real_.begin()+R_,0);
    if (raw) { std::copy_n(real_.data(),R_,raw->data); return WVKernelStatus::ok(); }
    return project(real_.data(),b.data);
}
WVKernelStatus WVTransformStratifiedQGKernel::quadraticBottomFrictionFlux(WVComplexConstView a,double dragCoefficient,WVComplexView b,
    WVRealVolumeView* raw,const WVRealFieldBundleConstView* preparedUV) {
    if (!std::isfinite(dragCoefficient) || dragCoefficient<0) return {WVKernelStatusCode::invalidConfiguration,"Quadratic drag must be finite and nonnegative."};
    auto status=spectral(a); if (!status) return status; status=spectral({b.data,b.shape}); if (!status) return status;
    status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,S_*sizeof(WVComplex64)); if (!status) return status;
    status=validateDiagnosticBuffers(a,b,raw,preparedUV); if (!status) return status;
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    if (preparedUV) std::copy_n(preparedUV->data,2*R_,real_.data());
    else {
    status=reconstruct(a,WVStratifiedQGField::u,WVStratifiedQGDerivative::value,real_.data()); if (!status) return status;
    status=reconstruct(a,WVStratifiedQGField::v,WVStratifiedQGDerivative::value,real_.data()+R_); if (!status) return status;
    }
    const auto& g=geometry(); const auto plane=R_/g.Nz;
    for (std::size_t i=0;i<plane;++i) {
        const double speed=std::hypot(real_[i],real_[R_+i]);
        real_[i]*=speed; real_[R_+i]*=speed;
    }
    std::fill(real_.begin()+plane,real_.begin()+R_,0);
    std::fill(real_.begin()+R_+plane,real_.begin()+2*R_,0);
    if (raw) {
        // Differentiate full-grid bottom stress before vertical projection;
        // projecting first would lose the raw vertical diagnostic profile.
        status=horizontal_->spatialDerivative(*horizontalWorkspace_,{real_.data()+R_,R_*sizeof(double)},
            {real_.data()+2*R_,R_*sizeof(double)},true); if (!status) return status;
        status=horizontal_->spatialDerivative(*horizontalWorkspace_,{real_.data(),R_*sizeof(double)},
            {real_.data()+3*R_,R_*sizeof(double)},false); if (!status) return status;
        const double scaled=-dragCoefficient/g.z_int.front();
        for (std::size_t i=0;i<R_;++i) raw->data[i]=scaled*(real_[2*R_+i]-real_[3*R_+i]);
        return WVKernelStatus::ok();
    }
    // Horizontal differentiation commutes with F projection. Only the bottom
    // cell carries stress; z_int owns its MATLAB quadrature normalization.
    status=project(real_.data(),auxiliary_.data()); if (!status) return status;
    status=project(real_.data()+R_,modal_.data()); if (!status) return status;
    const double scaled=-dragCoefficient/g.z_int.front();
    for (std::size_t i=0;i<S_;++i) {
        const auto mode=i/g.Nj;
        const auto dx=multiply(modal_[i],{0,g.k[mode]}),dy=multiply(auxiliary_[i],{0,g.l[mode]});
        b.data[i]=scale({dx.real-dy.real,dx.imag-dy.imag},scaled);
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::linearFlux(WVComplexConstView a,WVComplexView b,double beta) const {
    auto status=spectral(a); if (!status) return status; status=spectral({b.data,b.shape}); if (!status) return status;
    if (!std::isfinite(beta)) return {WVKernelStatusCode::invalidConfiguration,"Beta must be finite."};
    if (a.data!=b.data) { status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,S_*sizeof(WVComplex64)); if (!status) return status; }
    for (std::size_t i=0;i<S_;++i) b.data[i]=multiply(a.data[i],scale(factors_.v[i],-beta));
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::evolveA0(WVComplexConstView a,double time,WVComplexView b,double beta) const {
    auto status=spectral(a); if (!status) return status; status=spectral({b.data,b.shape}); if (!status) return status;
    if (!std::isfinite(time) || !std::isfinite(beta)) return {WVKernelStatusCode::invalidConfiguration,"Elapsed time and beta must be finite."};
    if (a.data!=b.data) { status=disjoint(a.data,S_*sizeof(WVComplex64),b.data,S_*sizeof(WVComplex64)); if (!status) return status; }
    for (std::size_t i=0;i<S_;++i) if (!std::isfinite(-beta*factors_.v[i].imag*time)) return {WVKernelStatusCode::numericalFailure,"Linear phase overflow."};
    for (std::size_t i=0;i<S_;++i) { const double angle=-beta*factors_.v[i].imag*time; b.data[i]=multiply(a.data[i],{std::cos(angle),std::sin(angle)}); }
    return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::totalEnergy(WVComplexConstView a,double& energy) const {
    auto status=spectral(a); if (!status) return status; double sum=0;
    for (std::size_t i=0;i<S_;++i) sum+=factors_.energy[i]*(a.data[i].real*a.data[i].real+a.data[i].imag*a.data[i].imag);
    energy=sum; return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::totalEnstrophy(WVComplexConstView a,double& value) const {
    auto status=spectral(a); if (!status) return status; double sum=0;
    for (std::size_t i=0;i<S_;++i) sum+=factors_.enstrophy[i]*(a.data[i].real*a.data[i].real+a.data[i].imag*a.data[i].imag);
    value=sum; return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::totalEnergySpatiallyIntegrated(WVComplexConstView a,double& value) {
    auto status=spectral(a); if (!status) return status; ActiveCall guard(active_); if (!guard.entered) return reentrant();
    const WVStratifiedQGField fields[]={WVStratifiedQGField::u,WVStratifiedQGField::v,WVStratifiedQGField::eta};
    for (std::size_t i=0;i<3;++i) { status=reconstruct(a,fields[i],WVStratifiedQGDerivative::value,real_.data()+i*R_); if (!status) return status; }
    double sum=0; const auto plane=R_/geometry().Nz;
    for (std::size_t i=0;i<R_;++i) { const auto z=i/plane; sum+=geometry().z_int[z]*(real_[i]*real_[i]+real_[R_+i]*real_[R_+i]+geometry().N2[z]*real_[2*R_+i]*real_[2*R_+i]); }
    value=sum/(2*plane); return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::totalEnstrophySpatiallyIntegrated(WVComplexConstView a,double& value) {
    auto status=spectral(a); if (!status) return status; ActiveCall guard(active_); if (!guard.entered) return reentrant();
    status=reconstruct(a,WVStratifiedQGField::qgpv,WVStratifiedQGDerivative::value,real_.data()); if (!status) return status;
    double sum=0; const auto plane=R_/geometry().Nz;
    // Match MATLAB WVGeostrophicMethods.totalEnstrophySpatiallyIntegrated:
    // its diagnostic uses trapezoidal weights on z, not modal quadrature.
    for (std::size_t z=0;z<geometry().Nz;++z) {
        const double weight=((z ? geometry().z[z]-geometry().z[z-1] : 0)+(z+1<geometry().Nz ? geometry().z[z+1]-geometry().z[z] : 0))/2;
        for (std::size_t xy=0;xy<plane;++xy) { const double q=real_[xy+plane*z]; sum+=weight*q*q; }
    }
    value=sum/(2*plane); return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::uvMax(WVComplexConstView a,double& value) {
    auto status=spectral(a); if (!status) return status; ActiveCall guard(active_); if (!guard.entered) return reentrant();
    status=reconstruct(a,WVStratifiedQGField::u,WVStratifiedQGDerivative::value,real_.data()); if (!status) return status;
    status=reconstruct(a,WVStratifiedQGField::v,WVStratifiedQGDerivative::value,real_.data()+R_); if (!status) return status;
    double maximum=0; for (std::size_t i=0;i<R_;++i) maximum=std::max(maximum,std::hypot(real_[i],real_[R_+i])); value=maximum; return WVKernelStatus::ok();
}
WVKernelStatus WVTransformStratifiedQGKernel::advectScalarWithAdvectionFields(WVRealVolumeConstView scalar, WVRealFieldBundleConstView fields, bool antialias, WVRealVolumeView output) {
    auto status = volume(scalar); if (!status) return status;
    status = volume({output.data,output.shape}); if (!status) return status;
    if (!fields.data || fields.shape.first != geometry().Nx || fields.shape.second != geometry().Ny || fields.shape.third != geometry().Nz || fields.shape.fourth != 3)
        return {WVKernelStatusCode::invalidShape,"SQG advection fields must have shape [Nx,Ny,Nz,3]."};
    status = volume({fields.data,spatialShape()}); if (!status) return status;
    for (const auto* input : {scalar.data,fields.data,(fields.data+R_)}) {
        status = disjoint(input,R_*sizeof(double),output.data,R_*sizeof(double)); if (!status) return status;
    }
    ActiveCall guard(active_); if (!guard.entered) return reentrant();
    status = horizontal_->spatialDerivative(*horizontalWorkspace_,{scalar.data,R_*sizeof(double)},{real_.data(),R_*sizeof(double)},true); if (!status) return status;
    status = horizontal_->spatialDerivative(*horizontalWorkspace_,{scalar.data,R_*sizeof(double)},{real_.data()+R_,R_*sizeof(double)},false); if (!status) return status;
    for (std::size_t i = 0; i < R_; ++i) output.data[i] = -fields.data[i]*real_[i]-(fields.data+R_)[i]*real_[R_+i];
    if (antialias) {
        status = horizontal_->forward(*horizontalWorkspace_,{output.data,R_*sizeof(double)},{gridSpectral_.data(),nullptr,nullptr,H_*sizeof(WVComplex64)}); if (!status) return status;
        status = horizontal_->inverse(*horizontalWorkspace_,{gridSpectral_.data(),nullptr,nullptr,H_*sizeof(WVComplex64)},{output.data,R_*sizeof(double)});
    }
    return status;
}
} // namespace wavevortex
