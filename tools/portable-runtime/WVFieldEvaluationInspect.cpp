#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"

#include "WVReferenceFFTEngine.hpp"

#include <iomanip>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;

namespace {

std::string escaped(const std::string &value) {
  std::string result;
  for (const char character : value) {
    if (character == '\\' || character == '"')
      result += '\\';
    result += character;
  }
  return result;
}

WVFieldRequest full(const std::string &name) {
  return {"full__" + name, name, {}};
}

void printArray(const std::vector<double> &values) {
  std::cout << '[';
  for (std::size_t index = 0; index < values.size(); ++index) {
    if (index != 0)
      std::cout << ',';
    std::cout << values[index];
  }
  std::cout << ']';
}

void printDimensions(const std::vector<std::size_t> &dimensions) {
  std::cout << '[';
  for (std::size_t index = 0; index < dimensions.size(); ++index) {
    if (index != 0)
      std::cout << ',';
    std::cout << dimensions[index];
  }
  std::cout << ']';
}

} // namespace

int main(int argc, char **argv) {
  if (argc != 2) {
    std::cerr << "usage: wv_field_evaluation_inspect checkpoint.nc\n";
    return 2;
  }
  WVCheckpoint checkpoint;
  const auto checkpointStatus = WVCheckpointReader::read(argv[1], checkpoint);
  if (!checkpointStatus) {
    std::cerr << checkpointStatus.message << " [" << checkpointStatus.location
              << "]\n";
    return 3;
  }
  std::unique_ptr<WVFieldEvaluationService> service;
  auto status = WVFieldEvaluationService::create(
      checkpoint.configuration, std::make_unique<WVReferenceFFTEngine>(),
      service);
  if (!status) {
    std::cerr << status.message << '\n';
    return 4;
  }

  const std::vector<std::string> volumeFields = {
      "u",      "v",         "w",      "eta",    "pi",
      "p",      "psi",       "qgpv",   "rho_e", "rho_total",
      "zeta_x", "zeta_y",    "zeta_z"};
  const std::vector<std::string> horizontalFields = {"ssu", "ssv", "ssh"};
  std::vector<WVFieldRequest> requests;
  for (const auto &name : WVFieldEvaluationService::supportedFieldNames())
    requests.push_back(full(name));

  WVFieldSamplingRequest profiles;
  profiles.kind = WVFieldSamplingKind::fixedVerticalProfiles;
  profiles.xIndices = {1, checkpoint.configuration.Nx};
  profiles.yIndices = {1, checkpoint.configuration.Ny};
  for (const auto &name : volumeFields)
    requests.push_back({"profile__" + name, name, profiles});

  const auto &configuration = checkpoint.configuration;
  const double dx = configuration.Lx / static_cast<double>(configuration.Nx);
  const double dy = configuration.Ly / static_cast<double>(configuration.Ny);
  const double dz = configuration.Lz /
                    static_cast<double>(configuration.Nz - 1);
  WVFieldSamplingRequest positions;
  positions.kind = WVFieldSamplingKind::positions;
  positions.x = {-0.35 * dx, configuration.Lx - 0.35 * dx, 0.4 * dx,
                 configuration.Lx + 0.4 * dx, 2.35 * dx,
                 configuration.Lx - 0.2 * dx};
  positions.y = {configuration.Ly + 0.55 * dy, 0.55 * dy, -0.3 * dy,
                 configuration.Ly - 0.3 * dy, 1.7 * dy,
                 configuration.Ly - 0.1 * dy};
  positions.z = {-configuration.Lz + 0.4 * dz,
                 -configuration.Lz + 0.4 * dz,
                 -configuration.Lz + 2.25 * dz,
                 -configuration.Lz + 2.25 * dz, -1.3 * dz,
                 dz};
  for (const auto interpolation : {WVPositionInterpolation::linear,
                                   WVPositionInterpolation::spline}) {
    positions.interpolation = interpolation;
    const std::string prefix = interpolation == WVPositionInterpolation::linear
                                   ? "linear__"
                                   : "spline__";
    for (const auto &name : volumeFields)
      requests.push_back({prefix + name, name, positions});
    auto horizontalPositions = positions;
    horizontalPositions.z.clear();
    for (const auto &name : horizontalFields)
      requests.push_back({prefix + name, name, horizontalPositions});
  }

  WVFieldEvaluationPlan plan;
  status = service->createPlan(requests, plan);
  if (!status) {
    std::cerr << status.message << '\n';
    return 5;
  }
  std::vector<std::vector<double>> storage;
  std::vector<WVFieldOutputView> outputs;
  storage.reserve(plan.outputCount());
  outputs.reserve(plan.outputCount());
  for (const auto &specification : plan.outputs())
    storage.emplace_back(specification.elementCount, 0.0);
  for (auto &values : storage)
    outputs.push_back({values.data(), values.size()});
  status = service->evaluate(plan, checkpoint.state.view(), outputs.data(),
                             outputs.size());
  if (!status) {
    std::cerr << status.message << '\n';
    return 6;
  }

  std::cout << std::setprecision(17);
  std::cout << "{\"outputs\":[";
  for (std::size_t index = 0; index < plan.outputCount(); ++index) {
    if (index != 0)
      std::cout << ',';
    const auto &specification = plan.outputs()[index];
    std::cout << "{\"identifier\":\"" << escaped(specification.identifier)
              << "\",\"field\":\"" << escaped(specification.fieldName)
              << "\",\"dimensions\":";
    printDimensions(specification.dimensions);
    std::cout << ",\"values\":";
    printArray(storage[index]);
    std::cout << '}';
  }
  const auto &metrics = service->metrics();
  std::cout << "],\"positions\":{\"x\":";
  printArray(positions.x);
  std::cout << ",\"y\":";
  printArray(positions.y);
  std::cout << ",\"z\":";
  printArray(positions.z);
  std::cout << "},\"metrics\":{\"evaluationCount\":"
            << metrics.evaluationCount << ",\"coincidentBatchCount\":"
            << metrics.coincidentBatchCount << ",\"lastPlanBytes\":"
            << metrics.lastPlanBytes << ",\"maximumPlanBytes\":"
            << metrics.maximumPlanBytes << ",\"servicePersistentBytes\":"
            << metrics.servicePersistentBytes
            << ",\"transformPersistentBytes\":"
            << metrics.transformPersistentBytes
            << ",\"scratchCapacityBytes\":" << metrics.scratchCapacityBytes
            << ",\"scratchHighWaterBytes\":"
            << metrics.scratchHighWaterBytes << ",\"transformCount\":"
            << metrics.transformCount << ",\"fftExecutionCount\":"
            << metrics.fftExecutionCount
            << ",\"primitiveFieldEvaluationCount\":"
            << metrics.primitiveFieldEvaluationCount
            << ",\"primitiveFieldReuseCount\":"
            << metrics.primitiveFieldReuseCount
            << ",\"fullGridWriteCount\":" << metrics.fullGridWriteCount
            << ",\"profileWriteCount\":" << metrics.profileWriteCount
            << ",\"linearInterpolationCount\":"
            << metrics.linearInterpolationCount
            << ",\"splineInterpolationCount\":"
            << metrics.splineInterpolationCount
            << ",\"outputElementWriteCount\":"
            << metrics.outputElementWriteCount << "}}\n";
  return 0;
}
