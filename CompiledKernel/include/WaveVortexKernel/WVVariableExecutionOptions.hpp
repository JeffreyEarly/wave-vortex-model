#pragma once
#include "WVSpectralOperators.hpp"

namespace wavevortex {
enum class WVVariableSpectralSchedule {
    establishedInterleaved,
    compactSplitFusedViews
};

// Execution policy only: canonical coefficients, modal records and scientific
// contracts are independent of this experimental schedule. Defaults retain the
// established path until complete-workload qualification justifies adoption.
struct WVVariableExecutionOptions {
    WVRetainedHorizontalSchedule horizontalSchedule = WVRetainedHorizontalSchedule::fullFFT;
    std::size_t horizontalWorkers = 1;
    bool streamedNonlinear = false;
    // The candidate compact variable path owns split-complex operator storage
    // and passes direct family views between vertical and horizontal services.
    // This remains explicit while complete variable workloads are qualified.
    WVVariableSpectralSchedule spectralSchedule = WVVariableSpectralSchedule::establishedInterleaved;
    // Prepared pointwise workers partition independent physical-grid cells.
    // The default preserves established serial arithmetic until calibration.
    std::size_t pointwiseWorkers = 1;
    bool usesCompactSplitViews() const noexcept {
        return spectralSchedule==WVVariableSpectralSchedule::compactSplitFusedViews;
    }
};
} // namespace wavevortex
