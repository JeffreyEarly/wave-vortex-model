#include "WaveVortexRuntime/WVFixedStepRK4.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <limits>
#include <new>

namespace wavevortex::runtime {
namespace {

WVMutableCoefficients coefficientViews(std::vector<WVComplex64>& storage, WVShape2D shape) {
    const auto count = shape.elementCount();
    return {{storage.data(),shape},{storage.data()+count,shape},{storage.data()+2*count,shape}};
}

WVFlux fluxViews(std::vector<WVComplex64>& storage, WVShape2D shape) {
    const auto count = shape.elementCount();
    return {{storage.data(),shape},{storage.data()+count,shape},{storage.data()+2*count,shape}};
}

WVComplex64 addScaled(WVComplex64 value, WVComplex64 increment, double scale) noexcept {
    return {value.real+scale*increment.real,value.imag+scale*increment.imag};
}

bool matchingShape(WVShape2D expected, WVComplexView value) noexcept {
    return value.data != nullptr && value.shape.rows == expected.rows && value.shape.columns == expected.columns;
}

bool overlaps(const WVComplex64* first, std::size_t firstCount, const WVComplex64* second, std::size_t secondCount) noexcept {
    if (first == nullptr || second == nullptr || firstCount == 0 || secondCount == 0) return false;
    const auto firstBegin = reinterpret_cast<std::uintptr_t>(first);
    const auto firstEnd = firstBegin+firstCount*sizeof(WVComplex64);
    const auto secondBegin = reinterpret_cast<std::uintptr_t>(second);
    const auto secondEnd = secondBegin+secondCount*sizeof(WVComplex64);
    return firstBegin < secondEnd && secondBegin < firstEnd;
}

double timeTolerance(double first, double second) noexcept {
    return 8.0*std::numeric_limits<double>::epsilon()*std::max({1.0,std::abs(first),std::abs(second)});
}

} // namespace

WVFixedStepRK4::WVFixedStepRK4(WVIntegrationSystem& system, WVFixedStepRK4Options options) : system_(system), options_(options) {}

WVKernelStatus WVFixedStepRK4::ensureWorkspace(const WVMutableState& state) {
    const auto expected = system_.stateShape();
    if (!matchingShape(expected,state.coefficients.Ap) || !matchingShape(expected,state.coefficients.Am) || !matchingShape(expected,state.coefficients.A0)) {
        return {WVKernelStatusCode::invalidShape,"RK4 state must use the forcing engine's canonical [Nj,Nkl] shape."};
    }
    if (!std::isfinite(state.t) || !std::isfinite(state.t0)) return {WVKernelStatusCode::invalidConfiguration,"RK4 state times must be finite."};
    if (shape_.rows == expected.rows && shape_.columns == expected.columns) return WVKernelStatus::ok();
    try {
        shape_ = expected;
        const auto values = 3*shape_.elementCount();
        stageState_.resize(values);
        stageFlux_.resize(values);
        weightedFlux_.resize(values);
        if (options_.retainDenseOutput) denseHistory_.resize(values);
        metrics_.denseHistoryCapacityBytes = denseHistory_.capacity()*sizeof(WVComplex64);
        metrics_.workspaceCapacityBytes = (stageState_.capacity()+stageFlux_.capacity()+weightedFlux_.capacity()+denseHistory_.capacity())*sizeof(WVComplex64);
        metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
        metrics_.workspaceMaximumLiveBytes = std::max(metrics_.workspaceMaximumLiveBytes,metrics_.workspaceLiveBytes);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"RK4 workspace allocation failed."};
    }
}

WVKernelStatus WVFixedStepRK4::prepareStateAfterRestart(WVMutableState& state) {
    hasAcceptedStep_ = false;
    acceptedStateConstrained_ = false;
    const auto status = ensureWorkspace(state);
    if (!status) return status;
    const auto constraintStatus = system_.enforceStateConstraints(state.coefficients);
    acceptedStateConstrained_ = static_cast<bool>(constraintStatus);
    return constraintStatus;
}

double WVFixedStepRK4::initialTime() const noexcept {
    return hasAcceptedStep_ ? acceptedStep_.initialTime : 0.0;
}

double WVFixedStepRK4::finalTime() const noexcept {
    return hasAcceptedStep_ ? acceptedStep_.finalTime : 0.0;
}

WVShape2D WVFixedStepRK4::stateShape() const noexcept {
    return shape_;
}

WVKernelStatus WVFixedStepRK4::evaluate(double time, WVMutableState& output) const {
    if (!options_.retainDenseOutput || !hasAcceptedStep_) return {WVKernelStatusCode::unsupportedOperation,"RK4 dense output is unavailable for the requested accepted step."};
    if (evaluatingDenseOutput_) return {WVKernelStatusCode::reentrantExecution,"RK4 dense-output evaluation is not reentrant."};
    if (!std::isfinite(time)) return {WVKernelStatusCode::invalidConfiguration,"RK4 dense-output time must be finite."};
    if (!matchingShape(shape_,output.coefficients.Ap) || !matchingShape(shape_,output.coefficients.Am) || !matchingShape(shape_,output.coefficients.A0)) {
        return {WVKernelStatusCode::invalidShape,"RK4 dense-output storage must use the canonical [Nj,Nkl] shape."};
    }
    const auto componentCount = shape_.elementCount();
    const auto stateCount = 3*componentCount;
    WVComplexView destinations[] = {output.coefficients.Ap,output.coefficients.Am,output.coefficients.A0};
    for (std::size_t first = 0; first < 3; ++first) {
        for (std::size_t second = first+1; second < 3; ++second) {
            if (overlaps(destinations[first].data,componentCount,destinations[second].data,componentCount)) return {WVKernelStatusCode::overlappingArrays,"RK4 dense-output component arrays must not overlap."};
        }
        if (overlaps(destinations[first].data,componentCount,weightedFlux_.data(),stateCount) ||
            overlaps(destinations[first].data,componentCount,denseHistory_.data(),stateCount) ||
            overlaps(destinations[first].data,componentCount,stageFlux_.data(),stateCount)) {
            return {WVKernelStatusCode::overlappingArrays,"RK4 dense-output storage must not alias retained method state or the accepted endpoint."};
        }
        const WVComplexConstView endpoints[] = {acceptedStep_.endpoint.coefficients.Ap,acceptedStep_.endpoint.coefficients.Am,acceptedStep_.endpoint.coefficients.A0};
        for (const auto& endpoint : endpoints) {
            if (overlaps(destinations[first].data,componentCount,endpoint.data,componentCount)) return {WVKernelStatusCode::overlappingArrays,"RK4 dense-output storage must not alias retained method state or the accepted endpoint."};
        }
    }
    const double tolerance = timeTolerance(acceptedStep_.initialTime,acceptedStep_.finalTime);
    if (time < acceptedStep_.initialTime-tolerance || time > acceptedStep_.finalTime+tolerance) return {WVKernelStatusCode::invalidConfiguration,"RK4 dense-output time lies outside the accepted interval."};

    evaluatingDenseOutput_ = true;
    struct Guard { bool& value; ~Guard() { value = false; } } guard{evaluatingDenseOutput_};
    const auto started = std::chrono::steady_clock::now();
    const double stepSize = acceptedStep_.finalTime-acceptedStep_.initialTime;
    double theta = stepSize == 0.0 ? 0.0 : (time-acceptedStep_.initialTime)/stepSize;
    if (std::abs(time-acceptedStep_.initialTime) <= tolerance) theta = 0.0;
    if (std::abs(time-acceptedStep_.finalTime) <= tolerance) theta = 1.0;
    theta = std::max(0.0,std::min(1.0,theta));
    const double theta2 = theta*theta;
    const double theta3 = theta2*theta;
    const double endpointWeight = 3.0*theta2-2.0*theta3;
    const double initialWeight = 1.0-endpointWeight;
    const double initialSlopeWeight = stepSize*(theta-2.0*theta2+theta3);
    const double finalSlopeWeight = stepSize*(theta3-theta2);
    const WVComplexConstView endpoints[] = {acceptedStep_.endpoint.coefficients.Ap,acceptedStep_.endpoint.coefficients.Am,acceptedStep_.endpoint.coefficients.A0};
    for (std::size_t component = 0; component < 3; ++component) {
        for (std::size_t index = 0; index < componentCount; ++index) {
            const auto flatIndex = component*componentCount+index;
            const auto initial = weightedFlux_[flatIndex];
            const auto endpoint = endpoints[component].data[index];
            const auto initialSlope = denseHistory_[flatIndex];
            const auto finalSlope = stageFlux_[flatIndex];
            destinations[component].data[index] = {
                initialWeight*initial.real+endpointWeight*endpoint.real+initialSlopeWeight*initialSlope.real+finalSlopeWeight*finalSlope.real,
                initialWeight*initial.imag+endpointWeight*endpoint.imag+initialSlopeWeight*initialSlope.imag+finalSlopeWeight*finalSlope.imag};
        }
    }
    auto status = system_.enforceStateConstraints(output.coefficients);
    if (!status) return status;
    output.t = theta == 0.0 ? acceptedStep_.initialTime : (theta == 1.0 ? acceptedStep_.finalTime : time);
    output.t0 = acceptedStep_.endpoint.t0;
    ++metrics_.denseOutputEvaluationCount;
    metrics_.denseOutputElementReads += 4*stateCount;
    metrics_.denseOutputElementWrites += stateCount;
    metrics_.denseOutputSeconds += std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
    return WVKernelStatus::ok();
}

WVKernelStatus WVFixedStepRK4::evaluateAcceptedState(const WVMutableState& state) {
    auto flux = fluxViews(stageFlux_,shape_);
    const auto status = system_.evaluateRightHandSide(state.view(),flux);
    if (status) ++metrics_.rightHandSideEvaluationCount;
    return status;
}

void WVFixedStepRK4::setStageFromBase(const WVMutableState& base, double scale, const std::vector<WVComplex64>* increment) {
#if WV_RUNTIME_ENABLE_STAGE_TIMING
    const auto started = std::chrono::steady_clock::now();
#endif
    const auto count = shape_.elementCount();
    const WVComplexView sources[] = {base.coefficients.Ap,base.coefficients.Am,base.coefficients.A0};
    for (std::size_t component = 0; component < 3; ++component) {
        for (std::size_t index = 0; index < count; ++index) {
            const auto delta = increment == nullptr ? WVComplex64{} : (*increment)[component*count+index];
            stageState_[component*count+index] = addScaled(sources[component].data[index],delta,scale);
        }
    }
    const auto stateElementCount = 3*count;
    metrics_.stageStateConstructionElementReads += stateElementCount;
    if (increment != nullptr) metrics_.stageStateConstructionElementReads += stateElementCount;
    metrics_.stageStateConstructionElementWrites += stateElementCount;
#if WV_RUNTIME_ENABLE_STAGE_TIMING
    metrics_.stageStateConstructionSeconds += std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
#endif
}

WVKernelStatus WVFixedStepRK4::evaluateStage(const WVMutableState& base, double stageTime, double scale, const std::vector<WVComplex64>* increment) {
    setStageFromBase(base,scale,increment);
    auto coefficients = coefficientViews(stageState_,shape_);
    auto status = system_.enforceStateConstraints(coefficients);
    if (!status) return status;
    auto flux = fluxViews(stageFlux_,shape_);
    const WVState stage{stageTime,base.t0,{{coefficients.Ap.data,coefficients.Ap.shape},{coefficients.Am.data,coefficients.Am.shape},{coefficients.A0.data,coefficients.A0.shape}}};
    status = system_.evaluateRightHandSide(stage,flux);
    if (status) ++metrics_.rightHandSideEvaluationCount;
    return status;
}

void WVFixedStepRK4::accumulateWeightedFlux(double weight) {
    for (std::size_t index = 0; index < stageFlux_.size(); ++index) {
        weightedFlux_[index].real += weight*stageFlux_[index].real;
        weightedFlux_[index].imag += weight*stageFlux_[index].imag;
    }
    metrics_.weightedAccumulationElementReads += 2*stageFlux_.size();
    metrics_.weightedAccumulationElementWrites += stageFlux_.size();
}

WVKernelStatus WVFixedStepRK4::step(WVMutableState& state, double deltaT) {
    if (stepping_) return {WVKernelStatusCode::reentrantExecution,"RK4 stepping is not reentrant."};
    if (!std::isfinite(deltaT) || deltaT <= 0.0) return {WVKernelStatusCode::invalidConfiguration,"RK4 deltaT must be finite and positive."};
    auto status = ensureWorkspace(state);
    if (!status) return status;
    hasAcceptedStep_ = false;
    stepping_ = true;
    struct Guard { bool& value; ~Guard() { value = false; } } guard{stepping_};

    const double initialTime = state.t;
    status = acceptedStateConstrained_ ? evaluateAcceptedState(state) : evaluateStage(state,state.t,0.0,nullptr);
    if (!status) return status;
    if (options_.retainDenseOutput) std::copy(stageFlux_.begin(),stageFlux_.end(),denseHistory_.begin());
    std::copy(stageFlux_.begin(),stageFlux_.end(),weightedFlux_.begin());
    metrics_.weightedFluxInitializationElementReads += stageFlux_.size();
    metrics_.weightedFluxInitializationElementWrites += weightedFlux_.size();
    status = evaluateStage(state,state.t+0.5*deltaT,0.5*deltaT,&stageFlux_);
    if (!status) return status;
    accumulateWeightedFlux(2.0);
    status = evaluateStage(state,state.t+0.5*deltaT,0.5*deltaT,&stageFlux_);
    if (!status) return status;
    accumulateWeightedFlux(2.0);
    status = evaluateStage(state,state.t+deltaT,deltaT,&stageFlux_);
    if (!status) return status;
    accumulateWeightedFlux(1.0);

    const auto count = shape_.elementCount();
    auto candidate = coefficientViews(stageState_,shape_);
    WVComplexView sources[] = {state.coefficients.Ap,state.coefficients.Am,state.coefficients.A0};
    WVComplexView candidateDestinations[] = {candidate.Ap,candidate.Am,candidate.A0};
    const double scale = deltaT/6.0;
    for (std::size_t component = 0; component < 3; ++component) {
        for (std::size_t index = 0; index < count; ++index) candidateDestinations[component].data[index] = addScaled(sources[component].data[index],weightedFlux_[component*count+index],scale);
    }
    metrics_.finalStateUpdateElementReads += 6*count;
    metrics_.finalStateUpdateElementWrites += 3*count;
    status = system_.enforceStateConstraints(candidate);
    if (!status) return status;
    if (options_.retainDenseOutput) {
        for (std::size_t component = 0; component < 3; ++component) std::copy_n(sources[component].data,count,weightedFlux_.data()+component*count);
    }
    WVComplexView destinations[] = {state.coefficients.Ap,state.coefficients.Am,state.coefficients.A0};
    const WVComplexView acceptedSources[] = {{candidate.Ap.data,candidate.Ap.shape},{candidate.Am.data,candidate.Am.shape},{candidate.A0.data,candidate.A0.shape}};
    for (std::size_t component = 0; component < 3; ++component) std::copy_n(acceptedSources[component].data,count,destinations[component].data);
    metrics_.acceptedStateCommitElementReads += 3*count;
    metrics_.acceptedStateCommitElementWrites += 3*count;
    state.t += deltaT;
    acceptedStateConstrained_ = true;
    ++metrics_.stepCount;
    metrics_.lastStepSize = deltaT;
    acceptedStep_ = {initialTime,state.t,state.view(),{1,4,deltaT},options_.retainDenseOutput ? static_cast<const WVDenseOutput*>(this) : nullptr};
    hasAcceptedStep_ = true;
    return WVKernelStatus::ok();
}

WVKernelStatus WVFixedStepRK4::advanceToTime(WVMutableState& state, double finalTime, double deltaT) {
    if (!std::isfinite(finalTime) || !std::isfinite(deltaT) || deltaT <= 0.0) return {WVKernelStatusCode::invalidConfiguration,"Final time and positive deltaT must be finite."};
    if (finalTime < state.t) return {WVKernelStatusCode::invalidConfiguration,"RK4 cannot advance backward in time."};
    while (state.t < finalTime) {
        const double remaining = finalTime-state.t;
        const double stepSize = std::min(deltaT,remaining);
        if (!(stepSize > 0.0)) break;
        const auto status = step(state,stepSize);
        if (!status) return status;
        if (state.t > finalTime || finalTime-state.t <= 8.0*std::numeric_limits<double>::epsilon()*std::max(1.0,std::abs(finalTime))) state.t = finalTime;
    }
    return WVKernelStatus::ok();
}

} // namespace wavevortex::runtime
