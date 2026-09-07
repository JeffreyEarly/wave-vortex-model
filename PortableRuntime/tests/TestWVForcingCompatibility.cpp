#include "WaveVortexRuntime/WVForcingContracts.hpp"
#include "generated/WVForcingCompatibilityRows.hpp"

#include <algorithm>
#include <iostream>
#include <stdexcept>
#include <string>

using namespace wavevortex::runtime;

int main() {
  try {
    const auto registrations = builtInForcingFactories();
    for (const auto &row : test::forcingCompatibilityRows) {
      const auto found = std::find_if(registrations.begin(), registrations.end(),
          [&](const auto &entry) { return entry.matlabClassName == row.identity &&
                                        entry.contractVersion == row.version; });
      if (found == registrations.end())
        throw std::runtime_error(std::string("Missing current registry pair: ") + row.identity);
      const bool available = found->isSupported &&
          (row.barotropic ? static_cast<bool>(found->barotropicQGFactory)
                          : static_cast<bool>(found->factory));
      if (available != row.factoryAvailable)
        throw std::runtime_error(std::string("Stale factory availability: ") + row.identity);
      // Unavailable placeholders do not define authoritative scientific stages.
      if (!row.applicable || !available) continue;
      const std::string stage(row.stage);
      WVForcingStage expected;
      if (stage == "HydrostaticSpatial" || stage == "NonhydrostaticSpatial" ||
          stage == "PVSpatial") expected = WVForcingStage::spatial;
      else if (stage == "Spectral" || stage == "PVSpectral")
        expected = WVForcingStage::spectral;
      else if (stage == "SpectralAmplitude" || stage == "PVSpectralAmplitude")
        expected = WVForcingStage::spectralAmplitude;
      else throw std::runtime_error("Unknown generated scientific stage.");
      const auto actual = row.barotropic ? found->barotropicQGStage : found->stage;
      if (actual != expected || found->priority != row.priority ||
          std::find(found->forcingTypes.begin(), found->forcingTypes.end(), stage) ==
              found->forcingTypes.end())
        throw std::runtime_error(std::string("MATLAB/registry stage or priority drift: ") + row.identity);
    }
    std::cout << "Checked " << test::forcingCompatibilityRows.size()
              << " MATLAB-derived rows against the current forcing registry.\n";
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
