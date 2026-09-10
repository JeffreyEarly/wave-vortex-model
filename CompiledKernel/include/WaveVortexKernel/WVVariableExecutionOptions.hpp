#pragma once
#include "WVSpectralOperators.hpp"

namespace wavevortex {
// Execution policy only: canonical coefficients, modal records and scientific
// contracts are independent of this experimental schedule. Defaults retain the
// established path until complete-workload qualification justifies adoption.
struct WVVariableExecutionOptions {
    WVRetainedHorizontalSchedule horizontalSchedule = WVRetainedHorizontalSchedule::fullFFT;
    std::size_t horizontalWorkers = 1;
    bool streamedNonlinear = false;
};
} // namespace wavevortex
