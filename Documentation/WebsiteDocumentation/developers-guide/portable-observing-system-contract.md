---
layout: default
title: Portable observing-system contract
parent: Developer guide
nav_order: 10
---

# Portable observing-system contract

The `portable-observers-v1` contract separates four concerns that MATLAB's `WVObservingSystem` hierarchy combines: integrated state, observation evaluation, output scheduling, and persistence. The records contain standard C++ values only. They do not contain MATLAB, MEX, NetCDF, or Apple-specific types.

`WVPortableObserverDescriptor` validates and freezes the records. `WVObserverFactoryRegistry` maps the five qualified built-in tags to their WaveVortexModel names; it is a construction seam, not a stable third-party binary plugin ABI. Unknown tags and custom MATLAB subclasses are rejected before integration or file mutation.

## Integrated state

Canonical `Ap`, `Am`, and `A0` remain three caller-owned complex `[Nj,Nkl]` arrays. The C++ numerical core sees the same zero-copy `WVState` views used before composite state was introduced. Additional integrated state is an ordered sequence of named real or complex blocks. Each block records its natural dimensions, ownership, absolute-tolerance policy, and restart requirement.

`WVCompositeStateLayout` resolves identifiers, element counts, and typed storage offsets once. RK stages consume ordered views, so hot loops perform no name lookup or per-element virtual dispatch. Observer-derived sampled values are not integrated and therefore do not occupy integrator workspace.

`WVConstantStratificationCompositeSystem` is the first concrete integrated-observer adapter. It delegates the coefficient tendency and constraints to `WVConstantStratificationForcingEngine`, resolves every particle's ordered state blocks once, and evaluates all particle velocities through one shared moving-position primitive transform. Horizontal particle state remains unwrapped exactly as it does in MATLAB; only interpolation coordinates are reduced periodically. An XY-only particle system carries one fixed configured depth per particle, while an XYZ system integrates all three coordinates. Tracers remain deliberately rejected until their separate runtime implementation.

The existing coefficient-only `WVFixedStepRK4` and `WVAdaptiveRK23` paths remain specialized and unchanged. `WVCompositeFixedStepRK4` and `WVCompositeAdaptiveRK23` retain the same numerical methods while adding typed block loops. Dense output is method-owned, writes to caller storage, and never becomes accepted state.

## MATLAB compatibility matrix

| MATLAB observer | Portable tag | Integrated state | Sampled/configuration fields | Interpolation and tolerance | Restart rule |
|---|---|---|---|---|---|
| `WVCoefficients` | `WVCoefficients` | `Ap`, `Am`, `A0`: complex `[Nj,Nkl]` | Canonical wave-vortex coefficients | Energy-scaled coefficient tolerance from `absTolerance` | All three arrays are required dynamic state and provide the complete coefficient restart |
| `WVEulerianFields` | `WVEulerianFields` | None | `fieldNames`; MATLAB-compatible initial-only versus time-series categorization | No integrated tolerance | Values are derived; field selection is configuration. Linear Ap/Am/A0 provide the initial-only coefficient restart. |
| `WVMooring` | `WVMooring` | None | `name`, `x`, `y`, `trackedFieldNames`; output profiles retain their natural vertical dimension | Fixed-location evaluation; no integrated tolerance | Positions and field selection are configuration; sampled profiles are derived |
| `WVLagrangianParticles` | `WVLagrangianParticles` | Real `x`, `y`, and optionally `z` blocks | `name`, initial positions, `isXYOnly`, `trackedFieldNames` | `advectionInterpolation` and tracked-field interpolation are `linear` or `spline`; horizontal and vertical absolute tolerances are explicit | Integrated positions are required dynamic state; tracked fields are derived |
| `WVTracer` | `WVTracer` | One real tracer block with its natural two- or three-dimensional shape | `name`, `isXYOnly`, `shouldAntialias` | Uniform `absTolerance` | Tracer values are required dynamic state; antialiasing is configuration |

Output-file records identify a destination. Ordered output-group records identify a name, interval and time bounds, observer references, and which single group carries a complete coefficient restart. `WVModelOutputNetCDFSink` maps those records to MATLAB-compatible annotated groups, unlimited time dimensions, observer metadata, dynamic observer state, derived observations, and real/imaginary coefficient pairs. Nonlinear dynamics use the `WVCoefficients` time series. Linear dynamics use the `WVEulerianFields` initial-only Ap/Am/A0 values while time-dependent Eulerian and mooring variables continue on the group's time axis. Exactly one physical coefficient stream exists per file even when observer metadata refers to those coefficients from more than one observer.

`WVObserverOutputEvaluationService` implements the `WVCoefficients`, `WVEulerianFields`, `WVMooring`, and `WVLagrangianParticles` evaluation boundary. It compiles field plans from the configured observers, coalesces identical fixed requests, and evaluates moving particle requests only when an event route contains those particles. Coincident particle systems share one primitive transform. The service may borrow the composite system's field evaluator so output adds no second transform or FFT-plan owner. Coefficients remain borrowed state views; tracked particle values occupy bounded result buffers.

Particle output follows the MATLAB schema: `<name>_id` is one-based, coordinate and tracked variables use logical `[id,t]` order, and every particle variable carries `isParticle`, `particleName`, and `particleVariableName` attributes. XY-only fixed depths are written at every output event but are not integrated. Configuration, tolerances, interpolation choices, and shared identities are persisted; interpolation weights, plans, and scratch are rebuilt after restart.

New destinations are initialized as a staged set before any final path becomes visible. Each append writes all payload slabs first, writes the scheduled time as the record commit marker, and synchronizes the containing file before advancing its continuation ordinal. A failed route can therefore be retried at the same record index. Inspection rejects incomplete payloads, mismatched schedules or shapes, unsupported annotated observer classes, broken references, and conflicting shared-observer metadata before integration advances.

The reader reconnects repeated observers by the runtime's persisted `portableIdentifier` when present. Existing MATLAB files without that additive attribute use deterministic class/name/configuration identities, and conflicting records are rejected instead of silently duplicated. The reconstructed result owns the latest canonical coefficients, the composite state layout, required particle/tracer state, the multi-file observer graph, and one committed schedule ordinal per group.

## Validation boundary

Descriptor construction rejects duplicate block, observer, file, group, and destination identities; zero or overflowing dimensions; incompatible canonical coefficient shapes; invalid ownership/restart combinations; unknown tags or references; invalid particle coordinates and tolerances; and ambiguous restart responsibility. Unsupported transform families and custom observers must be rejected by the future runtime factory before any state allocation, integration, or output mutation.

The observer schema is versioned independently of `WVKernelContractVersion`. Adding composite observer state does not change the numerical core's version-4 coefficient contract.
