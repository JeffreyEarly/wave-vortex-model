#include "WaveVortexRuntime/WVAdaptiveRK23.hpp"

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

double magnitude(WVComplex64 value) noexcept { return std::hypot(value.real,value.imag); }

double timeTolerance(double first, double second) noexcept {
    return 8.0*std::numeric_limits<double>::epsilon()*std::max({1.0,std::abs(first),std::abs(second)});
}

const WVComplex64* component(const WVMutableState& state, std::size_t index) noexcept {
    return index == 0 ? state.coefficients.Ap.data : (index == 1 ? state.coefficients.Am.data : state.coefficients.A0.data);
}

WVComplex64* component(WVMutableCoefficients& coefficients, std::size_t index) noexcept {
    return index == 0 ? coefficients.Ap.data : (index == 1 ? coefficients.Am.data : coefficients.A0.data);
}

const WVComplex64* component(const WVMutableCoefficients& coefficients, std::size_t index) noexcept {
    return index == 0 ? coefficients.Ap.data : (index == 1 ? coefficients.Am.data : coefficients.A0.data);
}

} // namespace

WVAdaptiveRK23Controller::WVAdaptiveRK23Controller(WVAdaptiveRK23Options options) : options_(options) {}

WVKernelStatus WVAdaptiveRK23Controller::validate() const noexcept {
    if (!std::isfinite(options_.relativeTolerance) || options_.relativeTolerance <= 0.0 ||
        !std::isfinite(options_.absoluteToleranceScale) || options_.absoluteToleranceScale <= 0.0 ||
        !std::isfinite(options_.safetyFactor) || options_.safetyFactor <= 0.0 || options_.safetyFactor > 1.0 ||
        !std::isfinite(options_.minimumStepFactor) || options_.minimumStepFactor <= 0.0 || options_.minimumStepFactor >= 1.0 ||
        !std::isfinite(options_.maximumStepFactor) || options_.maximumStepFactor < 1.0 || options_.maximumStepFactor < options_.minimumStepFactor) {
        return {WVKernelStatusCode::invalidConfiguration,"Adaptive RK3(2) tolerances and controller factors are invalid."};
    }
    return WVKernelStatus::ok();
}

double WVAdaptiveRK23Controller::stepFactor(double normalizedError, bool accepted) const noexcept {
    double factor = options_.minimumStepFactor;
    if (normalizedError == 0.0) factor = options_.maximumStepFactor;
    else if (std::isfinite(normalizedError) && normalizedError > 0.0) factor = options_.safetyFactor*std::pow(normalizedError,-1.0/3.0);
    factor = std::max(options_.minimumStepFactor,std::min(options_.maximumStepFactor,factor));
    return accepted ? factor : std::min(1.0,factor);
}

WVAdaptiveRK23::WVAdaptiveRK23(WVIntegrationSystem& system, WVAdaptiveRK23Options options)
    : system_(system), controller_(options) {}

WVKernelStatus WVAdaptiveRK23::ensureWorkspace(const WVMutableState& state) {
    auto status = controller_.validate();
    if (!status) return status;
    const auto expected = system_.stateShape();
    if (!matchingShape(expected,state.coefficients.Ap) || !matchingShape(expected,state.coefficients.Am) || !matchingShape(expected,state.coefficients.A0)) {
        return {WVKernelStatusCode::invalidShape,"Adaptive RK3(2) state must use the integration system's canonical shape."};
    }
    if (!std::isfinite(state.t) || !std::isfinite(state.t0)) return {WVKernelStatusCode::invalidConfiguration,"Adaptive RK3(2) state times must be finite."};
    if (shape_.rows == expected.rows && shape_.columns == expected.columns && errorPolicy_ != nullptr) return WVKernelStatus::ok();
    try {
        shape_ = expected;
        const auto values = 3*shape_.elementCount();
        stageState_.resize(values);
        k1_.resize(values);
        k2_.resize(values);
        k3_.resize(values);
        k4_.resize(values);
        status = system_.createErrorPolicy(controller_.options().absoluteToleranceScale,errorPolicy_);
        if (!status) return status;
        if (errorPolicy_ == nullptr || errorPolicy_->componentCount() != 3) return {WVKernelStatusCode::invalidConfiguration,"Adaptive error policy must describe the three current coefficient components."};
        for (std::size_t componentIndex = 0; componentIndex < 3; ++componentIndex) {
            if (errorPolicy_->elementCount(componentIndex) != shape_.elementCount()) return {WVKernelStatusCode::invalidShape,"Adaptive error-policy shape does not match the coefficient state."};
        }
        metrics_.workspaceCapacityBytes = (stageState_.capacity()+k1_.capacity()+k2_.capacity()+k3_.capacity()+k4_.capacity())*sizeof(WVComplex64);
        metrics_.errorPolicyBytes = errorPolicy_->persistentBytes();
        metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
        metrics_.workspaceMaximumLiveBytes = std::max(metrics_.workspaceMaximumLiveBytes,metrics_.workspaceLiveBytes);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"Adaptive RK3(2) workspace allocation failed."};
    }
}

WVKernelStatus WVAdaptiveRK23::prepareStateAfterRestart(WVMutableState& state) {
    invalidateAttempt();
    metrics_.nextStepSize = 0.0;
    auto status = ensureWorkspace(state);
    if (!status) return status;
    const auto constraintResult = system_.enforceStateConstraints(state.coefficients);
    metrics_.constraintModifiedCoefficientCount += constraintResult.modifiedCoefficientCount;
    return constraintResult.status;
}

WVKernelStatus WVAdaptiveRK23::evaluateDerivative(const WVState& state, std::vector<WVComplex64>& destination) {
    auto output = fluxViews(destination,shape_);
    const auto status = system_.evaluateRightHandSide(state,output);
    if (status) ++metrics_.rightHandSideEvaluationCount;
    return status;
}

WVKernelStatus WVAdaptiveRK23::constructAndEvaluateStage(
    const WVMutableState& base,
    double stageTime,
    double stepSize,
    double weight1,
    const std::vector<WVComplex64>* derivative1,
    double weight2,
    const std::vector<WVComplex64>* derivative2,
    double weight3,
    const std::vector<WVComplex64>* derivative3,
    std::vector<WVComplex64>& destination,
    WVStateConstraintResult* reportedConstraintResult) {
    const auto count = shape_.elementCount();
    for (std::size_t componentIndex = 0; componentIndex < 3; ++componentIndex) {
        const auto* initial = component(base,componentIndex);
        for (std::size_t index = 0; index < count; ++index) {
            const auto flatIndex = componentIndex*count+index;
            double real = initial[index].real;
            double imag = initial[index].imag;
            if (derivative1 != nullptr) { real += stepSize*weight1*(*derivative1)[flatIndex].real; imag += stepSize*weight1*(*derivative1)[flatIndex].imag; }
            if (derivative2 != nullptr) { real += stepSize*weight2*(*derivative2)[flatIndex].real; imag += stepSize*weight2*(*derivative2)[flatIndex].imag; }
            if (derivative3 != nullptr) { real += stepSize*weight3*(*derivative3)[flatIndex].real; imag += stepSize*weight3*(*derivative3)[flatIndex].imag; }
            stageState_[flatIndex] = {real,imag};
        }
    }
    auto stageCoefficients = coefficientViews(stageState_,shape_);
    const auto constraintResult = system_.enforceStateConstraints(stageCoefficients);
    metrics_.constraintModifiedCoefficientCount += constraintResult.modifiedCoefficientCount;
    if (reportedConstraintResult != nullptr) *reportedConstraintResult = constraintResult;
    if (!constraintResult) return constraintResult.status;
    const WVState stage{stageTime,base.t0,{{stageCoefficients.Ap.data,shape_},{stageCoefficients.Am.data,shape_},{stageCoefficients.A0.data,shape_}}};
    return evaluateDerivative(stage,destination);
}

double WVAdaptiveRK23::normalizedError(const WVMutableState& initial, const WVMutableCoefficients& candidate, double stepSize) const noexcept {
    const auto count = shape_.elementCount();
    const double relativeTolerance = controller_.options().relativeTolerance;
    double maximum = 0.0;
    for (std::size_t componentIndex = 0; componentIndex < 3; ++componentIndex) {
        const auto* first = component(initial,componentIndex);
        const auto* last = component(candidate,componentIndex);
        for (std::size_t index = 0; index < count; ++index) {
            const auto flatIndex = componentIndex*count+index;
            const WVComplex64 error{
                stepSize*((-5.0/72.0)*k1_[flatIndex].real+(1.0/12.0)*k2_[flatIndex].real+(1.0/9.0)*k3_[flatIndex].real-(1.0/8.0)*k4_[flatIndex].real),
                stepSize*((-5.0/72.0)*k1_[flatIndex].imag+(1.0/12.0)*k2_[flatIndex].imag+(1.0/9.0)*k3_[flatIndex].imag-(1.0/8.0)*k4_[flatIndex].imag)};
            const double denominator = errorPolicy_->absoluteTolerance(componentIndex,index)+relativeTolerance*std::max(magnitude(first[index]),magnitude(last[index]));
            const double ratio = magnitude(error)/denominator;
            if (!std::isfinite(ratio)) return std::numeric_limits<double>::infinity();
            maximum = std::max(maximum,ratio);
        }
    }
    return maximum;
}

void WVAdaptiveRK23::invalidateAttempt() noexcept {
    hasAcceptedStep_ = false;
    fsalAvailable_ = false;
}

WVKernelStatus WVAdaptiveRK23::step(WVMutableState& state, double proposedStepSize) {
    if (stepping_) return {WVKernelStatusCode::reentrantExecution,"Adaptive RK3(2) stepping is not reentrant."};
    if (!std::isfinite(proposedStepSize) || proposedStepSize <= 0.0) return {WVKernelStatusCode::invalidConfiguration,"Adaptive RK3(2) proposed step must be finite and positive."};
    auto status = ensureWorkspace(state);
    if (!status) return status;
    hasAcceptedStep_ = false;
    stepping_ = true;
    struct Guard { bool& value; ~Guard() { value = false; } } guard{stepping_};
    const double initialTimeValue = state.t;
    double stepSize = proposedStepSize;
    bool initialDerivativeAvailable = false;
    if (fsalAvailable_) {
        std::swap(k1_,k4_);
        initialDerivativeAvailable = true;
        fsalAvailable_ = false;
        ++metrics_.fsalReuseCount;
    }
    std::size_t rejectedThisStep = 0;
    std::size_t evaluationsThisStep = 0;
    for (;;) {
        if (!std::isfinite(stepSize) || !(initialTimeValue+stepSize > initialTimeValue)) {
            invalidateAttempt();
            return {WVKernelStatusCode::numericalFailure,"Adaptive RK3(2) cannot advance time with the proposed step."};
        }
        if (!initialDerivativeAvailable) {
            const auto before = metrics_.rightHandSideEvaluationCount;
            status = evaluateDerivative(state.view(),k1_);
            evaluationsThisStep += metrics_.rightHandSideEvaluationCount-before;
            if (!status) { invalidateAttempt(); return status; }
            initialDerivativeAvailable = true;
        }
        auto before = metrics_.rightHandSideEvaluationCount;
        status = constructAndEvaluateStage(state,initialTimeValue+0.5*stepSize,stepSize,0.5,&k1_,0.0,nullptr,0.0,nullptr,k2_);
        evaluationsThisStep += metrics_.rightHandSideEvaluationCount-before;
        if (!status) { invalidateAttempt(); return status; }
        before = metrics_.rightHandSideEvaluationCount;
        status = constructAndEvaluateStage(state,initialTimeValue+0.75*stepSize,stepSize,0.75,&k2_,0.0,nullptr,0.0,nullptr,k3_);
        evaluationsThisStep += metrics_.rightHandSideEvaluationCount-before;
        if (!status) { invalidateAttempt(); return status; }
        WVStateConstraintResult endpointConstraint;
        before = metrics_.rightHandSideEvaluationCount;
        status = constructAndEvaluateStage(state,initialTimeValue+stepSize,stepSize,2.0/9.0,&k1_,1.0/3.0,&k2_,4.0/9.0,&k3_,k4_,&endpointConstraint);
        evaluationsThisStep += metrics_.rightHandSideEvaluationCount-before;
        if (!status) { invalidateAttempt(); return status; }
        auto candidate = coefficientViews(stageState_,shape_);
        const double error = normalizedError(state,candidate,stepSize);
        const bool accepted = std::isfinite(error) && error <= 1.0;
        const double factor = controller_.stepFactor(error,accepted);
        const double next = stepSize*factor;
        metrics_.lastNormalizedError = error;
        metrics_.lastProposedStepSize = proposedStepSize;
        if (accepted) {
            const auto count = shape_.elementCount();
            for (std::size_t componentIndex = 0; componentIndex < 3; ++componentIndex) {
                std::copy_n(component(candidate,componentIndex),count,component(state.coefficients,componentIndex));
            }
            state.t = initialTimeValue+stepSize;
            ++metrics_.acceptedStepCount;
            metrics_.lastAcceptedStepSize = stepSize;
            metrics_.nextStepSize = next;
            fsalAvailable_ = endpointConstraint.modifiedCoefficientCount == 0 && endpointConstraint.fsalCompatible;
            if (!fsalAvailable_) ++metrics_.fsalInvalidationCount;
            acceptedStep_ = {initialTimeValue,state.t,state.view(),{1,rejectedThisStep,evaluationsThisStep,stepSize,proposedStepSize,next,error},static_cast<const WVDenseOutput*>(this)};
            hasAcceptedStep_ = true;
            return WVKernelStatus::ok();
        }
        ++rejectedThisStep;
        ++metrics_.rejectedStepCount;
        ++metrics_.rejectedInitialDerivativeReuseCount;
        stepSize = next;
    }
}

WVKernelStatus WVAdaptiveRK23::advanceToTime(WVMutableState& state, double finalTimeValue, double initialStepSize) {
    if (!std::isfinite(finalTimeValue) || !std::isfinite(initialStepSize) || initialStepSize <= 0.0) return {WVKernelStatusCode::invalidConfiguration,"Adaptive final time and initial step must be finite, with a positive step."};
    if (finalTimeValue < state.t) return {WVKernelStatusCode::invalidConfiguration,"Adaptive RK3(2) cannot advance backward in time."};
    double proposal = initialStepSize;
    while (state.t < finalTimeValue) {
        const double remaining = finalTimeValue-state.t;
        const double boundedStep = std::min(proposal,remaining);
        if (!(boundedStep > 0.0)) break;
        const auto status = step(state,boundedStep);
        if (!status) return status;
        proposal = metrics_.nextStepSize;
        if (state.t > finalTimeValue || finalTimeValue-state.t <= timeTolerance(state.t,finalTimeValue)) state.t = finalTimeValue;
    }
    return WVKernelStatus::ok();
}

double WVAdaptiveRK23::initialTime() const noexcept { return hasAcceptedStep_ ? acceptedStep_.initialTime : 0.0; }
double WVAdaptiveRK23::finalTime() const noexcept { return hasAcceptedStep_ ? acceptedStep_.finalTime : 0.0; }
WVShape2D WVAdaptiveRK23::stateShape() const noexcept { return shape_; }

WVKernelStatus WVAdaptiveRK23::evaluate(double time, WVMutableState& output) const {
    if (!hasAcceptedStep_) return {WVKernelStatusCode::unsupportedOperation,"Adaptive RK3(2) dense output is unavailable before an accepted step."};
    if (evaluatingDenseOutput_) return {WVKernelStatusCode::reentrantExecution,"Adaptive RK3(2) dense-output evaluation is not reentrant."};
    if (!std::isfinite(time)) return {WVKernelStatusCode::invalidConfiguration,"Adaptive dense-output time must be finite."};
    if (!matchingShape(shape_,output.coefficients.Ap) || !matchingShape(shape_,output.coefficients.Am) || !matchingShape(shape_,output.coefficients.A0)) return {WVKernelStatusCode::invalidShape,"Adaptive dense-output storage must use the canonical shape."};
    const auto count = shape_.elementCount();
    const auto stateCount = 3*count;
    WVComplexView destinations[] = {output.coefficients.Ap,output.coefficients.Am,output.coefficients.A0};
    const std::vector<WVComplex64>* histories[] = {&stageState_,&k1_,&k2_,&k3_,&k4_};
    for (std::size_t first = 0; first < 3; ++first) {
        for (std::size_t second = first+1; second < 3; ++second) if (overlaps(destinations[first].data,count,destinations[second].data,count)) return {WVKernelStatusCode::overlappingArrays,"Adaptive dense-output component arrays must not overlap."};
        for (const auto* history : histories) if (overlaps(destinations[first].data,count,history->data(),stateCount)) return {WVKernelStatusCode::overlappingArrays,"Adaptive dense-output storage must not alias retained method state."};
        const WVComplexConstView endpoints[] = {acceptedStep_.endpoint.coefficients.Ap,acceptedStep_.endpoint.coefficients.Am,acceptedStep_.endpoint.coefficients.A0};
        for (const auto& endpoint : endpoints) if (overlaps(destinations[first].data,count,endpoint.data,count)) return {WVKernelStatusCode::overlappingArrays,"Adaptive dense-output storage must not alias the accepted endpoint."};
    }
    const double tolerance = timeTolerance(acceptedStep_.initialTime,acceptedStep_.finalTime);
    if (time < acceptedStep_.initialTime-tolerance || time > acceptedStep_.finalTime+tolerance) return {WVKernelStatusCode::invalidConfiguration,"Adaptive dense-output time lies outside the accepted interval."};
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
    const double weights[] = {
        theta-(4.0/3.0)*theta2+(5.0/9.0)*theta3-2.0/9.0,
        theta2-(2.0/3.0)*theta3-1.0/3.0,
        (4.0/3.0)*theta2-(8.0/9.0)*theta3-4.0/9.0,
        -theta2+theta3};
    const std::vector<WVComplex64>* derivatives[] = {&k1_,&k2_,&k3_,&k4_};
    const WVComplexConstView endpoints[] = {acceptedStep_.endpoint.coefficients.Ap,acceptedStep_.endpoint.coefficients.Am,acceptedStep_.endpoint.coefficients.A0};
    for (std::size_t componentIndex = 0; componentIndex < 3; ++componentIndex) {
        for (std::size_t index = 0; index < count; ++index) {
            const auto flatIndex = componentIndex*count+index;
            double real = endpoints[componentIndex].data[index].real;
            double imag = endpoints[componentIndex].data[index].imag;
            for (std::size_t derivative = 0; derivative < 4; ++derivative) {
                real += stepSize*weights[derivative]*(*derivatives[derivative])[flatIndex].real;
                imag += stepSize*weights[derivative]*(*derivatives[derivative])[flatIndex].imag;
            }
            destinations[componentIndex].data[index] = {real,imag};
        }
    }
    const auto constraintResult = system_.enforceStateConstraints(output.coefficients);
    if (!constraintResult) return constraintResult.status;
    output.t = theta == 0.0 ? acceptedStep_.initialTime : (theta == 1.0 ? acceptedStep_.finalTime : time);
    output.t0 = acceptedStep_.endpoint.t0;
    ++metrics_.denseOutputEvaluationCount;
    metrics_.denseOutputElementReads += 5*stateCount;
    metrics_.denseOutputElementWrites += stateCount;
    metrics_.denseOutputSeconds += std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
    return WVKernelStatus::ok();
}

} // namespace wavevortex::runtime
