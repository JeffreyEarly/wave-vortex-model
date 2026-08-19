#pragma once

#include "WaveVortexKernel/WVKernelTypes.hpp"
#include "WaveVortexRuntime/WVObservingSystem.hpp"
#include "WaveVortexRuntime/WVPortableImplementationContract.hpp"
#include "WaveVortexRuntime/WVPortableTypedRecord.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace wavevortex::runtime {

inline constexpr std::uint32_t WVPortableObserverContractVersion = 1;
inline constexpr const char *WVPortableObserverContractIdentifier =
    "portable-observers-v1";

enum class WVStateScalarType : std::uint8_t { real64, complex64 };
enum class WVToleranceKind : std::uint8_t {
  coefficientEnergyScaled,
  uniformAbsolute
};
enum class WVRestartRequirement : std::uint8_t {
  requiredDynamicState,
  derivedState
};
enum class WVStateOwnership : std::uint8_t { integratorOwned, observerDerived };
enum class WVPositionInterpolation : std::uint8_t { linear, spline };

struct WVStateBlockRecord {
  std::string identifier;
  WVStateScalarType scalarType = WVStateScalarType::real64;
  std::vector<std::size_t> dimensions;
  WVToleranceKind toleranceKind = WVToleranceKind::uniformAbsolute;
  double absoluteTolerance = 0.0;
  WVStateOwnership ownership = WVStateOwnership::integratorOwned;
  WVRestartRequirement restartRequirement =
      WVRestartRequirement::requiredDynamicState;
};

struct WVObserverRecord {
  std::string identifier;
  std::string name;
  std::string typeIdentifier;
  std::uint32_t contractVersion = WVPortablePairContractVersion;
  std::vector<std::string> stateBlockIdentifiers;
  std::vector<std::string> fieldNames;
  std::vector<double> x;
  std::vector<double> y;
  std::vector<double> z;
  bool isXYOnly = false;
  bool shouldAntialias = true;
  WVPositionInterpolation advectionInterpolation =
      WVPositionInterpolation::linear;
  WVPositionInterpolation trackedFieldInterpolation =
      WVPositionInterpolation::linear;
  double horizontalAbsoluteTolerance = 0.0;
  double verticalAbsoluteTolerance = 0.0;
  double outputScale = 1.0;
  double outputOffset = 0.0;
};

struct WVOutputScheduleRecord {
  WVOutputScheduleRecord() = default;
  WVOutputScheduleRecord(double interval, double initial, double final)
      : outputInterval(interval), initialTime(initial), finalTime(final) {}
  double outputInterval = 0.0;
  double initialTime = 0.0;
  double finalTime = 0.0;
  // Empty identifies the legacy evenly-spaced schedule. New source-linked
  // providers use an exact identity/version and a construction-only record.
  std::string typeIdentifier;
  std::uint32_t contractVersion = 1;
  WVPortableTypedRecord configuration;
};

struct WVOutputGroupRecord {
  std::string identifier;
  std::string name;
  WVOutputScheduleRecord schedule;
  std::vector<std::string> observerIdentifiers;
  bool containsCompleteCoefficientRestart = false;
};

struct WVOutputFileRecord {
  std::string identifier;
  std::string destination;
  std::vector<WVOutputGroupRecord> groups;
};

struct WVPortableObserverRecord {
  std::string schemaIdentifier = WVPortableObserverContractIdentifier;
  std::uint32_t schemaVersion = WVPortableObserverContractVersion;
  std::vector<WVStateBlockRecord> stateBlocks;
  std::vector<WVObserverRecord> observers;
  std::vector<WVOutputFileRecord> outputFiles;
};

class WVPortableObserverDescriptor final {
public:
  static WVKernelStatus create(const WVPortableObserverRecord &record,
                               WVPortableObserverDescriptor &descriptor);

  WVPortableObserverRecord record() const { return record_; }
  const std::vector<WVStateBlockRecord> &stateBlocks() const noexcept {
    return record_.stateBlocks;
  }
  const std::vector<WVObserverRecord> &observers() const noexcept {
    return record_.observers;
  }
  const std::vector<WVOutputFileRecord> &outputFiles() const noexcept {
    return record_.outputFiles;
  }
  const WVObservingSystem *
  implementation(const WVObserverRecord &observer) const noexcept;
  std::size_t persistentBytes() const noexcept;

private:
  WVPortableObserverRecord record_;
  std::vector<std::shared_ptr<const WVObservingSystem>> implementations_;
};

// Registry seam for built-in tagged records. Version 1 intentionally exposes
// no third-party binary plugin ABI.
class WVObserverFactoryRegistry final {
public:
  static bool supports(
      const std::string &typeIdentifier,
      std::uint32_t contractVersion = WVPortablePairContractVersion) noexcept;
  static WVPortableCapability
  capability(std::string typeIdentifier,
             std::uint32_t contractVersion = WVPortablePairContractVersion);
  static bool isSealed() noexcept;

  // Register one source-level native observer adapter before constructing a
  // descriptor. The serialized observer record remains portable-observers-v1;
  // this is not a stable third-party binary plug-in ABI.
  static WVKernelStatus registerImplementation(
      std::shared_ptr<const WVObservingSystem> implementation);
};

} // namespace wavevortex::runtime
