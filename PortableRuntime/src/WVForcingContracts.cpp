#include "WaveVortexRuntime/WVForcingContracts.hpp"
#include "WVForcingImplementations.hpp"

#include <mutex>
#include <cmath>
#include <limits>
#include <optional>
#include <set>
#include <utility>

namespace wavevortex::runtime {
namespace {

std::deque<WVForcingFactoryRegistry::Registration> &mutableRegistrations() {
  using Encoding = WVForcingPersistenceEncoding;
  using Dimensions = WVForcingDimensionRule;
  const auto field = [](Encoding encoding, std::string recordName,
                        std::string imaginaryRecordName,
                        std::string netcdfName, Dimensions dimensions,
                        std::string reference = {}, bool optional = false,
                        bool nonnegative = false, bool positive = false,
                        bool allowInfinity = false) {
    return WVForcingPersistenceField{encoding, std::move(recordName),
                                     std::move(imaginaryRecordName),
                                     std::move(netcdfName), dimensions,
                                     std::move(reference), optional,
                                     nonnegative, positive, allowInfinity};
  };
  static std::deque<WVForcingFactoryRegistry::Registration> values{
      {"WVNonlinearAdvection", WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"},
       "nonlinear advection", WVForcingStage::spatial, 127, {},
       detail::createNonlinearAdvectionForcing, true, ""},
      {"WVAntialiasing", WVPortablePairContractVersion,
       {"Spectral", "PVSpectral"}, "antialiasing", WVForcingStage::spectral,
       255, {}, {}, false,
       "Transform-level antialiasing is represented by shouldAntialias; the "
       "diagnostic WVAntialiasing closure is not supported."},
      {"WVAdaptiveDamping", WVPortablePairContractVersion,
       {"Spectral", "PVSpectral"}, "adaptive damping",
       WVForcingStage::spectral, 255, {}, detail::createAdaptiveDampingForcing,
       true, "", true},
      {"WVFixedAmplitudeForcing", WVPortablePairContractVersion,
       {"SpectralAmplitude", "PVSpectralAmplitude"}, "fixed amplitude",
       WVForcingStage::spectralAmplitude, 255,
       {{{field(Encoding::zeroBasedIndexVariable, "ApIndices", {},
                "Ap_indices", Dimensions::ownLength, {}, true),
          field(Encoding::complexVariable, "ApValuesReal", "ApValuesImag",
                "Apbar", Dimensions::referencedLength, "Ap_indices", true),
          field(Encoding::zeroBasedIndexVariable, "AmIndices", {},
                "Am_indices", Dimensions::ownLength, {}, true),
          field(Encoding::complexVariable, "AmValuesReal", "AmValuesImag",
                "Ambar", Dimensions::referencedLength, "Am_indices", true),
          field(Encoding::zeroBasedIndexVariable, "A0Indices", {},
                "A0_indices", Dimensions::ownLength, {}, true),
          field(Encoding::complexVariable, "A0ValuesReal", "A0ValuesImag",
                "A0bar", Dimensions::referencedLength, "A0_indices", true)}},
        true},
       detail::createFixedAmplitudeForcing, true, ""},
      {"WVBottomFrictionQuadratic", WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"},
       "quadratic bottom friction", WVForcingStage::spatial, 255,
       {{{field(Encoding::realVariable, "Cd", {}, "Cd", Dimensions::scalar,
                {}, false, true)}},
        false},
       detail::createQuadraticBottomFriction, true, ""},
      {"WVPseudoTopographicWaveGeneration", WVPortablePairContractVersion,
       {"Spectral"}, "pseudo-topographic wave generation",
       WVForcingStage::spectral, 255,
       {{{field(Encoding::realVariable, "topographicHeight", {},
                "topographicHeight", Dimensions::horizontalYX),
          field(Encoding::complexVariable, "barotropicVelocityAmplitudeReal",
                "barotropicVelocityAmplitudeImag",
                "barotropicVelocityAmplitude", Dimensions::componentPair),
          field(Encoding::realVariable, "frequency", {}, "frequency",
                Dimensions::scalar, {}, false, false, true),
          field(Encoding::textAttribute, "darwinSymbol", {}, "darwinSymbol",
                Dimensions::scalar, {}, true),
          field(Encoding::realVariable, "rampDuration", {}, "rampDuration",
                Dimensions::scalar, {}, false, true),
          field(Encoding::realVariable, "startTime", {}, "startTime",
                Dimensions::scalar),
          field(Encoding::logicalVariable, "shouldAvoidAdaptiveDamping", {},
                "shouldAvoidAdaptiveDamping", Dimensions::scalar),
          field(Encoding::realVariable, "maximumForcedHorizontalWavenumber",
                {}, "maximumForcedHorizontalWavenumber", Dimensions::scalar,
                {}, false, true, false, true),
          field(Encoding::realVariable, "maximumForcedVerticalMode", {},
                "maximumForcedVerticalMode", Dimensions::scalar, {}, false,
                true, false, true)}},
        true},
       detail::createPseudoTopographicForcing, true, ""},
      {"WVBetaPlanePVAdvection", WVPortablePairContractVersion,
       {"Spectral", "PVSpatial"}, "beta-plane advection of qgpv",
       WVForcingStage::spectral, 255, {}, detail::createBetaPlaneForcing, true,
       ""},
      {"WVHorizontalDamping", WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial"}, "horizontal damping",
       WVForcingStage::spectral, 255, {}, {}, false,
       "WVHorizontalDamping is not implemented by portable runtime v1."},
      {"WVVerticalDamping", WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial"}, "vertical damping",
       WVForcingStage::spectral, 255, {}, {}, false,
       "WVVerticalDamping is not implemented by portable runtime v1."},
      {"WVThermalDamping", WVPortablePairContractVersion, {"PVSpatial"},
       "thermal damping", WVForcingStage::spectral, 255, {}, {}, false,
       "WVThermalDamping is not implemented by portable runtime v1."},
      {"WVBottomFrictionLinear", WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"},
       "linear bottom friction", WVForcingStage::spatial, 255, {}, {}, false,
       "WVBottomFrictionLinear is not implemented by portable runtime v1."},
      {"WVVerticalDiffusivity", WVPortablePairContractVersion,
       {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"},
       "vertical diffusivity", WVForcingStage::spectral, 255, {}, {}, false,
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
  if (registrationValue.isSupported && !registrationValue.factory)
    return invalid("Supported forcing implementations require a factory.");
  std::lock_guard<std::mutex> lock(registryMutex());
  if (registrySealed())
    return invalid("Forcing adapters must be registered before schedule construction.");
  for (const auto &value : mutableRegistrations())
    if (value.matlabClassName == registrationValue.matlabClassName)
      return invalid("Forcing adapter identities must be unique.");
  mutableRegistrations().push_back(std::move(registrationValue));
  return WVKernelStatus::ok();
}

WVKernelStatus WVForcingFactoryRegistry::create(
    const WVFrozenForcingEntry &entry,
    const WVTransformConstantStratificationDescriptor &descriptor,
    bool hasAdaptiveDamping, std::unique_ptr<WVForcing> &forcing) {
  const auto *value = registration(entry.typeIdentifier);
  if (value == nullptr || !value->isSupported || !value->factory)
    return {WVKernelStatusCode::unsupportedOperation,
            "Unsupported forcing identity."};
  if (entry.contractVersion != value->contractVersion)
    return {WVKernelStatusCode::unsupportedOperation,
            "Forcing contract version mismatch."};
  return value->factory(entry, descriptor, hasAdaptiveDamping, forcing);
}

WVKernelStatus WVForcingFactoryRegistry::validateConfiguration(
    const WVFrozenForcingEntry &entry) {
  const auto *value = registration(entry.typeIdentifier);
  if (value == nullptr || !value->isSupported ||
      value->contractVersion != entry.contractVersion)
    return invalid("Forcing configuration has no matching registered implementation.");
  const auto recordStatus = validatePortableTypedRecord(
      entry.configuration,
      {std::numeric_limits<std::size_t>::max(), false, true});
  if (!recordStatus)
    return recordStatus;
  if (entry.configuration.schemaIdentifier !=
          "wave-vortex-forcing-configuration-v1" ||
      entry.configuration.schemaVersion != 1)
    return invalid("Forcing configuration uses an unsupported schema.");
  std::set<std::string> allowed;
  for (const auto &field : value->persistence.fields) {
    allowed.insert(field.recordName);
    if (!field.imaginaryRecordName.empty())
      allowed.insert(field.imaginaryRecordName);
    const auto *stored = entry.configuration.value(field.recordName);
    if (stored == nullptr) {
      if (field.optional)
        continue;
      return invalid("Required forcing configuration value is missing.");
    }
    if (field.encoding == WVForcingPersistenceEncoding::realVariable) {
      const auto *reals = std::get_if<std::vector<double>>(&stored->storage);
      if (reals == nullptr)
        return invalid("Forcing real configuration has the wrong type.");
      for (const double scalar : *reals) {
        if (std::isnan(scalar) || (!field.allowInfinity && !std::isfinite(scalar)) ||
            (field.positive && !(scalar > 0.0)) ||
            (field.nonnegative && scalar < 0.0))
          return invalid("Forcing real configuration violates its registered bounds.");
      }
    }
  }
  for (const auto &stored : entry.configuration.values)
    if (allowed.count(stored.name) == 0)
      return invalid("Forcing configuration contains an undeclared value.");
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

WVFrozenForcingSchedule defaultNonlinearAdvectionSchedule() {
  WVFrozenForcingSchedule schedule;
  const auto *registration =
      WVForcingFactoryRegistry::registration("WVNonlinearAdvection");
  if (registration == nullptr)
    return schedule;
  WVFrozenForcingEntry entry;
  entry.typeIdentifier = registration->matlabClassName;
  entry.contractVersion = registration->contractVersion;
  entry.name = registration->defaultName;
  entry.stage = registration->stage;
  entry.priority = registration->priority;
  entry.ordinal = 1;
  entry.configuration.schemaIdentifier =
      "wave-vortex-forcing-configuration-v1";
  entry.configuration.schemaVersion = 1;
  schedule.entries.push_back(std::move(entry));
  return schedule;
}

} // namespace wavevortex::runtime
