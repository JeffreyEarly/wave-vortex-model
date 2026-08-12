#include "WVFFTWPlusPlusConvolution.hpp"

#include "convolve.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <climits>
#include <cstdint>
#include <new>
#include <stdexcept>
#include <utility>
#include <vector>

#include <omp.h>

namespace wavevortex {
namespace {

using Clock = std::chrono::steady_clock;

std::atomic<std::uint64_t> multiplierNanoseconds{0};
std::atomic<std::size_t> maximumMultiplierThreads{1};
std::atomic<std::size_t> maximumOpenMPLevel{0};

void updateMaximum(std::atomic<std::size_t>& destination, std::size_t value) {
    auto observed = destination.load();
    while (observed < value && !destination.compare_exchange_weak(observed,value)) {}
}

void waveVortexMultiplier(Complex** values, std::size_t count, fftwpp::Indices* indices, std::size_t threads) {
    const auto start = Clock::now();
    const auto inputCount = indices->fft->app.A;
    const auto outputCount = indices->fft->app.B;
    if (!((inputCount == 15 && outputCount == 3) || (inputCount == 19 && outputCount == 4))) throw std::invalid_argument("Unsupported WaveVortex MIMO convolution arity.");
    const auto sharedInputOffset = outputCount;
    updateMaximum(maximumMultiplierThreads,static_cast<std::size_t>(omp_get_num_threads()));
    updateMaximum(maximumOpenMPLevel,static_cast<std::size_t>(omp_get_active_level()));
    auto operation = [&](std::size_t index) {
        double* arrays[19]{};
        for (std::size_t channel = 0; channel < inputCount; ++channel) arrays[channel] = reinterpret_cast<double*>(values[channel]);
        const double U = arrays[sharedInputOffset][index];
        const double V = arrays[sharedInputOffset + 1][index];
        const double W = arrays[sharedInputOffset + 2][index];
        double outputs[4]{};
        for (std::size_t target = 0; target < outputCount; ++target) {
            const auto first = sharedInputOffset + 3 + 3 * target;
            outputs[target] = -(U * arrays[first][index] + V * arrays[first + 1][index] + W * arrays[first + 2][index]);
        }
        for (std::size_t target = 0; target < outputCount; ++target) arrays[target][index] = outputs[target];
        for (std::size_t channel = outputCount; channel < inputCount; ++channel) arrays[channel][index] = 0.0;
    };
    if (threads > 1) {
#pragma omp parallel for num_threads(threads)
        for (std::ptrdiff_t index = 0; index < static_cast<std::ptrdiff_t>(count); ++index) {
            updateMaximum(maximumMultiplierThreads,static_cast<std::size_t>(omp_get_num_threads()));
            updateMaximum(maximumOpenMPLevel,static_cast<std::size_t>(omp_get_active_level()));
            operation(static_cast<std::size_t>(index));
        }
    } else {
        for (std::size_t index = 0; index < count; ++index) operation(index);
    }
    multiplierNanoseconds.fetch_add(static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now() - start).count()));
}

class FFTWPlusPlusEngine final : public WVHorizontalConvolutionEngine {
public:
    FFTWPlusPlusEngine(const WVTransformConstantStratificationDescriptor& descriptor, std::string variant, std::size_t threadCount) : variant_(std::move(variant)), threadCount_(threadCount) {
        const auto planningStart = Clock::now();
        const auto& configuration = descriptor.configuration();
        for (const auto& mode : descriptor.fourierModes()) {
            geometry_.maximumKMode = std::max(geometry_.maximumKMode,static_cast<std::size_t>(std::abs(mode.kMode)));
            geometry_.maximumLMode = std::max(geometry_.maximumLMode,static_cast<std::size_t>(std::abs(mode.lMode)));
        }
        geometry_.hermitianKCount = geometry_.maximumKMode + 1;
        geometry_.centeredLCount = 2 * (geometry_.maximumLMode + 1);
        geometry_.verticalLevelCount = configuration.Nz;
        geometry_.outputCount = configuration.isHydrostatic ? 3 : 4;
        // FFTW++ permits the first B input arrays to be overwritten by B outputs
        // while later implicit residues still need every physical input. Reserve
        // B sacrificial output arrays ahead of the shared velocity and derivative
        // channels so the common inputs remain intact throughout the convolution.
        geometry_.inputCount = 3 + 4 * geometry_.outputCount;
        if (geometry_.maximumKMode >= static_cast<std::size_t>(configuration.Nx / 2) || geometry_.maximumLMode >= static_cast<std::size_t>(configuration.Ny / 2)) throw std::invalid_argument("Retained convolution geometry must exclude padded Nyquist modes.");
        storage_.resize(geometry_.inputCount * geometry_.elementsPerChannel());
        pointers_.resize(geometry_.inputCount);

        fftwpp::fftw::maxthreads = threadCount_;
        omp_set_dynamic(0);
        omp_set_max_active_levels(1);
        omp_set_num_threads(static_cast<int>(threadCount_));
        const auto centeredKCount = 2 * (geometry_.maximumKMode + 1);
        const auto innerX = variant_ == "fftwpp-implicit" ? geometry_.centeredLCount / 2 : geometry_.centeredLCount / 2 + 1;
        const auto innerY = variant_ == "fftwpp-implicit" ? centeredKCount / 2 : centeredKCount / 2 + 1;
        // The pinned FFTW++ source must include the issue #152 two-loop
        // scheduler repair before named asymmetric output counts are safe.
        const auto applicationOutputCount = geometry_.outputCount;
        appX_ = std::make_unique<fftwpp::Application>(geometry_.inputCount,applicationOutputCount,fftwpp::multNone,threadCount_,false,innerX,1,0);
        fftX_ = std::make_unique<fftwpp::fftPadCentered>(geometry_.centeredLCount,configuration.Ny,*appX_,geometry_.hermitianKCount,geometry_.hermitianKCount);
        appY_ = std::make_unique<fftwpp::Application>(geometry_.inputCount,applicationOutputCount,waveVortexMultiplier,*appX_,innerY,2,0);
        fftY_ = std::make_unique<fftwpp::fftPadHermitian>(centeredKCount,configuration.Nx,*appY_);
        convolution_ = std::make_unique<fftwpp::Convolution2>(fftX_.get(),fftY_.get());
        metrics_.centeredInnerLength = fftX_->m;
        metrics_.centeredInputFactor = fftX_->p;
        metrics_.centeredPaddedFactor = fftX_->q;
        metrics_.centeredLogicalPadding = fftX_->m * fftX_->p - fftX_->L;
        metrics_.hermitianInnerLength = fftY_->m;
        metrics_.hermitianInputFactor = fftY_->p;
        metrics_.hermitianPaddedFactor = fftY_->q;
        metrics_.hermitianLogicalPadding = fftY_->m * fftY_->p - fftY_->L;
        metrics_.physicalInputTransformCount = geometry_.inputCount - geometry_.outputCount;
        metrics_.sacrificialInputTransformCount = geometry_.outputCount;
        metrics_.outputTransformCount = geometry_.outputCount;
        const bool nonExplicit = fftX_->p != fftX_->q && fftY_->p != fftY_->q;
        const bool actualImplicit = nonExplicit && metrics_.centeredLogicalPadding == 0 && metrics_.hermitianLogicalPadding == 0;
        const bool actualHybrid = nonExplicit && (metrics_.centeredLogicalPadding > 0 || metrics_.hermitianLogicalPadding > 0);
        if ((variant_ == "fftwpp-implicit" && !actualImplicit) || (variant_ == "fftwpp-hybrid" && !actualHybrid)) throw std::invalid_argument("FFTW++ did not construct the requested implicit/hybrid padding schedule.");
        metrics_.retainedSpectrumBytes = storage_.capacity() * sizeof(WVComplex64);
        const auto workX = geometry_.inputCount * fftX_->outputSize() + fftX_->workSizeW() + applicationOutputCount * fftX_->workSizeV();
        const auto workY = geometry_.inputCount * fftY_->outputSize() + fftY_->workSizeW() + applicationOutputCount * fftY_->workSizeV();
        metrics_.exactWorkBytes = (workX + convolution_->Threads() * workY) * sizeof(Complex);
        metrics_.planWrapperLowerBoundBytes = sizeof(*this) + sizeof(*appX_) + sizeof(*appY_) + sizeof(*fftX_) + sizeof(*fftY_) + sizeof(*convolution_);
        metrics_.outerOpenMPThreads = convolution_->Threads();
        metrics_.maximumFFTWThreads = std::max(fftX_->Threads(),fftY_->Threads());
        const auto yThreads = convolution_->convolvey[0]->fft->Threads();
        metrics_.maximumFFTWThreads = std::max(metrics_.maximumFFTWThreads,yThreads);
        metrics_.workerRegionsDisjoint = convolution_->Threads() == 1 || yThreads == 1;
        metrics_.planningSeconds = std::chrono::duration<double>(Clock::now() - planningStart).count();
    }

    const char* identifier() const noexcept override { return variant_.c_str(); }
    const WVHorizontalConvolutionGeometry& geometry() const noexcept override { return geometry_; }
    WVComplex64* channelData(std::size_t channel) noexcept override { return storage_.data() + channel * geometry_.elementsPerChannel(); }
    const WVComplex64* channelData(std::size_t channel) const noexcept override { return storage_.data() + channel * geometry_.elementsPerChannel(); }

    WVKernelStatus execute() override {
        if (!metrics_.workerRegionsDisjoint || metrics_.outerOpenMPThreads > threadCount_ || metrics_.maximumFFTWThreads > threadCount_) return {WVKernelStatusCode::invalidConfiguration,"FFTW++ worker regions overlap or exceed the configured hardware-thread cap."};
        const auto multiplierBefore = multiplierNanoseconds.load();
        const auto start = Clock::now();
        for (std::size_t z = 0; z < geometry_.verticalLevelCount; ++z) {
            for (std::size_t channel = 0; channel < geometry_.inputCount; ++channel) {
                auto* base = reinterpret_cast<Complex*>(channelData(channel) + z * geometry_.elementsPerLevel());
                fftwpp::HermitianSymmetrizeX(geometry_.maximumLMode + 1,geometry_.hermitianKCount,geometry_.centeredLCount / 2,base);
                pointers_[channel] = base;
            }
            convolution_->convolve(pointers_.data());
        }
        metrics_.executionSeconds += std::chrono::duration<double>(Clock::now() - start).count();
        metrics_.multiplierSeconds += 1e-9 * static_cast<double>(multiplierNanoseconds.load() - multiplierBefore);
        metrics_.maximumObservedMultiplierThreads = maximumMultiplierThreads.load();
        metrics_.maximumObservedOpenMPLevel = maximumOpenMPLevel.load();
        metrics_.workerRegionsDisjoint = metrics_.workerRegionsDisjoint && metrics_.maximumObservedOpenMPLevel <= 1 && metrics_.maximumObservedMultiplierThreads <= threadCount_;
        ++metrics_.executionCount;
        return WVKernelStatus::ok();
    }

    std::size_t persistentBytes() const noexcept override { return metrics_.retainedSpectrumBytes + metrics_.exactWorkBytes + metrics_.planWrapperLowerBoundBytes; }
    WVHorizontalConvolutionMetrics metrics() const noexcept override { return metrics_; }

private:
    std::string variant_;
    std::size_t threadCount_ = 1;
    WVHorizontalConvolutionGeometry geometry_;
    std::vector<WVComplex64> storage_;
    std::vector<Complex*> pointers_;
    std::unique_ptr<fftwpp::Application> appX_;
    std::unique_ptr<fftwpp::Application> appY_;
    std::unique_ptr<fftwpp::fftPadCentered> fftX_;
    std::unique_ptr<fftwpp::fftPadHermitian> fftY_;
    std::unique_ptr<fftwpp::Convolution2> convolution_;
    WVHorizontalConvolutionMetrics metrics_;
};

} // namespace

WVFFTWPlusPlusConvolutionFactory::WVFFTWPlusPlusConvolutionFactory(std::string variant, std::size_t threadCount) : variant_(std::move(variant)), threadCount_(threadCount) {}

WVKernelStatus WVFFTWPlusPlusConvolutionFactory::create(const WVTransformConstantStratificationDescriptor& descriptor, std::unique_ptr<WVHorizontalConvolutionEngine>& engine) {
    if (variant_ != "fftwpp-implicit" && variant_ != "fftwpp-hybrid") return {WVKernelStatusCode::invalidConfiguration,"FFTW++ variant must be fftwpp-implicit or fftwpp-hybrid."};
    if (threadCount_ == 0 || threadCount_ > 16 || threadCount_ > static_cast<std::size_t>(INT_MAX)) return {WVKernelStatusCode::invalidConfiguration,"FFTW++ thread count must lie in [1,16]."};
    try {
        engine = std::make_unique<FFTWPlusPlusEngine>(descriptor,variant_,threadCount_);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"Unable to allocate FFTW++ convolution state."};
    } catch (const std::exception& exception) {
        return {WVKernelStatusCode::fftPlanFailure,exception.what()};
    }
}

} // namespace wavevortex
