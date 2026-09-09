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
    WVFieldEvaluationPlan rejected;
    require(!service->createPlan({{"public",name,{}}},rejected),"public density output promoted before qualification");
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
  Outputs failed(initialOnly);
  require(!service->evaluate(initialOnly,state,failed.views.data(),failed.views.size()) && failed.untouched(),"failed inversion published partial outputs");
  require(service->metrics().densityWorkspaceLiveBytes==0,"failed invocation leaked density state");
}
}
int main() {
  try {
    for(bool hydro:{false,true}) for(bool antialias:{false,true}) verifyConfiguration(hydro,antialias);
    std::cout<<"Density field integration tests passed\n";
    return 0;
  } catch(const std::exception& e) {
    std::cerr<<e.what()<<'\n';
    return 1;
  }
}
