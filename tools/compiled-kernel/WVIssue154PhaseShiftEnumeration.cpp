#include "WaveVortexKernel/WVKernelTypes.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <complex>
#include <cstddef>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

using namespace wavevortex;

namespace {

using Complex = std::complex<double>;
constexpr double pi = 3.141592653589793238462643383279502884;

struct Mode {
    std::int64_t k = 0;
    std::int64_t l = 0;

    bool operator<(const Mode& other) const noexcept { return std::tie(k,l) < std::tie(other.k,other.l); }
    bool operator==(const Mode& other) const noexcept { return k == other.k && l == other.l; }
};

Mode operator-(Mode value) { return {-value.k,-value.l}; }
Mode operator-(Mode first, Mode second) { return {first.k-second.k,first.l-second.l}; }

struct Alias {
    std::int64_t x = 0;
    std::int64_t y = 0;

    bool operator<(const Alias& other) const noexcept { return std::tie(x,y) < std::tie(other.x,other.y); }
    bool operator==(const Alias& other) const noexcept { return x == other.x && y == other.y; }
};

struct Shift {
    double x = 0.0;
    double y = 0.0;
};

using ModeSet = std::set<Mode>;
using AliasSet = std::set<Alias>;
using Spectrum = std::map<Mode,Complex>;

struct Aspect {
    double Lx = 0.0;
    double Ly = 0.0;
    const char* name = nullptr;
};

struct GeometryCase {
    std::size_t Nx = 0;
    std::size_t Ny = 0;
    std::size_t aspect = 0;
};

[[noreturn]] void fail(const std::string& message) { throw std::runtime_error(message); }

void require(bool condition, const std::string& message) {
    if (!condition) fail(message);
}

std::int64_t positiveRemainder(std::int64_t value, std::int64_t modulus) {
    const auto remainder = value % modulus;
    return remainder < 0 ? remainder + modulus : remainder;
}

WVTransformConstantStratificationConfiguration configuration(const GeometryCase& geometry, const Aspect& aspect, bool hydrostatic) {
    WVTransformConstantStratificationConfiguration value;
    value.Nx = geometry.Nx;
    value.Ny = geometry.Ny;
    value.Nz = 5;
    value.Nj = 3;
    value.Lx = aspect.Lx;
    value.Ly = aspect.Ly;
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

ModeSet retainedModes(const WVTransformConstantStratificationDescriptor& descriptor) {
    ModeSet retained;
    for (const auto& mode : descriptor.fourierModes()) {
        const Mode primary{mode.kMode,mode.lMode};
        retained.insert(primary);
        retained.insert(-primary);
    }
    return retained;
}

std::int64_t maximumAbsoluteK(const ModeSet& modes) {
    std::int64_t result = 0;
    for (const auto mode : modes) result = std::max(result,std::abs(mode.k));
    return result;
}

std::int64_t maximumAbsoluteL(const ModeSet& modes) {
    std::int64_t result = 0;
    for (const auto mode : modes) result = std::max(result,std::abs(mode.l));
    return result;
}

bool injectiveOnGrid(const ModeSet& modes, std::int64_t Mx, std::int64_t My) {
    std::set<std::pair<std::int64_t,std::int64_t>> residues;
    for (const auto mode : modes) {
        if (!residues.insert({positiveRemainder(mode.k,Mx),positiveRemainder(mode.l,My)}).second) return false;
    }
    return true;
}

AliasSet aliasSet(const ModeSet& retained, std::int64_t Mx, std::int64_t My) {
    AliasSet aliases;
    for (const auto first : retained) {
        for (const auto second : retained) {
            for (const auto output : retained) {
                const auto deltaK = first.k + second.k - output.k;
                const auto deltaL = first.l + second.l - output.l;
                if (deltaK % Mx != 0 || deltaL % My != 0) continue;
                const Alias alias{deltaK/Mx,deltaL/My};
                if (alias.x != 0 || alias.y != 0) aliases.insert(alias);
            }
        }
    }
    return aliases;
}

double characterResidual(const AliasSet& aliases, const std::vector<Shift>& shifts) {
    double residual = 0.0;
    for (const auto alias : aliases) {
        Complex average;
        for (const auto shift : shifts) average += std::polar(1.0,2.0*pi*(static_cast<double>(alias.x)*shift.x + static_cast<double>(alias.y)*shift.y));
        residual = std::max(residual,std::abs(average/static_cast<double>(shifts.size())));
    }
    return residual;
}

std::vector<Shift> minimumTensorHalfShiftSet(const AliasSet& aliases) {
    const std::array<Shift,4> candidates{{{0.0,0.0},{0.5,0.0},{0.0,0.5},{0.5,0.5}}};
    for (std::size_t count = 1; count <= candidates.size(); ++count) {
        for (unsigned mask = 1; mask < (1U << candidates.size()); ++mask) {
            if ((mask & 1U) == 0 || static_cast<std::size_t>(__builtin_popcount(mask)) != count) continue;
            std::vector<Shift> shifts;
            for (std::size_t index = 0; index < candidates.size(); ++index) if ((mask & (1U << index)) != 0) shifts.push_back(candidates[index]);
            if (characterResidual(aliases,shifts) < 1e-14) return shifts;
        }
    }
    fail("The four tensor half-cell shifts did not cancel the derived alias set.");
}

Complex spectrumValue(const Spectrum& spectrum, Mode mode) {
    const auto found = spectrum.find(mode);
    return found == spectrum.end() ? Complex{} : found->second;
}

Spectrum denseHermitianSpectrum(const ModeSet& retained, std::size_t channel) {
    Spectrum result;
    for (const auto mode : retained) {
        if (result.find(mode) != result.end()) continue;
        const double index = static_cast<double>(channel + 1);
        const double k = static_cast<double>(mode.k);
        const double l = static_cast<double>(mode.l);
        if (mode.k == 0 && mode.l == 0) {
            result[mode] = Complex(0.13*std::sin(0.7*index),0.0);
            continue;
        }
        const Complex value(0.07*std::sin(0.31*index + 0.19*k - 0.23*l),0.05*std::cos(0.17*index - 0.29*k + 0.11*l));
        result[mode] = value;
        result[-mode] = std::conj(value);
    }
    return result;
}

std::vector<Spectrum> operatorInputs(const ModeSet& retained, std::size_t outputCount) {
    const auto inputCount = 3 + 4*outputCount;
    std::vector<Spectrum> inputs(inputCount);
    for (std::size_t channel = outputCount; channel < inputCount; ++channel) inputs[channel] = denseHermitianSpectrum(retained,channel);
    return inputs;
}

std::vector<Spectrum> directRetainedConvolution(const ModeSet& retained, const std::vector<Spectrum>& inputs, std::size_t outputCount) {
    std::vector<Spectrum> outputs(outputCount);
    for (std::size_t target = 0; target < outputCount; ++target) {
        const auto derivative = outputCount + 3 + 3*target;
        for (const auto outputMode : retained) {
            Complex value;
            for (const auto velocityMode : retained) {
                const auto derivativeMode = outputMode - velocityMode;
                if (retained.find(derivativeMode) == retained.end()) continue;
                value -= spectrumValue(inputs[outputCount],velocityMode)*spectrumValue(inputs[derivative],derivativeMode);
                value -= spectrumValue(inputs[outputCount+1],velocityMode)*spectrumValue(inputs[derivative+1],derivativeMode);
                value -= spectrumValue(inputs[outputCount+2],velocityMode)*spectrumValue(inputs[derivative+2],derivativeMode);
            }
            outputs[target][outputMode] = value;
        }
    }
    return outputs;
}

Complex inverseDFTValue(const Spectrum& spectrum, double x, double y, std::int64_t Mx, std::int64_t My) {
    Complex value;
    for (const auto& entry : spectrum) {
        const auto angle = 2.0*pi*(static_cast<double>(entry.first.k)*x/static_cast<double>(Mx) + static_cast<double>(entry.first.l)*y/static_cast<double>(My));
        value += entry.second*std::polar(1.0,angle);
    }
    return value;
}

std::vector<Spectrum> gridConvolution(
    const ModeSet& retained,
    const std::vector<Spectrum>& inputs,
    std::size_t outputCount,
    std::int64_t Mx,
    std::int64_t My,
    const std::vector<Shift>& shifts) {
    const auto pointCount = static_cast<std::size_t>(Mx*My);
    std::vector<Spectrum> outputs(outputCount);
    for (const auto mode : retained) for (auto& output : outputs) output[mode] = {};
    for (const auto shift : shifts) {
        std::vector<std::vector<Complex>> spatial(inputs.size(),std::vector<Complex>(pointCount));
        for (std::size_t channel = outputCount; channel < inputs.size(); ++channel) {
            for (std::int64_t y = 0; y < My; ++y) for (std::int64_t x = 0; x < Mx; ++x) {
                spatial[channel][static_cast<std::size_t>(x+Mx*y)] = inverseDFTValue(inputs[channel],static_cast<double>(x)+shift.x,static_cast<double>(y)+shift.y,Mx,My);
            }
        }
        std::vector<std::vector<Complex>> products(outputCount,std::vector<Complex>(pointCount));
        for (std::size_t target = 0; target < outputCount; ++target) {
            const auto derivative = outputCount + 3 + 3*target;
            for (std::size_t point = 0; point < pointCount; ++point) {
                products[target][point] = -(spatial[outputCount][point]*spatial[derivative][point]
                    + spatial[outputCount+1][point]*spatial[derivative+1][point]
                    + spatial[outputCount+2][point]*spatial[derivative+2][point]);
            }
        }
        const auto normalization = 1.0/(static_cast<double>(pointCount)*static_cast<double>(shifts.size()));
        for (std::size_t target = 0; target < outputCount; ++target) {
            for (const auto outputMode : retained) {
                Complex value;
                for (std::int64_t y = 0; y < My; ++y) for (std::int64_t x = 0; x < Mx; ++x) {
                    const auto angle = -2.0*pi*(static_cast<double>(outputMode.k)*(static_cast<double>(x)+shift.x)/static_cast<double>(Mx)
                        + static_cast<double>(outputMode.l)*(static_cast<double>(y)+shift.y)/static_cast<double>(My));
                    value += products[target][static_cast<std::size_t>(x+Mx*y)]*std::polar(1.0,angle);
                }
                outputs[target][outputMode] += normalization*value;
            }
        }
    }
    return outputs;
}

double relativeInfinityError(const std::vector<Spectrum>& actual, const std::vector<Spectrum>& reference, const ModeSet& retained) {
    double difference = 0.0;
    double scale = 0.0;
    for (std::size_t target = 0; target < reference.size(); ++target) for (const auto mode : retained) {
        const auto expected = spectrumValue(reference[target],mode);
        difference = std::max(difference,std::abs(spectrumValue(actual[target],mode)-expected));
        scale = std::max(scale,std::abs(expected));
    }
    return difference/std::max(scale,std::numeric_limits<double>::min());
}

std::string aliasString(const AliasSet& aliases) {
    std::ostringstream stream;
    stream << '[';
    bool first = true;
    for (const auto alias : aliases) {
        if (!first) stream << ',';
        first = false;
        stream << '(' << alias.x << ',' << alias.y << ')';
    }
    stream << ']';
    return stream.str();
}

void verifyOriginalBoundaries(const ModeSet& retained, std::size_t Nx, std::size_t Ny) {
    require(retained.find({0,0}) != retained.end(),"The retained set omitted the zero mode.");
    for (const auto mode : retained) {
        if (Nx % 2 == 0) require(mode.k != -static_cast<std::int64_t>(Nx/2),"A retained mode lies on the original x Nyquist boundary.");
        if (Ny % 2 == 0) require(mode.l != -static_cast<std::int64_t>(Ny/2),"A retained mode lies on the original y Nyquist boundary.");
    }
}

void verifyAxisChainsAndMinimalGrid(const ModeSet& retained, std::int64_t K, std::int64_t L, std::int64_t Mx, std::int64_t My) {
    for (std::int64_t k = -K; k <= K; ++k) require(retained.find({k,0}) != retained.end(),"The radial set does not contain its complete k-axis chain.");
    for (std::int64_t l = -L; l <= L; ++l) require(retained.find({0,l}) != retained.end(),"The radial set does not contain its complete l-axis chain.");
    require(injectiveOnGrid(retained,Mx,My),"The proposed minimal phase grid aliases retained inputs.");
    if (K > 0) require(!injectiveOnGrid(retained,Mx-1,My),"The phase grid is not minimal in x.");
    if (L > 0) require(!injectiveOnGrid(retained,Mx,My-1),"The phase grid is not minimal in y.");
}

} // namespace

int main() {
    try {
        const std::array<Aspect,3> aspects{{
            {15000.0,15000.0,"square-domain"},
            {15000.0,11000.0,"short-y-domain"},
            {11000.0,15000.0,"long-y-domain"}}};
        std::vector<GeometryCase> geometries;
        for (std::size_t Nx = 2; Nx <= 9; ++Nx) for (std::size_t Ny = 2; Ny <= 9; ++Ny) for (std::size_t aspect = 0; aspect < aspects.size(); ++aspect) geometries.push_back({Nx,Ny,aspect});
        std::stable_sort(geometries.begin(),geometries.end(),[](const GeometryCase& first, const GeometryCase& second) {
            return std::make_tuple(first.Nx*first.Ny,first.Nx,first.Ny,first.aspect) < std::make_tuple(second.Nx*second.Ny,second.Nx,second.Ny,second.aspect);
        });

        AliasSet aggregateAliases;
        std::array<std::size_t,5> shiftCounts{};
        double maximumPhaseError = 0.0;
        double maximumExplicitError = 0.0;
        double maximumTwoDiagonalResidual = 0.0;
        std::size_t operatorCases = 0;
        for (const auto geometry : geometries) {
            for (const bool hydrostatic : {true,false}) {
                WVTransformConstantStratificationDescriptor descriptor;
                const auto status = WVTransformConstantStratificationDescriptor::create(configuration(geometry,aspects[geometry.aspect],hydrostatic),descriptor);
                require(static_cast<bool>(status),"Descriptor construction failed: " + status.message);
                const auto retained = retainedModes(descriptor);
                verifyOriginalBoundaries(retained,geometry.Nx,geometry.Ny);
                const auto K = maximumAbsoluteK(retained);
                const auto L = maximumAbsoluteL(retained);
                const auto Mx = 2*K+1;
                const auto My = 2*L+1;
                verifyAxisChainsAndMinimalGrid(retained,K,L,Mx,My);

                const auto aliases = aliasSet(retained,Mx,My);
                for (const auto alias : aliases) {
                    require(std::abs(alias.x) <= 1 && std::abs(alias.y) <= 1,"A derived alias lies outside the complete nearest-image set.");
                    aggregateAliases.insert(alias);
                }
                const auto shifts = minimumTensorHalfShiftSet(aliases);
                ++shiftCounts[shifts.size()];
                require(characterResidual(aliases,shifts) < 1e-14,"The selected shift set does not cancel every derived alias.");
                maximumTwoDiagonalResidual = std::max(maximumTwoDiagonalResidual,characterResidual(aliases,{{0.0,0.0},{0.5,0.5}}));

                const auto explicitMx = 3*K+1;
                const auto explicitMy = 3*L+1;
                require(aliasSet(retained,explicitMx,explicitMy).empty(),"The native explicit grid is not alias-free.");
                const auto outputCount = hydrostatic ? 3U : 4U;
                const auto inputs = operatorInputs(retained,outputCount);
                const auto direct = directRetainedConvolution(retained,inputs,outputCount);
                const auto explicitPadding = gridConvolution(retained,inputs,outputCount,explicitMx,explicitMy,{{0.0,0.0}});
                const auto phaseShift = gridConvolution(retained,inputs,outputCount,Mx,My,shifts);
                const auto explicitError = relativeInfinityError(explicitPadding,direct,retained);
                const auto phaseError = relativeInfinityError(phaseShift,direct,retained);
                maximumExplicitError = std::max(maximumExplicitError,explicitError);
                maximumPhaseError = std::max(maximumPhaseError,phaseError);
                ++operatorCases;
                if (explicitError > 1e-12 || phaseError > 1e-12) {
                    std::ostringstream message;
                    message << std::setprecision(17)
                            << "Smallest exactness counterexample: Nx=" << geometry.Nx << ", Ny=" << geometry.Ny
                            << ", aspect=" << aspects[geometry.aspect].name << ", hydrostatic=" << (hydrostatic ? "true" : "false")
                            << ", K=" << K << ", L=" << L << ", aliases=" << aliasString(aliases)
                            << ", shifts=" << shifts.size() << ", explicitError=" << explicitError << ", phaseError=" << phaseError;
                    fail(message.str());
                }
            }
        }

        const AliasSet completeNearestImages{{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}};
        require(aggregateAliases == completeNearestImages,"The enumerated radial cases did not exercise the complete eight-image alias set: " + aliasString(aggregateAliases));
        require(shiftCounts[4] > 0,"No enumerated radial case required the proven four-shift minimum.");

        std::cout << std::setprecision(17)
                  << "issue154 exactness gate passed\n"
                  << "geometries=" << geometries.size() << " operatorCases=" << operatorCases << '\n'
                  << "aggregateAliasSet=" << aliasString(aggregateAliases) << '\n'
                  << "minimalShiftCounts={1:" << shiftCounts[1] << ",2:" << shiftCounts[2] << ",3:" << shiftCounts[3] << ",4:" << shiftCounts[4] << "}\n"
                  << "maximumExplicitRelativeInfinityError=" << maximumExplicitError << '\n'
                  << "maximumPhaseRelativeInfinityError=" << maximumPhaseError << '\n'
                  << "maximumTwoDiagonalAliasResidual=" << maximumTwoDiagonalResidual << '\n'
                  << "lifecycle=passed\n";
        return 0;
    } catch (const std::exception& exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
