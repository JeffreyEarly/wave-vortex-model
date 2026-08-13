#include "WaveVortexRuntime/WVForcingEngine.hpp"

#include <algorithm>
#include <cmath>
#include <complex>
#include <limits>
#include <new>
#include <set>
#include <sstream>
#include <type_traits>

namespace wavevortex::runtime {
namespace {

constexpr double pi = 3.141592653589793238462643383279502884;

WVComplex64 add(WVComplex64 a, WVComplex64 b) noexcept { return {a.real+b.real,a.imag+b.imag}; }
WVComplex64 multiply(WVComplex64 a, WVComplex64 b) noexcept { return {a.real*b.real-a.imag*b.imag,a.real*b.imag+a.imag*b.real}; }
WVComplex64 multiply(WVComplex64 a, double b) noexcept { return {a.real*b,a.imag*b}; }
WVComplex64 conjugate(WVComplex64 a) noexcept { return {a.real,-a.imag}; }
bool finite(WVComplex64 value) noexcept { return std::isfinite(value.real) && std::isfinite(value.imag); }

std::size_t stageRank(WVForcingStage stage) noexcept { return static_cast<std::size_t>(stage); }

WVForcingStage requiredStage(WVForcingKind kind) noexcept {
    switch (kind) {
        case WVForcingKind::nonlinearAdvection:
        case WVForcingKind::bottomFrictionQuadratic:
            return WVForcingStage::spatial;
        case WVForcingKind::adaptiveDamping:
        case WVForcingKind::pseudoTopographicWaveGeneration:
        case WVForcingKind::betaPlanePVAdvection:
            return WVForcingStage::spectral;
        case WVForcingKind::fixedAmplitude:
            return WVForcingStage::spectralAmplitude;
        default:
            return WVForcingStage::spectral;
    }
}

bool supportedKind(WVForcingKind kind) noexcept {
    return kind == WVForcingKind::nonlinearAdvection || kind == WVForcingKind::adaptiveDamping ||
        kind == WVForcingKind::fixedAmplitude || kind == WVForcingKind::bottomFrictionQuadratic ||
        kind == WVForcingKind::pseudoTopographicWaveGeneration || kind == WVForcingKind::betaPlanePVAdvection;
}

template <typename T>
std::size_t vectorBytes(const std::vector<T>& values) noexcept { return values.capacity()*sizeof(T); }

double vanishingFilter(double value, double cutoff, double maximum) noexcept {
    value = std::abs(value);
    if (value < cutoff) return 0.0;
    if (value > maximum) return 1.0;
    if (maximum == cutoff) return value >= maximum ? 1.0 : 0.0;
    const double ratio = (value-maximum)/(value-cutoff);
    return std::exp(-(ratio*ratio));
}

WVComplex64 normalizedTerrainCoefficient(
    const WVPseudoTopographicWaveGenerationRecord& record,
    std::int64_t kMode,
    std::int64_t lMode) {
    const auto Nx = record.topographicShape.rows;
    const auto Ny = record.topographicShape.columns;
    std::complex<double> sum(0.0,0.0);
    for (std::size_t iY = 0; iY < Ny; ++iY) {
        for (std::size_t iX = 0; iX < Nx; ++iX) {
            const double angle = -2.0*pi*(static_cast<double>(kMode)*static_cast<double>(iX)/static_cast<double>(Nx) +
                static_cast<double>(lMode)*static_cast<double>(iY)/static_cast<double>(Ny));
            sum += record.topographicHeight[iX+Nx*iY]*std::complex<double>(std::cos(angle),std::sin(angle));
        }
    }
    sum /= static_cast<double>(Nx*Ny);
    return {sum.real(),sum.imag()};
}

WVFlux fluxViews(std::vector<WVComplex64>& storage, WVShape2D shape) {
    const auto count = shape.elementCount();
    return {{storage.data(),shape},{storage.data()+count,shape},{storage.data()+2*count,shape}};
}

WVMutableCoefficients coefficientViews(std::vector<WVComplex64>& storage, WVShape2D shape) {
    const auto count = shape.elementCount();
    return {{storage.data(),shape},{storage.data()+count,shape},{storage.data()+2*count,shape}};
}

void addFlux(const WVFlux& source, WVFlux& destination) {
    const auto count = source.Fp.shape.elementCount();
    for (std::size_t index = 0; index < count; ++index) {
        destination.Fp.data[index] = add(destination.Fp.data[index],source.Fp.data[index]);
        destination.Fm.data[index] = add(destination.Fm.data[index],source.Fm.data[index]);
        destination.F0.data[index] = add(destination.F0.data[index],source.F0.data[index]);
    }
}

WVKernelStatus validateMutableCoefficients(WVShape2D expected, const WVMutableCoefficients& coefficients) {
    for (const auto& value : {coefficients.Ap,coefficients.Am,coefficients.A0}) {
        if (value.data == nullptr) return {WVKernelStatusCode::invalidPointer,"Mutable coefficient storage is null."};
        if (value.shape.rows != expected.rows || value.shape.columns != expected.columns) return {WVKernelStatusCode::invalidShape,"Mutable coefficient shape does not match the forcing engine."};
    }
    return WVKernelStatus::ok();
}

} // namespace

struct WVConstantStratificationForcingEngine::DerivedForcing {
    std::size_t entryIndex = 0;
    WVForcingKind kind = WVForcingKind::nonlinearAdvection;
    double quadraticDrag = 0.0;
    std::vector<double> damping;
    std::vector<WVComplex64> betaA0;
    std::vector<WVComplex64> responsePlusX;
    std::vector<WVComplex64> responsePlusY;
    std::vector<WVComplex64> responseMinusX;
    std::vector<WVComplex64> responseMinusY;

    std::size_t persistentBytes() const noexcept {
        return vectorBytes(damping)+vectorBytes(betaA0)+vectorBytes(responsePlusX)+vectorBytes(responsePlusY)+vectorBytes(responseMinusX)+vectorBytes(responseMinusY);
    }
};

WVConstantStratificationForcingEngine::~WVConstantStratificationForcingEngine() = default;

WVKernelStatus WVConstantStratificationForcingEngine::validateSchedule(
    const WVTransformConstantStratificationConfiguration& configuration,
    const WVFrozenForcingSchedule& schedule,
    WVShape2D coefficientShape) {
    if (schedule.profileIdentifier != WVForcingScheduleProfileIdentifier || schedule.profileVersion != WVForcingScheduleProfileVersion) {
        return {WVKernelStatusCode::unsupportedOperation,"Unsupported frozen forcing schedule profile."};
    }
    if (coefficientShape.rows != configuration.Nj || coefficientShape.rows == 0 || coefficientShape.columns == 0) {
        return {WVKernelStatusCode::invalidShape,"Frozen forcing coefficient shape is incompatible with the model configuration."};
    }
    const auto count = coefficientShape.elementCount();
    std::set<std::string> names;
    for (const auto& entry : schedule.entries) {
        if (!supportedKind(entry.kind)) return {WVKernelStatusCode::unsupportedOperation,"The frozen schedule contains an unsupported forcing class."};
        if (entry.stage != requiredStage(entry.kind)) return {WVKernelStatusCode::invalidConfiguration,"A forcing record is assigned to the wrong execution stage."};
        if (entry.name.empty() || !names.insert(entry.name).second) return {WVKernelStatusCode::invalidConfiguration,"Forcing names must be nonempty and unique."};
        if (entry.kind == WVForcingKind::nonlinearAdvection && !std::holds_alternative<WVNonlinearAdvectionRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Nonlinear-advection payload type mismatch."};
        if (entry.kind == WVForcingKind::adaptiveDamping) {
            if (!std::holds_alternative<WVAdaptiveDampingRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Adaptive-damping payload type mismatch."};
            const double latitude = configuration.latitude*pi/180.0;
            if (2.0*configuration.rotationRate*std::sin(latitude) == 0.0) return {WVKernelStatusCode::unsupportedOperation,"Adaptive damping requires nonzero Coriolis frequency."};
        }
        if (entry.kind == WVForcingKind::betaPlanePVAdvection && !std::holds_alternative<WVBetaPlanePVAdvectionRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Beta-plane payload type mismatch."};
        if (entry.kind == WVForcingKind::bottomFrictionQuadratic) {
            if (!std::holds_alternative<WVBottomFrictionQuadraticRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Quadratic-bottom-friction payload type mismatch."};
            const double Cd = std::get<WVBottomFrictionQuadraticRecord>(entry.payload).Cd;
            if (!std::isfinite(Cd) || Cd < 0.0) return {WVKernelStatusCode::invalidConfiguration,"Quadratic drag coefficient must be finite and nonnegative."};
        }
        if (entry.kind == WVForcingKind::fixedAmplitude) {
            if (!std::holds_alternative<WVFixedAmplitudeForcingRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Fixed-amplitude payload type mismatch."};
            const auto& record = std::get<WVFixedAmplitudeForcingRecord>(entry.payload);
            const auto validFamily = [count](const auto& indices,const auto& values) {
                if (indices.size() != values.size()) return false;
                std::set<std::size_t> unique;
                for (std::size_t index = 0; index < indices.size(); ++index) if (indices[index] >= count || !finite(values[index]) || !unique.insert(indices[index]).second) return false;
                return true;
            };
            if (!validFamily(record.ApIndices,record.ApValues) || !validFamily(record.AmIndices,record.AmValues) || !validFamily(record.A0Indices,record.A0Values)) return {WVKernelStatusCode::invalidConfiguration,"Fixed-amplitude indices and values are incompatible with the coefficient shape."};
        }
        if (entry.kind == WVForcingKind::pseudoTopographicWaveGeneration) {
            if (!std::holds_alternative<WVPseudoTopographicWaveGenerationRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Pseudo-topographic payload type mismatch."};
            const auto& record = std::get<WVPseudoTopographicWaveGenerationRecord>(entry.payload);
            if (record.topographicShape.rows != configuration.Nx || record.topographicShape.columns != configuration.Ny || record.topographicHeight.size() != configuration.Nx*configuration.Ny) return {WVKernelStatusCode::invalidShape,"Pseudo-topographic height does not match the horizontal grid."};
            if (!std::isfinite(record.frequency) || record.frequency <= 0.0 || !std::isfinite(record.rampDuration) || record.rampDuration < 0.0 || !std::isfinite(record.startTime)) return {WVKernelStatusCode::invalidConfiguration,"Pseudo-topographic timing parameters are invalid."};
            for (const auto value : record.topographicHeight) if (!std::isfinite(value)) return {WVKernelStatusCode::invalidConfiguration,"Pseudo-topographic height must be finite."};
            for (const auto value : record.barotropicVelocityAmplitude) if (!finite(value)) return {WVKernelStatusCode::invalidConfiguration,"Barotropic velocity amplitude must be finite."};
        }
    }
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::create(
    const WVTransformConstantStratificationConfiguration& configuration,
    const WVFrozenForcingSchedule& schedule,
    std::unique_ptr<WVFFTEngine> fftEngine,
    std::unique_ptr<WVConstantStratificationForcingEngine>& forcingEngine) {
    if (!fftEngine) return {WVKernelStatusCode::invalidPointer,"Forcing-engine construction requires an FFT engine."};
    try {
        auto candidate = std::unique_ptr<WVConstantStratificationForcingEngine>(new WVConstantStratificationForcingEngine());
        auto status = WVTransformConstantStratificationKernel::create(configuration,std::move(fftEngine),candidate->kernel_);
        if (!status) return status;
        status = candidate->initialize(schedule);
        if (!status) return status;
        forcingEngine = std::move(candidate);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"Forcing-engine allocation failed."};
    } catch (const std::exception& exception) {
        return {WVKernelStatusCode::invalidConfiguration,exception.what()};
    }
}

WVKernelStatus WVConstantStratificationForcingEngine::initialize(const WVFrozenForcingSchedule& schedule) {
    if (schedule.profileIdentifier != WVForcingScheduleProfileIdentifier || schedule.profileVersion != WVForcingScheduleProfileVersion) {
        return {WVKernelStatusCode::unsupportedOperation,"Unsupported frozen forcing schedule profile."};
    }
    schedule_ = schedule;
    std::stable_sort(schedule_.entries.begin(),schedule_.entries.end(),[](const auto& left,const auto& right) {
        if (stageRank(left.stage) != stageRank(right.stage)) return stageRank(left.stage) < stageRank(right.stage);
        if (left.priority != right.priority) return left.priority < right.priority;
        return left.ordinal < right.ordinal;
    });

    std::set<std::string> names;
    const auto& descriptor = kernel_->descriptor();
    const auto shape = descriptor.spectralShape();
    const auto count = shape.elementCount();
    const auto& configuration = descriptor.configuration();
    const auto& modes = descriptor.verticalModes();
    bool hasAdaptiveDamping = false;
    std::vector<double> adaptiveDamping;

    for (std::size_t entryIndex = 0; entryIndex < schedule_.entries.size(); ++entryIndex) {
        const auto& entry = schedule_.entries[entryIndex];
        if (!supportedKind(entry.kind)) return {WVKernelStatusCode::unsupportedOperation,"The frozen schedule contains an unsupported forcing class."};
        if (entry.stage != requiredStage(entry.kind)) return {WVKernelStatusCode::invalidConfiguration,"A forcing record is assigned to the wrong execution stage."};
        if (entry.name.empty() || !names.insert(entry.name).second) return {WVKernelStatusCode::invalidConfiguration,"Forcing names must be nonempty and unique."};

        DerivedForcing derived;
        derived.entryIndex = entryIndex;
        derived.kind = entry.kind;
        if (entry.stage == WVForcingStage::spatial) ++metrics_.resolvedSpatialCount;
        else if (entry.stage == WVForcingStage::spectral) ++metrics_.resolvedSpectralCount;
        else ++metrics_.resolvedAmplitudeCount;

        if (entry.kind == WVForcingKind::nonlinearAdvection) {
            if (!std::holds_alternative<WVNonlinearAdvectionRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Nonlinear-advection payload type mismatch."};
        } else if (entry.kind == WVForcingKind::bottomFrictionQuadratic) {
            if (!std::holds_alternative<WVBottomFrictionQuadraticRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Quadratic-bottom-friction payload type mismatch."};
            const double Cd = std::get<WVBottomFrictionQuadraticRecord>(entry.payload).Cd;
            if (!std::isfinite(Cd) || Cd < 0.0) return {WVKernelStatusCode::invalidConfiguration,"Quadratic drag coefficient must be finite and nonnegative."};
            const double dz = configuration.Lz/static_cast<double>(configuration.Nz-1);
            derived.quadraticDrag = Cd/(0.5*dz);
        } else if (entry.kind == WVForcingKind::adaptiveDamping) {
            if (!std::holds_alternative<WVAdaptiveDampingRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Adaptive-damping payload type mismatch."};
            const double f2 = modes.coriolisFrequency*modes.coriolisFrequency;
            if (!(f2 > 0.0)) return {WVKernelStatusCode::unsupportedOperation,"Adaptive damping requires nonzero Coriolis frequency."};
            double maximumComponent = 0.0;
            for (const auto& horizontal : descriptor.fourierModes()) maximumComponent = std::max(maximumComponent,std::max(std::abs(horizontal.k),std::abs(horizontal.l)));
            if (!(maximumComponent > 0.0)) return {WVKernelStatusCode::invalidConfiguration,"Adaptive damping requires resolved horizontal wavenumbers."};
            const double effectiveResolution = pi/maximumComponent;
            const double klMaximum = maximumComponent;
            const double dklMinimum = std::min(2.0*pi/configuration.Lx,2.0*pi/configuration.Ly);
            const double klCutoff = dklMinimum*std::pow(klMaximum/dklMinimum,0.75);
            const double jMaximum = static_cast<double>(configuration.Nj-1);
            const double jCutoff = configuration.Nj > 2 ? std::pow(jMaximum,0.75) : 0.0;
            const double prefactorXY = effectiveResolution/(pi*pi);
            const double referenceLr2 = configuration.g*modes.h0.back()/f2;
            const double prefactorZ = (pi*pi*referenceLr2/(effectiveResolution*effectiveResolution))*prefactorXY;
            derived.damping.resize(count);
            for (std::size_t iMode = 0; iMode < descriptor.Nkl(); ++iMode) {
                const auto& horizontal = descriptor.fourierModes()[iMode];
                const double Qkl = vanishingFilter(horizontal.Kh,klCutoff,klMaximum);
                for (std::size_t iJ = 0; iJ < configuration.Nj; ++iJ) {
                    const auto index = iJ+configuration.Nj*iMode;
                    const double Qj = configuration.Nj > 2 ? vanishingFilter(modes.j[iJ],jCutoff,jMaximum) : 1.0;
                    const double Lr2Inverse = iJ == 0 ? 0.0 : f2/(configuration.g*modes.h0[iJ]);
                    derived.damping[index] = -prefactorXY*Qkl*horizontal.Kh*horizontal.Kh-prefactorZ*Qj*Lr2Inverse;
                }
            }
            hasAdaptiveDamping = true;
            adaptiveDamping = derived.damping;
        } else if (entry.kind == WVForcingKind::fixedAmplitude) {
            if (!std::holds_alternative<WVFixedAmplitudeForcingRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Fixed-amplitude payload type mismatch."};
            const auto& record = std::get<WVFixedAmplitudeForcingRecord>(entry.payload);
            const auto validate = [count](const auto& indices,const auto& values) {
                if (indices.size() != values.size()) return false;
                std::set<std::size_t> unique;
                for (std::size_t index = 0; index < indices.size(); ++index) if (indices[index] >= count || !finite(values[index]) || !unique.insert(indices[index]).second) return false;
                return true;
            };
            if (!validate(record.ApIndices,record.ApValues) || !validate(record.AmIndices,record.AmValues) || !validate(record.A0Indices,record.A0Values)) {
                return {WVKernelStatusCode::invalidConfiguration,"Fixed-amplitude indices and values are incompatible with the coefficient shape."};
            }
        } else if (entry.kind == WVForcingKind::betaPlanePVAdvection) {
            if (!std::holds_alternative<WVBetaPlanePVAdvectionRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Beta-plane payload type mismatch."};
            const double beta = 2.0*configuration.rotationRate*std::cos(configuration.latitude*pi/180.0)/configuration.planetaryRadius;
            derived.betaA0.resize(count);
            for (std::size_t iMode = 0; iMode < descriptor.Nkl(); ++iMode) {
                for (std::size_t iJ = 0; iJ < configuration.Nj; ++iJ) {
                    const auto index = iJ+configuration.Nj*iMode;
                    const auto value = modes.VA0Field[index];
                    derived.betaA0[index] = iMode == 0 ? WVComplex64{} : multiply(value,-beta/modes.Fg[iJ]);
                }
            }
        } else if (entry.kind == WVForcingKind::pseudoTopographicWaveGeneration) {
            if (!std::holds_alternative<WVPseudoTopographicWaveGenerationRecord>(entry.payload)) return {WVKernelStatusCode::invalidConfiguration,"Pseudo-topographic payload type mismatch."};
            const auto& record = std::get<WVPseudoTopographicWaveGenerationRecord>(entry.payload);
            if (record.topographicShape.rows != configuration.Nx || record.topographicShape.columns != configuration.Ny || record.topographicHeight.size() != configuration.Nx*configuration.Ny) {
                return {WVKernelStatusCode::invalidShape,"Pseudo-topographic height does not match the horizontal grid."};
            }
            if (!std::isfinite(record.frequency) || record.frequency <= 0.0 || !std::isfinite(record.rampDuration) || record.rampDuration < 0.0 || !std::isfinite(record.startTime)) {
                return {WVKernelStatusCode::invalidConfiguration,"Pseudo-topographic timing parameters are invalid."};
            }
            for (const auto value : record.topographicHeight) if (!std::isfinite(value)) return {WVKernelStatusCode::invalidConfiguration,"Pseudo-topographic height must be finite."};
            for (const auto value : record.barotropicVelocityAmplitude) if (!finite(value)) return {WVKernelStatusCode::invalidConfiguration,"Barotropic velocity amplitude must be finite."};
            derived.responsePlusX.assign(count,{}); derived.responsePlusY.assign(count,{});
            derived.responseMinusX.assign(count,{}); derived.responseMinusY.assign(count,{});
            for (std::size_t iMode = 0; iMode < descriptor.Nkl(); ++iMode) {
                const auto& horizontal = descriptor.fourierModes()[iMode];
                const auto terrain = normalizedTerrainCoefficient(record,horizontal.kMode,horizontal.lMode);
                const auto dHdx = multiply(WVComplex64{-terrain.imag,terrain.real},horizontal.k);
                const auto dHdy = multiply(WVComplex64{-terrain.imag,terrain.real},horizontal.l);
                for (std::size_t iJ = 1; iJ < configuration.Nj; ++iJ) {
                    const auto index = iJ+configuration.Nj*iMode;
                    if (!(horizontal.Kh > 0.0) || horizontal.Kh > record.maximumForcedHorizontalWavenumber || modes.j[iJ] > record.maximumForcedVerticalMode) continue;
                    if (record.shouldAvoidAdaptiveDamping && hasAdaptiveDamping && adaptiveDamping[index] != 0.0) continue;
                    const double NAp = modes.NApField[index]/modes.gWaveScale[iJ];
                    const double bottomF = modes.fWaveScale[index];
                    const double hpm = -NAp*modes.omega[index]/horizontal.Kh;
                    const double energyFactor = 2.0*hpm;
                    if (!(energyFactor > 0.0)) continue;
                    const WVComplex64 piPlus{configuration.g*bottomF*NAp,0.0};
                    const WVComplex64 piMinus{-piPlus.real,0.0};
                    derived.responsePlusX[index] = multiply(multiply(conjugate(piPlus),dHdx),1.0/energyFactor);
                    derived.responsePlusY[index] = multiply(multiply(conjugate(piPlus),dHdy),1.0/energyFactor);
                    derived.responseMinusX[index] = multiply(multiply(conjugate(piMinus),dHdx),1.0/energyFactor);
                    derived.responseMinusY[index] = multiply(multiply(conjugate(piMinus),dHdy),1.0/energyFactor);
                }
            }
        }
        metrics_.derivedOperatorBytes += derived.persistentBytes();
        derivedForcing_.push_back(std::move(derived));
    }

    std::ostringstream identifier;
    identifier << WVForcingScheduleProfileIdentifier << ':';
    for (std::size_t index = 0; index < schedule_.entries.size(); ++index) {
        if (index != 0) identifier << ',';
        identifier << schedule_.entries[index].typeIdentifier;
        metrics_.scheduleBytes += schedule_.entries[index].typeIdentifier.capacity()+schedule_.entries[index].name.capacity()+schedule_.entries[index].sourceGroupPath.capacity();
    }
    scheduleIdentifier_ = identifier.str();
    const auto R = descriptor.spatialShape().elementCount();
    const auto q = configuration.isHydrostatic ? 3U : 4U;
    physicalFields_.resize(4*R); forcingFields_.resize(q*R);
    accumulatedFlux_.resize(3*count); temporaryFlux_.resize(3*count);
    metrics_.workspaceCapacityBytes = vectorBytes(physicalFields_)+vectorBytes(forcingFields_)+vectorBytes(accumulatedFlux_)+vectorBytes(temporaryFlux_);
    metrics_.workspaceHighWaterBytes = metrics_.workspaceCapacityBytes;
    metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
    metrics_.workspaceMaximumLiveBytes = metrics_.workspaceCapacityBytes;
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::ensurePhysicalFields(const WVState& state, WVRealFieldBundleConstView& fields) {
    const auto& configuration = kernel_->descriptor().configuration();
    const WVShape4D shape{configuration.Nx,configuration.Ny,configuration.Nz,4};
    if (!physicalFieldsValid_) {
        WVRealFieldBundleView mutableFields{physicalFields_.data(),shape};
        const auto status = kernel_->transformWaveVortexToUVWEta(state,mutableFields);
        if (!status) return status;
        physicalFieldsValid_ = true;
    }
    fields = {physicalFields_.data(),shape};
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::addQuadraticBottomFriction(const WVState& state, const DerivedForcing& forcing, WVFlux& flux) {
    WVRealFieldBundleConstView fields;
    auto status = ensurePhysicalFields(state,fields);
    if (!status) return status;
    std::fill(forcingFields_.begin(),forcingFields_.end(),0.0);
    const auto& configuration = kernel_->descriptor().configuration();
    const auto R = kernel_->descriptor().spatialShape().elementCount();
    const auto horizontalCount = configuration.Nx*configuration.Ny;
    for (std::size_t index = 0; index < horizontalCount; ++index) {
        const double u = fields.data[index];
        const double v = fields.data[R+index];
        const double speed = std::sqrt(u*u+v*v);
        forcingFields_[index] = -forcing.quadraticDrag*u*speed;
        forcingFields_[R+index] = -forcing.quadraticDrag*v*speed;
    }
    auto coefficients = coefficientViews(temporaryFlux_,kernel_->descriptor().spectralShape());
    const auto q = configuration.isHydrostatic ? 3U : 4U;
    const WVRealFieldBundleConstView forcingFields{forcingFields_.data(),{configuration.Nx,configuration.Ny,configuration.Nz,q}};
    status = configuration.isHydrostatic ? kernel_->transformUVEtaToWaveVortex(forcingFields,state.t,state.t0,coefficients) : kernel_->transformUVWEtaToWaveVortex(forcingFields,state.t,state.t0,coefficients);
    if (!status) return status;
    WVFlux source{{coefficients.Ap.data,coefficients.Ap.shape},{coefficients.Am.data,coefficients.Am.shape},{coefficients.A0.data,coefficients.A0.shape}};
    addFlux(source,flux);
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::addAdaptiveDamping(const WVState& state, const DerivedForcing& forcing, WVFlux& flux) {
    WVRealFieldBundleConstView fields;
    const auto status = ensurePhysicalFields(state,fields);
    if (!status) return status;
    const auto R = kernel_->descriptor().spatialShape().elementCount();
    double maximumSpeed = 0.0;
    for (std::size_t index = 0; index < R; ++index) maximumSpeed = std::max(maximumSpeed,std::sqrt(fields.data[index]*fields.data[index]+fields.data[R+index]*fields.data[R+index]));
    const auto count = forcing.damping.size();
    for (std::size_t index = 0; index < count; ++index) {
        flux.Fp.data[index] = add(flux.Fp.data[index],multiply(state.coefficients.Ap.data[index],maximumSpeed*forcing.damping[index]));
        flux.Fm.data[index] = add(flux.Fm.data[index],multiply(state.coefficients.Am.data[index],maximumSpeed*forcing.damping[index]));
        flux.F0.data[index] = add(flux.F0.data[index],multiply(state.coefficients.A0.data[index],maximumSpeed*forcing.damping[index]));
    }
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::addPseudoTopographicGeneration(const WVState& state, const DerivedForcing& forcing, WVFlux& flux) {
    const auto& record = std::get<WVPseudoTopographicWaveGenerationRecord>(schedule_.entries[forcing.entryIndex].payload);
    const double elapsed = state.t-record.startTime;
    if (elapsed < 0.0) return WVKernelStatus::ok();
    const double ramp = record.rampDuration == 0.0 || elapsed >= record.rampDuration ? 1.0 : 0.5*(1.0-std::cos(pi*elapsed/record.rampDuration));
    const WVComplex64 oscillation{std::cos(record.frequency*elapsed),-std::sin(record.frequency*elapsed)};
    const double velocityX = ramp*multiply(record.barotropicVelocityAmplitude[0],oscillation).real;
    const double velocityY = ramp*multiply(record.barotropicVelocityAmplitude[1],oscillation).real;
    const auto& modes = kernel_->descriptor().verticalModes();
    const auto count = forcing.responsePlusX.size();
    for (std::size_t index = 0; index < count; ++index) {
        const double angle = modes.omega[index]*(state.t-state.t0);
        const WVComplex64 phase{std::cos(angle),std::sin(angle)};
        const auto plus = add(multiply(forcing.responsePlusX[index],velocityX),multiply(forcing.responsePlusY[index],velocityY));
        const auto minus = add(multiply(forcing.responseMinusX[index],velocityX),multiply(forcing.responseMinusY[index],velocityY));
        flux.Fp.data[index] = add(flux.Fp.data[index],multiply(plus,conjugate(phase)));
        flux.Fm.data[index] = add(flux.Fm.data[index],multiply(minus,phase));
    }
    return WVKernelStatus::ok();
}

void WVConstantStratificationForcingEngine::addBetaPlaneAdvection(const WVState& state, const DerivedForcing& forcing, WVFlux& flux) const {
    for (std::size_t index = 0; index < forcing.betaA0.size(); ++index) flux.F0.data[index] = add(flux.F0.data[index],multiply(forcing.betaA0[index],state.coefficients.A0.data[index]));
}

WVKernelStatus WVConstantStratificationForcingEngine::nonlinearFlux(const WVState& state, WVFlux& flux) {
    if (executing_) return {WVKernelStatusCode::reentrantExecution,"Forcing-engine execution is not reentrant."};
    const auto validation = validateStateAndFlux(kernel_->descriptor(),state,flux);
    if (!validation) return validation;
    executing_ = true;
    struct Guard { bool& value; ~Guard() { value = false; } } guard{executing_};
    clearEvaluationWorkspace();
    auto accumulator = fluxViews(accumulatedFlux_,kernel_->descriptor().spectralShape());
    auto temporary = fluxViews(temporaryFlux_,kernel_->descriptor().spectralShape());

    for (const auto& forcing : derivedForcing_) {
        WVKernelStatus status = WVKernelStatus::ok();
        if (forcing.kind == WVForcingKind::nonlinearAdvection) {
            std::fill(temporaryFlux_.begin(),temporaryFlux_.end(),WVComplex64{});
            metrics_.temporaryFluxClearElementWrites += temporaryFlux_.size();
            metrics_.kernelOutputInitializationElementWrites += temporaryFlux_.size();
            status = kernel_->nonlinearFlux(state,temporary);
            if (status) {
                addFlux(temporary,accumulator);
                metrics_.temporaryAccumulationElementReads += 2*temporaryFlux_.size();
                metrics_.temporaryAccumulationElementWrites += temporaryFlux_.size();
            }
        } else if (forcing.kind == WVForcingKind::bottomFrictionQuadratic) {
            status = addQuadraticBottomFriction(state,forcing,accumulator);
            if (status) {
                metrics_.temporaryAccumulationElementReads += 2*temporaryFlux_.size();
                metrics_.temporaryAccumulationElementWrites += temporaryFlux_.size();
            }
        } else if (forcing.kind == WVForcingKind::adaptiveDamping) {
            status = addAdaptiveDamping(state,forcing,accumulator);
        } else if (forcing.kind == WVForcingKind::pseudoTopographicWaveGeneration) {
            status = addPseudoTopographicGeneration(state,forcing,accumulator);
        } else if (forcing.kind == WVForcingKind::betaPlanePVAdvection) {
            addBetaPlaneAdvection(state,forcing,accumulator);
        } else if (forcing.kind == WVForcingKind::fixedAmplitude) {
            const auto& record = std::get<WVFixedAmplitudeForcingRecord>(schedule_.entries[forcing.entryIndex].payload);
            for (const auto index : record.ApIndices) accumulator.Fp.data[index] = {};
            for (const auto index : record.AmIndices) accumulator.Fm.data[index] = {};
            for (const auto index : record.A0Indices) accumulator.F0.data[index] = {};
        }
        if (!status) return status;
    }

    const auto count = kernel_->descriptor().spectralShape().elementCount();
    std::copy_n(accumulator.Fp.data,count,flux.Fp.data);
    std::copy_n(accumulator.Fm.data,count,flux.Fm.data);
    std::copy_n(accumulator.F0.data,count,flux.F0.data);
    metrics_.outputCopyElementReads += 3*count;
    metrics_.outputCopyElementWrites += 3*count;
    ++metrics_.evaluationCount;
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::restoreForcingAmplitudes(WVMutableCoefficients& coefficients) {
    const auto status = validateMutableCoefficients(kernel_->descriptor().spectralShape(),coefficients);
    if (!status) return status;
    for (const auto& forcing : derivedForcing_) {
        if (forcing.kind != WVForcingKind::fixedAmplitude) continue;
        const auto& record = std::get<WVFixedAmplitudeForcingRecord>(schedule_.entries[forcing.entryIndex].payload);
        for (std::size_t index = 0; index < record.ApIndices.size(); ++index) coefficients.Ap.data[record.ApIndices[index]] = record.ApValues[index];
        for (std::size_t index = 0; index < record.AmIndices.size(); ++index) coefficients.Am.data[record.AmIndices[index]] = record.AmValues[index];
        for (std::size_t index = 0; index < record.A0Indices.size(); ++index) coefficients.A0.data[record.A0Indices[index]] = record.A0Values[index];
        metrics_.restoredCoefficientCount += record.ApIndices.size()+record.AmIndices.size()+record.A0Indices.size();
        metrics_.stateConstraintElementWrites += record.ApIndices.size()+record.AmIndices.size()+record.A0Indices.size();
    }
    return WVKernelStatus::ok();
}

void WVConstantStratificationForcingEngine::clearEvaluationWorkspace() noexcept {
    std::fill(accumulatedFlux_.begin(),accumulatedFlux_.end(),WVComplex64{});
    metrics_.accumulatorClearElementWrites += accumulatedFlux_.size();
    physicalFieldsValid_ = false;
}

std::size_t WVConstantStratificationForcingEngine::persistentBytes() const noexcept {
    return kernel_->persistentBytes()+metrics_.scheduleBytes+metrics_.derivedOperatorBytes+metrics_.workspaceCapacityBytes;
}

} // namespace wavevortex::runtime
