#pragma once

#include "WaveVortexRuntime/WVForcing.hpp"
#include "WaveVortexRuntime/WVForcingTendency.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <memory>
#include <vector>

namespace wavevortex::runtime::detail {

// Owned by one diagnostic invocation, never by the integrator or field plan.
// The ordinary RHS has no dependency on these state-sized arrays.
class WVForcingDiagnosticWorkspace final {
public:
  WVForcingDiagnosticWorkspace(WVShape2D spectral, WVShape4D spatial,
      std::size_t coefficientFamilies=3,std::size_t physicalChannels=4)
      : spectral(spectral), spatial(spatial), flux(coefficientFamilies*spectral.elementCount()),
        previous(flux.size()), temporary(flux.size()),
        cumulative(spatial.elementCount()), raw(spatial.elementCount()),
        physical(physicalChannels*spatial.first*spatial.second*spatial.third) {}

  WVFlux fluxView() { return views(flux); }
  WVFlux temporaryView() { return views(temporary); }
  WVRealFieldBundleView rawView() { return {raw.data(),spatial}; }
  WVRealFieldBundleConstView cumulativeView() const { return {cumulative.data(),spatial}; }
  WVKernelStatus addSpatial(WVRealFieldBundleConstView value) {
    if (value.shape.first!=spatial.first || value.shape.second!=spatial.second ||
        value.shape.third!=spatial.third || value.shape.fourth!=spatial.fourth)
      return {WVKernelStatusCode::invalidShape,"A forcing supplied invalid spatial diagnostic channels."};
    if (!value.data)
      return {WVKernelStatusCode::invalidPointer,"A forcing supplied null spatial diagnostic storage."};
    spatialCaptured=true;
    for (std::size_t i=0;i<raw.size();++i) raw[i]+=value.data[i];
    return WVKernelStatus::ok();
  }
  std::size_t bytes() const noexcept {
    return sizeof(*this)+(flux.capacity()+previous.capacity()+temporary.capacity()+
        laplacianCoefficients.capacity())*sizeof(WVComplex64)+
        (cumulative.capacity()+raw.capacity()+physical.capacity()+laplacianFields.capacity()+staged.capacity())*sizeof(double);
  }

  WVShape2D spectral;
  WVShape4D spatial;
  std::vector<WVComplex64> flux,previous,temporary,laplacianCoefficients;
  std::vector<double> cumulative,raw,physical,laplacianFields,staged;
  bool physicalPrepared=false,spatialCaptured=false;

private:
  WVFlux views(std::vector<WVComplex64>& data) {
    const auto S=spectral.elementCount();
    if (data.size()==S) return {{},{},{data.data(),spectral}};
    return {{data.data(),spectral},{data.data()+S,spectral},{data.data()+2*S,spectral}};
  }
};

// MATLAB's inverse Fourier transform takes the real part at self-conjugate
// modes. The modal record excludes Nyquist modes, so only Kh=0 needs this
// projection. Averaging the inertial pair preserves its real u/v contribution;
// copying Ap into Am (the model-state constraint) would double an Ap-only delta.
// Only a temporary per-instance difference is changed, never the accumulator.
template<class Geometry>
void projectRealMeanTendency(std::vector<WVComplex64>& difference,const Geometry& g) {
  const auto S=g.Nj*g.Nkl;
  for (std::size_t mode=0;mode<g.Nkl;++mode) if (g.k[mode]==0 && g.l[mode]==0)
    for (std::size_t j=0;j<g.Nj;++j) {
      const auto i=j+g.Nj*mode;
      const auto ap=difference[i],am=difference[S+i];
      difference[i]={.5*ap.real+.5*am.real,.5*ap.imag-.5*am.imag};
      difference[S+i]={difference[i].real,-difference[i].imag};
      difference[2*S+i].imag=0;
    }
}

inline bool forcingArraysOverlap(const void* a,std::size_t n,const void* b,std::size_t m) {
  const auto x=reinterpret_cast<std::uintptr_t>(a),y=reinterpret_cast<std::uintptr_t>(b);
  return a && b && n && m && (x<=y ? y-x<n : x-y<m);
}

inline WVKernelStatus validatePreparedDiagnosticFields(
    const WVRealFieldBundleConstView* prepared,WVShape4D spatial,std::size_t channels,
    const WVState& state,const WVForcingTendencyOutput* outputs,std::size_t count) {
  if (!prepared) return WVKernelStatus::ok();
  const auto shape=prepared->shape;
  if(shape.first!=spatial.first || shape.second!=spatial.second || shape.third!=spatial.third || shape.fourth!=channels)
    return {WVKernelStatusCode::invalidShape,"Prepared forcing diagnostic fields have the wrong channels."};
  const auto bytes=shape.elementCount()*sizeof(double),address=reinterpret_cast<std::uintptr_t>(prepared->data);
  if(!address || address%alignof(double) || bytes>UINTPTR_MAX-address)
    return {WVKernelStatusCode::invalidPointer,"Invalid prepared forcing diagnostic field storage."};
  for(const auto input:{state.coefficients.Ap,state.coefficients.Am,state.coefficients.A0})
    if(forcingArraysOverlap(prepared->data,bytes,input.data,input.shape.elementCount()*sizeof(WVComplex64)))
      return {WVKernelStatusCode::overlappingArrays,"Prepared forcing fields overlap coefficient state."};
  for(std::size_t index=0;index<count;++index)
    if(forcingArraysOverlap(prepared->data,bytes,outputs[index].fields.data,spatial.elementCount()*sizeof(double)))
      return {WVKernelStatusCode::overlappingArrays,"Prepared forcing fields overlap diagnostic output."};
  for(std::size_t index=0;index<shape.elementCount();++index)
    if(!std::isfinite(prepared->data[index]))
      return {WVKernelStatusCode::invalidConfiguration,"Prepared forcing fields must be finite."};
  return WVKernelStatus::ok();
}

template<class Forcing>
WVKernelStatus validateForcingTendencyOutputs(
    const std::vector<std::unique_ptr<Forcing>>& forcing,WVShape2D spectral,WVShape4D spatial,
    const WVState& state,const WVForcingTendencyOutput* outputs,std::size_t count) {
  if (count && !outputs)
    return {WVKernelStatusCode::invalidPointer,"Missing forcing diagnostic output descriptors."};
  const auto bytes=spatial.elementCount()*sizeof(double);
  for (std::size_t i=0;i<count;++i) {
    const auto& output=outputs[i];
    if (output.executionIndex>=forcing.size())
      return {WVKernelStatusCode::invalidConfiguration,"Forcing diagnostic index is not bound to this schedule."};
    const auto shape=output.fields.shape;
    if (shape.first!=spatial.first || shape.second!=spatial.second ||
        shape.third!=spatial.third || shape.fourth!=spatial.fourth)
      return {WVKernelStatusCode::invalidShape,"Forcing diagnostic output has the wrong spatial channels."};
    const auto address=reinterpret_cast<std::uintptr_t>(output.fields.data);
    if (!address || address%alignof(double) || bytes>UINTPTR_MAX-address)
      return {WVKernelStatusCode::invalidPointer,"Invalid forcing diagnostic output storage."};
    for (const auto input:{state.coefficients.Ap,state.coefficients.Am,state.coefficients.A0})
      if (forcingArraysOverlap(output.fields.data,bytes,input.data,spectral.elementCount()*sizeof(WVComplex64)))
        return {WVKernelStatusCode::overlappingArrays,"Forcing diagnostic output overlaps model coefficients."};
    for (std::size_t j=0;j<i;++j) {
      if (output.executionIndex==outputs[j].executionIndex)
        return {WVKernelStatusCode::invalidConfiguration,"Repeated forcing diagnostic index must share one output."};
      if (forcingArraysOverlap(output.fields.data,bytes,outputs[j].fields.data,bytes))
        return {WVKernelStatusCode::overlappingArrays,"Forcing diagnostic outputs overlap."};
    }
  }
  if (count) {
    std::size_t last=0;
    for (std::size_t i=0;i<count;++i) last=std::max(last,outputs[i].executionIndex);
    for (std::size_t i=0;i<=last;++i)
      if (!forcing[i]->supportsTendencyDiagnostics())
        return {WVKernelStatusCode::unsupportedOperation,"The resolved forcing has no qualified diagnostic implementation."};
  }
  return WVKernelStatus::ok();
}

// The existing resolved instances remain the only forcing dispatch. Spatial
// operations are accumulated before the stage-boundary projection, matching
// SpatialForcingOperation. Later operations observe the preceding accumulator.
template<class Forcing,class Execute,class Project,class Reconstruct>
WVKernelStatus evaluateForcingTendencySequence(
    const std::vector<std::unique_ptr<Forcing>>& forcing,
    WVForcingDiagnosticWorkspace& work,const WVForcingTendencyOutput* outputs,
    std::size_t count,WVForcingTendencyMetrics& metrics,
    Execute execute,Project project,Reconstruct reconstruct) {
  if (!count) return WVKernelStatus::ok();
  if (count>work.raw.max_size()/work.raw.size())
    return {WVKernelStatusCode::sizeOverflow,"Forcing diagnostic staging size overflow."};
  work.staged.resize(count*work.raw.size());
  std::size_t last=0;
  for (std::size_t i=0;i<count;++i) last=std::max(last,outputs[i].executionIndex);
  bool projected=false;
  auto flux=work.fluxView();
  for (std::size_t index=0;index<=last;++index) {
    const auto spatial=forcing[index]->stage()==WVForcingStage::spatial;
    if (!spatial && !projected) {
      auto status=project(work.cumulativeView(),flux);
      if (!status) return status;
      ++metrics.spatialProjectionCount;
      projected=true;
    }
    if (!spatial) std::copy(work.flux.begin(),work.flux.end(),work.previous.begin());
    std::fill(work.raw.begin(),work.raw.end(),0.0);
    work.spatialCaptured=false;
    auto status=execute(*forcing[index],flux);
    if (!status) return status;
    if (spatial && !work.spatialCaptured)
      return {WVKernelStatusCode::unsupportedOperation,"The resolved spatial forcing does not expose a diagnostic contribution."};
    ++metrics.forcingEvaluationCount;
    WVRealFieldBundleView* destination=nullptr;
    WVRealFieldBundleView destinationView;
    for (std::size_t output=0;output<count;++output)
      if (outputs[output].executionIndex==index) {
        destinationView=outputs[output].fields;
        destinationView.data=work.staged.data()+output*work.raw.size();
        destination=&destinationView;
        break;
      }
    if (spatial) {
      for (std::size_t i=0;i<work.raw.size();++i) {
        const auto previous=work.cumulative[i];
        work.cumulative[i]+=work.raw[i];
        if (destination) destination->data[i]=work.cumulative[i]-previous;
      }
    } else if (destination) {
      for (std::size_t i=0;i<work.flux.size();++i)
        work.previous[i]={work.flux[i].real-work.previous[i].real,
                          work.flux[i].imag-work.previous[i].imag};
      status=reconstruct(work.previous,*destination);
      if (!status) return status;
      ++metrics.spectralReconstructionCount;
    }
  }
  for (std::size_t output=0;output<count;++output)
    std::copy_n(work.staged.data()+output*work.raw.size(),work.raw.size(),outputs[output].fields.data);
  ++metrics.evaluationCount;
  return WVKernelStatus::ok();
}

} // namespace wavevortex::runtime::detail
