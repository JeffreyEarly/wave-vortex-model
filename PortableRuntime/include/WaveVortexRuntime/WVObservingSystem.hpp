#pragma once

#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <cstddef>
#include <cstdint>
#include <map>
#include <string>

namespace wavevortex::runtime {

struct WVObserverRecord;
struct WVStateBlockRecord;

// Provisional source-linked implementation boundary for one MATLAB observing
// system. Implementations are resolved once by exact MATLAB identity and
// contract version. Calls occur once per observer, RHS stage, or output event;
// implementations must not introduce virtual dispatch inside element loops.
class WVObservingSystem {
public:
  virtual ~WVObservingSystem() = default;
  virtual const std::string &typeIdentifier() const noexcept = 0;
  virtual std::uint32_t contractVersion() const noexcept = 0;
  virtual const std::string &fieldListAttribute() const noexcept = 0;

  virtual WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &blocks,
      std::map<std::string, std::size_t> &integratedBlockOwnerCounts) const = 0;

  virtual bool recordsCoefficients() const noexcept { return false; }
  virtual bool recordsEulerianFields() const noexcept { return false; }
  virtual bool recordsFixedProfiles() const noexcept { return false; }
  virtual bool recordsFixedPoints() const noexcept { return false; }
  virtual bool recordsMovingParticles() const noexcept { return false; }
  virtual bool recordsTracerState() const noexcept { return false; }
  virtual bool contributesRightHandSide() const noexcept { return false; }
  virtual bool ownsParticleState() const noexcept { return false; }
  virtual bool ownsTracerState() const noexcept { return false; }
  virtual std::size_t persistentBytes() const noexcept = 0;
};

} // namespace wavevortex::runtime
