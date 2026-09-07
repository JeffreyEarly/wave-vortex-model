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
void* operator new(std::size_t n) {
    allocationProbe::record();
    if (auto p = std::malloc(n ? n : 1)) return p;
    throw std::bad_alloc();
}
void* operator new[](std::size_t n) { return ::operator new(n); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
void operator delete(void* p, std::size_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t) noexcept { std::free(p); }
void* operator new(std::size_t n, std::align_val_t alignment) {
    allocationProbe::record();
    void* p = nullptr;
    if (posix_memalign(&p, static_cast<std::size_t>(alignment), n ? n : 1)) throw std::bad_alloc();
    return p;
}
void* operator new[](std::size_t n, std::align_val_t a) { return ::operator new(n, a); }
void operator delete(void* p, std::align_val_t) noexcept { std::free(p); }
void operator delete[](void* p, std::align_val_t) noexcept { std::free(p); }
void operator delete(void* p, std::size_t, std::align_val_t) noexcept { std::free(p); }
void operator delete[](void* p, std::size_t, std::align_val_t) noexcept { std::free(p); }
