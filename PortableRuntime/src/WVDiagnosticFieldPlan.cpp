#include "WVDiagnosticFieldPlan.hpp"
#include "WVBarotropicQGFieldEvaluationAdapter.hpp"
#include "WVStratifiedFieldEvaluationAdapter.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <set>

namespace wavevortex::runtime::detail {
namespace {
using Variable = WVPortableVariable;
WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration,std::move(message)};
}
WVKernelStatus unsupported(std::string message) {
  return {WVKernelStatusCode::unsupportedOperation,std::move(message)};
}
bool sameSampling(const WVFieldSamplingRequest& a,const WVFieldSamplingRequest& b) {
  return a.kind==b.kind && a.interpolation==b.interpolation && a.xIndices==b.xIndices &&
      a.yIndices==b.yIndices && a.x==b.x && a.y==b.y && a.z==b.z;
}
std::size_t samplingBit(WVFieldSamplingKind kind) {
  switch(kind) {
    case WVFieldSamplingKind::fullGrid: return portableFullGridSampling;
    case WVFieldSamplingKind::fixedVerticalProfiles: return portableFixedVerticalProfileSampling;
    case WVFieldSamplingKind::positions: return portablePositionSampling;
  }
  return 0;
}
bool overlap(const void* a,std::size_t n,const void* b,std::size_t m) {
  if (!a || !b || !n || !m) return false;
  const auto x=reinterpret_cast<std::uintptr_t>(a),y=reinterpret_cast<std::uintptr_t>(b);
  return x<=y ? y-x<n : x-y<m;
}
}

bool WVDiagnosticFieldPlan::required(const std::vector<WVFieldRequest>& requests,bool stratified) noexcept {
  for(const auto& request:requests) {
    const auto* metadata=findPortableVariable(request.fieldName);
    if(metadata && (metadata->ordinal>=23 || (stratified && metadata->identifier==Variable::rhoBar))) return true;
  }
  return false;
}

WVKernelStatus WVDiagnosticFieldPlan::configure(const WVFieldEvaluationService& service) {
  owner_=&service;
  constant_=service.transform_;
  bool antialias=false;
  if(constant_) {
    const auto& c=constant_->descriptor().configuration();
    spatial_=constant_->descriptor().spatialShape(); spectral_=constant_->descriptor().spectralShape();
    isHydrostatic_=c.isHydrostatic; antialias=c.shouldAntialias; Lz_=c.Lz; constantN2_=c.N0*c.N0;
    configuration_=isHydrostatic_ ? "constant-hydrostatic" : "constant-nonhydrostatic";
  } else if(service.stratified_) {
    modal_=&service.stratified_->configuration();
    hydrostatic_=service.stratified_->hydrostaticKernel_;
    boussinesq_=service.stratified_->boussinesqKernel_;
    isQG_=!hydrostatic_ && !boussinesq_; isHydrostatic_=!boussinesq_;
    spatial_={modal_->Nx,modal_->Ny,modal_->Nz}; spectral_={modal_->Nj,modal_->Nkl};
    Lz_=modal_->Lz; antialias=modal_->shouldAntialias;
    configuration_=isQG_ ? "stratified-qg" : hydrostatic_ ? "hydrostatic" : "boussinesq";
  } else if(service.barotropicQG_) {
    const auto& c=service.barotropicQG_->configuration();
    spatial_={c.Nx,c.Ny,1};
    WVIntegrationStateLayout layout;
    auto status=service.createStateLayout({},layout); if(!status) return status;
    spectral_={1,layout.coefficientElementCount()};
    isBarotropic_=isQG_=true; Lz_=c.h; barotropicG_=c.g; antialias=c.shouldAntialias;
    configuration_="barotropic";
  } else return invalid("Diagnostic evaluation has no resolved transform.");
  configuration_+=antialias ? "-aa1" : "-aa0";
  return WVKernelStatus::ok();
}

WVKernelStatus WVDiagnosticFieldPlan::create(const WVFieldEvaluationService& service,
    const std::vector<WVFieldRequest>& requests,WVFieldEvaluationPlan& result) {
  try {
    auto plan=std::shared_ptr<WVDiagnosticFieldPlan>(new WVDiagnosticFieldPlan);
    auto status=plan->configure(service); if(!status) return status;
    std::set<std::string> identifiers;
    const auto dependency=[&](std::size_t group,std::string name,const WVFieldSamplingRequest& sampling) {
      auto& list=plan->groups_[group].requests;
      for(std::size_t index=0;index<list.size();++index)
        if(list[index].fieldName==name && sameSampling(list[index].sampling,sampling)) return index;
      const auto index=list.size();
      list.push_back({"diagnostic-"+std::to_string(group)+"-"+std::to_string(index),std::move(name),sampling});
      return index;
    };
    for(const auto& request:requests) {
      if(request.identifier.empty() || !identifiers.insert(request.identifier).second)
        return invalid("Diagnostic output identifiers must be nonempty and unique.");
      const auto* m=findPortableVariable(request.fieldName);
      if(!m) return unsupported("Unknown diagnostic: "+request.fieldName);
      const auto* contract=portableVariableContract(m->identifier,plan->configuration_);
      // Mixing legacy and diagnostic fields must preserve configuration applicability.
      if(!contract) return unsupported("Diagnostic is unavailable on this transform: "+request.fieldName);
      if(m->ordinal>=23 && (contract->metadata.samplingMask & (m->naturalRank==WVPortableNaturalRank::coefficient && request.sampling.kind==WVFieldSamplingKind::fullGrid ? static_cast<std::size_t>(portableCoefficientSampling) : samplingBit(request.sampling.kind)))==0)
        return unsupported("Diagnostic sampling contract is unsupported: "+request.fieldName);
      if(m->ordinal>=23) {
        WVPortableVariablePlan resolved;
        WVPortableVariableOptions options; options.source=WVPortableOperationSource::builtIn; options.requireEvaluator=true;
        const auto sampling=m->naturalRank==WVPortableNaturalRank::coefficient ? static_cast<std::size_t>(portableCoefficientSampling) : samplingBit(request.sampling.kind);
        const auto resolution=resolvePortableVariablePlan(request.fieldName,plan->configuration_,static_cast<std::uint8_t>(sampling),options,resolved);
        if(resolution!=WVPortableVariableStatus::supported)
          return unsupported(std::string(contract->configurationRestriction)+": "+request.fieldName);
      }
      Output output; output.variable=m->identifier;
      output.specification.identifier=request.identifier; output.specification.fieldName=request.fieldName;
      output.specification.samplingKind=request.sampling.kind;
      switch(m->identifier) {
        case Variable::A0t: case Variable::Apt: case Variable::Amt:
          output.specification.isComplex=true;
          output.specification.dimensions=plan->isBarotropic_ ? std::vector<std::size_t>{plan->spectral_.columns} :
              std::vector<std::size_t>{plan->spectral_.rows,plan->spectral_.columns};
          output.specification.elementCount=plan->spectral_.elementCount();
          break;
        case Variable::totalEnergySpatiallyIntegrated:
          output.auxiliaries[0]=dependency(0,"u",{});
          output.auxiliaries[1]=dependency(0,"v",{});
          output.auxiliaries[2]=dependency(0,"eta",{});
          if(!plan->isHydrostatic_) output.auxiliaries[3]=dependency(0,"w",{});
          output.specification.elementCount=1;
          break;
        default: {
          if(m->identifier==Variable::rhoBar && plan->modal_) {
            if(request.sampling.kind!=WVFieldSamplingKind::fullGrid) return unsupported("rho_bar requires its full vertical grid.");
            output.verticalMean=true; output.dependency=dependency(0,"rho_total",{}); break;
          }
          std::string base=request.fieldName;
          if(m->identifier==Variable::totalEnergy) base="energy";
          else if(m->identifier==Variable::geostrophicEnergy) {
            base="energy"; output.group=plan->isQG_ ? 0 : 1;
          } else if(m->ordinal>=23) {
            const auto component=contract->component;
            if(component==WVPortableFlowComponent::total)
              return unsupported("No numerical diagnostic implementation: "+request.fieldName);
            output.group=static_cast<std::size_t>(component);
            base=base.substr(0,base.rfind('_'));
          }
          if(request.sampling.kind==WVFieldSamplingKind::fullGrid) {
            if(base=="ssu" || base=="ssv" || base=="ssh") {
              output.surface=true;
              base=base=="ssu" ? "u" : base=="ssv" ? "v" : "pi";
            } else if(base=="uvMax" || base=="wMax") {
              output.extrema=true;
              output.auxiliaries[0]=dependency(0,base=="uvMax" ? "u" : "w",{});
              if(base=="uvMax") output.auxiliaries[1]=dependency(0,"v",{});
              output.specification.elementCount=1;
              break;
            }
          }
          output.dependency=dependency(output.group,base,request.sampling);
          break;
        }
      }
      plan->outputs_.push_back(std::move(output));
    }
    for(auto& group:plan->groups_) {
      if(group.requests.empty()) continue;
      status=service.createPlan(group.requests,group.fields); if(!status) return status;
    }
    WVFieldEvaluationPlan candidate;
    for(auto& output:plan->outputs_) {
      if(!output.specification.isComplex && !output.extrema && output.variable!=Variable::totalEnergySpatiallyIntegrated) {
        const auto& primitive=plan->groups_[output.group].fields.outputs()[output.dependency];
        output.specification.dimensions=primitive.dimensions;
        output.specification.elementCount=primitive.elementCount;
        if(output.verticalMean) {
          output.specification.dimensions={plan->spatial_.third};
          output.specification.elementCount=plan->spatial_.third;
        }
        if(output.surface) {
          output.specification.dimensions={plan->spatial_.first,plan->spatial_.second};
          output.specification.elementCount=plan->spatial_.first*plan->spatial_.second;
        }
      }
      candidate.outputs_.push_back(output.specification);
    }
    candidate.diagnosticPlan_=std::move(plan);
    result=std::move(candidate);
    return WVKernelStatus::ok();
  } catch(const std::bad_alloc&) {
    return {WVKernelStatusCode::allocationFailure,"Unable to allocate the diagnostic dependency plan."};
  }
}

WVKernelStatus WVDiagnosticFieldPlan::rebind(const WVFieldEvaluationService& service,WVFieldEvaluationPlan& result) const {
  try {
    std::vector<WVFieldRequest> requests;
    requests.reserve(outputs_.size());
    for(const auto& output:outputs_) {
      WVFieldSamplingRequest sampling;
      if(!output.specification.isComplex && !output.extrema && output.variable!=Variable::totalEnergySpatiallyIntegrated)
        sampling=groups_[output.group].requests[output.dependency].sampling;
      requests.push_back({output.specification.identifier,output.specification.fieldName,std::move(sampling)});
    }
    return create(service,requests,result);
  } catch(const std::bad_alloc&) {
    return {WVKernelStatusCode::allocationFailure,"Unable to rebind the diagnostic plan."};
  }
}

double WVDiagnosticFieldPlan::omega(std::size_t index) const noexcept {
  if(constant_) return constant_->descriptor().verticalModes().omega[index];
  if(hydrostatic_) return hydrostatic_->factors()[index].omega;
  if(boussinesq_) return boussinesq_->factors()[index].omega;
  return 0;
}
bool WVDiagnosticFieldPlan::keep(std::size_t group,std::size_t family,std::size_t index) const noexcept {
  const auto horizontal=index/spectral_.rows,vertical=index%spectral_.rows;
  const bool mean=constant_ ? constant_->descriptor().fourierModes()[horizontal].Kh==0 :
      modal_->modes[horizontal].k==0 && modal_->modes[horizontal].l==0;
  const bool zeroVertical=constant_ ? constant_->descriptor().verticalModes().j[vertical]==0 : modal_->j[vertical]==0;
  switch(group) {
    case 1: return family==2 && !mean;
    case 2: return family!=2 && !mean && !zeroVertical;
    case 3: return family!=2 && mean;
    case 4: return family==2 && mean && !zeroVertical;
    default: return true;
  }
}
double WVDiagnosticFieldPlan::weight(std::size_t z) const noexcept {
  if(isBarotropic_) return Lz_;
  if(modal_) return modal_->z_int[z];
  const double dz=Lz_/static_cast<double>(spatial_.third-1);
  return (z==0 || z+1==spatial_.third) ? dz/2 : dz;
}
double WVDiagnosticFieldPlan::stratification(std::size_t z) const noexcept {
  if(isBarotropic_) return barotropicG_/Lz_;
  return modal_ ? modal_->N2[z] : constantN2_;
}

WVKernelStatus WVDiagnosticFieldPlan::evaluate(WVFieldEvaluationService& service,const WVIntegrationState& input,
    WVFieldOutputView* outputs,std::size_t count) const {
  if(owner_!=&service) return invalid("The diagnostic plan belongs to a different field service.");
  if(count!=outputs_.size() || (count && !outputs)) return invalid("Diagnostic output-view count is invalid.");
  WVState amplitudes=input.waveVortex;
  if(input.coefficientFamilyCount) {
    if(input.coefficientFamilyCount!=(isQG_ ? 1u : 3u) || !input.coefficientFamilies)
      return invalid("Diagnostic coefficient families do not match the transform.");
    for(std::size_t family=0;family<input.coefficientFamilyCount;++family) {
      const auto* layout=input.coefficientFamilies[family].layout;
      const char* expected=isQG_ ? "A0" : family==0 ? "Ap" : family==1 ? "Am" : "A0";
      if(!layout || layout->identifier!=expected || layout->elementCount!=spectral_.elementCount() ||
          (isBarotropic_ ? layout->spectralDimensions.size()!=1 || layout->spectralDimensions[0]!=spectral_.columns :
            layout->spectralDimensions.size()!=2 || layout->spectralDimensions[0]!=spectral_.rows || layout->spectralDimensions[1]!=spectral_.columns))
        return invalid("Diagnostic coefficient family layout does not match the transform.");
    }
    if(isQG_) amplitudes.coefficients.A0={input.coefficientFamilies[0].data,spectral_};
    else amplitudes.coefficients={{input.coefficientFamilies[0].data,spectral_},
        {input.coefficientFamilies[1].data,spectral_},{input.coefficientFamilies[2].data,spectral_}};
  }
  const WVComplexConstView coefficientViews[]={amplitudes.coefficients.Ap,amplitudes.coefficients.Am,amplitudes.coefficients.A0};
  for(std::size_t family=isQG_ ? 2 : 0;family<3;++family)
    if(coefficientViews[family].shape.rows!=spectral_.rows || coefficientViews[family].shape.columns!=spectral_.columns)
      return invalid("Diagnostic coefficient view has the wrong shape.");
  const WVComplex64* coefficients[]={amplitudes.coefficients.Ap.data,amplitudes.coefficients.Am.data,amplitudes.coefficients.A0.data};
  const auto n=spectral_.elementCount();
  if(!std::isfinite(amplitudes.t) || !std::isfinite(amplitudes.t0) || !std::isfinite(amplitudes.t-amplitudes.t0)) return invalid("Diagnostic state times and elapsed time must be finite.");
  if(input.additionalBlockCount && !input.additionalBlocks) return invalid("Diagnostic additional state views are missing.");
  for(std::size_t block=0;block<input.additionalBlockCount;++block)
    if(!input.additionalBlocks[block].layout) return invalid("Diagnostic additional state layout is missing.");
  if(!isQG_) for(std::size_t index=0;index<n;++index)
    if(!std::isfinite(omega(index)*(amplitudes.t-amplitudes.t0))) return invalid("Diagnostic phase would overflow.");
  for(std::size_t family=isQG_ ? 2 : 0;family<3;++family) {
    if(!coefficients[family]) return invalid("Diagnostic coefficients are missing.");
    for(std::size_t index=0;index<n;++index)
      if(!std::isfinite(coefficients[family][index].real) || !std::isfinite(coefficients[family][index].imag))
        return invalid("Diagnostic coefficients must be finite.");
  }
  for(std::size_t index=0;index<count;++index) {
    const auto& spec=outputs_[index].specification;
    const void* pointer=spec.isComplex ? static_cast<void*>(outputs[index].complexData) : outputs[index].data;
    const auto bytes=spec.elementCount*(spec.isComplex ? sizeof(WVComplex64) : sizeof(double));
    if(outputs[index].elementCount!=spec.elementCount || (bytes && !pointer)) return invalid("Diagnostic output storage has the wrong shape or type.");
    for(const auto* coefficient:coefficients)
      if(overlap(pointer,bytes,coefficient,n*sizeof(WVComplex64)))
        return {WVKernelStatusCode::overlappingArrays,"Diagnostic output overlaps coefficient state."};
    for(std::size_t block=0;block<input.additionalBlockCount;++block) {
      const auto& view=input.additionalBlocks[block];
      if(overlap(pointer,bytes,view.realData,view.layout->elementCount*sizeof(double)) ||
          overlap(pointer,bytes,view.complexData,view.layout->elementCount*sizeof(WVComplex64)))
        return {WVKernelStatusCode::overlappingArrays,"Diagnostic output overlaps additional state."};
    }
    for(std::size_t previous=0;previous<index;++previous) {
      const auto& other=outputs_[previous].specification;
      if(overlap(pointer,bytes,other.isComplex ? static_cast<void*>(outputs[previous].complexData) : outputs[previous].data,
          other.elementCount*(other.isComplex ? sizeof(WVComplex64) : sizeof(double))))
        return {WVKernelStatusCode::overlappingArrays,"Diagnostic outputs overlap."};
    }
  }
  auto& metrics=service.stratified_ ? service.stratified_->metrics_ : service.barotropicQG_ ? service.barotropicQG_->metrics_ : service.metrics_;
  struct ResetLive { WVFieldEvaluationMetrics& metrics; ~ResetLive() {metrics.diagnosticWorkspaceLiveBytes=0;} } reset{metrics};
  try {
    std::array<std::vector<std::vector<double>>,5> fields;
    std::array<std::vector<WVComplex64>,3> masked;
    std::vector<WVComplex64> phases;
    std::size_t primitiveCount=0;
    const auto account=[&](std::size_t viewBytes) {
      std::size_t bytes=viewBytes;
      for(const auto& group:fields) {
        bytes+=group.capacity()*sizeof(std::vector<double>);
        for(const auto& buffer:group) bytes+=buffer.capacity()*sizeof(double);
      }
      for(const auto& buffer:masked) bytes+=buffer.capacity()*sizeof(WVComplex64);
      bytes+=phases.capacity()*sizeof(WVComplex64);
      metrics.diagnosticWorkspaceLiveBytes=bytes;
      metrics.diagnosticWorkspaceHighWaterBytes=std::max(metrics.diagnosticWorkspaceHighWaterBytes,bytes);
    };
    for(std::size_t group=0;group<groups_.size();++group) {
      const auto& plan=groups_[group].fields;
      if(!plan.outputCount()) continue;
      std::vector<WVFieldOutputView> views;
      fields[group].resize(plan.outputCount());
      for(std::size_t output=0;output<plan.outputCount();++output) {
        auto& buffer=fields[group][output]; buffer.resize(plan.outputs()[output].elementCount);
        views.push_back({buffer.data(),buffer.size()});
      }
      WVIntegrationState selected=input;
      selected.waveVortex=amplitudes;
      std::array<WVCoefficientFamilyConstView,3> selectedFamilies{};
      if(group) {
        for(std::size_t family=0;family<3;++family) {
          masked[family].resize(n);
          for(std::size_t index=0;index<n;++index)
            masked[family][index]=keep(group,family,index) ? coefficients[family][index] : WVComplex64{};
        }
        selected.waveVortex={amplitudes.t,amplitudes.t0,{{masked[0].data(),spectral_},{masked[1].data(),spectral_},{masked[2].data(),spectral_}}};
        if(input.coefficientFamilyCount) {
          for(std::size_t family=0;family<3;++family) selectedFamilies[family]={input.coefficientFamilies[family].layout,masked[family].data()};
          selected.coefficientFamilies=selectedFamilies.data();
        }
      }
      account(views.capacity()*sizeof(WVFieldOutputView));
      const auto status=service.evaluate(plan,selected,views.data(),views.size()); if(!status) return status;
      primitiveCount+=views.size();
    }
    bool needsPhase=false;
    for(const auto& output:outputs_) needsPhase|=output.variable==Variable::Apt || output.variable==Variable::Amt;
    if(needsPhase) {
      phases.resize(n);
      for(std::size_t index=0;index<n;++index) {
        const double angle=omega(index)*(amplitudes.t-amplitudes.t0);
        phases[index]={std::cos(angle),std::sin(angle)};
      }
    }
    account(0);
    for(std::size_t index=0;index<count;++index) {
      const auto& output=outputs_[index];
      if(output.specification.isComplex) {
        const auto family=output.variable==Variable::Apt ? 0 : output.variable==Variable::Amt ? 1 : 2;
        for(std::size_t coefficient=0;coefficient<n;++coefficient) {
          const auto a=coefficients[family][coefficient];
          if(family==2) outputs[index].complexData[coefficient]=a;
          else {
            auto phase=phases[coefficient]; if(family==1) phase.imag=-phase.imag;
            outputs[index].complexData[coefficient]={a.real*phase.real-a.imag*phase.imag,a.real*phase.imag+a.imag*phase.real};
          }
        }
      } else if(output.variable==Variable::totalEnergySpatiallyIntegrated) {
        const auto& u=fields[0][output.auxiliaries[0]];
        const auto& v=fields[0][output.auxiliaries[1]];
        const auto& eta=fields[0][output.auxiliaries[2]];
        const auto horizontal=spatial_.first*spatial_.second;
        double integral=0;
        for(std::size_t z=0;z<spatial_.third;++z) {
          double horizontalSum=0;
          for(std::size_t point=0;point<horizontal;++point) {
            const auto i=point+horizontal*z;
            double value=u[i]*u[i]+v[i]*v[i]+stratification(z)*eta[i]*eta[i];
            if(!isHydrostatic_) { const double w=fields[0][output.auxiliaries[3]][i]; value+=w*w; }
            horizontalSum+=value;
          }
          integral+=weight(z)*horizontalSum/static_cast<double>(horizontal);
        }
        outputs[index].data[0]=integral/2;
      } else if(output.verticalMean) {
        const auto& source=fields[0][output.dependency];
        const auto plane=spatial_.first*spatial_.second;
        for(std::size_t z=0;z<spatial_.third;++z) {
          double sum=0;
          for(std::size_t i=0;i<plane;++i) sum+=source[z*plane+i];
          outputs[index].data[z]=sum/static_cast<double>(plane);
        }
      } else if(output.extrema) {
        const auto& first=fields[0][output.auxiliaries[0]];
        double maximum=0;
        for(std::size_t point=0;point<first.size();++point) {
          const double value=output.variable==Variable::uvMax ?
              (constant_ || isBarotropic_ ? std::sqrt(first[point]*first[point]+fields[0][output.auxiliaries[1]][point]*fields[0][output.auxiliaries[1]][point]) : std::hypot(first[point],fields[0][output.auxiliaries[1]][point])) : std::abs(first[point]);
          maximum=std::max(maximum,value);
        }
        outputs[index].data[0]=maximum;
      } else {
        const auto& source=fields[output.group][output.dependency];
        const auto offset=output.surface ? (spatial_.third-1)*spatial_.first*spatial_.second : 0;
        std::copy_n(source.data()+offset,output.specification.elementCount,outputs[index].data);
      }
    }
    ++metrics.diagnosticEvaluationCount;
    metrics.diagnosticPrimitiveOutputCount+=primitiveCount;
    std::size_t primitiveReferences=0,phaseReferences=0;
    for(const auto& output:outputs_) {
      if(output.specification.isComplex) {
        if(output.variable!=Variable::A0t) ++phaseReferences;
      } else if(output.variable==Variable::totalEnergySpatiallyIntegrated) primitiveReferences+=isHydrostatic_ ? 3 : 4;
      else if(output.extrema) primitiveReferences+=output.variable==Variable::uvMax ? 2 : 1;
      else ++primitiveReferences;
    }
    metrics.diagnosticIntermediateReuseCount+=primitiveReferences-primitiveCount+(phaseReferences ? phaseReferences-1 : 0);
    metrics.diagnosticWorkspaceLiveBytes=0;
    return WVKernelStatus::ok();
  } catch(const std::bad_alloc&) {
    return {WVKernelStatusCode::allocationFailure,"Unable to allocate event-scoped diagnostic scratch."};
  }
}

std::size_t WVDiagnosticFieldPlan::persistentBytes() const noexcept {
  std::size_t bytes=sizeof(*this)+configuration_.capacity()+outputs_.capacity()*sizeof(Output);
  for(const auto& output:outputs_)
    bytes+=output.specification.identifier.capacity()+output.specification.fieldName.capacity()+
        output.specification.dimensions.capacity()*sizeof(std::size_t);
  for(const auto& group:groups_) {
    bytes+=group.fields.persistentBytes()-sizeof(group.fields)+group.requests.capacity()*sizeof(WVFieldRequest);
    for(const auto& request:group.requests)
      bytes+=request.identifier.capacity()+request.fieldName.capacity()+
          (request.sampling.x.capacity()+request.sampling.y.capacity()+request.sampling.z.capacity())*sizeof(double)+
          (request.sampling.xIndices.capacity()+request.sampling.yIndices.capacity())*sizeof(std::size_t);
  }
  return bytes;
}
} // namespace wavevortex::runtime::detail
