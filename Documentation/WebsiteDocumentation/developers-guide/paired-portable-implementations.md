---
layout: default
title: Paired MATLAB and C++ implementations
parent: Developers guide
nav_order: 13
---

# Paired MATLAB and C++ implementations

MATLAB is the authoritative scientific implementation of WaveVortexModel. The portable C++ runtime is a narrower speed-and-portability product: a feature is portable only when its MATLAB behavior has a versioned data contract and a matching source-level C++ implementation.

The initial contract is `wave-vortex-portable-pair-v1`. Every paired observer or forcing identifies its MATLAB class, positive contract version, immutable parameters, named dynamic state blocks, field dependencies, outputs, and restart requirements. The C++ implementation reports `supported`, `unavailable`, `versionMismatch`, or `invalidContract` with an actionable reason.

MATLAB observers expose this record through the developer-facing `portableImplementationContract()` method. The base `WVObservingSystem` implementation reports `unavailable`; each supported concrete class returns its exact MATLAB class name and contract version. A subclass cannot inherit portability accidentally because a contract whose type identifier differs from `class(observer)` is invalid.

MATLAB forcings use the same hook and exact-class rule. `WVForcing` defaults to `unavailable`; the six portable forcing classes return their immutable typed configuration. Shared envelope validation lives in `WVInternal.portableImplementationContract`, while observers and forcings retain separate typed registries and behavior contracts.

Shared scientific variables follow the [portable variable metadata contract](portable-variable-metadata.md). MATLAB annotations remain authoritative, while the C++ runtime resolves field names to generated ordinals during construction.

## Runtime boundary

The runtime resolves type identifiers, versions, dependencies, layouts, and dispatch targets during descriptor construction and preflight. Unsupported or version-mismatched features fail before coefficient-sized allocation, state advancement, or output mutation.

Observer registrations must be installed before the first portable observer descriptor is constructed. Descriptor construction seals the process registry, making later or concurrent registration a deterministic error. Registration binds a paired identity to reusable state and output contracts; it does not give the observer ownership of NetCDF definition or writing.

Forcing registrations follow the same lifetime rule and are sealed when a frozen schedule is decoded or validated. A registration maps an exact MATLAB identity and version to an existing typed payload and execution operation. Stage, priority, derived operators, tendency behavior, and post-step constraints are therefore resolved before integration; the forcing engine executes operation enums rather than MATLAB class names.

Configuration descriptors are immutable after construction. Evolving particle, tracer, forcing, and coefficient values live in explicit integration-state blocks. Observer output is produced through the existing output plan, driver, and sinks; observers do not define or write NetCDF storage themselves.

## Output configuration

The provisional C++ `WVModelOutputFile` and `WVModelOutputGroup` builders mirror the names and configuration flow of their MATLAB counterparts. They are mutable only before `WVModelOutputConfiguration::build()`. The build operation consumes the builders, resolves observer identifiers through the sealed paired-observer registry, validates the complete multi-file graph, and produces the existing immutable `WVPortableObserverDescriptor` and `WVOutputPlan`. It does not create or mutate output.

One policy applies to the complete graph. `create` requires every destination to be absent. `replace` stages every new file before transactionally replacing the destination set and restores the original files if installation fails. `append` requires compatible existing files and recovers their committed schedule ordinals. A graph cannot mix policies among files.

Default file identifiers are deterministic functions of normalized destinations; default group identifiers are deterministic functions of the file identity and group name. Explicit identifiers remain available for restart compatibility. Runtime routes contain only resolved ordinals and pointers. Builder objects, observer-name lookups, and a second output graph are not retained after compilation; NetCDF schema definition and writing remain exclusively in `WVModelOutputNetCDFSink`.

```cpp
WVModelOutputFile file;
WVModelOutputFile::create("output.nc", file);
WVModelOutputGroup *group = nullptr;
file.addNewEvenlySpacedOutputGroup(
    "wave-vortex", 60.0, initialTime, finalTime, group);
group->addObservingSystem("coefficients");
group->containsCompleteCoefficientRestart(true);

WVModelOutputConfiguration output;
std::vector<WVModelOutputFile> files;
files.push_back(std::move(file));
WVModelOutputConfiguration::build(
    observerRecord, std::move(files), WVModelOutputPolicy::create,
    initialTime, finalTime, output);
```

Every status must be checked in production code. The abbreviated example emphasizes the MATLAB-shaped construction sequence; integration consumes `output.plan()`, while `output.openNetCDFSink(...)` creates the existing persistence sink.

The source-level extension surface deliberately provides no binary plug-in ABI and does not execute MATLAB subclass code in C++. It introduces no second persistence graph, per-element virtual dispatch, hot-loop string lookup, or state-sized façade copy.

## Add a paired implementation

1. Define or update the authoritative MATLAB behavior.
2. Return the versioned data-only contract from the feature's portable-contract hook. The base MATLAB class defaults to unsupported.
3. Add the matching typed C++ descriptor and source registration.
4. Declare immutable parameters, state blocks, dependencies, outputs, constraints, and restart data.
5. Add MATLAB/C++ compatibility fixtures and unavailable/version-mismatch tests.
6. Verify that the integrator, output driver, persistence sink, and central dispatch code require no feature-specific edits.
7. Run numerical, lifecycle, complete-integration runtime, and retained-memory checks.

The common contract defines shared identity and capability behavior without imposing a generic mutable observer or forcing base class.

## Performance budget

Commit `5940f4e4e206fbfb9a6cb4760af2ba2347e3571f` is the pre-façade baseline. Complete integration runtime and retained memory may regress by no more than 3%, and a façade may introduce no state-sized copy or persistent state-sized storage. When valid implementations are within 3% in speed and memory, choose the simpler implementation.

The C++ API remains provisional until the milestone's final extension and performance proof. The final proof stabilizes source compatibility, not binary compatibility.
