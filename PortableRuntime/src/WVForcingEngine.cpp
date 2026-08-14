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

class WVWaveVortexCoefficientErrorPolicy final : public WVIntegrationErrorPolicy {
public:
    static WVKernelStatus create(
        const WVTransformConstantStratificationDescriptor& descriptor,
        double absoluteToleranceScale,
        std::unique_ptr<WVIntegrationErrorPolicy>& result) {
        if (!std::isfinite(absoluteToleranceScale) || absoluteToleranceScale <= 0.0) {
            return {WVKernelStatusCode::invalidConfiguration,"Adaptive absolute-tolerance scale must be finite and positive."};
        }
        try {
            auto policy = std::unique_ptr<WVWaveVortexCoefficientErrorPolicy>(new WVWaveVortexCoefficientErrorPolicy);
            const auto& configuration = descriptor.configuration();
            const auto& horizontalModes = descriptor.fourierModes();
            const auto& verticalModes = descriptor.verticalModes();
            const auto shape = descriptor.spectralShape();
            policy->shape_ = shape;
            policy->waveTolerance_.assign(shape.elementCount(),1.0);
            policy->vortexTolerance_.assign(shape.elementCount(),1.0);

            std::vector<double> uniqueKh;
            uniqueKh.reserve(horizontalModes.size());
            for (const auto& mode : horizontalModes) uniqueKh.push_back(std::abs(mode.Kh));
            std::sort(uniqueKh.begin(),uniqueKh.end());
            uniqueKh.erase(std::unique(uniqueKh.begin(),uniqueKh.end()),uniqueKh.end());
            if (uniqueKh.size() < 2) return {WVKernelStatusCode::invalidConfiguration,"Adaptive tolerances require at least two distinct horizontal radial wavenumbers."};
            double deltaK = 0.0;
            for (std::size_t index = 1; index < uniqueKh.size(); ++index) deltaK = std::max(deltaK,uniqueKh[index]-uniqueKh[index-1]);
            if (!(deltaK > 0.0) || !std::isfinite(deltaK)) return {WVKernelStatusCode::invalidConfiguration,"Adaptive radial tolerance spacing is invalid."};
            const double maximumKh = uniqueKh.back();
            std::vector<double> radialCenters;
            for (double center = 0.0; center <= maximumKh+0.5*deltaK; center += deltaK) radialCenters.push_back(center);
            std::vector<std::size_t> radialBin(horizontalModes.size(),radialCenters.size());
            std::vector<std::size_t> radialCounts(radialCenters.size(),0);
            for (std::size_t modeIndex = 0; modeIndex < horizontalModes.size(); ++modeIndex) {
                const double Kh = horizontalModes[modeIndex].Kh;
                for (std::size_t bin = 0; bin < radialCenters.size(); ++bin) {
                    if (radialCenters[bin]-0.5*deltaK < Kh && Kh <= radialCenters[bin]+0.5*deltaK) {
                        radialBin[modeIndex] = bin;
                        ++radialCounts[bin];
                        break;
                    }
                }
                if (radialBin[modeIndex] == radialCenters.size()) return {WVKernelStatusCode::invalidConfiguration,"A horizontal mode was not assigned to an adaptive radial tolerance bin."};
            }

            const double f = verticalModes.coriolisFrequency;
            const double f2 = f*f;
            const double N02 = configuration.N0*configuration.N0;
            for (std::size_t modeIndex = 0; modeIndex < horizontalModes.size(); ++modeIndex) {
                const double Kh = horizontalModes[modeIndex].Kh;
                const double Kh2 = Kh*Kh;
                const auto bin = radialBin[modeIndex];
                const double center = radialCenters[bin];
                const double radialEnergy = center+0.5*deltaK-std::max(center-0.5*deltaK,0.0);
                const double energyPerCoefficient = radialEnergy/static_cast<double>(radialCounts[bin]);
                for (std::size_t jIndex = 0; jIndex < configuration.Nj; ++jIndex) {
                    const auto coefficientIndex = jIndex+configuration.Nj*modeIndex;
                    const double verticalWavenumber = verticalModes.verticalWavenumber[jIndex];
                    double waveEnergyFactor = 0.0;
                    if (Kh == 0.0) {
                        waveEnergyFactor = jIndex == 0 ? configuration.Lz :
                            (configuration.isHydrostatic ? N02/(configuration.g*verticalWavenumber*verticalWavenumber) :
                                (N02-f2)/(configuration.g*verticalWavenumber*verticalWavenumber));
                    } else if (jIndex > 0) {
                        const double hpm = configuration.isHydrostatic ? N02/(configuration.g*verticalWavenumber*verticalWavenumber) :
                            (N02-f2)/(configuration.g*(verticalWavenumber*verticalWavenumber+Kh2));
                        waveEnergyFactor = 2.0*hpm;
                    }
                    double vortexEnergyFactor = 0.0;
                    if (Kh > 0.0) {
                        const double h0 = verticalModes.h0[jIndex];
                        const double deformationInverse = jIndex == 0 ? 0.0 : f2/(configuration.g*h0);
                        vortexEnergyFactor = h0/(Kh2+deformationInverse);
                    } else if (jIndex > 0) {
                        vortexEnergyFactor = configuration.g/2.0;
                    }
                    if (waveEnergyFactor > 0.0 && std::isfinite(waveEnergyFactor)) {
                        policy->waveTolerance_[coefficientIndex] = absoluteToleranceScale*std::sqrt(energyPerCoefficient/waveEnergyFactor);
                    }
                    if (vortexEnergyFactor > 0.0 && std::isfinite(vortexEnergyFactor)) {
                        policy->vortexTolerance_[coefficientIndex] = absoluteToleranceScale*std::sqrt(energyPerCoefficient/vortexEnergyFactor);
                    }
                }
            }
            result = std::move(policy);
            return WVKernelStatus::ok();
        } catch (const std::bad_alloc&) {
            return {WVKernelStatusCode::allocationFailure,"Adaptive tolerance allocation failed."};
        }
    }

    std::size_t componentCount() const noexcept override { return 3; }
    std::size_t elementCount(std::size_t component) const noexcept override { return component < 3 ? shape_.elementCount() : 0; }
    double absoluteTolerance(std::size_t component, std::size_t index) const noexcept override {
        if (component > 2 || index >= shape_.elementCount()) return std::numeric_limits<double>::quiet_NaN();
        return component < 2 ? waveTolerance_[index] : vortexTolerance_[index];
    }
    std::size_t persistentBytes() const noexcept override {
        return vectorBytes(waveTolerance_)+vectorBytes(vortexTolerance_);
    }

private:
    WVShape2D shape_;
    std::vector<double> waveTolerance_;
    std::vector<double> vortexTolerance_;
};

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
    const auto requiresPhysicalFields = std::any_of(derivedForcing_.begin(),derivedForcing_.end(),[](const auto& forcing) {
        return forcing.kind == WVForcingKind::bottomFrictionQuadratic || forcing.kind == WVForcingKind::adaptiveDamping;
    });
    const auto requiresForcingFields = std::any_of(derivedForcing_.begin(),derivedForcing_.end(),[](const auto& forcing) {
        return forcing.kind == WVForcingKind::bottomFrictionQuadratic;
    });
    const auto wholeFluxProducerCount = std::count_if(derivedForcing_.begin(),derivedForcing_.end(),[](const auto& forcing) {
        return forcing.kind == WVForcingKind::nonlinearAdvection || forcing.kind == WVForcingKind::bottomFrictionQuadratic;
    });
    if (requiresPhysicalFields) physicalFields_.resize(4*R);
    if (requiresForcingFields) forcingFields_.resize(q*R);
    if (wholeFluxProducerCount > 1) temporaryFlux_.resize(3*count);
    metrics_.workspaceCapacityBytes = vectorBytes(physicalFields_)+vectorBytes(forcingFields_)+vectorBytes(temporaryFlux_);
    metrics_.workspaceHighWaterBytes = metrics_.workspaceCapacityBytes;
    metrics_.workspaceLiveBytes = metrics_.workspaceCapacityBytes;
    metrics_.workspaceMaximumLiveBytes = metrics_.workspaceCapacityBytes;
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::ensurePhysicalFields(
    const WVState& state, WVRealFieldBundleConstView& fields,
    WVRealFieldBundleView* externalFields, bool& externalFieldsPrepared) {
    const auto& configuration = kernel_->descriptor().configuration();
    if (externalFields != nullptr) {
        if (!externalFieldsPrepared) {
            auto status = kernel_->transformWaveVortexToUVW(state,*externalFields);
            if (!status) return status;
            externalFieldsPrepared = true;
        }
        fields = {externalFields->data,externalFields->shape};
        return WVKernelStatus::ok();
    }
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

WVKernelStatus WVConstantStratificationForcingEngine::computeQuadraticBottomFriction(
    const WVState& state, const DerivedForcing& forcing, WVFlux& flux,
    WVRealFieldBundleView* externalFields, bool& externalFieldsPrepared) {
    WVRealFieldBundleConstView fields;
    auto status = ensurePhysicalFields(state,fields,externalFields,externalFieldsPrepared);
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
    WVMutableCoefficients coefficients{{flux.Fp.data,flux.Fp.shape},{flux.Fm.data,flux.Fm.shape},{flux.F0.data,flux.F0.shape}};
    const auto q = configuration.isHydrostatic ? 3U : 4U;
    const WVRealFieldBundleConstView forcingFields{forcingFields_.data(),{configuration.Nx,configuration.Ny,configuration.Nz,q}};
    return configuration.isHydrostatic ? kernel_->transformUVEtaToWaveVortex(forcingFields,state.t,state.t0,coefficients) : kernel_->transformUVWEtaToWaveVortex(forcingFields,state.t,state.t0,coefficients);
}

WVKernelStatus WVConstantStratificationForcingEngine::addAdaptiveDamping(
    const WVState& state, const DerivedForcing& forcing, WVFlux& flux,
    WVRealFieldBundleView* externalFields, bool& externalFieldsPrepared) {
    WVRealFieldBundleConstView fields;
    const auto status = ensurePhysicalFields(state,fields,externalFields,externalFieldsPrepared);
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
    return nonlinearFluxImpl(state,flux,nullptr,nullptr);
}

WVKernelStatus WVConstantStratificationForcingEngine::evaluateRightHandSideWithContext(
    const WVState& state, WVFlux& flux,
    WVRealFieldBundleView& advectionFieldStorage,
    WVConstantStratificationRightHandSideContext& context) {
    return nonlinearFluxImpl(state,flux,&advectionFieldStorage,&context);
}

WVKernelStatus WVConstantStratificationForcingEngine::nonlinearFluxImpl(
    const WVState& state, WVFlux& flux, WVRealFieldBundleView* externalFields,
    WVConstantStratificationRightHandSideContext* context) {
    if (executing_) return {WVKernelStatusCode::reentrantExecution,"Forcing-engine execution is not reentrant."};
    const auto validation = validateStateAndFlux(kernel_->descriptor(),state,flux);
    if (!validation) return validation;
    ++evaluationGeneration_;
    if (context != nullptr) *context = {};
    executing_ = true;
    struct Guard { bool& value; ~Guard() { value = false; } } guard{executing_};
    clearEvaluationWorkspace();
    const auto coefficientCount = kernel_->descriptor().spectralShape().elementCount();
    bool outputInitialized = false;
    bool externalFieldsPrepared = false;
    const auto initializeWithZeros = [&]() {
        std::fill_n(flux.Fp.data,coefficientCount,WVComplex64{});
        std::fill_n(flux.Fm.data,coefficientCount,WVComplex64{});
        std::fill_n(flux.F0.data,coefficientCount,WVComplex64{});
        metrics_.accumulatorClearElementWrites += 3*coefficientCount;
        outputInitialized = true;
    };

    for (const auto& forcing : derivedForcing_) {
        WVKernelStatus status = WVKernelStatus::ok();
        if (forcing.kind == WVForcingKind::nonlinearAdvection) {
            if (!outputInitialized) {
                status = externalFields == nullptr
                             ? kernel_->nonlinearFlux(state,flux)
                             : (externalFieldsPrepared
                                    ? kernel_->nonlinearFluxUsingAdvectionFields(state,flux,{externalFields->data,externalFields->shape})
                                    : kernel_->nonlinearFluxWithAdvectionFields(state,flux,*externalFields));
                if (status && externalFields != nullptr) externalFieldsPrepared = true;
                if (status) outputInitialized = true;
            } else {
                auto temporary = fluxViews(temporaryFlux_,kernel_->descriptor().spectralShape());
                status = externalFields == nullptr
                             ? kernel_->nonlinearFlux(state,temporary)
                             : (externalFieldsPrepared
                                    ? kernel_->nonlinearFluxUsingAdvectionFields(state,temporary,{externalFields->data,externalFields->shape})
                                    : kernel_->nonlinearFluxWithAdvectionFields(state,temporary,*externalFields));
                if (status && externalFields != nullptr) externalFieldsPrepared = true;
                if (status) {
                    addFlux(temporary,flux);
                    metrics_.temporaryAccumulationElementReads += 2*temporaryFlux_.size();
                    metrics_.temporaryAccumulationElementWrites += temporaryFlux_.size();
                }
            }
        } else if (forcing.kind == WVForcingKind::bottomFrictionQuadratic) {
            if (!outputInitialized) {
                status = computeQuadraticBottomFriction(state,forcing,flux,externalFields,externalFieldsPrepared);
                if (status) outputInitialized = true;
            } else {
                auto temporary = fluxViews(temporaryFlux_,kernel_->descriptor().spectralShape());
                status = computeQuadraticBottomFriction(state,forcing,temporary,externalFields,externalFieldsPrepared);
                if (status) {
                    addFlux(temporary,flux);
                    metrics_.temporaryAccumulationElementReads += 2*temporaryFlux_.size();
                    metrics_.temporaryAccumulationElementWrites += temporaryFlux_.size();
                }
            }
        } else if (forcing.kind == WVForcingKind::adaptiveDamping) {
            if (!outputInitialized) initializeWithZeros();
            status = addAdaptiveDamping(state,forcing,flux,externalFields,externalFieldsPrepared);
        } else if (forcing.kind == WVForcingKind::pseudoTopographicWaveGeneration) {
            if (!outputInitialized) initializeWithZeros();
            status = addPseudoTopographicGeneration(state,forcing,flux);
        } else if (forcing.kind == WVForcingKind::betaPlanePVAdvection) {
            if (!outputInitialized) initializeWithZeros();
            addBetaPlaneAdvection(state,forcing,flux);
        } else if (forcing.kind == WVForcingKind::fixedAmplitude) {
            if (!outputInitialized) initializeWithZeros();
            const auto& record = std::get<WVFixedAmplitudeForcingRecord>(schedule_.entries[forcing.entryIndex].payload);
            for (const auto index : record.ApIndices) flux.Fp.data[index] = {};
            for (const auto index : record.AmIndices) flux.Fm.data[index] = {};
            for (const auto index : record.A0Indices) flux.F0.data[index] = {};
        }
        if (!status) return status;
    }
    if (!outputInitialized) initializeWithZeros();
    if (externalFields != nullptr && !externalFieldsPrepared) {
        WVRealFieldBundleConstView ignored;
        auto status = ensurePhysicalFields(state,ignored,externalFields,externalFieldsPrepared);
        if (!status) return status;
    }
    if (context != nullptr) {
        context->owner_ = this;
        context->state_ = state;
        context->advectionFields_ = {externalFields->data,externalFields->shape};
        context->generation_ = evaluationGeneration_;
    }
    ++metrics_.evaluationCount;
    return WVKernelStatus::ok();
}

WVKernelStatus WVConstantStratificationForcingEngine::advectFGridScalar(
    const WVConstantStratificationRightHandSideContext& context,
    const WVRealVolumeConstView& scalar, bool shouldAntialias,
    WVRealVolumeView& rightHandSide) {
    if (context.owner_ != this || context.generation_ != evaluationGeneration_ ||
        context.advectionFields_.data == nullptr)
        return {WVKernelStatusCode::invalidConfiguration,"The RHS evaluation context is stale or belongs to another forcing engine."};
    return kernel_->advectFGridScalar(scalar,context.advectionFields_,shouldAntialias,rightHandSide);
}

WVStateConstraintResult WVConstantStratificationForcingEngine::restoreForcingAmplitudes(WVMutableCoefficients& coefficients) {
    const auto status = validateMutableCoefficients(kernel_->descriptor().spectralShape(),coefficients);
    if (!status) return {status,0,false};
    std::size_t modifiedCoefficientCount = 0;
    bool fsalCompatible = true;
    for (const auto& forcing : derivedForcing_) {
        if (forcing.kind != WVForcingKind::fixedAmplitude) continue;
        fsalCompatible = false;
        const auto& record = std::get<WVFixedAmplitudeForcingRecord>(schedule_.entries[forcing.entryIndex].payload);
        const auto restore = [&modifiedCoefficientCount](WVComplexView destination, const std::vector<std::size_t>& indices, const std::vector<WVComplex64>& values) {
            for (std::size_t index = 0; index < indices.size(); ++index) {
                const auto previous = destination.data[indices[index]];
                if (previous.real != values[index].real || previous.imag != values[index].imag) ++modifiedCoefficientCount;
                destination.data[indices[index]] = values[index];
            }
        };
        restore(coefficients.Ap,record.ApIndices,record.ApValues);
        restore(coefficients.Am,record.AmIndices,record.AmValues);
        restore(coefficients.A0,record.A0Indices,record.A0Values);
        metrics_.restoredCoefficientCount += record.ApIndices.size()+record.AmIndices.size()+record.A0Indices.size();
        metrics_.stateConstraintElementWrites += record.ApIndices.size()+record.AmIndices.size()+record.A0Indices.size();
    }
    return {WVKernelStatus::ok(),modifiedCoefficientCount,fsalCompatible};
}

WVKernelStatus WVConstantStratificationForcingEngine::createErrorPolicy(
    double absoluteToleranceScale,
    std::unique_ptr<WVIntegrationErrorPolicy>& policy) const {
    return WVWaveVortexCoefficientErrorPolicy::create(kernel_->descriptor(),absoluteToleranceScale,policy);
}

void WVConstantStratificationForcingEngine::clearEvaluationWorkspace() noexcept {
    physicalFieldsValid_ = false;
}

std::size_t WVConstantStratificationForcingEngine::persistentBytes() const noexcept {
    return kernel_->persistentBytes()+metrics_.scheduleBytes+metrics_.derivedOperatorBytes+metrics_.workspaceCapacityBytes;
}

} // namespace wavevortex::runtime
