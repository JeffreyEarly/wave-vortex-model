#pragma once

#include "WaveVortexRuntime/WVModelOutputNetCDF.hpp"

#include <cstddef>
#include <cstdint>
#include <deque>
#include <memory>
#include <string>
#include <vector>

namespace wavevortex::runtime {

// One policy applies transactionally to the complete multi-file graph.
enum class WVModelOutputPolicy : std::uint8_t { create, replace, append };

// Provisional, developer-facing configuration for one MATLAB-shaped evenly
// spaced output group. This builder owns names and identifiers only until
// WVModelOutputConfiguration::build() resolves and consumes the graph.
// Runtime scheduling remains owned by WVOutputPlan.
class WVModelOutputGroup final {
public:
  WVModelOutputGroup() = default;
  WVModelOutputGroup(WVModelOutputGroup &&) noexcept = default;
  WVModelOutputGroup &operator=(WVModelOutputGroup &&) noexcept = default;
  WVModelOutputGroup(const WVModelOutputGroup &) = delete;
  WVModelOutputGroup &operator=(const WVModelOutputGroup &) = delete;

  // Construct an inclusive lattice initialTime + ordinal*outputInterval,
  // bounded by finalTime. All times are seconds.
  static WVKernelStatus evenlySpaced(std::string name, double outputInterval,
                                     double initialTime, double finalTime,
                                     WVModelOutputGroup &group,
                                     std::string identifier = {});

  // Add one authoritative observer identifier. Duplicate membership fails.
  WVKernelStatus addObservingSystem(std::string observerIdentifier);
  // Mark this group as the file's complete restart group.
  WVKernelStatus containsCompleteCoefficientRestart(bool value);
  // Supply an append cursor for validation against persisted progress.
  WVKernelStatus committedOrdinal(WVOutputScheduleOrdinal value);

  const std::string &name() const noexcept { return record_.name; }
  const std::string &identifier() const noexcept { return record_.identifier; }
  const WVOutputScheduleRecord &schedule() const noexcept {
    return record_.schedule;
  }
  const std::vector<std::string> &observingSystems() const noexcept {
    return record_.observerIdentifiers;
  }
  bool isSealed() const noexcept { return sealed_; }
  std::size_t persistentBytes() const noexcept;

private:
  WVOutputGroupRecord record_;
  WVOutputScheduleOrdinal committedOrdinal_ = WVNoCommittedOutputOrdinal;
  bool hasExplicitProgress_ = false;
  bool sealed_ = false;

  friend class WVModelOutputFile;
  friend class WVModelOutputConfiguration;
};

// Provisional, developer-facing configuration for one MATLAB-shaped output
// file. Group addresses remain stable while this builder is mutable.
class WVModelOutputFile final {
public:
  WVModelOutputFile() = default;
  WVModelOutputFile(WVModelOutputFile &&) noexcept = default;
  WVModelOutputFile &operator=(WVModelOutputFile &&) noexcept = default;
  WVModelOutputFile(const WVModelOutputFile &) = delete;
  WVModelOutputFile &operator=(const WVModelOutputFile &) = delete;

  // Resolve destination to a normalized absolute path. A stable identifier is
  // generated when identifier is empty.
  static WVKernelStatus create(std::string destination,
                               WVModelOutputFile &file,
                               std::string identifier = {});

  // Add a preconfigured group. Ownership moves into this file.
  WVKernelStatus addOutputGroup(WVModelOutputGroup group);
  // Construct, add, and return a stable non-owning group pointer.
  WVKernelStatus addNewEvenlySpacedOutputGroup(
      std::string name, double outputInterval, double initialTime,
      double finalTime, WVModelOutputGroup *&group,
      std::string identifier = {});
  // MATLAB-compatible convenience valid only when this file has one group.
  WVKernelStatus addObservingSystem(std::string observerIdentifier);

  WVModelOutputGroup *outputGroupWithName(const std::string &name) noexcept;
  const WVModelOutputGroup *
  outputGroupWithName(const std::string &name) const noexcept;
  WVModelOutputGroup *
  outputGroupWithIdentifier(const std::string &identifier) noexcept;
  const WVModelOutputGroup *
  outputGroupWithIdentifier(const std::string &identifier) const noexcept;

  const std::string &destination() const noexcept { return destination_; }
  const std::string &identifier() const noexcept { return identifier_; }
  std::size_t outputGroupCount() const noexcept { return groups_.size(); }
  bool isSealed() const noexcept { return sealed_; }
  std::size_t persistentBytes() const noexcept;

private:
  std::string destination_;
  std::string identifier_;
  // Stable addresses preserve references returned by MATLAB-shaped lookup.
  std::deque<WVModelOutputGroup> groups_;
  bool sealed_ = false;

  friend class WVModelOutputConfiguration;
};

// Move-only compiled output configuration. The transient builders are not
// retained. This object owns only the existing authoritative descriptor and
// plan plus graph-wide policy and committed progress.
class WVModelOutputConfiguration final {
public:
  WVModelOutputConfiguration();
  ~WVModelOutputConfiguration();
  WVModelOutputConfiguration(WVModelOutputConfiguration &&) noexcept;
  WVModelOutputConfiguration &
  operator=(WVModelOutputConfiguration &&) noexcept;
  WVModelOutputConfiguration(const WVModelOutputConfiguration &) = delete;
  WVModelOutputConfiguration &
  operator=(const WVModelOutputConfiguration &) = delete;

  // Consume files, resolve observer registrations, validate the complete
  // graph and destination policy, and construct the immutable output plan.
  // No output file is created or mutated by this operation.
  static WVKernelStatus
  build(WVPortableObserverRecord observerRecord,
        std::vector<WVModelOutputFile> files, WVModelOutputPolicy policy,
        std::shared_ptr<const WVExtensionCatalog> catalog,
        double initialTime, double finalTime,
        WVModelOutputConfiguration &configuration);

  // Construct the existing NetCDF sink according to the compiled graph-wide
  // policy. sampleSource is non-owning and must outlive the sink.
  WVCheckpointStatus openNetCDFSink(
      const WVModelOutputNetCDFConfiguration &configuration,
      const WVIntegrationStateLayout &stateLayout,
      WVObserverSampleSource *sampleSource,
      WVModelOutputNetCDFSink &sink) const;

  const WVPortableObserverDescriptor &descriptor() const noexcept;
  const std::shared_ptr<const WVExtensionCatalog> &catalog() const noexcept;
  const WVOutputPlan &plan() const noexcept;
  const std::vector<WVOutputGroupProgress> &progress() const noexcept;
  WVModelOutputPolicy policy() const noexcept;
  std::size_t persistentBytes() const noexcept;

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace wavevortex::runtime
