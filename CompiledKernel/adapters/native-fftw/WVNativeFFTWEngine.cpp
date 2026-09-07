#include "WVNativeFFTWEngine.hpp"

#include <fftw3.h>

#include <climits>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <mutex>
#include <limits>
#include <new>
#include <utility>
#include <vector>

#if defined(__APPLE__) || defined(__linux__)
#include <dlfcn.h>
#endif

namespace wavevortex {
namespace {

std::mutex planningMutex;
std::atomic<std::size_t> activePlans{0};
std::atomic<std::size_t> totalPlansCreated{0};
std::atomic<std::size_t> totalPlansDestroyed{0};
std::atomic<std::size_t> outstandingPlanningBytes{0};
std::atomic<std::uint64_t> totalPlanningNanoseconds{0};

WVKernelStatus dimensions(const std::vector<WVFFTDimension>& source, std::vector<fftw_iodim64>& destination) {
    destination.clear();
    destination.reserve(source.size());
    for (const auto& dimension : source) {
        if (dimension.count == 0 || dimension.count > static_cast<std::size_t>(PTRDIFF_MAX) ||
            dimension.inputStride <= 0 || dimension.outputStride <= 0) {
            return {WVKernelStatusCode::invalidConfiguration, "FFTW dimensions must be nonzero, fit ptrdiff_t, and have positive strides."};
        }
        destination.push_back({static_cast<ptrdiff_t>(dimension.count),dimension.inputStride,dimension.outputStride});
    }
    return WVKernelStatus::ok();
}

std::string libraryContaining(const void* symbol) {
#if defined(__APPLE__) || defined(__linux__)
    Dl_info information{};
    if (symbol != nullptr && dladdr(symbol,&information) != 0 && information.dli_fname != nullptr) return information.dli_fname;
#endif
    return {};
}

std::string loadedLibrary() { return libraryContaining(reinterpret_cast<const void*>(&fftw_execute)); }

// Validate actual addressed spans, not arena capacities: a vertical sine plan
// starts inside a larger shared arena and intentionally leaves boundary holes.
WVKernelStatus addressedBytes(const WVFFTPlanSpecification& spec, bool input, std::size_t& bytes) {
    const bool complex = input ? spec.kind == WVFFTPlanKind::horizontalComplexToReal2D
                               : spec.kind == WVFFTPlanKind::horizontalRealToComplex2D;
    const auto elementBytes = complex ? sizeof(fftw_complex) : sizeof(double);
    const auto maximum = static_cast<std::size_t>(PTRDIFF_MAX) / elementBytes;
    std::size_t elements = 1;
    auto add = [&](const WVFFTDimension& dimension, bool lastTransform) {
        const auto count = complex && lastTransform ? dimension.count / 2 + 1 : dimension.count;
        const auto stride = static_cast<std::size_t>(input ? dimension.inputStride : dimension.outputStride);
        if (count - 1 > (maximum - elements) / stride) return false;
        elements += (count - 1) * stride;
        return true;
    };
    for (std::size_t i = 0; i < spec.transformDimensions.size(); ++i)
        if (!add(spec.transformDimensions[i], i + 1 == spec.transformDimensions.size()))
            return {WVKernelStatusCode::sizeOverflow,"FFTW transform span overflows ptrdiff_t."};
    for (const auto& dimension : spec.batchDimensions)
        if (!add(dimension, false)) return {WVKernelStatusCode::sizeOverflow,"FFTW batch span overflows ptrdiff_t."};
    bytes = elements * elementBytes;
    if (bytes > (input ? spec.inputBytes : spec.outputBytes))
        return {WVKernelStatusCode::invalidShape,"FFTW addressed span exceeds the declared buffer size."};
    return WVKernelStatus::ok();
}

class PlanningBuffer final {
public:
    explicit PlanningBuffer(std::size_t bytes) : data_(fftw_malloc(bytes)), bytes_(bytes) {
        if (!data_) throw std::bad_alloc();
        outstandingPlanningBytes += bytes_;
    }
    ~PlanningBuffer() { fftw_free(data_); outstandingPlanningBytes -= bytes_; }
    PlanningBuffer(const PlanningBuffer&) = delete;
    PlanningBuffer& operator=(const PlanningBuffer&) = delete;
    void* get() const noexcept { return data_; }
private:
    void* data_;
    std::size_t bytes_;
};

struct PlanDeleter {
    void operator()(fftw_plan plan) const noexcept {
        std::lock_guard<std::mutex> lock(planningMutex);
        fftw_destroy_plan(plan);
        --activePlans;
        ++totalPlansDestroyed;
    }
};
using OwnedPlan = std::unique_ptr<fftw_plan_s, PlanDeleter>;

class FFTWPlan final : public WVFFTPlan {
public:
    FFTWPlan(OwnedPlan plan, WVFFTPlanKind kind, bool inPlace, std::size_t inputSpan, std::size_t outputSpan)
        : plan_(std::move(plan)), kind_(kind), inPlace_(inPlace), inputSpan_(inputSpan), outputSpan_(outputSpan) {}
    WVKernelStatus execute(const void* input, void* output) override {
        if (input == nullptr || output == nullptr) return {WVKernelStatusCode::invalidPointer,"FFTW received a null execution pointer."};
        const auto in = reinterpret_cast<std::uintptr_t>(input);
        const auto out = reinterpret_cast<std::uintptr_t>(output);
        if (inPlace_) {
            if (in != out) return {WVKernelStatusCode::invalidPointer,"An in-place FFTW plan requires identical pointers."};
        } else if (in <= out ? out - in < inputSpan_ : in - out < outputSpan_) {
            return {WVKernelStatusCode::overlappingArrays,"An out-of-place FFTW plan requires disjoint addressed spans."};
        }
        switch (kind_) {
            case WVFFTPlanKind::horizontalRealToComplex2D:
                fftw_execute_dft_r2c(plan_.get(),const_cast<double*>(static_cast<const double*>(input)),static_cast<fftw_complex*>(output));
                break;
            case WVFFTPlanKind::horizontalComplexToReal2D:
                fftw_execute_dft_c2r(plan_.get(),const_cast<fftw_complex*>(static_cast<const fftw_complex*>(input)),static_cast<double*>(output));
                break;
            case WVFFTPlanKind::verticalDCTI:
            case WVFFTPlanKind::verticalDSTI:
                fftw_execute_r2r(plan_.get(),const_cast<double*>(static_cast<const double*>(input)),static_cast<double*>(output));
                break;
        }
        return WVKernelStatus::ok();
    }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
private:
    OwnedPlan plan_;
    WVFFTPlanKind kind_;
    bool inPlace_;
    std::size_t inputSpan_, outputSpan_;
};

} // namespace

WVFFTWEngine::WVFFTWEngine(std::size_t threadCount, std::string loadedLibraryPath) : threadCount_(threadCount), loadedLibraryPath_(std::move(loadedLibraryPath)) {}

WVKernelStatus WVFFTWEngine::create(std::size_t threadCount, std::unique_ptr<WVFFTEngine>& engine) {
    if (threadCount == 0 || threadCount > static_cast<std::size_t>(INT_MAX)) return {WVKernelStatusCode::invalidConfiguration,"FFTW thread count must lie in [1,INT_MAX]."};
    std::lock_guard<std::mutex> lock(planningMutex);
    if (fftw_init_threads() == 0) return {WVKernelStatusCode::fftPlanFailure,"FFTW thread initialization failed."};
    try {
        engine = std::unique_ptr<WVFFTEngine>(new WVFFTWEngine(threadCount,loadedLibrary()));
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"Unable to allocate the FFTW engine."};
    }
}

WVFFTWLifetimeMetrics WVFFTWEngine::lifetimeMetrics() noexcept {
    return {activePlans.load(),totalPlansCreated.load(),totalPlansDestroyed.load(),outstandingPlanningBytes.load(),1e-9*static_cast<double>(totalPlanningNanoseconds.load())};
}

WVFFTWLibraryIdentity WVFFTWEngine::linkedLibraries(const std::string& expectedOpenMPRuntime) {
    WVFFTWLibraryIdentity identity;
    identity.version = fftw_version;
    identity.baseLibrary = loadedLibrary();
    identity.threadLibrary = libraryContaining(reinterpret_cast<const void*>(&fftw_init_threads));
#if defined(__APPLE__) || defined(__linux__)
    if (!expectedOpenMPRuntime.empty()) {
        void* handle = dlopen(expectedOpenMPRuntime.c_str(),RTLD_LAZY | RTLD_NOLOAD);
        if (handle != nullptr) {
            identity.openMPRuntimeLibrary = libraryContaining(dlsym(handle,"omp_get_max_threads"));
            dlclose(handle);
        }
    }
#endif
    return identity;
}

std::string WVFFTWEngine::identifier() const { return "fftw"; }

WVKernelStatus WVFFTWEngine::createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) {
    try {
        const bool horizontal = specification.kind == WVFFTPlanKind::horizontalRealToComplex2D ||
                                specification.kind == WVFFTPlanKind::horizontalComplexToReal2D;
        const bool vertical = specification.kind == WVFFTPlanKind::verticalDCTI ||
                              specification.kind == WVFFTPlanKind::verticalDSTI;
        if ((!horizontal && !vertical) || specification.transformDimensions.size() != (horizontal ? 2u : 1u) ||
            specification.batchDimensions.size() > static_cast<std::size_t>(INT_MAX))
            return {WVKernelStatusCode::invalidConfiguration,"FFTW requires rank-two horizontal or rank-one vertical transforms."};
        if (horizontal && specification.inPlace)
            return {WVKernelStatusCode::unsupportedOperation,"Padded in-place horizontal FFTW storage is not supported."};
        if (specification.kind == WVFFTPlanKind::horizontalComplexToReal2D && !specification.destroysInput)
            return {WVKernelStatusCode::unsupportedOperation,"FFTW cannot preserve multidimensional c2r input; prepare destructive scratch explicitly."};
        if (specification.kind == WVFFTPlanKind::verticalDCTI && specification.transformDimensions.front().count < 2)
            return {WVKernelStatusCode::invalidConfiguration,"DCT-I requires at least two elements."};
        if (specification.inPlace) {
            for (const auto& dimension : specification.transformDimensions)
                if (dimension.inputStride != dimension.outputStride)
                    return {WVKernelStatusCode::unsupportedOperation,"In-place FFTW strides must match."};
            for (const auto& dimension : specification.batchDimensions)
                if (dimension.inputStride != dimension.outputStride)
                    return {WVKernelStatusCode::unsupportedOperation,"In-place FFTW batch strides must match."};
        }
        std::vector<fftw_iodim64> transformDimensions, batchDimensions;
        auto status = dimensions(specification.transformDimensions,transformDimensions);
        if (!status) return status;
        status = dimensions(specification.batchDimensions,batchDimensions);
        if (!status) return status;
        std::size_t inputSpan = 0, outputSpan = 0;
        status = addressedBytes(specification,true,inputSpan);
        if (!status) return status;
        status = addressedBytes(specification,false,outputSpan);
        if (!status) return status;
        std::vector<fftw_r2r_kind> kinds(vertical ? 1 : 0,
            specification.kind == WVFFTPlanKind::verticalDCTI ? FFTW_REDFT00 : FFTW_RODFT00);
        PlanningBuffer input(specification.inputBytes);
        // Avoid a second allocation for in-place transforms.
        std::unique_ptr<PlanningBuffer> output;
        if (!specification.inPlace) output = std::make_unique<PlanningBuffer>(specification.outputBytes);
        void* outputData = output ? output->get() : input.get();
        OwnedPlan rawPlan;
        const auto planningStart = std::chrono::steady_clock::now();
        {
            std::lock_guard<std::mutex> lock(planningMutex);
            fftw_plan_with_nthreads(static_cast<int>(threadCount_));
            unsigned flags = FFTW_MEASURE | FFTW_UNALIGNED;
            if (!specification.inPlace && !specification.destroysInput) flags |= FFTW_PRESERVE_INPUT;
            const int rank = static_cast<int>(transformDimensions.size());
            const int howManyRank = static_cast<int>(batchDimensions.size());
            fftw_plan created = nullptr;
            switch (specification.kind) {
                case WVFFTPlanKind::horizontalRealToComplex2D:
                    created = fftw_plan_guru64_dft_r2c(rank,transformDimensions.data(),howManyRank,batchDimensions.data(),static_cast<double*>(input.get()),static_cast<fftw_complex*>(outputData),flags);
                    break;
                case WVFFTPlanKind::horizontalComplexToReal2D:
                    created = fftw_plan_guru64_dft_c2r(rank,transformDimensions.data(),howManyRank,batchDimensions.data(),static_cast<fftw_complex*>(input.get()),static_cast<double*>(outputData),flags);
                    break;
                case WVFFTPlanKind::verticalDCTI:
                case WVFFTPlanKind::verticalDSTI:
                    created = fftw_plan_guru64_r2r(rank,transformDimensions.data(),howManyRank,batchDimensions.data(),static_cast<double*>(input.get()),static_cast<double*>(outputData),kinds.data(),flags);
                    break;
            }
            // Ownership and accounting begin immediately, before wrapper allocation.
            rawPlan.reset(created);
            if (created) { ++activePlans; ++totalPlansCreated; }
        }
        totalPlanningNanoseconds.fetch_add(static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-planningStart).count()));
        if (!rawPlan) return {WVKernelStatusCode::fftPlanFailure,"FFTW was unable to create the requested guru plan."};
        plan = std::make_unique<FFTWPlan>(std::move(rawPlan),specification.kind,specification.inPlace,inputSpan,outputSpan);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"FFTW allocation failed."};
    }
}

} // namespace wavevortex
