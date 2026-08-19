#pragma once

#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVObservation.hpp"
#include "WaveVortexRuntime/WVOutputOrchestration.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace wavevortex::runtime {

enum class WVOutputValueType : std::uint8_t { real64, complex64 };
enum class WVObserverOutputCadence : std::uint8_t { initialOnly, timeSeries };

struct WVObserverOutputAttribute {
  std::string name;
  std::string value;
};

// One derived observation variable declared before any file is created.
// Dimensions use MATLAB's logical order; the NetCDF adapter reverses them.
struct WVObserverOutputVariableSpecification {
  WVObserverOutputVariableSpecification() = default;
  WVObserverOutputVariableSpecification(
      std::string identifierValue, std::string nameValue,
      WVOutputValueType valueTypeValue,
      std::vector<std::string> dimensionNamesValue,
      std::vector<std::size_t> dimensionsValue, std::string unitsValue,
      std::string longNameValue)
      : identifier(std::move(identifierValue)), name(std::move(nameValue)),
        valueType(valueTypeValue),
        dimensionNames(std::move(dimensionNamesValue)),
        dimensions(std::move(dimensionsValue)), units(std::move(unitsValue)),
        longName(std::move(longNameValue)) {}
  std::string identifier;
  std::string name;
  WVOutputValueType valueType = WVOutputValueType::real64;
  std::vector<std::string> dimensionNames;
  std::vector<std::size_t> dimensions;
  std::string units;
  std::string longName;
  WVObserverOutputCadence cadence = WVObserverOutputCadence::timeSeries;
  std::vector<WVObserverOutputAttribute> attributes;
};

struct WVObserverOutputValueView {
  WVOutputValueType valueType = WVOutputValueType::real64;
  const double *realData = nullptr;
  const WVComplex64 *complexData = nullptr;
  std::size_t elementCount = 0;
};

// Observer evaluation remains independent of NetCDF. Implementations added by
// later observer issues may evaluate all coincident routes once in prepare().
class WVObserverSampleSource {
public:
  virtual ~WVObserverSampleSource() = default;
  // Complete provisional schema/batch boundary. The default implementation
  // adapts the fixed real/complex specification/value API below so existing
  // source-linked providers retain their exact schema.
  virtual WVKernelStatus observationSchema(
      const WVObserverRecord &observer, WVObservationSchema &output);
  virtual WVKernelStatus initialObservationBatch(
      const WVObserverRecord &observer, WVObservationBatch &output);
  virtual WVKernelStatus observationBatch(const WVObserverRecord &observer,
                                           WVObservationBatch &output);

  // Legacy fixed-shape adapter retained during the provisional source API.
  virtual WVKernelStatus specifications(
      const WVObserverRecord &observer,
      std::vector<WVObserverOutputVariableSpecification> &output);
  virtual WVKernelStatus preflight(const WVOutputPlan &) {
    return WVKernelStatus::ok();
  }
  virtual WVKernelStatus prepareInitial(const WVState &) {
    return WVKernelStatus::ok();
  }
  virtual WVKernelStatus prepare(const WVOutputEvent &event) = 0;
  virtual WVKernelStatus
  value(const WVObserverRecord &observer,
        const WVObserverOutputVariableSpecification &variable,
        WVObserverOutputValueView &output);
};

struct WVModelOutputNetCDFConfiguration {
  std::shared_ptr<const WVExtensionCatalog> catalog;
  WVCheckpoint checkpointTemplate;
  bool isDynamicsLinear = false;
};

struct WVModelOutputNetCDFMetrics {
  std::size_t fileCount = 0;
  std::size_t groupCount = 0;
  std::size_t initializedFileCount = 0;
  std::size_t committedRecordCount = 0;
  std::size_t synchronizationCount = 0;
  std::size_t writtenBytes = 0;
  double payloadWriteSeconds = 0.0;
  double synchronizationSeconds = 0.0;
  std::size_t failureCount = 0;
  std::size_t retainedStorageBytes = 0;
  std::size_t batchRetainedStorageBytes = 0;
  std::size_t batchMaximumLiveBytes = 0;
};

struct WVInspectedObservationSchema {
  std::string observerIdentifier;
  WVObservationSchema schema;
};

struct WVModelOutputNetCDFInspection {
  // Allocation-light latest complete coefficient restart among paths. Raw
  // inspection never loads coefficient arrays or constructs implementations.
  WVCheckpointInspection latestRestart;
  std::string latestRestartPath;
  bool isDynamicsLinear = false;
  // Reconstructed canonical observer/output records and declared schemas.
  WVPortableObserverRecord observerRecord;
  std::vector<WVInspectedObservationSchema> observationSchemas;
  // Schedule state at the selected restart is independent of the tail and
  // offsets committed in each destination.
  std::vector<WVOutputScheduleContinuation> scheduleContinuations;
  std::vector<WVOutputDestinationProgress> destinationProgress;
  std::vector<std::string> paths;
};

// MATLAB-compatible multi-file/multi-group persistence.
//
// createNew() fully defines, writes, synchronizes, and closes every sibling
// staging file before the destination set becomes visible. openAppend()
// validates the complete supplied graph, schedules, shapes, record counts,
// time-last markers, cursor state, ragged offsets, and committed payloads
// read-only before reopening the accepted set for mutation. inspect()
// reconstructs the observer graph and allocation-light restart metadata;
// restoreState() later loads the selected coefficient and observer state.
//
// deliver() writes all payloads at the group's next record index, writes time
// last as the commit marker, then synchronizes the file. A failed call leaves
// the route uncommitted and safe to retry with the same immutable event.
class WVModelOutputNetCDFSink final : public WVOutputSink {
public:
  WVModelOutputNetCDFSink();
  ~WVModelOutputNetCDFSink() override;
  WVModelOutputNetCDFSink(WVModelOutputNetCDFSink &&) noexcept;
  WVModelOutputNetCDFSink &operator=(WVModelOutputNetCDFSink &&) noexcept;
  WVModelOutputNetCDFSink(const WVModelOutputNetCDFSink &) = delete;
  WVModelOutputNetCDFSink &operator=(const WVModelOutputNetCDFSink &) = delete;

  static WVCheckpointStatus
  createNew(const WVModelOutputNetCDFConfiguration &configuration,
            const WVPortableObserverDescriptor &descriptor,
            const WVIntegrationStateLayout &stateLayout,
            WVObserverSampleSource *sampleSource,
            WVModelOutputNetCDFSink &sink);

  // Stages the complete file set before replacing any destination. Failure
  // restores every original destination byte-for-byte.
  static WVCheckpointStatus
  replaceExisting(const WVModelOutputNetCDFConfiguration &configuration,
                  const WVPortableObserverDescriptor &descriptor,
                  const WVIntegrationStateLayout &stateLayout,
                  WVObserverSampleSource *sampleSource,
                  WVModelOutputNetCDFSink &sink);

  static WVCheckpointStatus
  openAppend(const WVModelOutputNetCDFConfiguration &configuration,
             const WVPortableObserverDescriptor &descriptor,
             const WVIntegrationStateLayout &stateLayout,
             WVObserverSampleSource *sampleSource,
             const std::vector<WVOutputDestinationProgress>
                 &expectedDestinationProgress,
             WVModelOutputNetCDFSink &sink);

  static WVCheckpointStatus inspect(const std::vector<std::string> &paths,
                                    const WVExtensionCatalog &catalog,
                                    WVModelOutputNetCDFInspection &inspection);

  // Load the selected coefficient and observer-owned restart state only after
  // the canonical output graph has completed capability preflight.
  static WVCheckpointStatus restoreState(
      const WVModelOutputNetCDFInspection &inspection,
      const WVExtensionCatalog &catalog,
      const WVIntegrationStateLayout &stateLayout, WVCheckpoint &checkpoint,
      WVAdditionalStateStorage &additionalState);

  WVKernelStatus preflight(const WVOutputPlan &plan) override;
  WVKernelStatus deliver(const WVOutputEvent &event,
                         const WVOutputRouteView &route,
                         WVOutputDeliveryResult &result) override;

  const std::vector<WVOutputDestinationProgress> &
  destinationProgress() const noexcept;
  const WVModelOutputNetCDFMetrics &metrics() const noexcept;
  WVCheckpointStatus close() noexcept;

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace wavevortex::runtime
