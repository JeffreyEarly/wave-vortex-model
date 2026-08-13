#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVFixedStepRK4.hpp"
#include "WaveVortexRuntime/WVForcingEngine.hpp"
#include "WaveVortexRuntime/WVIntegrationDriver.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <algorithm>
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

class CollectingSink final : public WVIntegrationOutputSink {
public:
    explicit CollectingSink(WVShape2D shape) : shape_(shape), values_(3*shape.elementCount()) {}
    WVKernelStatus receive(const Event& event, Action& action) override {
        action = Action::continueIntegration;
        if (event.kind != EventKind::interpolated && event.kind != EventKind::accepted) return WVKernelStatus::ok();
        const auto count = shape_.elementCount();
        const WVComplexConstView sources[] = {event.state.coefficients.Ap,event.state.coefficients.Am,event.state.coefficients.A0};
        for (std::size_t componentIndex = 0; componentIndex < 3; ++componentIndex) std::copy_n(sources[componentIndex].data,count,values_.data()+componentIndex*count);
        outputTime_ = event.state.t;
        hasOutput_ = true;
        return WVKernelStatus::ok();
    }
    bool hasOutput() const noexcept { return hasOutput_; }
    double outputTime() const noexcept { return outputTime_; }
    const std::vector<WVComplex64>& values() const noexcept { return values_; }
private:
    WVShape2D shape_;
    std::vector<WVComplex64> values_;
    double outputTime_ = 0.0;
    bool hasOutput_ = false;
};

} // namespace

int main(int argc, char** argv) {
    if (argc != 4 && argc != 5) {
        std::cerr << "usage: wv_portable_rk4_inspect checkpoint.nc finalTime deltaT [outputTime]\n";
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
    const bool hasScheduledOutput = argc == 5;
    WVFixedStepRK4 integrator(*engine,{hasScheduledOutput});
    status = integrator.prepareStateAfterRestart(state);
    std::unique_ptr<CollectingSink> sink;
    std::unique_ptr<WVIntegrationDriver> driver;
    if (status && hasScheduledOutput) {
        sink = std::make_unique<CollectingSink>(shape);
        driver = std::make_unique<WVIntegrationDriver>(integrator);
        WVOrderedOutputSchedule schedule({std::stod(argv[4])});
        status = driver->advanceToTime(state,std::stod(argv[2]),std::stod(argv[3]),schedule,*sink);
    } else if (status) {
        status = integrator.advanceToTime(state,std::stod(argv[2]),std::stod(argv[3]));
    }
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
    if (hasScheduledOutput && sink && sink->hasOutput()) {
        const auto& output = sink->values();
        std::cout << ",\"outputTime\":" << sink->outputTime();
        std::cout << ",\"outputApReal\":"; component(output,0,count,false);
        std::cout << ",\"outputApImag\":"; component(output,0,count,true);
        std::cout << ",\"outputAmReal\":"; component(output,count,count,false);
        std::cout << ",\"outputAmImag\":"; component(output,count,count,true);
        std::cout << ",\"outputA0Real\":"; component(output,2*count,count,false);
        std::cout << ",\"outputA0Imag\":"; component(output,2*count,count,true);
        std::cout << ",\"interpolationBufferBytes\":" << driver->metrics().interpolationBufferCapacityBytes;
    }
    std::cout << "}\n";
    return 0;
}
