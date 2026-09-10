#include "WVDiagnosticFieldPlan.hpp"
#include "WVFieldEvaluationEventWorkspace.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;
using namespace wavevortex::runtime::detail;

namespace {
void require(bool value,const char* message) {
  if(!value) throw std::runtime_error(message);
}
void close(double actual,double expected,double tolerance,const char* message) {
  require(std::isfinite(actual) && std::abs(actual-expected)<=tolerance,message);
}
struct Outputs {
  std::vector<std::vector<double>> values;
  std::vector<WVFieldOutputView> views;
  explicit Outputs(const WVFieldEvaluationPlan& plan) {
    for(const auto& output:plan.outputs()) values.emplace_back(output.elementCount,-919.0);
    for(auto& value:values) views.push_back({value.data(),value.size()});
  }
  bool untouched() const {
    for(const auto& value:values) for(double x:value) if(x!=-919.0) return false;
    return true;
  }
};
WVFieldEvaluationPlan planFor(WVFieldEvaluationService& service,WVNoMotionReference reference,
    const std::vector<std::string>& names) {
  std::vector<WVFieldRequest> requests;
  for(std::size_t i=0;i<names.size();++i) requests.push_back({"out-"+std::to_string(i),names[i],{}});
  WVFieldEvaluationPlan plan;
  require(bool(WVDiagnosticFieldPlan::createDensityQualification(service,requests,{reference},plan)),"private density plan rejected");
  require(plan.hasDensityDiagnostics(),"ordinary density plan does not request event ownership");
  return plan;
}
std::vector<double> directDerivatives(const std::vector<double>& field,const WVTransformConstantStratificationConfiguration& c) {
  const auto R=c.Nx*c.Ny*c.Nz;
  std::vector<double> result(3*R);
  const double pi=std::acos(-1.0);
  for(std::size_t z=0;z<c.Nz;++z) for(std::size_t y=0;y<c.Ny;++y) for(std::size_t x=0;x<c.Nx;++x) {
    const auto i=x+c.Nx*(y+c.Ny*z);
    for(std::size_t axis=0;axis<2;++axis) {
      const auto n=axis==0 ? c.Nx : c.Ny, position=axis==0 ? x : y;
      const double length=axis==0 ? c.Lx : c.Ly;
      for(std::size_t source=0;source<n;++source) for(std::size_t mode=1;mode<n;++mode) {
        if(n%2==0 && mode==n/2) continue;
        const auto k=mode<(n+1)/2 ? static_cast<long>(mode) : static_cast<long>(mode)-static_cast<long>(n);
        const auto si=axis==0 ? source+c.Nx*(y+c.Ny*z) : x+c.Nx*(source+c.Ny*z);
        const double angle=2*pi*static_cast<double>(k)*(static_cast<double>(position)-static_cast<double>(source))/static_cast<double>(n);
        result[axis*R+i]-=field[si]*2*pi*static_cast<double>(k)/length*std::sin(angle)/static_cast<double>(n);
      }
    }
    for(std::size_t mode=1;mode<c.Nj;++mode) for(std::size_t source=1;source+1<c.Nz;++source)
      result[2*R+i]+=field[x+c.Nx*(y+c.Ny*source)]*2/static_cast<double>(c.Nz-1)*
        std::sin(pi*static_cast<double>(mode*source)/static_cast<double>(c.Nz-1))*pi*static_cast<double>(mode)/c.Lz*
        std::cos(pi*static_cast<double>(mode*z)/static_cast<double>(c.Nz-1));
  }
  return result;
}
void verifyGCalculus() {
  for(bool antialias:{false,true}) {
    WVTransformConstantStratificationConfiguration c;
    c.Nx=8;c.Ny=6;c.Nz=9;c.Nj=4;c.Lx=17;c.Ly=11;c.Lz=3;
    c.N0=.01;c.rho0=1025;c.g=9.81;c.rotationRate=7.2921e-5;c.latitude=33;c.planetaryRadius=6.371e6;
    c.shouldAntialias=antialias;
    std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
    require(bool(WVTransformConstantStratificationKernel::create(c,std::make_unique<WVReferenceFFTEngine>(),kernel)),"G calculus kernel creation failed");
    const auto R=c.Nx*c.Ny*c.Nz; const double pi=std::acos(-1.0);
    std::vector<double> scalar(R),result(3*R,-919);
    for(std::size_t z=0;z<c.Nz;++z) for(std::size_t y=0;y<c.Ny;++y) for(std::size_t x=0;x<c.Nx;++x)
      scalar[x+c.Nx*(y+c.Ny*z)]=(std::sin(6*pi*x/c.Nx)+.3*std::cos(4*pi*y/c.Ny))*(.2+std::sin(2*pi*z/(c.Nz-1)))+
        .7*std::sin(6*pi*z/(c.Nz-1))+.8*std::sin(7*pi*z/(c.Nz-1))+
        .2*std::cos(pi*x)*std::sin(2*pi*y/c.Ny)+.4*std::cos(pi*y)*std::sin(2*pi*x/c.Nx);
    const auto expected=directDerivatives(scalar,c);
    WVRealVolumeConstView input{scalar.data(),{c.Nx,c.Ny,c.Nz}};
    WVRealFieldBundleView output{result.data(),{c.Nx,c.Ny,c.Nz,3}};
    const auto before=kernel->metrics();
    require(bool(kernel->transformGGridScalarDerivatives(input,output)),"G calculus failed");
    for(std::size_t i=0;i<result.size();++i) close(result[i],expected[i],3e-13,"full-grid G calculus differs from direct Fourier/DST oracle");
    require(kernel->metrics().planCount==before.planCount && kernel->metrics().scratchCapacityBytes==before.scratchCapacityBytes,"G calculus allocated retained plans or storage");
    scalar.back()=std::numeric_limits<double>::quiet_NaN();std::fill(result.begin(),result.end(),-919);
    require(!kernel->transformGGridScalarDerivatives(input,output),"G calculus accepted nonfinite scalar");
    for(double value:result) require(value==-919,"failed G calculus published partial result");
  }
}
void verifyConfiguration(bool hydrostatic,bool antialias) {
  WVTransformConstantStratificationConfiguration c;
  c.Nx=c.Ny=4; c.Nz=7; c.Nj=6;
  c.Lx=15000; c.Ly=12000; c.Lz=2; c.N0=.1; c.rho0=1025; c.g=10;
  c.planetaryRadius=6.371e6; c.rotationRate=7.2921e-5; c.latitude=33;
  c.isHydrostatic=hydrostatic; c.shouldAntialias=antialias;
  std::unique_ptr<WVFieldEvaluationService> service;
  require(bool(WVFieldEvaluationService::create(c,std::make_unique<WVReferenceFFTEngine>(),service)),"field service creation failed");
  WVTransformConstantStratificationDescriptor descriptor;
  require(bool(WVTransformConstantStratificationDescriptor::create(c,descriptor)),"descriptor creation failed");
  const auto shape=descriptor.spectralShape();
  std::vector<WVComplex64> Ap(shape.elementCount()),Am(Ap.size()),A0(Ap.size());
  WVIntegrationState state;
  state.waveVortex={37,-3,{{Ap.data(),shape},{Am.data(),shape},{A0.data(),shape}}};
  auto combined=planFor(*service,WVNoMotionReference::actual,{"rho_nm","eta_true","ape"});
  auto rho=planFor(*service,WVNoMotionReference::actual,{"rho_nm"});
  auto eta=planFor(*service,WVNoMotionReference::actual,{"eta_true"});
  auto initial=planFor(*service,WVNoMotionReference::initial,{"ape","rho_nm","eta_true"});
  auto initialOnly=planFor(*service,WVNoMotionReference::initial,{"eta_true","ape"});
  for(const char* name:{"rho_nm","eta_true","ape","apv"}) {
    WVFieldEvaluationPlan publicPlan;
    require(bool(service->createPlan({{"public",name,{}}},publicPlan)),"public density full-grid output unavailable");
    WVFieldSamplingRequest sampling; sampling.kind=WVFieldSamplingKind::positions;
    sampling.x={0};sampling.y={0};sampling.z={-1};
    require(!service->createPlan({{"unsupported",name,sampling}},publicPlan),"density output accepted unsupported point sampling");
    sampling.kind=WVFieldSamplingKind::fixedVerticalProfiles; sampling.x.clear();sampling.y.clear();sampling.z.clear();
    sampling.xIndices={0};sampling.yIndices={0};
    require(!service->createPlan({{"unsupported",name,sampling}},publicPlan),"density output accepted unsupported profile sampling");
  }
  Outputs inactive(combined);
  const std::uint8_t none[]={0,0,0};
  require(bool(service->evaluate(combined,state,inactive.views.data(),inactive.views.size(),none)),"inactive density call failed");
  require(inactive.untouched() && service->metrics().densityWorkspaceHighWaterBytes==0 &&
      service->metrics().densityRecoveryCount==0,"inactive density allocated or evaluated");
  Outputs rest(combined);
  require(bool(service->evaluate(combined,state,rest.views.data(),rest.views.size())),"direct rest evaluation failed");
  const auto& z=descriptor.verticalModes().z;
  const double scale=c.rho0*c.N0*c.N0/c.g;
  for(std::size_t k=0;k<c.Nz;++k) close(rest.values[0][k],c.rho0-scale*z[k],1e-12,"rest profile mismatch");
  for(std::size_t field=1;field<3;++field) for(double x:rest.values[field]) close(x,0,1e-10,"rest displacement or APE nonzero");
  require(service->metrics().densityWorkspaceLiveBytes==0 && service->metrics().eventFieldWorkspaceLiveBytes==0,"direct invocation retained density storage");

  // Horizontal mean displacement changes the profile without changing pointers
  // or time. A new invocation must recover the new stable distribution.
  A0[1].real=.01;
  Outputs changed(combined);
  require(bool(service->evaluate(combined,state,changed.views.data(),changed.views.size())),"changed state density failed");
  require(changed.values[0]!=rest.values[0],"same-pointer mutation reused the previous profile");
  for(std::size_t field=1;field<3;++field) for(double x:changed.values[field]) close(x,0,1e-9,"stable current-profile diagnostic nonzero");
  Outputs approximation(initial);
  require(bool(service->evaluate(initial,state,approximation.views.data(),approximation.views.size())),"mixed initial-reference evaluation failed");
  require(approximation.values[1]==changed.values[0],"initial reference changed meaning of rho_nm");
  bool nonzero=false;
  for(std::size_t k=0;k<c.Nz;++k) {
    const double displacement=(changed.values[0][k]-(c.rho0-scale*z[k]))/scale;
    nonzero|=std::abs(displacement)>1e-8;
    for(std::size_t i=0;i<c.Nx*c.Ny;++i) {
      const auto index=k*c.Nx*c.Ny+i;
      close(approximation.values[2][index],displacement,2e-10,"initial linear displacement mismatch");
      close(approximation.values[0][index],.5*c.N0*c.N0*displacement*displacement,2e-12,"initial linear APE mismatch");
    }
  }
  require(nonzero,"changed profile control was trivial");
  const auto recoveries=service->metrics().densityRecoveryCount;
  Outputs approximationOnly(initialOnly);
  require(bool(service->evaluate(initialOnly,state,approximationOnly.views.data(),approximationOnly.views.size())),"initial-only evaluation failed");
  require(service->metrics().densityRecoveryCount==recoveries,"initial-only request recovered an unrequested profile");

  auto actualAPV=planFor(*service,WVNoMotionReference::actual,{"apv"});
  Outputs actualAvailable(actualAPV);
  require(bool(service->evaluate(actualAPV,state,actualAvailable.views.data(),actualAvailable.views.size())),"actual-reference stable APV failed");
  for(double value:actualAvailable.values[0]) close(value,0,2e-13,"stable actual-reference APV is nonzero");

  // APV uses the selected nonlinear displacement, full-grid horizontal
  // derivatives, retained G vertical calculus, and the existing vorticity fields.
  auto apv=planFor(*service,WVNoMotionReference::initial,{"apv","eta_true","ape"});
  auto apvOnly=planFor(*service,WVNoMotionReference::initial,{"apv"});
  std::size_t horizontal=0;
  for(std::size_t mode=0;mode<descriptor.fourierModes().size();++mode)
    if(descriptor.fourierModes()[mode].Kh>0) {horizontal=mode;break;}
  Ap[horizontal*c.Nj+1]={.0001,.00007};
  Am[horizontal*c.Nj+1]={-.00003,.00005};
  WVFieldEvaluationPlan vorticity;
  require(bool(service->createPlan({{"zx","zeta_x",{}},{"zy","zeta_y",{}},{"zz","zeta_z",{}}},vorticity)),"vorticity plan failed");
  Outputs vort(vorticity),available(apv);
  require(bool(service->evaluate(vorticity,state,vort.views.data(),vort.views.size())),"vorticity evaluation failed");
  require(bool(service->evaluate(apv,state,available.views.data(),available.views.size())),"initial APV failed");
  const auto derivatives=directDerivatives(available.values[1],c);
  const auto R=c.Nx*c.Ny*c.Nz;
  double maxAPV=0;
  for(std::size_t i=0;i<R;++i) {
    const double expected=vort.values[2][i]-vort.values[0][i]*derivatives[i]-vort.values[1][i]*derivatives[R+i]-
      (vort.values[2][i]+descriptor.verticalModes().coriolisFrequency)*derivatives[2*R+i];
    close(available.values[0][i],expected,2e-14,"APV differs from direct derivative/vorticity definition");
    maxAPV=std::max(maxAPV,std::abs(expected));
  }
  require(maxAPV>1e-9,"APV scientific control is trivial");
  WVFieldEvaluationPlan total;
  require(bool(service->createPlan({{"rho","rho_total",{}}},total)),"total density plan failed");
  Outputs totalValues(total);
  require(bool(service->evaluate(total,state,totalValues.views.data(),totalValues.views.size())),"total density evaluation failed");
  for(bool rhoFirst:{false,true}) {
    const std::vector<std::string> names=rhoFirst ? std::vector<std::string>{"rho_total","eta_true","apv"} :
      std::vector<std::string>{"eta_true","apv","rho_total"};
    std::vector<WVFieldRequest> requests;
    for(const auto& name:names) requests.push_back({name,name,{}});
    WVFieldEvaluationPlan mixed;
    require(bool(service->createPlan(requests,mixed,{WVNoMotionReference::initial})),"public mixed density plan failed");
    for(unsigned mask:{7u,1u,2u,4u,6u}) {
      Outputs values(mixed);
      std::uint8_t active[3];for(unsigned index=0;index<3;++index) active[index]=(mask>>index)&1;
      require(bool(service->evaluate(mixed,state,values.views.data(),values.views.size(),active)),"public mixed density evaluation failed");
      for(std::size_t index=0;index<3;++index) {
        if(!active[index]) {for(double value:values.values[index]) require(value==-919,"inactive density output changed");continue;}
        const auto& expected=names[index]=="rho_total" ? totalValues.values[0] : names[index]=="eta_true" ? available.values[1] : available.values[0];
        require(values.values[index]==expected,"public mixed request changed density/APV values");
      }
    }
    // The shared event may bind density before an ordinary rho_total output.
    WVFieldEvaluationEventScope event(*service,state,true,false);
    Outputs first(apvOnly),second(mixed);
    require(bool(service->evaluate(apvOnly,state,first.views.data(),first.views.size())),"public mixed event setup failed");
    require(bool(service->evaluate(mixed,state,second.views.data(),second.views.size())),"public mixed event replay failed");
    for(std::size_t index=0;index<3;++index) {
      const auto& expected=names[index]=="rho_total" ? totalValues.values[0] : names[index]=="eta_true" ? available.values[1] : available.values[0];
      require(second.values[index]==expected,"public mixed event output changed");
    }
  }
  const auto apvBefore=service->metrics();
  {
    WVFieldEvaluationEventScope event(*service,state,true,false);
    Outputs first(apvOnly),second(apv);
    require(bool(service->evaluate(apvOnly,state,first.views.data(),first.views.size())),"APV-only event failed");
    const auto peak=service->metrics().densityWorkspaceHighWaterBytes;
    for(std::size_t repeat=0;repeat<20;++repeat)
      require(bool(service->evaluate(apv,state,second.views.data(),second.views.size())),"APV event replay failed");
    require(first.values[0]==available.values[0] && second.values==available.values,"APV coincident order changed results");
    require(service->metrics().densityAPVPassCount==apvBefore.densityAPVPassCount+1 &&
      service->metrics().densityAPVReuseCount==apvBefore.densityAPVReuseCount+20 &&
      service->metrics().densityInversePassCount==apvBefore.densityInversePassCount+1 &&
      service->metrics().densityRecoveryCount==apvBefore.densityRecoveryCount,"APV repeated scientific stages or recovered initial reference");
    require(service->metrics().densityWorkspaceHighWaterBytes<=peak+R*sizeof(double),"APV replay retained unbounded event storage");
  }
  require(service->metrics().densityWorkspaceLiveBytes==0,"APV event retained storage");
  Ap[horizontal*c.Nj+1]={};Am[horizontal*c.Nj+1]={};

  const auto before=service->metrics();
  {
    WVFieldEvaluationEventScope event(*service,state,true,false);
    require(bool(event.status()),"ordinary coincident scope rejected");
    Outputs first(rho),second(eta),last(combined);
    require(bool(service->evaluate(rho,state,first.views.data(),first.views.size())),"profile-only event failed");
    require(service->metrics().densityInversePassCount==before.densityInversePassCount,"rho_nm-only event inverted parcels");
    require(bool(service->evaluate(eta,state,second.views.data(),second.views.size())),"extended displacement event failed");
    require(bool(service->evaluate(combined,state,last.views.data(),last.views.size())),"combined coincident event failed");
    require(last.values==changed.values && first.values[0]==last.values[0] && second.values[0]==last.values[1],"coincident output order changed results");
    require(service->metrics().densityRecoveryCount==before.densityRecoveryCount+1 &&
        service->metrics().densityProfileConstructionCount==before.densityProfileConstructionCount+1 &&
        service->metrics().densityInversePassCount==before.densityInversePassCount+1 &&
        service->metrics().densityAPEPassCount==before.densityAPEPassCount+1,"coincident event repeated an expensive density stage");
    Outputs wrongReference(initialOnly);
    require(!service->evaluate(initialOnly,state,wrongReference.views.data(),wrongReference.views.size()) && wrongReference.untouched(),"active event accepted a changed reference");
    auto dense=state; dense.waveVortex.t+=.25;
    Outputs wrongTime(combined);
    require(!service->evaluate(combined,dense,wrongTime.views.data(),wrongTime.views.size()) && wrongTime.untouched(),"active event accepted a different dense state");
  }
  require(service->metrics().densityWorkspaceLiveBytes==0 && service->metrics().eventFieldWorkspaceLiveBytes==0,"event retained density storage");

  // All requested outputs remain unchanged when inversion fails late.
  A0[1].real=1e6;
  Outputs failed(apv);
  require(!service->evaluate(apv,state,failed.views.data(),failed.views.size()) && failed.untouched(),"failed inversion published partial outputs");
  require(service->metrics().densityWorkspaceLiveBytes==0,"failed invocation leaked density state");
}
}
int main() {
  try {
    verifyGCalculus();
    for(bool hydro:{false,true}) for(bool antialias:{false,true}) verifyConfiguration(hydro,antialias);
    std::cout<<"Density field integration tests passed\n";
    return 0;
  } catch(const std::exception& e) {
    std::cerr<<e.what()<<'\n';
    return 1;
  }
}
