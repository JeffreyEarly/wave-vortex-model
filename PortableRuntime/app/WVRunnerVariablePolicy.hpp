#pragma once

#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexKernel/WVVariableExecutionOptions.hpp"

#include <cstddef>
#include <string_view>

namespace wavevortex::runtime::cli {

enum class WVRunnerMatrixBackend {
    scalar,
    accelerate
};

struct WVRunnerHostTopology {
    std::size_t logicalWorkers = 1;
    std::size_t performanceWorkers = 1;
};

struct WVRunnerVariablePolicy {
    bool buildEnabled = false;
    bool variableTransform = false;
    bool compact = false;
    WVPersistedTransformKind transformKind = WVPersistedTransformKind::constantStratification;
    WVRunnerMatrixBackend matrixBackend = WVRunnerMatrixBackend::scalar;
    WVVariableExecutionOptions execution;
    std::size_t effectiveFFTThreads = 1;
    std::string_view selection = "build-disabled";
};

WVRunnerHostTopology runnerHostTopology() noexcept;

WVRunnerVariablePolicy selectRunnerVariablePolicy(
    bool buildEnabled,
    WVPersistedTransformKind transformKind,
    std::string_view provider,
    std::size_t fftThreads,
    bool hasRequestedThreads,
    WVRunnerHostTopology topology) noexcept;

const char* runnerMatrixBackendIdentifier(WVRunnerMatrixBackend) noexcept;
const char* runnerTransformKindIdentifier(WVPersistedTransformKind) noexcept;
const char* runnerSpectralScheduleIdentifier(WVVariableSpectralSchedule) noexcept;
const char* runnerHorizontalScheduleIdentifier(WVRetainedHorizontalSchedule) noexcept;

} // namespace wavevortex::runtime::cli
