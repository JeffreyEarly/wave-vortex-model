#pragma once

#include "WaveVortexRuntime/WVForcing.hpp"
#include "WaveVortexRuntime/WVPortableImplementationContract.hpp"

#include <cstdint>
#include <deque>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace wavevortex::runtime {

enum class WVForcingPersistenceEncoding : std::uint8_t {
  realVariable,
  logicalVariable,
  textAttribute,
  zeroBasedIndexVariable,
  complexVariable
};

enum class WVForcingDimensionRule : std::uint8_t {
  scalar,
  ownLength,
  referencedLength,
  horizontalYX,
  componentPair
};

struct WVForcingPersistenceField {
  WVForcingPersistenceEncoding encoding =
      WVForcingPersistenceEncoding::realVariable;
  std::string recordName;
  std::string imaginaryRecordName;
  std::string netcdfName;
  WVForcingDimensionRule dimensions = WVForcingDimensionRule::scalar;
  std::string dimensionReference;
  bool optional = false;
  bool nonnegative = false;
  bool positive = false;
  bool allowInfinity = false;
};

struct WVForcingPersistenceSchema {
  std::vector<WVForcingPersistenceField> fields;
  bool writesNameAttribute = false;
};

using WVForcingFactory = std::function<WVKernelStatus(
    const WVFrozenForcingEntry &,
    const WVTransformConstantStratificationDescriptor &,
    bool, std::unique_ptr<WVForcing> &)>;

// Construction-time registry for MATLAB/C++ forcing pairs. Registrations map
// an exact source identity to a typed persistence and execution contract;
// they do not introduce a binary plug-in ABI or element-loop polymorphism.
class WVForcingFactoryRegistry final {
public:
  struct Registration {
    std::string matlabClassName;
    std::uint32_t contractVersion = WVPortablePairContractVersion;
    std::vector<std::string> forcingTypes;
    std::string defaultName;
    WVForcingStage stage = WVForcingStage::spatial;
    std::uint8_t priority = 255;
    WVForcingPersistenceSchema persistence;
    WVForcingFactory factory;
    bool isSupported = true;
    std::string unavailabilityReason;
    bool providesAdaptiveDamping = false;
  };

  static const std::deque<Registration> &registrations() noexcept;
  static const Registration *registration(
      const std::string &typeIdentifier) noexcept;
  static WVPortableCapability capability(
      std::string typeIdentifier,
      std::uint32_t contractVersion = WVPortablePairContractVersion);
  static WVKernelStatus registerAdapter(Registration registration);
  static WVKernelStatus create(
      const WVFrozenForcingEntry &entry,
      const WVTransformConstantStratificationDescriptor &descriptor,
      bool hasAdaptiveDamping, std::unique_ptr<WVForcing> &forcing);
  static WVKernelStatus
  validateConfiguration(const WVFrozenForcingEntry &entry);
  static void seal() noexcept;
  static bool isSealed() noexcept;
};

WVFrozenForcingSchedule defaultNonlinearAdvectionSchedule();

} // namespace wavevortex::runtime
