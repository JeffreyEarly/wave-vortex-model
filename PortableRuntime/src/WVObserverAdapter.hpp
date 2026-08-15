#pragma once

#include "WaveVortexRuntime/WVObserverContracts.hpp"

#include <deque>
#include <map>
#include <string>
#include <vector>

namespace wavevortex::runtime::detail {

enum class WVMovingFieldChannel : std::uint8_t {
  x,
  y,
  z,
  tracerValue
};

struct WVObserverDefinition {
  WVObserverKind kind;
  std::string portableTag;
  std::string matlabClassName;
  WVObserverStateContract stateContract;
  WVObserverOutputRule outputRule;
  std::string fieldListAttribute;
};

const std::deque<WVObserverDefinition> &observerDefinitions() noexcept;
const WVObserverDefinition *observerDefinition(WVObserverKind kind) noexcept;
const WVObserverDefinition *
observerDefinitionForMatlabClass(const std::string &className) noexcept;
WVKernelStatus registerObserverDefinition(
    WVObserverFactoryRegistry::Registration registration);

const char *movingFieldChannelName(WVMovingFieldChannel channel) noexcept;
std::vector<WVMovingFieldChannel>
movingFieldChannels(const WVObserverRecord &observer);
std::string movingFieldVariableName(const WVObserverRecord &observer,
                                    WVMovingFieldChannel channel);

WVKernelStatus validateObserver(
    const WVObserverRecord &observer,
    const std::map<std::string, const WVStateBlockRecord *> &blocksByIdentifier,
    std::map<std::string, std::size_t> &integratedBlockOwnerCounts);

} // namespace wavevortex::runtime::detail
