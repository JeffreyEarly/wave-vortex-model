#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
#include <stdexcept>

namespace wavevortex {
namespace {

enum PlanIndex : std::size_t {
    horizontalForward3, horizontalForward4, horizontalInverse3, horizontalInverse4,
    verticalDCT2Storage3, verticalDST1Storage3, verticalDST2Storage3, verticalDCT1Storage3,
#if defined(WV_KERNEL_PAIRED_SCHEDULE)
    horizontalInverse6, verticalDCT4Storage6, verticalDST2Storage6, verticalDST4Storage6, verticalDCT2Storage6,
#endif
    verticalDCT2Storage4, verticalDST2Storage4,
    verticalDCT3Storage4, verticalDST3Storage4,
    verticalDCT1Storage4, verticalDST1Storage4,
    planCount
};

WVComplex64 add(WVComplex64 a, WVComplex64 b) { return {a.real + b.real, a.imag + b.imag}; }
WVComplex64 subtract(WVComplex64 a, WVComplex64 b) { return {a.real - b.real, a.imag - b.imag}; }
WVComplex64 multiply(WVComplex64 a, WVComplex64 b) { return {a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}; }
WVComplex64 multiply(WVComplex64 a, double b) { return {a.real * b, a.imag * b}; }
WVComplex64 conjugate(WVComplex64 a) { return {a.real, -a.imag}; }
WVComplex64 phase(double angle) { return {std::cos(angle), std::sin(angle)}; }

WVComplex64 modalValueForTarget(const WVConstantStratificationModes& modes, std::size_t index, std::size_t target, WVComplex64 Ap, WVComplex64 Am, WVComplex64 A0) {
    if (target == 0) return add(multiply(add(multiply(modes.UAp[index],Ap),multiply(modes.UAm[index],Am)),1.0 / modes.Fwg[index]),multiply(modes.UA0[index],A0));
    if (target == 1) return add(multiply(add(multiply(modes.VAp[index],Ap),multiply(modes.VAm[index],Am)),1.0 / modes.Fwg[index]),multiply(modes.VA0[index],A0));
    if (target == 2) return multiply(add(multiply(modes.WAp[index],Ap),multiply(modes.WAm[index],Am)),1.0 / modes.Gwg[index]);
    return add(multiply(add(multiply(Ap,modes.NAp[index]),multiply(Am,modes.NAm[index])),1.0 / modes.Gwg[index]),multiply(A0,modes.NA0[index]));
}

std::size_t checkedProduct(std::size_t first, std::size_t second) {
    if (first != 0 && second > std::numeric_limits<std::size_t>::max() / first) throw std::overflow_error("kernel scratch size overflow");
    return first * second;
}

class ExecutionGuard {
public:
    explicit ExecutionGuard(bool& flag) : flag_(flag), entered_(!flag) { if (entered_) flag_ = true; }
    ~ExecutionGuard() { if (entered_) flag_ = false; }
    bool entered() const noexcept { return entered_; }
private:
    bool& flag_;
    bool entered_;
};

WVKernelStatus validateBundle(const WVRealFieldBundleConstView& view, WVShape3D spatial, std::size_t channels, const char* name) {
    if (view.shape.first != spatial.first || view.shape.second != spatial.second || view.shape.third != spatial.third || view.shape.fourth != channels) {
        return {WVKernelStatusCode::invalidShape, std::string(name) + " must have shape [Nx,Ny,Nz,Nfield]."};
    }
    if (view.data == nullptr) return {WVKernelStatusCode::invalidPointer, std::string(name) + " has a null data pointer."};
    return WVKernelStatus::ok();
}

WVKernelStatus validateBundle(const WVRealFieldBundleView& view, WVShape3D spatial, std::size_t channels, const char* name) {
    return validateBundle(WVRealFieldBundleConstView{view.data, view.shape}, spatial, channels, name);
}

template <typename T>
WVKernelStatus validateSpectral(const WVMatrixView<T>& view, WVShape2D spectral, const char* name) {
    if (view.shape.rows != spectral.rows || view.shape.columns != spectral.columns) return {WVKernelStatusCode::invalidShape, std::string(name) + " must have shape [Nj,Nkl]."};
    if (view.data == nullptr) return {WVKernelStatusCode::invalidPointer, std::string(name) + " has a null data pointer."};
    return WVKernelStatus::ok();
}

bool memoryOverlaps(const void* first, std::size_t firstBytes, const void* second, std::size_t secondBytes) {
    if (first == nullptr || second == nullptr || firstBytes == 0 || secondBytes == 0) return false;
    const auto firstAddress = reinterpret_cast<std::uintptr_t>(first);
    const auto secondAddress = reinterpret_cast<std::uintptr_t>(second);
    return firstAddress < secondAddress + secondBytes && secondAddress < firstAddress + firstBytes;
}

WVKernelStatus validateForwardOwnership(const WVRealFieldBundleConstView& fields, const WVMutableCoefficients& coefficients, WVShape2D spectral) {
    const auto coefficientBytes = spectral.elementCount() * sizeof(WVComplex64);
    const auto fieldBytes = fields.shape.elementCount() * sizeof(double);
    const void* outputs[] = {coefficients.Ap.data,coefficients.Am.data,coefficients.A0.data};
    for (std::size_t first = 0; first < 3; ++first) {
        if (memoryOverlaps(outputs[first],coefficientBytes,fields.data,fieldBytes)) return {WVKernelStatusCode::overlappingArrays,"Forward coefficient outputs must not overlap the spatial input."};
        for (std::size_t second = first + 1; second < 3; ++second) if (memoryOverlaps(outputs[first],coefficientBytes,outputs[second],coefficientBytes)) return {WVKernelStatusCode::overlappingArrays,"Forward coefficient outputs must not overlap each other."};
    }
    return WVKernelStatus::ok();
}

WVKernelStatus validateInverseOwnership(const WVState& state, const WVRealFieldBundleView& fields, WVShape2D spectral) {
    const auto coefficientBytes = spectral.elementCount() * sizeof(WVComplex64);
    const auto fieldBytes = fields.shape.elementCount() * sizeof(double);
    for (const void* input : {static_cast<const void*>(state.coefficients.Ap.data),static_cast<const void*>(state.coefficients.Am.data),static_cast<const void*>(state.coefficients.A0.data)}) if (memoryOverlaps(fields.data,fieldBytes,input,coefficientBytes)) return {WVKernelStatusCode::overlappingArrays,"Inverse spatial output must not overlap coefficient inputs."};
    return WVKernelStatus::ok();
}

WVKernelStatus validateDerivativeOwnership(const WVComplexConstView& Apm, const WVComplexConstView& A0, const WVRealFieldBundleView& fields, WVShape2D spectral) {
    const auto coefficientBytes = spectral.elementCount() * sizeof(WVComplex64);
    const auto fieldBytes = fields.shape.elementCount() * sizeof(double);
    if (memoryOverlaps(fields.data,fieldBytes,Apm.data,coefficientBytes) || memoryOverlaps(fields.data,fieldBytes,A0.data,coefficientBytes)) return {WVKernelStatusCode::overlappingArrays,"Derivative output must not overlap coefficient inputs."};
    return WVKernelStatus::ok();
}

WVFFTPlanSpecification horizontalSpecification(const WVTransformConstantStratificationConfiguration& c, std::size_t fields, bool forward) {
    const std::size_t NxHalf = c.Nx / 2 + 1;
    const std::size_t realPlane = c.Nx * c.Ny;
    const std::size_t realField = realPlane * c.Nz;
    const std::size_t halfRows = NxHalf * c.Ny;
    const std::size_t halfField = halfRows * c.Nz;
    WVFFTPlanSpecification specification;
    specification.kind = forward ? WVFFTPlanKind::horizontalRealToComplex2D : WVFFTPlanKind::horizontalComplexToReal2D;
    specification.transformDimensions = {
        {c.Ny, static_cast<std::ptrdiff_t>(c.Nx), static_cast<std::ptrdiff_t>(c.Nz * fields * NxHalf)},
        {c.Nx, 1, static_cast<std::ptrdiff_t>(c.Nz * fields)}};
    specification.batchDimensions = {
        {c.Nz, static_cast<std::ptrdiff_t>(realPlane), 1},
        {fields, static_cast<std::ptrdiff_t>(realField), static_cast<std::ptrdiff_t>(c.Nz)}};
    specification.inputBytes = forward ? fields * realField * sizeof(double) : fields * halfField * sizeof(WVComplex64);
    specification.outputBytes = forward ? fields * halfField * sizeof(WVComplex64) : fields * realField * sizeof(double);
    specification.destroysInput = !forward;
    if (!forward) {
        for (auto& dimension : specification.transformDimensions) std::swap(dimension.inputStride, dimension.outputStride);
        for (auto& dimension : specification.batchDimensions) std::swap(dimension.inputStride, dimension.outputStride);
    }
    return specification;
}

WVFFTPlanSpecification verticalSpecification(const WVTransformConstantStratificationConfiguration& c, std::size_t halfRows, std::size_t storageChannels, std::size_t transformedChannels, bool sine) {
    WVFFTPlanSpecification specification;
    specification.kind = sine ? WVFFTPlanKind::verticalDSTI : WVFFTPlanKind::verticalDCTI;
    const std::size_t transformLength = sine ? c.Nz - 2 : c.Nz;
    specification.transformDimensions = {{transformLength, 2, 2}};
    specification.batchDimensions = {
        {2, 1, 1},
        {halfRows, static_cast<std::ptrdiff_t>(2 * c.Nz * storageChannels), static_cast<std::ptrdiff_t>(2 * c.Nz * storageChannels)},
        {transformedChannels, static_cast<std::ptrdiff_t>(2 * c.Nz), static_cast<std::ptrdiff_t>(2 * c.Nz)}};
    specification.inputBytes = 2 * c.Nz * halfRows * storageChannels * sizeof(double);
    specification.outputBytes = specification.inputBytes;
    specification.inPlace = true;
    return specification;
}

void normalizeForwardDCT(WVComplex64* data, std::size_t Nz, std::size_t rows, std::size_t storageChannels, std::size_t firstChannel, std::size_t channels) {
    const double scale = 1.0 / static_cast<double>(Nz - 1);
    for (std::size_t row = 0; row < rows; ++row) for (std::size_t channel = firstChannel; channel < firstChannel + channels; ++channel) {
        const auto base = Nz * channel + Nz * storageChannels * row;
        for (std::size_t z = 0; z < Nz; ++z) data[base + z] = multiply(data[base + z],scale);
        data[base + Nz - 1] = multiply(data[base + Nz - 1],0.5);
    }
}

void normalizeForwardDST(WVComplex64* data, std::size_t Nz, std::size_t rows, std::size_t storageChannels, std::size_t firstChannel, std::size_t channels) {
    const double scale = 1.0 / static_cast<double>(Nz - 1);
    for (std::size_t row = 0; row < rows; ++row) for (std::size_t channel = firstChannel; channel < firstChannel + channels; ++channel) {
            const auto base = Nz * channel + Nz * storageChannels * row;
            data[base] = {};
            for (std::size_t z = 1; z + 1 < Nz; ++z) data[base + z] = multiply(data[base + z], scale);
            data[base + Nz - 1] = {};
    }
}

void normalizeInverseDCT(WVComplex64* data, std::size_t Nz, std::size_t rows, std::size_t storageChannels, std::size_t firstChannel, std::size_t channels) {
    for (std::size_t row = 0; row < rows; ++row) for (std::size_t channel = firstChannel; channel < firstChannel + channels; ++channel) {
        const auto base = Nz * channel + Nz * storageChannels * row;
        for (std::size_t z = 0; z < Nz; ++z) data[base + z] = multiply(data[base + z],0.5);
    }
}

void normalizeInverseDST(WVComplex64* data, std::size_t Nz, std::size_t rows, std::size_t storageChannels, std::size_t firstChannel, std::size_t channels) {
    for (std::size_t row = 0; row < rows; ++row) for (std::size_t channel = firstChannel; channel < firstChannel + channels; ++channel) {
            const auto base = Nz * channel + Nz * storageChannels * row;
            data[base] = {};
            for (std::size_t z = 1; z + 1 < Nz; ++z) data[base + z] = multiply(data[base + z], 0.5);
            data[base + Nz - 1] = {};
    }
}

WVComplex64 storedValue(const WVComplex64* half, const WVHalfSpectrumMappings& mapping, std::size_t Nz, std::size_t channels, std::size_t field, std::size_t mode, std::size_t z) {
    auto value = half[z + Nz * field + Nz * channels * mapping.storageRowsByWVIndex[mode]];
    return mapping.conjugatesStoredValueByWVIndex[mode] ? conjugate(value) : value;
}

void storeWVValue(WVComplex64* half, const WVHalfSpectrumMappings& mapping, std::size_t Nz, std::size_t channels, std::size_t field, std::size_t mode, std::size_t z, WVComplex64 value) {
    half[z + Nz * field + Nz * channels * mapping.storageRowsByWVIndex[mode]] = mapping.conjugatesStoredValueByWVIndex[mode] ? conjugate(value) : value;
}

void completeHermitianBoundaries(WVComplex64* half, const WVHalfSpectrumMappings& mapping, std::size_t Nz, std::size_t channels) {
    for (std::size_t field = 0; field < channels; ++field) {
        for (std::size_t i = 0; i < mapping.hermitianCompletionRows.size(); ++i) for (std::size_t z = 0; z < Nz; ++z) half[z + Nz * field + Nz * channels * mapping.hermitianCompletionRows[i]] = conjugate(half[z + Nz * field + Nz * channels * mapping.hermitianSourceRows[i]]);
        for (const auto row : mapping.selfConjugateRows) for (std::size_t z = 0; z < Nz; ++z) half[z + Nz * field + Nz * channels * row].imag = 0.0;
    }
}

} // namespace

WVKernelStatus WVTransformConstantStratificationKernel::create(
    const WVTransformConstantStratificationConfiguration& configuration,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVTransformConstantStratificationKernel>& kernel) {
    if (!engine) return {WVKernelStatusCode::invalidPointer, "An FFT engine is required."};
    try {
        auto candidate = std::unique_ptr<WVTransformConstantStratificationKernel>(new WVTransformConstantStratificationKernel());
        auto status = WVTransformConstantStratificationDescriptor::create(configuration, candidate->descriptor_);
        if (!status) return status;
        candidate->engineIdentifier_ = engine->identifier();
        candidate->engineLibraryIdentity_ = engine->libraryIdentity();
        candidate->engine_ = std::move(engine);
        constexpr std::size_t halfChannels =
#if defined(WV_KERNEL_PAIRED_SCHEDULE)
            6;
#else
            4;
#endif
        const auto halfElements = checkedProduct(checkedProduct(candidate->descriptor_.halfSpectrumMappings().NxHalf, configuration.Ny), checkedProduct(configuration.Nz, halfChannels));
        const auto realElements = checkedProduct(candidate->descriptor_.spatialShape().elementCount(),
#if defined(WV_KERNEL_PAIRED_SCHEDULE)
            configuration.isHydrostatic ? 9 : 11);
#else
            configuration.isHydrostatic ? 8 : 9);
#endif
        candidate->halfSpectrumScratch_.resize(2 * halfElements);
        candidate->realScratch_.resize(realElements);
        candidate->metrics_.descriptorBytes = candidate->descriptor_.persistentBytes();
        candidate->metrics_.halfSpectrumScratchCapacityBytes = candidate->halfSpectrumScratch_.size() * sizeof(double);
        candidate->metrics_.realScratchCapacityBytes = candidate->realScratch_.size() * sizeof(double);
        candidate->metrics_.scratchCapacityBytes = candidate->scratchBytes();
        candidate->metrics_.scratchHighWaterBytes = candidate->scratchBytes();
        status = candidate->preparePlans();
        if (!status) return status;
        kernel = std::move(candidate);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure, "Unable to allocate the bounded kernel scratch arena."};
    } catch (const std::overflow_error& error) {
        return {WVKernelStatusCode::sizeOverflow, error.what()};
    }
}

WVKernelStatus WVTransformConstantStratificationKernel::preparePlans() {
    plans_.resize(planCount);
    const auto& c = descriptor_.configuration();
    const auto halfRows = (c.Nx / 2 + 1) * c.Ny;
    const WVFFTPlanSpecification specifications[] = {
        horizontalSpecification(c, 3, true), horizontalSpecification(c, 4, true), horizontalSpecification(c, 3, false), horizontalSpecification(c, 4, false),
        verticalSpecification(c,halfRows,3,2,false), verticalSpecification(c,halfRows,3,1,true), verticalSpecification(c,halfRows,3,2,true), verticalSpecification(c,halfRows,3,1,false),
#if defined(WV_KERNEL_PAIRED_SCHEDULE)
        horizontalSpecification(c,6,false), verticalSpecification(c,halfRows,6,4,false), verticalSpecification(c,halfRows,6,2,true), verticalSpecification(c,halfRows,6,4,true), verticalSpecification(c,halfRows,6,2,false),
#endif
        verticalSpecification(c,halfRows,4,2,false), verticalSpecification(c,halfRows,4,2,true),
        verticalSpecification(c,halfRows,4,3,false), verticalSpecification(c,halfRows,4,3,true),
        verticalSpecification(c,halfRows,4,1,false), verticalSpecification(c,halfRows,4,1,true)};
    for (std::size_t i = 0; i < planCount; ++i) {
        auto status = engine_->createPlan(specifications[i], plans_[i]);
        if (!status || !plans_[i]) return status ? WVKernelStatus{WVKernelStatusCode::fftPlanFailure, "FFT engine returned an empty plan."} : status;
        metrics_.planBytes += plans_[i]->persistentBytes();
    }
    metrics_.planCount = plans_.size();
    return WVKernelStatus::ok();
}

std::size_t WVTransformConstantStratificationKernel::persistentBytes() const noexcept {
    return descriptor_.persistentBytes() + metrics_.planBytes + scratchBytes();
}

const char* WVTransformConstantStratificationKernel::nonlinearFluxScheduleIdentifier() const noexcept {
#if defined(WV_KERNEL_PAIRED_SCHEDULE)
    return "paired";
#else
    return "sequential";
#endif
}

WVKernelStatus WVTransformConstantStratificationKernel::transformUVEtaToWaveVortex(
    const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients) {
    if (!descriptor_.configuration().isHydrostatic) return {WVKernelStatusCode::invalidConfiguration, "transformUVEtaToWaveVortex requires a hydrostatic kernel."};
    const auto status = validateBundle(fields, descriptor_.spatialShape(), 3, "Hydrostatic fields");
    if (!status) return status;
    const auto spectral = descriptor_.spectralShape();
    const WVKernelStatus outputStatuses[] = {validateSpectral(coefficients.Ap, spectral, "Ap"), validateSpectral(coefficients.Am, spectral, "Am"), validateSpectral(coefficients.A0, spectral, "A0")};
    for (const auto& value : outputStatuses) if (!value) return value;
    if (const auto ownership = validateForwardOwnership(fields,coefficients,spectral); !ownership) return ownership;
    ExecutionGuard guard(executing_);
    if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution, "Kernel operations are not reentrant."};
    return transformUVEtaToWaveVortexImpl(fields,t,t0,coefficients);
}

WVKernelStatus WVTransformConstantStratificationKernel::transformUVEtaToWaveVortexImpl(
    const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients) {
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    auto execute = plans_[horizontalForward3]->execute(fields.data, half);
    if (!execute) return execute;
    ++metrics_.executionCount; ++metrics_.horizontalExecutionCount;
    execute = plans_[verticalDCT2Storage3]->execute(half,half); if (!execute) return execute;
    execute = plans_[verticalDST1Storage3]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    normalizeForwardDCT(half,c.Nz,halfRows,3,0,2);
    normalizeForwardDST(half,c.Nz,halfRows,3,2,1);
    const double horizontalScale = 1.0 / static_cast<double>(c.Nx * c.Ny);

    for (std::size_t iMode = 0; iMode < descriptor_.Nkl(); ++iMode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * iMode;
        const auto U = multiply(storedValue(half,mapping,c.Nz,3,0,iMode,j),horizontalScale);
        const auto V = multiply(storedValue(half,mapping,c.Nz,3,1,iMode,j),horizontalScale);
        const auto N = multiply(storedValue(half,mapping,c.Nz,3,2,iMode,j),horizontalScale);
        const auto& horizontal = descriptor_.fourierModes()[iMode];
        const auto divergence = add(multiply(U, WVComplex64{0.0, horizontal.k}), multiply(V, WVComplex64{0.0, horizontal.l}));
        const auto vorticity = subtract(multiply(V, WVComplex64{0.0, horizontal.k}), multiply(U, WVComplex64{0.0, horizontal.l}));
        const auto nBar = multiply(N, 1.0 / modes.Gg[index]);
        const auto zetaBar = multiply(vorticity, 1.0 / modes.Fg[index]);
        const auto A0 = add(multiply(zetaBar, modes.A0Z[index]), multiply(nBar, modes.A0N[index]));
        const auto deltaBar = multiply(divergence, modes.h0[j] * modes.Gwg[index] / modes.Fg[index]);
        const auto nwBar = multiply(subtract(nBar, multiply(A0, modes.NA0[index])), modes.Gwg[index]);
        auto Ap = add(multiply(modes.ApmD[index], deltaBar), multiply(nwBar, modes.ApmN[index]));
        auto Am = subtract(multiply(modes.ApmD[index], deltaBar), multiply(nwBar, modes.ApmN[index]));
        if (iMode == 0) {
            const auto inertial = subtract(U, multiply(V, WVComplex64{0.0, 1.0}));
            Ap = multiply(inertial, 0.5 * modes.Fwg[index] / modes.Fg[index]);
            Am = conjugate(Ap);
        }
        const auto p = phase(modes.omega[index] * (t - t0));
        coefficients.Ap.data[index] = multiply(Ap, conjugate(p));
        coefficients.Am.data[index] = multiply(Am, p);
        coefficients.A0.data[index] = A0;
    }
    return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::transformUVWEtaToWaveVortex(
    const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients) {
    if (descriptor_.configuration().isHydrostatic) return {WVKernelStatusCode::invalidConfiguration, "transformUVWEtaToWaveVortex requires a nonhydrostatic kernel."};
    auto status = validateBundle(fields, descriptor_.spatialShape(), 4, "Nonhydrostatic fields");
    if (!status) return status;
    const auto spectral = descriptor_.spectralShape();
    const WVKernelStatus outputStatuses[] = {validateSpectral(coefficients.Ap, spectral, "Ap"), validateSpectral(coefficients.Am, spectral, "Am"), validateSpectral(coefficients.A0, spectral, "A0")};
    for (const auto& value : outputStatuses) if (!value) return value;
    if (const auto ownership = validateForwardOwnership(fields,coefficients,spectral); !ownership) return ownership;
    ExecutionGuard guard(executing_);
    if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution, "Kernel operations are not reentrant."};
    return transformUVWEtaToWaveVortexImpl(fields,t,t0,coefficients);
}

WVKernelStatus WVTransformConstantStratificationKernel::transformUVWEtaToWaveVortexImpl(
    const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients) {
    const auto& c = descriptor_.configuration(); const auto& mapping = descriptor_.halfSpectrumMappings(); const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    auto execute = plans_[horizontalForward4]->execute(fields.data, half); if (!execute) return execute;
    ++metrics_.executionCount; ++metrics_.horizontalExecutionCount;
    execute = plans_[verticalDCT2Storage4]->execute(half,half); if (!execute) return execute;
    execute = plans_[verticalDST2Storage4]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    normalizeForwardDCT(half,c.Nz,halfRows,4,0,2); normalizeForwardDST(half,c.Nz,halfRows,4,2,2);
    const double horizontalScale = 1.0 / static_cast<double>(c.Nx * c.Ny);
    for (std::size_t iMode = 0; iMode < descriptor_.Nkl(); ++iMode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * iMode;
        const auto U = multiply(storedValue(half,mapping,c.Nz,4,0,iMode,j),horizontalScale);
        const auto V = multiply(storedValue(half,mapping,c.Nz,4,1,iMode,j),horizontalScale);
        const auto W = multiply(storedValue(half,mapping,c.Nz,4,2,iMode,j),horizontalScale);
        const auto N = multiply(storedValue(half,mapping,c.Nz,4,3,iMode,j),horizontalScale);
        const auto& horizontal = descriptor_.fourierModes()[iMode]; const double Kh = std::hypot(horizontal.k, horizontal.l);
        const double cosAlpha = Kh == 0.0 ? 0.0 : horizontal.k / Kh; const double sinAlpha = Kh == 0.0 ? 0.0 : horizontal.l / Kh;
        const auto vorticity = subtract(multiply(V, WVComplex64{0.0, horizontal.k}), multiply(U, WVComplex64{0.0, horizontal.l}));
        const auto nBar = multiply(N, 1.0 / modes.Gg[index]); const auto zetaBar = multiply(vorticity, 1.0 / modes.Fg[index]);
        const auto A0 = add(multiply(zetaBar, modes.A0Z[index]), multiply(nBar, modes.A0N[index]));
        const auto nwBar = multiply(subtract(nBar, multiply(A0, modes.NA0[index])), modes.Gwg[index]);
        const auto delta = multiply(add(multiply(U, cosAlpha), multiply(V, sinAlpha)), modes.ApmDScaled[index]);
        const auto wBar = multiply(modes.ApmWScaled[index], W);
        auto Ap = add(add(delta, wBar), multiply(nwBar, modes.ApmN[index]));
        auto Am = subtract(add(delta, wBar), multiply(nwBar, modes.ApmN[index]));
        if (iMode == 0) { const auto inertial = subtract(U, multiply(V, WVComplex64{0.0, 1.0})); Ap = multiply(inertial, 0.5 * modes.Fwg[index] / modes.Fg[index]); Am = conjugate(Ap); }
        const auto p = phase(modes.omega[index] * (t - t0)); coefficients.Ap.data[index] = multiply(Ap, conjugate(p)); coefficients.Am.data[index] = multiply(Am, p); coefficients.A0.data[index] = A0;
    }
    return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::transformWaveVortexToUVWEta(const WVState& state, WVRealFieldBundleView& fields) {
    auto status = validateBundle(fields, descriptor_.spatialShape(), 4, "Reconstructed fields"); if (!status) return status;
    const auto spectral = descriptor_.spectralShape();
    const WVKernelStatus inputStatuses[] = {validateSpectral(state.coefficients.Ap, spectral, "Ap"), validateSpectral(state.coefficients.Am, spectral, "Am"), validateSpectral(state.coefficients.A0, spectral, "A0")};
    for (const auto& value : inputStatuses) if (!value) return value;
    if (const auto ownership = validateInverseOwnership(state,fields,spectral); !ownership) return ownership;
    ExecutionGuard guard(executing_); if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution, "Kernel operations are not reentrant."};
    return transformWaveVortexToUVWEtaImpl(state,fields);
}

WVKernelStatus WVTransformConstantStratificationKernel::transformWaveVortexToUVWEtaImpl(const WVState& state, WVRealFieldBundleView& fields) {
    const auto& c = descriptor_.configuration(); const auto& mapping = descriptor_.halfSpectrumMappings(); const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny; auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 4 * halfRows,WVComplex64{});
    for (std::size_t iMode = 0; iMode < descriptor_.Nkl(); ++iMode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * iMode; const auto p = phase(modes.omega[index] * (state.t - state.t0));
        const auto Ap = multiply(state.coefficients.Ap.data[index], p); const auto Am = multiply(state.coefficients.Am.data[index], conjugate(p)); const auto A0 = state.coefficients.A0.data[index];
        const auto UWave = add(multiply(modes.UAp[index],Ap),multiply(modes.UAm[index],Am));
        const auto VWave = add(multiply(modes.VAp[index],Ap),multiply(modes.VAm[index],Am));
        const auto WWave = add(multiply(modes.WAp[index],Ap),multiply(modes.WAm[index],Am));
        const auto NWave = add(multiply(Ap,modes.NAp[index]),multiply(Am,modes.NAm[index]));
        storeWVValue(half,mapping,c.Nz,4,0,iMode,j,multiply(add(multiply(UWave,1.0 / modes.Fwg[index]),multiply(modes.UA0[index],A0)),modes.Fg[index]));
        storeWVValue(half,mapping,c.Nz,4,1,iMode,j,multiply(add(multiply(VWave,1.0 / modes.Fwg[index]),multiply(modes.VA0[index],A0)),modes.Fg[index]));
        storeWVValue(half,mapping,c.Nz,4,2,iMode,j,multiply(WWave,modes.Gg[index] / modes.Gwg[index]));
        storeWVValue(half,mapping,c.Nz,4,3,iMode,j,multiply(add(multiply(NWave,1.0 / modes.Gwg[index]),multiply(A0,modes.NA0[index])),modes.Gg[index]));
    }
    completeHermitianBoundaries(half,mapping,c.Nz,4);
    auto execute = plans_[verticalDCT2Storage4]->execute(half,half); if (!execute) return execute;
    execute = plans_[verticalDST2Storage4]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    normalizeInverseDCT(half,c.Nz,halfRows,4,0,2); normalizeInverseDST(half,c.Nz,halfRows,4,2,2);
    execute = plans_[horizontalInverse4]->execute(half, fields.data); if (!execute) return execute;
    ++metrics_.executionCount; ++metrics_.horizontalExecutionCount;
    return WVKernelStatus::ok();
}

namespace {
WVKernelStatus transformAllDerivatives(WVTransformConstantStratificationKernel& kernel, bool cosine, const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields) {
    const auto spectral = kernel.descriptor().spectralShape();
    auto status = validateSpectral(Apm, spectral, "Apm"); if (!status) return status;
    status = validateSpectral(A0, spectral, "A0"); if (!status) return status;
    status = validateBundle(fields, kernel.descriptor().spatialShape(), 4, "Field derivatives"); if (!status) return status;
    status = validateDerivativeOwnership(Apm,A0,fields,spectral); if (!status) return status;
    // Implemented as a friendless helper through the public transform path is not possible; the member wrappers below contain the operation.
    return {WVKernelStatusCode::unsupportedOperation, cosine ? "internal F derivative dispatch" : "internal G derivative dispatch"};
}
} // namespace

WVKernelStatus WVTransformConstantStratificationKernel::transformToSpatialDomainWithFAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields) {
    auto initial = transformAllDerivatives(*this, true, Apm, A0, fields); if (initial.code != WVKernelStatusCode::unsupportedOperation) return initial;
    ExecutionGuard guard(executing_); if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution, "Kernel operations are not reentrant."};
    const auto& c = descriptor_.configuration(); const auto& mapping = descriptor_.halfSpectrumMappings(); const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny; auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 4 * halfRows,WVComplex64{});
    for (std::size_t mode = 0; mode < descriptor_.Nkl(); ++mode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * mode; const auto modal = add(multiply(Apm.data[index], 1.0 / modes.Fwg[index]), A0.data[index]);
        const auto value = multiply(modal,modes.Fg[index]); const auto& horizontal = descriptor_.fourierModes()[mode];
        storeWVValue(half,mapping,c.Nz,4,0,mode,j,value);
        storeWVValue(half,mapping,c.Nz,4,1,mode,j,multiply(value,WVComplex64{0.0,horizontal.k}));
        storeWVValue(half,mapping,c.Nz,4,2,mode,j,multiply(value,WVComplex64{0.0,horizontal.l}));
        storeWVValue(half,mapping,c.Nz,4,3,mode,j,multiply(value,-modes.j[j] * 3.14159265358979323846 / c.Lz));
    }
    completeHermitianBoundaries(half,mapping,c.Nz,4);
    auto execute = plans_[verticalDCT3Storage4]->execute(half,half); if (!execute) return execute;
    execute = plans_[verticalDST1Storage4]->execute(half + 3 * c.Nz + 1,half + 3 * c.Nz + 1); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    normalizeInverseDCT(half,c.Nz,halfRows,4,0,3); normalizeInverseDST(half,c.Nz,halfRows,4,3,1);
    execute = plans_[horizontalInverse4]->execute(half, fields.data); if (!execute) return execute; ++metrics_.executionCount; ++metrics_.horizontalExecutionCount; return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::transformToSpatialDomainWithGAllDerivatives(const WVComplexConstView& Apm, const WVComplexConstView& A0, WVRealFieldBundleView& fields) {
    auto initial = transformAllDerivatives(*this, false, Apm, A0, fields); if (initial.code != WVKernelStatusCode::unsupportedOperation) return initial;
    ExecutionGuard guard(executing_); if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution, "Kernel operations are not reentrant."};
    const auto& c = descriptor_.configuration(); const auto& mapping = descriptor_.halfSpectrumMappings(); const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny; auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 4 * halfRows,WVComplex64{});
    for (std::size_t mode = 0; mode < descriptor_.Nkl(); ++mode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * mode; const auto modal = add(multiply(Apm.data[index],1.0 / modes.Gwg[index]),A0.data[index]);
        const auto value = multiply(modal,modes.Gg[index]); const auto& horizontal = descriptor_.fourierModes()[mode];
        storeWVValue(half,mapping,c.Nz,4,0,mode,j,value);
        storeWVValue(half,mapping,c.Nz,4,1,mode,j,multiply(value,WVComplex64{0.0,horizontal.k}));
        storeWVValue(half,mapping,c.Nz,4,2,mode,j,multiply(value,WVComplex64{0.0,horizontal.l}));
        storeWVValue(half,mapping,c.Nz,4,3,mode,j,multiply(value,modes.j[j] * 3.14159265358979323846 / c.Lz));
    }
    completeHermitianBoundaries(half,mapping,c.Nz,4);
    auto execute = plans_[verticalDST3Storage4]->execute(half + 1,half + 1); if (!execute) return execute;
    execute = plans_[verticalDCT1Storage4]->execute(half + 3 * c.Nz,half + 3 * c.Nz); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    normalizeInverseDST(half,c.Nz,halfRows,4,0,3); normalizeInverseDCT(half,c.Nz,halfRows,4,3,1);
    execute = plans_[horizontalInverse4]->execute(half, fields.data); if (!execute) return execute; ++metrics_.executionCount; ++metrics_.horizontalExecutionCount; return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::transformToSpatialDomainWithDerivativesImpl(
    const WVState& state, std::size_t target, WVRealFieldBundleView& derivatives) {
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 3 * halfRows,WVComplex64{});
    const bool cosine = target < 2;
    for (std::size_t mode = 0; mode < descriptor_.Nkl(); ++mode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * mode;
        const auto p = phase(modes.omega[index] * (state.t - state.t0));
        const auto Ap = multiply(state.coefficients.Ap.data[index],p);
        const auto Am = multiply(state.coefficients.Am.data[index],conjugate(p));
        const auto A0 = state.coefficients.A0.data[index];
        const auto modal = modalValueForTarget(modes,index,target,Ap,Am,A0);
        const auto value = multiply(modal,cosine ? modes.Fg[index] : modes.Gg[index]);
        const auto& horizontal = descriptor_.fourierModes()[mode];
        storeWVValue(half,mapping,c.Nz,3,0,mode,j,multiply(value,WVComplex64{0.0,horizontal.k}));
        storeWVValue(half,mapping,c.Nz,3,1,mode,j,multiply(value,WVComplex64{0.0,horizontal.l}));
        const double verticalWavenumber = modes.j[j] * 3.14159265358979323846 / c.Lz;
        storeWVValue(half,mapping,c.Nz,3,2,mode,j,multiply(value,cosine ? -verticalWavenumber : verticalWavenumber));
    }
    completeHermitianBoundaries(half,mapping,c.Nz,3);
    WVKernelStatus execute;
    if (cosine) {
        execute = plans_[verticalDCT2Storage3]->execute(half,half); if (!execute) return execute;
        execute = plans_[verticalDST1Storage3]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
        normalizeInverseDCT(half,c.Nz,halfRows,3,0,2);
        normalizeInverseDST(half,c.Nz,halfRows,3,2,1);
    } else {
        execute = plans_[verticalDST2Storage3]->execute(half + 1,half + 1); if (!execute) return execute;
        execute = plans_[verticalDCT1Storage3]->execute(half + 2 * c.Nz,half + 2 * c.Nz); if (!execute) return execute;
        normalizeInverseDST(half,c.Nz,halfRows,3,0,2);
        normalizeInverseDCT(half,c.Nz,halfRows,3,2,1);
    }
    metrics_.executionCount += 2;
    metrics_.verticalExecutionCount += 2;
    execute = plans_[horizontalInverse3]->execute(half,derivatives.data); if (!execute) return execute;
    ++metrics_.executionCount;
    ++metrics_.horizontalExecutionCount;
    return WVKernelStatus::ok();
}

#if defined(WV_KERNEL_PAIRED_SCHEDULE)
WVKernelStatus WVTransformConstantStratificationKernel::transformToSpatialDomainWithPairedDerivativesImpl(
    const WVState& state, std::size_t firstTarget, std::size_t secondTarget, WVRealFieldBundleView& derivatives) {
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 6 * halfRows,WVComplex64{});
    const bool cosine = firstTarget < 2;
    for (std::size_t mode = 0; mode < descriptor_.Nkl(); ++mode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * mode;
        const auto p = phase(modes.omega[index] * (state.t - state.t0));
        const auto Ap = multiply(state.coefficients.Ap.data[index],p);
        const auto Am = multiply(state.coefficients.Am.data[index],conjugate(p));
        const auto A0 = state.coefficients.A0.data[index];
        const auto first = multiply(modalValueForTarget(modes,index,firstTarget,Ap,Am,A0),cosine ? modes.Fg[index] : modes.Gg[index]);
        const auto second = multiply(modalValueForTarget(modes,index,secondTarget,Ap,Am,A0),cosine ? modes.Fg[index] : modes.Gg[index]);
        const auto& horizontal = descriptor_.fourierModes()[mode];
        const double verticalWavenumber = modes.j[j] * 3.14159265358979323846 / c.Lz;
        storeWVValue(half,mapping,c.Nz,6,0,mode,j,multiply(first,WVComplex64{0.0,horizontal.k}));
        storeWVValue(half,mapping,c.Nz,6,1,mode,j,multiply(first,WVComplex64{0.0,horizontal.l}));
        storeWVValue(half,mapping,c.Nz,6,2,mode,j,multiply(second,WVComplex64{0.0,horizontal.k}));
        storeWVValue(half,mapping,c.Nz,6,3,mode,j,multiply(second,WVComplex64{0.0,horizontal.l}));
        storeWVValue(half,mapping,c.Nz,6,4,mode,j,multiply(first,cosine ? -verticalWavenumber : verticalWavenumber));
        storeWVValue(half,mapping,c.Nz,6,5,mode,j,multiply(second,cosine ? -verticalWavenumber : verticalWavenumber));
    }
    completeHermitianBoundaries(half,mapping,c.Nz,6);
    WVKernelStatus execute;
    if (cosine) {
        execute = plans_[verticalDCT4Storage6]->execute(half,half); if (!execute) return execute;
        execute = plans_[verticalDST2Storage6]->execute(half + 4 * c.Nz + 1,half + 4 * c.Nz + 1); if (!execute) return execute;
        normalizeInverseDCT(half,c.Nz,halfRows,6,0,4);
        normalizeInverseDST(half,c.Nz,halfRows,6,4,2);
    } else {
        execute = plans_[verticalDST4Storage6]->execute(half + 1,half + 1); if (!execute) return execute;
        execute = plans_[verticalDCT2Storage6]->execute(half + 4 * c.Nz,half + 4 * c.Nz); if (!execute) return execute;
        normalizeInverseDST(half,c.Nz,halfRows,6,0,4);
        normalizeInverseDCT(half,c.Nz,halfRows,6,4,2);
    }
    metrics_.executionCount += 2;
    metrics_.verticalExecutionCount += 2;
    execute = plans_[horizontalInverse6]->execute(half,derivatives.data); if (!execute) return execute;
    ++metrics_.executionCount;
    ++metrics_.horizontalExecutionCount;
    return WVKernelStatus::ok();
}
#endif

WVKernelStatus WVTransformConstantStratificationKernel::nonlinearFlux(const WVState& state, WVFlux& flux) {
    auto status = validateStateAndFlux(descriptor_,state,flux);
    if (!status) return status;
    ExecutionGuard guard(executing_);
    if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution,"Kernel operations are not reentrant."};

    const auto spatial = descriptor_.spatialShape();
    const auto fieldElements = spatial.elementCount();
    WVRealFieldBundleView advectingFields{realScratch_.data(),{spatial.first,spatial.second,spatial.third,4}};
    status = transformWaveVortexToUVWEtaImpl(state,advectingFields);
    if (!status) return status;

    const std::size_t targetCount = descriptor_.configuration().isHydrostatic ? 3 : 4;
#if defined(WV_KERNEL_PAIRED_SCHEDULE)
    WVRealFieldBundleView firstPair{realScratch_.data() + 3 * fieldElements,{spatial.first,spatial.second,spatial.third,6}};
    status = transformToSpatialDomainWithPairedDerivativesImpl(state,0,1,firstPair);
    if (!status) return status;
    const double* U = realScratch_.data(); const double* V = U + fieldElements; const double* W = V + fieldElements;
    for (std::size_t i = 0; i < fieldElements; ++i) {
        firstPair.data[i] = -(U[i] * firstPair.data[i] + V[i] * firstPair.data[i + fieldElements] + W[i] * firstPair.data[i + 4 * fieldElements]);
        firstPair.data[i + fieldElements] = -(U[i] * firstPair.data[i + 2 * fieldElements] + V[i] * firstPair.data[i + 3 * fieldElements] + W[i] * firstPair.data[i + 5 * fieldElements]);
    }
    if (descriptor_.configuration().isHydrostatic) {
        double* derivativeData = realScratch_.data() + 5 * fieldElements;
        WVRealFieldBundleView derivatives{derivativeData,{spatial.first,spatial.second,spatial.third,3}};
        status = transformToSpatialDomainWithDerivativesImpl(state,3,derivatives);
        if (!status) return status;
        for (std::size_t i = 0; i < fieldElements; ++i) derivativeData[i] = -(U[i] * derivativeData[i] + V[i] * derivativeData[i + fieldElements] + W[i] * derivativeData[i + 2 * fieldElements]);
    } else {
        WVRealFieldBundleView secondPair{realScratch_.data() + 5 * fieldElements,{spatial.first,spatial.second,spatial.third,6}};
        status = transformToSpatialDomainWithPairedDerivativesImpl(state,2,3,secondPair);
        if (!status) return status;
        for (std::size_t i = 0; i < fieldElements; ++i) {
            secondPair.data[i] = -(U[i] * secondPair.data[i] + V[i] * secondPair.data[i + fieldElements] + W[i] * secondPair.data[i + 4 * fieldElements]);
            secondPair.data[i + fieldElements] = -(U[i] * secondPair.data[i + 2 * fieldElements] + V[i] * secondPair.data[i + 3 * fieldElements] + W[i] * secondPair.data[i + 5 * fieldElements]);
        }
    }
#else
    const std::size_t hydrostaticTargets[] = {0,1,3};
    const std::size_t nonhydrostaticTargets[] = {0,1,2,3};
    const auto* targets = descriptor_.configuration().isHydrostatic ? hydrostaticTargets : nonhydrostaticTargets;
    for (std::size_t iTarget = 0; iTarget < targetCount; ++iTarget) {
        double* derivativeData = realScratch_.data() + (3 + iTarget) * fieldElements;
        WVRealFieldBundleView derivatives{derivativeData,{spatial.first,spatial.second,spatial.third,3}};
        status = transformToSpatialDomainWithDerivativesImpl(state,targets[iTarget],derivatives);
        if (!status) return status;
        const double* U = realScratch_.data();
        const double* V = U + fieldElements;
        const double* W = V + fieldElements;
        const double* dx = derivativeData;
        const double* dy = dx + fieldElements;
        const double* dz = dy + fieldElements;
        for (std::size_t i = 0; i < fieldElements; ++i) derivativeData[i] = -(U[i] * dx[i] + V[i] * dy[i] + W[i] * dz[i]);
    }
#endif

    const double* fluxFields = realScratch_.data() + 3 * fieldElements;
    const WVRealFieldBundleConstView fields{fluxFields,{spatial.first,spatial.second,spatial.third,targetCount}};
    WVMutableCoefficients coefficients{flux.Fp,flux.Fm,flux.F0};
    return descriptor_.configuration().isHydrostatic ? transformUVEtaToWaveVortexImpl(fields,state.t,state.t0,coefficients) : transformUVWEtaToWaveVortexImpl(fields,state.t,state.t0,coefficients);
}

} // namespace wavevortex
