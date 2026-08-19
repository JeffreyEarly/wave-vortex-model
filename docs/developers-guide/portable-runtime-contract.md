---
layout: default
title: Portable runtime contract
parent: Developers guide
nav_order: 12
---

# Portable runtime contract

The portable runtime composes the MATLAB-independent `WaveVortexKernel` with integration, field evaluation, observing-system adapters, and NetCDF persistence. MATLAB/MEX, NetCDF, FFTW, and Apple APIs remain outside the numerical core.

The move-only `WVModel` façade owns that composition, while `WVModelState` owns evolving canonical coefficients and explicit observer state. The façade delegates to the contracts below; it does not introduce another numerical, output, or persistence implementation. Both the standalone runner and production MEX right-hand-side path use this owner.

## Integration boundaries

`WVIntegrationStateLayout` describes canonical `Ap`, `Am`, and `A0` plus zero or more typed observer-owned blocks. Coefficient-only execution is the same representation with no additional blocks.

`WVIntegrationSystem` owns right-hand-side evaluation, constraints, and error scaling. `WVTimeIntegrator` advances accepted state. `WVDenseOutput` evaluates state inside an accepted step from that method's Runge--Kutta data. Output scheduling consumes only these interfaces: adding another integrator must not add method branches to the output driver, and adding another state block must not change an integrator.

The runtime supplies classical fixed RK4 and Bogacki--Shampine RK3(2). The adaptive controller uses the `matlab-ode23-v1` contract: componentwise scale `max(absTol, relTol*max(abs(y),abs(ynew)))`, MATLAB's accepted/rejected step factors, a bounded maximum step, and FSAL reuse only when constraints preserve the endpoint derivative. Coefficient tolerances use the model-wide requested scale; particle, tracer, and other observing-system blocks retain their declared absolute tolerances without an additional global factor. Rejected adaptive attempts do not mutate accepted state or emit output. Interpolated output never becomes accepted state.

## Observers and fields

`WVExtensionCatalogBuilder` is the only mutable extension-registration boundary. Its strongly typed observer, output-schedule, and forcing operations bind an exact identity and version to the corresponding typed factory contract; the runtime does not use one universal factory abstraction. Duplicate or incomplete registration invalidates the builder, mutation after freezing fails, and the builder can freeze only once. `addBuiltInExtensions()` installs every built-in through the same source-linked path.

Freezing produces an immutable `std::shared_ptr<const WVExtensionCatalog>` with separate `WVObserverCatalog`, `WVOutputScheduleCatalog`, and `WVForcingCatalog` subcatalogs. The caller supplies this catalog explicitly to inspection, semantic resolution, graph compilation, descriptor construction, `WVModel`, MEX handles, and runner entry points. Those objects retain shared ownership for as long as resolved implementations depend on it. Destroying the builder or the caller's original pointer therefore cannot invalidate a live runtime, and independent catalogs may coexist in one process without interference. There is no process-global mutable registry or implicit sealing event.

Raw NetCDF inspection reconstructs owning data-only records without invoking an extension factory or constructing a runtime implementation. Semantic preflight then resolves exact identities and versions through the supplied catalog. Observer descriptor construction creates one distinct immutable resolved observer for every record, even when records share a stateless factory, and freezes a declarative execution plan on that instance. Observation persistence crosses the separate data-only `WVObservationSchema`/`WVObservationBatch` boundary: the sink, graph reader, output evaluator, output driver, and integrator do not branch on observer class or kind. The five qualified MATLAB observers use this same boundary without changing their fixed-shape NetCDF encoding.

The catalog is intentionally a native source API rather than a third-party binary plug-in ABI. A new observer can reuse the existing coefficient, full-grid field, mooring, particle, or tracer behavior without editing the runtime subsystems. A genuinely new state or output behavior first requires a new shared contract implementation, after which an observer resolves that behavior declaratively. Source-link the adapter, add it to a builder before freezing, and pass the resulting catalog explicitly into every runtime owner that needs it.

Portable observers and forcings follow the [paired MATLAB and C++ implementation contract](paired-portable-implementations.html). MATLAB remains authoritative, while the runtime accepts only an exact versioned C++ match resolved during preflight.

The forcing subcatalog maps each of the seven qualified MATLAB forcing identities and exact contract versions to a strongly typed source-linked C++ `WVForcing` factory. A resolved forcing owns immutable typed configuration and derived operators and is called once per forcing stage or coefficient-constraint pass, never once per mode or grid point. The frozen schedule retains MATLAB-compatible names, ordering, and persistence, while generic named-value schemas keep the NetCDF reader and writer independent of forcing classes. Duplicate, missing, version-mismatched, malformed, or unavailable entries fail during builder validation or semantic preflight before integration.

Spatial forcing implementations borrow the shared reconstructed physical fields, clear one shared spatial-tendency buffer, and project that tendency through coarse execution-context operations. Linear and quadratic bottom friction both use this path. Constant-stratification descriptors expose the bottom quadrature weight $$L_z/[2(N_z-1)]$$, so portable linear drag derives $$r_\mathrm{scaled}=2(N_z-1)r$$ from the persisted rate $$r$$ without retaining another state-sized field or reconstructing velocity twice.

`WVFieldEvaluationService` owns transform plans and bounded scratch and shares primitive field reconstruction across coincident observers. Particle and tracer tendencies consume the same per-RHS velocity context produced for nonlinear advection, so the runtime does not independently reconstruct or differentiate equivalent quantities.

## Output and restart

`WVOutputPlan` represents explicit, evenly spaced, or source-linked algorithmic schedules independently of the integration method. It retains immutable group schedules rather than enumerating a complete future window. `WVOutputDriver` owns one bounded cursor and cached occurrence per group, finds the next exact timestamp with a simple group scan, validates exact state-layout compatibility, stages failed routes for retry, and commits a proposed cursor only after its route succeeds. Exact coincident timestamps share one state evaluation; tolerance-based timestamp merging is not used. Legacy evenly spaced files retain their original scalar schedule variables. New providers persist exact identity/version, a construction-only typed configuration, and a text-free cursor envelope limited to 4 KiB. State-triggered schedules remain explicitly unsupported.

Developer-facing `WVModelOutputFile` and `WVModelOutputGroup` builders provide MATLAB-shaped output configuration without changing this runtime boundary. `WVModelOutputConfiguration::build()` consumes the mutable builders, resolves observers and schedules through the supplied frozen catalog, and compiles them directly into the authoritative observer descriptor and output plan. Create, transactional replace, and compatible append are graph-wide policies implemented by the existing NetCDF sink; no second scheduler, route graph, or persistence schema is introduced.

`WVModelOutputNetCDFSink` writes MATLAB-compatible records transactionally: payload variables precede the time commit, incomplete records are rejected, and dynamic particle or tracer state is restored with the canonical coefficients. Plans, mappings, derived operators, caches, integrator history, and scratch are never checkpoint data.

`WVModel::createFromModelOutputFiles()` treats the complete reconstructed sibling-file record as the model boundary. Raw inspection remains data-only; its allocation-light semantic preflight then uses the supplied catalog to resolve the dynamics mode, frozen forcing order, observer identities and dependencies, output schedules, committed ordinals, and integration layout before numerical execution. Full-model continuation uses the same descriptor for the integration system, observer evaluation, output plan, and sink. Destination remapping changes paths by stable file identifier only. The reduced coefficient-only reader remains available for the explicit legacy workflow.

The command-line mutation policy is separate from the restart mode. Coefficient-only output requires safe `create` or authorized `replace`. Complete-model requests may create or transactionally replace a complete destination set, or append to a complete compatible set. Path aliases, incompatible append graphs, and existing create destinations are rejected before integration.

## NetCDF and run-request boundary

The standalone CLI consumes a MATLAB-authored NetCDF bundle plus `wave-vortex-run-request-v1` JSON. NetCDF remains the only scientific configuration and restart representation. The JSON decoder is confined to the CLI and produces paths, integration settings, destination policy, and execution settings; it never constructs an observer, forcing, or output schedule.

Validation proceeds in dependency order: strict JSON decoding, data-only sibling-file inspection, catalog-backed paired implementation and forcing validation, integrator bounds, destination remapping, and immutable output-configuration compilation. Only after those allocation-light checks succeed may the CLI construct the FFT provider and `WVModelState`. The prepared `WVModelOutputConfiguration` is moved into `WVModel`, so request handling does not retain or rebuild a second output graph. Library and test clients may call the reusable `runWaveVortex(argc,argv,catalog)` entry point with their own frozen catalog; the executable main constructs the built-in catalog and delegates to it.

Destination remapping is keyed by stable file identifier. Any nonempty remap is complete. Create and replace destinations cannot alias source files; append targets must already contain the same graph and compatible progress. NetCDF definition, transaction handling, committed progress, and payload writing remain owned by `WVModelOutputNetCDFSink`.

The vendored `nlohmann/json` header is pinned to 3.11.3 and used only by the CLI decoder. It adds no runtime binary dependency and does not enter the portable numerical library.

## Extension checklist

For a new integrator:

1. Implement `WVTimeIntegrator` and return an accepted-step object with method-derived dense output.
2. Use `WVIntegrationSystem` for all state blocks, constraints, and error scaling.
3. Prove rejected-step immutability and method-neutral output delivery.

For a new integrated observer:

1. Define its immutable record and dynamic state blocks.
2. Add its portable tag, MATLAB class name, state contract, and output rule through the observer operation on `WVExtensionCatalogBuilder`.
3. Consume shared field services rather than rebuilding transforms or derivatives.
4. Add a test-only adapter that proves validation, evaluation, persistence, restoration, and restart continuation without another subsystem switch.

For a paired forcing:

1. Keep the MATLAB forcing as the authoritative scientific implementation and return its exact versioned immutable contract.
2. Add the MATLAB identity and version through the forcing operation on `WVExtensionCatalogBuilder`, with a construction-time factory, persistence schema, and coarse execution contract, before freezing the catalog.
3. Convert the generic persistence record once into immutable typed configuration and derived operators; resolve stage, priority, tendency, constraints, and restart behavior during preflight.
4. Prove numerical and persistence equivalence without adding class-name dispatch to the forcing engine or integrator.

For every extension, freeze the builder and pass the immutable catalog explicitly through inspection, compilation, model construction, MEX ownership, or `runWaveVortex()` as applicable. Prove catalog-lifetime and multi-catalog isolation in addition to numerical and persistence behavior.

For a new sink, implement guarded preflight and transactional route delivery without inspecting the integration method.
