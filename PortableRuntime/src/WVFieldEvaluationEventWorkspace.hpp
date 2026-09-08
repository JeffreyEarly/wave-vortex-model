#pragma once

#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexRuntime/WVIntegrationState.hpp"

#include <algorithm>
#include <array>
#include <new>
#include <vector>

namespace wavevortex::runtime::detail {

// Expensive reconstructed fields shared only within one output preparation.
// The owning service fixes the transform; the borrowed state fixes time and
// coefficients. Masked coefficient copies cannot hit this workspace. Nothing
// survives its scope, so later events cannot reuse an in-place state mutation.
class WVFieldEvaluationEventWorkspace final {
public:
  static constexpr std::size_t dynamicalDerivativeKeyBase=32;
  explicit WVFieldEvaluationEventWorkspace(const WVIntegrationState& state)
      : t_(state.waveVortex.t), t0_(state.waveVortex.t0) {
    coefficients_={state.waveVortex.coefficients.Ap.data,state.waveVortex.coefficients.Am.data,state.waveVortex.coefficients.A0.data};
    if(state.coefficientFamilies) {
      if(state.coefficientFamilyCount==1) coefficients_={nullptr,nullptr,state.coefficientFamilies[0].data};
      else if(state.coefficientFamilyCount==3)
        for(std::size_t family=0;family<3;++family) coefficients_[family]=state.coefficientFamilies[family].data;
    }
  }

  template<class Operation>
  WVKernelStatus evaluate(std::size_t field,const WVState& state,double* output,
      std::size_t count,Operation&& operation,bool& reused) {
    reused=false;
    const std::array<const WVComplex64*,3> coefficients{state.coefficients.Ap.data,state.coefficients.Am.data,state.coefficients.A0.data};
    if(state.t!=t_ || state.t0!=t0_ || coefficients!=coefficients_ || field>=fields_.size())
      return operation();
    auto& values=fields_[field];
    if(!values.empty() && values.size()==count) {
      std::copy(values.begin(),values.end(),output);
      reused=true;
      ++metrics_->eventFieldReuseCount;
      return WVKernelStatus::ok();
    }
    const auto status=operation();
    if(!status) return status;
    try {
      values.assign(output,output+count);
    } catch(const std::bad_alloc&) {
      return {WVKernelStatusCode::allocationFailure,"Unable to retain a reconstructed field for this output event."};
    }
    std::size_t bytes=0;
    for(const auto& fieldValues:fields_) bytes+=fieldValues.capacity()*sizeof(double);
    metrics_->eventFieldWorkspaceLiveBytes=bytes;
    metrics_->eventFieldWorkspaceHighWaterBytes=std::max(metrics_->eventFieldWorkspaceHighWaterBytes,bytes);
    return WVKernelStatus::ok();
  }

private:
  friend class WVFieldEvaluationEventScope;
  double t_=0,t0_=0;
  std::array<const WVComplex64*,3> coefficients_{};
  std::array<std::vector<double>,dynamicalDerivativeKeyBase+3> fields_;
  WVFieldEvaluationMetrics* metrics_=nullptr;
};

class WVFieldEvaluationEventScope final {
public:
  WVFieldEvaluationEventScope(WVFieldEvaluationService&,const WVIntegrationState&,bool enabled=true);
  ~WVFieldEvaluationEventScope() {release();}
  WVFieldEvaluationEventScope(const WVFieldEvaluationEventScope&)=delete;
  WVFieldEvaluationEventScope& operator=(const WVFieldEvaluationEventScope&)=delete;
  const WVKernelStatus& status() const noexcept {return status_;}
  void release() noexcept;
private:
  WVFieldEvaluationService* service_=nullptr;
  WVFieldEvaluationEventWorkspace workspace_;
  WVKernelStatus status_=WVKernelStatus::ok();
};

} // namespace wavevortex::runtime::detail
