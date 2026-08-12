#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVForcingEngine.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <iomanip>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

void component(const std::vector<WVComplex64>& values, std::size_t offset, std::size_t count, bool imaginary) {
    std::cout << '[';
    for (std::size_t index = 0; index < count; ++index) {
        if (index != 0) std::cout << ',';
        const auto value = values[offset+index];
        std::cout << (imaginary ? value.imag : value.real);
    }
    std::cout << ']';
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "usage: wv_portable_forcing_inspect checkpoint.nc\n";
        return 2;
    }
    WVCheckpoint checkpoint;
    auto checkpointStatus = WVCheckpointReader::read(argv[1],checkpoint);
    if (!checkpointStatus) {
        std::cerr << checkpointStatus.message << '\n';
        return 3;
    }
    std::unique_ptr<WVConstantStratificationForcingEngine> engine;
    auto status = WVConstantStratificationForcingEngine::create(checkpoint.configuration,checkpoint.forcingSchedule,std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),engine);
    if (!status) {
        std::cerr << status.message << '\n';
        return 4;
    }
    const auto& descriptor = engine->kernel().descriptor();
    for (std::size_t iMode = 0; iMode < descriptor.Nkl(); ++iMode) {
        const bool horizontalMean = descriptor.fourierModes()[iMode].Kh == 0.0;
        for (std::size_t iJ = 0; iJ < checkpoint.configuration.Nj; ++iJ) {
            const auto index = iJ+checkpoint.configuration.Nj*iMode;
            const bool waveOrInertial = horizontalMean || iJ > 0;
            const bool geostrophicOrMDA = !horizontalMean || iJ > 0;
            if (!waveOrInertial) {
                checkpoint.state.coefficients.Ap[index] = {};
                checkpoint.state.coefficients.Am[index] = {};
            }
            if (!geostrophicOrMDA) checkpoint.state.coefficients.A0[index] = {};
        }
    }
    const auto shape = descriptor.spectralShape();
    const auto count = shape.elementCount();
    std::vector<WVComplex64> values(3*count);
    WVFlux flux{{values.data(),shape},{values.data()+count,shape},{values.data()+2*count,shape}};
    status = engine->nonlinearFlux(checkpoint.state.view(),flux);
    if (!status) {
        std::cerr << status.message << '\n';
        return 5;
    }
    std::cout << std::setprecision(17);
    std::cout << "{\"shape\":[" << shape.rows << ',' << shape.columns << ']';
    std::cout << ",\"FpReal\":"; component(values,0,count,false);
    std::cout << ",\"FpImag\":"; component(values,0,count,true);
    std::cout << ",\"FmReal\":"; component(values,count,count,false);
    std::cout << ",\"FmImag\":"; component(values,count,count,true);
    std::cout << ",\"F0Real\":"; component(values,2*count,count,false);
    std::cout << ",\"F0Imag\":"; component(values,2*count,count,true);
    std::cout << ",\"schedule\":\"" << engine->scheduleIdentifier() << "\"}\n";
    return 0;
}
