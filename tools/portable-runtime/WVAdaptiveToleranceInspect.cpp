#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVForcingEngine.hpp"
#include "WVReferenceFFTEngine.hpp"

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <memory>

using namespace wavevortex;
using namespace wavevortex::runtime;

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "usage: wv_adaptive_tolerance_inspect CHECKPOINT ABSOLUTE_SCALE\n";
        return 2;
    }
    char* end = nullptr;
    const double scale = std::strtod(argv[2],&end);
    if (end == argv[2] || *end != '\0') return 2;
    WVCheckpoint checkpoint;
    const auto readStatus = WVCheckpointReader::read(argv[1],checkpoint);
    if (!readStatus) { std::cerr << readStatus.message << '\n'; return 3; }
    std::unique_ptr<WVConstantStratificationForcingEngine> system;
    auto status = WVConstantStratificationForcingEngine::create(
        checkpoint.configuration,checkpoint.forcingSchedule,std::make_unique<wavevortex::test::WVReferenceFFTEngine>(),system);
    if (!status) { std::cerr << status.message << '\n'; return 4; }
    std::unique_ptr<WVIntegrationErrorPolicy> policy;
    status = system->createErrorPolicy(scale,policy);
    if (!status) { std::cerr << status.message << '\n'; return 5; }
    const auto shape = system->stateShape();
    std::cout << std::setprecision(17) << "{\"shape\":[" << shape.rows << ',' << shape.columns << "],\"wave\":[";
    for (std::size_t index = 0; index < shape.elementCount(); ++index) {
        if (index != 0) std::cout << ',';
        std::cout << policy->absoluteTolerance(0,index);
    }
    std::cout << "],\"vortex\":[";
    for (std::size_t index = 0; index < shape.elementCount(); ++index) {
        if (index != 0) std::cout << ',';
        std::cout << policy->absoluteTolerance(2,index);
    }
    std::cout << "]}\n";
    return 0;
}
