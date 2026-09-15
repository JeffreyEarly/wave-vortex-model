# Cleanup verification ledger

Numerical runtime is pinned to WVM `9e44657561eeec1a03548cdec2261de8c30bb7e4`; the final provider-isolation UnitTest fix and study README are `cb7543ee`. Tests use MATLAB R2026a Update 5 and the released beta.7 package graph. See `../provenance.json` and `../../../legacy-removal.md` for the matched benchmark and ownership boundaries.

| Gate | Outcome | Record |
|---|---|---|
| Focused cleanup batch | 55/55 pass, 142.8099 s | `wvm-focused-tests.json` |
| Final persistence and merged Thermal tests | 7/8 initially; all three persistence methods pass | `wvm-post-merge-rerun.json` |
| Corrected provider-free Thermal restart test | 1/1 pass, 27.3144 s | `wvm-provider-free-rerun.json` |
| Consolidated latest focused results | 67/67 pass; not a fresh full-suite run | `focused-ledger.json` |
| Per-wavenumber report assertions | Six latest methods pass; final three-method correction rerun 8.4368 s | `per-kappa-wave-assessment-rerun.json`, `per-kappa-wave-assessment-correction-rerun.json` |
| Initial hosted final integration | 1,208/1,212 full tests pass; four stale report assertions corrected; all other jobs pass | `initial-hosted-integration.json` |
| Matched new-policy state/assessment comparison | All three policies exactly equal, excluding documented handles/timers | `../after/comparison.json` |
| Release metadata | 9/9 pass | `release-verification.json` |
| Native MPM installation | Declared seven-package graph verified; five installed-policy tests pass | `installed-package.txt`, `installed-policy-tests.json` |
| Documentation build and check | 2,649 files, 5,405 routes, zero validation failures and zero drift | `authoring-gates.txt` |
| Production Code Analyzer | 330 files, zero blocking findings; 310 classified nonblocking findings | `production-analyzer-summary.json`, `production-analyzer.csv` |
| Changed authoring files Code Analyzer | One existing array-growth advisory in the historical benchmark | `authoring-analyzer.json` |
| GPT-6 Astra extra-high review | Approved source, tests, provider boundary, numerical evidence, and report | Review summary below |
| Technical note | Three pages compile and pass visual inspection; approved larger-k figure retained | Local literature commit `65617131539c0c6f73e5da2189daf970cb281de8` |

The one post-merge failure was test isolation: removing the first InternalModes root exposed a second sibling checkout, so the provider-free assertion correctly failed before reading the saved basis. The test now removes each resolved provider root and restores the original path afterward. Its scientific assertions are unchanged. The targeted rerun is the latest result for that method; the initial failure is retained in the archive.

Astra review found and cleared one production defect before the final three persistence tests: NetCDF's recursive variable lookup could mistake an unrelated child group's legacy-named variable for transform metadata. Exact local-group path matching fixes this, while retired metadata in the transform's own group still fails explicitly. The nested-child fixture verifies exact coefficient restoration, policy, and counts. No production scientific tolerance was relaxed.

Correctness gates load the pinned snapshots through `configureCIEnvironment(wvmRoot,oceanKitRoot,documentationPackageSpecifier="ClassDocumentation@1.3.2")`. Run the named UnitTest classes/methods with `matlab.unittest.TestSuite`, then `assertSuccess`. Authoring gates use `buildtool docs:build`, `TestReleaseVerification`, `buildtool docs:check`, and `analyzeProductionCode(wvmRoot)`. The changed authoring-file scan uses `checkcode(...,'-id')` for extant MATLAB tools, tests, and experiments changed since the before revision, including newly merged Thermal work.

Installation verification uses `verifyWaveVortexModelPackage(wvmRoot,oceanKitRoot)` in a fresh process with isolated `MATLAB_PREFDIR` and a writable temporary add-on directory configured through MATLAB settings. Installed WVM and provider paths are asserted before running `TestFreeSurfaceNonlinearAdvectionGuard`; production code resolves from the installed package, not the source checkout. No user preferences or versioned package snapshots are modified.

The source and generated documentation pass whitespace/scope checks, with no manifest changes in this cleanup. The PR's `final-integration` label requests hosted R2025b smoke, full, exhaustive, optional, documentation/rendered-site, Code Analyzer, portable runtime/sanitizers, clean-install and exported-package checks. Hosted outcomes and the final merge are recorded on [WVM PR #528](https://github.com/JeffreyEarly/wave-vortex-model/pull/528), so local R2026a results are not presented as a substitute for that compatibility-floor integration gate.

The first hosted R2025b full integration at `3638594f` passed 1,208/1,212 tests. Its four failures were stale `TestPerKappaWaveAssessment` assumptions: candidate discovery now evaluates the full `Nz-1` inventory, while selected prefixes and their convergence errors are reported separately. The corrected tests check both inventories, exact selected label mappings, unchanged 1e-6 selected-prefix acceptance, and unchanged 1e-16 rejection. Exact state repeatability now pins the same reference resolution in both calls; an automatic reference may choose a different candidate resolution. No runtime or numerical tolerance changes were made. The initial local correction used a nonexistent `Nxyz` property in three methods; those were corrected to `Nz` and passed the targeted rerun. The other three methods had already passed unchanged. Astra extra-high review approved the correction. The hosted full suite is rerun before merge.
