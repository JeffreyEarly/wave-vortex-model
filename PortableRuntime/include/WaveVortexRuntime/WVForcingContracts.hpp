#pragma once

#include "WaveVortexKernel/WVForcingSchedule.hpp"
#include "WaveVortexRuntime/WVPortableImplementationContract.hpp"

#include <cstdint>
#include <deque>
#include <string>
#include <vector>

namespace wavevortex::runtime {

// Construction-time registry for MATLAB/C++ forcing pairs. Registrations map
// an exact source identity to an existing typed payload and execution contract;
// they do not introduce a binary plug-in ABI or element-loop polymorphism.
class WVForcingFactoryRegistry final {
public:
  struct Registration {
    WVForcingKind operation = WVForcingKind::nonlinearAdvection;
    std::string matlabClassName;
    std::uint32_t contractVersion = WVPortablePairContractVersion;
    std::vector<std::string> forcingTypes;
    bool isSupported = true;
    std::string unavailabilityReason;
  };

  static const std::deque<Registration> &registrations() noexcept;
  static const Registration *registration(
      const std::string &typeIdentifier) noexcept;
  static WVPortableCapability capability(
      std::string typeIdentifier,
      std::uint32_t contractVersion = WVPortablePairContractVersion);
  static WVKernelStatus registerAdapter(Registration registration);
  static void seal() noexcept;
  static bool isSealed() noexcept;
};

} // namespace wavevortex::runtime
