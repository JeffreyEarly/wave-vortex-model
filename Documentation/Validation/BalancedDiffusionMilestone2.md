# Balanced diffusion 2: integration and verification

This handoff covers T4–T8, issues [#435](https://github.com/JeffreyEarly/wave-vortex-model/issues/435)–[#439](https://github.com/JeffreyEarly/wave-vortex-model/issues/439), delivered through [PR #525](https://github.com/JeffreyEarly/wave-vortex-model/pull/525) targeting `feature/v5.0-free-surface-qg`. The released `main` line is separate. Work began at T3 commit `aed3c284075b62a5a4412bef13913beefb37c33d`; the qualified T4 checkpoint and architecture audit are commit `875ac2ecc698141b26b00a1f96b532474c25b8ec`. The T5–T8 runtime integration is commit `557e13ffe3d02b38373bb74c55b37539197507a1`; subsequent commits retain its qualification evidence and final integration corrections.

## Resolved architecture

The thermal transform remains a peer of the APV QG transform. Both use existing geometry, coefficient-family discovery, forcings, `WVModel`, the exponential controller, annotated storage and committed output graphs. There is no new transform superclass, observer hierarchy, timestep controller or file format.

- **Physical forcing:** one quadratic stress law calls each peer's endpoint streamfunction and physical stress projection. Thermal nonlinear advection evaluates its qualified product grid once at its registered position. Optional process diagnostics record actual callback increments. A supplied nonlinear stage speed is authoritative; closure-only linear evolution uses one native speed consistently for the closure and its stability bound.
- **Evolution:** one internal adapter selected at setup supplies rates, packing, physical norms, source projection, explicit RHS and validation. APV diffusion remains owned by `WVVerticalDiffusivity`; thermal diffusion remains owned by the immutable transform. APV keeps four norms and departure scaling; thermal keeps five norms and total-state scaling. Exact seasonal sources, null rates and observation scheduling are retained. Failed trials restore the last accepted canonical physical state directly.
- **Physical inventories:** thermal energy accessors now follow the other resolved transforms' horizontally averaged, depth-integrated convention, in m3/s2. Factors of the full physical metric retain thermal cross terms and independent mean contributions. Diagnostics use physical wavenumbers and explicit reconstructed quantities; a thermal direction index is not an APV scale. Native reconstruction, nonlinear product quadrature and physical metric quadrature remain distinct where their purposes differ.
- **Damping:** `WVThermalAPVDamping` freezes an explicitly constructed APV diagnostic band, sampling grid, signed endpoint weights and filter configuration. Vertical action is `L*D*P`, where `P*L=I` and `L` minimizes positive physical energy. The complete complement `I-L*P` is unchanged vertically; the common horizontal filter acts on all thermal directions. Mean coefficients are unchanged. Fixed numerical maps and a physical operator-norm bound are cached. Every actual trial stage contributes to the controller's stability check.
- **Persistence and transfer:** restoration uses authoritative stored arrays without scientific construction. Integrator and closure caches rebuild from those arrays. The thermal reader delegates committed state and output selection to the shared lifecycle. Resolution transfer fits physical QGPV and exact endpoint constraints, independently preserves mean endpoint/integrated-buoyancy constraints, and reports physical loss. The frozen closure and seasonal pattern convert through existing forcing ownership rules.

## Decisions for subsequent experiments

The damping is an **explicit APV-coordinate comparison closure**, not a claim of equivalent full APV trajectories or physical-energy dissipation. Vertical damping can inject physical energy through the physical metric's cross terms. The independent audit and an ordinary mixed exponential control demonstrate this. Horizontal damping dissipates physical energy. Both contributions are recorded separately, and the timestep bound covers the actual potentially nonnormal action. A campaign must record this closure choice, APV band, sample grid and endpoint weights. A richer offline diagnostic band must not silently change the online closure.

Choose retained thermal resolution, diagnostic APV band and campaign acceptance thresholds using the T6 measurements and the later T10 comparisons. The historical linear result remains: 257 and 385 complete directions pass all 30 declared seasonal linear checks; 129 does not. Small manufactured tests and a short restart at the actual target geometry do not qualify a long nonlinear seasonal campaign. Coarsening reports loss without declaring it scientifically acceptable. Full campaign performance and parameter tuning remain downstream.

The time-refined 11.57-day seasonal comparison starts from the exact same-space response at 2.5 years and retains 257 thermal directions. On its 18 by 18 grid, annual meridional mode 5 lies in the horizontal filter transition. The candidate changes surface displacement by 1.7400 m RMS (27.93%) for M=10 and 49.6288 m RMS (79.65%) for M=100. Bottom RMS differences are 0.13590 mm and 5.33494 mm; the latter exceeds the small undamped bottom signal. These are measured closure differences, not integration errors: final successive time-control differences are at most `1.35e-9` and `6.20e-11` relative. On the intended 64-grid campaign, mode 5 is below the horizontal cutoff, so these results must not be extrapolated as its bias. The matched short developed-flow control instead measures at most 0.2845% field difference at 100x speed. T10 must compare the actual selected campaign grid/filter and decide whether this closure is scientifically appropriate.

Thermal `withDiffusivity` copies the state and basis with a new scalar diffusivity, including zero; it does not copy the forcing inventory. Convert registered forcings explicitly when constructing a configured new run and reattach the integrator. Changing diffusivity is not part of resolution transfer. New target construction may invoke InternalModes; transfer between existing targets and snapshot/model restoration may not.

The 257-direction restart control uses the target 500 km square, 4 km depth, exponential profile and annual mode-5 forcing, with both active endpoints, drag and the optional mapped closure. A fresh process with InternalModes absent reproduces the two-hour continuation to relative coefficient error `1.0811e-20` and field error `7.8242e-16`. All six process contributions are nonzero. This tests restart at the target vertical space and geometry; the 18 by 18 horizontal grid and two-hour duration do not qualify a 64-grid annual campaign. Physical refinement transfers agree to `1.22e-13` in the bounded controls, while deliberate coarsening loses 15.7–17.7% of the field norm and reports that loss.

## Evidence

| Increment | Evidence and scope |
| --- | --- |
| T4: nonlinear evolution | [Issue435](Issue435/README.md): independent product/reference quadrature, conservation and time refinement; preserved historical seasonal linear evidence |
| T5: forcing and drag | [Issue436](Issue436/README.md): independent physical stress work, strict source clock/units, ordered callbacks, process omissions and eight refined trajectories |
| T6: adapter and damping | [Issue437](Issue437/README.md): frozen coordinate law/complement, full APV differences, stage stability, physical work, seasonal bias and short developed-flow sensitivity |
| T7: diagnostics | [Issue438](Issue438/README.md): independent inventories and directional rates, physical spectra/tails, dense-startup process-budget reconciliation, signed vertical closure work |
| T8: restart and transfer | [Issue439](Issue439/README.md): committed-stream recovery, provider-unavailable continuation, actual-target short restart, independent schedules and measured transfer loss |

## Dependency and reproduction ledger

MATLAB R2026a Update 4, Apple Silicon, double precision, two computational threads per qualification process. Local OceanKit checkout: `592c4039242d47c98a7c979fb392f9b58e3a2868`; hosted CI uses its existing pinned checkout `65d9aa2c3de941406dc6bf2cf1937ba5b3dcd1d5`. Both load the named immutable snapshots. InternalModes `v2.0.0-beta.4` resolves to commit `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51` (annotated tag object `631154ea071368cb5089e8ea48b8283276a8d10d`). Other runtime snapshots: ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0, Distributions 2.0.0, chebfun 5.7.0. Documentation uses ClassDocumentation 1.3.2. No package version, dependency declaration, released snapshot, historical experiment pin or experiment trajectory changed.

Run `matlab -batch` outside the local macOS sandbox, as required by the workspace's Apple Silicon MATLAB policy. From the WVM authoring repository, the qualification setup is:

```matlab
restoredefaultpath;
repository = pwd;
workspace = fileparts(repository);
addpath('tools');
configureCIEnvironment(repository,fullfile(workspace,'OceanKit'));
p = string(strsplit(path,pathsep));
stale = startsWith(p,string(workspace)+"/") & ...
    ~startsWith(p,string(workspace)+"/OceanKit/") & ...
    ~startsWith(p,string(repository));
if any(stale), rmpath(char(join(p(stale),pathsep))); end
assert(contains(string(which('IMInternalModes')),'OceanKit/InternalModes-2.0.0-beta.4'));
assert(numel(which('IMInternalModes','-all'))==1);
maxNumCompThreads(2);
addpath('UnitTests');
```

The per-issue evidence supplies the scientific reproduction commands and tolerances. Unit-test classes install their own fixture paths; do not add `UnitTests/Fixtures` globally when checking test isolation. The 70-test shared selection was `runtests` on `TestDensityDiffusionIntegrator`, `TestThermalIntegration`, `TestFreeSurfaceOutputRestart`, `TestWVModelOutputPersistence`, `TestBoussinesqAdaptiveDamping` and `TestFreeSurfaceAdaptiveIntegration` under `UnitTests`. Each result was checked with `assertSuccess`. Final integration commands and outcomes are recorded below as their gates complete.

| Integration gate | Result |
| --- | --- |
| Existing APV and thermal exponential suites before closure integration | 21/21 pass |
| `buildtool test:smoke` | 139/139 pass; 35.4 s test execution |
| New damping coordinate/complement, metric bound, process and trial-rejection controls | 8/8 pass after independent audit and smallest-grid filter fix |
| Shared restart, integrator, Boussinesq damping and adaptive-tolerance regressions | 70/70 pass |
| Forcing and core API documentation regressions | 34/34 pass |
| Documentation tools/core API and cross-release normalization | 40/40 pass on R2025b; R2025b and R2026a generated checks both have zero differences after common-indent normalization |
| Canonical documentation build/check | Pass: 2653 files, 5413 routes, zero differences; closure catalog and public factory/configuration taxonomy included |
| Production Code Analyzer | Pass on 341 runtime files, including 75 internal namespace files; zero blocking findings |
| Analyzer policy and portable request writer regressions | 19/19 pass |
| Character-name forcing registry and portable contracts | 13/13 pass |
| Exact R2025b seasonal conversion regression and analyzer | 2/2 pass; 341 production files, zero blocking findings after local/property name disambiguation |
| Thermal package consumer on runtime-only path | Pass in 4.31 s: six process budgets, exact snapshot/closure configuration, `4.27e-16` physical transfer error, and restored continuation |
| Package/scope/whitespace checks | Manifest unchanged; runtime files use existing installed roots; no snapshot, historical experiment or generated binary changes; the only hand-authored website correction joins an existing example call onto one line to satisfy its existing style regression; local evidence links and whitespace pass. Install/export consumer results are recorded on PR #525. |
| Hosted MATLAB R2025b and C++ gates | Recorded against the tested head on [PR #525](https://github.com/JeffreyEarly/wave-vortex-model/pull/525/checks); required before merge, with full, exhaustive, optional, clean-install and exported-package jobs enabled by `final-integration` |

A bounded seasonal control exposed a pre-existing degenerate horizontal filter: when cutoff equals the maximum, the lowest supported grid produced 0/0 at that radius. The shared worker now gives zero at/below cutoff, including equality, and retains the old ordinary-grid formula. An end-to-end four-point-grid APV/thermal regression passes.

A seasonal-only source plus mapped closure also exposed concatenation of character-valued forcing names. The shared registry now converts each name individually before forming its ordered string column; 13 legacy forcing/portable tests, including the new character-name regression, pass.

The first hosted smoke invocation stopped during test classification: pre-existing `TestFreeSurfaceAdaptiveIntegration` had no primary tag. It now declares `full`; the repository discovery policy remains unchanged, and the corrected smoke gate passes. This is a test-discovery correction, not a skipped numerical check. The analyzer inventory now includes internal namespace files. Six existing thermal compatibility overrides intentionally throw before returning; their existing unset-output findings are accepted only after checking the exact method and unconditional documented error body. Conditional or unrelated unset outputs and suppressed unreachable statements remain blocking. A genuinely unused assignment after closing a portable-request temporary file was removed; all nine transaction-writer regressions pass. Earlier local corrections and measured failed targets remain recorded with the relevant issue evidence.

The next hosted focused run passed all 139 smoke tests and then found an R2025b property/local-name ambiguity in seasonal forcing conversion. Renaming the local to `targetPattern` preserves behavior. The exact R2025b release subsequently passes both affected seasonal tests and the complete 341-file production analyzer locally. The final install/export verifier also exercises thermal construction, all six processes, physical diagnostics, authoritative snapshot restoration, frozen closure identity, physical transfer and continued integration using only public installed APIs; no authoring fixtures or scientific data files are available to that consumer.

The first full hosted integration run passed smoke, analyzer, clean installation, optional and exhaustive gates. Export preparation and documentation exposed one whitespace-only class-overview difference between R2025b and R2026a: the former indents reflected class help, and removing metadata before normalizing indentation left stray spaces. The generator now normalizes common indentation first, using its existing helper. The integrator overview also names both APV and thermal coefficient families. This correction preserves the documentation and export checks rather than treating whitespace drift as a passing result. Final cross-release documentation results and hosted outcomes are recorded on PR #525.


## Full-suite integration corrections

The hosted run at `39a3775165f451020f3500f0bcbd3a42c0ff243e` passed required CI, clean installation, exported-package verification, all 2440 exhaustive tests and all seven optional tests. The full job reached its 45-minute limit and reported real failures before cancellation. That run is retained as failed verification, not counted as success. Its seasonal spatial-convergence study alone took approximately 14 minutes 43 seconds. The full job now has a 75-minute budget; its selection and scientific acceptance criteria are unchanged.

- Quadratic drag again reuses a supplied `phiHat` stage snapshot. When none is supplied it uses the selective endpoint hook. The existing regression changes the live state after taking a snapshot, checks the supplied-state answer and ensures combined tendency evaluation performs only one volume reconstruction.
- APV cache regressions now follow the common adapter: batching is prepared once at setup, while physical QR factors are absent at setup, constructed on first use, reused after coefficient/time changes and rebuilt for replacement diffusion operators. Independent per-page transform and physical quadrature comparisons remain intact.
- Thermal diagnostics and shared-contract classes explicitly install their fixture paths. Eleven tests pass with the fixture directory absent before discovery; globally adding that directory had masked this test-isolation defect.
- The portable forcing schema recognizes the optional inactive `apvCutoffFraction` default. An absent legacy field or a scalar-double NaN has no active portable configuration; both writers emit the canonical NaN default. Finite values, infinities, wrong type/rank, unknown fields and programmatically injected active values remain rejected. All 15 MATLAB portable compatibility methods and focused C++ reader/writer/catalog/forcing/model-output checks pass. No filter mathematics or fixture payloads changed.
- The pre-existing thermodynamic authoring study now projects only the scalar displacement correction and its derivative, preserving unchanged coefficients and avoiding cancellation of phase terms. All nine unchanged tangent/comparison tests pass on R2025b. This helper is outside the runtime; scientific reports, published outputs and experiment pins are preserved.
- A manuscript regression differences independently sampled moving-volume integrands before integration, avoiding subtraction of two background inventories near `3.34e8` to estimate a rate near `0.120`. Its `2e-5` tolerance is unchanged. Four decreasing difference intervals verify convergence of the numerically stable expression; no analytic rate is used to form the difference.
- The obsolete construction-budget assertion was removed because user commit `34a413944057d159ea16b3f29b4a966045a7449f` had deliberately removed that early resource cap before this milestone. The assertion supplied no scientific basis and expected the removed cap to abort first. Current physical convergence and quadratic-error requirements are unchanged.
- One pre-existing user-guide example call is put on one line to satisfy the existing documentation-style regression. No example behavior or website structure changes.

The 12 corrected shared-interface/construction tests pass with zero Code Analyzer findings on the three root-owned MATLAB files. The 243 full-tagged tests after the hosted timeout point also pass (242 in the first local selection, followed by the sole documentation-method rerun); none is incomplete. The three corrected diagnostics test files and thermodynamic study helper have zero Code Analyzer findings. The final R2025b documentation build/check passes with 2653 files, 5413 routes and zero differences. Evidence links and whitespace checks pass. These corrections received a separate agent review. Minimum-release local verification uses MATLAB R2025b with two threads and the same unique InternalModes beta.4 snapshot. The final hosted run must pass the complete enabled suite before merge; its exact tested commit and results are recorded on PR #525 and in the issue completion records.


A subsequent test-isolation audit found that the QR cache regression selected built-in profiler detail without restoring the previous detail setting. Its test teardown now restores that setting after the profiler is stopped. The affected method passes on R2025b, Code Analyzer has zero findings, and a before/after check confirms `mmex` is restored. No runtime, physics or tolerance changed. The full hosted rerun at `1147d5cc0037ad4f7f5fd285c74a501b018041c9` was superseded for this two-line cleanup; its required CI, package, exhaustive and optional gates had passed. The replacement full run remains required before merge.
