#include "WaveVortexRuntime/WVPortableVariablePlan.hpp"

#include "WVAllocationProbe.hpp"

#include <cstddef>
#include <cstdlib>
#include <set>
#include <string>

using namespace wavevortex::runtime;

int main() {
  const auto require = [](const bool condition) {
    if (!condition) std::abort();
  };
  static_assert(WVPortableVariableCatalog.size() == 76);
  static_assert(portableVariableCatalogBytes() ==
                sizeof(WVPortableVariableCatalog));
  static_assert(findPortableVariable("u") != nullptr);
  static_assert(findPortableVariable("unknown") == nullptr);
  static_assert(portableVariableMetadata(WVPortableVariable::invalid) ==
                nullptr);

  std::set<std::string> names;
  std::set<std::uint8_t> ordinals;
  for (std::size_t index = 0; index < WVPortableVariableCatalog.size();
       ++index) {
    const auto &variable = WVPortableVariableCatalog[index];
    require(variable.ordinal == index);
    require(static_cast<std::size_t>(variable.identifier) == index);
    require(names.insert(variable.name).second);
    require(ordinals.insert(variable.ordinal).second);
    require(portableVariableMetadata(variable.identifier) == &variable);
    require(findPortableVariable(variable.name) == &variable);
  }

  const auto *Ap = findPortableVariable("Ap");
  require(Ap != nullptr);
  require(Ap->kind == WVPortableVariableKind::coefficient);
  require(Ap->naturalRank == WVPortableNaturalRank::coefficient);
  require(Ap->isComplex);
  require(!Ap->isVariableWithLinearTimeStep);
  require(Ap->samplingMask == portableCoefficientSampling);

  const auto *u = findPortableVariable("u");
  require(u != nullptr);
  require(u->kind == WVPortableVariableKind::field);
  require(u->naturalRank == WVPortableNaturalRank::volume);
  require((u->samplingMask & portableFullGridSampling) != 0);
  require((u->samplingMask & portableFixedVerticalProfileSampling) != 0);
  require((u->samplingMask & portablePositionSampling) != 0);
  require(u->primitiveDependencyMask == 1);
  require(u->movingPrimitiveChannel == 0);
  require(u->netCDFAttributeCount == 1);
  require(std::string(u->netCDFAttribute.name) == "standard_name");

  const auto *rhoBar = findPortableVariable("rho_bar");
  require(rhoBar != nullptr);
  require(rhoBar->naturalRank == WVPortableNaturalRank::vertical);
  require(rhoBar->samplingMask == portableFullGridSampling);
  require(rhoBar->dimensionCount == 1);
  require(std::string(rhoBar->dimensions[0]) == "z");

  const auto *zetaZ = findPortableVariable("zeta_z");
  require(zetaZ != nullptr);
  require(zetaZ->primitiveDependencyMask == (16 | 32));
  require(std::string(zetaZ->netCDFAttribute.name) == "short_name");

  allocationProbe::calls = 0;
  allocationProbe::counting = true;
  WVPortableVariableOptions options;
  options.source = WVPortableOperationSource::builtIn;
  WVPortableVariablePlan plan;
  const auto resolve = [&](std::string_view name, std::string_view configuration = "hydrostatic-aa0",
                           std::uint8_t sampling = portableFullGridSampling) {
    return resolvePortableVariablePlan(name, configuration, sampling, options, plan);
  };
  require(resolve("eta_true") == WVPortableVariableStatus::supported);
  require(plan.primitiveMask == 1);
  require(plan.order[plan.count - 1] == WVPortableVariable::eta_true);
  const auto referenceCount = plan.count;
  options.shouldUseTrueNoMotionProfile = true;
  require(resolve("eta_true") == WVPortableVariableStatus::requiresNoMotionSolver);
  require(plan.count == 0 && plan.output == nullptr);
  options.noMotionSolver = WVPortableNoMotionSolver::fminsearch;
  require(resolve("eta_true") == WVPortableVariableStatus::supported);
  require(plan.count > referenceCount);
  require(resolve("apv") == WVPortableVariableStatus::supported);
  require(plan.primitiveMask == (1 | 16 | 32 | 64));
  require(resolve("energy_w") == WVPortableVariableStatus::supported);
  require(plan.primitiveMask == 128);
  options.requireEvaluator = true;
  require(resolve("eta_true") == WVPortableVariableStatus::intentionalIncompatibility);
  require(resolve("energy_w") == WVPortableVariableStatus::supported);
  require(findExecutablePortableVariable("energy_w") != nullptr);
  require(findExecutablePortableVariable("eta_true") == nullptr);
  require(findExecutablePortableVariable("u") != nullptr);
  options.requireEvaluator = false;
  require(resolve("eta_true", "barotropic-aa0") == WVPortableVariableStatus::notApplicable);
  require(resolve("u", "barotropic-aa0") == WVPortableVariableStatus::supported);
  require(plan.output->metadata.dimensionCount == 2);
  require(resolve("u", "barotropic-aa0", portableFixedVerticalProfileSampling) == WVPortableVariableStatus::unsupportedSampling);
  require(resolve("ape", "hydrostatic-aa0", portablePositionSampling) == WVPortableVariableStatus::unsupportedSampling);
  require(resolve("ape", "unknown") == WVPortableVariableStatus::unknownConfiguration);
  require(resolve("custom") == WVPortableVariableStatus::unknownVariable);
  require(resolve("totalEnstrophy") == WVPortableVariableStatus::intentionalIncompatibility);
  require(resolve("Fu_portable_catalog_forcing") == WVPortableVariableStatus::requiresForcingBinding);
  options.hasQualifiedForcingBinding = true;
  require(resolve("Fu_portable_catalog_forcing") == WVPortableVariableStatus::supported);
  require(plan.output->runtime == WVPortableDiagnosticRuntime::pending315);
  options.requireEvaluator = true;
  require(resolve("Fu_portable_catalog_forcing") == WVPortableVariableStatus::pendingEvaluation);
  options.requireEvaluator = false;
  options.source = WVPortableOperationSource::custom;
  require(resolve("u") == WVPortableVariableStatus::customOperation);
  options.source = WVPortableOperationSource::builtIn;
  // Every generated row resolves to a topological order with no duplicate work.
  for (const auto &row : WVPortableVariableContracts) {
    const auto sampling = row.metadata.naturalRank == WVPortableNaturalRank::coefficient
        ? portableCoefficientSampling : portableFullGridSampling;
    require(resolve(row.metadata.name, row.configuration, sampling) == WVPortableVariableStatus::supported);
    std::array<bool, WVPortableVariableCatalog.size()> seen{};
    for (std::size_t index = 0; index < plan.count; ++index) {
      const auto id = plan.order[index];
      require(!seen[static_cast<std::size_t>(id)]);
      const auto *dependency = portableVariableContract(id, row.configuration);
      for (std::size_t edge = 0; edge < dependency->dependencyCount; ++edge)
        require(seen[static_cast<std::size_t>(dependency->dependencies[edge])]);
      if (dependency->trueProfileDependency != WVPortableVariable::invalid)
        require(seen[static_cast<std::size_t>(dependency->trueProfileDependency)]);
      seen[static_cast<std::size_t>(id)] = true;
    }
    require(plan.order[plan.count - 1] == row.metadata.identifier);
  }

  std::array<WVPortableForcingVariableBinding, 2> bindings{{
      {"wind-stress", 7, true}, {"wind stress", 8, true}}};
  require(resolvePortableForcingVariablePlan("Fu_wind_stress", "hydrostatic-aa0",
      portableFullGridSampling, bindings.data(), 1, options, plan) == WVPortableVariableStatus::supported);
  require(plan.resolvedName == "Fu_wind_stress" && plan.forcingInstanceOrdinal == 7);
  require(resolvePortableForcingVariablePlan("Fu_wind_stress", "hydrostatic-aa0",
      portableFullGridSampling, bindings.data(), 2, options, plan) == WVPortableVariableStatus::ambiguousForcingBinding);
  require(plan.count == 0);
  bindings[0].qualified = false;
  require(resolvePortableForcingVariablePlan("Fu_wind_stress", "hydrostatic-aa0",
      portableFullGridSampling, bindings.data(), 1, options, plan) == WVPortableVariableStatus::requiresForcingBinding);
  allocationProbe::counting = false;
  require(allocationProbe::calls == 0);
  return 0;
}
