#include "WaveVortexRuntime/WVCompositeState.hpp"

#include <cmath>
#include <limits>
#include <new>
#include <set>
#include <utility>

namespace wavevortex::runtime {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}
bool sameShape(WVShape2D first, WVShape2D second) noexcept {
  return first.rows == second.rows && first.columns == second.columns;
}
bool canonical(const std::string &value) noexcept {
  return value == "Ap" || value == "Am" || value == "A0";
}

std::size_t checkedCount(const std::vector<std::size_t> &dimensions,
                         bool &invalidValue) noexcept {
  std::size_t result = 1;
  invalidValue = dimensions.empty();
  for (const auto dimension : dimensions) {
    if (dimension == 0 ||
        result > std::numeric_limits<std::size_t>::max() / dimension) {
      invalidValue = true;
      return 0;
    }
    result *= dimension;
  }
  return result;
}

} // namespace

WVKernelStatus
WVCompositeStateLayout::create(WVShape2D coefficientShape,
                               const WVPortableObserverDescriptor &descriptor,
                               WVCompositeStateLayout &layout) {
  if (coefficientShape.rows == 0 || coefficientShape.columns == 0)
    return invalid("Composite coefficient shape must be nonzero.");
  try {
    WVCompositeStateLayout candidate;
    candidate.coefficientShape_ = coefficientShape;
    candidate.stateBlockRecords_ = descriptor.stateBlocks();
    candidate.observerRecords_ = descriptor.observers();
    std::set<std::string> canonicalBlocks;
    for (const auto &record : descriptor.stateBlocks()) {
      bool badCount = false;
      const auto count = checkedCount(record.dimensions, badCount);
      if (badCount)
        return {WVKernelStatusCode::sizeOverflow,
                "Composite state-block element count is invalid."};
      if (canonical(record.identifier)) {
        canonicalBlocks.insert(record.identifier);
        if (record.scalarType != WVStateScalarType::complex64 ||
            record.ownership != WVStateOwnership::integratorOwned ||
            record.dimensions !=
                std::vector<std::size_t>(
                    {coefficientShape.rows, coefficientShape.columns}))
          return {WVKernelStatusCode::invalidShape,
                  "Canonical coefficient blocks must be integrator-owned "
                  "complex [Nj,Nkl] arrays."};
        continue;
      }
      if (record.ownership != WVStateOwnership::integratorOwned)
        continue;
      WVAdditionalStateBlockLayout block{record.identifier,
                                         record.scalarType,
                                         record.dimensions,
                                         record.toleranceKind,
                                         record.absoluteTolerance,
                                         record.ownership,
                                         record.restartRequirement,
                                         count,
                                         0};
      auto &total = record.scalarType == WVStateScalarType::real64
                        ? candidate.realElementCount_
                        : candidate.complexElementCount_;
      if (total > std::numeric_limits<std::size_t>::max() - count)
        return {WVKernelStatusCode::sizeOverflow,
                "Composite state storage overflows size_t."};
      block.scalarOffset = total;
      total += count;
      candidate.additionalBlocks_.push_back(std::move(block));
    }
    if (canonicalBlocks != std::set<std::string>({"A0", "Am", "Ap"}))
      return invalid(
          "Composite layout requires canonical Ap, Am, and A0 blocks.");
    layout = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Composite state-layout allocation failed."};
  }
}

std::size_t WVCompositeStateLayout::persistentBytes() const noexcept {
  std::size_t bytes =
      additionalBlocks_.capacity() * sizeof(WVAdditionalStateBlockLayout) +
      stateBlockRecords_.capacity() * sizeof(WVStateBlockRecord) +
      observerRecords_.capacity() * sizeof(WVObserverRecord);
  for (const auto &block : additionalBlocks_)
    bytes += block.identifier.capacity() +
             block.dimensions.capacity() * sizeof(std::size_t);
  for (const auto &block : stateBlockRecords_)
    bytes += block.identifier.capacity() +
             block.dimensions.capacity() * sizeof(std::size_t);
  for (const auto &observer : observerRecords_) {
    bytes += observer.identifier.capacity() + observer.name.capacity() +
             observer.stateBlockIdentifiers.capacity() * sizeof(std::string) +
             observer.fieldNames.capacity() * sizeof(std::string) +
             (observer.x.capacity() + observer.y.capacity() +
              observer.z.capacity()) *
                 sizeof(double);
    for (const auto &identifier : observer.stateBlockIdentifiers)
      bytes += identifier.capacity();
    for (const auto &name : observer.fieldNames)
      bytes += name.capacity();
  }
  return bytes;
}

WVKernelStatus
WVAdditionalStateStorage::initialize(const WVCompositeStateLayout &layout) {
  try {
    realStorage_.assign(layout.realElementCount(), 0.0);
    complexStorage_.assign(layout.complexElementCount(), WVComplex64{});
    mutableViews_.clear();
    constViews_.clear();
    mutableViews_.reserve(layout.additionalBlocks().size());
    constViews_.reserve(layout.additionalBlocks().size());
    for (const auto &block : layout.additionalBlocks()) {
      auto *real = block.scalarType == WVStateScalarType::real64
                       ? realStorage_.data() + block.scalarOffset
                       : nullptr;
      auto *complex = block.scalarType == WVStateScalarType::complex64
                          ? complexStorage_.data() + block.scalarOffset
                          : nullptr;
      mutableViews_.push_back({&block, real, complex});
      constViews_.push_back({&block, real, complex});
    }
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    clear();
    return {WVKernelStatusCode::allocationFailure,
            "Additional state storage allocation failed."};
  }
}

std::size_t WVAdditionalStateStorage::capacityBytes() const noexcept {
  return realStorage_.capacity() * sizeof(double) +
         complexStorage_.capacity() * sizeof(WVComplex64) +
         mutableViews_.capacity() * sizeof(WVAdditionalStateBlockView) +
         constViews_.capacity() * sizeof(WVAdditionalStateBlockConstView);
}

void WVAdditionalStateStorage::clear() noexcept {
  realStorage_.clear();
  complexStorage_.clear();
  mutableViews_.clear();
  constViews_.clear();
}

WVCompositeState
compositeConstView(const WVMutableCompositeState &state,
                   std::vector<WVAdditionalStateBlockConstView> &blockViews) {
  blockViews.clear();
  blockViews.reserve(state.additionalBlockCount);
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index)
    blockViews.push_back({state.additionalBlocks[index].layout,
                          state.additionalBlocks[index].realData,
                          state.additionalBlocks[index].complexData});
  return {state.waveVortex.view(), blockViews.data(), blockViews.size()};
}

WVKernelStatus validateCompositeState(const WVCompositeStateLayout &layout,
                                      const WVCompositeState &state) {
  if (!std::isfinite(state.waveVortex.t) || !std::isfinite(state.waveVortex.t0))
    return invalid("Composite state times must be finite.");
  const auto shape = layout.coefficientShape();
  const auto &c = state.waveVortex.coefficients;
  if (c.Ap.data == nullptr || c.Am.data == nullptr || c.A0.data == nullptr ||
      !sameShape(c.Ap.shape, shape) || !sameShape(c.Am.shape, shape) ||
      !sameShape(c.A0.shape, shape))
    return {WVKernelStatusCode::invalidShape,
            "Composite coefficients must use the resolved [Nj,Nkl] shape."};
  if (state.additionalBlockCount != layout.additionalBlocks().size() ||
      (state.additionalBlockCount && state.additionalBlocks == nullptr))
    return {WVKernelStatusCode::invalidShape,
            "Composite state-block count does not match its layout."};
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index) {
    const auto &expected = layout.additionalBlocks()[index];
    const auto &actual = state.additionalBlocks[index];
    if (actual.layout != &expected)
      return invalid(
          "Composite state-block order does not match its frozen layout.");
    if ((expected.scalarType == WVStateScalarType::real64 &&
         actual.realData == nullptr) ||
        (expected.scalarType == WVStateScalarType::complex64 &&
         actual.complexData == nullptr))
      return {WVKernelStatusCode::invalidPointer,
              "Composite state block has a null data pointer."};
  }
  return WVKernelStatus::ok();
}

WVKernelStatus
validateMutableCompositeState(const WVCompositeStateLayout &layout,
                              const WVMutableCompositeState &state) {
  try {
    std::vector<WVAdditionalStateBlockConstView> views;
    return validateCompositeState(layout, compositeConstView(state, views));
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Composite state validation allocation failed."};
  }
}

} // namespace wavevortex::runtime
