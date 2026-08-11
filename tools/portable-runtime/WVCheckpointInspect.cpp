#include "WaveVortexRuntime/WVCheckpointReader.hpp"

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>

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

} // namespace

int main(int argc, char** argv) {
    if (argc < 2 || argc > 4) {
        std::cerr << "usage: wv_checkpoint_inspect checkpoint.nc [zero-based-state-index] [--include-coefficients]\n";
        return 2;
    }
    WVCheckpointStateSelection selection = WVCheckpointStateSelection::latest();
    bool includeCoefficients = false;
    bool hasIndex = false;
    for (int index = 2; index < argc; ++index) {
        if (std::string(argv[index]) == "--include-coefficients") {
            includeCoefficients = true;
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
    for (std::size_t index = 0; index < metadata.forcingHeaders.size(); ++index) {
        if (index != 0) std::cout << ',';
        const auto& forcing = metadata.forcingHeaders[index];
        std::cout << "{\"ordinal\":" << forcing.ordinal << ",\"path\":\"" << escaped(forcing.groupPath)
                  << "\",\"annotatedClass\":\"" << escaped(forcing.annotatedClass) << "\"}";
    }
    std::cout << "]}\n";
    return 0;
}
