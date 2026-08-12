#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <thread>
#include <vector>

namespace {

struct ComplexValue {
    double real;
    double imag;
};

constexpr std::size_t Nx = 256;
constexpr std::size_t Ny = 256;
constexpr std::size_t Nz = 65;
constexpr std::size_t Nj = 42;
constexpr std::size_t channels = 4;
constexpr std::size_t Nkl = 11439;
constexpr std::size_t halfRows = (Nx / 2 + 1) * Ny;
constexpr std::size_t values = halfRows * Nz * channels;
constexpr std::size_t halfSpectrumBytes = values * sizeof(ComplexValue);
constexpr std::size_t hydroRealScratchBytes = Nx * Ny * Nz * 8 * sizeof(double);
constexpr std::size_t nonhydroRealScratchBytes = Nx * Ny * Nz * 9 * sizeof(double);
constexpr std::size_t stateOrFluxBytes = 3 * Nj * Nkl * sizeof(ComplexValue);
constexpr std::size_t hydroCompleteNanoseconds = 56283250;
constexpr std::size_t nonhydroCompleteNanoseconds = 72076417;
constexpr std::size_t hydroHorizontalNanoseconds = 17016710;
constexpr std::size_t nonhydroHorizontalNanoseconds = 22225292;

std::size_t verticalIndex(std::size_t row, std::size_t z, std::size_t channel) {
    return z + Nz * channel + Nz * channels * row;
}

std::size_t horizontalIndex(std::size_t row, std::size_t z, std::size_t channel) {
    return row + halfRows * z + halfRows * Nz * channel;
}

void packRange(const ComplexValue* source, ComplexValue* destination, std::size_t zBegin, std::size_t zEnd) {
    for (std::size_t channel = 0; channel < channels; ++channel) {
        for (std::size_t z = zBegin; z < zEnd; ++z) {
            for (std::size_t row = 0; row < halfRows; ++row) {
                destination[horizontalIndex(row,z,channel)] = source[verticalIndex(row,z,channel)];
            }
        }
    }
}

void unpackRange(const ComplexValue* source, ComplexValue* destination, std::size_t zBegin, std::size_t zEnd) {
    for (std::size_t channel = 0; channel < channels; ++channel) {
        for (std::size_t z = zBegin; z < zEnd; ++z) {
            for (std::size_t row = 0; row < halfRows; ++row) {
                destination[verticalIndex(row,z,channel)] = source[horizontalIndex(row,z,channel)];
            }
        }
    }
}

template <typename Operation>
void forEachZBlock(std::size_t blockSize, std::size_t workers, Operation&& operation) {
    const auto clippedBlock = std::min(blockSize,Nz);
    for (std::size_t begin = 0; begin < Nz; begin += clippedBlock) {
        const auto end = std::min(begin + clippedBlock,Nz);
        if (workers == 1 || end - begin == 1) {
            operation(begin,end);
        } else {
            const auto middle = begin + (end - begin) / 2;
            std::thread second([&]() { operation(middle,end); });
            operation(begin,middle);
            second.join();
        }
    }
}

double median(std::vector<double> valuesToSort) {
    std::sort(valuesToSort.begin(),valuesToSort.end());
    return valuesToSort[valuesToSort.size()/2];
}

double relativeError(const std::vector<ComplexValue>& actual, const std::vector<ComplexValue>& expected) {
    double maximumDifference = 0.0;
    double maximumExpected = 0.0;
    for (std::size_t i = 0; i < actual.size(); ++i) {
        maximumDifference = std::max(maximumDifference,std::hypot(actual[i].real-expected[i].real,actual[i].imag-expected[i].imag));
        maximumExpected = std::max(maximumExpected,std::hypot(expected[i].real,expected[i].imag));
    }
    return maximumDifference / std::max(maximumExpected,std::numeric_limits<double>::min());
}

double optimisticImprovement(double completeSeconds, double horizontalSeconds, double boundarySeconds) {
    return (horizontalSeconds - boundarySeconds) / completeSeconds;
}

void printResult(std::size_t blockSize, std::size_t workers, double packSeconds, double unpackSeconds, double error) {
    // nonlinearFlux crosses from vertical to horizontal storage for the four-channel
    // reconstruction and every three-channel derivative, then crosses back for the
    // final three- or four-channel projection.
    const double hydroBoundarySeconds = 3.25 * packSeconds + 0.75 * unpackSeconds;
    const double nonhydroBoundarySeconds = 4.0 * packSeconds + unpackSeconds;
    const double hydroSeconds = 1e-9 * static_cast<double>(hydroCompleteNanoseconds);
    const double nonhydroSeconds = 1e-9 * static_cast<double>(nonhydroCompleteNanoseconds);
    const double hydroHorizontalSeconds = 1e-9 * static_cast<double>(hydroHorizontalNanoseconds);
    const double nonhydroHorizontalSeconds = 1e-9 * static_cast<double>(nonhydroHorizontalNanoseconds);
    std::cout << "{\"zBlock\":" << blockSize
              << ",\"workers\":" << workers
              << ",\"packMedianSeconds\":" << packSeconds
              << ",\"unpackMedianSeconds\":" << unpackSeconds
              << ",\"roundTripMedianSeconds\":" << packSeconds + unpackSeconds
              << ",\"bytesMovedPerPack\":" << 2 * halfSpectrumBytes
              << ",\"bytesMovedPerRoundTrip\":" << 4 * halfSpectrumBytes
              << ",\"hydroBoundarySeconds\":" << hydroBoundarySeconds
              << ",\"nonhydroBoundarySeconds\":" << nonhydroBoundarySeconds
              << ",\"hydroBoundaryBytesMoved\":" << 8 * halfSpectrumBytes
              << ",\"nonhydroBoundaryBytesMoved\":" << 10 * halfSpectrumBytes
              << ",\"maximumRelativeError\":" << error
              << ",\"optimisticHydroCompleteImprovement\":" << optimisticImprovement(hydroSeconds,hydroHorizontalSeconds,hydroBoundarySeconds)
              << ",\"optimisticNonhydroCompleteImprovement\":" << optimisticImprovement(nonhydroSeconds,nonhydroHorizontalSeconds,nonhydroBoundarySeconds)
              << "}\n";
}

} // namespace

int main() {
    std::vector<ComplexValue> vertical(values);
    std::vector<ComplexValue> horizontal(values);
    std::vector<ComplexValue> roundTrip(values);
    for (std::size_t i = 0; i < values; ++i) vertical[i] = {static_cast<double>(i % 1009) / 1009.0,-static_cast<double>(i % 1013) / 1013.0};
    const std::size_t blockSizes[] = {1,4,8,16,Nz};
    const std::size_t workerCounts[] = {1,2};
    constexpr std::size_t sampleCount = 3;
    std::cout << std::setprecision(17);
    std::cout << "{\"kind\":\"metadata\",\"Nx\":" << Nx << ",\"Ny\":" << Ny << ",\"Nz\":" << Nz << ",\"Nj\":" << Nj << ",\"Nkl\":" << Nkl
              << ",\"channels\":" << channels << ",\"halfRows\":" << halfRows << ",\"halfSpectrumBytes\":" << halfSpectrumBytes
              << ",\"baselineHydroScratchBytes\":" << halfSpectrumBytes + hydroRealScratchBytes
              << ",\"baselineNonhydroScratchBytes\":" << halfSpectrumBytes + nonhydroRealScratchBytes
              << ",\"baselineHydroKnownMaximumLiveBytes\":" << halfSpectrumBytes + hydroRealScratchBytes + stateOrFluxBytes
              << ",\"baselineNonhydroKnownMaximumLiveBytes\":" << halfSpectrumBytes + nonhydroRealScratchBytes + stateOrFluxBytes
              << ",\"baselineHydroCompleteSeconds\":" << 1e-9 * static_cast<double>(hydroCompleteNanoseconds)
              << ",\"baselineNonhydroCompleteSeconds\":" << 1e-9 * static_cast<double>(nonhydroCompleteNanoseconds)
              << ",\"baselineHydroHorizontalSeconds\":" << 1e-9 * static_cast<double>(hydroHorizontalNanoseconds)
              << ",\"baselineNonhydroHorizontalSeconds\":" << 1e-9 * static_cast<double>(nonhydroHorizontalNanoseconds)
              << ",\"addedPersistentBytesForPackLayout\":" << halfSpectrumBytes
              << ",\"packLayoutHydroKnownMaximumLiveBytes\":" << 2 * halfSpectrumBytes + hydroRealScratchBytes + stateOrFluxBytes
              << ",\"packLayoutNonhydroKnownMaximumLiveBytes\":" << 2 * halfSpectrumBytes + nonhydroRealScratchBytes + stateOrFluxBytes
              << ",\"baselineHorizontalExecutionsHydro\":7,\"baselineVerticalExecutionsHydro\":11"
              << ",\"baselineHorizontalExecutionsNonhydro\":9,\"baselineVerticalExecutionsNonhydro\":14"
              << ",\"candidateExecutionCountChange\":0,\"candidatePlanCountChange\":0}\n";
    for (const auto workers : workerCounts) {
        for (const auto blockSize : blockSizes) {
            forEachZBlock(blockSize,workers,[&](auto begin, auto end) { packRange(vertical.data(),horizontal.data(),begin,end); });
            forEachZBlock(blockSize,workers,[&](auto begin, auto end) { unpackRange(horizontal.data(),roundTrip.data(),begin,end); });
            const auto error = relativeError(roundTrip,vertical);
            std::vector<double> packSamples;
            std::vector<double> unpackSamples;
            for (std::size_t sample = 0; sample < sampleCount; ++sample) {
                auto start = std::chrono::steady_clock::now();
                forEachZBlock(blockSize,workers,[&](auto begin, auto end) { packRange(vertical.data(),horizontal.data(),begin,end); });
                packSamples.push_back(std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count());
                start = std::chrono::steady_clock::now();
                forEachZBlock(blockSize,workers,[&](auto begin, auto end) { unpackRange(horizontal.data(),roundTrip.data(),begin,end); });
                unpackSamples.push_back(std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count());
            }
            printResult(blockSize,workers,median(packSamples),median(unpackSamples),error);
        }
    }
    return 0;
}
