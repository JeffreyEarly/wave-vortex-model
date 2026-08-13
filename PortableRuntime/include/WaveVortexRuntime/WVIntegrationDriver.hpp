#pragma once

#include "WaveVortexRuntime/WVCheckpointWriter.hpp"
#include "WaveVortexRuntime/WVIntegrationContracts.hpp"

#include <cstddef>
#include <string>
#include <vector>

namespace wavevortex::runtime {

// Finite, strictly increasing output times for one integration interval. The
// entire sequence is validated by reset() before integration or output begins.
class WVOrderedOutputSchedule final : public WVOutputSchedule {
public:
    explicit WVOrderedOutputSchedule(std::vector<double> requestedTimes);

    WVKernelStatus reset(double initialTime, double finalTime) override;
    bool nextTimeInInterval(double initialTime, double finalTime, double& outputTime) const noexcept override;
    void consumeNextTime() noexcept override;

    std::size_t requestCount() const noexcept { return requestedTimes_.size(); }
    std::size_t consumedCount() const noexcept { return nextIndex_; }

private:
    std::vector<double> requestedTimes_;
    std::size_t nextIndex_ = 0;
};

struct WVIntegrationDriverMetrics {
    std::size_t acceptedStepCount = 0;
    std::size_t initialEventCount = 0;
    std::size_t interpolatedEventCount = 0;
    std::size_t acceptedEventCount = 0;
    std::size_t doneEventCount = 0;
    std::size_t interpolationBufferCapacityBytes = 0;
    std::size_t interpolationBufferMaximumLiveBytes = 0;
    double interpolationSeconds = 0.0;
};

// Method-neutral fixed-step integration and scheduled-observation driver.
// Requested output never truncates a solver step and interpolated state never
// becomes accepted state. The interpolation buffer is allocated lazily only
// when a true interior output is requested.
class WVIntegrationDriver final {
public:
    explicit WVIntegrationDriver(WVTimeIntegrator& integrator);

    WVKernelStatus advanceToTime(
        WVMutableState& state,
        double finalTime,
        double stepSize,
        WVOutputSchedule& schedule,
        WVIntegrationOutputSink& sink);

    const WVIntegrationDriverMetrics& metrics() const noexcept { return metrics_; }
    std::size_t persistentBytes() const noexcept { return interpolationStorage_.capacity()*sizeof(WVComplex64); }

private:
    WVKernelStatus emit(WVIntegrationOutputSink::EventKind kind, const WVState& state, WVIntegrationOutputSink& sink, bool& terminate);
    WVKernelStatus emitDone(const WVState& acceptedState, WVIntegrationOutputSink& sink);
    WVKernelStatus ensureInterpolationStorage(WVShape2D shape);

    WVTimeIntegrator& integrator_;
    WVShape2D interpolationShape_;
    std::vector<WVComplex64> interpolationStorage_;
    WVIntegrationDriverMetrics metrics_;
    bool running_ = false;
};

struct WVCheckpointOutputSinkMetrics {
    std::size_t receivedEventCount = 0;
    std::size_t checkpointWriteCount = 0;
    std::size_t copiedCoefficientBytes = 0;
    double checkpointWriteSeconds = 0.0;
};

// Transactional sink for one explicit output time and destination. Multi-file
// naming and public CLI scheduling intentionally remain outside this contract.
class WVCheckpointOutputSink final : public WVIntegrationOutputSink {
public:
    WVCheckpointOutputSink(double targetTime, std::string destination, WVCheckpoint checkpointTemplate);

    WVKernelStatus receive(const Event& event, Action& action) override;

    bool wroteCheckpoint() const noexcept { return wroteCheckpoint_; }
    const WVCheckpointOutputSinkMetrics& metrics() const noexcept { return metrics_; }
    std::size_t persistentBytes() const noexcept;

private:
    double targetTime_ = 0.0;
    std::string destination_;
    WVCheckpoint checkpoint_;
    WVCheckpointOutputSinkMetrics metrics_;
    bool wroteCheckpoint_ = false;
};

struct WVCheckpointOutputTarget {
    double requestedTime = 0.0;
    std::string destination;
};

struct WVCheckpointOutputRecord {
    std::size_t ordinal = 0;
    double requestedTime = 0.0;
    double emittedTime = 0.0;
    WVIntegrationOutputSink::EventKind eventKind = WVIntegrationOutputSink::EventKind::accepted;
    std::string destination;
    double writeSeconds = 0.0;
    bool committed = false;
    std::string failure;
};

struct WVCheckpointSeriesOutputSinkMetrics {
    std::size_t receivedEventCount = 0;
    std::size_t checkpointWriteCount = 0;
    std::size_t copiedCoefficientBytes = 0;
    double checkpointWriteSeconds = 0.0;
};

// Create a collision-safe series of scalar MATLAB-compatible checkpoints.
// One checkpoint-sized staging buffer is reused for every requested time.
class WVCheckpointSeriesOutputSink final : public WVIntegrationOutputSink {
public:
    WVCheckpointSeriesOutputSink(
        std::vector<WVCheckpointOutputTarget> targets,
        WVCheckpoint checkpointTemplate);

    WVKernelStatus receive(const Event& event, Action& action) override;

    bool wroteAllCheckpoints() const noexcept { return nextTarget_ == targets_.size(); }
    const std::vector<WVCheckpointOutputTarget>& targets() const noexcept { return targets_; }
    const std::vector<WVCheckpointOutputRecord>& records() const noexcept { return records_; }
    const WVCheckpointSeriesOutputSinkMetrics& metrics() const noexcept { return metrics_; }
    std::size_t persistentBytes() const noexcept;

private:
    std::vector<WVCheckpointOutputTarget> targets_;
    WVCheckpoint checkpoint_;
    std::vector<WVCheckpointOutputRecord> records_;
    WVCheckpointSeriesOutputSinkMetrics metrics_;
    std::size_t nextTarget_ = 0;
};

} // namespace wavevortex::runtime
