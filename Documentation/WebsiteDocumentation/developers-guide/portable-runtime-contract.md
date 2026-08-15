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

`WVObserverAdapter` is the single registry for the five supported built-in records. It owns the portable tag, MATLAB class name, state contract, metadata, evaluation, and persistence dispatch. Adding a built-in requires updating that registry and its compatibility tests; there is no third-party binary plug-in ABI.

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
2. Register its metadata, evaluation, and persistence in `WVObserverAdapter`.
3. Consume shared field services rather than rebuilding transforms or derivatives.
4. Add MATLAB/C++ round-trip and restart-continuation tests.

For a new sink, implement guarded preflight and transactional route delivery without inspecting the integration method.
