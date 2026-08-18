#include "WaveVortexRuntime/WVForcingContracts.hpp"

#include <mutex>
#include <optional>
#include <utility>

namespace wavevortex::runtime {
namespace {

std::deque<WVForcingFactoryRegistry::Registration> &mutableRegistrations() {
  static std::deque<WVForcingFactoryRegistry::Registration> values{
      {WVForcingKind::nonlinearAdvection, "WVNonlinearAdvection",
       WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, true,
       ""},
      {WVForcingKind::antialiasing, "WVAntialiasing",
       WVPortablePairContractVersion, {"Spectral", "PVSpectral"}, false,
       "Transform-level antialiasing is represented by shouldAntialias; the "
       "diagnostic WVAntialiasing closure is not supported."},
      {WVForcingKind::adaptiveDamping, "WVAdaptiveDamping",
       WVPortablePairContractVersion, {"Spectral", "PVSpectral"}, true, ""},
      {WVForcingKind::fixedAmplitude, "WVFixedAmplitudeForcing",
       WVPortablePairContractVersion,
       {"SpectralAmplitude", "PVSpectralAmplitude"}, true, ""},
      {WVForcingKind::bottomFrictionQuadratic, "WVBottomFrictionQuadratic",
       WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, true,
       ""},
      {WVForcingKind::pseudoTopographicWaveGeneration,
       "WVPseudoTopographicWaveGeneration", WVPortablePairContractVersion,
       {"Spectral"}, true, ""},
      {WVForcingKind::betaPlanePVAdvection, "WVBetaPlanePVAdvection",
       WVPortablePairContractVersion, {"Spectral", "PVSpatial"}, true, ""},
      {WVForcingKind::horizontalDamping, "WVHorizontalDamping",
       WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial"}, false,
       "WVHorizontalDamping is not implemented by portable runtime v1."},
      {WVForcingKind::verticalDamping, "WVVerticalDamping",
       WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial"}, false,
       "WVVerticalDamping is not implemented by portable runtime v1."},
      {WVForcingKind::thermalDamping, "WVThermalDamping",
       WVPortablePairContractVersion, {"PVSpatial"}, false,
       "WVThermalDamping is not implemented by portable runtime v1."},
      {WVForcingKind::bottomFrictionLinear, "WVBottomFrictionLinear",
       WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, false,
       "WVBottomFrictionLinear is not implemented by portable runtime v1."},
      {WVForcingKind::verticalDiffusivity, "WVVerticalDiffusivity",
       WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, false,
       "WVVerticalDiffusivity is not implemented by portable runtime v1."}};
  return values;
}

std::mutex &registryMutex() {
  static std::mutex value;
  return value;
}

bool &registrySealed() {
  static bool value = false;
  return value;
}

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

} // namespace

const std::deque<WVForcingFactoryRegistry::Registration> &
WVForcingFactoryRegistry::registrations() noexcept {
  return mutableRegistrations();
}

const WVForcingFactoryRegistry::Registration *
WVForcingFactoryRegistry::registration(
    const std::string &typeIdentifier) noexcept {
  for (const auto &value : mutableRegistrations())
    if (value.matlabClassName == typeIdentifier)
      return &value;
  return nullptr;
}

WVPortableCapability WVForcingFactoryRegistry::capability(
    std::string typeIdentifier, std::uint32_t contractVersion) {
  const auto *value = registration(typeIdentifier);
  std::optional<WVPortableImplementationIdentity> available;
  if (value != nullptr && value->isSupported)
    available = WVPortableImplementationIdentity{value->matlabClassName,
                                                  value->contractVersion};
  auto result = evaluatePortableCapability(
      {std::move(typeIdentifier), contractVersion}, std::move(available));
  if (value != nullptr && !value->isSupported &&
      result.status == WVPortableCapabilityStatus::unavailable)
    result.reason = value->unavailabilityReason;
  return result;
}

WVKernelStatus WVForcingFactoryRegistry::registerAdapter(
    Registration registrationValue) {
  if (registrationValue.matlabClassName.empty())
    return invalid("Forcing adapter MATLAB class names must be nonempty.");
  if (registrationValue.contractVersion == 0)
    return invalid("Forcing adapter contract versions must be positive.");
  if (registrationValue.isSupported &&
      !registrationValue.unavailabilityReason.empty())
    return invalid("Supported forcing adapters cannot declare an unavailability reason.");
  if (!registrationValue.isSupported &&
      registrationValue.unavailabilityReason.empty())
    return invalid("Unavailable forcing adapters require an actionable reason.");
  std::lock_guard<std::mutex> lock(registryMutex());
  if (registrySealed())
    return invalid("Forcing adapters must be registered before schedule construction.");
  for (const auto &value : mutableRegistrations())
    if (value.matlabClassName == registrationValue.matlabClassName)
      return invalid("Forcing adapter identities must be unique.");
  mutableRegistrations().push_back(std::move(registrationValue));
  return WVKernelStatus::ok();
}

void WVForcingFactoryRegistry::seal() noexcept {
  std::lock_guard<std::mutex> lock(registryMutex());
  registrySealed() = true;
}

bool WVForcingFactoryRegistry::isSealed() noexcept {
  std::lock_guard<std::mutex> lock(registryMutex());
  return registrySealed();
}

} // namespace wavevortex::runtime
