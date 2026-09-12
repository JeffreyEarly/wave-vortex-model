# Remaining RHS scheduling assessment (#484)

This study assesses transient spectral-pressure reuse, fixed setup, and source-only assembly against v5 `fadb169d03fa5a64e6e137dc1169a83583f34407`. It holds displacement, divergence-form advection, modal pressure, retained modes, and dense vertical differentiation fixed. The earlier cache integration and exact wave factorization remain in place.

## Candidates and cache ownership

`production` invokes the existing coefficient callback. `baseline` is an authoring control with the same mathematics through the candidate reconstruction wrapper. `setup` prepares the derivative handles and fixed coordinate arrays once per study object. `source` omits the unused linear/total/physical diagnostic assembly inside the nonlinear-term evaluator. `spectral` consumes pressure synthesis transiently to form horizontal spectral multipliers and a dense vertical matrix application before inverse transforms; it omits the spatial pressure inverse. `combined` applies all three candidates. A second comparison adds `state`, which copies the six canonical arrays directly for total reconstruction, and `stateSource`, which combines that copy with source-only assembly. Component requests retain the shared coefficient-selection protocol. Public coefficient annotations are mutable handles and are not cached or shared.

The study subclass mirrors the parent's inaccessible private thermodynamic and surface contexts. It preserves their definitions and excludes setup from timing. The integrated implementation continues to use the original private contexts. For reproduction after integration, `RHSSchedulingReference` freezes the pre-change reconstruction, nonlinear wrapper, and complete term evaluator; the initial candidate CSVs were recorded against actual production at the baseline revision.

Every candidate uses the existing operation-name validation, component ownership checks, field cache, and coefficient/clock invalidation. No independent pressure cache is added. On the spectral path, no pressure value is fabricated or inserted into the cache. The study's two-output reconstruction method returns pressure gradients to the RHS; ordinary one-output field requests retain their normal behavior. If spatial pressure is already cached, the RHS uses it with directional derivatives. If only pressure is missing after an earlier RHS, it is reconstructed normally and becomes eligible for ordinary warm reuse. This avoids repeatedly synthesizing a spectrum merely to sustain the candidate route.

The study subclass is a qualification tool, not a proposed public API. Any adopted implementation must share the production reconstruction machinery without adding a public gradient-return convention.

## Protocol

Fixtures use constant N²=1e-4 s^-2 and exponential N²=1e-4 exp(z/650) s^-2, a 100 km ×100 km ×1 km domain, nEVP=256, and explicitly qualified nonlinear inventories (`shouldAntialias=true`, `shouldCheckQuadraticAliasing=true`). Grids and APV/wave/MDA/inertial counts are:

| Grid | Counts |
| --- | --- |
| 8×8×33 | 3 / 4 / 2 / 3 |
| 8×8×65 | 3 / 4 / 2 / 3 |
| 16×16×65 | 6 / 8 / 4 / 6 |
| 24×24×129 | 10 / 12 / 8 / 8 |

The mixed-state fixture comes from `manuscriptEvolutionOperators`, amplitude 0.1 and initial clock 327 s, including both wave signs, APV, boundary modes, inertial and mean-density contributions. Its mean offsets keep parcel labels valid. Factory setup is excluded; task-local saved scientific fixtures avoid repeated eigensolves during authoring, and are not production caches or committed artifacts.

Each timing compares the complete `coefficientTendency` callback with nonlinear advection registered normally. Cold calls clear dependent field caches; overlap calls include a preceding `u_hat,p,ssh` request; warm calls retain eligible fields; successive calls advance time by 0.01 s, invalidating the fields. Three warmups precede five alternating-order trials of 30 evaluations. Profile output identifies work but is not used as benchmark time. Source tolerances are 3e-10 relative plus 1e-17 absolute; coefficient tolerances are 3e-10 plus 1e-18. No tolerance is relaxed to qualify an optimization.

Adoption requires repeatable complete-call benefit beyond trial variability, preserved accuracy/cache/restart behavior, and no unjustified setup or invalidation complexity. Isolated kernel speedups and changes attributable to the study wrapper are insufficient. Retaining the current implementation is a valid completion.

## Reproduction

With manifest-compatible dependencies and WVM on the MATLAB path:

```matlab
addpath('tools/rhs-scheduling-study','tools/nonlinear-study', ...
    '../OceanKit/tools/profiling')
prepareRHSSchedulingStudy('/tmp/484-fixtures')
runRHSSchedulingBenchmarks('/tmp/484-fixtures')
runRHSSchedulingBenchmarks('/tmp/484-fixtures', ...
    strategies=["production","baseline","state","stateSource"],prefix="state-candidate")
```

The fixture directory is an explicit local input to subsequent qualification; regenerate it for the recorded baseline rather than reusing unrelated state files. The profiling driver records project-level self times and actionable lines. The benchmark records all trial times and equivalence errors separately.

Run final timings in a **fresh MATLAB process**, separately from tests and profiling:

```matlab
addpath('tools/rhs-scheduling-study')
runFinalRHSScheduling('/tmp/484-fixtures')
runRHSSchedulingTrajectories('/tmp/484-fixtures')
```

Final timing uses twenty warmups and seven alternating trials of fifty complete callbacks. The frozen reference has the same lazy context definitions and field ownership as the old production code. An initial timing attempt immediately after profiler-based tests was discarded: its absolute costs and relative ordering differed from fresh-process results. The committed final CSV contains only the isolated run. Do not combine profiler/test execution and wall-time qualification in one process.

## Disposition

Integrate direct total-state copying and source-only assembly. The reconstruction cache is still checked first; component selection still uses `coefficientState`. `freeSurfaceNonlinearTerms` returns its full diagnostic inventory by default, while the RHS explicitly requests only `source`. No source equation, transform, projection, phase, persistent state, or public field behavior changes.

Retain directional pressure differentiation. Across the exploratory trials, transient spectral pressure offered only small, grid-dependent gains after accounting for the control wrapper; it adds reconstruction/RHS coupling and an extra surface inverse. Fixed derivative handles and coordinate arrays likewise did not justify another setup owner. Both candidates remain reproducible authoring code, with no production switch or unfinished implementation dependency.

## Operation accounting

The accepted changes remove six coefficient-annotation constructions per total reconstruction and the unused linear/total/physical diagnostic assembly. Warm reconstruction already skips state copying. Overlap may perform two total reconstructions and benefits twice. Array arithmetic and all transform/modal counts keep their existing asymptotic orders.

| Cold operation | Retained production | Spectral-pressure candidate |
| --- | ---: | ---: |
| Volume field/gradient inverse 2D transforms | 5 | 7 |
| Volume source forward 2D transforms | 4 | 4 |
| Volume directional 1D FFT passes | 20 | 16 |
| Surface directional 1D FFT passes | 8 | 8 |
| Additional surface 2D inverse | 0 | 1 |
| Dense vertical applications | 5 on Z×H | 4 on Z×H + 1 on Z×K |

Thus both cold schedules have 19 volume transform equivalents; production has 4 surface equivalents, the tested pressure candidate 5. Modal synthesis/projection is unchanged. The ideal note's distinct schedule has its own surface count. These counts describe schedules, not minima. The mapped MATLAB derivative remains dense. Fast vertical differentiation and structured modal transforms retain their separate future scopes.

## Final measured result

MATLAB R2026a Update 4 on Apple M5 Max, with InternalModes v2.0.0-beta.4, SplineCore 2.2.0, NetCDF 1.0.2, ClassAnnotations 1.2.1, ClassDocumentation 1.3.2, and Chebfun `1fe01297a74d9ee765a466c3068b7fb474bee053`. The baseline is `fadb169d03fa5a64e6e137dc1169a83583f34407`; these are local measurements, not platform-independent speed guarantees.

| Profile | Grid | Cold before/after (ms) | Successive before/after (ms) |
| --- | --- | ---: | ---: |
| constant | 8×8×33 | 2.297 / 1.656 | 1.438 / 1.035 |
| constant | 8×8×65 | 2.789 / 2.080 | 2.186 / 1.668 |
| constant | 16×16×65 | 4.602 / 4.157 | 4.410 / 3.928 |
| constant | 24×24×129 | 11.419 / 10.803 | 11.355 / 10.771 |
| exponential | 8×8×33 | 1.514 / 1.110 | 1.563 / 1.193 |
| exponential | 8×8×65 | 2.266 / 1.867 | 2.174 / 1.781 |
| exponential | 16×16×65 | 5.110 / 4.551 | 4.917 / 4.474 |
| exponential | 24×24×129 | 14.277 / 13.782 | 14.242 / 13.692 |

Cold calls improved 3–28%, successive-state calls 4–28%, and overlapping requests 7–35%. Warm calls ranged from 3.3% slower to 3.4% faster; no meaningful warm-cache gain is claimed. At 16×16×65, the 40-second RK4 trajectories (eight steps, 32 complete RHS calls) improved 12.5% for constant and 7.8% for exponential stratification, with exactly equal final coefficients. These short trajectories test scheduling equivalence, not long-time physical resolution.

[Final callback trials](results/final-rhs.csv), [trajectory trials](results/final-trajectories.csv), [initial candidates](results/candidates.csv), [state-copy candidates](results/state-candidates.csv), and their equivalence CSVs retain the individual measurements. The frozen reference and candidate wrapper keep conclusions separate from isolated kernel timing.

## Verification

The candidate comparisons include 640 quantity checks across eight fixtures. The state-copy/source-only candidate is bit-for-bit equal to the original sources and rates; the pressure candidates' maximum absolute difference is 5.4e-18. The integrated production tests require exact equality to the frozen baseline across constant/exponential profiles, six individual families and mixed states, amplitudes 1e-4/0.1/1, clocks 0/327/901, reference-time changes, cold/warm/overlap requests, coefficient invalidation, and restart. A separate factory-built inventory checks unequal per-wavenumber counts. Existing tests supply component/custom-operation ownership, conjugacy, inactive/zero wave padding, full diagnostics, and native nonlinear particle/tracer continuation.

 All 24 focused tests passed: four new scheduling checks plus 20 existing cases in `TestFreeSurfaceRHSReuse`, `TestSelectiveFreeSurfaceReconstruction`, `TestFreeSurfaceVariableWaveCounts`, `TestFreeSurfaceNonlinearRestart`, `TestFreeSurfaceNonlinearEvolution`, and `TestAdvectionForms`. The preserved candidates additionally pass cold, ordinary pressure-overlap, and warm checks through `checkRHSSchedulingCandidates` on both profiles.

Production Code Analyzer: 241 files, zero blocking findings. Direct Code Analyzer checks of all new/changed MATLAB files report no findings. `docs:check` validates 2,362 files and 4,827 routes without validation errors, but still fails its generated-file comparison on the two established baseline differences: `docs/classes/developer-internals/wvdensitydiffusionintegrator/index.md` and `docs/version-history.md`. Those files remain untouched. Whitespace and scope checks pass; fixture MAT/NetCDF files and generated profiling intermediates are excluded.

```matlab
assertSuccess(runtests('UnitTests/TestFreeSurfaceRHSScheduling.m'))
checkRHSSchedulingCandidates('/tmp/484-fixtures')
```

No MATLAB source changes are needed to reproduce the retained pressure/setup candidates. No website, package manifest, released snapshot, API, or persistence schema is changed.
