#pragma once

#include "WaveVortexRuntime/WVObserverContracts.hpp"

#include <deque>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace wavevortex::runtime::detail {

enum class WVMovingFieldChannel : std::uint8_t {
  x,
  y,
  z,
  tracerValue
};

const std::deque<std::shared_ptr<const WVObservingSystem>> &
observerImplementations() noexcept;
std::shared_ptr<const WVObservingSystem>
observerImplementation(const std::string &typeIdentifier,
                       std::uint32_t contractVersion) noexcept;
WVKernelStatus registerObserverImplementation(
    std::shared_ptr<const WVObservingSystem> implementation);
void sealObserverDefinitions() noexcept;
bool observerDefinitionsSealed() noexcept;

const char *movingFieldChannelName(WVMovingFieldChannel channel) noexcept;
std::vector<WVMovingFieldChannel>
movingFieldChannels(const WVObserverRecord &observer);
std::string movingFieldVariableName(const WVObserverRecord &observer,
                                    WVMovingFieldChannel channel);

} // namespace wavevortex::runtime::detail
