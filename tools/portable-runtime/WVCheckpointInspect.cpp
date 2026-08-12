#include "WaveVortexRuntime/WVCheckpointReader.hpp"

#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>
#include <type_traits>

using wavevortex::runtime::WVCheckpoint;
using wavevortex::runtime::WVCheckpointReader;
using wavevortex::runtime::WVCheckpointStateSelection;

namespace {

std::string escaped(const std::string& value) {
    std::string result;
    for (const char character : value) {
        switch (character) {
            case '\\': result += "\\\\"; break;
            case '"': result += "\\\""; break;
            case '\n': result += "\\n"; break;
            case '\r': result += "\\r"; break;
            case '\t': result += "\\t"; break;
            default: result += character; break;
        }
    }
    return result;
}

void complexComponent(const std::vector<wavevortex::WVComplex64>& values, bool imaginary) {
    std::cout << '[';
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) std::cout << ',';
        std::cout << (imaginary ? values[index].imag : values[index].real);
    }
    std::cout << ']';
}

void indices(const std::vector<std::size_t>& values) {
    std::cout << '[';
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) std::cout << ',';
        std::cout << values[index] + 1;
    }
    std::cout << ']';
}

void jsonDouble(double value) {
    if (std::isinf(value)) {
        std::cout << (value > 0.0 ? "\"Inf\"" : "\"-Inf\"");
    } else if (std::isnan(value)) {
        std::cout << "\"NaN\"";
    } else {
        std::cout << value;
    }
}

void capabilities() {
    std::cout << "{\"profile\":\"" << wavevortex::WVForcingScheduleProfileIdentifier << "\",\"version\":" << wavevortex::WVForcingScheduleProfileVersion << ",\"capabilities\":[";
    const auto& values = wavevortex::forcingCapabilities();
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) std::cout << ',';
        const auto& value = values[index];
        std::cout << "{\"typeIdentifier\":\"" << escaped(value.typeIdentifier) << "\",\"forcingTypes\":[";
        for (std::size_t typeIndex = 0; typeIndex < value.forcingTypes.size(); ++typeIndex) {
            if (typeIndex != 0) std::cout << ',';
            std::cout << "\"" << escaped(value.forcingTypes[typeIndex]) << "\"";
        }
        std::cout << "],\"isSupported\":" << (value.isSupported ? "true" : "false") << ",\"reason\":\"" << escaped(value.unavailabilityReason) << "\"}";
    }
    std::cout << "]}\n";
}

void forcingPayload(const wavevortex::WVFrozenForcingEntry& entry, bool includeArrays) {
    std::visit([includeArrays](const auto& payload) {
        using Payload = std::decay_t<decltype(payload)>;
        std::cout << '{';
        if constexpr (std::is_same_v<Payload, wavevortex::WVBottomFrictionQuadraticRecord>) {
            std::cout << "\"Cd\":" << payload.Cd;
        } else if constexpr (std::is_same_v<Payload, wavevortex::WVFixedAmplitudeForcingRecord>) {
            std::cout << "\"ApCount\":" << payload.ApIndices.size() << ",\"AmCount\":" << payload.AmIndices.size() << ",\"A0Count\":" << payload.A0Indices.size();
            if (includeArrays) {
                std::cout << ",\"ApIndices\":"; indices(payload.ApIndices);
                std::cout << ",\"ApReal\":"; complexComponent(payload.ApValues, false);
                std::cout << ",\"ApImag\":"; complexComponent(payload.ApValues, true);
                std::cout << ",\"AmIndices\":"; indices(payload.AmIndices);
                std::cout << ",\"AmReal\":"; complexComponent(payload.AmValues, false);
                std::cout << ",\"AmImag\":"; complexComponent(payload.AmValues, true);
                std::cout << ",\"A0Indices\":"; indices(payload.A0Indices);
                std::cout << ",\"A0Real\":"; complexComponent(payload.A0Values, false);
                std::cout << ",\"A0Imag\":"; complexComponent(payload.A0Values, true);
            }
        } else if constexpr (std::is_same_v<Payload, wavevortex::WVPseudoTopographicWaveGenerationRecord>) {
            std::cout << "\"topographicShape\":[" << payload.topographicShape.rows << ',' << payload.topographicShape.columns << ']';
            std::cout << ",\"barotropicVelocityReal\":[" << payload.barotropicVelocityAmplitude[0].real << ',' << payload.barotropicVelocityAmplitude[1].real << ']';
            std::cout << ",\"barotropicVelocityImag\":[" << payload.barotropicVelocityAmplitude[0].imag << ',' << payload.barotropicVelocityAmplitude[1].imag << ']';
            std::cout << ",\"frequency\":" << payload.frequency << ",\"darwinSymbol\":\"" << escaped(payload.darwinSymbol) << "\"";
            std::cout << ",\"rampDuration\":" << payload.rampDuration << ",\"startTime\":" << payload.startTime;
            std::cout << ",\"shouldAvoidAdaptiveDamping\":" << (payload.shouldAvoidAdaptiveDamping ? "true" : "false");
            std::cout << ",\"maximumForcedHorizontalWavenumber\":"; jsonDouble(payload.maximumForcedHorizontalWavenumber);
            std::cout << ",\"maximumForcedVerticalMode\":"; jsonDouble(payload.maximumForcedVerticalMode);
            if (includeArrays) {
                std::cout << ",\"topographicHeight\":[";
                for (std::size_t index = 0; index < payload.topographicHeight.size(); ++index) {
                    if (index != 0) std::cout << ',';
                    std::cout << payload.topographicHeight[index];
                }
                std::cout << ']';
            }
        }
        std::cout << '}';
    }, entry.payload);
}

} // namespace

int main(int argc, char** argv) {
    if (argc == 2 && std::string(argv[1]) == "--forcing-capabilities") {
        capabilities();
        return 0;
    }
    if (argc < 2 || argc > 5) {
        std::cerr << "usage: wv_checkpoint_inspect checkpoint.nc [zero-based-state-index] [--include-coefficients] [--include-forcing-arrays]\n"
                  << "       wv_checkpoint_inspect --forcing-capabilities\n";
        return 2;
    }
    WVCheckpointStateSelection selection = WVCheckpointStateSelection::latest();
    bool includeCoefficients = false;
    bool includeForcingArrays = false;
    bool hasIndex = false;
    for (int index = 2; index < argc; ++index) {
        if (std::string(argv[index]) == "--include-coefficients") {
            includeCoefficients = true;
        } else if (std::string(argv[index]) == "--include-forcing-arrays") {
            includeForcingArrays = true;
        } else if (!hasIndex) {
            selection = WVCheckpointStateSelection::atIndex(static_cast<std::size_t>(std::stoull(argv[index])));
            hasIndex = true;
        } else {
            std::cerr << "Only one state index may be supplied.\n";
            return 2;
        }
    }
    WVCheckpoint checkpoint;
    const auto status = WVCheckpointReader::read(argv[1], checkpoint, selection);
    if (!status) {
        std::cerr << status.message << '\n';
        return 3;
    }
    const auto& configuration = checkpoint.configuration;
    const auto& metadata = checkpoint.metadata;
    std::cout << std::setprecision(17);
    std::cout << "{\"profile\":\"" << escaped(metadata.profileIdentifier) << "\"";
    std::cout << ",\"modelVersion\":\"" << escaped(metadata.modelVersion) << "\"";
    std::cout << ",\"transformClass\":\"" << escaped(metadata.transformClass) << "\"";
    std::cout << ",\"stateGroupPath\":\"" << escaped(metadata.stateGroupPath) << "\"";
    std::cout << ",\"selectedStateIndex\":" << metadata.selectedStateIndex;
    std::cout << ",\"stateCount\":" << metadata.stateCount;
    std::cout << ",\"shape\":[" << configuration.Nj << ',' << checkpoint.state.coefficients.shape.columns << ']';
    std::cout << ",\"grid\":[" << configuration.Nx << ',' << configuration.Ny << ',' << configuration.Nz << ']';
    std::cout << ",\"t\":" << checkpoint.state.t << ",\"t0\":" << checkpoint.state.t0;
    std::cout << ",\"isHydrostatic\":" << (configuration.isHydrostatic ? "true" : "false");
    std::cout << ",\"shouldAntialias\":" << (configuration.shouldAntialias ? "true" : "false");
    if (includeCoefficients) {
        std::cout << ",\"ApReal\":"; complexComponent(checkpoint.state.coefficients.Ap, false);
        std::cout << ",\"ApImag\":"; complexComponent(checkpoint.state.coefficients.Ap, true);
        std::cout << ",\"AmReal\":"; complexComponent(checkpoint.state.coefficients.Am, false);
        std::cout << ",\"AmImag\":"; complexComponent(checkpoint.state.coefficients.Am, true);
        std::cout << ",\"A0Real\":"; complexComponent(checkpoint.state.coefficients.A0, false);
        std::cout << ",\"A0Imag\":"; complexComponent(checkpoint.state.coefficients.A0, true);
    }
    std::cout << ",\"forcing\":[";
    for (std::size_t index = 0; index < checkpoint.forcingSchedule.entries.size(); ++index) {
        if (index != 0) std::cout << ',';
        const auto& forcing = checkpoint.forcingSchedule.entries[index];
        std::cout << "{\"ordinal\":" << forcing.ordinal << ",\"path\":\"" << escaped(forcing.sourceGroupPath)
                  << "\",\"annotatedClass\":\"" << escaped(forcing.typeIdentifier) << "\",\"name\":\"" << escaped(forcing.name)
                  << "\",\"stage\":\"" << wavevortex::forcingStageName(forcing.stage) << "\",\"priority\":" << static_cast<unsigned int>(forcing.priority) << ",\"payload\":";
        forcingPayload(forcing, includeForcingArrays);
        std::cout << '}';
    }
    std::cout << "],\"forcingProfile\":\"" << escaped(checkpoint.forcingSchedule.profileIdentifier) << "\"}\n";
    return 0;
}
