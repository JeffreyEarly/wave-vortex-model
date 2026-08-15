#pragma once

#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <variant>
#include <vector>

namespace wavevortex {

inline constexpr std::uint32_t WVForcingScheduleProfileVersion = 1;
inline constexpr const char* WVForcingScheduleProfileIdentifier = "wave-vortex-forcing-v1";

enum class WVForcingKind : std::uint8_t {
    nonlinearAdvection,
    antialiasing,
    adaptiveDamping,
    fixedAmplitude,
    bottomFrictionQuadratic,
    pseudoTopographicWaveGeneration,
    betaPlanePVAdvection,
    horizontalDamping,
    verticalDamping,
    thermalDamping,
    bottomFrictionLinear,
    verticalDiffusivity
};

enum class WVForcingStage : std::uint8_t {
    spatial,
    spectral,
    spectralAmplitude
};

struct WVForcingCapability {
    WVForcingKind kind;
    const char* typeIdentifier;
    std::vector<std::string> forcingTypes;
    bool isSupported;
    const char* unavailabilityReason;
};

inline const std::array<WVForcingCapability, 12>& forcingCapabilities() {
    static const std::array<WVForcingCapability, 12> capabilities = {{
        {WVForcingKind::nonlinearAdvection, "WVNonlinearAdvection", {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, true, ""},
        {WVForcingKind::antialiasing, "WVAntialiasing", {"Spectral", "PVSpectral"}, false, "Transform-level antialiasing is represented by shouldAntialias; the diagnostic WVAntialiasing closure is not supported."},
        {WVForcingKind::adaptiveDamping, "WVAdaptiveDamping", {"Spectral", "PVSpectral"}, true, ""},
        {WVForcingKind::fixedAmplitude, "WVFixedAmplitudeForcing", {"SpectralAmplitude", "PVSpectralAmplitude"}, true, ""},
        {WVForcingKind::bottomFrictionQuadratic, "WVBottomFrictionQuadratic", {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, true, ""},
        {WVForcingKind::pseudoTopographicWaveGeneration, "WVPseudoTopographicWaveGeneration", {"Spectral"}, true, ""},
        {WVForcingKind::betaPlanePVAdvection, "WVBetaPlanePVAdvection", {"Spectral", "PVSpatial"}, true, ""},
        {WVForcingKind::horizontalDamping, "WVHorizontalDamping", {"HydrostaticSpatial", "NonhydrostaticSpatial"}, false, "WVHorizontalDamping is not implemented by portable runtime v1."},
        {WVForcingKind::verticalDamping, "WVVerticalDamping", {"HydrostaticSpatial", "NonhydrostaticSpatial"}, false, "WVVerticalDamping is not implemented by portable runtime v1."},
        {WVForcingKind::thermalDamping, "WVThermalDamping", {"PVSpatial"}, false, "WVThermalDamping is not implemented by portable runtime v1."},
        {WVForcingKind::bottomFrictionLinear, "WVBottomFrictionLinear", {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, false, "WVBottomFrictionLinear is not implemented by portable runtime v1."},
        {WVForcingKind::verticalDiffusivity, "WVVerticalDiffusivity", {"HydrostaticSpatial", "NonhydrostaticSpatial", "PVSpatial"}, false, "WVVerticalDiffusivity is not implemented by portable runtime v1."}
    }};
    return capabilities;
}

inline const WVForcingCapability* forcingCapability(const std::string& typeIdentifier) {
    for (const auto& capability : forcingCapabilities()) {
        if (typeIdentifier == capability.typeIdentifier) return &capability;
    }
    return nullptr;
}

inline const char* forcingStageName(WVForcingStage stage) noexcept {
    switch (stage) {
        case WVForcingStage::spatial: return "spatial";
        case WVForcingStage::spectral: return "spectral";
        case WVForcingStage::spectralAmplitude: return "spectral-amplitude";
    }
    return "unknown";
}

struct WVNonlinearAdvectionRecord {};
struct WVAdaptiveDampingRecord {};
struct WVBetaPlanePVAdvectionRecord {};

struct WVFixedAmplitudeForcingRecord {
    std::vector<std::size_t> ApIndices;
    std::vector<WVComplex64> ApValues;
    std::vector<std::size_t> AmIndices;
    std::vector<WVComplex64> AmValues;
    std::vector<std::size_t> A0Indices;
    std::vector<WVComplex64> A0Values;
};

struct WVBottomFrictionQuadraticRecord {
    double Cd = 0.0;
};

struct WVPseudoTopographicWaveGenerationRecord {
    WVShape2D topographicShape;
    std::vector<double> topographicHeight;
    std::array<WVComplex64, 2> barotropicVelocityAmplitude{};
    double frequency = 0.0;
    std::string darwinSymbol;
    double rampDuration = 0.0;
    double startTime = 0.0;
    bool shouldAvoidAdaptiveDamping = true;
    double maximumForcedHorizontalWavenumber = 0.0;
    double maximumForcedVerticalMode = 0.0;
};

using WVForcingPayload = std::variant<
    WVNonlinearAdvectionRecord,
    WVAdaptiveDampingRecord,
    WVFixedAmplitudeForcingRecord,
    WVBottomFrictionQuadraticRecord,
    WVPseudoTopographicWaveGenerationRecord,
    WVBetaPlanePVAdvectionRecord>;

struct WVFrozenForcingEntry {
    WVForcingKind kind = WVForcingKind::nonlinearAdvection;
    std::string typeIdentifier;
    std::string name;
    WVForcingStage stage = WVForcingStage::spatial;
    std::uint8_t priority = 255;
    std::size_t ordinal = 0;
    std::string sourceGroupPath;
    WVForcingPayload payload = WVNonlinearAdvectionRecord{};
};

struct WVFrozenForcingSchedule {
    std::string profileIdentifier = WVForcingScheduleProfileIdentifier;
    std::uint32_t profileVersion = WVForcingScheduleProfileVersion;
    std::vector<WVFrozenForcingEntry> entries;
};

} // namespace wavevortex
