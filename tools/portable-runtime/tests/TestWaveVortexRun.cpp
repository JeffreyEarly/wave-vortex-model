#include "WaveVortexRuntime/WVCheckpointReader.hpp"

#include <algorithm>
#include <cstdlib>
#include <chrono>
#include <csignal>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#if defined(__APPLE__) || defined(__linux__)
#include <unistd.h>
#endif

namespace {

using namespace wavevortex::runtime;

void require(bool condition, const std::string& message) { if (!condition) throw std::runtime_error(message); }

std::string quote(const std::filesystem::path& path) { return "\""+path.string()+"\""; }

int run(const std::string& arguments) { return std::system((quote(WV_RUNTIME_RUNNER)+" "+arguments).c_str()); }

int runWithPid(const std::string& arguments, const std::filesystem::path& pidFile) {
    return std::system((quote(WV_RUNTIME_RUNNER)+" "+arguments+" >/dev/null 2>&1 & echo $! > "+quote(pidFile)+"; wait $!").c_str());
}

std::vector<char> bytes(const std::filesystem::path& path) {
    std::ifstream input(path,std::ios::binary);
    return {std::istreambuf_iterator<char>(input),std::istreambuf_iterator<char>()};
}

std::string text(const std::filesystem::path& path) {
    std::ifstream input(path,std::ios::binary);
    return {std::istreambuf_iterator<char>(input),std::istreambuf_iterator<char>()};
}

void waitForText(const std::filesystem::path& path, const std::string& expected) {
    for (std::size_t attempt = 0; attempt < 1000; ++attempt) {
        if (std::filesystem::exists(path) && text(path).find(expected) != std::string::npos) return;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    throw std::runtime_error("timed out waiting for runner phase "+expected);
}

void waitForNonemptyFile(const std::filesystem::path& path) {
    for (std::size_t attempt = 0; attempt < 1000; ++attempt) {
        if (std::filesystem::exists(path) && !text(path).empty()) return;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    throw std::runtime_error("timed out waiting for "+path.string());
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

bool hasFiniteState(const WVCheckpoint& checkpoint) {
    const std::vector<wavevortex::WVComplex64>* values[] = {
        &checkpoint.state.coefficients.Ap,&checkpoint.state.coefficients.Am,&checkpoint.state.coefficients.A0};
    for (const auto* component : values) {
        for (const auto value : *component) {
            if (!std::isfinite(value.real) || !std::isfinite(value.imag)) return false;
        }
    }
    return true;
}

double jsonNumber(const std::string& json, const std::string& key) {
    const auto position = json.find("\""+key+"\":");
    require(position != std::string::npos,"JSON field is missing: "+key);
    const char* begin = json.c_str()+position+key.size()+3;
    char* end = nullptr;
    const double value = std::strtod(begin,&end);
    require(end != begin,"JSON field is not numeric: "+key);
    return value;
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
        WVCheckpoint initialCheckpoint;
        require(static_cast<bool>(WVCheckpointReader::read(input.string(),initialCheckpoint)),"scheduled-output input is unreadable");
        const double scheduledMidpoint = initialCheckpoint.state.t+5e-6;
        const double scheduledEndpoint = initialCheckpoint.state.t+1e-5;
        const double scheduledFinalTime = initialCheckpoint.state.t+2e-5;
        const auto scheduledDirectory = directory/"scheduled-fixed";
        const auto scheduledReport = directory/"scheduled-fixed-report.json";
        const auto fixedScheduledArguments = std::string(" --delta-t 1e-5 --final-time ")+number(scheduledFinalTime)+" --fft-provider reference --output-time "+number(initialCheckpoint.state.t)+" --output-time "+number(scheduledMidpoint)+" --output-time "+number(scheduledEndpoint)+" --output-time "+number(scheduledFinalTime)+" --output-directory "+quote(scheduledDirectory)+" --report "+quote(scheduledReport);
        require(run(quote(input)+fixedScheduledArguments) == 0,"fixed runner scheduled-output execution failed");
        const std::vector<std::filesystem::path> scheduledPaths{
            scheduledDirectory/"checkpoint-000001.nc",scheduledDirectory/"checkpoint-000002.nc",
            scheduledDirectory/"checkpoint-000003.nc",scheduledDirectory/"checkpoint-000004.nc"};
        for (std::size_t index = 0; index < scheduledPaths.size(); ++index) {
            WVCheckpoint scheduledCheckpoint;
            require(static_cast<bool>(WVCheckpointReader::read(scheduledPaths[index].string(),scheduledCheckpoint)),"fixed scheduled checkpoint is not readable");
            const double expectedTimes[] = {initialCheckpoint.state.t,scheduledMidpoint,scheduledEndpoint,scheduledFinalTime};
            require(std::abs(scheduledCheckpoint.state.t-expectedTimes[index]) <= 1e-14,"fixed scheduled checkpoint has the wrong time");
        }
        const auto scheduledReportText = text(scheduledReport);
        require(scheduledReportText.find("\"requestedCount\":4") != std::string::npos && scheduledReportText.find("\"committedCount\":4") != std::string::npos,"fixed scheduled-output report omitted counts");
        require(scheduledReportText.find("\"eventKind\":\"initial\"") != std::string::npos && scheduledReportText.find("\"eventKind\":\"interpolated\"") != std::string::npos && scheduledReportText.find("\"eventKind\":\"accepted-endpoint\"") != std::string::npos,"fixed scheduled-output report omitted event kinds");
        const auto scheduledSentinel = bytes(scheduledPaths.front());
        require(run(quote(input)+fixedScheduledArguments+" >/dev/null 2>&1") != 0,"scheduled output replaced existing checkpoints");
        require(bytes(scheduledPaths.front()) == scheduledSentinel,"scheduled output collision changed an existing checkpoint");

        const auto lateFailureDirectory = directory/"late-failure";
        const auto lateFailurePhase = directory/"late-failure.phase";
        const auto lateFailureReport = directory/"late-failure.json";
        const auto lateFailureArguments = quote(input)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-time "+number(scheduledFinalTime)+" --output-directory "+quote(lateFailureDirectory)+" --phase-file "+quote(lateFailurePhase)+" --report "+quote(lateFailureReport)+" >/dev/null 2>&1";
        int lateFailureStatus = 0;
        std::thread lateFailureWorker([&] { lateFailureStatus = run(lateFailureArguments); });
        waitForText(lateFailurePhase,"output-committed:1");
        const auto racedDestination = lateFailureDirectory/"checkpoint-000002.nc";
        {
            std::ofstream stream(racedDestination,std::ios::binary);
            stream << "protected";
        }
        lateFailureWorker.join();
        require(lateFailureStatus != 0,"later scheduled-output collision unexpectedly succeeded");
        WVCheckpoint earlierCommitted;
        require(static_cast<bool>(WVCheckpointReader::read((lateFailureDirectory/"checkpoint-000001.nc").string(),earlierCommitted)),"later scheduled-output failure corrupted the earlier checkpoint");
        require(text(racedDestination) == "protected","later scheduled-output failure replaced the raced destination");
        const auto lateFailureReportText = text(lateFailureReport);
        require(lateFailureReportText.find("\"committedCount\":1") != std::string::npos && lateFailureReportText.find("\"status\":\"failed\"") != std::string::npos,"later scheduled-output failure report omitted partial results");

#if defined(__APPLE__) || defined(__linux__)
        const auto interruptedDirectory = directory/"interrupted";
        const auto interruptedPhase = directory/"interrupted.phase";
        const auto interruptedPid = directory/"interrupted.pid";
        const auto interruptedArguments = quote(input)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-time "+number(scheduledFinalTime)+" --output-directory "+quote(interruptedDirectory)+" --phase-file "+quote(interruptedPhase);
        int interruptedStatus = 0;
        std::thread interruptedWorker([&] { interruptedStatus = runWithPid(interruptedArguments,interruptedPid); });
        waitForText(interruptedPhase,"output-committed:1");
        waitForNonemptyFile(interruptedPid);
        std::ifstream pidInput(interruptedPid);
        int processIdentifier = 0;
        pidInput >> processIdentifier;
        require(processIdentifier > 0 && ::kill(processIdentifier,SIGTERM) == 0,"unable to interrupt scheduled-output runner");
        interruptedWorker.join();
        require(interruptedStatus != 0,"interrupted scheduled-output runner reported success");
        WVCheckpoint interruptedCheckpoint;
        require(static_cast<bool>(WVCheckpointReader::read((interruptedDirectory/"checkpoint-000001.nc").string(),interruptedCheckpoint)),"interruption corrupted the committed checkpoint");
        require(!std::filesystem::exists(interruptedDirectory/"checkpoint-000002.nc"),"interruption created a later checkpoint");
#endif

        const auto fixedControl = directory/"fixed-scheduled-control.nc";
        require(run(quote(input)+" "+quote(fixedControl)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference >/dev/null 2>&1") == 0,"fixed scheduled-output control failed");
        WVCheckpoint fixedControlCheckpoint;
        WVCheckpoint fixedScheduledFinal;
        require(static_cast<bool>(WVCheckpointReader::read(fixedControl.string(),fixedControlCheckpoint)) && static_cast<bool>(WVCheckpointReader::read(scheduledPaths.back().string(),fixedScheduledFinal)),"fixed scheduled-output comparison is unreadable");
        require(relativeDifference(fixedControlCheckpoint,fixedScheduledFinal) == 0.0,"fixed scheduled output changed the accepted trajectory");
        const auto fixedInterpolatedRestart = directory/"fixed-interpolated-restart.nc";
        require(run(quote(scheduledPaths[1])+" "+quote(fixedInterpolatedRestart)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference >/dev/null 2>&1") == 0,"fixed interpolated checkpoint did not restart");
        WVCheckpoint fixedInterpolatedRestartCheckpoint;
        require(static_cast<bool>(WVCheckpointReader::read(fixedInterpolatedRestart.string(),fixedInterpolatedRestartCheckpoint)),"fixed interpolated restart is unreadable");
        require(std::abs(fixedInterpolatedRestartCheckpoint.state.t-scheduledFinalTime) <= 1e-12 && hasFiniteState(fixedInterpolatedRestartCheckpoint),"fixed interpolated checkpoint did not produce a finite restart at the requested final time");
        const auto adaptiveOutput = directory/"adaptive-output.nc";
        const auto adaptiveReport = directory/"adaptive-report.json";
        require(run(quote(input)+" "+quote(adaptiveOutput)+" --delta-t 0.037 --steps 2 --integrator adaptive-rk23 --relative-tolerance 1e-3 --absolute-tolerance 1e-6 --fft-provider reference --report "+quote(adaptiveReport)) == 0,"adaptive runner execution failed");
        WVCheckpoint adaptiveCheckpoint;
        status = WVCheckpointReader::read(adaptiveOutput.string(),adaptiveCheckpoint);
        require(static_cast<bool>(status) && adaptiveCheckpoint.state.t > checkpoint.state.t-0.074,"adaptive runner output is not readable or did not advance");
        const auto adaptiveReportText = text(adaptiveReport);
        require(adaptiveReportText.find("\"id\":\"adaptive-rk23\"") != std::string::npos && adaptiveReportText.find("\"rejectedStepCount\":") != std::string::npos && adaptiveReportText.find("\"nextStepSize\":") != std::string::npos && adaptiveReportText.find("\"denseOutputEvaluationCount\":") != std::string::npos && adaptiveReportText.find("\"denseOutputSeconds\":") != std::string::npos,"adaptive runner report omitted method diagnostics");
        const auto adaptiveSeriesDirectory = directory/"scheduled-adaptive";
        const auto adaptiveSeriesReport = directory/"scheduled-adaptive-report.json";
        const auto adaptiveSeriesArguments = std::string(" --delta-t 1e-5 --final-time ")+number(scheduledFinalTime)+" --integrator adaptive-rk23 --relative-tolerance 1e-6 --absolute-tolerance 1e-8 --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-time "+number(scheduledFinalTime)+" --output-directory "+quote(adaptiveSeriesDirectory)+" --output-pattern 'state-{index}-{time}.nc' --report "+quote(adaptiveSeriesReport);
        require(run(quote(input)+adaptiveSeriesArguments) == 0,"adaptive runner public scheduled-output execution failed");
        const auto adaptiveSeriesText = text(adaptiveSeriesReport);
        require(adaptiveSeriesText.find("\"requestedCount\":2") != std::string::npos && adaptiveSeriesText.find("\"committedCount\":2") != std::string::npos && adaptiveSeriesText.find("\"status\":\"committed\"") != std::string::npos,"adaptive scheduled-output report is incomplete");
        std::vector<std::filesystem::path> adaptiveSeriesPaths;
        for (const auto& entry : std::filesystem::directory_iterator(adaptiveSeriesDirectory)) adaptiveSeriesPaths.push_back(entry.path());
        std::sort(adaptiveSeriesPaths.begin(),adaptiveSeriesPaths.end());
        require(adaptiveSeriesPaths.size() == 2,"adaptive scheduled output wrote the wrong number of checkpoints");
        for (const auto& path : adaptiveSeriesPaths) {
            WVCheckpoint emitted;
            require(static_cast<bool>(WVCheckpointReader::read(path.string(),emitted)),"adaptive scheduled checkpoint is not readable");
        }
        const auto adaptiveSeriesControl = directory/"scheduled-adaptive-control.nc";
        const auto adaptiveSeriesControlReport = directory/"scheduled-adaptive-control.json";
        require(run(quote(input)+" "+quote(adaptiveSeriesControl)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --integrator adaptive-rk23 --relative-tolerance 1e-6 --absolute-tolerance 1e-8 --fft-provider reference --report "+quote(adaptiveSeriesControlReport)) == 0,"adaptive scheduled-output control failed");
        WVCheckpoint adaptiveSeriesFinal;
        WVCheckpoint adaptiveSeriesControlCheckpoint;
        require(static_cast<bool>(WVCheckpointReader::read(adaptiveSeriesPaths.back().string(),adaptiveSeriesFinal)) && static_cast<bool>(WVCheckpointReader::read(adaptiveSeriesControl.string(),adaptiveSeriesControlCheckpoint)),"adaptive scheduled-output comparison is unreadable");
        require(relativeDifference(adaptiveSeriesFinal,adaptiveSeriesControlCheckpoint) == 0.0,"adaptive scheduled output changed the accepted trajectory");
        const auto adaptiveSeriesControlText = text(adaptiveSeriesControlReport);
        for (const auto& field : {"stepCount","rejectedStepCount","rhsEvaluationCount"}) require(jsonNumber(adaptiveSeriesText,field) == jsonNumber(adaptiveSeriesControlText,field),"adaptive scheduled output changed "+std::string(field));
        const auto adaptiveInterpolatedRestart = directory/"adaptive-interpolated-restart.nc";
        require(run(quote(adaptiveSeriesPaths.front())+" "+quote(adaptiveInterpolatedRestart)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --integrator adaptive-rk23 --relative-tolerance 1e-6 --absolute-tolerance 1e-8 --fft-provider reference >/dev/null 2>&1") == 0,"adaptive interpolated checkpoint did not restart");
        WVCheckpoint adaptiveInterpolatedRestartCheckpoint;
        require(static_cast<bool>(WVCheckpointReader::read(adaptiveInterpolatedRestart.string(),adaptiveInterpolatedRestartCheckpoint)),"adaptive interpolated restart is unreadable");
        require(relativeDifference(adaptiveSeriesControlCheckpoint,adaptiveInterpolatedRestartCheckpoint) <= 1e-6,"adaptive interpolated restart exceeded tolerance-equivalent continuation");
        const auto adaptiveDenseOutput = directory/"adaptive-dense-output.nc";
        const auto adaptiveDenseReport = directory/"adaptive-dense-report.json";
        require(run(quote(input)+" "+quote(adaptiveDenseOutput)+" --delta-t 1e-7 --steps 2 --integrator adaptive-rk23 --fft-provider reference --benchmark-dense-outputs-per-step 1 --report "+quote(adaptiveDenseReport)) == 0,"adaptive runner dense-output execution failed");
        const auto adaptiveDenseReportText = text(adaptiveDenseReport);
        require(adaptiveDenseReportText.find("\"denseOutputEvaluationCount\":2") != std::string::npos && adaptiveDenseReportText.find("\"interpolatedOutputCount\":2") != std::string::npos,"adaptive runner did not report its dense-output work");
        const auto adaptiveScheduledOutput = directory/"adaptive-scheduled-output.nc";
        const auto adaptiveScheduledReport = directory/"adaptive-scheduled-report.json";
        require(run(quote(input)+" "+quote(adaptiveScheduledOutput)+" --delta-t 1e-7 --final-time 8.9510002 --integrator adaptive-rk23 --fft-provider reference --benchmark-output-count 4 --report "+quote(adaptiveScheduledReport)) == 0,"adaptive runner scheduled-output execution failed");
        const auto adaptiveScheduledReportText = text(adaptiveScheduledReport);
        require(adaptiveScheduledReportText.find("\"requestedOutputCount\":4") != std::string::npos && adaptiveScheduledReportText.find("\"interpolatedOutputCount\":4") != std::string::npos && adaptiveScheduledReportText.find("\"interpolationSeconds\":") != std::string::npos,"adaptive runner did not report scheduled-output work");
        const std::vector<std::string> forcingFixtures{
            "forcing-nonlinear.nc","forcing-adaptive-damping.nc","forcing-fixed-amplitude.nc","forcing-quadratic-bottom-friction.nc",
            "forcing-pseudo-topographic.nc","forcing-beta-plane.nc","forcing-mixed-hydrostatic.nc","forcing-mixed-nonhydrostatic.nc"};
        for (const auto& fixture : forcingFixtures) {
            const auto fixtureInput = std::filesystem::path(WV_RUNTIME_FIXTURE_DIR)/fixture;
            const auto fixtureOutput = directory/("adaptive-"+fixture);
            require(run(quote(fixtureInput)+" "+quote(fixtureOutput)+" --delta-t 1e-5 --steps 1 --integrator adaptive-rk23 --fft-provider reference >/dev/null 2>&1") == 0,"adaptive runner failed forcing fixture "+fixture);
        }
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
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --integrator adaptive-rk23 --benchmark-output-count 2 --fft-provider reference >/dev/null 2>&1") != 0,"adaptive runner accepted scheduled outputs without final-time integration");
        require(run(quote(input)+" "+quote(output)+" --delta-t 0.037 --steps 1 --integrator unknown --fft-provider reference >/dev/null 2>&1") != 0,"runner accepted an unknown integrator");
        const auto invalidSeriesDirectory = directory/"invalid-series";
        require(run(quote(input)+" "+quote(output)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-directory "+quote(invalidSeriesDirectory)+" >/dev/null 2>&1") != 0,"runner accepted positional OUTPUT with scheduled output");
        require(run(quote(input)+" --delta-t 1e-5 --steps 2 --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-directory "+quote(invalidSeriesDirectory)+" >/dev/null 2>&1") != 0,"runner accepted --steps with scheduled output");
        require(run(quote(input)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-time "+number(scheduledMidpoint)+" --output-directory "+quote(invalidSeriesDirectory)+" >/dev/null 2>&1") != 0,"runner accepted duplicate scheduled times");
        require(run(quote(input)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-directory "+quote(invalidSeriesDirectory)+" --output-pattern '../escape-{index}.nc' >/dev/null 2>&1") != 0,"runner accepted a scheduled-output path escape");
        const auto outputDirectoryFile = directory/"not-a-directory";
        {
            std::ofstream stream(outputDirectoryFile);
            stream << "file";
        }
        require(run(quote(input)+" --delta-t 1e-5 --final-time "+number(scheduledFinalTime)+" --fft-provider reference --output-time "+number(scheduledMidpoint)+" --output-directory "+quote(outputDirectoryFile)+" >/dev/null 2>&1") != 0,"runner accepted a file as the scheduled output directory");
        require(bytes(output) == sentinel,"argument failure changed an existing output");
        std::filesystem::remove_all(directory);
        std::cout << "Standalone runner tests passed.\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
