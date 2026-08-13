#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVCheckpointWriter.hpp"

#include <iostream>
#include <string>

using namespace wavevortex::runtime;

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "usage: wv_checkpoint_roundtrip input.nc output.nc\n";
        return 2;
    }
    WVCheckpoint checkpoint;
    auto result = WVCheckpointReader::read(argv[1], checkpoint);
    if (!result) {
        std::cerr << result.message << '\n';
        return 1;
    }
    result = WVCheckpointWriter::write(argv[2], checkpoint);
    if (!result) {
        std::cerr << result.message << '\n';
        return 1;
    }
    std::cout << "Wrote compatible checkpoint " << argv[2] << '\n';
    return 0;
}
