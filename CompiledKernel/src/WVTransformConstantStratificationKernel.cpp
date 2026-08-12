#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <algorithm>
#include <cmath>
#include <chrono>
#include <limits>
#include <new>
#include <thread>
#include <stdexcept>

namespace wavevortex {
namespace {

#ifndef WV_KERNEL_COEFFICIENT_WORKERS
#define WV_KERNEL_COEFFICIENT_WORKERS 2
#endif

#if defined(WV_KERNEL_NATIVE_OPTIMIZATION) && WV_KERNEL_NATIVE_OPTIMIZATION && (defined(__clang__) || defined(__GNUC__))
#define WV_KERNEL_RESTRICT __restrict__
#else
#define WV_KERNEL_RESTRICT
#endif

template <typename Operation>
void forEachModeBlock(std::size_t modeCount, Operation&& operation) {
    constexpr std::size_t requestedWorkers = WV_KERNEL_COEFFICIENT_WORKERS;
    const std::size_t workerCount = std::min(requestedWorkers,modeCount);
    if (workerCount <= 1) {
        operation(0,modeCount);
        return;
    }
    std::vector<std::thread> workers;
    workers.reserve(workerCount - 1);
    const std::size_t blockSize = (modeCount + workerCount - 1) / workerCount;
    for (std::size_t worker = 1; worker < workerCount; ++worker) {
        const std::size_t begin = std::min(worker * blockSize,modeCount);
        const std::size_t end = std::min(begin + blockSize,modeCount);
        workers.emplace_back([begin,end,&operation]() { operation(begin,end); });
    }
    operation(0,std::min(blockSize,modeCount));
    for (auto& worker : workers) worker.join();
}

enum PlanIndex : std::size_t {
    horizontalForward3, horizontalForward4, horizontalInverse3, horizontalInverse4,
    verticalDCT2Storage3, verticalDST1Storage3, verticalDST2Storage3, verticalDCT1Storage3,
    verticalDCT2Storage4, verticalDST2Storage4,
    verticalDCT3Storage4, verticalDST3Storage4,
    verticalDCT1Storage4, verticalDST1Storage4,
    horizontalForward1, verticalDCT1Storage1, verticalDST1Storage1,
    planCount
};

WVComplex64 add(WVComplex64 a, WVComplex64 b) { return {a.real + b.real, a.imag + b.imag}; }
WVComplex64 subtract(WVComplex64 a, WVComplex64 b) { return {a.real - b.real, a.imag - b.imag}; }
WVComplex64 multiply(WVComplex64 a, WVComplex64 b) { return {a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real}; }
WVComplex64 multiply(WVComplex64 a, double b) { return {a.real * b, a.imag * b}; }
WVComplex64 conjugate(WVComplex64 a) { return {a.real, -a.imag}; }
WVComplex64 phase(double angle) { return {std::cos(angle), std::sin(angle)}; }

template <std::size_t Target>
WVComplex64 coefficientValueForField(const WVConstantStratificationModes& modes, std::size_t index, WVComplex64 Ap, WVComplex64 Am, WVComplex64 A0) {
    if constexpr (Target == 0) return add(add(multiply(modes.UApField[index],Ap),multiply(conjugate(modes.UApField[index]),Am)),multiply(modes.UA0Field[index],A0));
    if constexpr (Target == 1) return add(add(multiply(modes.VApField[index],Ap),multiply(conjugate(modes.VApField[index]),Am)),multiply(modes.VA0Field[index],A0));
    if constexpr (Target == 2) return add(multiply(modes.WApField[index],Ap),multiply(modes.WApField[index],Am));
    return add(add(multiply(Ap,modes.NApField[index]),multiply(Am,-modes.NApField[index])),multiply(A0,modes.NA0Field[index]));
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

struct EvolvedWaveVortexCoefficients {
    WVComplex64 Ap;
    WVComplex64 Am;
    WVComplex64 A0;
};

template <bool Conjugated, typename CoefficientSource>
void assembleFieldSpectraForMode(
    WVComplex64* half,
    const WVHalfSpectrumMappings& mapping,
    const WVConstantStratificationModes& modes,
    std::size_t Nz,
    std::size_t Nj,
    std::size_t mode,
    CoefficientSource&& source) {
    const auto storageRow = mapping.storageRowsByWVIndex[mode];
    for (std::size_t j = 0; j < Nj; ++j) {
        const auto index = j + Nj * mode;
        const auto coefficients = source(index);
        WVComplex64 values[] = {
            coefficientValueForField<0>(modes,index,coefficients.Ap,coefficients.Am,coefficients.A0),
            coefficientValueForField<1>(modes,index,coefficients.Ap,coefficients.Am,coefficients.A0),
            coefficientValueForField<2>(modes,index,coefficients.Ap,coefficients.Am,coefficients.A0),
            coefficientValueForField<3>(modes,index,coefficients.Ap,coefficients.Am,coefficients.A0)};
        for (std::size_t target = 0; target < 4; ++target) {
            // FFTW's DCT-I/DST-I inverse is unnormalized. By linearity, applying
            // the required factor here avoids rewriting the complete dense
            // half spectrum after the vertical transforms.
            values[target] = target >= 2 && (j == 0 || j + 1 == Nz) ? WVComplex64{} : multiply(values[target],0.5);
            half[j + Nz * target + Nz * 4 * storageRow] = Conjugated ? conjugate(values[target]) : values[target];
        }
    }
}

template <std::size_t Target, bool Conjugated>
void assembleDerivativeSpectraForMode(
    WVComplex64* half,
    const WVHalfSpectrumMappings& mapping,
    const WVConstantStratificationModes& modes,
    const std::vector<WVFourierMode>& horizontalModes,
    const WVCoefficients& coefficients,
    std::size_t Nz,
    std::size_t Nj,
    std::size_t mode) {
    const auto storageRow = mapping.storageRowsByWVIndex[mode];
    const auto& horizontal = horizontalModes[mode];
    constexpr bool cosine = Target < 2;
    for (std::size_t j = 0; j < Nj; ++j) {
        const auto index = j + Nj * mode;
        auto value = coefficientValueForField<Target>(modes,index,coefficients.Ap.data[index],coefficients.Am.data[index],coefficients.A0.data[index]);
        if constexpr (Conjugated) value = conjugate(value);
        auto x = multiply(value,WVComplex64{0.0,Conjugated ? -horizontal.k : horizontal.k});
        auto y = multiply(value,WVComplex64{0.0,Conjugated ? -horizontal.l : horizontal.l});
        auto z = multiply(value,cosine ? -modes.verticalWavenumber[j] : modes.verticalWavenumber[j]);
        if constexpr (cosine) {
            x = multiply(x,0.5); y = multiply(y,0.5);
            z = j == 0 || j + 1 == Nz ? WVComplex64{} : multiply(z,0.5);
        } else {
            x = j == 0 || j + 1 == Nz ? WVComplex64{} : multiply(x,0.5);
            y = j == 0 || j + 1 == Nz ? WVComplex64{} : multiply(y,0.5);
            z = multiply(z,0.5);
        }
        half[j + Nz * 0 + Nz * 3 * storageRow] = x;
        half[j + Nz * 1 + Nz * 3 * storageRow] = y;
        half[j + Nz * 2 + Nz * 3 * storageRow] = z;
    }
}

template <bool Conjugated, typename CoefficientSource>
void assembleVelocitySpectraForMode(
    WVComplex64* half,
    const WVHalfSpectrumMappings& mapping,
    const WVConstantStratificationModes& modes,
    std::size_t Nz,
    std::size_t Nj,
    std::size_t mode,
    CoefficientSource&& source) {
    const auto storageRow = mapping.storageRowsByWVIndex[mode];
    for (std::size_t j = 0; j < Nj; ++j) {
        const auto index = j + Nj * mode;
        const auto coefficients = source(index);
        WVComplex64 values[] = {
            coefficientValueForField<0>(modes,index,coefficients.Ap,coefficients.Am,coefficients.A0),
            coefficientValueForField<1>(modes,index,coefficients.Ap,coefficients.Am,coefficients.A0),
            coefficientValueForField<2>(modes,index,coefficients.Ap,coefficients.Am,coefficients.A0)};
        values[0] = multiply(values[0],0.5);
        values[1] = multiply(values[1],0.5);
        values[2] = j == 0 || j + 1 == Nz ? WVComplex64{} : multiply(values[2],0.5);
        for (std::size_t target = 0; target < 3; ++target) half[j + Nz * target + Nz * 3 * storageRow] = Conjugated ? conjugate(values[target]) : values[target];
    }
}

template <std::size_t Target, bool Conjugated>
void assembleDerivativeSpectraForModeFromState(
    WVComplex64* half,
    const WVHalfSpectrumMappings& mapping,
    const WVConstantStratificationModes& modes,
    const std::vector<WVFourierMode>& horizontalModes,
    const WVState& state,
    WVComplexConstView phaseValues,
    std::size_t Nz,
    std::size_t Nj,
    std::size_t mode) {
    const auto storageRow = mapping.storageRowsByWVIndex[mode];
    const auto& horizontal = horizontalModes[mode];
    constexpr bool cosine = Target < 2;
    for (std::size_t j = 0; j < Nj; ++j) {
        const auto index = j + Nj * mode;
        const auto p = phaseValues.data[index];
        const auto Ap = multiply(state.coefficients.Ap.data[index],p);
        const auto Am = multiply(state.coefficients.Am.data[index],conjugate(p));
        auto value = coefficientValueForField<Target>(modes,index,Ap,Am,state.coefficients.A0.data[index]);
        if constexpr (Conjugated) value = conjugate(value);
        auto x = multiply(value,WVComplex64{0.0,Conjugated ? -horizontal.k : horizontal.k});
        auto y = multiply(value,WVComplex64{0.0,Conjugated ? -horizontal.l : horizontal.l});
        auto z = multiply(value,cosine ? -modes.verticalWavenumber[j] : modes.verticalWavenumber[j]);
        if constexpr (cosine) {
            x = multiply(x,0.5); y = multiply(y,0.5);
            z = j == 0 || j + 1 == Nz ? WVComplex64{} : multiply(z,0.5);
        } else {
            x = j == 0 || j + 1 == Nz ? WVComplex64{} : multiply(x,0.5);
            y = j == 0 || j + 1 == Nz ? WVComplex64{} : multiply(y,0.5);
            z = multiply(z,0.5);
        }
        half[j + Nz * 0 + Nz * 3 * storageRow] = x;
        half[j + Nz * 1 + Nz * 3 * storageRow] = y;
        half[j + Nz * 2 + Nz * 3 * storageRow] = z;
    }
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
        constexpr std::size_t halfChannels = 4;
        const auto halfElements = checkedProduct(checkedProduct(candidate->descriptor_.halfSpectrumMappings().NxHalf, configuration.Ny), checkedProduct(configuration.Nz, halfChannels));
        const auto halfFieldElements = checkedProduct(checkedProduct(candidate->descriptor_.halfSpectrumMappings().NxHalf,configuration.Ny),configuration.Nz);
        if (candidate->descriptor_.spectralShape().elementCount() > halfFieldElements) return {WVKernelStatusCode::invalidShape,"The streamed phase reservation requires M <= H."};
        constexpr std::size_t realChannels = 6;
        const auto realElements = checkedProduct(candidate->descriptor_.spatialShape().elementCount(),realChannels);
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
        verticalSpecification(c,halfRows,4,2,false), verticalSpecification(c,halfRows,4,2,true),
        verticalSpecification(c,halfRows,4,3,false), verticalSpecification(c,halfRows,4,3,true),
        verticalSpecification(c,halfRows,4,1,false), verticalSpecification(c,halfRows,4,1,true)
        ,horizontalSpecification(c,1,true), verticalSpecification(c,halfRows,1,1,false), verticalSpecification(c,halfRows,1,1,true)
    };
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
    return "streamed-target-three-channel";
}

const char* WVTransformConstantStratificationKernel::phaseImplementationIdentifier() const noexcept {
    return "scalar-sincos";
}

const char* WVTransformConstantStratificationKernel::coefficientArithmeticModeIdentifier() const noexcept {
    return "natural-dimensional-prescaled";
}

const char* WVTransformConstantStratificationKernel::inverseNormalizationPlacementIdentifier() const noexcept {
    return "coefficient-production";
}

const char* WVTransformConstantStratificationKernel::optimizationImplementationIdentifier() const noexcept {
#if defined(WV_KERNEL_NATIVE_OPTIMIZATION) && WV_KERNEL_NATIVE_OPTIMIZATION
    return "O3-native";
#else
    return "portable";
#endif
}

std::size_t WVTransformConstantStratificationKernel::coefficientWorkerCount() const noexcept { return WV_KERNEL_COEFFICIENT_WORKERS; }

std::size_t WVTransformConstantStratificationKernel::phaseReservationBytes() const noexcept {
    const auto& c = descriptor_.configuration();
    return descriptor_.halfSpectrumMappings().NxHalf * c.Ny * c.Nz * sizeof(WVComplex64);
}

void WVTransformConstantStratificationKernel::setStageInstrumentation(bool enabled) noexcept {
    stageInstrumentationEnabled_ = enabled;
    if (!enabled) return;
    metrics_.phaseSeconds = 0.0;
    metrics_.reconstructionSeconds = 0.0;
    metrics_.derivativeReconstructionSeconds = 0.0;
    metrics_.productSeconds = 0.0;
    metrics_.projectionSeconds = 0.0;
    metrics_.coefficientAssemblySeconds = 0.0;
    metrics_.derivativeCoefficientAssemblySeconds = 0.0;
    metrics_.coefficientProjectionSeconds = 0.0;
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
    const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients, WVComplexConstView phaseValues) {
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
    auto* WV_KERNEL_RESTRICT outputAp=coefficients.Ap.data; auto* WV_KERNEL_RESTRICT outputAm=coefficients.Am.data; auto* outputA0=coefficients.A0.data;

    const auto coefficientProjectionStart = std::chrono::steady_clock::now();
    forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) { for (std::size_t iMode = begin; iMode < end; ++iMode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * iMode;
        const auto U = multiply(storedValue(half,mapping,c.Nz,3,0,iMode,j),horizontalScale);
        const auto V = multiply(storedValue(half,mapping,c.Nz,3,1,iMode,j),horizontalScale);
        const auto N = multiply(storedValue(half,mapping,c.Nz,3,2,iMode,j),horizontalScale);
        const auto& horizontal = descriptor_.fourierModes()[iMode];
        const auto divergence = add(multiply(U, WVComplex64{0.0, horizontal.k}), multiply(V, WVComplex64{0.0, horizontal.l}));
        const auto vorticity = subtract(multiply(V, WVComplex64{0.0, horizontal.k}), multiply(U, WVComplex64{0.0, horizontal.l}));
        const auto A0 = add(multiply(vorticity, modes.A0FromVorticity[index]), multiply(N, modes.A0FromBuoyancy[index]));
        const auto deltaContribution = multiply(modes.ApmDProjection[index],divergence);
        const auto buoyancyContribution = multiply(subtract(N,multiply(A0,modes.NA0Field[index])),modes.ApmNProjection[index]);
        auto Ap = add(deltaContribution,buoyancyContribution);
        auto Am = subtract(deltaContribution,buoyancyContribution);
        if (iMode == 0) {
            const auto inertial = subtract(U, multiply(V, WVComplex64{0.0, 1.0}));
            Ap = multiply(inertial,modes.inertialScale[j]);
            Am = conjugate(Ap);
        }
        const auto p = phaseValues.data == nullptr ? phase(modes.omega[index] * (t - t0)) : phaseValues.data[index];
        outputAp[index] = multiply(Ap, conjugate(p));
        outputAm[index] = multiply(Am, p);
        outputA0[index] = A0;
    }});
    if (stageInstrumentationEnabled_) metrics_.coefficientProjectionSeconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientProjectionStart).count();
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
    const WVRealFieldBundleConstView& fields, double t, double t0, WVMutableCoefficients& coefficients, WVComplexConstView phaseValues) {
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
    auto* WV_KERNEL_RESTRICT outputAp=coefficients.Ap.data; auto* WV_KERNEL_RESTRICT outputAm=coefficients.Am.data; auto* outputA0=coefficients.A0.data;
    const auto coefficientProjectionStart = std::chrono::steady_clock::now();
    forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) { for (std::size_t iMode = begin; iMode < end; ++iMode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * iMode;
        const auto U = multiply(storedValue(half,mapping,c.Nz,4,0,iMode,j),horizontalScale);
        const auto V = multiply(storedValue(half,mapping,c.Nz,4,1,iMode,j),horizontalScale);
        const auto W = multiply(storedValue(half,mapping,c.Nz,4,2,iMode,j),horizontalScale);
        const auto N = multiply(storedValue(half,mapping,c.Nz,4,3,iMode,j),horizontalScale);
        const auto& horizontal = descriptor_.fourierModes()[iMode];
        const auto vorticity = subtract(multiply(V, WVComplex64{0.0, horizontal.k}), multiply(U, WVComplex64{0.0, horizontal.l}));
        const auto A0 = add(multiply(vorticity,modes.A0FromVorticity[index]),multiply(N,modes.A0FromBuoyancy[index]));
        const auto delta = multiply(add(multiply(U,horizontal.cosAlpha),multiply(V,horizontal.sinAlpha)),modes.ApmDScaled[index]);
        const auto wBar = multiply(WVComplex64{0.0, (horizontal.Kh / 2.0) * modes.apmWProjectionPrefactor[j]}, W);
        const auto buoyancyContribution = multiply(subtract(N,multiply(A0,modes.NA0Field[index])),modes.ApmNProjection[index]);
        auto Ap = add(add(delta,wBar),buoyancyContribution);
        auto Am = subtract(add(delta,wBar),buoyancyContribution);
        if (iMode == 0) {
            const auto inertial = subtract(U, multiply(V, WVComplex64{0.0, 1.0}));
            Ap = multiply(inertial,modes.inertialScale[j]);
            Am = conjugate(Ap);
        }
        const auto p = phaseValues.data == nullptr ? phase(modes.omega[index] * (t - t0)) : phaseValues.data[index]; outputAp[index] = multiply(Ap, conjugate(p)); outputAm[index] = multiply(Am, p); outputA0[index] = A0;
    }});
    if (stageInstrumentationEnabled_) metrics_.coefficientProjectionSeconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientProjectionStart).count();
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

WVKernelStatus WVTransformConstantStratificationKernel::transformWaveVortexToUVWEtaImpl(const WVState& state, WVRealFieldBundleView& fields, const WVCoefficients* evolvedCoefficients) {
    const auto& c = descriptor_.configuration(); const auto& mapping = descriptor_.halfSpectrumMappings(); const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny; auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 4 * halfRows,WVComplex64{});
    const auto coefficientAssemblyStart = std::chrono::steady_clock::now();
    forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) {
        for (std::size_t iMode = begin; iMode < end; ++iMode) {
        if (evolvedCoefficients == nullptr) {
            auto source = [&](std::size_t index) {
                const auto p = phase(modes.omega[index] * (state.t - state.t0));
                return EvolvedWaveVortexCoefficients{
                    multiply(state.coefficients.Ap.data[index],p),
                    multiply(state.coefficients.Am.data[index],conjugate(p)),
                    state.coefficients.A0.data[index]};
            };
            if (mapping.conjugatesStoredValueByWVIndex[iMode]) assembleFieldSpectraForMode<true>(half,mapping,modes,c.Nz,c.Nj,iMode,source);
            else assembleFieldSpectraForMode<false>(half,mapping,modes,c.Nz,c.Nj,iMode,source);
        } else {
            auto source = [&](std::size_t index) {
                return EvolvedWaveVortexCoefficients{
                    evolvedCoefficients->Ap.data[index],
                    evolvedCoefficients->Am.data[index],
                    evolvedCoefficients->A0.data[index]};
            };
            if (mapping.conjugatesStoredValueByWVIndex[iMode]) assembleFieldSpectraForMode<true>(half,mapping,modes,c.Nz,c.Nj,iMode,source);
            else assembleFieldSpectraForMode<false>(half,mapping,modes,c.Nz,c.Nj,iMode,source);
        }
        }
    });
    if (stageInstrumentationEnabled_) metrics_.coefficientAssemblySeconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientAssemblyStart).count();
    completeHermitianBoundaries(half,mapping,c.Nz,4);
    auto execute = plans_[verticalDCT2Storage4]->execute(half,half); if (!execute) return execute;
    execute = plans_[verticalDST2Storage4]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    execute = plans_[horizontalInverse4]->execute(half, fields.data); if (!execute) return execute;
    ++metrics_.executionCount; ++metrics_.horizontalExecutionCount;
    return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::transformWaveVortexToUVWImpl(
    const WVState& state, WVRealFieldBundleView& fields, const WVCoefficients* evolvedCoefficients, WVComplexConstView phaseValues) {
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 3 * halfRows,WVComplex64{});
    const auto coefficientAssemblyStart = std::chrono::steady_clock::now();
    forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) {
        for (std::size_t iMode = begin; iMode < end; ++iMode) {
            auto source = [&](std::size_t index) {
                if (evolvedCoefficients != nullptr) return EvolvedWaveVortexCoefficients{evolvedCoefficients->Ap.data[index],evolvedCoefficients->Am.data[index],evolvedCoefficients->A0.data[index]};
                const auto p = phaseValues.data[index];
                return EvolvedWaveVortexCoefficients{multiply(state.coefficients.Ap.data[index],p),multiply(state.coefficients.Am.data[index],conjugate(p)),state.coefficients.A0.data[index]};
            };
            if (mapping.conjugatesStoredValueByWVIndex[iMode]) assembleVelocitySpectraForMode<true>(half,mapping,modes,c.Nz,c.Nj,iMode,source);
            else assembleVelocitySpectraForMode<false>(half,mapping,modes,c.Nz,c.Nj,iMode,source);
        }
    });
    if (stageInstrumentationEnabled_) metrics_.coefficientAssemblySeconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientAssemblyStart).count();
    completeHermitianBoundaries(half,mapping,c.Nz,3);
    auto execute = plans_[verticalDCT2Storage3]->execute(half,half); if (!execute) return execute;
    execute = plans_[verticalDST1Storage3]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    execute = plans_[horizontalInverse3]->execute(half,fields.data); if (!execute) return execute;
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
    const auto coefficientAssemblyStart = std::chrono::steady_clock::now();
    forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) { for (std::size_t mode = begin; mode < end; ++mode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * mode;
        const auto value = add(multiply(Apm.data[index],modes.fWaveScale[index]),multiply(A0.data[index],modes.Fg[j]));
        const auto& horizontal = descriptor_.fourierModes()[mode];
        storeWVValue(half,mapping,c.Nz,4,0,mode,j,value);
        storeWVValue(half,mapping,c.Nz,4,1,mode,j,multiply(value,WVComplex64{0.0,horizontal.k}));
        storeWVValue(half,mapping,c.Nz,4,2,mode,j,multiply(value,WVComplex64{0.0,horizontal.l}));
        storeWVValue(half,mapping,c.Nz,4,3,mode,j,multiply(value,-modes.verticalWavenumber[j]));
    }});
    if (stageInstrumentationEnabled_) metrics_.derivativeCoefficientAssemblySeconds += std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientAssemblyStart).count();
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
    const auto coefficientAssemblyStart = std::chrono::steady_clock::now();
    forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) { for (std::size_t mode = begin; mode < end; ++mode) for (std::size_t j = 0; j < c.Nj; ++j) {
        const auto index = j + c.Nj * mode;
        const auto value = add(multiply(Apm.data[index],modes.gWaveScale[j]),multiply(A0.data[index],modes.Gg[j]));
        const auto& horizontal = descriptor_.fourierModes()[mode];
        storeWVValue(half,mapping,c.Nz,4,0,mode,j,value);
        storeWVValue(half,mapping,c.Nz,4,1,mode,j,multiply(value,WVComplex64{0.0,horizontal.k}));
        storeWVValue(half,mapping,c.Nz,4,2,mode,j,multiply(value,WVComplex64{0.0,horizontal.l}));
        storeWVValue(half,mapping,c.Nz,4,3,mode,j,multiply(value,modes.verticalWavenumber[j]));
    }});
    if (stageInstrumentationEnabled_) metrics_.derivativeCoefficientAssemblySeconds += std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientAssemblyStart).count();
    completeHermitianBoundaries(half,mapping,c.Nz,4);
    auto execute = plans_[verticalDST3Storage4]->execute(half + 1,half + 1); if (!execute) return execute;
    execute = plans_[verticalDCT1Storage4]->execute(half + 3 * c.Nz,half + 3 * c.Nz); if (!execute) return execute;
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    normalizeInverseDST(half,c.Nz,halfRows,4,0,3); normalizeInverseDCT(half,c.Nz,halfRows,4,3,1);
    execute = plans_[horizontalInverse4]->execute(half, fields.data); if (!execute) return execute; ++metrics_.executionCount; ++metrics_.horizontalExecutionCount; return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::transformToSpatialDomainWithDerivativesImpl(
    const WVCoefficients& evolvedCoefficients, std::size_t target, WVRealFieldBundleView& derivatives) {
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 3 * halfRows,WVComplex64{});
    const bool cosine = target < 2;
    const auto coefficientAssemblyStart = std::chrono::steady_clock::now();
    auto assembleTarget = [&](auto targetConstant) {
        constexpr std::size_t resolvedTarget = decltype(targetConstant)::value;
        forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) {
            for (std::size_t mode = begin; mode < end; ++mode) {
                if (mapping.conjugatesStoredValueByWVIndex[mode]) assembleDerivativeSpectraForMode<resolvedTarget,true>(half,mapping,modes,descriptor_.fourierModes(),evolvedCoefficients,c.Nz,c.Nj,mode);
                else assembleDerivativeSpectraForMode<resolvedTarget,false>(half,mapping,modes,descriptor_.fourierModes(),evolvedCoefficients,c.Nz,c.Nj,mode);
            }
        });
    };
    if (target == 0) assembleTarget(std::integral_constant<std::size_t,0>{});
    else if (target == 1) assembleTarget(std::integral_constant<std::size_t,1>{});
    else if (target == 2) assembleTarget(std::integral_constant<std::size_t,2>{});
    else assembleTarget(std::integral_constant<std::size_t,3>{});
    if (stageInstrumentationEnabled_) metrics_.derivativeCoefficientAssemblySeconds += std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientAssemblyStart).count();
    completeHermitianBoundaries(half,mapping,c.Nz,3);
    WVKernelStatus execute;
    if (cosine) {
        execute = plans_[verticalDCT2Storage3]->execute(half,half); if (!execute) return execute;
        execute = plans_[verticalDST1Storage3]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
    } else {
        execute = plans_[verticalDST2Storage3]->execute(half + 1,half + 1); if (!execute) return execute;
        execute = plans_[verticalDCT1Storage3]->execute(half + 2 * c.Nz,half + 2 * c.Nz); if (!execute) return execute;
    }
    metrics_.executionCount += 2;
    metrics_.verticalExecutionCount += 2;
    execute = plans_[horizontalInverse3]->execute(half,derivatives.data); if (!execute) return execute;
    ++metrics_.executionCount;
    ++metrics_.horizontalExecutionCount;
    return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::transformToSpatialDomainWithDerivativesFromStateImpl(
    const WVState& state, WVComplexConstView phaseValues, std::size_t target, WVRealFieldBundleView& derivatives) {
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    std::fill(half,half + c.Nz * 3 * halfRows,WVComplex64{});
    const bool cosine = target < 2;
    const auto coefficientAssemblyStart = std::chrono::steady_clock::now();
    auto assembleTarget = [&](auto targetConstant) {
        constexpr std::size_t resolvedTarget = decltype(targetConstant)::value;
        forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) {
            for (std::size_t mode = begin; mode < end; ++mode) {
                if (mapping.conjugatesStoredValueByWVIndex[mode]) assembleDerivativeSpectraForModeFromState<resolvedTarget,true>(half,mapping,modes,descriptor_.fourierModes(),state,phaseValues,c.Nz,c.Nj,mode);
                else assembleDerivativeSpectraForModeFromState<resolvedTarget,false>(half,mapping,modes,descriptor_.fourierModes(),state,phaseValues,c.Nz,c.Nj,mode);
            }
        });
    };
    if (target == 0) assembleTarget(std::integral_constant<std::size_t,0>{});
    else if (target == 1) assembleTarget(std::integral_constant<std::size_t,1>{});
    else if (target == 2) assembleTarget(std::integral_constant<std::size_t,2>{});
    else assembleTarget(std::integral_constant<std::size_t,3>{});
    if (stageInstrumentationEnabled_) metrics_.derivativeCoefficientAssemblySeconds += std::chrono::duration<double>(std::chrono::steady_clock::now() - coefficientAssemblyStart).count();
    completeHermitianBoundaries(half,mapping,c.Nz,3);
    WVKernelStatus execute;
    if (cosine) {
        execute = plans_[verticalDCT2Storage3]->execute(half,half); if (!execute) return execute;
        execute = plans_[verticalDST1Storage3]->execute(half + 2 * c.Nz + 1,half + 2 * c.Nz + 1); if (!execute) return execute;
    } else {
        execute = plans_[verticalDST2Storage3]->execute(half + 1,half + 1); if (!execute) return execute;
        execute = plans_[verticalDCT1Storage3]->execute(half + 2 * c.Nz,half + 2 * c.Nz); if (!execute) return execute;
    }
    metrics_.executionCount += 2; metrics_.verticalExecutionCount += 2;
    execute = plans_[horizontalInverse3]->execute(half,derivatives.data); if (!execute) return execute;
    ++metrics_.executionCount; ++metrics_.horizontalExecutionCount;
    return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::projectSingleFluxTargetImpl(
    const WVRealFieldBundleConstView& field, std::size_t target, WVComplexConstView phaseValues, WVFlux& flux) {
    const auto& c = descriptor_.configuration();
    const auto& mapping = descriptor_.halfSpectrumMappings();
    const auto& modes = descriptor_.verticalModes();
    const std::size_t halfRows = mapping.NxHalf * c.Ny;
    auto* half = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data());
    auto execute = plans_[horizontalForward1]->execute(field.data,half); if (!execute) return execute;
    ++metrics_.executionCount; ++metrics_.horizontalExecutionCount;
    if (target < 2) {
        execute = plans_[verticalDCT1Storage1]->execute(half,half); if (!execute) return execute;
        normalizeForwardDCT(half,c.Nz,halfRows,1,0,1);
    } else {
        execute = plans_[verticalDST1Storage1]->execute(half + 1,half + 1); if (!execute) return execute;
        normalizeForwardDST(half,c.Nz,halfRows,1,0,1);
    }
    ++metrics_.executionCount; ++metrics_.verticalExecutionCount;
    const double horizontalScale = 1.0 / static_cast<double>(c.Nx * c.Ny);
    forEachModeBlock(descriptor_.Nkl(),[&](std::size_t begin, std::size_t end) {
        for (std::size_t iMode = begin; iMode < end; ++iMode) for (std::size_t j = 0; j < c.Nj; ++j) {
            const auto index = j + c.Nj * iMode;
            const auto value = multiply(storedValue(half,mapping,c.Nz,1,0,iMode,j),horizontalScale);
            const auto& horizontal = descriptor_.fourierModes()[iMode];
            WVComplex64 A0Contribution{};
            if (target == 0) A0Contribution = multiply(multiply(value,WVComplex64{0.0,-horizontal.l}),modes.A0FromVorticity[index]);
            else if (target == 1) A0Contribution = multiply(multiply(value,WVComplex64{0.0,horizontal.k}),modes.A0FromVorticity[index]);
            else if (target == 3) A0Contribution = multiply(value,modes.A0FromBuoyancy[index]);
            const auto buoyancyValue = subtract(target == 3 ? value : WVComplex64{},multiply(A0Contribution,modes.NA0Field[index]));
            const auto buoyancyContribution = multiply(buoyancyValue,modes.ApmNProjection[index]);
            WVComplex64 waveContribution{};
            if (c.isHydrostatic) {
                if (target == 0) waveContribution = multiply(multiply(value,WVComplex64{0.0,horizontal.k}),modes.ApmDProjection[index]);
                else if (target == 1) waveContribution = multiply(multiply(value,WVComplex64{0.0,horizontal.l}),modes.ApmDProjection[index]);
            } else {
                if (target == 0) waveContribution = multiply(value,horizontal.cosAlpha * modes.ApmDScaled[index]);
                else if (target == 1) waveContribution = multiply(value,horizontal.sinAlpha * modes.ApmDScaled[index]);
                else if (target == 2) waveContribution = multiply(value,WVComplex64{0.0, (horizontal.Kh / 2.0) * modes.apmWProjectionPrefactor[j]});
            }
            auto ApContribution = add(waveContribution,buoyancyContribution);
            auto AmContribution = subtract(waveContribution,buoyancyContribution);
            if (iMode == 0) {
                if (target == 0) ApContribution = multiply(value,modes.inertialScale[j]);
                else if (target == 1) ApContribution = multiply(multiply(value,WVComplex64{0.0,-1.0}),modes.inertialScale[j]);
                else ApContribution = {};
                AmContribution = conjugate(ApContribution);
            }
            const auto p = phaseValues.data[index];
            flux.Fp.data[index] = add(flux.Fp.data[index],multiply(ApContribution,conjugate(p)));
            flux.Fm.data[index] = add(flux.Fm.data[index],multiply(AmContribution,p));
            flux.F0.data[index] = add(flux.F0.data[index],A0Contribution);
        }
    });
    return WVKernelStatus::ok();
}

WVKernelStatus WVTransformConstantStratificationKernel::nonlinearFlux(const WVState& state, WVFlux& flux) {
    auto status = validateStateAndFlux(descriptor_,state,flux);
    if (!status) return status;
    ExecutionGuard guard(executing_);
    if (!guard.entered()) return {WVKernelStatusCode::reentrantExecution,"Kernel operations are not reentrant."};

    const auto spectral = descriptor_.spectralShape();
    const auto phaseEvaluationCount = spectral.elementCount();
    const auto& modes = descriptor_.verticalModes();
    using Clock = std::chrono::steady_clock;
    auto stageStart = Clock::now();
    const auto& c = descriptor_.configuration();
    const auto halfFieldElements = descriptor_.halfSpectrumMappings().NxHalf * c.Ny * c.Nz;
    auto* phaseStorage = reinterpret_cast<WVComplex64*>(halfSpectrumScratch_.data()) + 3 * halfFieldElements;
    const double elapsed = state.t - state.t0;
    for (std::size_t index = 0; index < phaseEvaluationCount; ++index) {
        phaseStorage[index] = phase(modes.omega[index] * elapsed);
        flux.Fp.data[index] = {};
        flux.Fm.data[index] = {};
        flux.F0.data[index] = {};
    }
    if (stageInstrumentationEnabled_) metrics_.phaseSeconds = std::chrono::duration<double>(Clock::now() - stageStart).count();
    ++metrics_.nonlinearFluxCallCount;
    metrics_.nonlinearFluxPhaseEvaluationCount += phaseEvaluationCount;
    const WVComplexConstView phaseValues{phaseStorage,spectral};

    const auto spatial = descriptor_.spatialShape();
    const auto fieldElements = spatial.elementCount();
    WVRealFieldBundleView advectingFields{realScratch_.data(),{spatial.first,spatial.second,spatial.third,3}};
    stageStart = Clock::now();
    status = transformWaveVortexToUVWImpl(state,advectingFields,nullptr,phaseValues);
    if (!status) return status;
    if (stageInstrumentationEnabled_) metrics_.reconstructionSeconds = std::chrono::duration<double>(Clock::now() - stageStart).count();

    const std::size_t targetCount = descriptor_.configuration().isHydrostatic ? 3 : 4;
    const std::size_t hydrostaticTargets[] = {0,1,3};
    const std::size_t nonhydrostaticTargets[] = {0,1,2,3};
    const auto* targets = descriptor_.configuration().isHydrostatic ? hydrostaticTargets : nonhydrostaticTargets;
    double derivativeSeconds = 0.0;
    double productSeconds = 0.0;
    double projectionSeconds = 0.0;
    for (std::size_t iTarget = 0; iTarget < targetCount; ++iTarget) {
        double* derivativeData = realScratch_.data() + 3 * fieldElements;
        WVRealFieldBundleView derivatives{derivativeData,{spatial.first,spatial.second,spatial.third,3}};
        stageStart = Clock::now();
        status = transformToSpatialDomainWithDerivativesFromStateImpl(state,phaseValues,targets[iTarget],derivatives);
        if (!status) return status;
        if (stageInstrumentationEnabled_) derivativeSeconds += std::chrono::duration<double>(Clock::now() - stageStart).count();
        const double* WV_KERNEL_RESTRICT U = realScratch_.data();
        const double* WV_KERNEL_RESTRICT V = U + fieldElements;
        const double* WV_KERNEL_RESTRICT W = V + fieldElements;
        double* WV_KERNEL_RESTRICT dx = derivativeData;
        const double* WV_KERNEL_RESTRICT dy = dx + fieldElements;
        const double* WV_KERNEL_RESTRICT dz = dy + fieldElements;
        stageStart = Clock::now();
        for (std::size_t i = 0; i < fieldElements; ++i) dx[i] = -(U[i] * dx[i] + V[i] * dy[i] + W[i] * dz[i]);
        if (stageInstrumentationEnabled_) productSeconds += std::chrono::duration<double>(Clock::now() - stageStart).count();
        const WVRealFieldBundleConstView field{dx,{spatial.first,spatial.second,spatial.third,1}};
        stageStart = Clock::now();
        status = projectSingleFluxTargetImpl(field,targets[iTarget],phaseValues,flux);
        if (!status) return status;
        if (stageInstrumentationEnabled_) projectionSeconds += std::chrono::duration<double>(Clock::now() - stageStart).count();
    }
    if (stageInstrumentationEnabled_) {
        metrics_.derivativeReconstructionSeconds = derivativeSeconds;
        metrics_.productSeconds = productSeconds;
    }
    if (stageInstrumentationEnabled_) metrics_.projectionSeconds = projectionSeconds;
    return WVKernelStatus::ok();
}

} // namespace wavevortex
