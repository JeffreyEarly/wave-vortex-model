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

Observer registrations must be installed before the first portable observer descriptor is constructed. Descriptor construction seals the process registry, making later or concurrent registration a deterministic error. Registration binds a paired identity to one immutable, source-linked C++ `WVObservingSystem` implementation. The descriptor creates one immutable resolved instance per observer record, retaining its typed configuration and declarative execution plan; integration and output routes use those resolved pointers and variable ordinals rather than repeating class-name lookup or calling observer-kind discriminators. Registration does not give the observer ownership of NetCDF definition or writing.

Forcing registrations follow the same lifetime rule and are sealed when a frozen schedule is decoded or validated. A registration maps an exact MATLAB identity and version to an existing typed payload and execution operation. Stage, priority, derived operators, tendency behavior, and post-step constraints are therefore resolved before integration; the forcing engine executes operation enums rather than MATLAB class names.

Configuration descriptors are immutable after construction. Evolving particle, tracer, forcing, and coefficient values live in explicit integration-state blocks. Observer output is produced through the existing output plan, driver, and sinks; observers do not define or write NetCDF storage themselves.

## Resolved observing systems

The C++ `WVObservingSystem` name intentionally matches the MATLAB abstraction, but its responsibilities are narrower. A resolved implementation owns immutable observer-specific interpretation and declares, through coarse operations:

- state-block ownership, tolerances, and restart requirements;
- resolved portable-variable dependencies;
- initialization and restoration behavior;
- an optional right-hand-side contribution;
- fixed-shape sample metadata and event-level sampling behavior.

The five supported MATLAB observers—`WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`—are registered through this boundary. Their numerical kernels, variable names, coefficient ordering, dense interpolation, and NetCDF schemas are unchanged. Particle and tracer element loops remain specialized and are selected during construction; a virtual call is permitted at observer, stage, or output-event granularity, never for each grid point, particle, or tracer value.

Persistence remains deliberately inverted relative to an object-oriented NetCDF design. An observing-system implementation supplies a data-only `WVObservationSchema` and initial or event-scoped `WVObservationBatch` values. A schema declares fixed and unlimited axes; real, complex, integer, Boolean, or text variables; coordinate roles; and contiguous-ragged row-count or row-offset relationships. A batch explicitly borrows immutable event state or owns bounded temporary storage. `WVModelOutputNetCDFSink` validates the complete batch set before mutation, evaluates coincident routes once, writes variable-size values to flat unlimited axes with per-record committed counts, and commits time last. The generic reader reconstructs nonlegacy provisional schemas from the persisted declarations, while a compatibility adapter preserves the existing five MATLAB encodings and restart rules. Observing-system implementations never call NetCDF.

The test-only paired `WVTestPortablePointDiagnostic` demonstrates the fixed-position extension seam with immutable field and point coordinates plus affine scale and offset. A separate test-only observation provider exercises fixed bins, moving coordinates, variable profiles and passes, zero-length events, mixed scalar types, and contiguous ragged values through the same schema/batch path. Adding either provider requires no observer-specific change to the integrator, output driver, graph reader, field evaluator, or sink. Along-track observation science is intentionally not part of this persistence contract.

## Output configuration

The provisional C++ `WVModelOutputFile` and `WVModelOutputGroup` builders mirror the names and configuration flow of their MATLAB counterparts. They are mutable only before `WVModelOutputConfiguration::build()`. The build operation consumes the builders, resolves observer identifiers through the sealed paired-observer registry, validates the complete multi-file graph, and produces the existing immutable `WVPortableObserverDescriptor` and `WVOutputPlan`. It does not create or mutate output.

Output schedules use a separate provisional source-linked registry. A provider receives a typed construction record and returns an immutable implementation with transactional `peek` semantics. The caller owns the cursor and commits the proposed next cursor only after output delivery succeeds. Runtime selection uses resolved implementations and ordinals; it performs no provider-name lookup while integrating.

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

## Runtime façade

The provisional move-only `WVModel` façade is the common owner used by the standalone program and the production MEX right-hand-side path. It owns immutable resolved services: forcing, observer behavior, numerical system, integrator, output evaluation, driver, sink, and metrics. `WVModelState` separately owns canonical `[Nj,Nkl]` coefficients and explicit particle or tracer state blocks. This separation follows MATLAB's distinction between model configuration and evolving state without copying state into a façade layer.

`WVModel::createFromModelOutputFiles()` inspects a complete sibling NetCDF set together, selects the latest complete compatible state, and rebuilds derived services. A destination map may replace file paths by stable file identifier, but cannot change observer membership, group schedules, or progress. The transient inspection and builder records are consumed; runtime routes retain resolved ordinals and pointers.

The façade deliberately provides high-level restart, right-hand-side, integration, output, capability, and metrics operations rather than a broad public transform API. Numerical stages remain in the existing kernel and field services, and persistence remains in the existing sink.

The source-level extension surface deliberately provides no binary plug-in ABI and does not execute MATLAB subclass code in C++. It introduces no second persistence graph, per-element virtual dispatch, hot-loop string lookup, or state-sized façade copy.

## Add a paired implementation

1. Define or update the authoritative MATLAB behavior.
2. Return the versioned data-only contract from the feature's portable-contract hook. The base MATLAB class defaults to unsupported.
3. Add the matching typed C++ descriptor and source registration.
4. Declare immutable parameters, state blocks, dependencies, outputs, constraints, and restart data.
5. Add MATLAB/C++ compatibility fixtures and unavailable/version-mismatch tests.
6. Verify that the integrator, output driver, persistence sink, and central dispatch code require no feature-specific edits.
7. Run numerical, lifecycle, complete-integration runtime, and retained-memory checks.

The common contract defines shared identity and capability behavior without imposing a generic mutable observer or forcing base class. Observer implementations are statically linked source extensions; their configuration becomes immutable when the descriptor is built.

## Performance budget

Commit `5940f4e4e206fbfb9a6cb4760af2ba2347e3571f` is the pre-façade baseline. Complete integration runtime and retained memory may regress by no more than 3%, and a façade may introduce no state-sized copy or persistent state-sized storage. When valid implementations are within 3% in speed and memory, choose the simpler implementation.

The C++ API remains provisional until the milestone's final extension and performance proof. The final proof stabilizes source compatibility, not binary compatibility.
