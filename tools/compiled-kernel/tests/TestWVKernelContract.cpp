#include "WaveVortexKernel/WVFFTEngine.hpp"
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"
#include "WVCoefficientFormulas.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <cmath>
#include <complex>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <vector>

using namespace wavevortex;

namespace {

void require(bool condition, const char* message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

std::complex<double> standardComplex(WVComplex64 value) { return {value.real,value.imag}; }

void requireComplexClose(WVComplex64 actual, std::complex<double> expected, const char* message) {
    const double tolerance = 2e-14 * std::max(1.0,std::abs(expected));
    require(std::abs(standardComplex(actual)-expected) <= tolerance,message);
}

template <std::size_t Target>
std::complex<double> referenceFieldValue(const WVConstantStratificationModes& modes, std::size_t index, const detail::EvolvedWaveVortexCoefficients& coefficients) {
    const auto Ap = standardComplex(coefficients.Ap);
    const auto Am = standardComplex(coefficients.Am);
    const auto A0 = standardComplex(coefficients.A0);
    if constexpr (Target == 0) return standardComplex(modes.UApField[index])*Ap + std::conj(standardComplex(modes.UApField[index]))*Am + standardComplex(modes.UA0Field[index])*A0;
    if constexpr (Target == 1) return standardComplex(modes.VApField[index])*Ap + std::conj(standardComplex(modes.VApField[index]))*Am + standardComplex(modes.VA0Field[index])*A0;
    if constexpr (Target == 2) return standardComplex(modes.WApField[index])*(Ap+Am);
    return modes.NApField[index]*(Ap-Am) + modes.NA0Field[index]*A0;
}

template <std::size_t Target, bool Conjugated>
void checkFieldAndDerivativeFormula(const WVConstantStratificationModes& modes, const WVFourierMode& horizontal, std::size_t index, std::size_t j, const detail::EvolvedWaveVortexCoefficients& coefficients) {
    const auto field = detail::coefficientValueForField<Target>(modes,index,coefficients);
    const auto expectedField = referenceFieldValue<Target>(modes,index,coefficients);
    requireComplexClose(field,expectedField,"WV-to-field coefficient formula mismatch");
    const bool endpoint = j == 0;
    const auto actual = detail::normalizedDerivativeSpectrum<Target < 2,Conjugated>(field,horizontal.k,horizontal.l,modes.verticalWavenumber[j],endpoint);
    const auto storedField = Conjugated ? std::conj(expectedField) : expectedField;
    const double storedK = Conjugated ? -horizontal.k : horizontal.k;
    const double storedL = Conjugated ? -horizontal.l : horizontal.l;
    auto expectedX = std::complex<double>(0.0,storedK)*storedField;
    auto expectedY = std::complex<double>(0.0,storedL)*storedField;
    auto expectedZ = (Target < 2 ? -modes.verticalWavenumber[j] : modes.verticalWavenumber[j])*storedField;
    if constexpr (Target < 2) {
        expectedX *= 0.5; expectedY *= 0.5; expectedZ = endpoint ? std::complex<double>{} : 0.5*expectedZ;
    } else {
        expectedX = endpoint ? std::complex<double>{} : 0.5*expectedX;
        expectedY = endpoint ? std::complex<double>{} : 0.5*expectedY;
        expectedZ *= 0.5;
    }
    requireComplexClose(actual.x,expectedX,"x-derivative coefficient formula mismatch");
    requireComplexClose(actual.y,expectedY,"y-derivative coefficient formula mismatch");
    requireComplexClose(actual.z,expectedZ,"z-derivative coefficient formula mismatch");
}

template <bool FFamily, bool Conjugated>
void checkFieldFamilyFormula(const WVConstantStratificationModes& modes, const WVFourierMode& horizontal, std::size_t index, std::size_t j) {
    const WVComplex64 Apm{0.17,-0.23};
    const WVComplex64 A0{-0.31,0.11};
    const double waveScale = FFamily ? modes.fWaveScale[index] : modes.gWaveScale[j];
    const double geostrophicScale = FFamily ? modes.Fg[j] : modes.Gg[j];
    const auto actual = detail::fieldFamilyDerivativeSpectrum<FFamily,Conjugated>(Apm,A0,waveScale,geostrophicScale,horizontal.k,horizontal.l,modes.verticalWavenumber[j]);
    auto expected = standardComplex(Apm)*waveScale + standardComplex(A0)*geostrophicScale;
    auto expectedX = std::complex<double>(0.0,horizontal.k)*expected;
    auto expectedY = std::complex<double>(0.0,horizontal.l)*expected;
    auto expectedZ = (FFamily ? -modes.verticalWavenumber[j] : modes.verticalWavenumber[j])*expected;
    if constexpr (Conjugated) { expected=std::conj(expected); expectedX=std::conj(expectedX); expectedY=std::conj(expectedY); expectedZ=std::conj(expectedZ); }
    requireComplexClose(actual.value,expected,"F/G field coefficient formula mismatch");
    requireComplexClose(actual.x,expectedX,"F/G x-derivative formula mismatch");
    requireComplexClose(actual.y,expectedY,"F/G y-derivative formula mismatch");
    requireComplexClose(actual.z,expectedZ,"F/G z-derivative formula mismatch");
}

WVTransformConstantStratificationConfiguration configuration(std::size_t Nx, std::size_t Ny, bool hydrostatic) {
    WVTransformConstantStratificationConfiguration value;
    value.Nx = Nx;
    value.Ny = Ny;
    value.Nz = 9;
    value.Nj = 5;
    value.Lx = 15000.0;
    value.Ly = 12000.0;
    value.Lz = 1300.0;
    value.N0 = 5.2e-3;
    value.rho0 = 1025.0;
    value.g = 9.81;
    value.planetaryRadius = 6.371e6;
    value.rotationRate = 7.2921e-5;
    value.latitude = 33.0;
    value.isHydrostatic = hydrostatic;
    return value;
}

class FakePlan final : public WVFFTPlan {
public:
    WVKernelStatus execute(const void* input, void* output) override {
        return input != nullptr && output != nullptr ? WVKernelStatus::ok() : WVKernelStatus{WVKernelStatusCode::invalidPointer, "fake pointer"};
    }
    std::size_t persistentBytes() const noexcept override { return 64; }
};

class FakeEngine final : public WVFFTEngine {
public:
    std::string identifier() const override { return "fake"; }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& specification, std::unique_ptr<WVFFTPlan>& plan) override {
        last = specification;
        plan = std::make_unique<FakePlan>();
        return WVKernelStatus::ok();
    }
    WVFFTPlanSpecification last;
};

class FailingPlan final : public WVFFTPlan {
public:
    explicit FailingPlan(std::shared_ptr<std::size_t> activePlans) : activePlans_(std::move(activePlans)) { ++*activePlans_; }
    ~FailingPlan() override { --*activePlans_; }
    WVKernelStatus execute(const void*, void*) override { return {WVKernelStatusCode::fftExecutionFailure,"injected execution failure"}; }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
private:
    std::shared_ptr<std::size_t> activePlans_;
};

class FailingEngine final : public WVFFTEngine {
public:
    explicit FailingEngine(WVKernelStatusCode code) : code_(code), activePlans(std::make_shared<std::size_t>(0)) {}
    std::string identifier() const override { return "failing"; }
    WVKernelStatus createPlan(const WVFFTPlanSpecification&, std::unique_ptr<WVFFTPlan>& plan) override {
        if (code_ == WVKernelStatusCode::fftPlanFailure || code_ == WVKernelStatusCode::allocationFailure) return {code_,"injected planning failure"};
        plan = std::make_unique<FailingPlan>(activePlans);
        return WVKernelStatus::ok();
    }
    WVKernelStatusCode code_;
    std::shared_ptr<std::size_t> activePlans;
};

void testCoefficientFormulaHelpers() {
    const std::size_t horizontalSizes[][2] = {{6,5},{7,5}};
    for (const auto& horizontalSize : horizontalSizes) for (const bool hydrostatic : {true,false}) {
        auto config = configuration(horizontalSize[0],horizontalSize[1],hydrostatic);
        config.Nz = 7;
        config.Nj = 6;
        config.shouldAntialias = false;
        WVTransformConstantStratificationDescriptor descriptor;
        const auto status = WVTransformConstantStratificationDescriptor::create(config,descriptor);
        require(static_cast<bool>(status),"formula-test descriptor construction failed");
        const auto& mapping = descriptor.halfSpectrumMappings();
        const auto& modes = descriptor.verticalModes();
        require(!mapping.directWVIndices.empty(),"formula tests require direct half-spectrum storage");
        require(!mapping.conjugatedWVIndices.empty(),"formula tests require conjugated half-spectrum storage");

        const std::size_t selectedModes[] = {0,mapping.directWVIndices.back(),mapping.conjugatedWVIndices.front()};
        const std::size_t selectedVerticalModes[] = {0,1,config.Nj-1};
        for (const auto mode : selectedModes) for (const auto j : selectedVerticalModes) {
            const auto index = j + config.Nj * mode;
            const auto& horizontal = descriptor.fourierModes()[mode];
            const WVComplex64 Ap{0.13+0.01*static_cast<double>(j),-0.21};
            const WVComplex64 Am{-0.08,0.19+0.01*static_cast<double>(mode)};
            const WVComplex64 A0{0.07,-0.17};
            const double angle = modes.omega[index] * 37.5;
            const auto phaseValue = detail::phase(angle);
            requireComplexClose(phaseValue,{std::cos(angle),std::sin(angle)},"phase formula mismatch");
            const auto evolved = detail::evolveWaveVortexCoefficients(Ap,Am,A0,phaseValue);
            requireComplexClose(evolved.Ap,standardComplex(Ap)*standardComplex(phaseValue),"positive-wave phase evolution mismatch");
            requireComplexClose(evolved.Am,standardComplex(Am)*std::conj(standardComplex(phaseValue)),"negative-wave phase evolution mismatch");
            requireComplexClose(evolved.A0,standardComplex(A0),"geostrophic phase evolution mismatch");

            const bool conjugated = mapping.conjugatesStoredValueByWVIndex[mode] != 0;
            if (conjugated) {
                checkFieldAndDerivativeFormula<0,true>(modes,horizontal,index,j,evolved);
                checkFieldAndDerivativeFormula<1,true>(modes,horizontal,index,j,evolved);
                checkFieldAndDerivativeFormula<2,true>(modes,horizontal,index,j,evolved);
                checkFieldAndDerivativeFormula<3,true>(modes,horizontal,index,j,evolved);
                checkFieldFamilyFormula<true,true>(modes,horizontal,index,j);
                checkFieldFamilyFormula<false,true>(modes,horizontal,index,j);
            } else {
                checkFieldAndDerivativeFormula<0,false>(modes,horizontal,index,j,evolved);
                checkFieldAndDerivativeFormula<1,false>(modes,horizontal,index,j,evolved);
                checkFieldAndDerivativeFormula<2,false>(modes,horizontal,index,j,evolved);
                checkFieldAndDerivativeFormula<3,false>(modes,horizontal,index,j,evolved);
                checkFieldFamilyFormula<true,false>(modes,horizontal,index,j);
                checkFieldFamilyFormula<false,false>(modes,horizontal,index,j);
            }

            const WVComplex64 U{0.23,-0.14};
            const WVComplex64 V{-0.09,0.31};
            const WVComplex64 N{0.12,0.05};
            const auto expectedVorticity = std::complex<double>(0.0,horizontal.k)*standardComplex(V) - std::complex<double>(0.0,horizontal.l)*standardComplex(U);
            const auto expectedA0 = modes.A0FromVorticity[index]*expectedVorticity + modes.A0FromBuoyancy[index]*standardComplex(N);
            const auto actualA0 = detail::geostrophicCoefficient(U,V,N,horizontal.k,horizontal.l,modes.A0FromVorticity[index],modes.A0FromBuoyancy[index]);
            requireComplexClose(actualA0,expectedA0,"field-to-geostrophic coefficient formula mismatch");
            const auto actualBuoyancy = detail::buoyancyProjection(N,actualA0,modes.NA0Field[index],modes.ApmNProjection[index]);
            requireComplexClose(actualBuoyancy,(standardComplex(N)-expectedA0*modes.NA0Field[index])*modes.ApmNProjection[index],"field-to-wave buoyancy formula mismatch");

            const auto pair = detail::waveCoefficientPair(WVComplex64{0.19,-0.04},actualBuoyancy);
            requireComplexClose(pair.Ap,std::complex<double>(0.19,-0.04)+standardComplex(actualBuoyancy),"positive-wave assembly formula mismatch");
            requireComplexClose(pair.Am,std::complex<double>(0.19,-0.04)-standardComplex(actualBuoyancy),"negative-wave assembly formula mismatch");
            const auto referencePair = detail::atReferenceTime(pair,phaseValue);
            requireComplexClose(referencePair.Ap,standardComplex(pair.Ap)*std::conj(standardComplex(phaseValue)),"positive-wave reference-time formula mismatch");
            requireComplexClose(referencePair.Am,standardComplex(pair.Am)*standardComplex(phaseValue),"negative-wave reference-time formula mismatch");
        }

        const WVComplex64 U{0.33,-0.27};
        const WVComplex64 V{-0.15,0.08};
        const auto inertial = detail::inertialCoefficientPair(U,V,modes.inertialScale[1]);
        const auto expectedInertial = (standardComplex(U)-std::complex<double>(0.0,1.0)*standardComplex(V))*modes.inertialScale[1];
        requireComplexClose(inertial.Ap,expectedInertial,"inertial positive-wave formula mismatch");
        requireComplexClose(inertial.Am,std::conj(expectedInertial),"inertial negative-wave formula mismatch");
        const auto inertialU = detail::inertialCoefficientPair<0>(U,modes.inertialScale[1]);
        const auto inertialV = detail::inertialCoefficientPair<1>(V,modes.inertialScale[1]);
        const auto inertialN = detail::inertialCoefficientPair<3>(V,modes.inertialScale[1]);
        requireComplexClose(inertialU.Ap,standardComplex(U)*modes.inertialScale[1],"inertial U-target formula mismatch");
        requireComplexClose(inertialV.Ap,std::complex<double>(0.0,-1.0)*standardComplex(V)*modes.inertialScale[1],"inertial V-target formula mismatch");
        requireComplexClose(inertialN.Ap,{},"nonvelocity inertial target was not zero");
    }
}

void testDescriptor() {
    const auto evenConfiguration = configuration(16, 12, false);
    WVTransformConstantStratificationDescriptor even;
    auto status = WVTransformConstantStratificationDescriptor::create(evenConfiguration, even);
    require(static_cast<bool>(status), "even descriptor construction failed");
    require(WVKernelContractVersion == 4,"kernel contract version changed");
    require(even.spectralShape().rows == 5, "unexpected spectral rows");
    require(even.spectralShape().columns == even.Nkl(),"spectral shape is not canonical [Nj,Nkl]");
    require(even.Nkl() > 0, "empty Fourier modes");
    require(even.fourierModes().front().kMode == 0 && even.fourierModes().front().lMode == 0, "zero mode must be first");
    require(even.verticalModes().z.front() == -1300.0, "unexpected bottom coordinate");
    require(even.verticalModes().z.back() == 0.0, "unexpected surface coordinate");
    require(even.verticalModes().h0.front() == 1300.0, "unexpected barotropic equivalent depth");
    require(std::isfinite(even.verticalModes().coriolisFrequency), "non-finite Coriolis frequency");
    require(even.verticalModes().apmWProjectionPrefactor.size() == even.spectralShape().rows, "compact ApmW prefactor must be vertical-only");
    for (std::size_t j = 0; j < even.spectralShape().rows; ++j) {
        const double sign = j % 2 == 0 ? 1.0 : -1.0;
        const double f = even.verticalModes().coriolisFrequency;
        const double expected = sign * std::sqrt(evenConfiguration.g * evenConfiguration.Lz /
            (2.0 * (evenConfiguration.N0 * evenConfiguration.N0 - f * f)));
        require(std::abs(even.verticalModes().apmWProjectionPrefactor[j] - expected) <= 1e-15 * std::abs(expected), "compact ApmW prefactor changed #126 pre-scaling");
    }
    require(!even.halfSpectrumMappings().selfConjugateRows.empty(),"even-grid zero/Nyquist boundary mappings are missing");
    require(!even.halfSpectrumMappings().directWVIndices.empty() && !even.halfSpectrumMappings().conjugatedWVIndices.empty(),"even-grid direct/conjugated half storage is incomplete");
    require(even.halfSpectrumMappings().hermitianCompletionRows.size() == even.halfSpectrumMappings().hermitianSourceRows.size(),"Hermitian boundary mappings are inconsistent");

    WVTransformConstantStratificationDescriptor odd;
    status = WVTransformConstantStratificationDescriptor::create(configuration(15, 13, true), odd);
    require(static_cast<bool>(status) && odd.Nkl() > 0, "odd descriptor construction failed");
    require(!odd.halfSpectrumMappings().selfConjugateRows.empty(),"odd-grid zero-mode boundary mapping is missing");

    auto invalid = configuration(16, 12, false);
    invalid.Nj = invalid.Nz;
    status = WVTransformConstantStratificationDescriptor::create(invalid, odd);
    require(status.code == WVKernelStatusCode::invalidConfiguration, "invalid Nj was accepted");

    invalid = configuration(16, 12, false);
    invalid.Nx = static_cast<std::size_t>(-1);
    status = WVTransformConstantStratificationDescriptor::create(invalid, odd);
    require(status.code == WVKernelStatusCode::sizeOverflow, "overflowing horizontal shape was accepted");
}

void testViewsAndAliasing() {
    WVTransformConstantStratificationDescriptor descriptor;
    auto status = WVTransformConstantStratificationDescriptor::create(configuration(8, 8, false), descriptor);
    require(static_cast<bool>(status), "descriptor construction failed");
    const auto shape = descriptor.spectralShape();
    const auto count = shape.elementCount();
    std::vector<WVComplex64> Ap(count), Am(count), A0(count), Fp(count), Fm(count), F0(count);
    WVState state{0.5, 0.0, {{Ap.data(), shape}, {Am.data(), shape}, {A0.data(), shape}}};
    WVFlux flux{{Fp.data(), shape}, {Fm.data(), shape}, {F0.data(), shape}};
    require(static_cast<bool>(validateStateAndFlux(descriptor, state, flux)), "valid views were rejected");
    flux.Fp.data = Ap.data();
    status = validateStateAndFlux(descriptor, state, flux);
    require(status.code == WVKernelStatusCode::overlappingArrays, "overlapping state and flux were accepted");
}

void testEngineContract() {
    FakeEngine engine;
    WVFFTPlanSpecification specification;
    specification.kind = WVFFTPlanKind::horizontalRealToComplex2D;
    specification.transformDimensions = {{12,16,9*9},{16,1,9}};
    specification.batchDimensions = {{9,16*12,1}};
    std::unique_ptr<WVFFTPlan> plan;
    const auto status = engine.createPlan(specification, plan);
    require(static_cast<bool>(status) && plan && engine.last.batchDimensions.front().count == 9, "fake plan contract failed");
    double input = 0.0;
    double output = 0.0;
    require(static_cast<bool>(plan->execute(&input, &output)), "fake plan execution failed");
}

void testFailureCleanup() {
    for (const auto failure : {WVKernelStatusCode::fftPlanFailure,WVKernelStatusCode::allocationFailure}) {
        auto engine = std::make_unique<FailingEngine>(failure);
        const auto activePlans = engine->activePlans;
        std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
        const auto status = WVTransformConstantStratificationKernel::create(configuration(8,8,false),std::move(engine),kernel);
        require(status.code == failure,"kernel did not preserve the injected plan-creation failure");
        require(!kernel,"failed kernel construction returned an object");
        require(*activePlans == 0,"failed construction leaked plans");
    }

    auto engine = std::make_unique<FailingEngine>(WVKernelStatusCode::fftExecutionFailure);
    const auto activePlans = engine->activePlans;
    std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
    auto status = WVTransformConstantStratificationKernel::create(configuration(8,8,false),std::move(engine),kernel);
    require(static_cast<bool>(status) && kernel,"execution-failure kernel construction failed");
    const auto shape = kernel->descriptor().spectralShape();
    std::vector<WVComplex64> Ap(shape.elementCount()),Am(shape.elementCount()),A0(shape.elementCount()),Fp(shape.elementCount()),Fm(shape.elementCount()),F0(shape.elementCount());
    WVState state{0.0,0.0,{{Ap.data(),shape},{Am.data(),shape},{A0.data(),shape}}};
    WVFlux flux{{Fp.data(),shape},{Fm.data(),shape},{F0.data(),shape}};
    status = kernel->nonlinearFlux(state,flux);
    require(status.code == WVKernelStatusCode::fftExecutionFailure,"kernel did not preserve the injected execution failure");
    kernel.reset();
    require(*activePlans == 0,"kernel destruction leaked plans after execution failure");
}

void testReferenceHorizontalRoundTrip() {
    constexpr std::size_t Nx = 6, Ny = 5, Nz = 3, fields = 4, NxHalf = Nx / 2 + 1;
    WVFFTPlanSpecification forward;
    forward.kind = WVFFTPlanKind::horizontalRealToComplex2D;
    forward.transformDimensions = {{Ny,static_cast<std::ptrdiff_t>(Nx),static_cast<std::ptrdiff_t>(Nz*fields*NxHalf)},{Nx,1,static_cast<std::ptrdiff_t>(Nz*fields)}};
    forward.batchDimensions = {{Nz,static_cast<std::ptrdiff_t>(Nx*Ny),1},{fields,static_cast<std::ptrdiff_t>(Nx*Ny*Nz),static_cast<std::ptrdiff_t>(Nz)}};
    auto inverse = forward;
    inverse.kind = WVFFTPlanKind::horizontalComplexToReal2D;
    for (auto& dimension : inverse.transformDimensions) std::swap(dimension.inputStride,dimension.outputStride);
    for (auto& dimension : inverse.batchDimensions) std::swap(dimension.inputStride,dimension.outputStride);
    wavevortex::test::WVReferenceFFTEngine engine;
    std::unique_ptr<WVFFTPlan> forwardPlan, inversePlan;
    require(static_cast<bool>(engine.createPlan(forward,forwardPlan)),"reference forward plan failed");
    require(static_cast<bool>(engine.createPlan(inverse,inversePlan)),"reference inverse plan failed");
    std::vector<double> source(Nx*Ny*Nz*fields), output(source.size());
    std::vector<WVComplex64> half(NxHalf*Ny*Nz*fields);
    for (std::size_t i = 0; i < source.size(); ++i) source[i] = std::sin(0.1*static_cast<double>(i+1));
    require(static_cast<bool>(forwardPlan->execute(source.data(),half.data())),"reference forward failed");
    require(static_cast<bool>(inversePlan->execute(half.data(),output.data())),"reference inverse failed");
    double error = 0.0;
    for (std::size_t i = 0; i < source.size(); ++i) error = std::max(error,std::abs(output[i]/static_cast<double>(Nx*Ny)-source[i]));
    require(error < 1e-12,"reference horizontal round trip failed");
}

void testNonlinearFlux(bool hydrostatic) {
    auto config = configuration(6, 5, hydrostatic);
    config.Nz = 7;
    config.Nj = 4;
    config.shouldAntialias = true;
    std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
    auto status = WVTransformConstantStratificationKernel::create(config, std::make_unique<wavevortex::test::WVReferenceFFTEngine>(), kernel);
    require(static_cast<bool>(status) && kernel, "kernel construction failed");

    const auto shape = kernel->descriptor().spectralShape();
    const auto count = shape.elementCount();
    std::vector<WVComplex64> Ap(count), Am(count), A0(count), Fp(count), Fm(count), F0(count);
    WVState state{0.5, 0.0, {{Ap.data(),shape},{Am.data(),shape},{A0.data(),shape}}};
    WVFlux flux{{Fp.data(),shape},{Fm.data(),shape},{F0.data(),shape}};
    status = kernel->nonlinearFlux(state,flux);
    require(static_cast<bool>(status), "zero-state nonlinear flux failed");
    for (const auto* array : {&Fp,&Fm,&F0}) {
        for (const auto& value : *array) require(value.real == 0.0 && value.imag == 0.0,"zero state produced nonzero nonlinear flux");
    }

    for (std::size_t i = 0; i < count; ++i) {
        Ap[i] = {1e-4*std::sin(0.17*static_cast<double>(i+1)),1e-4*std::cos(0.11*static_cast<double>(i+2))};
        Am[i] = {1e-4*std::cos(0.13*static_cast<double>(i+3)),1e-4*std::sin(0.07*static_cast<double>(i+4))};
        A0[i] = {1e-4*std::sin(0.19*static_cast<double>(i+5)),1e-4*std::cos(0.05*static_cast<double>(i+6))};
    }
    status = kernel->nonlinearFlux(state,flux);
    require(static_cast<bool>(status), "nonlinear flux failed");
    for (const auto* array : {&Fp,&Fm,&F0}) {
        for (const auto& value : *array) require(std::isfinite(value.real) && std::isfinite(value.imag),"nonlinear flux produced a non-finite coefficient");
    }
    const std::size_t executionsPerCall = hydrostatic ? 18 : 23;
    require(kernel->metrics().executionCount == 2*executionsPerCall,"unexpected nonlinear-flux plan execution count");
    require(kernel->metrics().nonlinearFluxCallCount == 2,"unexpected nonlinear-flux call count");
    require(kernel->metrics().nonlinearFluxPhaseEvaluationCount == 2*count,"nonlinear flux did not evaluate phase exactly once per coefficient");
    require(std::string(kernel->nonlinearFluxScheduleIdentifier()) == "streamed-target-three-channel","unexpected nonlinear-flux schedule identifier");
    const auto halfFieldBytes = (config.Nx / 2 + 1) * config.Ny * config.Nz * sizeof(WVComplex64);
    const auto realFieldBytes = config.Nx * config.Ny * config.Nz * sizeof(double);
    require(kernel->metrics().halfSpectrumScratchCapacityBytes == 4 * halfFieldBytes,"streamed target half-spectrum scratch is not 4H");
    require(kernel->metrics().realScratchCapacityBytes == 6 * realFieldBytes,"streamed target real scratch is not 6R");
    require(kernel->phaseReservationBytes() == halfFieldBytes,"streamed target phase reservation is not one H region");
    require(kernel->descriptor().spectralShape().elementCount() * sizeof(WVComplex64) <= kernel->phaseReservationBytes(),"streamed phase values do not fit inside their H-sized reservation");
    require(kernel->metrics().planCount == 17,"unexpected streamed target plan count");

    WVFlux overlapping{{Ap.data(),shape},{Fm.data(),shape},{F0.data(),shape}};
    status = kernel->nonlinearFlux(state,overlapping);
    require(status.code == WVKernelStatusCode::overlappingArrays,"overlapping nonlinear-flux arrays were accepted");
}

[[maybe_unused]] void testFusedTransformRoundTrip(bool hydrostatic) {
    auto config = configuration(6, 5, hydrostatic);
    config.Nz = 7;
    config.Nj = 4;
    config.shouldAntialias = false;
    std::unique_ptr<WVTransformConstantStratificationKernel> kernel;
    auto status = WVTransformConstantStratificationKernel::create(config, std::make_unique<wavevortex::test::WVReferenceFFTEngine>(), kernel);
    require(static_cast<bool>(status) && kernel, "kernel construction failed");

    const auto spatial = kernel->descriptor().spatialShape();
    const auto spectral = kernel->descriptor().spectralShape();
    const std::size_t inputChannels = hydrostatic ? 3 : 4;
    std::vector<double> source(spatial.elementCount() * inputChannels);
    for (std::size_t i = 0; i < source.size(); ++i) source[i] = std::sin(0.173 * static_cast<double>(i + 1)) + 0.2 * std::cos(0.071 * static_cast<double>(i + 3));
    const auto count = spectral.elementCount();
    std::vector<WVComplex64> Ap(count), Am(count), A0(count), Ap2(count), Am2(count), A02(count);
    WVMutableCoefficients coefficients{{Ap.data(),spectral},{Am.data(),spectral},{A0.data(),spectral}};
    const WVRealFieldBundleConstView input{source.data(),{spatial.first,spatial.second,spatial.third,inputChannels}};
    status = hydrostatic ? kernel->transformUVEtaToWaveVortex(input,0.25,0.0,coefficients) : kernel->transformUVWEtaToWaveVortex(input,0.25,0.0,coefficients);
    require(static_cast<bool>(status), "fused forward transform failed");

    std::vector<double> reconstructed(spatial.elementCount() * 4);
    WVState state{0.25,0.0,{{Ap.data(),spectral},{Am.data(),spectral},{A0.data(),spectral}}};
    WVRealFieldBundleView output{reconstructed.data(),{spatial.first,spatial.second,spatial.third,4}};
    status = kernel->transformWaveVortexToUVWEta(state,output);
    require(static_cast<bool>(status), "fused inverse transform failed");

    WVMutableCoefficients repeated{{Ap2.data(),spectral},{Am2.data(),spectral},{A02.data(),spectral}};
    const WVRealFieldBundleConstView repeatedInput{reconstructed.data(),{spatial.first,spatial.second,spatial.third,inputChannels}};
    status = hydrostatic ? kernel->transformUVEtaToWaveVortex(repeatedInput,0.25,0.0,repeated) : kernel->transformUVWEtaToWaveVortex(repeatedInput,0.25,0.0,repeated);
    require(static_cast<bool>(status), "repeated fused forward transform failed");
    for (const auto* array : {&Ap2,&Am2,&A02}) for (const auto& coefficient : *array) require(std::isfinite(coefficient.real) && std::isfinite(coefficient.imag),"fused transform produced a non-finite coefficient");
    require(kernel->metrics().horizontalExecutionCount == 3, "unexpected horizontal execution count");
    require(kernel->metrics().verticalExecutionCount == 6, "unexpected vertical execution count");
    require(kernel->persistentBytes() >= kernel->scratchBytes(), "persistent byte accounting is incomplete");
    WVMutableCoefficients overlapping{{Ap2.data(),spectral},{Ap2.data(),spectral},{A02.data(),spectral}};
    status = hydrostatic ? kernel->transformUVEtaToWaveVortex(input,0.25,0.0,overlapping) : kernel->transformUVWEtaToWaveVortex(input,0.25,0.0,overlapping);
    require(status.code == WVKernelStatusCode::overlappingArrays,"overlapping transform outputs were accepted");
}

} // namespace

int main() {
    testCoefficientFormulaHelpers();
    testDescriptor();
    testViewsAndAliasing();
    testEngineContract();
    testFailureCleanup();
    testReferenceHorizontalRoundTrip();
    testFusedTransformRoundTrip(true);
    testFusedTransformRoundTrip(false);
    testNonlinearFlux(true);
    testNonlinearFlux(false);
    std::cout << "WaveVortex kernel contract tests passed\n";
    return 0;
}
