#include "WaveVortexRuntime/generated/WVPortableVariableCatalog.hpp"

#include <cassert>
#include <cstddef>
#include <set>
#include <string>

using namespace wavevortex::runtime;

int main() {
  static_assert(WVPortableVariableCatalog.size() == 23);
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
    assert(variable.ordinal == index);
    assert(static_cast<std::size_t>(variable.identifier) == index);
    assert(names.insert(variable.name).second);
    assert(ordinals.insert(variable.ordinal).second);
    assert(portableVariableMetadata(variable.identifier) == &variable);
    assert(findPortableVariable(variable.name) == &variable);
  }

  const auto *Ap = findPortableVariable("Ap");
  assert(Ap != nullptr);
  assert(Ap->kind == WVPortableVariableKind::coefficient);
  assert(Ap->naturalRank == WVPortableNaturalRank::coefficient);
  assert(Ap->isComplex);
  assert(!Ap->isVariableWithLinearTimeStep);
  assert(Ap->samplingMask == portableCoefficientSampling);

  const auto *u = findPortableVariable("u");
  assert(u != nullptr);
  assert(u->kind == WVPortableVariableKind::field);
  assert(u->naturalRank == WVPortableNaturalRank::volume);
  assert((u->samplingMask & portableFullGridSampling) != 0);
  assert((u->samplingMask & portableFixedVerticalProfileSampling) != 0);
  assert((u->samplingMask & portablePositionSampling) != 0);
  assert(u->primitiveDependencyMask == 1);
  assert(u->movingPrimitiveChannel == 0);
  assert(u->netCDFAttributeCount == 1);
  assert(std::string(u->netCDFAttribute.name) == "standard_name");

  const auto *rhoBar = findPortableVariable("rho_bar");
  assert(rhoBar != nullptr);
  assert(rhoBar->naturalRank == WVPortableNaturalRank::vertical);
  assert(rhoBar->samplingMask == portableFullGridSampling);
  assert(rhoBar->dimensionCount == 1);
  assert(std::string(rhoBar->dimensions[0]) == "z");

  const auto *zetaZ = findPortableVariable("zeta_z");
  assert(zetaZ != nullptr);
  assert(zetaZ->primitiveDependencyMask == (16 | 32));
  assert(std::string(zetaZ->netCDFAttribute.name) == "short_name");

  return 0;
}
