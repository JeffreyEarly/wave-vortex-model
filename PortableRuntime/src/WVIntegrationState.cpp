#include "WaveVortexRuntime/WVIntegrationState.hpp"

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

WVKernelStatus WVIntegrationStateLayout::createCoefficientOnly(
    WVShape2D coefficientShape, WVIntegrationStateLayout &layout) {
  if (coefficientShape.rows == 0 || coefficientShape.columns == 0)
    return invalid("Integration coefficient shape must be nonzero.");
  try {
    WVIntegrationStateLayout candidate;
    candidate.coefficientShape_ = coefficientShape;
    for (const char *identifier : {"Ap", "Am", "A0"}) {
      WVStateBlockRecord record;
      record.identifier = identifier;
      record.scalarType = WVStateScalarType::complex64;
      record.dimensions = {coefficientShape.rows, coefficientShape.columns};
      record.toleranceKind = WVToleranceKind::coefficientEnergyScaled;
      record.ownership = WVStateOwnership::integratorOwned;
      record.restartRequirement =
          WVRestartRequirement::requiredDynamicState;
      candidate.stateBlockRecords_.push_back(std::move(record));
    }
    layout = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Integration state-layout allocation failed."};
  }
}

WVKernelStatus
WVIntegrationStateLayout::create(WVShape2D coefficientShape,
                               const WVPortableObserverDescriptor &descriptor,
                               WVIntegrationStateLayout &layout) {
  if (coefficientShape.rows == 0 || coefficientShape.columns == 0)
    return invalid("Integration coefficient shape must be nonzero.");
  try {
    WVIntegrationStateLayout candidate;
    candidate.coefficientShape_ = coefficientShape;
    candidate.stateBlockRecords_ = descriptor.stateBlocks();
    candidate.observerRecords_ = descriptor.observers();
    std::set<std::string> canonicalBlocks;
    for (const auto &record : descriptor.stateBlocks()) {
      bool badCount = false;
      const auto count = checkedCount(record.dimensions, badCount);
      if (badCount)
        return {WVKernelStatusCode::sizeOverflow,
                "Integration state-block element count is invalid."};
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
                "Integration state storage overflows size_t."};
      block.scalarOffset = total;
      total += count;
      candidate.additionalBlocks_.push_back(std::move(block));
    }
    if (canonicalBlocks != std::set<std::string>({"A0", "Am", "Ap"}))
      return invalid(
          "Integration layout requires canonical Ap, Am, and A0 blocks.");
    layout = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Integration state-layout allocation failed."};
  }
}

std::size_t WVIntegrationStateLayout::persistentBytes() const noexcept {
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
WVAdditionalStateStorage::initialize(const WVIntegrationStateLayout &layout) {
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

WVIntegrationState
integrationConstView(const WVMutableIntegrationState &state,
                   std::vector<WVAdditionalStateBlockConstView> &blockViews) {
  blockViews.clear();
  blockViews.reserve(state.additionalBlockCount);
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index)
    blockViews.push_back({state.additionalBlocks[index].layout,
                          state.additionalBlocks[index].realData,
                          state.additionalBlocks[index].complexData});
  return {state.waveVortex.view(), blockViews.data(), blockViews.size()};
}

WVKernelStatus validateIntegrationState(const WVIntegrationStateLayout &layout,
                                      const WVIntegrationState &state) {
  if (!std::isfinite(state.waveVortex.t) || !std::isfinite(state.waveVortex.t0))
    return invalid("Integration state times must be finite.");
  const auto shape = layout.coefficientShape();
  const auto &c = state.waveVortex.coefficients;
  if (c.Ap.data == nullptr || c.Am.data == nullptr || c.A0.data == nullptr ||
      !sameShape(c.Ap.shape, shape) || !sameShape(c.Am.shape, shape) ||
      !sameShape(c.A0.shape, shape))
    return {WVKernelStatusCode::invalidShape,
            "Integration coefficients must use the resolved [Nj,Nkl] shape."};
  if (state.additionalBlockCount != layout.additionalBlocks().size() ||
      (state.additionalBlockCount && state.additionalBlocks == nullptr))
    return {WVKernelStatusCode::invalidShape,
            "Integration state-block count does not match its layout."};
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index) {
    const auto &expected = layout.additionalBlocks()[index];
    const auto &actual = state.additionalBlocks[index];
    if (actual.layout != &expected)
      return invalid(
          "Integration state-block order does not match its frozen layout.");
    if ((expected.scalarType == WVStateScalarType::real64 &&
         actual.realData == nullptr) ||
        (expected.scalarType == WVStateScalarType::complex64 &&
         actual.complexData == nullptr))
      return {WVKernelStatusCode::invalidPointer,
              "Integration state block has a null data pointer."};
  }
  return WVKernelStatus::ok();
}

WVKernelStatus
validateMutableIntegrationState(const WVIntegrationStateLayout &layout,
                              const WVMutableIntegrationState &state) {
  if (!std::isfinite(state.waveVortex.t) ||
      !std::isfinite(state.waveVortex.t0))
    return invalid("Integration state times must be finite.");
  const auto shape = layout.coefficientShape();
  const auto &c = state.waveVortex.coefficients;
  if (c.Ap.data == nullptr || c.Am.data == nullptr || c.A0.data == nullptr ||
      !sameShape(c.Ap.shape, shape) || !sameShape(c.Am.shape, shape) ||
      !sameShape(c.A0.shape, shape))
    return {WVKernelStatusCode::invalidShape,
            "Integration coefficients must use the resolved [Nj,Nkl] shape."};
  if (state.additionalBlockCount != layout.additionalBlocks().size() ||
      (state.additionalBlockCount && state.additionalBlocks == nullptr))
    return {WVKernelStatusCode::invalidShape,
            "Integration state-block count does not match its layout."};
  for (std::size_t index = 0; index < state.additionalBlockCount; ++index) {
    const auto &expected = layout.additionalBlocks()[index];
    const auto &actual = state.additionalBlocks[index];
    if (actual.layout != &expected)
      return invalid(
          "Integration state-block order does not match its frozen layout.");
    if ((expected.scalarType == WVStateScalarType::real64 &&
         actual.realData == nullptr) ||
        (expected.scalarType == WVStateScalarType::complex64 &&
         actual.complexData == nullptr))
      return {WVKernelStatusCode::invalidPointer,
              "Integration state block has a null data pointer."};
  }
  return WVKernelStatus::ok();
}

bool sameIntegrationStateLayout(const WVIntegrationStateLayout &first,
                                const WVIntegrationStateLayout &second) noexcept {
  if (!sameShape(first.coefficientShape(), second.coefficientShape()) ||
      first.stateBlockRecords().size() != second.stateBlockRecords().size() ||
      first.observerRecords().size() != second.observerRecords().size())
    return false;
  for (std::size_t i = 0; i < first.stateBlockRecords().size(); ++i) {
    const auto &a = first.stateBlockRecords()[i];
    const auto &b = second.stateBlockRecords()[i];
    if (a.identifier != b.identifier || a.scalarType != b.scalarType ||
        a.dimensions != b.dimensions || a.toleranceKind != b.toleranceKind ||
        a.absoluteTolerance != b.absoluteTolerance ||
        a.ownership != b.ownership ||
        a.restartRequirement != b.restartRequirement)
      return false;
  }
  const auto &aObservers = first.observerRecords();
  const auto &bObservers = second.observerRecords();
  for (std::size_t i = 0; i < aObservers.size(); ++i) {
    const auto &a = aObservers[i];
    const auto &b = bObservers[i];
    if (a.identifier != b.identifier || a.name != b.name || a.kind != b.kind ||
        a.stateBlockIdentifiers != b.stateBlockIdentifiers ||
        a.fieldNames != b.fieldNames || a.x != b.x || a.y != b.y ||
        a.z != b.z || a.isXYOnly != b.isXYOnly ||
        a.shouldAntialias != b.shouldAntialias ||
        a.advectionInterpolation != b.advectionInterpolation ||
        a.trackedFieldInterpolation != b.trackedFieldInterpolation ||
        a.horizontalAbsoluteTolerance != b.horizontalAbsoluteTolerance ||
        a.verticalAbsoluteTolerance != b.verticalAbsoluteTolerance)
      return false;
  }
  return true;
}

} // namespace wavevortex::runtime
