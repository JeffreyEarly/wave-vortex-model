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

`WVObserverFactoryRegistry` is the single source-level extension point for observer kinds. Each registration binds a portable tag and MATLAB class name to one state contract and one output rule. Validation, integration-state dependencies, field evaluation, NetCDF schema creation, writing, restoration, and append all consult that registration; none dispatch directly on the observer kind. The five qualified MATLAB observers are pre-registered through the same mechanism.

Each registration also carries the exact `wave-vortex-portable-pair-v1` contract version. MATLAB's `portableImplementationContract()` and the C++ registry must agree on the class identity and version before descriptor construction. The registry is sealed by the first descriptor construction so integration never observes changing dispatch state.

The registry is intentionally a native source API rather than a third-party binary plug-in ABI. A new observer can reuse the existing coefficient, full-grid field, mooring, particle, or tracer behavior without editing the runtime subsystems. A genuinely new state or output behavior first requires a new shared contract implementation, after which observer kinds select it declaratively. Register adapters before constructing descriptors or starting concurrent runtime work; registrations are immutable for the process lifetime.

Portable observers and forcings follow the [paired MATLAB and C++ implementation contract](paired-portable-implementations.html). MATLAB remains authoritative, while the runtime accepts only an exact versioned C++ match resolved during preflight.

`WVForcingFactoryRegistry` is separate from the observer registry. Its registrations map the six qualified MATLAB forcing identities to the existing typed payload and execution contracts. The frozen schedule retains MATLAB-compatible names, order, payloads, and persistence, but hot paths dispatch only on resolved operations. The registry is sealed at schedule construction; duplicate, missing, version-mismatched, and late registrations fail before integration.

`WVFieldEvaluationService` owns transform plans and bounded scratch and shares primitive field reconstruction across coincident observers. Particle and tracer tendencies consume the same per-RHS velocity context produced for nonlinear advection, so the runtime does not independently reconstruct or differentiate equivalent quantities.

## Output and restart

`WVOutputPlan` represents explicit, evenly spaced, or source-linked algorithmic schedules independently of the integration method. It retains immutable group schedules rather than enumerating a complete future window. `WVOutputDriver` owns one bounded cursor and cached occurrence per group, finds the next exact timestamp with a simple group scan, validates exact state-layout compatibility, stages failed routes for retry, and commits a proposed cursor only after its route succeeds. Exact coincident timestamps share one state evaluation; tolerance-based timestamp merging is not used. Legacy evenly spaced files retain their original scalar schedule variables. New providers persist exact identity/version, a construction-only typed configuration, and a text-free cursor envelope limited to 4 KiB. State-triggered schedules remain explicitly unsupported.

Developer-facing `WVModelOutputFile` and `WVModelOutputGroup` builders provide MATLAB-shaped output configuration without changing this runtime boundary. `WVModelOutputConfiguration::build()` consumes the mutable builders and compiles them directly into the authoritative observer descriptor and output plan. Create, transactional replace, and compatible append are graph-wide policies implemented by the existing NetCDF sink; no second scheduler, route graph, or persistence schema is introduced.

`WVModelOutputNetCDFSink` writes MATLAB-compatible records transactionally: payload variables precede the time commit, incomplete records are rejected, and dynamic particle or tracer state is restored with the canonical coefficients. Plans, mappings, derived operators, caches, integrator history, and scratch are never checkpoint data.

`WVModel::createFromModelOutputFiles()` treats the complete reconstructed sibling-file record as the model boundary. Its allocation-light preflight resolves the dynamics mode, frozen forcing order, observer identities and dependencies, output schedules, committed ordinals, and integration layout before numerical execution. Full-model continuation uses the same descriptor for the integration system, observer evaluation, output plan, and sink. Destination remapping changes paths by stable file identifier only. The reduced coefficient-only reader remains available for the explicit legacy workflow.

The command-line mutation policy is separate from the restart mode. Coefficient-only output requires safe `create` or authorized `replace`. Complete-model requests may create or transactionally replace a complete destination set, or append to a complete compatible set. Path aliases, incompatible append graphs, and existing create destinations are rejected before integration.

## NetCDF and run-request boundary

The standalone CLI consumes a MATLAB-authored NetCDF bundle plus `wave-vortex-run-request-v1` JSON. NetCDF remains the only scientific configuration and restart representation. The JSON decoder is confined to the CLI and produces paths, integration settings, destination policy, and execution settings; it never constructs an observer, forcing, or output schedule.

Validation proceeds in dependency order: strict JSON decoding, complete sibling-file inspection, paired implementation and forcing validation, integrator bounds, destination remapping, and immutable output-configuration compilation. Only after those allocation-light checks succeed may the CLI construct the FFT provider and `WVModelState`. The prepared `WVModelOutputConfiguration` is moved into `WVModel`, so request handling does not retain or rebuild a second output graph.

Destination remapping is keyed by stable file identifier. Any nonempty remap is complete. Create and replace destinations cannot alias source files; append targets must already contain the same graph and compatible progress. NetCDF definition, transaction handling, committed progress, and payload writing remain owned by `WVModelOutputNetCDFSink`.

The vendored `nlohmann/json` header is pinned to 3.11.3 and used only by the CLI decoder. It adds no runtime binary dependency and does not enter the portable numerical library.

## Extension checklist

For a new integrator:

1. Implement `WVTimeIntegrator` and return an accepted-step object with method-derived dense output.
2. Use `WVIntegrationSystem` for all state blocks, constraints, and error scaling.
3. Prove rejected-step immutability and method-neutral output delivery.

For a new integrated observer:

1. Define its immutable record and dynamic state blocks.
2. Register its portable tag, MATLAB class name, state contract, and output rule with `WVObserverFactoryRegistry`.
3. Consume shared field services rather than rebuilding transforms or derivatives.
4. Add a test-only adapter that proves validation, evaluation, persistence, restoration, and restart continuation without another subsystem switch.

For a paired forcing:

1. Keep the MATLAB forcing as the authoritative scientific implementation and return its exact versioned immutable contract.
2. Register the MATLAB identity with one existing typed payload and execution operation before schedule construction.
3. Resolve stage, priority, payload validation, derived operators, tendency, constraint, and restart behavior during preflight.
4. Prove numerical and persistence equivalence without adding class-name dispatch to the forcing engine or integrator.

For a new sink, implement guarded preflight and transactional route delivery without inspecting the integration method.
