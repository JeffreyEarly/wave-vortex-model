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

MATLAB forcings use the same hook and exact-class rule. `WVForcing` defaults to `unavailable`; the seven portable forcing classes return their immutable typed configuration. Shared envelope validation lives in `WVInternal.portableImplementationContract`, while observers and forcings retain separate typed subcatalogs and behavior contracts.

Shared scientific variables follow the [portable variable metadata contract](portable-variable-metadata.md). MATLAB annotations remain authoritative, while the C++ runtime resolves field names to generated ordinals during construction.

The C++ compilation boundary is independently identified as `wave-vortex-portable-source-api-v1`, version 1.0. It stabilizes the documented source surface, not a binary layout. A consumer must select one WaveVortexModel checkout, compile the runtime and every statically linked extension together, and recompile the complete application after changing that selection. An incompatible documented source change requires a new source-API major version. Pair, observer-graph, schedule, payload, observation-schema, run-request, and compiled-kernel versions remain independent exact data contracts; a match at one boundary never substitutes for a match at another.

## Runtime boundary

The runtime resolves type identifiers, versions, dependencies, layouts, and dispatch targets during descriptor construction and preflight. Unsupported or version-mismatched features fail before coefficient-sized allocation, state advancement, or output mutation.

`WVExtensionCatalogBuilder` is the only mutable extension-registration boundary. Its strongly typed observer, output-schedule, and forcing operations reject duplicate or incomplete registrations; a rejected registration invalidates the builder, mutation after freezing fails, and a builder can freeze only once. The public v1 observer registration has exactly five inputs: type identity, contract version, factory, optional data-only configuration resolver, and optional data-only output-plan resolver. Historical MATLAB-encoding callbacks and persistence metadata are private runtime compatibility machinery, not extension registration inputs. `addBuiltInExtensions()` installs every built-in through that same source-linked path. Freezing produces one immutable `std::shared_ptr<const WVExtensionCatalog>` with distinct `WVObserverCatalog`, `WVOutputScheduleCatalog`, and `WVForcingCatalog` subcatalogs. There is no process-global mutable registry, implicit sealing event, dynamic discovery, binary plug-in ABI, separately loadable extension, or distributed compiled extension.

The application creates the frozen catalog and supplies it explicitly to inspection, resolution, compilation, model, MEX-handle, and runner entry points. APIs retain shared ownership whenever resolved implementations or compiled graphs depend on it, so destroying the builder or the application's original pointer cannot invalidate a live model. Independent catalogs may coexist in one process and may bind the same source identity to different implementations without interference.

NetCDF inspection first reconstructs owning data-only records. Raw inspection does not invoke an observer, output-schedule, or forcing factory and does not construct a runtime implementation. Semantic preflight then uses the explicitly supplied catalog to resolve exact identities and versions. Observer descriptor construction creates one immutable resolved `WVObservingSystem` for every observer record, even when records share a stateless factory, and freezes its typed configuration and declarative execution plan. Forcing resolution similarly fixes stage, priority, derived operators, tendency behavior, and post-step constraints before integration. Runtime routes use resolved pointers and variable ordinals rather than class-name lookup or observer-kind discriminators.

Configuration descriptors are immutable after construction. Evolving particle, tracer, forcing, and coefficient values live in explicit integration-state blocks. Observer output is produced through the existing output plan, driver, and sinks; observers do not define or write NetCDF storage themselves.

## External source-linked proof

The real external-consumer baseline is [AlongTrackSimulator main at the completed ATS #4 integration](https://github.com/satmapkit/AlongTrackSimulator/commit/ba57981f336ad5bbbc0907dcd74fcd4fcd137708). Its application-owned runner adds WaveVortexModel's built-ins, adds the source-linked `WVAlongTrackSchedule` and `WVAlongTrackObservingSystem` pair, freezes one catalog, and passes that catalog to `runWaveVortex()`. Source API v1 qualification recompiles that consumer against the selected WaveVortexModel checkout and requires its observer registration to supply the exact five v1 inputs described above. WaveVortexModel contains no AlongTrack identity, orbit algorithm, schema branch, or registration discovery.

Select the WaveVortexModel checkout explicitly and compile both source trees together:

```sh
cmake -S /path/to/AlongTrackSimulator -B build/alongtrack-wvm \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=ON \
  -DALONGTRACK_BUILD_WAVEVORTEX_EXTENSION=ON \
  -DALONGTRACK_WAVEVORTEX_SOURCE_DIR=/path/to/wave-vortex-model
cmake --build build/alongtrack-wvm --parallel
ctest --test-dir build/alongtrack-wvm --output-on-failure
```

This proof uses a MATLAB-authored run bundle containing the AlongTrack schedule/observer pair and the built-in `WVBottomFrictionLinear` forcing. The built-in-only runner rejects the unavailable external pair during allocation-light preflight; the extended runner resolves its exact identities, versions, schema, dependencies, event geometry, state, schedule cursor, and execution targets before advancing. Repeating and nonrepeating/geodetic passes, fixed and adaptive integration, exact and dense output, persistence, restart, continuation, route retry, source immutability, MATLAB parity, catalog lifetime, and independent catalogs use the same generic runtime paths. The external runner is qualified on Ubuntu with GCC and Clang and on macOS with AppleClang. WaveVortexModel does not currently compile under MSVC, so the source-linked runner is unsupported on Windows.

## Resolved observing systems

The C++ `WVObservingSystem` name intentionally matches the MATLAB abstraction, but its responsibilities are narrower. A resolved implementation owns immutable observer-specific interpretation and declares, through coarse operations:

- state-block ownership, tolerances, and restart requirements;
- resolved portable-variable dependencies;
- initialization and restoration behavior;
- an optional right-hand-side contribution;
- fixed-shape sample metadata and event-level sampling behavior.

The five supported MATLAB observers—`WVCoefficients`, `WVEulerianFields`, `WVMooring`, `WVLagrangianParticles`, and `WVTracer`—are registered through this boundary. Their numerical kernels, variable names, coefficient ordering, dense interpolation, and NetCDF schemas are unchanged. Particle and tracer element loops remain specialized and are selected during construction; a virtual call is permitted at observer, stage, or output-event granularity, never for each grid point, particle, or tracer value.

Persistence remains deliberately inverted relative to an object-oriented NetCDF design. An observing-system implementation supplies a data-only `WVObservationSchema` and initial or event-scoped `WVObservationBatch` values. A schema declares fixed and unlimited axes; real, complex, integer, Boolean, or text variables; coordinate roles; and contiguous-ragged row-count or row-offset relationships. A batch explicitly borrows immutable event state or owns bounded temporary storage. `WVModelOutputNetCDFSink` validates the complete batch set before mutation, evaluates coincident routes once, writes variable-size values to flat unlimited axes with per-record committed counts, and commits time last. The generic reader reconstructs nonlegacy schemas from the persisted declarations, while a private compatibility adapter preserves the existing five MATLAB encodings and restart rules. Observing-system implementations never call NetCDF.

The test-only paired `WVTestPortablePointDiagnostic` demonstrates the fixed-position extension seam with immutable field and point coordinates plus affine scale and offset. A separate test-only observation provider exercises fixed bins, moving coordinates, variable profiles and passes, zero-length events, mixed scalar types, and contiguous ragged values through the same schema/batch path. Adding either provider requires no observer-specific change to the integrator, output driver, graph reader, field evaluator, or sink. AlongTrackSimulator supplies the real along-track science externally; only the generic schema, batch, geometry, field-evaluation, and persistence contracts live in WaveVortexModel.

## Output configuration

The stable source-level `WVModelOutputFile` and `WVModelOutputGroup` builders mirror the names and configuration flow of their MATLAB counterparts. They are mutable only before `WVModelOutputConfiguration::build()`. The build operation consumes the builders, resolves observer identifiers through the supplied frozen catalog, validates the complete multi-file graph, and produces the existing immutable `WVPortableObserverDescriptor` and `WVOutputPlan`. It does not create or mutate output.

Output schedules use the strongly typed output-schedule subcatalog rather than an observer or forcing factory abstraction. A provider receives a typed construction record and returns an immutable implementation with transactional `peek` semantics. The caller owns the cursor and commits the proposed next cursor only after output delivery succeeds. Runtime selection uses resolved implementations and ordinals; it performs no provider-name lookup while integrating.

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
    catalog, initialTime, finalTime, output);
```

Every status must be checked in production code. The abbreviated example emphasizes the MATLAB-shaped construction sequence; integration consumes `output.plan()`, while `output.openNetCDFSink(...)` creates the existing persistence sink.

## Runtime façade

The stable source-level, move-only `WVModel` façade is the common owner used by the standalone program and the production MEX right-hand-side path. It retains the frozen extension catalog together with immutable resolved services: forcing, observer behavior, numerical system, integrator, output evaluation, driver, sink, and metrics. `WVModelState` separately owns the ordered coefficient families and natural ranks declared by the resolved transform together with explicit particle or tracer state blocks. Constant stratification retains zero-copy `Ap`/`Am`/`A0` compatibility views; Barotropic QG owns only compact `A0[Nkl]`. This separation follows MATLAB's distinction between model configuration and evolving state without copying state into a façade layer.

`WVModel::createFromModelOutputFiles()` inspects a complete sibling NetCDF set together, selects the latest complete compatible state, and rebuilds derived services. A destination map may replace file paths by stable file identifier, but cannot change observer membership, group schedules, or progress. The transient inspection and builder records are consumed; runtime routes retain resolved ordinals and pointers.

The façade deliberately provides high-level restart, right-hand-side, integration, output, capability, and metrics operations rather than a broad public transform API. Numerical stages remain in the existing kernel and field services, and persistence remains in the existing sink. Library and test clients can call the reusable `runWaveVortex(argc,argv,catalog)` entry point with their own frozen catalog; the small executable main constructs the built-in catalog and delegates to that entry point.

The source-level extension surface deliberately provides no binary plug-in ABI and does not execute MATLAB subclass code in C++. It introduces no second persistence graph, per-element virtual dispatch, hot-loop string lookup, or state-sized façade copy.

## Add a paired implementation

1. Define or update the authoritative MATLAB behavior.
2. Return the versioned data-only contract from the feature's portable-contract hook. The base MATLAB class defaults to unsupported.
3. Add the matching typed C++ descriptor and register it with the appropriate `WVExtensionCatalogBuilder` operation.
4. Declare immutable parameters, state blocks, dependencies, outputs, constraints, and restart data.
5. Add MATLAB/C++ compatibility fixtures and unavailable/version-mismatch tests.
6. Verify that the integrator, output driver, persistence sink, and central dispatch code require no feature-specific edits.
7. Freeze a catalog, pass it explicitly through inspection and runtime construction, and run numerical, lifecycle, multi-catalog, complete-integration runtime, and retained-memory checks.

The common contract defines shared identity and capability behavior without imposing a generic mutable observer or forcing base class. Observer implementations are statically linked source extensions; their configuration becomes immutable when the descriptor is built.

## Performance budget

Commit `5940f4e4e206fbfb9a6cb4760af2ba2347e3571f` is the pre-façade baseline. Complete integration runtime and retained memory may regress by no more than 3%, and a façade may introduce no state-sized copy or persistent state-sized storage. When valid implementations are within 3% in speed and memory, choose the simpler implementation.

The accepted external extension, compatibility, numerical, performance, and ownership proof stabilizes `wave-vortex-portable-source-api-v1`. WaveVortexModel and its source-linked consumers distribute and select source, then rebuild together; they do not promise binary compatibility or distribute compiled extension products.
