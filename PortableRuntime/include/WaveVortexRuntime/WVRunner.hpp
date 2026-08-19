#pragma once

#include <memory>

namespace wavevortex::runtime {

class WVExtensionCatalog;

// Reusable command-line runner entry point. The caller owns the frozen
// extension catalog for the complete invocation.
int runWaveVortex(int argc, char **argv,
                  std::shared_ptr<const WVExtensionCatalog> catalog);

} // namespace wavevortex::runtime
