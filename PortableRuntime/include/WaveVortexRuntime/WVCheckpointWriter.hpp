#pragma once

#include "WaveVortexRuntime/WVCheckpointReader.hpp"

#include <string>

namespace wavevortex::runtime {

// Write one compatible root-level WaveVortexModel 4.x checkpoint.
//
// The writer validates and writes a same-directory temporary file, reads that
// file through WVCheckpointReader, and atomically replaces the destination only
// after every operation succeeds. On failure, an existing destination is
// unchanged and the temporary file is removed.
class WVCheckpointWriter final {
public:
    static WVCheckpointStatus write(
        const std::string& path,
        const WVCheckpoint& checkpoint);
};

} // namespace wavevortex::runtime
