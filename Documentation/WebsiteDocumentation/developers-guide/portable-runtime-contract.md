---
layout: default
title: Portable runtime contract
parent: Developers guide
nav_order: 12
---

# Portable runtime contract

The portable runtime composes the MATLAB-independent `WaveVortexKernel` with integration, field evaluation, observing-system adapters, and NetCDF persistence. MATLAB/MEX, NetCDF, FFTW, and Apple APIs remain outside the numerical core.

## Integration boundaries

`WVIntegrationStateLayout` describes canonical `Ap`, `Am`, and `A0` plus zero or more typed observer-owned blocks. Coefficient-only execution is the same representation with no additional blocks.

`WVIntegrationSystem` owns right-hand-side evaluation, constraints, and error scaling. `WVTimeIntegrator` advances accepted state. `WVDenseOutput` evaluates state inside an accepted step from that method's Runge--Kutta data. Output scheduling consumes only these interfaces: adding another integrator must not add method branches to the output driver, and adding another state block must not change an integrator.

The runtime supplies classical fixed RK4 and Bogacki--Shampine RK3(2). Rejected adaptive attempts do not mutate accepted state or emit output. Interpolated output never becomes accepted state.

## Observers and fields

`WVObserverFactoryRegistry` is the single source-level extension point for observer kinds. Each registration binds a portable tag and MATLAB class name to one state contract and one output rule. Validation, integration-state dependencies, field evaluation, NetCDF schema creation, writing, restoration, and append all consult that registration; none dispatch directly on the observer kind. The five qualified MATLAB observers are pre-registered through the same mechanism.

The registry is intentionally a native source API rather than a third-party binary plug-in ABI. A new observer can reuse the existing coefficient, full-grid field, mooring, particle, or tracer behavior without editing the runtime subsystems. A genuinely new state or output behavior first requires a new shared contract implementation, after which observer kinds select it declaratively. Register adapters before constructing descriptors or starting concurrent runtime work; registrations are immutable for the process lifetime.

`WVFieldEvaluationService` owns transform plans and bounded scratch and shares primitive field reconstruction across coincident observers. Particle and tracer tendencies consume the same per-RHS velocity context produced for nonlinear advection, so the runtime does not independently reconstruct or differentiate equivalent quantities.

## Output and restart

`WVOutputPlan` represents explicit or evenly spaced events independently of the integration method. `WVOutputDriver` validates exact state-layout compatibility, stages failed routes for retry, and delivers immutable event state to a sink. Sink callbacks are non-reentrant.

`WVModelOutputNetCDFSink` writes MATLAB-compatible records transactionally: payload variables precede the time commit, incomplete records are rejected, and dynamic particle or tracer state is restored with the canonical coefficients. Plans, mappings, derived operators, caches, integrator history, and scratch are never checkpoint data.

The command-line program exposes one checkpoint input and output. Multi-file and named-group orchestration remain C++ library APIs until a separate user-facing configuration contract is designed.

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

For a new sink, implement guarded preflight and transactional route delivery without inspecting the integration method.
