#include "WaveVortexRuntime/WVCheckpointReader.hpp"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using namespace wavevortex::runtime;

void require(bool condition, const std::string& message) { if (!condition) throw std::runtime_error(message); }

std::string quote(const std::filesystem::path& path) { return "\""+path.string()+"\""; }

int run(const std::string& arguments) { return std::system((quote(WV_RUNTIME_RUNNER)+" "+arguments).c_str()); }

std::vector<char> bytes(const std::filesystem::path& path) {
    std::ifstream input(path,std::ios::binary);
    return {std::istreambuf_iterator<char>(input),std::istreambuf_iterator<char>()};
}

std::string text(const std::filesystem::path& path) {
    std::ifstream input(path,std::ios::binary);
    return {std::istreambuf_iterator<char>(input),std::istreambuf_iterator<char>()};
}

} // namespace

int main() {
    try {
        const auto directory = std::filesystem::temp_directory_path()/"wave-vortex-run-contract";
        std::filesystem::remove_all(directory);
        std::filesystem::create_directories(directory);
        const auto input = std::filesystem::path(WV_RUNTIME_FIXTURE_DIR)/"forcing-mixed-hydrostatic.nc";
        const auto output = directory/"output.nc";
        const auto report = directory/"report.json";
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 2 --fft-provider reference --report "+quote(report)) == 0,"runner step execution failed");
        WVCheckpoint checkpoint;
        auto status = WVCheckpointReader::read(output.string(),checkpoint);
        require(static_cast<bool>(status),status.message);
        require(checkpoint.state.t > 8.949 && checkpoint.state.t < 9.025,"runner did not advance the selected state");
        require(std::filesystem::file_size(report) > 0,"runner did not write its report");
        const auto reportText = text(report);
        require(reportText.find("\"arrayTraffic\"") != std::string::npos && reportText.find("\"stageStateConstructionReads\":1512") != std::string::npos,"runner omitted exact RK4 traffic diagnostics");
        require(reportText.find("\"contractAbstractionAdditionalArrayStorage\":0") != std::string::npos,"runner reported array-sized contract workspace");
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --final-time 9 --fft-provider reference >/dev/null 2>&1") != 0,"runner accepted both endpoint modes");
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --fft-provider native-fftw >/dev/null 2>&1") != 0,"reference-only build silently substituted a provider");
        const auto sentinel = bytes(output);
        require(run(quote(input)+" "+quote(output)+" --delta-t bad --steps 1 --fft-provider reference >/dev/null 2>&1") != 0,"runner accepted malformed deltaT");
        require(bytes(output) == sentinel,"argument failure changed an existing output");
        std::filesystem::remove_all(directory);
        std::cout << "Standalone runner tests passed.\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
