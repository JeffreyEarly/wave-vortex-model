#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVFixedStepRK4.hpp"
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
    if (argc != 4) {
        std::cerr << "usage: wv_portable_rk4_inspect checkpoint.nc finalTime deltaT\n";
        return 2;
    }
    WVCheckpoint checkpoint;
    auto checkpointStatus = WVCheckpointReader::read(argv[1],checkpoint);
    if (!checkpointStatus) {
        std::cerr << checkpointStatus.message << '\n';
        return 1;
    }
    std::unique_ptr<WVConstantStratificationForcingEngine> engine;
    auto status = WVConstantStratificationForcingEngine::create(checkpoint.configuration,checkpoint.forcingSchedule,std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),engine);
    if (!status) {
        std::cerr << status.message << '\n';
        return 1;
    }
    const auto shape = engine->kernel().descriptor().spectralShape();
    const auto count = shape.elementCount();
    WVMutableState state{checkpoint.state.t,checkpoint.state.t0,{
        {checkpoint.state.coefficients.Ap.data(),shape},
        {checkpoint.state.coefficients.Am.data(),shape},
        {checkpoint.state.coefficients.A0.data(),shape}}};
    WVFixedStepRK4 integrator(*engine);
    status = integrator.prepareStateAfterRestart(state);
    if (status) status = integrator.advanceToTime(state,std::stod(argv[2]),std::stod(argv[3]));
    if (!status) {
        std::cerr << status.message << '\n';
        return 1;
    }
    std::vector<WVComplex64> values;
    values.reserve(3*count);
    values.insert(values.end(),checkpoint.state.coefficients.Ap.begin(),checkpoint.state.coefficients.Ap.end());
    values.insert(values.end(),checkpoint.state.coefficients.Am.begin(),checkpoint.state.coefficients.Am.end());
    values.insert(values.end(),checkpoint.state.coefficients.A0.begin(),checkpoint.state.coefficients.A0.end());
    std::cout << std::setprecision(17) << "{\"shape\":[" << shape.rows << ',' << shape.columns << "],\"t\":" << state.t
              << ",\"stepCount\":" << integrator.metrics().stepCount << ",\"rhsEvaluationCount\":" << integrator.metrics().rightHandSideEvaluationCount
              << ",\"workspaceBytes\":" << integrator.metrics().workspaceCapacityBytes;
    std::cout << ",\"ApReal\":"; component(values,0,count,false);
    std::cout << ",\"ApImag\":"; component(values,0,count,true);
    std::cout << ",\"AmReal\":"; component(values,count,count,false);
    std::cout << ",\"AmImag\":"; component(values,count,count,true);
    std::cout << ",\"A0Real\":"; component(values,2*count,count,false);
    std::cout << ",\"A0Imag\":"; component(values,2*count,count,true);
    std::cout << "}\n";
    return 0;
}
