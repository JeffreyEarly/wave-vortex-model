#pragma once
#include "WaveVortexRuntime/WVForcingTendency.hpp"
#include "WaveVortexRuntime/WVPortableVariablePlan.hpp"
#include <limits>
#include <memory>
#include <string>
#include <type_traits>
#include <vector>

namespace wavevortex::runtime { class WVConstantStratificationForcingEngine; }

namespace wavevortex::runtime::detail {

// Borrows an existing forcing engine and its immutable, already resolved
// instances. This is a coarse service binding, never a second forcing registry.
class WVForcingDiagnosticBinding final {
public:
  struct Output {
    const WVPortableVariableContract* contract=nullptr;
    std::size_t executionIndex=0,channel=0,physicalChannels=0;
  };
  template<class Engine,bool QG>
  static WVKernelStatus create(Engine& engine,std::unique_ptr<WVForcingDiagnosticBinding>& result) {
    try {
      auto candidate=std::unique_ptr<WVForcingDiagnosticBinding>(new WVForcingDiagnosticBinding);
      candidate->engine_=&engine;
      bool prefixQualified=true,physicalNeeded=false;
      for(std::size_t index=0;index<engine.forcingCount();++index) {
        const auto* instance=engine.forcingInstance(index);
        if(instance->ordinal()>std::numeric_limits<std::uint32_t>::max())
          return {WVKernelStatusCode::invalidConfiguration,"Forcing instance ordinal exceeds the graph contract."};
        for(const auto& previous:candidate->bindings_) if(previous.instanceOrdinal==instance->ordinal())
          return {WVKernelStatusCode::invalidConfiguration,"Forcing graph ordinals must be unique for diagnostic binding."};
        prefixQualified&=instance->supportsTendencyDiagnostics();
        physicalNeeded|=instance->requiresDiagnosticPhysicalFields();
        candidate->physicalPrefix_.push_back(physicalNeeded);
        candidate->bindings_.push_back({instance->name(),static_cast<std::uint32_t>(instance->ordinal()),prefixQualified});
      }
      candidate->physicalChannels_=QG ? 2 : std::is_same_v<Engine,WVConstantStratificationForcingEngine> ? 3 : 4;
      candidate->evaluate_=[](void* pointer,const WVState& state,const WVForcingTendencyOutput* outputs,std::size_t count,const WVRealFieldBundleConstView* prepared) {
        auto& resolved=*static_cast<Engine*>(pointer);
        if constexpr(QG) return resolved.evaluateForcingTendencies(state.coefficients.A0,outputs,count,prepared);
        else return resolved.evaluateForcingTendencies(state,outputs,count,prepared);
      };
      candidate->metrics_=[](const void* pointer)->const WVForcingTendencyMetrics& {return static_cast<const Engine*>(pointer)->tendencyMetrics();};
      result=std::move(candidate);
      return WVKernelStatus::ok();
    } catch(const std::bad_alloc&) {
      return {WVKernelStatusCode::allocationFailure,"Unable to bind resolved forcing diagnostics."};
    }
  }
  WVKernelStatus resolve(std::string_view name,std::string_view configuration,std::uint8_t sampling,Output& output) const {
    WVPortableVariableOptions options; options.source=WVPortableOperationSource::builtIn;
    // The source-linked engine implementation qualifies numerical execution.
    // Catalog delivery status remains pending until full output qualification.
    WVPortableVariablePlan plan;
    const auto status=resolvePortableForcingVariablePlan(name,configuration,sampling,bindings_.data(),bindings_.size(),options,plan);
    if(status!=WVPortableVariableStatus::supported)
      return {WVKernelStatusCode::unsupportedOperation,"Forcing diagnostic identity, sampling, or instance binding is unsupported or ambiguous: "+std::string(name)};
    for(std::size_t index=0;index<bindings_.size();++index) if(bindings_[index].instanceOrdinal==plan.forcingInstanceOrdinal) {
      output.contract=plan.output; output.executionIndex=index;
      output.physicalChannels=physicalPrefix_[index] ? physicalChannels_ : 0;
      switch(plan.output->metadata.identifier) {
        case WVPortableVariable::Fu_portable_catalog_forcing: case WVPortableVariable::Fqgpv_portable_catalog_forcing: output.channel=0; break;
        case WVPortableVariable::Fv_portable_catalog_forcing: output.channel=1; break;
        case WVPortableVariable::Fw_portable_catalog_forcing: output.channel=2; break;
        case WVPortableVariable::Feta_portable_catalog_forcing:
          output.channel=configuration.rfind("constant-nonhydrostatic-",0)==0 || configuration.rfind("boussinesq-",0)==0 ? 3 : 2; break;
        default: return {WVKernelStatusCode::unsupportedOperation,"Unknown forcing diagnostic channel."};
      }
      return WVKernelStatus::ok();
    }
    return {WVKernelStatusCode::invalidConfiguration,"Resolved forcing instance is absent from its execution schedule."};
  }
  WVKernelStatus evaluate(const WVState& state,const WVForcingTendencyOutput* outputs,std::size_t count,const WVRealFieldBundleConstView* prepared) const {
    return evaluate_(engine_,state,outputs,count,prepared);
  }
  const WVForcingTendencyMetrics& metrics() const {return metrics_(engine_);}
  std::size_t persistentBytes() const noexcept {
    return sizeof(*this)+bindings_.capacity()*sizeof(WVPortableForcingVariableBinding)+physicalPrefix_.capacity()*sizeof(std::uint8_t);
  }
private:
  void* engine_=nullptr;
  WVKernelStatus (*evaluate_)(void*,const WVState&,const WVForcingTendencyOutput*,std::size_t,const WVRealFieldBundleConstView*)=nullptr;
  const WVForcingTendencyMetrics& (*metrics_)(const void*)=nullptr;
  std::vector<WVPortableForcingVariableBinding> bindings_;
  std::vector<std::uint8_t> physicalPrefix_;
  std::size_t physicalChannels_=0;
};
}
