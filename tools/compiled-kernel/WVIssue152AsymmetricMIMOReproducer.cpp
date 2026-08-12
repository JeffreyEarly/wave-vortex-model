#include "convolve.h"
#include "direct.h"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

using Channel = std::vector<Complex>;
using Channels = std::vector<Channel>;

struct Comparison {
    double namedError = std::numeric_limits<double>::infinity();
    double bestError = std::numeric_limits<double>::infinity();
    std::size_t bestInputShift = 0;
    std::size_t bestOutputShift = 0;
};

std::size_t shifted(std::size_t channel, std::size_t inputCount, std::size_t shift) {
    return (channel + shift) % inputCount;
}

void productChannels(std::size_t output, std::size_t inputCount, std::size_t outputCount,
                     std::size_t shift, std::size_t& firstA, std::size_t& firstB,
                     std::size_t& secondA, std::size_t& secondB) {
    const auto physicalCount = inputCount - outputCount;
    firstA = shifted(outputCount + (2 * output) % physicalCount,inputCount,shift);
    firstB = shifted(outputCount + (2 * output + 1) % physicalCount,inputCount,shift);
    secondA = shifted(outputCount + (3 * output + 2) % physicalCount,inputCount,shift);
    secondB = shifted(outputCount + (3 * output + 4) % physicalCount,inputCount,shift);
}

void namedComplexMultiplier(Complex** values, std::size_t count, fftwpp::Indices* indices, std::size_t) {
    const auto inputCount = indices->fft->app.A;
    const auto outputCount = indices->fft->app.B;
    for (std::size_t index = 0; index < count; ++index) {
        Complex output[4]{};
        for (std::size_t target = 0; target < outputCount; ++target) {
            std::size_t firstA, firstB, secondA, secondB;
            productChannels(target,inputCount,outputCount,0,firstA,firstB,secondA,secondB);
            output[target] = static_cast<double>(target + 1) * values[firstA][index] * values[firstB][index]
                - static_cast<double>(target + 2) * values[secondA][index] * values[secondB][index];
        }
        for (std::size_t target = 0; target < outputCount; ++target) values[target][index] = output[target];
    }
}

void namedRealMultiplier(Complex** values, std::size_t count, fftwpp::Indices* indices, std::size_t) {
    const auto inputCount = indices->fft->app.A;
    const auto outputCount = indices->fft->app.B;
    double* arrays[19]{};
    for (std::size_t channel = 0; channel < inputCount; ++channel) arrays[channel] = reinterpret_cast<double*>(values[channel]);
    for (std::size_t index = 0; index < count; ++index) {
        double output[4]{};
        for (std::size_t target = 0; target < outputCount; ++target) {
            std::size_t firstA, firstB, secondA, secondB;
            productChannels(target,inputCount,outputCount,0,firstA,firstB,secondA,secondB);
            output[target] = static_cast<double>(target + 1) * arrays[firstA][index] * arrays[firstB][index]
                - static_cast<double>(target + 2) * arrays[secondA][index] * arrays[secondB][index];
        }
        for (std::size_t target = 0; target < outputCount; ++target) arrays[target][index] = output[target];
    }
}

Channels copyChannels(Complex** values, std::size_t inputCount, std::size_t length) {
    Channels copy(inputCount,Channel(length));
    for (std::size_t channel = 0; channel < inputCount; ++channel)
        std::copy(values[channel],values[channel] + length,copy[channel].begin());
    return copy;
}

double relativeError(const Channels& actual, const Channels& expected, std::size_t outputShift) {
    double difference = 0.0;
    double scale = 0.0;
    const auto outputCount = actual.size();
    for (std::size_t output = 0; output < outputCount; ++output) {
        const auto& reference = expected[(output + outputShift) % outputCount];
        for (std::size_t index = 0; index < actual[output].size(); ++index) {
            difference = std::max(difference,abs(actual[output][index] - reference[index]));
            scale = std::max(scale,abs(reference[index]));
        }
    }
    return difference / std::max(scale,std::numeric_limits<double>::min());
}

template<class Oracle>
Comparison compareAllMappings(const Channels& actual, std::size_t inputCount, std::size_t outputCount, Oracle oracle) {
    Comparison result;
    for (std::size_t inputShift = 0; inputShift < inputCount; ++inputShift) {
        const auto expected = oracle(inputShift);
        for (std::size_t outputShift = 0; outputShift < outputCount; ++outputShift) {
            const auto error = relativeError(actual,expected,outputShift);
            if (inputShift == 0 && outputShift == 0) result.namedError = error;
            if (error < result.bestError) {
                result.bestError = error;
                result.bestInputShift = inputShift;
                result.bestOutputShift = outputShift;
            }
        }
    }
    return result;
}

Channels centeredOracle(const Channels& input, std::size_t outputCount, std::size_t inputShift) {
    const auto inputCount = input.size();
    const auto length = input.front().size();
    Channels expected(outputCount,Channel(length));
    Channel product(length);
    fftwpp::directconv<Complex> direct(length);
    for (std::size_t output = 0; output < outputCount; ++output) {
        std::size_t firstA, firstB, secondA, secondB;
        productChannels(output,inputCount,outputCount,inputShift,firstA,firstB,secondA,secondB);
        direct.convolveC(product.data(),const_cast<Complex*>(input[firstA].data()),const_cast<Complex*>(input[firstB].data()));
        for (std::size_t index = 0; index < length; ++index) expected[output][index] += static_cast<double>(output + 1) * product[index];
        direct.convolveC(product.data(),const_cast<Complex*>(input[secondA].data()),const_cast<Complex*>(input[secondB].data()));
        for (std::size_t index = 0; index < length; ++index) expected[output][index] -= static_cast<double>(output + 2) * product[index];
    }
    return expected;
}

Channels hermitianOracle(const Channels& input, std::size_t outputCount, std::size_t inputShift) {
    const auto inputCount = input.size();
    const auto length = input.front().size();
    Channels expected(outputCount,Channel(length));
    Channel product(length);
    fftwpp::directconvh direct(length);
    for (std::size_t output = 0; output < outputCount; ++output) {
        std::size_t firstA, firstB, secondA, secondB;
        productChannels(output,inputCount,outputCount,inputShift,firstA,firstB,secondA,secondB);
        direct.convolve(product.data(),const_cast<Complex*>(input[firstA].data()),const_cast<Complex*>(input[firstB].data()));
        for (std::size_t index = 0; index < length; ++index) expected[output][index] += static_cast<double>(output + 1) * product[index];
        direct.convolve(product.data(),const_cast<Complex*>(input[secondA].data()),const_cast<Complex*>(input[secondB].data()));
        for (std::size_t index = 0; index < length; ++index) expected[output][index] -= static_cast<double>(output + 2) * product[index];
    }
    return expected;
}

Channels hermitian2Oracle(const Channels& input, std::size_t outputCount, std::size_t inputShift,
                          std::size_t centeredCount, std::size_t hermitianCount) {
    const auto inputCount = input.size();
    Channels expected(outputCount,Channel(centeredCount * hermitianCount));
    Channel product(centeredCount * hermitianCount);
    fftwpp::directconvh2 direct((centeredCount + 1) / 2,hermitianCount,centeredCount % 2,hermitianCount);
    for (std::size_t output = 0; output < outputCount; ++output) {
        std::size_t firstA, firstB, secondA, secondB;
        productChannels(output,inputCount,outputCount,inputShift,firstA,firstB,secondA,secondB);
        direct.convolve(product.data(),const_cast<Complex*>(input[firstA].data()),const_cast<Complex*>(input[firstB].data()),false);
        for (std::size_t index = 0; index < product.size(); ++index) expected[output][index] += static_cast<double>(output + 1) * product[index];
        direct.convolve(product.data(),const_cast<Complex*>(input[secondA].data()),const_cast<Complex*>(input[secondB].data()),false);
        for (std::size_t index = 0; index < product.size(); ++index) expected[output][index] -= static_cast<double>(output + 2) * product[index];
    }
    return expected;
}

void initializeCentered(Complex** values, std::size_t inputCount, std::size_t length) {
    for (std::size_t channel = 0; channel < inputCount; ++channel)
        for (std::size_t index = 0; index < length; ++index)
            values[channel][index] = Complex(0.11 * static_cast<double>((channel + 1) * (index + 2)),
                                             0.07 * static_cast<double>((channel + 3) * (2 * index + 1)));
}

void initializeHermitian(Complex** values, std::size_t inputCount, std::size_t length) {
    for (std::size_t channel = 0; channel < inputCount; ++channel) {
        for (std::size_t index = 0; index < length; ++index)
            values[channel][index] = Complex(0.13 * static_cast<double>((channel + 2) * (index + 1)),
                                             0.05 * static_cast<double>((channel + 1) * (index + 3)));
        fftwpp::HermitianSymmetrize(values[channel]);
    }
}

void initializeHermitian2(Complex** values, std::size_t inputCount, std::size_t centeredCount,
                          std::size_t hermitianCount) {
    for (std::size_t channel = 0; channel < inputCount; ++channel) {
        for (std::size_t x = 0; x < centeredCount; ++x)
            for (std::size_t y = 0; y < hermitianCount; ++y)
                values[channel][x * hermitianCount + y] = Complex(
                    0.017 * static_cast<double>((channel + 2) * (x + 1) * (y + 2)),
                    0.009 * static_cast<double>((channel + 1) * (2 * x + y + 3)));
        fftwpp::HermitianSymmetrizeX((centeredCount + 1) / 2,hermitianCount,centeredCount / 2,values[channel],hermitianCount);
    }
}

Comparison runCentered(std::size_t inputCount, std::size_t outputCount, std::size_t innerLength) {
    constexpr std::size_t length = 8;
    constexpr std::size_t paddedLength = 12;
    auto** values = utils::ComplexAlign(inputCount,length);
    initializeCentered(values,inputCount,length);
    const auto input = copyChannels(values,inputCount,length);
    fftwpp::Application application(inputCount,outputCount,namedComplexMultiplier,1,false,innerLength,1,0);
    fftwpp::fftPadCentered fft(length,paddedLength,application);
    if (fft.p != 2 || fft.q != 3) throw std::runtime_error("Unexpected centered residue schedule.");
    fftwpp::Convolution convolution(&fft);
    convolution.convolve(values);
    Channels actual(outputCount,Channel(length));
    for (std::size_t output = 0; output < outputCount; ++output)
        std::copy(values[output],values[output] + length,actual[output].begin());
    utils::deleteAlign(values[0]);
    delete [] values;
    return compareAllMappings(actual,inputCount,outputCount,[&](std::size_t shift) { return centeredOracle(input,outputCount,shift); });
}

Comparison runHermitian(std::size_t inputCount, std::size_t outputCount, std::size_t innerLength) {
    constexpr std::size_t realLength = 8;
    constexpr std::size_t paddedLength = 12;
    constexpr std::size_t hermitianCount = realLength / 2;
    auto** values = utils::ComplexAlign(inputCount,hermitianCount);
    initializeHermitian(values,inputCount,hermitianCount);
    const auto input = copyChannels(values,inputCount,hermitianCount);
    fftwpp::Application application(inputCount,outputCount,namedRealMultiplier,1,false,innerLength,2,0);
    fftwpp::fftPadHermitian fft(realLength,paddedLength,application);
    if (fft.p != 2 || fft.q != 3 || !fft.loop2()) throw std::runtime_error("Unexpected Hermitian two-loop residue schedule.");
    fftwpp::Convolution convolution(&fft);
    convolution.convolve(values);
    Channels actual(outputCount,Channel(hermitianCount));
    for (std::size_t output = 0; output < outputCount; ++output)
        std::copy(values[output],values[output] + hermitianCount,actual[output].begin());
    utils::deleteAlign(values[0]);
    delete [] values;
    return compareAllMappings(actual,inputCount,outputCount,[&](std::size_t shift) { return hermitianOracle(input,outputCount,shift); });
}

Comparison runHermitian2(std::size_t inputCount, std::size_t outputCount, std::size_t innerLength) {
    constexpr std::size_t centeredCount = 8;
    constexpr std::size_t realHermitianLength = 8;
    constexpr std::size_t hermitianCount = realHermitianLength / 2;
    constexpr std::size_t paddedLength = 12;
    auto** values = utils::ComplexAlign(inputCount,centeredCount * hermitianCount);
    initializeHermitian2(values,inputCount,centeredCount,hermitianCount);
    const auto input = copyChannels(values,inputCount,centeredCount * hermitianCount);
    fftwpp::Application centeredApplication(inputCount,outputCount,fftwpp::multNone,1,false,innerLength,1,0);
    fftwpp::fftPadCentered centeredFFT(centeredCount,paddedLength,centeredApplication,hermitianCount,hermitianCount);
    fftwpp::Application hermitianApplication(inputCount,outputCount,namedRealMultiplier,centeredApplication,innerLength,2,0);
    fftwpp::fftPadHermitian hermitianFFT(realHermitianLength,paddedLength,hermitianApplication);
    if (centeredFFT.p != 2 || centeredFFT.q != 3 || hermitianFFT.p != 2 || hermitianFFT.q != 3 || !hermitianFFT.loop2())
        throw std::runtime_error("Unexpected 2-D centered/Hermitian residue schedule.");
    fftwpp::Convolution2 convolution(&centeredFFT,&hermitianFFT);
    convolution.convolve(values);
    Channels actual(outputCount,Channel(centeredCount * hermitianCount));
    for (std::size_t output = 0; output < outputCount; ++output)
        std::copy(values[output],values[output] + centeredCount * hermitianCount,actual[output].begin());
    utils::deleteAlign(values[0]);
    delete [] values;
    return compareAllMappings(actual,inputCount,outputCount,[&](std::size_t shift) {
        return hermitian2Oracle(input,outputCount,shift,centeredCount,hermitianCount);
    });
}

void report(const std::string& dimension, const std::string& schedule, std::size_t inputCount,
            std::size_t outputCount, const Comparison& comparison, bool& allCorrect) {
    constexpr double tolerance = 1e-12;
    const bool correct = comparison.namedError <= tolerance;
    allCorrect = allCorrect && correct;
    std::cout << "case=" << dimension << '-' << schedule
              << " arity=" << inputCount << "->" << outputCount
              << " namedError=" << comparison.namedError
              << " bestError=" << comparison.bestError
              << " bestInputShift=" << comparison.bestInputShift
              << " bestOutputShift=" << comparison.bestOutputShift
              << " status=" << (correct ? "PASS" : "FAIL") << '\n';
}

} // namespace

int main(int argc, char** argv) {
    try {
        const bool requireCorrect = argc == 2 && std::string(argv[1]) == "--require-correct";
        if (argc > 2 || (argc == 2 && !requireCorrect)) throw std::invalid_argument("Usage: reproducer [--require-correct]");
        fftwpp::fftw::maxthreads = 1;
        std::cout << std::scientific << std::setprecision(6);
        bool allCorrect = true;
        for (const auto& schedule : {std::pair<const char*,std::size_t>{"implicit",4},{"hybrid",5}}) {
            report("1d-centered",schedule.first,5,2,runCentered(5,2,schedule.second),allCorrect);
            report("1d-hermitian",schedule.first,5,2,runHermitian(5,2,schedule.second),allCorrect);
            report("2d-centered-hermitian",schedule.first,5,2,runHermitian2(5,2,schedule.second),allCorrect);
            report("2d-centered-hermitian",schedule.first,15,3,runHermitian2(15,3,schedule.second),allCorrect);
            report("2d-centered-hermitian",schedule.first,19,4,runHermitian2(19,4,schedule.second),allCorrect);
        }
        return requireCorrect && !allCorrect ? 1 : 0;
    } catch (const std::exception& exception) {
        std::cerr << "issue152 reproducer failed: " << exception.what() << '\n';
        return 2;
    }
}
