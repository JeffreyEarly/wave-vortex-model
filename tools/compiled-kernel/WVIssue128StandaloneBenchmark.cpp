#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"
#include "WVFFTWEngine.hpp"

#if defined(WV_ISSUE128_HAS_FFTWPP)
#include "WVFFTWPlusPlusConvolution.hpp"
#endif

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/resource.h>
#include <utility>
#include <vector>

using namespace wavevortex;

namespace {

using Clock = std::chrono::steady_clock;

struct Options {
    std::size_t Nx = 128;
    std::size_t Ny = 128;
    std::size_t Nz = 33;
    std::size_t Nj = 21;
    std::size_t threads = 1;
    std::size_t warmups = 2;
    std::size_t samples = 3;
    std::uint64_t seed = 128389;
    bool hydrostatic = true;
    std::string variant = "explicit";
    std::string outputPath;
    std::string referenceInputPath;
    std::string referenceOutputPath;
    std::string expectedOpenMPRuntime;
};

[[noreturn]] void fail(const std::string& message) { throw std::runtime_error(message); }

std::size_t parseSize(const std::map<std::string,std::string>& values, const std::string& key, std::size_t defaultValue) {
    const auto found = values.find(key);
    if (found == values.end()) return defaultValue;
    const auto value = std::stoull(found->second);
    if (value > std::numeric_limits<std::size_t>::max()) fail(key + " is too large.");
    return static_cast<std::size_t>(value);
}

Options parseOptions(int argc, char** argv) {
    std::map<std::string,std::string> values;
    for (int index = 1; index < argc; ++index) {
        const std::string key = argv[index];
        if (key.rfind("--",0) != 0 || index + 1 >= argc) fail("Arguments must be --key value pairs.");
        values[key.substr(2)] = argv[++index];
    }
    Options result;
    result.Nx = parseSize(values,"Nx",result.Nx);
    result.Ny = parseSize(values,"Ny",result.Ny);
    result.Nz = parseSize(values,"Nz",result.Nz);
    result.Nj = parseSize(values,"Nj",result.Nj);
    result.threads = parseSize(values,"threads",result.threads);
    result.warmups = parseSize(values,"warmups",result.warmups);
    result.samples = parseSize(values,"samples",result.samples);
    result.seed = static_cast<std::uint64_t>(parseSize(values,"seed",result.seed));
    if (const auto found = values.find("hydrostatic"); found != values.end()) result.hydrostatic = found->second == "1" || found->second == "true";
    if (const auto found = values.find("variant"); found != values.end()) result.variant = found->second;
    if (const auto found = values.find("output"); found != values.end()) result.outputPath = found->second;
    if (const auto found = values.find("reference-input"); found != values.end()) result.referenceInputPath = found->second;
    if (const auto found = values.find("reference-output"); found != values.end()) result.referenceOutputPath = found->second;
    if (const auto found = values.find("expected-openmp-runtime"); found != values.end()) result.expectedOpenMPRuntime = found->second;
    if (result.threads == 0 || result.threads > 16) fail("threads must lie in [1,16].");
    if (result.samples == 0) fail("samples must be positive.");
    if (result.variant != "explicit" && result.variant != "fftwpp-implicit" && result.variant != "fftwpp-hybrid" && result.variant != "fftwpp-auto") fail("Unknown variant.");
#if !defined(WV_ISSUE128_HAS_FFTWPP)
    if (result.variant != "explicit") fail("This executable contains only the pthread explicit control.");
#endif
    return result;
}

WVTransformConstantStratificationConfiguration configuration(const Options& options) {
    WVTransformConstantStratificationConfiguration value;
    value.Nx = options.Nx;
    value.Ny = options.Ny;
    value.Nz = options.Nz;
    value.Nj = options.Nj;
    value.Lx = 15000.0;
    value.Ly = 15000.0;
    value.Lz = 1300.0;
    value.N0 = 5.2e-3;
    value.rho0 = 1025.0;
    value.g = 9.81;
    value.planetaryRadius = 6.371e6;
    value.rotationRate = 7.2921e-5;
    value.latitude = 33.0;
    value.isHydrostatic = options.hydrostatic;
    value.shouldAntialias = true;
    return value;
}

void fillState(std::vector<WVComplex64>& Ap, std::vector<WVComplex64>& Am, std::vector<WVComplex64>& A0, std::uint64_t seed, std::size_t step) {
    const double phase = 1e-5 * static_cast<double>(seed) + 0.013 * static_cast<double>(step);
    for (std::size_t index = 0; index < Ap.size(); ++index) {
        const auto i = static_cast<double>(index + 1);
        Ap[index] = {1e-4*std::sin(0.017*i+phase),1e-4*std::cos(0.011*i-0.3*phase)};
        Am[index] = {1e-4*std::cos(0.013*i+0.7*phase),1e-4*std::sin(0.007*i-0.5*phase)};
        A0[index] = {1e-4*std::sin(0.019*i-0.2*phase),1e-4*std::cos(0.005*i+0.9*phase)};
    }
}

void requireStatus(const WVKernelStatus& status, const char* stage) {
    if (!status) fail(std::string(stage) + ": " + status.message);
}

double secondsSince(Clock::time_point start) { return std::chrono::duration<double>(Clock::now()-start).count(); }

double execute(WVTransformConstantStratificationKernel& kernel, WVState& state, WVFlux& flux) {
    const auto start = Clock::now();
    requireStatus(kernel.nonlinearFlux(state,flux),"nonlinearFlux");
    return secondsSince(start);
}

struct ReferenceHeader {
    std::uint64_t magic = 0x5756493132385246ULL;
    std::uint64_t Nx = 0;
    std::uint64_t Ny = 0;
    std::uint64_t Nz = 0;
    std::uint64_t Nj = 0;
    std::uint64_t hydrostatic = 0;
    std::uint64_t count = 0;
    std::uint64_t step = 0;
};

void writeReference(const std::string& path, const Options& options, std::size_t step, const std::vector<WVComplex64>& Fp, const std::vector<WVComplex64>& Fm, const std::vector<WVComplex64>& F0) {
    std::ofstream stream(path,std::ios::binary);
    if (!stream) fail("Unable to open reference output.");
    const ReferenceHeader header{0x5756493132385246ULL,options.Nx,options.Ny,options.Nz,options.Nj,options.hydrostatic ? 1ULL : 0ULL,Fp.size(),step};
    stream.write(reinterpret_cast<const char*>(&header),sizeof(header));
    for (const auto* values : {&Fp,&Fm,&F0}) stream.write(reinterpret_cast<const char*>(values->data()),static_cast<std::streamsize>(values->size()*sizeof(WVComplex64)));
    if (!stream) fail("Unable to write reference output.");
}

double readReferenceError(const std::string& path, const Options& options, std::size_t expectedStep, const std::vector<WVComplex64>& Fp, const std::vector<WVComplex64>& Fm, const std::vector<WVComplex64>& F0) {
    std::ifstream stream(path,std::ios::binary);
    if (!stream) fail("Unable to open reference input.");
    ReferenceHeader header;
    stream.read(reinterpret_cast<char*>(&header),sizeof(header));
    if (header.magic != 0x5756493132385246ULL || header.Nx != options.Nx || header.Ny != options.Ny || header.Nz != options.Nz || header.Nj != options.Nj || header.hydrostatic != static_cast<std::uint64_t>(options.hydrostatic) || header.count != Fp.size() || header.step != expectedStep) fail("Reference identity does not match this case.");
    double difference = 0.0;
    double scale = 0.0;
    std::vector<WVComplex64> reference(Fp.size());
    for (const auto* actual : {&Fp,&Fm,&F0}) {
        stream.read(reinterpret_cast<char*>(reference.data()),static_cast<std::streamsize>(reference.size()*sizeof(WVComplex64)));
        for (std::size_t index = 0; index < reference.size(); ++index) {
            difference = std::max(difference,std::hypot(actual->at(index).real-reference[index].real,actual->at(index).imag-reference[index].imag));
            scale = std::max(scale,std::hypot(reference[index].real,reference[index].imag));
        }
    }
    if (!stream) fail("Unable to read reference input.");
    return difference/std::max(scale,std::numeric_limits<double>::min());
}

std::string quote(const std::string& value) {
    std::ostringstream stream;
    stream << '"';
    for (const char character : value) {
        if (character == '"' || character == '\\') stream << '\\';
        stream << character;
    }
    stream << '"';
    return stream.str();
}

std::string samplesJSON(const std::vector<double>& samples) {
    std::ostringstream stream;
    stream << '[' << std::setprecision(17);
    for (std::size_t index = 0; index < samples.size(); ++index) {
        if (index != 0) stream << ',';
        stream << samples[index];
    }
    stream << ']';
    return stream.str();
}

double median(std::vector<double> values) {
    std::sort(values.begin(),values.end());
    const auto middle = values.size()/2;
    return values.size()%2 == 0 ? 0.5*(values[middle-1]+values[middle]) : values[middle];
}

std::uint64_t maximumRSSBytes() {
    rusage usage{};
    return getrusage(RUSAGE_SELF,&usage) == 0 ? static_cast<std::uint64_t>(usage.ru_maxrss) : 0;
}

void writeResult(const Options& options, const WVFFTWLibraryIdentity& identity, double constructionSeconds, double firstSeconds, const std::vector<double>& samples, double correctnessError, bool wroteReference, const WVKernelMetrics& kernelMetrics, std::size_t persistentBytes, std::size_t spectralElementCount, const WVHorizontalConvolutionMetrics& convolution, double cleanupSeconds, const WVFFTWLifetimeMetrics& lifetime) {
    std::ostringstream stream;
    stream << std::setprecision(17);
    stream << "{\n";
    stream << "  \"schemaVersion\":\"1.0.0\",\n";
    stream << "  \"status\":\"complete\",\n";
    stream << "  \"variant\":" << quote(options.variant) << ",\n";
    stream << "  \"Nxyz\":[" << options.Nx << ',' << options.Ny << ',' << options.Nz << "],\n";
    stream << "  \"Nj\":" << options.Nj << ",\n";
    stream << "  \"hydrostatic\":" << (options.hydrostatic ? "true" : "false") << ",\n";
    stream << "  \"threads\":" << options.threads << ",\n";
    stream << "  \"warmups\":" << options.warmups << ",\n";
    stream << "  \"samplesSeconds\":" << samplesJSON(samples) << ",\n";
    stream << "  \"medianSeconds\":" << median(samples) << ",\n";
    stream << "  \"firstSeconds\":" << firstSeconds << ",\n";
    stream << "  \"constructionSeconds\":" << constructionSeconds << ",\n";
    stream << "  \"optimizerDiscoverySeconds\":" << convolution.optimizerDiscoverySeconds << ",\n";
    stream << "  \"cleanupSeconds\":" << cleanupSeconds << ",\n";
    stream << "  \"relativeInfinityError\":" << correctnessError << ",\n";
    stream << "  \"referenceWritten\":" << (wroteReference ? "true" : "false") << ",\n";
    stream << "  \"libraries\":{\"version\":" << quote(identity.version) << ",\"base\":" << quote(identity.baseLibrary) << ",\"thread\":" << quote(identity.threadLibrary) << ",\"openmp\":" << quote(identity.openMPRuntimeLibrary) << "},\n";
    stream << "  \"memory\":{\"descriptorBytes\":" << kernelMetrics.descriptorBytes << ",\"planWrapperBytes\":" << kernelMetrics.planBytes << ",\"scratchCapacityBytes\":" << kernelMetrics.scratchCapacityBytes << ",\"persistentBytes\":" << persistentBytes << ",\"knownMaximumLiveOwnedBytes\":" << persistentBytes + 3*spectralElementCount*sizeof(WVComplex64) << ",\"retainedSpectrumBytes\":" << convolution.retainedSpectrumBytes << ",\"convolutionWorkBytes\":" << convolution.exactWorkBytes << ",\"opaquePlanBytes\":" << convolution.opaquePlanBytes << ",\"maximumRSSBytes\":" << maximumRSSBytes() << "},\n";
    stream << "  \"stages\":{\"phaseSeconds\":" << kernelMetrics.phaseSeconds << ",\"reconstructionSeconds\":" << kernelMetrics.reconstructionSeconds << ",\"derivativeReconstructionSeconds\":" << kernelMetrics.derivativeReconstructionSeconds << ",\"productSeconds\":" << kernelMetrics.productSeconds << ",\"projectionSeconds\":" << kernelMetrics.projectionSeconds << ",\"convolutionMappingSeconds\":" << kernelMetrics.convolutionMappingSeconds << ",\"convolutionSeconds\":" << kernelMetrics.convolutionSeconds << ",\"multiplierSeconds\":" << convolution.multiplierSeconds << "},\n";
    stream << "  \"schedule\":{\"centered\":{\"m\":" << convolution.centeredInnerLength << ",\"D\":" << convolution.centeredResidueBatchCount << ",\"I\":" << (convolution.centeredInPlace ? 1 : 0) << ",\"p\":" << convolution.centeredInputFactor << ",\"q\":" << convolution.centeredPaddedFactor << ",\"logicalPadding\":" << convolution.centeredLogicalPadding << "},\"hermitian\":{\"m\":" << convolution.hermitianInnerLength << ",\"D\":" << convolution.hermitianResidueBatchCount << ",\"I\":" << (convolution.hermitianInPlace ? 1 : 0) << ",\"p\":" << convolution.hermitianInputFactor << ",\"q\":" << convolution.hermitianPaddedFactor << ",\"logicalPadding\":" << convolution.hermitianLogicalPadding << "}},\n";
    stream << "  \"transformCounts\":{\"physicalInputs\":" << convolution.physicalInputTransformCount << ",\"sacrificialInputs\":" << convolution.sacrificialInputTransformCount << ",\"outputs\":" << convolution.outputTransformCount << ",\"libraryTotal\":" << convolution.physicalInputTransformCount + convolution.sacrificialInputTransformCount + convolution.outputTransformCount << "},\n";
    stream << "  \"threadBehavior\":{\"outerOpenMPThreads\":" << convolution.outerOpenMPThreads << ",\"maximumFFTWThreads\":" << convolution.maximumFFTWThreads << ",\"maximumMultiplierThreads\":" << convolution.maximumObservedMultiplierThreads << ",\"maximumOpenMPLevel\":" << convolution.maximumObservedOpenMPLevel << ",\"workerRegionsDisjoint\":" << (convolution.workerRegionsDisjoint ? "true" : "false") << "},\n";
    stream << "  \"lifecycle\":{\"activePlans\":" << lifetime.activePlans << ",\"created\":" << lifetime.totalPlansCreated << ",\"destroyed\":" << lifetime.totalPlansDestroyed << ",\"outstandingPlanningBytes\":" << lifetime.outstandingPlanningBytes << "}\n";
    stream << "}\n";
    if (options.outputPath.empty()) std::cout << stream.str();
    else {
        std::ofstream output(options.outputPath);
        if (!output) fail("Unable to open JSON output.");
        output << stream.str();
    }
}

} // namespace

int main(int argc, char** argv) {
    try {
        const auto options = parseOptions(argc,argv);
        const auto constructionStart = Clock::now();
        std::unique_ptr<WVFFTEngine> engine;
        requireStatus(WVFFTWEngine::create(options.threads,engine),"FFTW engine creation");
        std::unique_ptr<WVHorizontalConvolutionFactory> factory;
#if defined(WV_ISSUE128_HAS_FFTWPP)
        if (options.variant != "explicit") factory = std::make_unique<WVFFTWPlusPlusConvolutionFactory>(options.variant,options.threads);
#endif
        std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
        requireStatus(WVTransformConstantStratificationKernel::create(configuration(options),std::move(engine),kernel,std::move(factory)),"kernel creation");
        kernel->setStageInstrumentation(true);
        const auto constructionSeconds = secondsSince(constructionStart);
        const auto shape = kernel->descriptor().spectralShape();
        const auto count = shape.elementCount();
        std::vector<WVComplex64> Ap(count),Am(count),A0(count),Fp(count),Fm(count),F0(count);
        WVState state{0.5,0.0,{{Ap.data(),shape},{Am.data(),shape},{A0.data(),shape}}};
        WVFlux flux{{Fp.data(),shape},{Fm.data(),shape},{F0.data(),shape}};
        fillState(Ap,Am,A0,options.seed,0);
        const auto firstSeconds = execute(*kernel,state,flux);
        for (std::size_t warmup = 0; warmup < options.warmups; ++warmup) {
            fillState(Ap,Am,A0,options.seed,warmup+1);
            execute(*kernel,state,flux);
        }
        std::vector<double> samples;
        samples.reserve(options.samples);
        for (std::size_t sample = 0; sample < options.samples; ++sample) {
            fillState(Ap,Am,A0,options.seed,options.warmups+sample+1);
            samples.push_back(execute(*kernel,state,flux));
        }
        const auto correctnessStep = options.warmups + options.samples + 100;
        fillState(Ap,Am,A0,options.seed,correctnessStep);
        execute(*kernel,state,flux);
        double correctnessError = 0.0;
        bool wroteReference = false;
        if (!options.referenceOutputPath.empty()) {
            writeReference(options.referenceOutputPath,options,correctnessStep,Fp,Fm,F0);
            wroteReference = true;
        }
        if (!options.referenceInputPath.empty()) correctnessError = readReferenceError(options.referenceInputPath,options,correctnessStep,Fp,Fm,F0);
        const auto kernelMetrics = kernel->metrics();
        const auto persistentBytes = kernel->persistentBytes();
        const auto convolutionMetrics = kernel->horizontalConvolutionMetrics();
        const auto identity = WVFFTWEngine::linkedLibraries(options.expectedOpenMPRuntime);
        const auto cleanupStart = Clock::now();
        kernel.reset();
        const auto cleanupSeconds = secondsSince(cleanupStart);
        const auto lifetime = WVFFTWEngine::lifetimeMetrics();
        if (lifetime.activePlans != 0 || lifetime.outstandingPlanningBytes != 0 || lifetime.totalPlansCreated != lifetime.totalPlansDestroyed) fail("FFTW lifecycle check failed.");
        writeResult(options,identity,constructionSeconds,firstSeconds,samples,correctnessError,wroteReference,kernelMetrics,persistentBytes,count,convolutionMetrics,cleanupSeconds,lifetime);
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
