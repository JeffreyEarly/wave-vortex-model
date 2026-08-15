#include "WVObserverAdapter.hpp"

#include <cmath>
#include <utility>

namespace wavevortex::runtime::detail {
namespace {

constexpr std::array<WVObserverDefinition, 5> definitions{{
    {WVObserverKind::coefficients, "WVCoefficients", "WVCoefficients",
     WVObserverStateContract::canonicalCoefficients,
     WVObserverOutputRule::coefficients, nullptr},
    {WVObserverKind::eulerianFields, "WVEulerianFields", "WVEulerianFields",
     WVObserverStateContract::sampleOnly,
     WVObserverOutputRule::eulerianFields, "fieldNames"},
    {WVObserverKind::mooring, "WVMooring", "WVMooring",
     WVObserverStateContract::sampleOnly, WVObserverOutputRule::mooring,
     "trackedFieldNames"},
    {WVObserverKind::lagrangianParticles, "WVLagrangianParticles",
     "WVLagrangianParticles", WVObserverStateContract::particlePosition,
     WVObserverOutputRule::lagrangianParticles, "trackedFieldNames"},
    {WVObserverKind::tracer, "WVTracer", "WVTracer",
     WVObserverStateContract::tracerField, WVObserverOutputRule::tracer,
     nullptr},
}};

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

} // namespace

const std::array<WVObserverDefinition, 5> &observerDefinitions() noexcept {
  return definitions;
}

const WVObserverDefinition *observerDefinition(WVObserverKind kind) noexcept {
  for (const auto &definition : definitions)
    if (definition.kind == kind)
      return &definition;
  return nullptr;
}

const WVObserverDefinition *
observerDefinitionForMatlabClass(const std::string &className) noexcept {
  for (const auto &definition : definitions)
    if (className == definition.matlabClassName)
      return &definition;
  return nullptr;
}

const char *movingFieldChannelName(WVMovingFieldChannel channel) noexcept {
  switch (channel) {
  case WVMovingFieldChannel::x:
    return "x";
  case WVMovingFieldChannel::y:
    return "y";
  case WVMovingFieldChannel::z:
    return "z";
  case WVMovingFieldChannel::tracerValue:
    return "value";
  }
  return nullptr;
}

std::vector<WVMovingFieldChannel>
movingFieldChannels(const WVObserverRecord &observer) {
  const auto *definition = observerDefinition(observer.kind);
  if (definition == nullptr)
    return {};
  if (definition->stateContract == WVObserverStateContract::particlePosition)
    return observer.isXYOnly
               ? std::vector<WVMovingFieldChannel>{WVMovingFieldChannel::x,
                                                   WVMovingFieldChannel::y}
               : std::vector<WVMovingFieldChannel>{WVMovingFieldChannel::x,
                                                   WVMovingFieldChannel::y,
                                                   WVMovingFieldChannel::z};
  if (definition->stateContract == WVObserverStateContract::tracerField)
    return {WVMovingFieldChannel::tracerValue};
  return {};
}

std::string movingFieldVariableName(const WVObserverRecord &observer,
                                    WVMovingFieldChannel channel) {
  if (channel == WVMovingFieldChannel::tracerValue)
    return observer.name;
  return observer.name + '_' + movingFieldChannelName(channel);
}

WVKernelStatus validateBuiltInObserver(
    const WVObserverRecord &observer,
    const std::map<std::string, const WVStateBlockRecord *> &blocksByIdentifier,
    std::map<std::string, std::size_t> &integratedBlockOwnerCounts) {
  const auto *definition = observerDefinition(observer.kind);
  if (definition == nullptr)
    return {WVKernelStatusCode::unsupportedOperation,
            "Unsupported observing-system tag."};

  switch (definition->stateContract) {
  case WVObserverStateContract::canonicalCoefficients:
    if (observer.stateBlockIdentifiers !=
        std::vector<std::string>({"Ap", "Am", "A0"}))
      return invalid(
          "WVCoefficients must reference Ap, Am, and A0 in canonical order.");
    return WVKernelStatus::ok();

  case WVObserverStateContract::sampleOnly:
    if (!observer.stateBlockIdentifiers.empty())
      return invalid(
          "Sample-only observers cannot own integrated state blocks.");
    if (definition->outputRule == WVObserverOutputRule::mooring &&
        (observer.x.empty() || observer.x.size() != observer.y.size()))
      return invalid("WVMooring requires equal nonempty x and y coordinates.");
    return WVKernelStatus::ok();

  case WVObserverStateContract::particlePosition: {
    if (observer.x.empty() || observer.x.size() != observer.y.size())
      return invalid(
          "WVLagrangianParticles requires equal nonempty x and y coordinates.");
    if (!observer.isXYOnly && observer.z.size() != observer.x.size())
      return invalid(
          "Three-dimensional particles require one z coordinate per particle.");
    if (!(observer.horizontalAbsoluteTolerance > 0.0) ||
        !std::isfinite(observer.horizontalAbsoluteTolerance))
      return invalid(
          "Particle horizontal tolerance must be finite and positive.");
    if (!observer.isXYOnly &&
        (!(observer.verticalAbsoluteTolerance > 0.0) ||
         !std::isfinite(observer.verticalAbsoluteTolerance)))
      return invalid("Particle vertical tolerance must be finite and positive.");
    const auto channels = movingFieldChannels(observer);
    if (observer.stateBlockIdentifiers.size() != channels.size())
      return invalid("WVLagrangianParticles requires ordered x, y, and "
                     "optional z state blocks.");
    for (const auto &identifier : observer.stateBlockIdentifiers) {
      const auto *block = blocksByIdentifier.at(identifier);
      if (block->scalarType != WVStateScalarType::real64 ||
          block->ownership != WVStateOwnership::integratorOwned ||
          block->dimensions !=
              std::vector<std::size_t>({observer.x.size()}))
        return invalid("Particle state blocks must be integrator-owned real "
                       "vectors matching the particle count.");
      ++integratedBlockOwnerCounts.at(identifier);
    }
    return WVKernelStatus::ok();
  }

  case WVObserverStateContract::tracerField: {
    if (observer.stateBlockIdentifiers.size() != 1)
      return invalid("WVTracer requires exactly one state block.");
    const auto *block =
        blocksByIdentifier.at(observer.stateBlockIdentifiers.front());
    if (block->scalarType != WVStateScalarType::real64 ||
        block->ownership != WVStateOwnership::integratorOwned)
      return invalid("WVTracer requires one integrator-owned real state block.");
    const std::size_t expectedRank = observer.isXYOnly ? 2 : 3;
    if (block->dimensions.size() != expectedRank)
      return invalid(observer.isXYOnly
                         ? "A two-dimensional WVTracer requires a rank-two state block."
                         : "A three-dimensional WVTracer requires a rank-three state block.");
    ++integratedBlockOwnerCounts.at(observer.stateBlockIdentifiers.front());
    return WVKernelStatus::ok();
  }
  }
  return {WVKernelStatusCode::unsupportedOperation,
          "Unsupported observing-system state contract."};
}

} // namespace wavevortex::runtime::detail
