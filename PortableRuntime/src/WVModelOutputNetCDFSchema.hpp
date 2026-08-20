#pragma once

#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"

#include <array>
#include <string>
#include <vector>

namespace wavevortex::runtime::detail {

WVCheckpointStatus defineModelOutputRoot(
    int root, const WVCheckpoint &checkpoint, const WVForcingCatalog &catalog,
    bool isDynamicsLinear,
    std::array<int, 5> &dimensions, std::vector<int> &forcingGroups,
    std::vector<const WVFrozenForcingEntry *> &forcingEntries);

WVCheckpointStatus writeModelOutputRoot(
    int root, const WVCheckpoint &checkpoint,
    const WVForcingCatalog &catalog,
    const std::vector<int> &forcingGroups,
    const std::vector<const WVFrozenForcingEntry *> &forcingEntries);

WVCheckpointStatus checkedNetCDF(int code, const std::string &operation,
                                 const std::string &location);
WVCheckpointStatus putTextAttribute(int group, int variable, const char *name,
                                    const std::string &value,
                                    const std::string &location);
WVCheckpointStatus putByteAttribute(int group, int variable, const char *name,
                                    unsigned char value,
                                    const std::string &location);
WVCheckpointStatus defineDoubleVariable(int group, const std::string &name,
                                        const std::vector<int> &dimensions,
                                        int &variable, const std::string &path);
WVCheckpointStatus defineComplexVariable(int group, const std::string &name,
                                         const std::vector<int> &dimensions,
                                         const std::string &path);

} // namespace wavevortex::runtime::detail
