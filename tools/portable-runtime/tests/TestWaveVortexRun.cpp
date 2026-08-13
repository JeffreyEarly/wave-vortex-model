#include "WaveVortexRuntime/WVCheckpointReader.hpp"

#include <cstdlib>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
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

std::string number(double value) {
    std::ostringstream stream;
    stream << std::setprecision(17) << value;
    return stream.str();
}

double relativeDifference(const WVCheckpoint& first, const WVCheckpoint& second) {
    double difference = 0.0;
    double scale = 0.0;
    const std::vector<wavevortex::WVComplex64>* firstValues[] = {&first.state.coefficients.Ap,&first.state.coefficients.Am,&first.state.coefficients.A0};
    const std::vector<wavevortex::WVComplex64>* secondValues[] = {&second.state.coefficients.Ap,&second.state.coefficients.Am,&second.state.coefficients.A0};
    for (std::size_t component = 0; component < 3; ++component) {
        require(firstValues[component]->size() == secondValues[component]->size(),"restart comparison shapes differ");
        for (std::size_t index = 0; index < firstValues[component]->size(); ++index) {
            const auto left = (*firstValues[component])[index];
            const auto right = (*secondValues[component])[index];
            difference = std::max(difference,std::hypot(left.real-right.real,left.imag-right.imag));
            scale = std::max(scale,std::max(std::hypot(left.real,left.imag),std::hypot(right.real,right.imag)));
        }
    }
    return difference/std::max(scale,std::numeric_limits<double>::min());
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
        require(reportText.find("\"arrayTraffic\"") != std::string::npos && reportText.find("\"stageStateConstructionReads\":1296") != std::string::npos,"runner omitted exact RK4 traffic diagnostics");
        require(reportText.find("\"stageFluxClearWrites\":0") != std::string::npos && reportText.find("\"weightedFluxInitializationReads\":216") != std::string::npos,"runner omitted eliminated-clear and first-stage initialization diagnostics");
        require(reportText.find("\"contractAbstractionAdditionalArrayStorage\":0") != std::string::npos,"runner reported array-sized contract workspace");
        const auto adaptiveOutput = directory/"adaptive-output.nc";
        const auto adaptiveReport = directory/"adaptive-report.json";
        require(run(quote(input)+" "+quote(adaptiveOutput)+" --delta-t 0.037 --steps 2 --integrator adaptive-rk23 --relative-tolerance 1e-3 --absolute-tolerance 1e-6 --fft-provider reference --report "+quote(adaptiveReport)) == 0,"adaptive runner execution failed");
        WVCheckpoint adaptiveCheckpoint;
        status = WVCheckpointReader::read(adaptiveOutput.string(),adaptiveCheckpoint);
        require(static_cast<bool>(status) && adaptiveCheckpoint.state.t > checkpoint.state.t-0.074,"adaptive runner output is not readable or did not advance");
        const auto adaptiveReportText = text(adaptiveReport);
        require(adaptiveReportText.find("\"id\":\"adaptive-rk23\"") != std::string::npos && adaptiveReportText.find("\"rejectedStepCount\":") != std::string::npos && adaptiveReportText.find("\"nextStepSize\":") != std::string::npos && adaptiveReportText.find("\"denseOutputEvaluationCount\":") != std::string::npos && adaptiveReportText.find("\"denseOutputSeconds\":") != std::string::npos,"adaptive runner report omitted method diagnostics");
        const auto adaptiveDenseOutput = directory/"adaptive-dense-output.nc";
        const auto adaptiveDenseReport = directory/"adaptive-dense-report.json";
        require(run(quote(input)+" "+quote(adaptiveDenseOutput)+" --delta-t 1e-7 --steps 2 --integrator adaptive-rk23 --fft-provider reference --benchmark-dense-outputs-per-step 1 --report "+quote(adaptiveDenseReport)) == 0,"adaptive runner dense-output execution failed");
        const auto adaptiveDenseReportText = text(adaptiveDenseReport);
        require(adaptiveDenseReportText.find("\"denseOutputEvaluationCount\":2") != std::string::npos && adaptiveDenseReportText.find("\"interpolatedOutputCount\":2") != std::string::npos,"adaptive runner did not report its dense-output work");
        const std::vector<std::string> forcingFixtures{
            "forcing-nonlinear.nc","forcing-adaptive-damping.nc","forcing-fixed-amplitude.nc","forcing-quadratic-bottom-friction.nc",
            "forcing-pseudo-topographic.nc","forcing-beta-plane.nc","forcing-mixed-hydrostatic.nc","forcing-mixed-nonhydrostatic.nc"};
        for (const auto& fixture : forcingFixtures) {
            const auto fixtureInput = std::filesystem::path(WV_RUNTIME_FIXTURE_DIR)/fixture;
            const auto fixtureOutput = directory/("adaptive-"+fixture);
            require(run(quote(fixtureInput)+" "+quote(fixtureOutput)+" --delta-t 1e-5 --steps 1 --integrator adaptive-rk23 --fft-provider reference >/dev/null 2>&1") == 0,"adaptive runner failed forcing fixture "+fixture);
        }
        WVCheckpoint initialCheckpoint;
        require(static_cast<bool>(WVCheckpointReader::read(input.string(),initialCheckpoint)),"adaptive restart input is unreadable");
        const auto continuous = directory/"adaptive-continuous.nc";
        const auto midpoint = directory/"adaptive-midpoint.nc";
        const auto restarted = directory/"adaptive-restarted.nc";
        const double midpointTime = initialCheckpoint.state.t+1e-5;
        const double finalTime = initialCheckpoint.state.t+2e-5;
        const auto adaptiveArguments = std::string(" --delta-t 1e-5 --integrator adaptive-rk23 --relative-tolerance 1e-6 --absolute-tolerance 1e-8 --fft-provider reference");
        require(run(quote(input)+" "+quote(continuous)+adaptiveArguments+" --final-time "+number(finalTime)+" >/dev/null 2>&1") == 0,"continuous adaptive restart control failed");
        require(run(quote(input)+" "+quote(midpoint)+adaptiveArguments+" --final-time "+number(midpointTime)+" >/dev/null 2>&1") == 0,"adaptive midpoint checkpoint failed");
        require(run(quote(midpoint)+" "+quote(restarted)+adaptiveArguments+" --final-time "+number(finalTime)+" >/dev/null 2>&1") == 0,"adaptive restart continuation failed");
        WVCheckpoint continuousCheckpoint;
        WVCheckpoint restartedCheckpoint;
        require(static_cast<bool>(WVCheckpointReader::read(continuous.string(),continuousCheckpoint)) && static_cast<bool>(WVCheckpointReader::read(restarted.string(),restartedCheckpoint)),"adaptive restart outputs are unreadable");
        require(relativeDifference(continuousCheckpoint,restartedCheckpoint) <= 1e-6,"adaptive restart exceeded tolerance-based trajectory equivalence");
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --final-time 9 --fft-provider reference >/dev/null 2>&1") != 0,"runner accepted both endpoint modes");
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --fft-provider native-fftw >/dev/null 2>&1") != 0,"reference-only build silently substituted a provider");
        const auto sentinel = bytes(output);
        require(run(quote(input)+" "+quote(output)+" --delta-t bad --steps 1 --fft-provider reference >/dev/null 2>&1") != 0,"runner accepted malformed deltaT");
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --integrator fixed-rk4 --relative-tolerance 1e-3 --fft-provider reference >/dev/null 2>&1") != 0,"fixed runner accepted adaptive tolerance options");
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --integrator unknown --fft-provider reference >/dev/null 2>&1") != 0,"runner accepted an unknown integrator");
        require(bytes(output) == sentinel,"argument failure changed an existing output");
        std::filesystem::remove_all(directory);
        std::cout << "Standalone runner tests passed.\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
