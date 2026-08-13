#include "WaveVortexRuntime/WVFixedStepRK4.hpp"

#include <algorithm>
#include <cmath>
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

} // namespace

WVFixedStepRK4::WVFixedStepRK4(WVIntegrationSystem& system) : system_(system) {}

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
        metrics_.workspaceCapacityBytes = (stageState_.capacity()+stageFlux_.capacity()+weightedFlux_.capacity())*sizeof(WVComplex64);
        metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
        metrics_.workspaceMaximumLiveBytes = std::max(metrics_.workspaceMaximumLiveBytes,metrics_.workspaceLiveBytes);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"RK4 workspace allocation failed."};
    }
}

WVKernelStatus WVFixedStepRK4::prepareStateAfterRestart(WVMutableState& state) {
    hasAcceptedStep_ = false;
    const auto status = ensureWorkspace(state);
    if (!status) return status;
    return system_.enforceStateConstraints(state.coefficients);
}

void WVFixedStepRK4::setStageFromBase(const WVMutableState& base, double scale, const std::vector<WVComplex64>* increment) {
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
}

WVKernelStatus WVFixedStepRK4::evaluateStage(const WVMutableState& base, double stageTime, double scale, const std::vector<WVComplex64>* increment) {
    setStageFromBase(base,scale,increment);
    auto coefficients = coefficientViews(stageState_,shape_);
    auto status = system_.enforceStateConstraints(coefficients);
    if (!status) return status;
    std::fill(stageFlux_.begin(),stageFlux_.end(),WVComplex64{});
    metrics_.stageFluxClearElementWrites += stageFlux_.size();
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

    std::fill(weightedFlux_.begin(),weightedFlux_.end(),WVComplex64{});
    metrics_.weightedFluxClearElementWrites += weightedFlux_.size();
    const double initialTime = state.t;
    status = evaluateStage(state,state.t,0.0,nullptr);
    if (!status) return status;
    accumulateWeightedFlux(1.0);
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
    WVComplexView destinations[] = {state.coefficients.Ap,state.coefficients.Am,state.coefficients.A0};
    const double scale = deltaT/6.0;
    for (std::size_t component = 0; component < 3; ++component) {
        for (std::size_t index = 0; index < count; ++index) destinations[component].data[index] = addScaled(destinations[component].data[index],weightedFlux_[component*count+index],scale);
    }
    metrics_.finalStateUpdateElementReads += 6*count;
    metrics_.finalStateUpdateElementWrites += 3*count;
    state.t += deltaT;
    status = system_.enforceStateConstraints(state.coefficients);
    if (!status) return status;
    ++metrics_.stepCount;
    metrics_.lastStepSize = deltaT;
    acceptedStep_ = {initialTime,state.t,state.view(),{1,4,deltaT},nullptr};
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
