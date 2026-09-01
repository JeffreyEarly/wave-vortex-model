# Free-Surface QG Coefficient-Storage Decision

Status: Accepted Issue #343 implementation decision for [milestone 22](https://github.com/JeffreyEarly/wave-vortex-model/milestone/22).

## Decision

Retain `Ag_q`, `Ag_0`, and `Amda` as three separate integrator entries in annotation order. Do not adopt the private packed-integrator adapter.

This decision changes neither the public coefficient properties nor the family-keyed tendency and persistence contracts. The private packed candidate remains authoring-only benchmark code and is excluded from the runtime package. The public and persisted layouts remain those in the [Phase 1 coefficient-state contract](free-surface-coefficient-state-contract.md).

The selection rule required packed storage to pass every correctness gate and to place the upper endpoint of its 95% bootstrapped packed/separate fixed-RK4 median-ratio interval below `0.97` in every endpoint/grid case. Otherwise the existing separate representation was retained. No case met that rule.

## Fair baseline

The pre-benchmark audit found that production `WVCoefficients` reconstructed every coefficient annotation during every RHS evaluation. That cost is metadata discovery, not a consequence of separate coefficient backing. `WVCoefficients` now caches immutable family names and shapes once at observer construction, while annotations remain authoritative for constructing that cache.

Both benchmark candidates therefore use the same construction-time metadata policy:

- `separate`: production `WVCoefficients`, with one integrator entry per annotation;
- `packed`: [`WVFreeSurfaceQGPackedCoefficientAdapter`](../../Benchmarks/WVFreeSurfaceQGPackedCoefficientAdapter.m), with one complex column vector unpacked to the same public properties before each RHS.

The packed adapter changes no transform, tendency, forcing, or NetCDF interface. Every candidate invocation crosses the public `Ag_q`, `Ag_0`, and `Amda` setters and executes the same complete nonlinear tendency.

## Canonical evidence

The immutable artifact is [`free-surface-qg-coefficient-storage-v1-m5-max-r2026a`](../../Benchmarks/results/reference/free-surface-qg-coefficient-storage-v1-m5-max-r2026a/summary.md). It was produced on MATLAB R2026a Update 4 (`maca64`) with the active `InternalModesEVP` checkout at `b0ab431f8b1ed2f36c1b1acad10684ac80b669a3`. The runner, adapter, tests, artifact, and this decision are co-committed so the WaveVortexModel source identity is the containing commit.

The matrix uses a 150 km by 150 km by 1000 m domain and constant `N2=1e-4 s-2`:

- small: `64 × 64 × 33`, automatic common mode selection at the InternalModes default quadratic-aliasing tolerance `0.1`;
- representative: `256 × 256 × 129`, a matched certified `Nj=10` prefix for every endpoint case;
- active endpoints: zero, surface only, and surface plus bottom;
- timing: one warmup and five samples for reconstruction, projection, complete RHS, integrator copy/update, and a complete fixed-RK4 step;
- statistics: 10,000 deterministic bootstrap resamples of the ratio of independent medians;
- memory: exact MATLAB payload bytes from `whos` plus fresh-process, phase-scoped total process-tree RSS.

The representative fixed prefix remains well below the default `0.1` certificates: the zero-, one-, and two-endpoint common certified maxima were 86, 41, and 42 modes. A fixed prefix was necessary because the automatic two-endpoint construction refitted the MDA transform at the APV-limited common count and `lsqlin` exited without converging. That scientific-construction defect belongs to #346 and is not hidden by the artifact.

The subsequent coefficient-state contract permits APV and MDA to retain different counts. Scientific construction now delegates independently refitted family-count selection to InternalModesEVP and never truncates MDA merely to match APV. Its APV Gram, MDA Gram, APV quadratic-aliasing, and APV inversion singularity tolerances are initialization options. Family-specific weights, shared-grid provenance, and compact certification results are persisted. The immutable benchmark artifact and its historical `commonCertifiedModeCount` fields remain unchanged because the storage decision compared matched states under the contract in force when it was recorded.

## Results

Every state, RHS, copy/update result, and RK4 result agreed exactly between candidates at the benchmark's `5e-13` relative correctness gate.

| Case | `Nj` | Packed/separate complete RHS | Packed/separate copy/update | Packed/separate RK4 median | RK4 ratio 95% interval | Packed/separate exact state bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Small, zero endpoint | 21 | 1.0358 | 1.8091 | 1.0921 | `[0.8259, 1.4060]` | 1.00070 |
| Small, one endpoint | 5 | 1.0149 | 2.2266 | 1.0473 | `[0.7847, 1.4033]` | 1.00058 |
| Small, two endpoints | 5 | 1.0963 | 2.0776 | 1.0209 | `[0.6545, 1.3233]` | 1.00050 |
| Representative, zero endpoint | 10 | 1.0173 | 2.1377 | 1.0134 | `[0.9748, 1.0525]` | 1.00004 |
| Representative, one endpoint | 10 | 1.0234 | 2.5116 | 1.0129 | `[0.9676, 1.0588]` | 1.00004 |
| Representative, two endpoints | 10 | 1.0004 | 2.3773 | 0.9988 | `[0.9148, 1.0379]` | 1.00004 |

Packing provides no demonstrated end-to-end gain. Its copy/update path is 1.81–2.51 times slower because every stage allocates or traverses the packed vector and then unpacks it through three canonical setters. It also turns real `Amda` storage into complex storage, adding exactly eight bytes per retained MDA coefficient. Process RSS varies by allocator state and construction history and shows no consistent packed advantage; it is retained as secondary evidence rather than used to infer copy-on-write behavior.

## Consequences

- Production integration keeps one cell entry per coefficient annotation.
- Annotation order remains `Ag_q`, `Ag_0`, `Amda`.
- No packed production adapter, buffer invalidation policy, or packing API is introduced.
- The metadata cache in `WVCoefficients` is retained because it improves the reference path without changing its state representation.
- The authoring-only packed adapter remains available to reproduce or extend the decision but is not shipped by `resources/mpackage.json`.
- Public properties, family-keyed tendencies, observing-system discovery, and NetCDF variables require no migration.

## Acceptance audit for #344–#347

| Issue | Current evidence | Remaining acceptance work | Assessment |
| --- | --- | --- | --- |
| [#344](https://github.com/JeffreyEarly/wave-vortex-model/issues/344) transform/state | `WVTransformFreeSurfaceQG` exposes and persists the three canonical families; four endpoint configurations, independent APV/MDA counts, mutation, cache invalidation, MDA constraints, direct construction, snapshot/output restart, and inactive-family omission have focused tests. #343 now selects the required backing. | Preserve legacy rigid-lid regressions in the final series gate. | Implementation substantially satisfies #344; its issue text still describes the superseded common-count contract. |
| [#345](https://github.com/JeffreyEarly/wave-vortex-model/issues/345) modes/operators | APV and MDA bases and distinct-`kh` zero-APV pages are built once and persisted. Pure APV, pure zero APV, MDA, mixed, axial/oblique page reuse, generalized-energy diagnostics, inactive constraints, and direct persisted restoration are exercised. | Add an explicit maximum-retained-`kh` zero-APV endpoint-residual assertion when completing #346's certification suite. | Core assembly and analytical projection are implemented; the remaining certification edge belongs with #346. |
| [#346](https://github.com/JeffreyEarly/wave-vortex-model/issues/346) grid and retained counts | The default shared grid is explicitly APV-designed; APV and MDA weights and counts are independently fitted and persisted; explicit family counts above their respective certified maxima are rejected; the `0.1` APV product-aliasing tolerance and compact diagnostics are exposed. The MDA refit at an APV-limited common count has been removed. | Add independent over-resolved product experiments, threshold provenance, depth-closure checks, alternative-grid comparisons, and maximum-`kh` zero-APV residual coverage. | The construction-path blocker is resolved; the remaining work is the planned scientific certification study. |
| [#347](https://github.com/JeffreyEarly/wave-vortex-model/issues/347) nonlinear tendency | The complete QGPV and endpoint-advection RHS is present. Manufactured projection, all endpoint configurations, pure/mixed horizontal and vertical refinement, exact zero MDA tendency, physical reality, and matched packed/separate RK4 behavior pass focused tests. | Promote the current refinement check into the independently over-resolved vertical product/projection experiment required by the issue, and record the selected procedure and tolerance after #346 supplies reproducible representative modes. | Core dynamics are implemented; the retained numerical investigation is not yet complete. |

No GitHub issue was edited or closed by this increment.
