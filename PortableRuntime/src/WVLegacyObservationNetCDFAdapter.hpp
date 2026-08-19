#pragma once

#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"

#include <map>
#include <string>
#include <vector>

namespace wavevortex::runtime::detail {

// Compatibility boundary for the five legacy MATLAB observing-system
// encodings. The graph reader remains schema-driven; this adapter contains the
// data-only mapping between legacy class metadata and portable records.
WVCheckpointStatus parsePersistedObserver(
    int outputGroup, int metadataGroup, const std::string &outputPath,
    WVPortableObserverRecord &portable, std::string &identifier);

bool persistedObserverCarriesCoefficientState(int metadataGroup) noexcept;

WVCheckpointStatus resolvePersistedObserverRestartState(
    const std::vector<WVOutputFileRecord> &files,
    std::vector<WVObserverRecord> &observers, double selectedTime,
    std::map<std::string, std::vector<std::vector<double>>> &resolvedState);

} // namespace wavevortex::runtime::detail
