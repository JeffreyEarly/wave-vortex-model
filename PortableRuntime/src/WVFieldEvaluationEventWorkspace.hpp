#pragma once

#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexRuntime/WVIntegrationState.hpp"
#include "WVDensityEventEvaluation.hpp"

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
    if(!retainPrimitiveFields_ || state.t!=t_ || state.t0!=t0_ || coefficients!=coefficients_ || field>=fields_.size())
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
    account();
    return WVKernelStatus::ok();
  }

  WVKernelStatus validateDensityBinding(const WVState& state,
      WVDensityDiagnosticContract contract) const {
    const std::array<const WVComplex64*,3> coefficients{state.coefficients.Ap.data,state.coefficients.Am.data,state.coefficients.A0.data};
    if(state.t!=t_ || state.t0!=t0_ || coefficients!=coefficients_)
      return {WVKernelStatusCode::invalidConfiguration,"Density evaluation belongs to a different active event state."};
    if(density_.initialized() && contract.reference!=densityContract_.reference)
      return {WVKernelStatusCode::invalidConfiguration,"Density reference cannot change within an active event."};
    return WVKernelStatus::ok();
  }
  bool hasDensitySource() const noexcept {return density_.initialized();}
  WVKernelStatus bindDensity(std::vector<double>& source,WVShape3D shape,
      WVDensityEventGeometry geometry,WVDensityDiagnosticContract contract) {
    if(density_.initialized()) return WVKernelStatus::ok();
    densitySource_=std::move(source);
    account();
    densityHeights_=*geometry.heights; account();
    densityWeights_=*geometry.integrationWeights; account();
    densityInitial_=*geometry.initialProfile; account();
    geometry.heights=&densityHeights_;
    geometry.integrationWeights=&densityWeights_;
    geometry.initialProfile=&densityInitial_;
    densityContract_=contract;
    const auto status=WVDensityEventEvaluation::create(
        {densitySource_.data(),shape},geometry,contract,density_);
    account();
    return status;
  }
  WVKernelStatus prepareDensity(std::uint8_t demands) {
    const auto status=density_.prepare(demands);
    const auto& now=density_.metrics();
    metrics_->densityRecoveryCount+=now.recoveryCount-densityMetrics_.recoveryCount;
    metrics_->densityProfileConstructionCount+=now.profileConstructionCount-densityMetrics_.profileConstructionCount;
    metrics_->densityInversePassCount+=now.inversePassCount-densityMetrics_.inversePassCount;
    metrics_->densityAPEPassCount+=now.apePassCount-densityMetrics_.apePassCount;
    metrics_->densityReuseCount+=now.reuseCount-densityMetrics_.reuseCount;
    densityMetrics_=now;
    account();
    return status;
  }
  WVDensityEventView densityView(WVDensityEventField field) const noexcept {return density_.view(field);}

private:
  friend class WVFieldEvaluationEventScope;
  double t_=0,t0_=0;
  std::array<const WVComplex64*,3> coefficients_{};
  std::array<std::vector<double>,dynamicalDerivativeKeyBase+3> fields_;
  WVFieldEvaluationMetrics* metrics_=nullptr;
  bool retainPrimitiveFields_=true;
  std::vector<double> densitySource_;
  std::vector<double> densityHeights_, densityWeights_, densityInitial_;
  WVDensityDiagnosticContract densityContract_;
  WVDensityEventEvaluation density_;
  WVDensityEventMetrics densityMetrics_;
  void account() noexcept {
    const auto sourceBytes=(densitySource_.capacity()+densityHeights_.capacity()+
        densityWeights_.capacity()+densityInitial_.capacity())*sizeof(double);
    const auto live=sourceBytes+density_.metrics().liveBytes;
    const auto peak=sourceBytes+density_.metrics().highWaterBytes;
    metrics_->densityWorkspaceLiveBytes=live;
    metrics_->densityWorkspaceHighWaterBytes=std::max(metrics_->densityWorkspaceHighWaterBytes,peak);
    std::size_t other=0;
    for(const auto& field:fields_) other+=field.capacity()*sizeof(double);
    metrics_->eventFieldWorkspaceLiveBytes=other+live;
    metrics_->eventFieldWorkspaceHighWaterBytes=std::max(metrics_->eventFieldWorkspaceHighWaterBytes,other+peak);
  }
};

class WVFieldEvaluationEventScope final {
public:
  WVFieldEvaluationEventScope(WVFieldEvaluationService&,const WVIntegrationState&,bool enabled=true,bool retainPrimitiveFields=true);
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
