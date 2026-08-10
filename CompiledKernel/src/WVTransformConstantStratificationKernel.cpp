#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>

namespace wavevortex {
namespace {

enum PlanIndex : std::size_t {
    horizontalForward3, horizontalForward4, horizontalInverse4,
    verticalDCT2Storage3, verticalDST1Storage3,
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
        const auto halfElements = checkedProduct(checkedProduct(candidate->descriptor_.halfSpectrumMappings().NxHalf, configuration.Ny), checkedProduct(configuration.Nz, 4));
        candidate->scratch_.resize(2 * halfElements);
        candidate->metrics_.descriptorBytes = candidate->descriptor_.persistentBytes();
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
        horizontalSpecification(c, 3, true), horizontalSpecification(c, 4, true), horizontalSpecification(c, 4, false),
        verticalSpecification(c,halfRows,3,2,false), verticalSpecification(c,halfRows,3,1,true),
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

WVKernelStatus WVTransformConstantStratificationKernel::transformUVEtaToWaveVortex(
    const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients) {
    if (!descriptor_.configuration().isHydrostatic) return {WVKernelStatusCode::invalidConfiguration, "transformUVEtaToWaveVortex requires a hydrostatic kernel."};
    // The shared implementation distinguishes the three-field layout through the descriptor.
    const auto status = validateBundle(fields, descriptor_.spatialShape(), 3, "Hydrostatic fields");
    if (!status) return status;
    // Forward implementation is shared below by temporarily dispatching through the four-field method's internal body.
    ExecutionGuard guard(executing_);
    if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution, "Kernel operations are not reentrant."};

    const auto spectral = descriptor_.spectralShape();
    const WVKernelStatus outputStatuses[] = {validateSpectral(coefficients.Ap, spectral, "Ap"), validateSpectral(coefficients.Am, spectral, "Am"), validateSpectral(coefficients.A0, spectral, "A0")};
    for (const auto& value : outputStatuses) if (!value) return value;
    if (const auto ownership = validateForwardOwnership(fields,coefficients,spectral); !ownership) return ownership;
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(scratch_.data());
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
    ExecutionGuard guard(executing_);
    if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution, "Kernel operations are not reentrant."};
    const auto spectral = descriptor_.spectralShape();
    const WVKernelStatus outputStatuses[] = {validateSpectral(coefficients.Ap, spectral, "Ap"), validateSpectral(coefficients.Am, spectral, "Am"), validateSpectral(coefficients.A0, spectral, "A0")};
    for (const auto& value : outputStatuses) if (!value) return value;
    if (const auto ownership = validateForwardOwnership(fields,coefficients,spectral); !ownership) return ownership;
    const auto& c = descriptor_.configuration(); const auto& mapping = descriptor_.halfSpectrumMappings(); const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(scratch_.data());
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
    const auto& c = descriptor_.configuration(); const auto& mapping = descriptor_.halfSpectrumMappings(); const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny; auto* half = reinterpret_cast<WVComplex64*>(scratch_.data());
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
    const std::size_t halfRows = mapping.NxHalf * c.Ny; auto* half = reinterpret_cast<WVComplex64*>(scratch_.data());
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
    const std::size_t halfRows = mapping.NxHalf * c.Ny; auto* half = reinterpret_cast<WVComplex64*>(scratch_.data());
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

} // namespace wavevortex
