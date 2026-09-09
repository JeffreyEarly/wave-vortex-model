# Per-kappa retained wave modes

The experimental free-surface Boussinesq transform accepts an explicit retained wave prefix for each distinct positive horizontal wavenumber magnitude. The scalar `waveModeCount` remains the uniform-count convenience. The state remains entirely adiabatic, with the original computed mode labels, equivalent depths, polarization and frequencies. Inertial, APV, zero-APV and mean-density-anomaly counts remain independent.

## Count map and storage

Use `waveModeKappa` and `waveModeCount` to supply physical wavenumber keys (rad/m) and nonnegative integer counts. Counts include the external mode. Keys may be reordered or consistently repeated, but must cover every supported positive page and may not include unsupported pages or conflicting counts. Matching permits only the existing 64-ulp roundoff allowance used by the horizontal page grouping. No interpolation between nearby wavenumbers is used.

`waveModeCountByKh` stores the map in `khUnique` order. `waveMode` spans the largest requested count; `Aw_p` and `Aw_m` keep their existing rectangular mode-by-Fourier-column shape. `activeWaveModes` identifies the physically present entries. Inactive entries are exactly zero, cannot be assigned a nonzero coefficient, and never enter divisions, polarization or source pairing. Zero-count pages omit their wave solve. Entirely absent wave families are supported while inertial and balanced families remain present.

This representation preserves the existing array and integrator contracts. It does not claim the storage savings of packed arrays: allocation follows the largest count, while scientific construction and reconstruction work follow the active prefixes. Benchmark evidence below records that tradeoff rather than requiring a predetermined speedup.

## Explicit accuracy assessment

The optional second output of `fromStratification` reports linear resolution evidence for the actual bases used to construct the transform:

```matlab
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification( ...
    [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z, ...
    waveModeCount=4,nEVP=64,referenceNEVP=96,modeConvergenceTolerance=1e-6);
disp(assessment.pages)
```

An explicit `referenceNEVP` requests the additional reference solve. Without it, a requested report includes the stored-grid assessment but marks mode-convergence evidence as not requested; ordinary single-output construction does no extra assessment solve. Assessment never changes the requested counts or replaces the model's modes with reference modes.

For each positive kappa, the report separates equivalent-depth and positive joint field/derivative convergence from fixed-grid Gram error. Its usable count is the contiguous prefix passing both linear criteria. Passing all supplied modes reaches the candidate ceiling, not a demonstrated maximum possible count. Missing or ambiguous reference evidence is inconclusive. Zero-count pages are explicitly not requested. Inertial evidence is reported separately. Two-resolution agreement is evidence of convergence, not a rigorous absolute error bound.

The InternalModes `ExamplesV2/waveModeCountsByWavenumber.m` example plots this distinction across a declared horizontal Fourier inventory and a WKB-Chebyshev physical vertical grid. Its grid tolerance is an explicit example choice, not a change to WVM's default projection tolerance.

Quadratic evidence remains with the existing authoring advisory. Its output-page breakdown describes the tested sparse inventory under a common wave prefix on all participating wave pages; it does not certify arbitrary independent count maps or all quadratic interactions. Keep that scope distinct from the construction report's per-page linear evidence. A restored model contains its saved modes and count map; loading it does not silently re-solve modes to manufacture a convergence report.

## Restart and resolution transfer

Files store `waveModeCountByKh` and the existing resolved operator arrays. Inactive slots remain zero; an entirely absent wave family omits its zero-length dimensions and variables. Older uniform-count files without a count map restore full prefixes on every page. Restart uses saved operators and requires no InternalModes solve.

Resolution transfer matches only physical labels present on both source and target pages, including phase and normalization checks. Discarded modes and Fourier columns contribute to the existing positive physical discarded-content assessment. New target modes start at zero. A nonuniform count map is preserved automatically on shared target kappa values. If horizontal refinement introduces a new kappa, the caller must specify its target count explicitly. Uniform maps retain the existing scalar expansion behavior.

## Verification

Focused tests cover reordered/repeated maps, zero pages and absent wave families, unchanged scalar behavior, exact retained prefixes, active-mode reconstruction/projection, energy, physical source forcing, fixed-step integration, saved state/output/restart, legacy uniform files and transfer with discarded-content accounting. Provider checks cover variable-count bulk construction and shared convergence measurements against actual constant/variable-stratification modes. The final source integration passes all 111 affected cases, including the existing QG/Boussinesq scientific controls, output/restart/transfer and 15 new unequal-count/assessment/persistence cases. The [machine-readable ledger](issue-414-source-tests.csv) lists every case. All 18 existing source/product/advisory cases also pass with unchanged historical data and the original `AbsTol=1e-7` reference comparison.

Separate processes continue both an unequal-count checkpoint and a completely absent-wave checkpoint with InternalModes removed from the MATLAB path. A real uniform-count checkpoint produced by pre-change WVM `fc4a39ea` also restores correctly.

The full exported provider candidate passes 374/374 V2 tests. WVM documentation build/check passes with 2,358 files, 4,819 routes and zero drift. Changed-file Analyzer has only one inherited `FNDSB` suggestion on the unchanged advisory mean-page lookup; the benchmark’s `whos` measurement is explicitly annotated.

The [bounded cost comparison](Issue414PerKappaCountCosts.md) and [raw measurements](issue-414-count-costs.csv) show identical rectangular storage for the same maximum count. At 32², median construction/reconstruction times changed from 0.611 s / 12.35 ms to 0.521 s / 8.59 ms; the 16² varying-count case was slightly slower. These small measurements justify retaining the simpler arrays, without a general speedup claim.

InternalModes provider [PR #29](https://github.com/JeffreyEarly/internal-modes/pull/29) is merged and released as [2.0.0-beta.4](https://github.com/JeffreyEarly/internal-modes/releases/tag/v2.0.0-beta.4), commit `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`. Its published OceanKit snapshot is pinned at `65d9aa2c3de941406dc6bf2cf1937ba5b3dcd1d5`; WVM declares the exact beta.4 dependency. A clean installation of that released provider passes all 374 V2 tests. The separate pre-release WVM candidate installation passed 42 focused checks. Final clean-installed WVM qualification against the published beta.4 graph passes **138/138 tests**, with zero failures and incomplete cases: 111 affected QG/Boussinesq cases, nine package/release checks and all 18 source/product/advisory cases. The [installed-test ledger](issue-414-installed-tests.csv) records every result. Both WVM and provider runtime symbols resolve from isolated installed packages, with no authoring repository on the runtime path. Tests and the authoring advisory are loaded explicitly from the review checkout.

The committed generator `6ea0a8dbd9ca684c4379cc0650106bccdc08fc86` records a separate [beta.4 advisory reference](../../tools/aliasing-study/results/provider-regressions/internal-modes-2.0.0-beta.4/cal-constant-17/provenance.json). All eight quadratic-error values are identical to beta.3; the original `AbsTol=1e-7`, accepted count and rejection checks remain unchanged. The final dependency/changelog documentation batch passes the same 2,358-file / 4,819-route build and drift check. The manifest change is limited to the InternalModes dependency; WVM remains a v5 development candidate with its existing 4.3.0 package manifest, not a stable v5 release.

This work does not qualify nonlinear Boussinesq dynamics, introduce thermal modes, enable automatic mode adaptation, or publish stable WVM v5.
