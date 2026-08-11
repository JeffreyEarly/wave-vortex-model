#pragma once

#include "WaveVortexKernel/WVFFTEngine.hpp"

#include <cstddef>
#include <memory>
#include <string>

namespace wavevortex {

struct WVFFTWLifetimeMetrics {
    std::size_t activePlans = 0;
    std::size_t totalPlansCreated = 0;
    std::size_t totalPlansDestroyed = 0;
    std::size_t outstandingPlanningBytes = 0;
};

// Authoring-only FFTW implementation of the portable engine contract.
// FFTW is supplied by MATLAB and is never bundled here.
class WVFFTWEngine final : public WVFFTEngine {
public:
    static WVKernelStatus create(std::size_t threadCount, std::unique_ptr<WVFFTEngine>& engine);
    static WVFFTWLifetimeMetrics lifetimeMetrics() noexcept;

    std::string identifier() const override;
    std::string libraryIdentity() const override { return loadedLibraryPath_; }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) override;
    std::size_t threadCount() const noexcept { return threadCount_; }
    const std::string& loadedLibraryPath() const noexcept { return loadedLibraryPath_; }

private:
    WVFFTWEngine(std::size_t threadCount, std::string loadedLibraryPath);
    std::size_t threadCount_ = 1;
    std::string loadedLibraryPath_;
};

} // namespace wavevortex
