#include "WVRunRequest.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

using wavevortex::runtime::cli::WVRunRequest;
using wavevortex::runtime::cli::decodeRunRequest;

void require(bool condition, const std::string &message) {
  if (!condition)
    throw std::runtime_error(message);
}

void write(const std::filesystem::path &path, const std::string &value) {
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  require(static_cast<bool>(output), "unable to write " + path.string());
  output << value;
}

std::string fixedRequest(const std::string &extra = {}) {
  return R"({
    "schemaIdentifier":"wave-vortex-run-request-v1",
    "schemaVersion":1,
    "modelFiles":["model.nc"],
    "integration":{"method":"fixed-rk4","finalTime":12,"initialStep":0.25},
    "output":{"policy":"create","destinations":{"primary":"output.nc"}},
    "execution":{"fftProvider":"reference","threads":1},
    "report":"report.json")" + extra + "}";
}

} // namespace

int main() {
  try {
    const auto root = std::filesystem::temp_directory_path() /
                      "wave-vortex-run-request-contract";
    std::filesystem::remove_all(root);
    std::filesystem::create_directories(root / "subdirectory");
    write(root / "model.nc", "fixture");
    write(root / "request.json", fixedRequest());

    WVRunRequest request;
    auto status = decodeRunRequest((root / "request.json").string(), request);
    require(static_cast<bool>(status), status.message);
    require(request.requestPath ==
                std::filesystem::weakly_canonical(root / "request.json"),
            "request path was not canonicalized");
    require(request.modelFiles.size() == 1 &&
                request.modelFiles.front() ==
                    std::filesystem::weakly_canonical(root / "model.nc"),
            "model path was not resolved relative to the request");
    require(request.integrator == "fixed-rk4" && request.initialStep == 0.25 &&
                request.maximumStep == 0.25,
            "fixed integration contract was decoded incorrectly");
    require(request.outputPolicy == "create" &&
                request.destinations.size() == 1 &&
                request.destinations.front().fileIdentifier == "primary",
            "output destination contract was decoded incorrectly");
    const auto originalWorkingDirectory = std::filesystem::current_path();
    std::filesystem::current_path(root / "subdirectory");
    status = decodeRunRequest("../request.json", request);
    std::filesystem::current_path(originalWorkingDirectory);
    require(static_cast<bool>(status),
            "request failed outside its authoring directory: " +
                status.message);

    write(root / "adaptive.json", R"({
      "schemaIdentifier":"wave-vortex-run-request-v1",
      "schemaVersion":1,
      "modelFiles":["model.nc"],
      "integration":{"method":"adaptive-rk23","finalTime":12,"initialStep":0.25,"maximumStep":1,"relativeTolerance":0.001,"absoluteToleranceScale":0.000001},
      "output":{"policy":"append","destinations":{}},
      "execution":{"fftProvider":"reference","threads":1},
      "report":"adaptive-report.json"
    })");
    status = decodeRunRequest((root / "adaptive.json").string(), request);
    require(static_cast<bool>(status) && request.integrator == "adaptive-rk23" &&
                request.destinations.empty(),
            "adaptive append request was not accepted");

    const auto expectFailure = [&](const std::string &name,
                                   const std::string &contents,
                                   const std::string &message) {
      write(root / name, contents);
      WVRunRequest unchanged;
      unchanged.integrator = "sentinel";
      const auto failure = decodeRunRequest((root / name).string(), unchanged);
      require(!failure, message);
      require(unchanged.integrator == "sentinel",
              "failed decoding changed its output object");
    };
    expectFailure("unknown.json", fixedRequest(",\"unexpected\":true"),
                  "unknown field was accepted");
    expectFailure("malformed.json", "{", "malformed JSON was accepted");
    expectFailure(
        "wrong-version.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":2,"modelFiles":["model.nc"],"integration":{},"output":{},"execution":{},"report":"report.json"})",
        "wrong schema version was accepted");
    expectFailure(
        "missing-model.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["missing.nc"],"integration":{"method":"fixed-rk4","finalTime":12,"initialStep":1},"output":{"policy":"create","destinations":{"primary":"output.nc"}},"execution":{"fftProvider":"reference","threads":1},"report":"report.json"})",
        "missing model file was accepted");
    expectFailure(
        "duplicate-model.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["model.nc","./model.nc"],"integration":{"method":"fixed-rk4","finalTime":12,"initialStep":1},"output":{"policy":"create","destinations":{"primary":"output.nc"}},"execution":{"fftProvider":"reference","threads":1},"report":"report.json"})",
        "aliased model files were accepted");
    expectFailure(
        "source-alias.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["model.nc"],"integration":{"method":"fixed-rk4","finalTime":12,"initialStep":1},"output":{"policy":"replace","destinations":{"primary":"model.nc"}},"execution":{"fftProvider":"reference","threads":1},"report":"report.json"})",
        "source/output alias was accepted");
    expectFailure(
        "fixed-adaptive-fields.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["model.nc"],"integration":{"method":"fixed-rk4","finalTime":12,"initialStep":1,"maximumStep":1},"output":{"policy":"create","destinations":{"primary":"output.nc"}},"execution":{"fftProvider":"reference","threads":1},"report":"report.json"})",
        "fixed request accepted adaptive fields");
    expectFailure(
        "rk45-v1.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["model.nc"],"integration":{"method":"adaptive-rk45","finalTime":12,"initialStep":0.25,"maximumStep":1,"relativeTolerance":0.001,"absoluteToleranceScale":0.000001},"output":{"policy":"append","destinations":{}},"execution":{"fftProvider":"reference","threads":1},"report":"report.json"})",
        "run-request v1 accepted unreleased adaptive-rk45 identity");
    expectFailure(
        "rk78-v1.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["model.nc"],"integration":{"method":"adaptive-rk78","finalTime":12,"initialStep":0.25,"maximumStep":1,"relativeTolerance":0.001,"absoluteToleranceScale":0.000001},"output":{"policy":"append","destinations":{}},"execution":{"fftProvider":"reference","threads":1},"report":"report.json"})",
        "run-request v1 accepted adaptive-rk78 identity");
    expectFailure(
        "report-alias.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["model.nc"],"integration":{"method":"fixed-rk4","finalTime":12,"initialStep":1},"output":{"policy":"create","destinations":{"primary":"output.nc"}},"execution":{"fftProvider":"reference","threads":1},"report":"output.nc"})",
        "report/output alias was accepted");
    expectFailure(
        "reference-threads.json",
        R"({"schemaIdentifier":"wave-vortex-run-request-v1","schemaVersion":1,"modelFiles":["model.nc"],"integration":{"method":"fixed-rk4","finalTime":12,"initialStep":1},"output":{"policy":"create","destinations":{"primary":"output.nc"}},"execution":{"fftProvider":"reference","threads":2},"report":"report.json"})",
        "reference provider accepted multiple threads");

    std::filesystem::remove_all(root);
    std::cout << "Run-request decoder tests passed.\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
