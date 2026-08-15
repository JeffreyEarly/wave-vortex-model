#pragma once

#include "WaveVortexRuntime/WVObserverContracts.hpp"

#include <cstddef>
#include <string>
#include <vector>

namespace wavevortex::runtime {

struct WVAdditionalStateBlockLayout {
  std::string identifier;
  WVStateScalarType scalarType = WVStateScalarType::real64;
  std::vector<std::size_t> dimensions;
  WVToleranceKind toleranceKind = WVToleranceKind::uniformAbsolute;
  double absoluteTolerance = 0.0;
  WVStateOwnership ownership = WVStateOwnership::integratorOwned;
  WVRestartRequirement restartRequirement =
      WVRestartRequirement::requiredDynamicState;
  std::size_t elementCount = 0;
  std::size_t scalarOffset = 0;
};

// Resolves identifiers and offsets once so numerical stages use ordered views
// without virtual dispatch or repeated name lookup. The originating state and
// observer records remain available for exact cross-boundary compatibility
// checks.
class WVIntegrationStateLayout final {
public:
  static WVKernelStatus createCoefficientOnly(WVShape2D coefficientShape,
                                              WVIntegrationStateLayout &layout);
  static WVKernelStatus create(WVShape2D coefficientShape,
                               const WVPortableObserverDescriptor &descriptor,
                               WVIntegrationStateLayout &layout);
  WVShape2D coefficientShape() const noexcept { return coefficientShape_; }
  const std::vector<WVAdditionalStateBlockLayout> &
  additionalBlocks() const noexcept {
    return additionalBlocks_;
  }
  const std::vector<WVStateBlockRecord> &stateBlockRecords() const noexcept {
    return stateBlockRecords_;
  }
  const std::vector<WVObserverRecord> &observerRecords() const noexcept {
    return observerRecords_;
  }
  std::size_t realElementCount() const noexcept { return realElementCount_; }
  std::size_t complexElementCount() const noexcept {
    return complexElementCount_;
  }
  std::size_t integratedScalarCount() const noexcept {
    return 6 * coefficientShape_.elementCount() + realElementCount_ +
           2 * complexElementCount_;
  }
  std::size_t persistentBytes() const noexcept;

private:
  WVShape2D coefficientShape_;
  std::vector<WVAdditionalStateBlockLayout> additionalBlocks_;
  std::vector<WVStateBlockRecord> stateBlockRecords_;
  std::vector<WVObserverRecord> observerRecords_;
  std::size_t realElementCount_ = 0;
  std::size_t complexElementCount_ = 0;
};

struct WVAdditionalStateBlockConstView {
  const WVAdditionalStateBlockLayout *layout = nullptr;
  const double *realData = nullptr;
  const WVComplex64 *complexData = nullptr;
};

struct WVAdditionalStateBlockView {
  const WVAdditionalStateBlockLayout *layout = nullptr;
  double *realData = nullptr;
  WVComplex64 *complexData = nullptr;
};

struct WVIntegrationState {
  WVState waveVortex;
  const WVAdditionalStateBlockConstView *additionalBlocks = nullptr;
  std::size_t additionalBlockCount = 0;
};

struct WVMutableIntegrationState {
  WVMutableState waveVortex;
  WVAdditionalStateBlockView *additionalBlocks = nullptr;
  std::size_t additionalBlockCount = 0;
};

struct WVIntegrationFlux {
  WVFlux waveVortex;
  WVAdditionalStateBlockView *additionalBlocks = nullptr;
  std::size_t additionalBlockCount = 0;
};

// Owns only additional state; canonical Ap, Am, and A0 remain caller-owned.
class WVAdditionalStateStorage final {
public:
  WVKernelStatus initialize(const WVIntegrationStateLayout &layout);
  WVAdditionalStateBlockView *mutableBlocks() noexcept {
    return mutableViews_.data();
  }
  const WVAdditionalStateBlockConstView *constBlocks() const noexcept {
    return constViews_.data();
  }
  std::size_t blockCount() const noexcept { return mutableViews_.size(); }
  std::size_t capacityBytes() const noexcept;
  void clear() noexcept;

private:
  std::vector<double> realStorage_;
  std::vector<WVComplex64> complexStorage_;
  std::vector<WVAdditionalStateBlockView> mutableViews_;
  std::vector<WVAdditionalStateBlockConstView> constViews_;
};

WVIntegrationState
integrationConstView(const WVMutableIntegrationState &state,
                   std::vector<WVAdditionalStateBlockConstView> &blockViews);
WVKernelStatus validateIntegrationState(const WVIntegrationStateLayout &layout,
                                      const WVIntegrationState &state);
WVKernelStatus
validateMutableIntegrationState(const WVIntegrationStateLayout &layout,
                              const WVMutableIntegrationState &state);
bool sameIntegrationStateLayout(const WVIntegrationStateLayout &first,
                                const WVIntegrationStateLayout &second) noexcept;

} // namespace wavevortex::runtime
