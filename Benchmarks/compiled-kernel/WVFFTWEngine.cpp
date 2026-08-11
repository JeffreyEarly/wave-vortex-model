#include "WVFFTWEngine.hpp"

#include <fftw3.h>

#include <climits>
#include <atomic>
#include <cstdlib>
#include <mutex>
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

WVKernelStatus dimensions(const std::vector<WVFFTDimension>& source, std::vector<fftw_iodim64>& destination) {
    destination.clear();
    destination.reserve(source.size());
    for (const auto& dimension : source) {
        if (dimension.count == 0 || dimension.count > static_cast<std::size_t>(LLONG_MAX)) {
            return {WVKernelStatusCode::invalidConfiguration, "FFTW dimensions must be nonzero and fit fftw_iodim64."};
        }
        destination.push_back({static_cast<ptrdiff_t>(dimension.count),dimension.inputStride,dimension.outputStride});
    }
    return WVKernelStatus::ok();
}

std::string loadedLibrary() {
#if defined(__APPLE__) || defined(__linux__)
    Dl_info information{};
    if (dladdr(reinterpret_cast<const void*>(&fftw_execute),&information) != 0 && information.dli_fname != nullptr) return information.dli_fname;
#endif
    return {};
}

class FFTWPlan final : public WVFFTPlan {
public:
    FFTWPlan(fftw_plan plan, WVFFTPlanKind kind) : plan_(plan), kind_(kind) { ++activePlans; ++totalPlansCreated; }
    ~FFTWPlan() override {
        std::lock_guard<std::mutex> lock(planningMutex);
        if (plan_ != nullptr) fftw_destroy_plan(plan_);
        --activePlans;
        ++totalPlansDestroyed;
    }
    WVKernelStatus execute(const void* input, void* output) override {
        if (input == nullptr || output == nullptr) return {WVKernelStatusCode::invalidPointer,"FFTW received a null execution pointer."};
        switch (kind_) {
            case WVFFTPlanKind::horizontalRealToComplex2D:
                fftw_execute_dft_r2c(plan_,const_cast<double*>(static_cast<const double*>(input)),static_cast<fftw_complex*>(output));
                break;
            case WVFFTPlanKind::horizontalComplexToReal2D:
                fftw_execute_dft_c2r(plan_,const_cast<fftw_complex*>(static_cast<const fftw_complex*>(input)),static_cast<double*>(output));
                break;
            case WVFFTPlanKind::verticalDCTI:
            case WVFFTPlanKind::verticalDSTI:
                fftw_execute_r2r(plan_,const_cast<double*>(static_cast<const double*>(input)),static_cast<double*>(output));
                break;
        }
        return WVKernelStatus::ok();
    }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
private:
    fftw_plan plan_ = nullptr;
    WVFFTPlanKind kind_;
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
    return {activePlans.load(),totalPlansCreated.load(),totalPlansDestroyed.load(),outstandingPlanningBytes.load()};
}

std::string WVFFTWEngine::identifier() const { return "fftw"; }

WVKernelStatus WVFFTWEngine::createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) {
    std::vector<fftw_iodim64> transformDimensions;
    std::vector<fftw_iodim64> batchDimensions;
    auto status = dimensions(specification.transformDimensions,transformDimensions);
    if (!status) return status;
    status = dimensions(specification.batchDimensions,batchDimensions);
    if (!status) return status;
    void* input = fftw_malloc(specification.inputBytes);
    void* output = specification.inPlace ? input : fftw_malloc(specification.outputBytes);
    if (input == nullptr || output == nullptr) {
        if (input != nullptr) fftw_free(input);
        if (!specification.inPlace && output != nullptr) fftw_free(output);
        return {WVKernelStatusCode::allocationFailure,"Unable to allocate FFTW planning surrogates."};
    }
    const auto planningBytes = specification.inputBytes + (specification.inPlace ? 0 : specification.outputBytes);
    outstandingPlanningBytes += planningBytes;
    fftw_plan rawPlan = nullptr;
    {
        std::lock_guard<std::mutex> lock(planningMutex);
        fftw_plan_with_nthreads(static_cast<int>(threadCount_));
        constexpr unsigned flags = FFTW_MEASURE | FFTW_UNALIGNED;
        const int rank = static_cast<int>(transformDimensions.size());
        const int howManyRank = static_cast<int>(batchDimensions.size());
        switch (specification.kind) {
            case WVFFTPlanKind::horizontalRealToComplex2D:
                rawPlan = fftw_plan_guru64_dft_r2c(rank,transformDimensions.data(),howManyRank,batchDimensions.data(),static_cast<double*>(input),static_cast<fftw_complex*>(output),flags);
                break;
            case WVFFTPlanKind::horizontalComplexToReal2D:
                rawPlan = fftw_plan_guru64_dft_c2r(rank,transformDimensions.data(),howManyRank,batchDimensions.data(),static_cast<fftw_complex*>(input),static_cast<double*>(output),flags);
                break;
            case WVFFTPlanKind::verticalDCTI:
            case WVFFTPlanKind::verticalDSTI: {
                std::vector<fftw_r2r_kind> kinds(transformDimensions.size(),specification.kind == WVFFTPlanKind::verticalDCTI ? FFTW_REDFT00 : FFTW_RODFT00);
                rawPlan = fftw_plan_guru64_r2r(rank,transformDimensions.data(),howManyRank,batchDimensions.data(),static_cast<double*>(input),static_cast<double*>(output),kinds.data(),flags);
                break;
            }
        }
    }
    fftw_free(input);
    if (!specification.inPlace) fftw_free(output);
    outstandingPlanningBytes -= planningBytes;
    if (rawPlan == nullptr) return {WVKernelStatusCode::fftPlanFailure,"FFTW was unable to create the requested guru plan."};
    try {
        plan = std::make_unique<FFTWPlan>(rawPlan,specification.kind);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        fftw_destroy_plan(rawPlan);
        return {WVKernelStatusCode::allocationFailure,"Unable to retain the FFTW plan."};
    }
}

} // namespace wavevortex
