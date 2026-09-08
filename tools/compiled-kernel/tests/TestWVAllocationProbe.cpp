#include "WVAllocationProbe.hpp"
#include <cstddef>
#include <cstdint>
#include <cstdio>

int main() {
    struct Family {
        void* (*allocate)();
        void (*release)(void*);
        std::size_t alignment;
    };
    const Family families[] = {
        {[] { return ::operator new(17, std::nothrow); },
         [](void* p) { ::operator delete(p); }, alignof(std::max_align_t)},
        {[] { return ::operator new[](17, std::nothrow); },
         [](void* p) { ::operator delete[](p); }, alignof(std::max_align_t)},
        {[] { return ::operator new(17, std::align_val_t{64}, std::nothrow); },
         [](void* p) { ::operator delete(p, std::align_val_t{64}); }, 64},
        {[] { return ::operator new[](17, std::align_val_t{64}, std::nothrow); },
         [](void* p) { ::operator delete[](p, std::align_val_t{64}); }, 64}
    };
    for (const auto& family : families) {
        allocationProbe::calls = 0;
        allocationProbe::counting = true;
        void* p = family.allocate();
        const bool counted = p && allocationProbe::calls == 1 &&
            reinterpret_cast<std::uintptr_t>(p) % family.alignment == 0;
        family.release(p);
        allocationProbe::failAfter = 0;
        p = family.allocate();
        const bool failed = !p && allocationProbe::calls == 2;
        family.release(p);
        allocationProbe::counting = false;
        allocationProbe::failAfter = -1;
        if (!counted || !failed) {
            std::fputs("Nothrow allocation bypassed counting or failure injection.\n", stderr);
            return 1;
        }
    }
}
