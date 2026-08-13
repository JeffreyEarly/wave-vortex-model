#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVCheckpointWriter.hpp"
#include "WaveVortexRuntime/WVFixedStepRK4.hpp"
#include "WaveVortexRuntime/WVForcingEngine.hpp"
#include "WVReferenceFFTEngine.hpp"

#if WV_RUNTIME_HAS_NATIVE_FFTW
#include "WVNativeFFTWEngine.hpp"
#endif

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <sstream>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#if defined(__APPLE__) || defined(__linux__)
#include <sys/resource.h>
#include <unistd.h>
#endif

#if defined(__APPLE__)
#include <mach/mach.h>
#endif

namespace {

using namespace wavevortex;
using namespace wavevortex::runtime;
using Clock = std::chrono::steady_clock;

enum class ExitCode : int { success = 0, usage = 2, checkpoint = 3, provider = 4, integration = 5, output = 6 };

struct Options {
    std::string input;
    std::string output;
    std::string provider;
    std::string report;
    std::string phaseFile;
    double deltaT = 0.0;
    double finalTime = 0.0;
    std::size_t steps = 0;
    std::size_t threads = 0;
    bool hasFinalTime = false;
    bool hasSteps = false;
};

struct Timings {
    double inspect = 0.0;
    double read = 0.0;
    double construct = 0.0;
    double prepare = 0.0;
    double integrate = 0.0;
    double write = 0.0;
    double total = 0.0;
};

double seconds(Clock::time_point start) { return std::chrono::duration<double>(Clock::now()-start).count(); }

std::string jsonEscape(const std::string& value) {
    std::ostringstream output;
    for (const unsigned char character : value) {
        switch (character) {
            case '\\': output << "\\\\"; break;
            case '"': output << "\\\""; break;
            case '\n': output << "\\n"; break;
            case '\r': output << "\\r"; break;
            case '\t': output << "\\t"; break;
            default:
                if (character < 0x20) output << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<unsigned>(character) << std::dec;
                else output << character;
        }
    }
    return output.str();
}

std::string quoted(const std::string& value) { return "\""+jsonEscape(value)+"\""; }

bool parseDouble(const std::string& text, double& value) {
    char* end = nullptr;
    value = std::strtod(text.c_str(),&end);
    return end != text.c_str() && *end == '\0' && std::isfinite(value);
}

bool parseSize(const std::string& text, std::size_t& value) {
    if (text.empty() || text.front() == '-') return false;
    char* end = nullptr;
    const auto raw = std::strtoull(text.c_str(),&end,10);
    if (end == text.c_str() || *end != '\0' || raw > std::numeric_limits<std::size_t>::max()) return false;
    value = static_cast<std::size_t>(raw);
    return true;
}

bool parseOptions(int argc, char** argv, Options& options, std::string& error) {
    if (argc < 3) { error = "INPUT and OUTPUT are required."; return false; }
    options.input = argv[1];
    options.output = argv[2];
    for (int index = 3; index < argc; ++index) {
        const std::string name = argv[index];
        if (index+1 >= argc) { error = "Missing value for "+name+"."; return false; }
        const std::string value = argv[++index];
        if (name == "--delta-t") {
            if (!parseDouble(value,options.deltaT) || options.deltaT <= 0.0) { error = "--delta-t must be finite and positive."; return false; }
        } else if (name == "--steps") {
            if (!parseSize(value,options.steps) || options.steps == 0) { error = "--steps must be a positive integer."; return false; }
            options.hasSteps = true;
        } else if (name == "--final-time") {
            if (!parseDouble(value,options.finalTime)) { error = "--final-time must be finite."; return false; }
            options.hasFinalTime = true;
        } else if (name == "--fft-provider") {
            options.provider = value;
        } else if (name == "--threads") {
            if (!parseSize(value,options.threads) || options.threads == 0) { error = "--threads must be a positive integer."; return false; }
        } else if (name == "--report") {
            options.report = value;
        } else if (name == "--phase-file") {
            options.phaseFile = value;
        } else {
            error = "Unknown option "+name+".";
            return false;
        }
    }
    if (!(options.deltaT > 0.0)) { error = "--delta-t is required."; return false; }
    if (options.hasSteps == options.hasFinalTime) { error = "Exactly one of --steps or --final-time is required."; return false; }
    if (options.provider != "native-fftw" && options.provider != "reference") { error = "--fft-provider must be native-fftw or reference."; return false; }
    if (options.provider == "reference" && options.threads > 1) { error = "The reference provider supports only one thread."; return false; }
    if (options.threads == 0) options.threads = options.provider == "reference" ? 1 : std::min<std::size_t>(18,std::max(1U,std::thread::hardware_concurrency()));
    return true;
}

void phase(const Options& options, const std::string& value) {
    if (options.phaseFile.empty()) return;
    const auto temporary = options.phaseFile+".tmp";
    {
        std::ofstream output(temporary,std::ios::binary|std::ios::trunc);
        if (!output) return;
        output << value << '\n';
    }
    std::error_code ignored;
    std::filesystem::rename(temporary,options.phaseFile,ignored);
}

void phasePlateau(const Options& options, const std::string& value) {
    phase(options,value);
    if (!options.phaseFile.empty()) std::this_thread::sleep_for(std::chrono::milliseconds(100));
}

std::size_t currentRSSBytes() {
#if defined(__APPLE__)
    mach_task_basic_info information{};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(),MACH_TASK_BASIC_INFO,reinterpret_cast<task_info_t>(&information),&count) == KERN_SUCCESS) return static_cast<std::size_t>(information.resident_size);
#elif defined(__linux__)
    std::ifstream input("/proc/self/statm");
    std::size_t total = 0;
    std::size_t resident = 0;
    if (input >> total >> resident) return resident*static_cast<std::size_t>(sysconf(_SC_PAGESIZE));
#endif
    return 0;
}

std::size_t peakRSSBytes() {
#if defined(__APPLE__) || defined(__linux__)
    rusage usage{};
    if (getrusage(RUSAGE_SELF,&usage) == 0) {
#if defined(__APPLE__)
        return static_cast<std::size_t>(usage.ru_maxrss);
#else
        return static_cast<std::size_t>(usage.ru_maxrss)*1024U;
#endif
    }
#endif
    return 0;
}

std::size_t stateBytes(const WVCheckpoint& checkpoint) {
    return (checkpoint.state.coefficients.Ap.capacity()+checkpoint.state.coefficients.Am.capacity()+checkpoint.state.coefficients.A0.capacity())*sizeof(WVComplex64);
}

std::string forcingJSON(const WVFrozenForcingSchedule& schedule) {
    std::ostringstream output;
    output << '[';
    for (std::size_t index = 0; index < schedule.entries.size(); ++index) {
        if (index != 0) output << ',';
        const auto& entry = schedule.entries[index];
        output << "{\"ordinal\":" << entry.ordinal << ",\"type\":" << quoted(entry.typeIdentifier) << ",\"name\":" << quoted(entry.name) << ",\"stage\":" << static_cast<unsigned>(entry.stage) << ",\"priority\":" << static_cast<unsigned>(entry.priority) << '}';
    }
    output << ']';
    return output.str();
}

std::string failureJSON(ExitCode code, const std::string& stage, const std::string& message, const std::string& location = {}) {
    std::ostringstream output;
    output << "{\"schemaVersion\":\"wave-vortex-run-v1\",\"status\":\"failed\",\"exitCode\":" << static_cast<int>(code) << ",\"failure\":{\"stage\":" << quoted(stage) << ",\"message\":" << quoted(message) << ",\"location\":" << quoted(location) << "}}";
    return output.str();
}

void emit(const std::string& report, const std::string& path, std::ostream& stream) {
    stream << report << '\n';
    if (!path.empty()) {
        std::ofstream output(path,std::ios::binary|std::ios::trunc);
        if (output) output << report << '\n';
    }
}

std::unique_ptr<WVFFTEngine> provider(const Options& options, std::string& version, std::string& baseLibrary, std::string& threadLibrary, std::string& error) {
    if (options.provider == "reference") return std::make_unique<WVReferenceFFTEngine>();
#if WV_RUNTIME_HAS_NATIVE_FFTW
    std::unique_ptr<WVFFTEngine> result;
    const auto status = WVFFTWEngine::create(options.threads,result);
    if (!status) { error = status.message; return {}; }
    const auto identity = WVFFTWEngine::linkedLibraries();
    version = identity.version;
    baseLibrary = identity.baseLibrary;
    threadLibrary = identity.threadLibrary;
    const std::filesystem::path expected = std::filesystem::weakly_canonical(WV_RUNTIME_EXPECTED_FFTW_ROOT);
    const auto base = std::filesystem::weakly_canonical(baseLibrary);
    const auto threads = std::filesystem::weakly_canonical(threadLibrary);
    const auto underExpected = [&expected](const std::filesystem::path& value) { return value.string().rfind(expected.string()+std::string(1,std::filesystem::path::preferred_separator),0) == 0; };
    if (version.find("3.3.11") == std::string::npos || !underExpected(base) || !underExpected(threads)) {
        error = "Loaded FFTW identity does not match the configured pinned 3.3.11 provider.";
        return {};
    }
    return result;
#else
    (void)version; (void)baseLibrary; (void)threadLibrary;
    error = "This runner was built without the native FFTW provider.";
    return {};
#endif
}

} // namespace

int main(int argc, char** argv) {
    const auto totalStart = Clock::now();
    Options options;
    std::string error;
    if (!parseOptions(argc,argv,options,error)) {
        emit(failureJSON(ExitCode::usage,"arguments",error),options.report,std::cerr);
        return static_cast<int>(ExitCode::usage);
    }

    std::string providerVersion;
    std::string baseLibrary;
    std::string threadLibrary;
    auto fftEngine = provider(options,providerVersion,baseLibrary,threadLibrary,error);
    if (!fftEngine) {
        emit(failureJSON(ExitCode::provider,"provider",error),options.report,std::cerr);
        return static_cast<int>(ExitCode::provider);
    }

    Timings timings;
    phase(options,"inspect");
    WVCheckpointInspection inspection;
    auto start = Clock::now();
    auto checkpointStatus = WVCheckpointReader::inspect(options.input,inspection);
    timings.inspect = seconds(start);
    if (!checkpointStatus) {
        emit(failureJSON(ExitCode::checkpoint,"inspect",checkpointStatus.message,checkpointStatus.location),options.report,std::cerr);
        return static_cast<int>(ExitCode::checkpoint);
    }
    const auto forcingStatus = WVConstantStratificationForcingEngine::validateSchedule(inspection.configuration,inspection.forcingSchedule,inspection.coefficientShape);
    if (!forcingStatus) {
        emit(failureJSON(ExitCode::checkpoint,"forcing-preflight",forcingStatus.message),options.report,std::cerr);
        return static_cast<int>(ExitCode::checkpoint);
    }
    if (options.hasFinalTime && options.finalTime < inspection.t) {
        emit(failureJSON(ExitCode::usage,"arguments","--final-time precedes the selected checkpoint state."),options.report,std::cerr);
        return static_cast<int>(ExitCode::usage);
    }

    WVCheckpoint checkpoint;
    phase(options,"read");
    start = Clock::now();
    checkpointStatus = WVCheckpointReader::read(options.input,checkpoint);
    timings.read = seconds(start);
    if (!checkpointStatus) {
        emit(failureJSON(ExitCode::checkpoint,"read",checkpointStatus.message,checkpointStatus.location),options.report,std::cerr);
        return static_cast<int>(ExitCode::checkpoint);
    }

    std::unique_ptr<WVConstantStratificationForcingEngine> forcingEngine;
    phase(options,"construct");
    start = Clock::now();
    auto kernelStatus = WVConstantStratificationForcingEngine::create(checkpoint.configuration,checkpoint.forcingSchedule,std::move(fftEngine),forcingEngine);
    if (!kernelStatus) {
        emit(failureJSON(ExitCode::provider,"construct",kernelStatus.message),options.report,std::cerr);
        return static_cast<int>(ExitCode::provider);
    }
    WVFixedStepRK4 integrator(*forcingEngine);
    const auto shape = forcingEngine->kernel().descriptor().spectralShape();
    WVMutableState state{checkpoint.state.t,checkpoint.state.t0,{{checkpoint.state.coefficients.Ap.data(),shape},{checkpoint.state.coefficients.Am.data(),shape},{checkpoint.state.coefficients.A0.data(),shape}}};
    timings.construct = seconds(start);
    phase(options,"prepare");
    start = Clock::now();
    kernelStatus = integrator.prepareStateAfterRestart(state);
    timings.prepare = seconds(start);
    if (!kernelStatus) {
        emit(failureJSON(ExitCode::integration,"prepare",kernelStatus.message),options.report,std::cerr);
        return static_cast<int>(ExitCode::integration);
    }

    phasePlateau(options,"steady-retained");
    const auto integrationBaselineRSS = currentRSSBytes();
    phase(options,"integrate");
    start = Clock::now();
    if (options.hasSteps) {
        for (std::size_t step = 0; step < options.steps && kernelStatus; ++step) kernelStatus = integrator.step(state,options.deltaT);
    } else {
        kernelStatus = integrator.advanceToTime(state,options.finalTime,options.deltaT);
    }
    timings.integrate = seconds(start);
    const auto integrationPeakRSS = peakRSSBytes();
    if (!kernelStatus) {
        emit(failureJSON(ExitCode::integration,"integrate",kernelStatus.message),options.report,std::cerr);
        return static_cast<int>(ExitCode::integration);
    }
    phasePlateau(options,"outputs-held");

    checkpoint.state.t = state.t;
    checkpoint.state.t0 = state.t0;
    start = Clock::now();
    phase(options,"write");
    checkpointStatus = WVCheckpointWriter::write(options.output,checkpoint);
    timings.write = seconds(start);
    timings.total = seconds(totalStart);
    if (!checkpointStatus) {
        emit(failureJSON(ExitCode::output,"write",checkpointStatus.message,checkpointStatus.location),options.report,std::cerr);
        return static_cast<int>(ExitCode::output);
    }

    const auto& kernel = forcingEngine->kernel();
    const auto& kernelMetrics = kernel.metrics();
    const auto& forcingMetrics = forcingEngine->metrics();
    const auto& integratorMetrics = integrator.metrics();
    const auto checkpointStateBytes = stateBytes(checkpoint);
    const auto knownPersistentBytes = checkpointStateBytes+forcingEngine->persistentBytes()+integrator.persistentBytes();
    const auto integratorElementReads = integratorMetrics.stageStateConstructionElementReads+integratorMetrics.weightedFluxInitializationElementReads+integratorMetrics.weightedAccumulationElementReads+integratorMetrics.finalStateUpdateElementReads+integratorMetrics.acceptedStateCommitElementReads;
    const auto integratorElementWrites = integratorMetrics.stageStateConstructionElementWrites+integratorMetrics.stageFluxClearElementWrites+integratorMetrics.weightedFluxClearElementWrites+integratorMetrics.weightedFluxInitializationElementWrites+integratorMetrics.weightedAccumulationElementWrites+integratorMetrics.finalStateUpdateElementWrites+integratorMetrics.acceptedStateCommitElementWrites;
    const auto forcingElementReads = forcingMetrics.temporaryAccumulationElementReads+forcingMetrics.outputCopyElementReads;
    const auto forcingElementWrites = forcingMetrics.accumulatorClearElementWrites+forcingMetrics.temporaryFluxClearElementWrites+forcingMetrics.kernelOutputInitializationElementWrites+forcingMetrics.temporaryAccumulationElementWrites+forcingMetrics.outputCopyElementWrites+forcingMetrics.stateConstraintElementWrites;
    const auto trafficElementReads = integratorElementReads+forcingElementReads;
    const auto trafficElementWrites = integratorElementWrites+forcingElementWrites;
    std::ostringstream report;
    report << std::setprecision(17)
           << "{\"schemaVersion\":\"wave-vortex-run-v1\",\"status\":\"complete\",\"source\":{\"commit\":" << quoted(WV_RUNTIME_SOURCE_COMMIT) << "},"
           << "\"input\":" << quoted(options.input) << ",\"output\":" << quoted(options.output) << ",\"provider\":{\"id\":" << quoted(options.provider) << ",\"version\":" << quoted(providerVersion) << ",\"threads\":" << options.threads << ",\"baseLibrary\":" << quoted(baseLibrary) << ",\"threadLibrary\":" << quoted(threadLibrary) << "},"
           << "\"state\":{\"initialTime\":" << inspection.t << ",\"finalTime\":" << state.t << ",\"deltaT\":" << options.deltaT << ",\"stepCount\":" << integratorMetrics.stepCount << ",\"rhsEvaluationCount\":" << integratorMetrics.rightHandSideEvaluationCount << ",\"shape\":[" << shape.rows << ',' << shape.columns << "]},"
           << "\"forcing\":" << forcingJSON(checkpoint.forcingSchedule) << ','
           << "\"timingSeconds\":{\"inspect\":" << timings.inspect << ",\"read\":" << timings.read << ",\"construct\":" << timings.construct << ",\"prepare\":" << timings.prepare << ",\"integrate\":" << timings.integrate << ",\"write\":" << timings.write << ",\"total\":" << timings.total << "},"
           << "\"storageBytes\":{\"checkpointState\":" << checkpointStateBytes << ",\"descriptor\":" << kernelMetrics.descriptorBytes << ",\"planWrapper\":" << kernelMetrics.planBytes << ",\"kernelScratch\":" << kernelMetrics.scratchCapacityBytes << ",\"forcingSchedule\":" << forcingMetrics.scheduleBytes << ",\"forcingDerivedOperators\":" << forcingMetrics.derivedOperatorBytes << ",\"forcingWorkspace\":" << forcingMetrics.workspaceCapacityBytes << ",\"integratorWorkspace\":" << integratorMetrics.workspaceCapacityBytes << ",\"knownPersistent\":" << knownPersistentBytes << ",\"persistentFullHermitian\":0},"
           << "\"arrayTraffic\":{\"scope\":\"exact integration-boundary arrays; FFT plans and kernel scratch internals excluded\",\"elementBytes\":" << sizeof(WVComplex64) << ",\"integrator\":{\"stageStateConstructionReads\":" << integratorMetrics.stageStateConstructionElementReads << ",\"stageStateConstructionWrites\":" << integratorMetrics.stageStateConstructionElementWrites << ",\"stageFluxClearWrites\":" << integratorMetrics.stageFluxClearElementWrites << ",\"weightedFluxClearWrites\":" << integratorMetrics.weightedFluxClearElementWrites << ",\"weightedFluxInitializationReads\":" << integratorMetrics.weightedFluxInitializationElementReads << ",\"weightedFluxInitializationWrites\":" << integratorMetrics.weightedFluxInitializationElementWrites << ",\"weightedAccumulationReads\":" << integratorMetrics.weightedAccumulationElementReads << ",\"weightedAccumulationWrites\":" << integratorMetrics.weightedAccumulationElementWrites << ",\"finalStateUpdateReads\":" << integratorMetrics.finalStateUpdateElementReads << ",\"finalStateUpdateWrites\":" << integratorMetrics.finalStateUpdateElementWrites << ",\"acceptedStateCommitReads\":" << integratorMetrics.acceptedStateCommitElementReads << ",\"acceptedStateCommitWrites\":" << integratorMetrics.acceptedStateCommitElementWrites << "},\"forcing\":{\"accumulatorClearWrites\":" << forcingMetrics.accumulatorClearElementWrites << ",\"temporaryFluxClearWrites\":" << forcingMetrics.temporaryFluxClearElementWrites << ",\"kernelOutputInitializationWrites\":" << forcingMetrics.kernelOutputInitializationElementWrites << ",\"temporaryAccumulationReads\":" << forcingMetrics.temporaryAccumulationElementReads << ",\"temporaryAccumulationWrites\":" << forcingMetrics.temporaryAccumulationElementWrites << ",\"outputCopyReads\":" << forcingMetrics.outputCopyElementReads << ",\"outputCopyWrites\":" << forcingMetrics.outputCopyElementWrites << ",\"stateConstraintWrites\":" << forcingMetrics.stateConstraintElementWrites << "},\"totals\":{\"elementReads\":" << trafficElementReads << ",\"elementWrites\":" << trafficElementWrites << ",\"bytesRead\":" << trafficElementReads*sizeof(WVComplex64) << ",\"bytesWritten\":" << trafficElementWrites*sizeof(WVComplex64) << "}},"
           << "\"livenessBytes\":{\"integratorWorkspaceLive\":" << integratorMetrics.workspaceLiveBytes << ",\"integratorWorkspaceMaximumLive\":" << integratorMetrics.workspaceMaximumLiveBytes << ",\"forcingWorkspaceLive\":" << forcingMetrics.workspaceLiveBytes << ",\"forcingWorkspaceMaximumLive\":" << forcingMetrics.workspaceMaximumLiveBytes << ",\"acceptedStepAdditionalArrayStorage\":0,\"contractAbstractionAdditionalArrayStorage\":0,\"knownRetained\":" << knownPersistentBytes << ",\"knownMaximumLive\":" << knownPersistentBytes << "},"
           << "\"rssBytes\":{\"integrationBaseline\":" << integrationBaselineRSS << ",\"processPeak\":" << integrationPeakRSS << ",\"peakIncrementLowerBound\":" << (integrationPeakRSS > integrationBaselineRSS ? integrationPeakRSS-integrationBaselineRSS : 0) << "},"
           << "\"execution\":{\"engine\":" << quoted(kernel.engineIdentifier()) << ",\"library\":" << quoted(kernel.engineLibraryIdentity()) << ",\"schedule\":" << quoted(forcingEngine->scheduleIdentifier()) << ",\"planCount\":" << kernelMetrics.planCount << ",\"noFallback\":true}}";
    emit(report.str(),options.report,std::cout);
    phase(options,"complete");
    return static_cast<int>(ExitCode::success);
}
