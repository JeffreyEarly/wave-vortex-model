#include "WVFFTWPhaseShiftConvolution.hpp"

#include <fftw3.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <climits>
#include <cmath>
#include <cstdint>
#include <new>
#include <stdexcept>
#include <vector>

namespace wavevortex {
namespace {

using Clock = std::chrono::steady_clock;
constexpr double pi = 3.141592653589793238462643383279502884;
std::atomic<std::size_t> activePlans{0};
std::atomic<std::size_t> totalPlansCreated{0};
std::atomic<std::size_t> totalPlansDestroyed{0};

WVComplex64 multiply(WVComplex64 first, WVComplex64 second) {
    return {first.real*second.real-first.imag*second.imag,first.real*second.imag+first.imag*second.real};
}

WVComplex64 multiply(WVComplex64 value, double scale) { return {value.real*scale,value.imag*scale}; }
WVComplex64 conjugate(WVComplex64 value) { return {value.real,-value.imag}; }
WVComplex64 phase(double angle) { return {std::cos(angle),std::sin(angle)}; }

std::size_t positiveRemainder(std::int64_t value, std::size_t modulus) {
    const auto signedModulus = static_cast<std::int64_t>(modulus);
    const auto remainder = value % signedModulus;
    return static_cast<std::size_t>(remainder < 0 ? remainder+signedModulus : remainder);
}

class PlanOwner {
public:
    PlanOwner() = default;
    explicit PlanOwner(fftw_plan plan) : plan_(plan) {
        if (plan_ != nullptr) {
            ++activePlans;
            ++totalPlansCreated;
        }
    }
    ~PlanOwner() { reset(); }
    PlanOwner(const PlanOwner&) = delete;
    PlanOwner& operator=(const PlanOwner&) = delete;
    PlanOwner(PlanOwner&& other) noexcept : plan_(other.plan_) { other.plan_ = nullptr; }
    PlanOwner& operator=(PlanOwner&& other) noexcept {
        if (this != &other) {
            reset();
            plan_ = other.plan_;
            other.plan_ = nullptr;
        }
        return *this;
    }
    fftw_plan get() const noexcept { return plan_; }

private:
    void reset() noexcept {
        if (plan_ == nullptr) return;
        fftw_destroy_plan(plan_);
        plan_ = nullptr;
        --activePlans;
        ++totalPlansDestroyed;
    }
    fftw_plan plan_ = nullptr;
};

class PhaseShiftEngine final : public WVHorizontalConvolutionEngine {
public:
    PhaseShiftEngine(const WVTransformConstantStratificationDescriptor& descriptor, std::size_t threadCount) : threadCount_(threadCount) {
        const auto planningStart = Clock::now();
        const auto& configuration = descriptor.configuration();
        for (const auto& mode : descriptor.fourierModes()) {
            geometry_.maximumKMode = std::max(geometry_.maximumKMode,static_cast<std::size_t>(std::abs(mode.kMode)));
            geometry_.maximumLMode = std::max(geometry_.maximumLMode,static_cast<std::size_t>(std::abs(mode.lMode)));
        }
        geometry_.hermitianKCount = geometry_.maximumKMode+1;
        geometry_.centeredLCount = 2*geometry_.maximumLMode+1;
        geometry_.verticalLevelCount = configuration.Nz;
        geometry_.outputCount = configuration.isHydrostatic ? 3 : 4;
        geometry_.inputCount = 3+4*geometry_.outputCount;
        realNx_ = 2*geometry_.maximumKMode+1;
        realNy_ = 2*geometry_.maximumLMode+1;
        if (realNx_ > static_cast<std::size_t>(INT_MAX) || realNy_ > static_cast<std::size_t>(INT_MAX)) throw std::overflow_error("Phase-shift grid dimensions exceed FFTW integer limits.");
        storage_.resize(geometry_.inputCount*geometry_.elementsPerChannel());
        frequencyWork_.resize(geometry_.hermitianKCount*realNy_);
        realInputs_.resize(geometry_.inputCount*realNx_*realNy_);
        realProducts_.resize(geometry_.outputCount*realNx_*realNy_);

        fftw_plan_with_nthreads(static_cast<int>(threadCount_));
        inversePlan_ = PlanOwner(fftw_plan_dft_c2r_2d(
            static_cast<int>(realNy_),static_cast<int>(realNx_),
            reinterpret_cast<fftw_complex*>(frequencyWork_.data()),realInputs_.data(),FFTW_MEASURE|FFTW_UNALIGNED));
        forwardPlan_ = PlanOwner(fftw_plan_dft_r2c_2d(
            static_cast<int>(realNy_),static_cast<int>(realNx_),
            realProducts_.data(),reinterpret_cast<fftw_complex*>(frequencyWork_.data()),FFTW_MEASURE|FFTW_UNALIGNED));
        if (inversePlan_.get() == nullptr || forwardPlan_.get() == nullptr) throw std::runtime_error("FFTW could not create the phase-shift convolution plans.");

        metrics_.retainedSpectrumBytes = storage_.capacity()*sizeof(WVComplex64);
        metrics_.exactWorkBytes = frequencyWork_.capacity()*sizeof(WVComplex64)
            + (realInputs_.capacity()+realProducts_.capacity())*sizeof(double);
        metrics_.planWrapperLowerBoundBytes = 2*sizeof(PlanOwner);
        metrics_.outerOpenMPThreads = 1;
        metrics_.maximumFFTWThreads = threadCount_;
        metrics_.workerRegionsDisjoint = true;
        metrics_.centeredInnerLength = realNy_;
        metrics_.centeredInputFactor = 1;
        metrics_.centeredPaddedFactor = 1;
        metrics_.hermitianInnerLength = realNx_;
        metrics_.hermitianInputFactor = 1;
        metrics_.hermitianPaddedFactor = 1;
        metrics_.planningSeconds = std::chrono::duration<double>(Clock::now()-planningStart).count();
    }

    const char* identifier() const noexcept override { return "phase-shift-tensor4"; }
    const WVHorizontalConvolutionGeometry& geometry() const noexcept override { return geometry_; }
    WVComplex64* channelData(std::size_t channel) noexcept override { return storage_.data()+channel*geometry_.elementsPerChannel(); }
    const WVComplex64* channelData(std::size_t channel) const noexcept override { return storage_.data()+channel*geometry_.elementsPerChannel(); }

    WVKernelStatus execute() override {
        const auto start = Clock::now();
        const std::array<std::array<double,2>,4> shifts{{{{0.0,0.0}},{{0.5,0.0}},{{0.0,0.5}},{{0.5,0.5}}}};
        const auto points = realNx_*realNy_;
        const auto scale = 1.0/(static_cast<double>(points)*static_cast<double>(shifts.size()));
        for (std::size_t output = 0; output < geometry_.outputCount; ++output) {
            std::fill(channelData(output),channelData(output)+geometry_.elementsPerChannel(),WVComplex64{});
        }
        for (std::size_t z = 0; z < geometry_.verticalLevelCount; ++z) {
            for (const auto& shift : shifts) {
                for (std::size_t channel = geometry_.outputCount; channel < geometry_.inputCount; ++channel) {
                    fillShiftedFrequency(channel,z,shift[0],shift[1]);
                    fftw_execute_dft_c2r(inversePlan_.get(),reinterpret_cast<fftw_complex*>(frequencyWork_.data()),realInputs_.data()+channel*points);
                }
                const auto shared = geometry_.outputCount;
                for (std::size_t output = 0; output < geometry_.outputCount; ++output) {
                    const auto derivative = geometry_.outputCount+3+3*output;
                    auto* product = realProducts_.data()+output*points;
                    const auto* U = realInputs_.data()+shared*points;
                    const auto* V = realInputs_.data()+(shared+1)*points;
                    const auto* W = realInputs_.data()+(shared+2)*points;
                    const auto* dx = realInputs_.data()+derivative*points;
                    const auto* dy = realInputs_.data()+(derivative+1)*points;
                    const auto* dz = realInputs_.data()+(derivative+2)*points;
                    for (std::size_t point = 0; point < points; ++point) product[point] = -(U[point]*dx[point]+V[point]*dy[point]+W[point]*dz[point]);
                    fftw_execute_dft_r2c(forwardPlan_.get(),product,reinterpret_cast<fftw_complex*>(frequencyWork_.data()));
                    accumulateInverseShiftedOutput(output,z,shift[0],shift[1],scale);
                }
            }
        }
        metrics_.executionSeconds += std::chrono::duration<double>(Clock::now()-start).count();
        ++metrics_.executionCount;
        return WVKernelStatus::ok();
    }

    std::size_t persistentBytes() const noexcept override {
        return metrics_.retainedSpectrumBytes+metrics_.exactWorkBytes+metrics_.planWrapperLowerBoundBytes;
    }
    WVHorizontalConvolutionMetrics metrics() const noexcept override { return metrics_; }

private:
    std::size_t storageIndex(std::size_t k, std::int64_t l, std::size_t z) const {
        const auto centeredL = static_cast<std::size_t>(l+static_cast<std::int64_t>(geometry_.maximumLMode));
        return k+geometry_.hermitianKCount*centeredL+geometry_.elementsPerLevel()*z;
    }

    std::size_t frequencyIndex(std::size_t k, std::int64_t l) const {
        return k+geometry_.hermitianKCount*positiveRemainder(l,realNy_);
    }

    WVComplex64 storedInput(std::size_t channel, std::size_t k, std::int64_t l, std::size_t z) const {
        if (k == 0 && l < 0) return conjugate(channelData(channel)[storageIndex(0,-l,z)]);
        auto value = channelData(channel)[storageIndex(k,l,z)];
        if (k == 0 && l == 0) value.imag = 0.0;
        return value;
    }

    void fillShiftedFrequency(std::size_t channel, std::size_t z, double shiftX, double shiftY) {
        std::fill(frequencyWork_.begin(),frequencyWork_.end(),WVComplex64{});
        const auto maximumL = static_cast<std::int64_t>(geometry_.maximumLMode);
        for (std::int64_t l = -maximumL; l <= maximumL; ++l) for (std::size_t k = 0; k <= geometry_.maximumKMode; ++k) {
            const auto angle = 2.0*pi*(static_cast<double>(k)*shiftX/static_cast<double>(realNx_)+static_cast<double>(l)*shiftY/static_cast<double>(realNy_));
            frequencyWork_[frequencyIndex(k,l)] = multiply(storedInput(channel,k,l,z),phase(angle));
        }
    }

    void accumulateInverseShiftedOutput(std::size_t output, std::size_t z, double shiftX, double shiftY, double scale) {
        const auto maximumL = static_cast<std::int64_t>(geometry_.maximumLMode);
        for (std::int64_t l = -maximumL; l <= maximumL; ++l) for (std::size_t k = 0; k <= geometry_.maximumKMode; ++k) {
            const auto angle = -2.0*pi*(static_cast<double>(k)*shiftX/static_cast<double>(realNx_)+static_cast<double>(l)*shiftY/static_cast<double>(realNy_));
            const auto value = multiply(multiply(frequencyWork_[frequencyIndex(k,l)],phase(angle)),scale);
            auto& destination = channelData(output)[storageIndex(k,l,z)];
            destination.real += value.real;
            destination.imag += value.imag;
        }
    }

    std::size_t threadCount_ = 1;
    std::size_t realNx_ = 0;
    std::size_t realNy_ = 0;
    WVHorizontalConvolutionGeometry geometry_;
    std::vector<WVComplex64> storage_;
    std::vector<WVComplex64> frequencyWork_;
    std::vector<double> realInputs_;
    std::vector<double> realProducts_;
    PlanOwner inversePlan_;
    PlanOwner forwardPlan_;
    WVHorizontalConvolutionMetrics metrics_;
};

} // namespace

WVFFTWPhaseShiftConvolutionFactory::WVFFTWPhaseShiftConvolutionFactory(std::size_t threadCount) : threadCount_(threadCount) {}

WVKernelStatus WVFFTWPhaseShiftConvolutionFactory::create(const WVTransformConstantStratificationDescriptor& descriptor, std::unique_ptr<WVHorizontalConvolutionEngine>& engine) {
    if (threadCount_ == 0 || threadCount_ > 16 || threadCount_ > static_cast<std::size_t>(INT_MAX)) return {WVKernelStatusCode::invalidConfiguration,"Phase-shift thread count must lie in [1,16]."};
    try {
        engine = std::make_unique<PhaseShiftEngine>(descriptor,threadCount_);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"Unable to allocate phase-shift convolution state."};
    } catch (const std::overflow_error& exception) {
        return {WVKernelStatusCode::sizeOverflow,exception.what()};
    } catch (const std::exception& exception) {
        return {WVKernelStatusCode::fftPlanFailure,exception.what()};
    }
}

WVPhaseShiftLifetimeMetrics WVFFTWPhaseShiftConvolutionFactory::lifetimeMetrics() noexcept {
    return {activePlans.load(),totalPlansCreated.load(),totalPlansDestroyed.load()};
}

} // namespace wavevortex
