#pragma once

#include "WaveVortexKernel/WVForcingSchedule.hpp"
#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace wavevortex::runtime {

// Version of the reader contract. This identifier is not written into 4.x files.
inline constexpr std::uint32_t WVCheckpointProfileVersion = 1;
inline constexpr const char* WVCheckpointProfileIdentifier = "wave-vortex-4x-v1";

enum class WVCheckpointStatusCode : std::uint32_t {
    success = 0,
    openFailure,
    netcdfFailure,
    missingAttribute,
    missingDimension,
    missingVariable,
    missingComplexPartner,
    unsupportedModelVersion,
    unsupportedTransform,
    typeMismatch,
    shapeMismatch,
    invalidValue,
    ambiguousState,
    stateIndexOutOfRange,
    descriptorFailure,
    unsupportedForcing,
    malformedForcing,
    duplicateForcing,
    incompatibleForcing,
    writeFailure,
    commitFailure
};

struct WVCheckpointStatus {
    WVCheckpointStatusCode code = WVCheckpointStatusCode::success;
    std::string message;
    std::string location;

    explicit operator bool() const noexcept { return code == WVCheckpointStatusCode::success; }
    static WVCheckpointStatus ok() { return {}; }
};

enum class WVCheckpointStateSelectionKind : std::uint8_t {
    latest,
    index
};

struct WVCheckpointStateSelection {
    WVCheckpointStateSelectionKind kind = WVCheckpointStateSelectionKind::latest;
    std::size_t index = 0;

    static WVCheckpointStateSelection latest() noexcept { return {}; }
    static WVCheckpointStateSelection atIndex(std::size_t value) noexcept {
        return {WVCheckpointStateSelectionKind::index, value};
    }
};

// Owned canonical coefficient storage. The first dimension, Nj, is adjacent.
struct WVCheckpointCoefficients {
    WVShape2D shape;
    std::vector<WVComplex64> Ap;
    std::vector<WVComplex64> Am;
    std::vector<WVComplex64> A0;

    WVCoefficients view() const noexcept;
};

// One selected checkpoint state and its coefficient reference time.
struct WVCheckpointState {
    double t = 0.0;
    double t0 = 0.0;
    WVCheckpointCoefficients coefficients;

    WVState view() const noexcept;
};

// Identity of one existing annotated forcing record. Parameter decoding is separate.
struct WVCheckpointForcingHeader {
    std::size_t ordinal = 0;
    std::string groupPath;
    std::string annotatedClass;
};

// Source and selection details retained for diagnostics and compatibility decisions.
struct WVCheckpointMetadata {
    std::string profileIdentifier = WVCheckpointProfileIdentifier;
    std::uint32_t profileVersion = WVCheckpointProfileVersion;
    std::string modelVersion;
    std::string transformClass;
    std::string stateGroupPath;
    std::size_t selectedStateIndex = 0;
    std::size_t stateCount = 0;
    std::vector<WVCheckpointForcingHeader> forcingHeaders;
};

// Complete owning result needed to rebuild the portable constant-stratification core.
struct WVCheckpoint {
    WVTransformConstantStratificationConfiguration configuration;
    WVCheckpointState state;
    WVCheckpointMetadata metadata;
    WVFrozenForcingSchedule forcingSchedule;
};

// Read and structurally validate existing WaveVortexModel 4.x NetCDF checkpoints.
class WVCheckpointReader final {
public:
    // On failure, checkpoint is unchanged and all NetCDF handles are closed.
    static WVCheckpointStatus read(
        const std::string& path,
        WVCheckpoint& checkpoint,
        WVCheckpointStateSelection selection = WVCheckpointStateSelection::latest());
};

} // namespace wavevortex::runtime
