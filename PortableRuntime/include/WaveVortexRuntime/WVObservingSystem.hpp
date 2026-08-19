#pragma once

#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <cstddef>
#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace wavevortex::runtime {

struct WVObserverRecord;
struct WVStateBlockRecord;

// Declarative, per-record operations resolved once before integration. These
// describe generic sampling and integrated-state mechanics; runtime consumers
// do not identify MATLAB observer classes or query type discriminator methods.
enum class WVObserverSamplingTopology : std::uint8_t {
  fullField,
  fixedVerticalProfiles,
  fixedPositions,
  movingPositions,
  integratedState
};

enum class WVObserverIntegratedOperation : std::uint8_t {
  none,
  advectedPositions,
  advectedScalar
};

struct WVObserverExecutionPlan {
  WVObserverSamplingTopology sampling =
      WVObserverSamplingTopology::fullField;
  WVObserverIntegratedOperation integratedOperation =
      WVObserverIntegratedOperation::none;
  std::string fieldListAttribute;
  // Empty omits the legacy NetCDF name attribute for encodings that did not
  // historically persist one.
  std::string persistedName;
  std::vector<std::string> outputFields;
  // A record contributes a complete coefficient restart when this list
  // contains Ap, Am, and A0. Other restart representations can expose the
  // same generic family identities without a class-specific special case.
  std::vector<std::string> coefficientRestartFamilies;
};

// Provisional source-linked implementation boundary for one MATLAB observing
// system. Implementations are resolved once by exact MATLAB identity and
// contract version. Calls occur once per observer, RHS stage, or output event;
// implementations must not introduce virtual dispatch inside element loops.
class WVObservingSystem {
public:
  virtual ~WVObservingSystem() = default;
  virtual const std::string &typeIdentifier() const noexcept = 0;
  virtual std::uint32_t contractVersion() const noexcept = 0;

  virtual WVKernelStatus validate(
      const WVObserverRecord &observer,
      const std::map<std::string, const WVStateBlockRecord *> &blocks,
      std::map<std::string, std::size_t> &integratedBlockOwnerCounts) const = 0;
  virtual WVKernelStatus executionPlan(
      const WVObserverRecord &observer,
      WVObserverExecutionPlan &plan) const = 0;
  virtual std::size_t persistentBytes() const noexcept = 0;
};

} // namespace wavevortex::runtime
