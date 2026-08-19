#pragma once

#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexRuntime/WVObservation.hpp"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace wavevortex::runtime {

// Borrowed construction context shared by every resolved observer. Observer
// implementations declare their schema and coarse evaluation channels here;
// they never receive a persistence adapter or issue NetCDF calls.
struct WVObserverOutputPlanningContext {
  const WVTransformConstantStratificationConfiguration *configuration =
      nullptr;
  const WVStateBlockRecord *stateBlocks = nullptr;
  std::size_t stateBlockCount = 0;
  bool isDynamicsLinear = false;

  const WVStateBlockRecord *
  stateBlock(const std::string &identifier) const noexcept;
};

enum class WVObserverOutputChannelSource : std::uint8_t {
  coefficient,
  sampledField,
  movingField,
  additionalState
};

// One coarse value channel requested by a source-linked observer. The central
// evaluator resolves and shares the expensive field work, then makes the
// resulting immutable value available by variableIdentifier once per batch.
struct WVObserverOutputChannel {
  std::string variableIdentifier;
  WVObserverOutputChannelSource source =
      WVObserverOutputChannelSource::sampledField;
  std::string sourceIdentifier;
  WVFieldSamplingRequest sampling;
  std::size_t coefficientFamily = 0;
  double scale = 1.0;
  double offset = 0.0;
};

struct WVObserverMovingPositionSource {
  std::vector<std::string> stateBlockIdentifiers;
  std::vector<double> fixedZ;
  std::size_t positionCount = 0;
  bool isXYOnly = false;
  WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
};

// Immutable per-record declaration retained by the evaluation service. Values
// in constantValues own their bounded configuration storage; batches borrow it.
struct WVObserverOutputPlan {
  WVObservationSchema schema;
  std::vector<WVObservationValue> constantValues;
  std::vector<WVObserverOutputChannel> channels;
  WVObserverMovingPositionSource movingPositions;
};

struct WVObserverBorrowedValueView {
  WVObservationScalarType scalarType = WVObservationScalarType::real64;
  const double *real64 = nullptr;
  const WVComplex64 *complex64 = nullptr;
  const std::int64_t *integer64 = nullptr;
  const std::uint8_t *boolean8 = nullptr;
  const std::string *text = nullptr;
  std::vector<std::size_t> extents;
  std::size_t elementCount = 0;
};

// Event-scoped borrowed context. Calls are coarse (one per declared variable),
// never per grid point, particle, profile sample, or other element.
class WVObserverOutputEvaluationContext {
public:
  virtual ~WVObserverOutputEvaluationContext() = default;
  virtual std::size_t eventOrdinal() const noexcept = 0;
  virtual double scheduledTime() const noexcept = 0;
  virtual WVKernelStatus
  value(const std::string &variableIdentifier,
        WVObserverBorrowedValueView &output) const = 0;
};

std::size_t
observerOutputPlanRetainedBytes(const WVObserverOutputPlan &plan) noexcept;

} // namespace wavevortex::runtime
