# Legacy quadratic assessment removal

InternalModes [#42](https://github.com/JeffreyEarly/internal-modes/issues/42) completes the practical-dealiasing replacement in WVM. Cleanup commit `602deb92` removes 20 dedicated runtime helpers and all executable MATLAB/Python code from the old `tools/aliasing-study` survey: 60 deleted source files in total. Frozen numerical records remain labeled as historical evidence. There is no callable legacy research diagnostic or construction fallback.

The default remains `quadraticDealiasing="fixedFraction"`, `retainedFraction=2/3`. Explicit `"none"` and `"effectiveBandwidth"` remain available. Wave and APV selection share the policy; linear convergence, Gram acceptance, strict explicit counts, fixed-boundary resolution, and horizontal antialiasing remain independent requirements. The replacement boundary-only wavenumber helper preserves QG bracketing and boundary error behavior without constructing product inventories. Old free-surface options and saved metadata are rejected explicitly, with no adapter. The saved-group check examines the transform's own variables, so an unrelated child group does not cause rejection.

Reusable InternalModes projection/product operations have independent callers and are retained. No provider API, dependency floor, or released OceanKit payload changes in this cleanup. Thermal QG's separate mapped-quadrature algorithm remains. Its newly merged offline APV diagnostic caller now requests `quadraticDealiasing="none"` explicitly. The revision-guarded beta.4 Thermal benchmark and the labeled historical beta.5/beta.6 construction recipe preserve their original inputs for reproduction with those old sources; they do not implement the removed survey.

## Matched construction and scientific parity

Measurements use Apple M4 Max (128 GiB), MATLAB R2026a Update 5, and `maxNumCompThreads(1)`. Each revision runs in a fresh MATLAB process. Each policy has one warmup and three unprofiled trials; every unprofiled policy batch finishes before the separate default-policy profile. No MATLAB test process runs concurrently.

| Policy | Before median (s) | After median (s) | Before filter/report (ms) | After filter/report (ms) | Wave modes per sign, each k / APV |
|---|---:|---:|---:|---:|---:|
| `none` | 15.6702 | 15.6795 | 19.737 | 19.489 | 38 / 38 |
| `fixedFraction` | 15.4507 | 15.4611 | 20.147 | 19.992 | 25 / 25 |
| `effectiveBandwidth` | 15.6551 | 15.5897 | 219.056 | 217.410 | 26 / 26 |

The cleanup produces no material timing change, as expected when deleting a superseded path. The small differences are not claimed as speedups. The default costs about 20 ms for policy dispatch, validation, scoring, and reporting; shared preparation remains in total construction time. Every policy still uses 569 positive wavenumbers and 1,140 candidate/reference wave/inertial solves.

For all three policies, **all 74 recorded scientific-state fields match exactly** (`isequaln`). Only the two input function handles, `N2Function` and `rhoFunction`, are excluded from the serialized comparison; sampled stratification, operators, counts, parameters, and the remaining state are compared. Entire assessments also match exactly after replacing only `assessmentSeconds`, `waveConstructionSeconds`, `constructionSeconds`, and `quadraticDealiasingSeconds` with sentinels. Counters, scientific measurements, selected modes, labels, tolerances, and field inventories remain part of the comparison. This matches the calibrated new policies, not the removed heuristic.

Separate profiler passes take 23.6744 s before and 23.5549 s after. In the final profile, `IMSolver.solveAssembledEVP` has 7.3349 s self time (9.6328 s inclusive); the wave-assessment loop has 1.5903 s self time (12.6827 s inclusive). Finite generalized-eigenpair filtering is 0.8402 s self time, zero-mode assessment 0.7161 s, and `chebfun.isempty` 0.5379 s. Inclusive rows overlap and cannot be added into promised savings. Profiled and unprofiled totals are distinct measurements.

The historical 17.57-second linear result and 650.75 seconds **before rejection** motivated the replacement. The latter is a failed diagnostic, not a successful-construction baseline, and neither number is used for the paired comparison above.

## Pinned reproduction

- Before WVM: `ec0c5f23e37ab815665d96ae40605cd852428d6d`.
- After runtime: `9e44657561eeec1a03548cdec2261de8c30bb7e4`, including cleanup and the clean integration of v5 target `01ff9ac19426dfc844b82f14b35c9af6b7cf7e6e`. Subsequent verification/documentation commits do not change this Boussinesq numerical path.
- InternalModes beta.7: `f7f78b59f73c1f6c4052f3c5f0feb5aca7d6aa81`.
- OceanKit exported payload checkout: `75bce622d096dd582be49855bb6c718dd163672b`; merged distribution and CI pin: `0f2dae987eb777dd54a15f9b910ddb7f221b5852`.
- Chebfun timing checkout: `1fe01297a74d9ee765a466c3068b7fb474bee053`. Correctness/package tests use the declared Chebfun 5.7.0 export.
- Other dependency snapshots: ClassAnnotations 1.2.1, Distributions 2.0.0, SplineCore 2.2.0, NetCDF 1.0.2. Documentation uses ClassDocumentation 1.3.2.

Use `measureLegacyRemoval.m` and `compareLegacyRemoval.m` from the cleanup checkout as the driver for both revisions. Supply distinct output folders and fresh MATLAB processes, keeping dependency roots identical. `wvmRoot` selects the revision under test, while the driver's folder is restored after path setup.

```matlab
addpath(fullfile(driverRoot,"tools","quadratic-dealiasing-study"));
measureLegacyRemoval(wvmRoot,outputFolder, ...
    internalModesRoot=fullfile(oceanKitRoot,"InternalModes-2.0.0-beta.7"), ...
    dependencyRoot=oceanKitRoot,chebfunRoot=chebfunRoot);
% After both fresh-process runs:
compareLegacyRemoval(beforeFolder,afterFolder);
```

The constructor is:

```matlab
WVTransformFreeSurfaceBoussinesq.fromStratification( ...
    [1e5 1e5 1000],[128 128 65], ...
    N2Function=@(z)1e-4*exp(2*z/700),nEVP=104, ...
    shouldAntialias=true,quadraticDealiasing=policy)
```

Candidate/reference resolutions are 104/156. Raw trials, profiles, provenance, comparison results, and verification records are in `results/legacy-removal`. Large scientific-state MAT files are reproducible outputs kept outside the repository; their checksums and exact-comparison outcomes are recorded. The essential result does not depend on those local files remaining available.

## Verification and reassessment

The cleanup's focused suite passes 55/55, covering current policy construction, strict counts, independent refinement/boundary checks, persistence/resolution changes, nonlinear evolution/adaptive restart, and Thermal quadrature/APV diagnostics. The final local-group persistence change passes its three focused methods, including the nested-child regression. Additional merged Thermal tests and integration gates are recorded in the verification ledger; initial failures and targeted corrections are preserved.

GPT-6 Astra extra-high review checks simplicity, correctness, provider boundaries, and scientific parity. Its one saved-group scope finding was fixed and regressed. The provider-free Thermal test now removes every resolved InternalModes root, preventing a second authoring checkout from masking the intended absence test; its scientific assertions are unchanged.

The three-page literature note at `literature/ape-apv-free-surface/notes/quadratic-dealiasing.tex` is committed locally at `65617131539c0c6f73e5da2189daf970cb281de8`, compiled with TeX Live 2025, and visually inspected on all pages. It retains the approved larger-k figure and reproducible inputs. It is not pushed to Overleaf.

**Next target:** reassess [#35 toolbox-free parallel construction](https://github.com/JeffreyEarly/internal-modes/issues/35). Eigensolution remains the largest self-time hotspot, and independent positive-wavenumber work is the natural parallel unit. Refresh the old native-probe end-to-end projection against the current approximately 15.5-second workload before deciding production scope. No parallel speedup is established by this cleanup; full eigenvectors, numerical parity, bounded workspaces, thread safety, nested-thread control, and a serial fallback remain requirements. The earlier Gram-prefix optimization stays deferred because its measured gain did not justify the complexity.
