#pragma once

#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexKernel/WVSpectralOperators.hpp"
#include <memory>

namespace wavevortex::runtime {

// Scientific record semantics, separate from checkpoint and execution contracts.
inline constexpr const char* WVStratifiedModalRecordContract = "wave-vortex-stratified-modal-record-v1";

struct WVStratifiedModalGeometry {
    std::string transformClass, modelVersion;
    std::size_t Nx = 0, Ny = 0, Nz = 0, Nj = 0, Nkl = 0;
    double Lx = 0, Ly = 0, Lz = 0, g = 0, rho0 = 0;
    double latitude = 0, rotationRate = 0, planetaryRadius = 0;
    bool shouldAntialias = false;
    std::vector<double> x, y, z, j, k, l, N2, rho_nm0, dLnN2, P0, Q0, h_0, z_int;
    std::vector<WVRetainedModeKey> modes;
};

struct WVStratifiedModalInspection {
    WVStratifiedModalGeometry geometry;
    std::size_t scientificMatrixBytes = 0;
    // Matrix payloads are scanned through a fixed buffer, never retained here.
    static constexpr std::size_t matrixScanBytes = 4096*sizeof(double);
};

// Names refer to unpreconditioned scientific F/G operations. Matrix storage is
// column-major. Reconstruction maps modal to vertical grid; projection reverses it.
enum class WVStratifiedModalOperator { reconstructF, projectF, reconstructG, projectG, GToF, FToG };

enum class WVStratifiedScientificMatrix { PF0inv, QG0inv, PF0, QG0 };
struct WVScientificModalGroup {
    std::uint64_t identity = 0;
    std::vector<std::size_t> columns;
};

class WVStratifiedModalRecord {
public:
    const WVStratifiedModalGeometry& geometry() const noexcept { return geometry_; }
    const std::vector<double>& PF0inv() const noexcept { return PF0inv_; }
    const std::vector<double>& QG0inv() const noexcept { return QG0inv_; }
    const std::vector<double>& PF0() const noexcept { return PF0_; }
    const std::vector<double>& QG0() const noexcept { return QG0_; }
    // Exact identity of this immutable in-process scientific record. No reuse by
    // path, radius or approximate matrix values; rereading creates a new record.
    const std::string& sourceIdentity() const noexcept { return sourceIdentity_; }
    const std::string& modeSetIdentity() const noexcept { return modeSetIdentity_; }
    std::size_t persistentBytes() const noexcept;
    // Exact source group membership, shared across this record's F/G family.
    // The initial shared-matrix slice has one group; grouped wave records can
    // retain discontiguous membership in the same vocabulary in a later decoder.
    const std::vector<WVScientificModalGroup>& groups() const noexcept { return groups_; }
    // Borrowed const view of persisted preconditioned values, valid while this
    // scientific record lives. No normalization conversion or derived product.
    WVKernelStatus matrixView(WVStratifiedScientificMatrix matrix, WVVerticalMatrixRecord& result) const;

    WVKernelStatus prepareVertical(WVStratifiedModalOperator operation,
        WVComplexLayout input, WVComplexLayout output,
        std::unique_ptr<WVVerticalMatrixBackend> backend,
        std::unique_ptr<WVPreparedVerticalOperator>& result,
        WVAccumulation accumulation = WVAccumulation::overwrite) const;
    WVKernelStatus horizontalSpecification(std::size_t planes,
        WVComplexRepresentation representation, const std::string& family,
        WVRetainedHorizontalSpecification& result) const;
private:
    friend class WVStratifiedModalReader;
    WVStratifiedModalRecord() = default;
    WVStratifiedModalGeometry geometry_;
    std::vector<double> PF0inv_, QG0inv_, PF0_, QG0_;
    std::string sourceIdentity_, modeSetIdentity_;
    std::vector<WVScientificModalGroup> groups_;
};

class WVStratifiedModalReader {
public:
    // Reads geometry/modal data only. Does not promise transform execution or
    // decode forcings/coefficient state; those remain checkpoint/kernel concerns.
    // Both calls validate all matrix payloads. Failure preserves existing output.
    static WVCheckpointStatus inspect(const std::string& path, WVStratifiedModalInspection& result);
    static WVCheckpointStatus read(const std::string& path, std::shared_ptr<const WVStratifiedModalRecord>& result);
};

} // namespace wavevortex::runtime
