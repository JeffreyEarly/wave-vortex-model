# T9 verification ledger

Implementation baseline: v5 `e513f3f81971539a0a74ecf1f856e9bca7d7e132` (PR #525). Runtime, dependencies, focused tests and generated API documentation are committed as `787b90ae` on `implementation/thermal-apv-diagnostics-t9`, targeting `feature/v5.0-free-surface-qg`. This ledger covers local qualification; final hosted check results and the merge revision are recorded on [#440](https://github.com/JeffreyEarly/wave-vortex-model/issues/440) and its implementation pull request.

## Environment

Numerical, installed-package and documentation verification used MATLAB R2025b Update 5 (`25.2.0.3177638`, `MACA64`), with two computation threads. Every local MATLAB batch ran outside the macOS sandbox as required by the workspace policy. Scientific and output evidence record the observed host conditions separately.

Clean setup, starting in the WVM authoring repository:

```matlab
restoredefaultpath;
sourceRoot = string(pwd);
workspaceRoot = string(fileparts(sourceRoot));
addpath(fullfile(sourceRoot,"tools"));
configureCIEnvironment(sourceRoot,fullfile(workspaceRoot,"OceanKit"),documentationPackageSpecifier="ClassDocumentation@1.3.2");
entries = string(strsplit(path,pathsep));
sibling = startsWith(entries,workspaceRoot+"/") & ~startsWith(entries,workspaceRoot+"/OceanKit/") & ~(entries==sourceRoot | startsWith(entries,sourceRoot+"/"));
if any(sibling), rmpath(char(join(entries(sibling),pathsep))); end
assert(contains(which("IMInternalModes"),"OceanKit/InternalModes-2.0.0-beta.5"));
assert(numel(which("IMInternalModes","-all"))==1);
maxNumCompThreads(2);
```

The [dependency report](DependencyQualification.md) records all versions, exact release/export revisions, native compatible-version range tests and manifest provenance. The active WVM manifest version is unchanged at 4.3.0; the v5 feature branch remains unreleased. Existing package-path ordering and Java X11 warnings did not block checks.

## Local checks

| Gate | Result and scope |
| --- | --- |
| Dependency and APV compatibility | 16/16 passed: 9 release-verification tests, 5 existing free-surface QG mode/projection controls, shared automatic-family selection, provider-free thermal restoration |
| New output analysis | 6/6 passed: scalar and nested committed streams, bounds, fingerprints, staged tails, corruption/ambiguity and cleanup |
| Shared reader/restart | 38/38 passed across `TestNetCDFHandleOwnership`, `TestFreeSurfaceOutputRestart`, `TestThermalOutputRestart` |
| New scientific interfaces | 9/9 passed across independent projection/synthesis, self/cross inventories, Fourier reality, means, directional rates, native APV comparison, cache/closure separation and mutation validation. The updated directional method also passed independent absolute/reference rate-norm checks, including energy and both endpoints |
| Shared thermal physical metrics | 5/5 `TestThermalDiagnostics` methods passed after final core changes |
| Independent scientific qualification | All 14 small controls, 8 source fits, 12 refinements and 27 observable-budget rows passed. See [scientific results](README.md) for source-fit errors, target residual/reference budgets, measured costs and exact limits on target timing coverage |
| Fresh provider-free process | Saved source and diagnostic transforms restored and all three committed records diagnosed exactly; staged tail ignored and source/basis hashes preserved. Only transient construction-assessment availability differs. See [procedure](OutputQualification.md) |
| Native installed package | `verifyWaveVortexModelPackage(sourceRoot,oceanKitRoot)` passed in an isolated R2025b MPM environment. The six dependencies resolved to snapshots, installed T9 workers resolved inside the package, and public diagnosis preserved state, matched restored coefficients, physical energy, endpoints and six ordered process rates |
| Production Code Analyzer | 345 production files, 0 blocking findings; 290 existing active informational/style findings and 29 documented suppressions reported. Final individual analysis of all 17 changed runtime/test/setup/taxonomy MATLAB files produced 0 messages; the qualification utility's final analysis is in the scientific report |
| API documentation | Final build and clean check passed (2654 generated files, 5415 routes, 0 failures, 0 generated differences), including public taxonomy and complete field enumeration. Generated-page inspection confirms the method appears beside existing energy-budget APIs |
| Source scope and whitespace | `git diff --check`, local documentation-link/fence checks, manifest diff, snapshot cleanliness, generated-file review and explicit staging inventory checked at handoff |

Run focused tests using the clean setup above, without globally adding fixtures:

```matlab
results = runtests(["UnitTests/TestThermalAPVDiagnostics.m", "UnitTests/TestThermalAPVOutput.m", "UnitTests/TestThermalDiagnostics.m"]);
assertSuccess(results);
```

The new test classes install their own fixture paths. Shared regressions and exact dependency selections have reproduction commands in the companion reports. The public installed consumer runs in a separate MATLAB process with an isolated `MATLAB_PREFDIR`; it calls `verifyWaveVortexModelPackage` directly after adding only authoring `tools`. The implementation example and consumer need no literature files or test fixtures.

The coherent documentation commands are `buildtool("docs:build")` then `buildtool("docs:check")`; the production gate is `buildtool("analyze")`. A second documentation cycle was justified by inspection of the generated page: existing taxonomy had classified the new public method as internal. The correction routes it beside `quadraticDiagnostics`. No numerical test was repeated merely for that documentation correction.

## Final integration policy and scope

The implementation PR enables `final-integration`, which requests full, exhaustive, optional, clean native installation and unpublished exported-package checks in addition to routine smoke, documentation, Code Analyzer and portable C++ checks. Successful local gates are not a substitute for those final hosted gates. Required checks must pass before merge; branch protection is not bypassed. No package release or published export is part of this task.

Generated API pages include the new public method, class navigation ordering, corrected endpoint-response units and changelog. Other generated changes are deterministic navigation-order shifts. No hand-authored website pages, experiment-repository files, historical evidence, pinned trajectories or released package snapshots changed. The unrelated untracked `tools/free-surface-initialization-study/` remains outside the commit.

All historical linear results, including the 129-direction failure and 257/385-direction qualification, remain intact. T9 uses deterministic self-contained inputs, so missing historical MAT/NetCDF assets do not block its tests. The full seasonal study, nonlinear campaign qualification, damping selection and whole-model performance remain [T10/#441](https://github.com/JeffreyEarly/wave-vortex-model/issues/441), with the concrete handoff in [ImplementationHandoff.md](ImplementationHandoff.md).

## Bounded mode-capacity follow-up, 14 September 2026

The [mode-capacity report](ModeCapacity/README.md) adds an authoring-only qualification driver and measured evidence on top of merged v5 `9d55ad2b6c0d16db529a39990aad4b89f9e835a8`. It establishes practical bands and a reusable selection method before T10. It does not change runtime, dependencies, exported behavior or original T9 numerical gates; the earlier final-integration policy above describes the completed production implementation.

| Check | Result |
| --- | --- |
| Bounded qualification | Two batches of `qualifyThermalAPVModeCapacity`: six constructor cases, four accepted diagnostic bands, two preserved physical-shape failures at the automatic limits, 36 accepted-case residual rows |
| CSV and report audit | Expected cases/statuses and source-normalized comparison allowances verified; report links resolve |
| Shared diagnostic regressions | `runtests('UnitTests/TestThermalAPVDiagnostics.m')`: 9 passed, 0 failed, 0 incomplete on R2026a Update 4 |
| Added MATLAB Code Analyzer | `checkcode('tools/qualifyThermalAPVModeCapacity.m','-id')`: zero messages |
| Independent scientific audit | No blocking findings; retained explicit limits on automatic counts, one-state coverage, unqualified nonlinear products, coefficient magnitudes, source-scale convergence and caller-owned dependency setup |
| Documentation consistency | One `buildtool("docs:check")` with ClassDocumentation 1.3.2: 2654 files, 5415 routes, zero failures and zero generated differences |
| Scope | One authoring utility plus validation reports/CSV evidence; no runtime, website, manifest, snapshot or historical experiment changes |

The study uses uniquely resolved InternalModes beta.5 through `configureCIEnvironment`, the same immutable dependency revisions as the T9 dependency qualification, and two computation threads. The initial package-path warnings are followed by sibling-checkout removal and unique-provider assertions. No local asset was missing. Whole-campaign and broad production suites were not repeated for this authoring-only follow-up. The nine regressions and documentation gate ran once after the coherent code/report batch; later verification-ledger updates do not affect generated documentation.
