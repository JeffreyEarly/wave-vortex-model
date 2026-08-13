#include "WaveVortexRuntime/WVIntegrationDriver.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <limits>
#include <new>
#include <utility>

namespace wavevortex::runtime {
namespace {

double timeTolerance(double first, double second) noexcept {
    return 8.0*std::numeric_limits<double>::epsilon()*std::max({1.0,std::abs(first),std::abs(second)});
}

bool sameTime(double first, double second) noexcept {
    return std::abs(first-second) <= timeTolerance(first,second);
}

WVMutableState mutableStateView(std::vector<WVComplex64>& storage, WVShape2D shape, double time, double referenceTime) {
    const auto count = shape.elementCount();
    return {time,referenceTime,{{storage.data(),shape},{storage.data()+count,shape},{storage.data()+2*count,shape}}};
}

bool matchingShape(WVShape2D first, WVShape2D second) noexcept {
    return first.rows == second.rows && first.columns == second.columns;
}

} // namespace

WVOrderedOutputSchedule::WVOrderedOutputSchedule(std::vector<double> requestedTimes) : requestedTimes_(std::move(requestedTimes)) {}

WVKernelStatus WVOrderedOutputSchedule::reset(double initialTime, double finalTime) {
    nextIndex_ = 0;
    if (!std::isfinite(initialTime) || !std::isfinite(finalTime) || finalTime < initialTime) return {WVKernelStatusCode::invalidConfiguration,"Output schedule requires a finite, nondecreasing integration interval."};
    const double tolerance = timeTolerance(initialTime,finalTime);
    for (std::size_t index = 0; index < requestedTimes_.size(); ++index) {
        const double value = requestedTimes_[index];
        if (!std::isfinite(value)) return {WVKernelStatusCode::invalidConfiguration,"Output schedule times must be finite."};
        if (index > 0 && !(value > requestedTimes_[index-1])) return {WVKernelStatusCode::invalidConfiguration,"Output schedule times must be strictly increasing."};
        if (value < initialTime-tolerance || value > finalTime+tolerance) return {WVKernelStatusCode::invalidConfiguration,"Output schedule time lies outside the integration interval."};
    }
    return WVKernelStatus::ok();
}

bool WVOrderedOutputSchedule::nextTimeInInterval(double initialTime, double finalTime, double& outputTime) const noexcept {
    if (nextIndex_ >= requestedTimes_.size()) return false;
    const double value = requestedTimes_[nextIndex_];
    const double tolerance = timeTolerance(initialTime,finalTime);
    if (value < initialTime-tolerance || value > finalTime+tolerance) return false;
    outputTime = value;
    return true;
}

void WVOrderedOutputSchedule::consumeNextTime() noexcept {
    if (nextIndex_ < requestedTimes_.size()) ++nextIndex_;
}

WVIntegrationDriver::WVIntegrationDriver(WVTimeIntegrator& integrator) : integrator_(integrator) {}

WVKernelStatus WVIntegrationDriver::emit(WVIntegrationOutputSink::EventKind kind, const WVState& state, WVIntegrationOutputSink& sink, bool& terminate) {
    WVIntegrationOutputSink::Action action = WVIntegrationOutputSink::Action::continueIntegration;
    const auto status = sink.receive({kind,state},action);
    if (!status) return status;
    switch (kind) {
        case WVIntegrationOutputSink::EventKind::init: ++metrics_.initialEventCount; break;
        case WVIntegrationOutputSink::EventKind::interpolated: ++metrics_.interpolatedEventCount; break;
        case WVIntegrationOutputSink::EventKind::accepted: ++metrics_.acceptedEventCount; break;
        case WVIntegrationOutputSink::EventKind::done: ++metrics_.doneEventCount; break;
    }
    terminate = action == WVIntegrationOutputSink::Action::terminate;
    return WVKernelStatus::ok();
}

WVKernelStatus WVIntegrationDriver::emitDone(const WVState& acceptedState, WVIntegrationOutputSink& sink) {
    bool ignored = false;
    return emit(WVIntegrationOutputSink::EventKind::done,acceptedState,sink,ignored);
}

WVKernelStatus WVIntegrationDriver::ensureInterpolationStorage(WVShape2D shape) {
    if (matchingShape(interpolationShape_,shape) && interpolationStorage_.size() == 3*shape.elementCount()) return WVKernelStatus::ok();
    try {
        interpolationShape_ = shape;
        interpolationStorage_.resize(3*shape.elementCount());
        metrics_.interpolationBufferCapacityBytes = interpolationStorage_.capacity()*sizeof(WVComplex64);
        metrics_.interpolationBufferMaximumLiveBytes = std::max(metrics_.interpolationBufferMaximumLiveBytes,metrics_.interpolationBufferCapacityBytes);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"Integration-driver interpolation storage allocation failed."};
    }
}

WVKernelStatus WVIntegrationDriver::advanceToTime(WVMutableState& state, double finalTime, double stepSize, WVOutputSchedule& schedule, WVIntegrationOutputSink& sink) {
    if (running_) return {WVKernelStatusCode::reentrantExecution,"Integration-driver execution is not reentrant."};
    if (!std::isfinite(state.t) || !std::isfinite(finalTime) || !std::isfinite(stepSize) || stepSize <= 0.0 || finalTime < state.t) return {WVKernelStatusCode::invalidConfiguration,"Integration driver requires finite times, positive step size, and no backward integration."};
    auto status = schedule.reset(state.t,finalTime);
    if (!status) return status;

    running_ = true;
    struct Guard { bool& value; ~Guard() { value = false; } } guard{running_};
    bool terminate = false;
    status = emit(WVIntegrationOutputSink::EventKind::init,state.view(),sink,terminate);
    if (!status) return status;

    double requestedTime = 0.0;
    while (schedule.nextTimeInInterval(state.t,state.t,requestedTime) && sameTime(requestedTime,state.t)) schedule.consumeNextTime();
    if (terminate) return emitDone(state.view(),sink);

    while (state.t < finalTime && !sameTime(state.t,finalTime)) {
        const double currentStepSize = std::min(stepSize,finalTime-state.t);
        status = integrator_.step(state,currentStepSize);
        if (!status) return status;
        ++metrics_.acceptedStepCount;
        const auto* acceptedStep = integrator_.lastAcceptedStep();
        if (acceptedStep == nullptr) return {WVKernelStatusCode::numericalFailure,"Integrator succeeded without publishing its accepted step."};

        while (schedule.nextTimeInInterval(acceptedStep->initialTime,acceptedStep->finalTime,requestedTime)) {
            if (sameTime(requestedTime,acceptedStep->initialTime)) {
                schedule.consumeNextTime();
                continue;
            }
            if (sameTime(requestedTime,acceptedStep->finalTime)) {
                status = emit(WVIntegrationOutputSink::EventKind::accepted,acceptedStep->endpoint,sink,terminate);
            } else {
                if (acceptedStep->denseOutput == nullptr) return {WVKernelStatusCode::unsupportedOperation,"An interior output was requested from an integrator without dense output."};
                status = ensureInterpolationStorage(acceptedStep->endpoint.coefficients.Ap.shape);
                if (!status) return status;
                auto interpolationState = mutableStateView(interpolationStorage_,interpolationShape_,requestedTime,acceptedStep->endpoint.t0);
                const auto started = std::chrono::steady_clock::now();
                status = acceptedStep->denseOutput->evaluate(requestedTime,interpolationState);
                metrics_.interpolationSeconds += std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
                if (status) status = emit(WVIntegrationOutputSink::EventKind::interpolated,interpolationState.view(),sink,terminate);
            }
            if (!status) return status;
            schedule.consumeNextTime();
            if (terminate) return emitDone(acceptedStep->endpoint,sink);
        }
    }
    if (sameTime(state.t,finalTime)) state.t = finalTime;
    return emitDone(state.view(),sink);
}

WVCheckpointOutputSink::WVCheckpointOutputSink(double targetTime, std::string destination, WVCheckpoint checkpointTemplate)
    : targetTime_(targetTime), destination_(std::move(destination)), checkpoint_(std::move(checkpointTemplate)) {}

WVKernelStatus WVCheckpointOutputSink::receive(const Event& event, Action& action) {
    action = Action::continueIntegration;
    ++metrics_.receivedEventCount;
    if (!std::isfinite(targetTime_) || destination_.empty()) return {WVKernelStatusCode::invalidConfiguration,"Checkpoint output requires a finite target time and explicit destination."};
    if (event.kind == EventKind::done || !sameTime(event.state.t,targetTime_)) return WVKernelStatus::ok();
    if (wroteCheckpoint_) return {WVKernelStatusCode::invalidConfiguration,"Checkpoint output target was delivered more than once."};
    const auto shape = checkpoint_.state.coefficients.shape;
    if (!matchingShape(shape,event.state.coefficients.Ap.shape) || !matchingShape(shape,event.state.coefficients.Am.shape) || !matchingShape(shape,event.state.coefficients.A0.shape)) return {WVKernelStatusCode::invalidShape,"Checkpoint template and output state shapes differ."};
    const auto count = shape.elementCount();
    if (checkpoint_.state.coefficients.Ap.size() != count || checkpoint_.state.coefficients.Am.size() != count || checkpoint_.state.coefficients.A0.size() != count) return {WVKernelStatusCode::invalidShape,"Checkpoint template coefficient storage is incomplete."};
    const WVComplexConstView sources[] = {event.state.coefficients.Ap,event.state.coefficients.Am,event.state.coefficients.A0};
    std::vector<WVComplex64>* destinations[] = {&checkpoint_.state.coefficients.Ap,&checkpoint_.state.coefficients.Am,&checkpoint_.state.coefficients.A0};
    for (std::size_t component = 0; component < 3; ++component) std::copy_n(sources[component].data,count,destinations[component]->data());
    checkpoint_.state.t = event.state.t;
    checkpoint_.state.t0 = event.state.t0;
    const auto started = std::chrono::steady_clock::now();
    const auto writeStatus = WVCheckpointWriter::write(destination_,checkpoint_);
    metrics_.checkpointWriteSeconds += std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
    if (!writeStatus) return {WVKernelStatusCode::unsupportedOperation,"Checkpoint output failed at "+writeStatus.location+": "+writeStatus.message};
    wroteCheckpoint_ = true;
    ++metrics_.checkpointWriteCount;
    metrics_.copiedCoefficientBytes += 3*count*sizeof(WVComplex64);
    return WVKernelStatus::ok();
}

std::size_t WVCheckpointOutputSink::persistentBytes() const noexcept {
    return (checkpoint_.state.coefficients.Ap.capacity()+checkpoint_.state.coefficients.Am.capacity()+checkpoint_.state.coefficients.A0.capacity())*sizeof(WVComplex64)+destination_.capacity();
}

} // namespace wavevortex::runtime
