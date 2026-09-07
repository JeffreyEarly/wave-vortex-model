#pragma once

// Test executable allocation interposition. Counts application C++ allocation,
// including aligned allocation; FFTW's internal malloc is outside this ledger.
#include <atomic>
#include <cstdlib>
#include <new>

namespace allocationProbe {
inline std::atomic<bool> counting{false};
inline std::atomic<std::size_t> calls{0};
inline std::atomic<long> failAfter{-1};
inline void record() {
    if (counting.load()) ++calls;
    auto remaining = failAfter.load();
    if (remaining >= 0 && failAfter.fetch_sub(1) == 0) throw std::bad_alloc();
}
}
