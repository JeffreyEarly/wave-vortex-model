#pragma once

#include "WaveVortexRuntime/WVObserverContracts.hpp"

#include <array>
#include <map>
#include <string>
#include <vector>

namespace wavevortex::runtime::detail {

// Internal closed-world dispatch for the portable-observers-v1 built-ins.
// Adding a built-in observer begins here; the serialized contract deliberately
// exposes no third-party binary plug-in ABI.
enum class WVObserverStateContract : std::uint8_t {
  canonicalCoefficients,
  sampleOnly,
  particlePosition,
  tracerField
};

enum class WVObserverOutputRule : std::uint8_t {
  coefficients,
  eulerianFields,
  mooring,
  lagrangianParticles,
  tracer
};

enum class WVMovingFieldChannel : std::uint8_t {
  x,
  y,
  z,
  tracerValue
};

struct WVObserverDefinition {
  WVObserverKind kind;
  const char *portableTag;
  const char *matlabClassName;
  WVObserverStateContract stateContract;
  WVObserverOutputRule outputRule;
  const char *fieldListAttribute;
};

const std::array<WVObserverDefinition, 5> &observerDefinitions() noexcept;
const WVObserverDefinition *observerDefinition(WVObserverKind kind) noexcept;
const WVObserverDefinition *
observerDefinitionForMatlabClass(const std::string &className) noexcept;

const char *movingFieldChannelName(WVMovingFieldChannel channel) noexcept;
std::vector<WVMovingFieldChannel>
movingFieldChannels(const WVObserverRecord &observer);
std::string movingFieldVariableName(const WVObserverRecord &observer,
                                    WVMovingFieldChannel channel);

WVKernelStatus validateBuiltInObserver(
    const WVObserverRecord &observer,
    const std::map<std::string, const WVStateBlockRecord *> &blocksByIdentifier,
    std::map<std::string, std::size_t> &integratedBlockOwnerCounts);

} // namespace wavevortex::runtime::detail
