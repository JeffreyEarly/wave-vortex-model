#pragma once
#include "WVSpectralOperators.hpp"

namespace wavevortex {
enum class WVVariableSpectralSchedule {
    establishedInterleaved,
    compactSplitFusedViews
};

// Execution policy only: canonical coefficients, modal records and scientific
// contracts are independent of execution scheduling. Kernel constructors retain
// the established path; eligible native runners may supply a qualified schedule.
struct WVVariableExecutionOptions {
    WVRetainedHorizontalSchedule horizontalSchedule = WVRetainedHorizontalSchedule::fullFFT;
    std::size_t horizontalWorkers = 1;
    bool streamedNonlinear = false;
    // The candidate compact variable path owns split-complex operator storage
    // and passes direct family views between vertical and horizontal services.
    // This remains explicit for direct kernel callers.
    WVVariableSpectralSchedule spectralSchedule = WVVariableSpectralSchedule::establishedInterleaved;
    // Prepared pointwise workers partition independent physical-grid cells.
    // The default preserves established serial arithmetic for direct kernel callers.
    std::size_t pointwiseWorkers = 1;
    bool usesCompactSplitViews() const noexcept {
        return spectralSchedule==WVVariableSpectralSchedule::compactSplitFusedViews;
    }
};
} // namespace wavevortex
