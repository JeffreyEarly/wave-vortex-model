#pragma once

#include <cstddef>
#include <string>
#include <utility>
#include <vector>

namespace wavevortex::runtime::cli {

struct WVRunRequestDestination {
  std::string fileIdentifier;
  std::string path;
};

// A compact execution request. Scientific configuration, state, forcing,
// observers, schedules, and restart progress remain authoritative in the
// referenced NetCDF model bundle.
struct WVRunRequest {
  static constexpr const char *schemaIdentifier =
      "wave-vortex-run-request-v1";
  static constexpr int schemaVersion = 1;

  std::string requestPath;
  std::vector<std::string> modelFiles;
  std::string integrator;
  double finalTime = 0.0;
  double initialStep = 0.0;
  double maximumStep = 0.0;
  double relativeTolerance = 0.0;
  double absoluteToleranceScale = 0.0;
  std::string outputPolicy;
  std::vector<WVRunRequestDestination> destinations;
  std::string fftProvider;
  std::size_t threads = 0;
  std::string report;
};

struct WVRunRequestStatus {
  bool success = false;
  std::string message;
  explicit operator bool() const noexcept { return success; }

  static WVRunRequestStatus ok() { return {true, {}}; }
  static WVRunRequestStatus failure(std::string value) {
    return {false, std::move(value)};
  }
};

// Decode, validate, and normalize one request. Every returned path is
// absolute. Existing model files are canonicalized; prospective destinations
// canonicalize their nearest existing parent. Unknown fields are rejected.
WVRunRequestStatus decodeRunRequest(const std::string &path,
                                    WVRunRequest &request);

} // namespace wavevortex::runtime::cli
