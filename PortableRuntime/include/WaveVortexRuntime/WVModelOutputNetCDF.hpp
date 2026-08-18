#pragma once

#include "WaveVortexRuntime/WVCheckpointReader.hpp"
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
  virtual WVKernelStatus specifications(
      const WVObserverRecord &observer,
      std::vector<WVObserverOutputVariableSpecification> &output) = 0;
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
        WVObserverOutputValueView &output) = 0;
};

struct WVModelOutputNetCDFConfiguration {
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
};

struct WVModelOutputNetCDFInspection {
  // Latest complete coefficient restart among paths. Required additional
  // particle and tracer state is owned separately below.
  WVCheckpoint latestRestart;
  bool isDynamicsLinear = false;
  // Reconstructed shared observer graph and its resolved integration layout.
  WVPortableObserverRecord observerRecord;
  WVIntegrationStateLayout stateLayout;
  WVAdditionalStateStorage additionalState;
  // Last committed original-lattice ordinal for every file/group pair.
  std::vector<WVOutputGroupProgress> progress;
  std::vector<std::string> paths;
};

// MATLAB-compatible multi-file/multi-group persistence.
//
// createNew() fully defines, writes, synchronizes, and closes every sibling
// staging file before the destination set becomes visible. openAppend()
// validates the supplied descriptor, schedules, shapes, prior time lattice,
// and every committed payload before returning. inspect() reconstructs the
// observer graph and latest required restart state without requiring callers
// to supply the original descriptor.
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
             WVModelOutputNetCDFSink &sink);

  static WVCheckpointStatus inspect(const std::vector<std::string> &paths,
                                    WVModelOutputNetCDFInspection &inspection);

  WVKernelStatus preflight(const WVOutputPlan &plan) override;
  WVKernelStatus deliver(const WVOutputEvent &event,
                         const WVOutputRouteView &route,
                         WVOutputDeliveryResult &result) override;

  const std::vector<WVOutputGroupProgress> &progress() const noexcept;
  const WVModelOutputNetCDFMetrics &metrics() const noexcept;
  WVCheckpointStatus close() noexcept;

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace wavevortex::runtime
