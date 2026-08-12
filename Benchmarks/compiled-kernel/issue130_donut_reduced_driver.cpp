#include "WVFFTWEngine.hpp"
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

#ifndef WV_KERNEL_ISSUE130_VARIANT
#define WV_KERNEL_ISSUE130_VARIANT 0
#endif

using namespace wavevortex;

namespace {

constexpr std::uint64_t fluxMagic = 0x5756493133304452ULL;

struct Options {
    bool hydrostatic = true;
    std::size_t threads = 18;
    std::size_t warmups = 2;
    std::size_t samples = 3;
    std::string outputPath;
    std::string fluxPath;
};

struct FluxFile {
    std::vector<WVComplex64> Fp;
    std::vector<WVComplex64> Fm;
    std::vector<WVComplex64> F0;
};

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

void requireStatus(const WVKernelStatus& status) {
    if (!status) throw std::runtime_error(status.message);
}

std::string argument(int argc, char* argv[], const std::string& name) {
    for (int index = 1; index + 1 < argc; ++index) {
        if (argv[index] == name) return argv[index + 1];
    }
    throw std::runtime_error("Missing argument " + name + '.');
}

Options options(int argc, char* argv[]) {
    Options value;
    const auto caseId = argument(argc,argv,"--case");
    require(caseId == "hydrostatic" || caseId == "nonhydrostatic","--case must be hydrostatic or nonhydrostatic.");
    value.hydrostatic = caseId == "hydrostatic";
    value.threads = std::stoull(argument(argc,argv,"--threads"));
    value.warmups = std::stoull(argument(argc,argv,"--warmups"));
    value.samples = std::stoull(argument(argc,argv,"--samples"));
    value.outputPath = argument(argc,argv,"--output");
    value.fluxPath = argument(argc,argv,"--flux");
    require(value.threads == 18,"The Donut reduced protocol requires exactly 18 FFTW threads.");
    require(value.warmups == 2 && value.samples == 3,"The Donut reduced protocol requires two warmups and three samples.");
    return value;
}

WVTransformConstantStratificationConfiguration configuration(bool hydrostatic) {
    WVTransformConstantStratificationConfiguration value;
    value.Nx = 256;
    value.Ny = 256;
    value.Nz = 65;
    value.Nj = 42;
    value.Lx = 15000.0;
    value.Ly = 15000.0;
    value.Lz = 1300.0;
    value.N0 = 5.2e-3;
    value.rho0 = 1025.0;
    value.g = 9.81;
    value.planetaryRadius = 6.371e6;
    value.rotationRate = 7.2921e-5;
    value.latitude = 33.0;
    value.isHydrostatic = hydrostatic;
    value.shouldAntialias = true;
    return value;
}

const char* variantIdentifier() {
#if WV_KERNEL_ISSUE130_VARIANT == 3
    return "streamed-target-three-channel";
#elif WV_KERNEL_ISSUE130_VARIANT == 4
    return "streamed-target-single-output-4H+5R";
#else
    return "control-be0f78995c49a2bfe4c43d75827856e3812ac278";
#endif
}

void initializeState(std::vector<WVComplex64>& Ap, std::vector<WVComplex64>& Am, std::vector<WVComplex64>& A0) {
    for (std::size_t index = 0; index < Ap.size(); ++index) {
        const auto i = static_cast<double>(index + 1);
        Ap[index] = {1e-4*std::sin(0.017*i),1e-4*std::cos(0.013*(i+1.0))};
        Am[index] = {1e-4*std::cos(0.011*(i+2.0)),1e-4*std::sin(0.019*(i+3.0))};
        A0[index] = {1e-4*std::sin(0.023*(i+4.0)),1e-4*std::cos(0.007*(i+5.0))};
    }
}

void advanceState(const std::vector<WVComplex64>& baseAp, const std::vector<WVComplex64>& baseAm, const std::vector<WVComplex64>& baseA0,
                  std::vector<WVComplex64>& Ap, std::vector<WVComplex64>& Am, std::vector<WVComplex64>& A0, std::size_t stateIndex) {
    const double theta = 0.017 * static_cast<double>(stateIndex);
    const double positiveReal = std::cos(theta);
    const double positiveImag = std::sin(theta);
    const double negativeImag = -positiveImag;
    const double zeroReal = std::cos(theta/3.0);
    const double zeroImag = std::sin(theta/3.0);
    for (std::size_t index = 0; index < Ap.size(); ++index) {
        Ap[index] = {baseAp[index].real*positiveReal-baseAp[index].imag*positiveImag,baseAp[index].real*positiveImag+baseAp[index].imag*positiveReal};
        Am[index] = {baseAm[index].real*positiveReal-baseAm[index].imag*negativeImag,baseAm[index].real*negativeImag+baseAm[index].imag*positiveReal};
        A0[index] = {baseA0[index].real*zeroReal-baseA0[index].imag*zeroImag,baseA0[index].real*zeroImag+baseA0[index].imag*zeroReal};
    }
}

void writeFlux(const std::string& path, const FluxFile& flux) {
    std::ofstream output(path,std::ios::binary | std::ios::trunc);
    require(static_cast<bool>(output),"Unable to open flux output " + path + '.');
    const auto count = static_cast<std::uint64_t>(flux.Fp.size());
    output.write(reinterpret_cast<const char*>(&fluxMagic),sizeof(fluxMagic));
    output.write(reinterpret_cast<const char*>(&count),sizeof(count));
    for (const auto* values : {&flux.Fp,&flux.Fm,&flux.F0}) {
        output.write(reinterpret_cast<const char*>(values->data()),static_cast<std::streamsize>(values->size()*sizeof(WVComplex64)));
    }
    require(static_cast<bool>(output),"Unable to write flux output " + path + '.');
}

FluxFile readFlux(const std::string& path) {
    std::ifstream input(path,std::ios::binary);
    require(static_cast<bool>(input),"Unable to open flux input " + path + '.');
    std::uint64_t magic = 0;
    std::uint64_t count = 0;
    input.read(reinterpret_cast<char*>(&magic),sizeof(magic));
    input.read(reinterpret_cast<char*>(&count),sizeof(count));
    require(magic == fluxMagic && count > 0,"Invalid issue #130 flux file " + path + '.');
    FluxFile flux{std::vector<WVComplex64>(count),std::vector<WVComplex64>(count),std::vector<WVComplex64>(count)};
    for (auto* values : {&flux.Fp,&flux.Fm,&flux.F0}) {
        input.read(reinterpret_cast<char*>(values->data()),static_cast<std::streamsize>(values->size()*sizeof(WVComplex64)));
    }
    require(static_cast<bool>(input),"Truncated issue #130 flux file " + path + '.');
    return flux;
}

double relativeInfinityError(const std::vector<WVComplex64>& actual, const std::vector<WVComplex64>& expected) {
    require(actual.size() == expected.size(),"Flux sizes differ.");
    double numerator = 0.0;
    double denominator = 0.0;
    for (std::size_t index = 0; index < actual.size(); ++index) {
        numerator = std::max(numerator,std::hypot(actual[index].real-expected[index].real,actual[index].imag-expected[index].imag));
        denominator = std::max(denominator,std::hypot(expected[index].real,expected[index].imag));
    }
    return numerator/std::max(denominator,std::numeric_limits<double>::min());
}

void writeComparison(const std::string& controlPath, const std::string& candidatePath, const std::string& outputPath) {
    const auto control = readFlux(controlPath);
    const auto candidate = readFlux(candidatePath);
    const auto Fp = relativeInfinityError(candidate.Fp,control.Fp);
    const auto Fm = relativeInfinityError(candidate.Fm,control.Fm);
    const auto F0 = relativeInfinityError(candidate.F0,control.F0);
    std::ofstream output(outputPath,std::ios::trunc);
    require(static_cast<bool>(output),"Unable to open comparison output " + outputPath + '.');
    output << std::setprecision(17) << "{\n"
           << "  \"Fp\": " << Fp << ",\n"
           << "  \"Fm\": " << Fm << ",\n"
           << "  \"F0\": " << F0 << ",\n"
           << "  \"maximumRelativeInfinityError\": " << std::max({Fp,Fm,F0}) << "\n}\n";
}

template<typename T>
void writeNumberArray(std::ostream& output, const std::vector<T>& values) {
    output << '[';
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index > 0) output << ',';
        output << std::setprecision(17) << values[index];
    }
    output << ']';
}

void run(const Options& options) {
    const auto identity = WVFFTWEngine::linkedLibraries();
    require(identity.version.find("3.3.11") != std::string::npos,"The native driver did not resolve FFTW 3.3.11.");
    require(identity.openMPRuntimeLibrary.empty(),"The native driver unexpectedly resolved an OpenMP runtime.");
    const auto lifetimeBefore = WVFFTWEngine::lifetimeMetrics();
    std::unique_ptr<WVFFTEngine> engine;
    requireStatus(WVFFTWEngine::create(options.threads,engine));
    std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
    const auto planningStart = std::chrono::steady_clock::now();
    requireStatus(WVTransformConstantStratificationKernel::create(configuration(options.hydrostatic),std::move(engine),kernel));
    const auto constructionSeconds = std::chrono::duration<double>(std::chrono::steady_clock::now()-planningStart).count();
    const auto shape = kernel->descriptor().spectralShape();
    const auto count = shape.elementCount();
    std::vector<WVComplex64> baseAp(count),baseAm(count),baseA0(count),Ap(count),Am(count),A0(count),Fp(count),Fm(count),F0(count);
    initializeState(baseAp,baseAm,baseA0);
    WVState state{0.0,0.0,{{Ap.data(),shape},{Am.data(),shape},{A0.data(),shape}}};
    WVFlux flux{{Fp.data(),shape},{Fm.data(),shape},{F0.data(),shape}};
    for (std::size_t warmup = 1; warmup <= options.warmups; ++warmup) {
        advanceState(baseAp,baseAm,baseA0,Ap,Am,A0,warmup);
        state.t = 30.0*static_cast<double>(warmup);
        requireStatus(kernel->nonlinearFlux(state,flux));
    }
    std::vector<double> samples;
    samples.reserve(options.samples);
    for (std::size_t sample = 1; sample <= options.samples; ++sample) {
        const auto stateIndex = options.warmups + sample;
        advanceState(baseAp,baseAm,baseA0,Ap,Am,A0,stateIndex);
        state.t = 30.0*static_cast<double>(stateIndex);
        const auto start = std::chrono::steady_clock::now();
        requireStatus(kernel->nonlinearFlux(state,flux));
        samples.push_back(std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count());
    }
    const auto diagnosticState = options.warmups + options.samples + 1;
    advanceState(baseAp,baseAm,baseA0,Ap,Am,A0,diagnosticState);
    state.t = 30.0*static_cast<double>(diagnosticState);
    const auto metricsBefore = kernel->metrics();
    kernel->setStageInstrumentation(true);
    const auto diagnosticStart = std::chrono::steady_clock::now();
    requireStatus(kernel->nonlinearFlux(state,flux));
    const auto diagnosticTotalSeconds = std::chrono::duration<double>(std::chrono::steady_clock::now()-diagnosticStart).count();
    const auto metricsAfter = kernel->metrics();
    kernel->setStageInstrumentation(false);
    writeFlux(options.fluxPath,{Fp,Fm,F0});

    const auto schedule = std::string(kernel->nonlinearFluxScheduleIdentifier());
    const auto spectralBytes = count*sizeof(WVComplex64);
    const auto halfFieldBytes = (256/2+1)*256*65*sizeof(WVComplex64);
    const auto phaseReservationBytes = WV_KERNEL_ISSUE130_VARIANT >= 3 ? halfFieldBytes : 0;
    const auto coefficientWorkerCount = kernel->coefficientWorkerCount();
    const auto persistentBytes = kernel->persistentBytes();
    const auto scratchBytes = kernel->scratchBytes();
    const auto descriptorBytes = metricsAfter.descriptorBytes;
    const auto planBytes = metricsAfter.planBytes;
    const auto stateInputBytes = 3*spectralBytes;
    const auto fluxOutputBytes = 3*spectralBytes;
    const auto exactMaximumLiveArrayBytes = descriptorBytes+scratchBytes+stateInputBytes+fluxOutputBytes;
    const auto knownMaximumLiveOwnedBytes = persistentBytes+stateInputBytes+fluxOutputBytes;
    const auto planningMetrics = WVFFTWEngine::lifetimeMetrics();
    kernel.reset();
    const auto lifetimeAfter = WVFFTWEngine::lifetimeMetrics();
    const bool cleanupBalanced = lifetimeAfter.activePlans == lifetimeBefore.activePlans && lifetimeAfter.outstandingPlanningBytes == 0 &&
        lifetimeAfter.totalPlansCreated-lifetimeBefore.totalPlansCreated == lifetimeAfter.totalPlansDestroyed-lifetimeBefore.totalPlansDestroyed;

    std::ofstream output(options.outputPath,std::ios::trunc);
    require(static_cast<bool>(output),"Unable to open native result " + options.outputPath + '.');
    output << std::setprecision(17) << "{\n"
           << "  \"schemaVersion\": \"1.0.0\",\n"
           << "  \"status\": \"" << (cleanupBalanced ? "complete" : "failed") << "\",\n"
           << "  \"variant\": \"" << variantIdentifier() << "\",\n"
           << "  \"case\": \"" << (options.hydrostatic ? "hydrostatic" : "nonhydrostatic") << "\",\n"
           << "  \"configuration\": {\"Nx\":256,\"Ny\":256,\"Nz\":65,\"Nj\":42,\"threadsRequested\":18,\"threadsEffective\":18,\"coefficientWorkerCount\":" << coefficientWorkerCount << ",\"threadBehavior\":\"fftw_plan_with_nthreads(18) for every plan; two joined coefficient workers run outside FFTW execution regions; no nested threading or OpenMP runtime\",\"warmups\":2,\"samples\":3},\n"
           << "  \"identity\": {\"fftwVersion\":\"" << identity.version << "\",\"baseLibraryDladdr\":\"" << identity.baseLibrary << "\",\"threadLibraryDladdr\":\"" << identity.threadLibrary << "\",\"openMPRuntimeDladdr\":\"" << identity.openMPRuntimeLibrary << "\",\"compiler\":\"" << __clang_version__ << "\"},\n"
           << "  \"schedule\": \"" << schedule << "\",\n"
           << "  \"timing\": {\"constructionSeconds\":" << constructionSeconds << ",\"samplesSeconds\":";
    writeNumberArray(output,samples);
    output << ",\"diagnosticTotalSeconds\":" << diagnosticTotalSeconds << ",\"stages\":{"
           << "\"phaseSeconds\":" << metricsAfter.phaseSeconds << ','
           << "\"reconstructionSeconds\":" << metricsAfter.reconstructionSeconds << ','
           << "\"derivativeReconstructionSeconds\":" << metricsAfter.derivativeReconstructionSeconds << ','
           << "\"productSeconds\":" << metricsAfter.productSeconds << ','
           << "\"projectionSeconds\":" << metricsAfter.projectionSeconds << ','
           << "\"coefficientAssemblySeconds\":" << metricsAfter.coefficientAssemblySeconds << ','
           << "\"derivativeCoefficientAssemblySeconds\":" << metricsAfter.derivativeCoefficientAssemblySeconds << ','
           << "\"coefficientProjectionSeconds\":" << metricsAfter.coefficientProjectionSeconds << "}},\n"
           << "  \"memory\": {\"descriptorBytes\":" << descriptorBytes << ",\"scratchBytes\":" << scratchBytes << ",\"halfSpectrumScratchBytes\":" << metricsAfter.halfSpectrumScratchCapacityBytes << ",\"realScratchBytes\":" << metricsAfter.realScratchCapacityBytes << ",\"phaseReservationBytes\":" << phaseReservationBytes << ",\"stateInputBytes\":" << stateInputBytes << ",\"fluxOutputBytes\":" << fluxOutputBytes << ",\"persistentOwnedBytesLowerBound\":" << persistentBytes << ",\"exactMaximumLiveArrayBytesExcludingOpaquePlans\":" << exactMaximumLiveArrayBytes << ",\"knownMaximumLiveOwnedBytesLowerBound\":" << knownMaximumLiveOwnedBytes << ",\"persistentFullHermitianBytes\":0},\n"
           << "  \"plans\": {\"count\":" << metricsAfter.planCount << ",\"wrapperBytesLowerBound\":" << planBytes << ",\"memoryAccounting\":\"wrapper lower bound; FFTW-owned plan memory is opaque\",\"executionCount\":" << metricsAfter.executionCount-metricsBefore.executionCount << ",\"horizontalExecutionCount\":" << metricsAfter.horizontalExecutionCount-metricsBefore.horizontalExecutionCount << ",\"verticalExecutionCount\":" << metricsAfter.verticalExecutionCount-metricsBefore.verticalExecutionCount << ",\"phaseEvaluationCount\":" << metricsAfter.nonlinearFluxPhaseEvaluationCount-metricsBefore.nonlinearFluxPhaseEvaluationCount << "},\n"
           << "  \"lifecycle\": {\"activePlansBefore\":" << lifetimeBefore.activePlans << ",\"activePlansDuring\":" << planningMetrics.activePlans << ",\"activePlansAfter\":" << lifetimeAfter.activePlans << ",\"created\":" << lifetimeAfter.totalPlansCreated-lifetimeBefore.totalPlansCreated << ",\"destroyed\":" << lifetimeAfter.totalPlansDestroyed-lifetimeBefore.totalPlansDestroyed << ",\"outstandingPlanningBytesAfter\":" << lifetimeAfter.outstandingPlanningBytes << ",\"balancedCleanup\":" << (cleanupBalanced ? "true" : "false") << "},\n"
           << "  \"fallbackOccurred\": false\n}\n";
}

} // namespace

int main(int argc, char* argv[]) {
    try {
        if (argc > 1 && std::string(argv[1]) == "--compare") {
            require(argc == 5,"Usage: --compare CONTROL_FLUX CANDIDATE_FLUX OUTPUT_JSON");
            writeComparison(argv[2],argv[3],argv[4]);
        } else {
            run(options(argc,argv));
        }
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
