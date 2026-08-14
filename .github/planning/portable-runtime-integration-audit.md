# Portable Runtime Integration Audit

Issue: [#216](https://github.com/JeffreyEarly/wave-vortex-model/issues/216)

Authoritative record: [`portable-runtime-integration-audit.json`](portable-runtime-integration-audit.json)

Outcome: **SAFE TO INTEGRATE**

The audit reconciles `feature/portable-runtime-v1` at `d673617` with `feature/portable-observing-systems-v1` at `e7e46c7`. The reconciled baseline is `b865a14`; the two accepted simplifications are recorded by `5ed5ec4`. Public APIs, numerical methods, persisted schemas, fixtures, and canonical measurements are unchanged.

## Architecture map

| Layer | Owns | May depend on | Must not own |
|---|---|---|---|
| `CompiledKernel` | Constant-stratification numerical kernel and FFT-engine interface | C++17 | MATLAB, MEX, NetCDF, FFTW, Accelerate, or Apple APIs |
| Portable numerics | Forcing, field evaluation, fixed/adaptive integration, composite state evolution | `CompiledKernel` | Persistence or MATLAB behavior |
| Observing and output | Observer descriptors, schedules, field sampling, delivery | Portable numerical contracts and `WVObserverAdapter` | Numerical method selection or NetCDF implementation |
| Persistence | Checkpoint/model-output schema, reading, transactional writing | Public runtime records and NetCDF | Time stepping or field reconstruction |
| Standalone CLI | Provider selection and composition of public runtime services | Public runtime and provider adapters | Scientific algorithm duplication or direct NetCDF calls |

The dependency direction is:

```text
CompiledKernel
    ↓
portable numerical services
    ↓
observing/output orchestration
    ↓
persistence adapters
    ↓
standalone CLI composition
```

## Changes accepted before integration

- Consolidated identical checkpoint-state validation, coefficient staging, time assignment, and capacity accounting used by single-target and series output sinks.
- Removed the misleading internal `WaveVortex::Checkpoint` CMake alias; every tool and test now names the complete `WaveVortex::PortableRuntime` target.

Both changes are internal and preserve the exact copies, error messages, storage, and write policies.

## Retained complexity

| Finding | Disposition | Rationale |
|---|---|---|
| Canonical and composite integration families | Follow up after integration | Both are stable public boundaries. Convergence changes driver, dense-output, CLI, and persistence relationships and therefore belongs in [#222](https://github.com/JeffreyEarly/wave-vortex-model/issues/222). |
| Shared checkpoint/model-output persistence records | Retain | Both formats encode the same `wave-vortex-4x-v1` model, state, and forcing profile. Shared records avoid conversion and duplicate status types. |
| Large NetCDF reader/writer implementation | Retain | Schema, reader, writer, and observer dispatch responsibilities are already separated. File length alone is not an architectural defect. |
| Closed five-observer registry | Retain | `portable-observers-v1` intentionally has no plug-in ABI; custom MATLAB subclasses remain unsupported. |
| CLI lacks observer-graph configuration | Retain for v1 | This is a documented product limitation rather than hidden fallback or duplicated logic. |
| Runtime remains in WaveVortexModel | Retain | There is not yet an independent consumer, release cadence, or API-versioning need that justifies repository extraction. |

## Deleted and consolidated code

- Removed one redundant CMake alias and replaced its twelve internal uses.
- Replaced two copies of checkpoint-state staging and two copies of coefficient-capacity accounting with private shared helpers.
- Added no public types, persistent state, wire fields, caches, or execution paths.

## Safe-to-merge checklist

- [x] Portable-runtime distribution and observing-system histories are reconciled without rebasing.
- [x] `CompiledKernel` remains independent of MATLAB, MEX, NetCDF, FFTW, Accelerate, and Apple APIs.
- [x] Observer identity and built-in dispatch remain centralized in `WVObserverAdapter`.
- [x] Public APIs and `portable-observers-v1`/`wave-vortex-4x-v1` schemas are unchanged.
- [x] #203 compatibility evidence and checkpoint fixtures remain unchanged.
- [x] #214 preserves one content-addressed documentation payload per unique byte stream.
- [x] Exported source contains the complete runtime build path and no downloaded or compiled product.
- [x] Every audit finding is resolved, deferred through a bounded issue, or intentionally retained with rationale.

Issue #217 may proceed after this audit reaches `feature/portable-observing-systems-v1`. It must still integrate the portable runtime and observing-system layers into `main` through separate pull requests.
