# Practical quadratic dealiasing study

This study supports InternalModes issues [#39](https://github.com/JeffreyEarly/internal-modes/issues/39), [#40](https://github.com/JeffreyEarly/internal-modes/issues/40), and [#41](https://github.com/JeffreyEarly/internal-modes/issues/41). The reusable score is released in [InternalModes v2.0.0-beta.7](https://github.com/JeffreyEarly/internal-modes/releases/tag/v2.0.0-beta.7). WVM owns prefix selection, explicit-count policy, construction metadata, and nonlinear registration. InternalModes has no dependency on WVM.

## Reproduction

Use MATLAB R2026a Update 5 with one computational thread. The measurements use an Apple M4 Max. Paths are explicit so no previously installed authoring package can silently replace the intended provider. The root arguments below are placeholders for local checkouts, not additional MATLAB dependencies.

```matlab
addpath(fullfile(wvmRoot,"tools","quadratic-dealiasing-study"));
common = namedargs2cell(struct(wvmRoot=wvmRoot, ...
    internalModesRoot=fullfile(oceanKitRoot,"InternalModes-2.0.0-beta.7"), ...
    dependencyRoot=oceanKitRoot,chebfunRoot=chebfunRoot, ...
    sourceRevision=wvmRevision,providerRevision=providerRevision));
calibrateQuadraticDealiasing("results/calibration",common{:});
measureDealiasingConstruction("results/construction",common{:});
```

The full construction workload is:

```matlab
maxNumCompThreads(1);
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification( ...
    [1e5 1e5 1000],[128 128 65], ...
    N2Function=@(z)1e-4*exp(2*z/700),nEVP=104, ...
    shouldAntialias=true,quadraticDealiasing="fixedFraction");
```

`measureDealiasingConstruction` measures one warmup and three subsequent unprofiled constructions per policy, then performs a separate profiler pass. The constructor's filtering timer measures scoring and work attributable to preparing its inputs; shared linear preparation remains part of total construction time. Inclusive profiler times overlap and cannot be added into projected savings. Failed constructions are recorded as rejections, never as successful timings or silently replaced with a different policy.

`calibrateQuadraticDealiasing` compares 13 parameter choices: no filtering; fixed fractions 1/2, 2/3, and 3/4; and effective bandwidth with energy fractions .95, .99, .999 crossed with bandwidth fractions 1/2, 2/3, 3/4. The primary cases use constant and exponential stratification at 33, 65, and 129 vertical points, plus one sharper profile at 65 points. Additional resolved cases cover the large benchmark's upper horizontal wavenumber band. A preliminary constant-stratification case with 33 points and a 12.5 km domain failed the independent boundary-resolution check (surface error .0832 at k=0.00256305, tolerance .01); it is not a filtering calibration result. The study keeps the boundary tolerance unchanged and uses resolved domains/resolutions.

All profiles occupy `z=[-1000,0]` m. Their squared buoyancy frequencies are `1e-4`, `1e-4*exp(2*z/700)`, and `1e-5+9e-5*exp(-((z+200)/100).^2)` s^-2 for constant, exponential, and sharp respectively. Calibration uses a 16×16 horizontal grid; exact domains, selected wavenumbers, and fine/reference sample counts are in the CSV files. A more concentrated preliminary profile, `1e-6+9.9e-5*exp(-((z+200)/70).^2)`, was rejected at 65 points by the independent inertial linear check (`WV:NoResolvedInertialModes`), before filtering. This rejection is not a filter result and motivated the resolved localized-profile case.

## What the sampled error measures

Every comparison uses the same solved modes evaluated on the simulation grid and two finer grids in the common WKB coordinate. Rebuilt basis values must match the constructor's stored F/G arrays to relative Frobenius error below 1e-9. Fine reference sampling adds no eigensolve. The calibration itself reconstructs those basis objects once to evaluate them; production filtering reuses existing linear-assessment samples and adds no solve.

The diagnostic compares coarse and reference product coefficients through the fixed degree `floor(2*(Nz-1)/3)`, divided by the **full** reference product norm. The norm weights the constant Chebyshev coefficient twice. All policies use the same measured band. Separate fine-versus-reference errors test convergence of both this band and the full spectrum used in the denominator.

Pair samples grow linearly with the available inventory: self, neighboring, reflected, and selected wave/APV pairs, each in FF, FG, and GG channels. Retained-policy subsets include self-products at their cutoff. This is bounded calibration, not certification of all pairs, physical derivatives, or nonlinear dynamics. Zero retained counts and empty sample sets are reported explicitly; missing samples do not mean zero error.

## Recorded evidence

The calibrated production default is **`fixedFraction`, `retainedFraction=2/3`**. The optional effective-bandwidth defaults remain **`energyFraction=.99`, `bandwidthFraction=2/3`**. Across nine resolved cases, fixed fraction retains 65.8–66.7% of the linear inventory with maximum sampled error **0.008284**; effective bandwidth retains 67.9–72.2% with maximum **0.028620**. No filtering reaches **0.716635**. Raising effective-bandwidth energy coverage to .999 gives the same worst error as fixed fraction with slightly lower average retention; this does not justify a more complex default. A fixed half retains fewer modes and lowers error further; two thirds is an empirical retention/error tradeoff, not an error-minimizing optimum.

| Policy | Full constructor median (s) | Policy/report timer (ms) | Waves per sign, each k | APV |
|---|---:|---:|---:|---:|
| `none` | 15.6649 | 20.045 | 38 | 38 |
| `fixedFraction` | 15.3164 | 19.746 | 25 | 25 |
| `effectiveBandwidth` | 15.4796 | 217.958 | 26 | 26 |

These are fresh-process medians after one warmup and three measured calls per policy. The `none` timer includes policy dispatch, validation, and reporting, so the fixed-fraction timer is essentially the same small overhead. Differences of a few tenths of a second in full construction should not be overinterpreted as speedups. Every policy performs the same 1,140 wave/inertial candidate/reference solves. Bandwidth scoring uses existing fine samples and adds no eigensolve.

The first measurement sequence interleaved profiler passes between timing batches and produced inflated later timings. Those trials are preserved in `results/construction-profile-sequence` but excluded from the comparison above. The script now completes **all unprofiled batches before any profiling**. The separate profiles are 23.39, 23.47, and 23.96 seconds respectively; they use unchanged runtime code. Eigenpair solution is the largest remaining hotspot (about 7.3 seconds self time within the profiled solver), followed by the wave-assessment loop. None of these overlapping profiler times is added into promised savings.

The calibration contains **702 policy records and 35,124 unique product samples**. Every selected sample count, maximum, and percentile was reconciled against the raw products during Astra review. Maximum fine-to-reference full-spectrum error is **2.3932e-13**, and reconstructed coarse mode shapes match the constructor's stored arrays exactly in these recorded cases. This sampled F/G study does not certify all mode pairs, physical derivatives, or interactions with inertial, MDA, and boundary families.

- `results/baseline`: matched pre-change linear-only construction at WVM `2c3c216593415ee6c909ae64e4b8fe97d25ad57f`, provider beta.6 `370162ddf71781689b560163bb3e3d2751d80c28`. Median 15.6113 seconds, 38 waves per wavenumber and 38 APV modes, 569 positive wavenumbers and 1,140 wave/inertial candidate/reference solves. This control explicitly disabled the old quadratic assessment.
- `results/verification`: focused scientific, persistence, nonlinear, and exported-provider test evidence, including initial failures and their targeted reruns.
- Calibration and final construction outputs record revisions, resolved dependency roots, raw timings, retained counts, and sampled errors. The workspace Chebfun checkout used for matched timing is `1fe01297a74d9ee765a466c3068b7fb474bee053`.

The eight constant/exponential cases ran with study revision `ffb349ec500a3104a0859f1a0d578a2c1c1af9bc`; the resolved sharp case uses `f80167e7072a435b433672d4bb20e9cd33e219a6`. The consolidated files exactly concatenate the preserved `calibration-main` and `calibration-sharp` records. Final timing/figure sequencing is implemented in `ced7dc0b`; numerical runtime code remains pinned to `ffb349ec500a3104a0859f1a0d578a2c1c1af9bc` throughout.

Verification: **85 distinct focused WVM tests** have passing latest results in the consolidated ledger (not a fresh full-suite run). The final targeted batch passed 28/28, including all four corrected initial failures, strict-count/refinement edges, persistence, nonlinear evolution and adaptive restart, and Thermal APV diagnostics/output. The release metadata suite passed 9/9; native MPM installation verified the full declared dependency graph and passed five nonlinear-policy tests using installed production code. Released-provider verification passed 42 tests, including 11 scoring tests. Documentation build/check has zero drift across 2,649 files and 5,405 routes. Code Analyzer reports zero blocking findings across 349 production files; changed authoring files have only five existing/permitted growth advisories. GPT-6 Astra extra-high correctness/simplicity and scientific reviews are clear.

The energy test retains its original 1e-5 physical temporal-invariance criterion. A redundant 1e-13 assertion had mislabeled `totalEnergy` as a separate modal invariant even though its getter directly returns `physicalEnergy().totalEnergy`; that assertion was removed. Production scientific tolerances were not changed.

The historical motivation was about **17.57 seconds** for linear-only construction versus **650.75 seconds before rejection** with the old quadratic assessment. The latter was a failed diagnostic run, not a successful-construction baseline, and is not used to claim a speedup. Its pinned reproduction is preserved in the linked milestone and earlier construction study.

## Technical note and figure

After recording the study, generate the note inputs with Python and Matplotlib:

```sh
python generateFigures.py results /path/to/literature/ape-apv-free-surface/notes/quadratic-dealiasing-data
```

Compile `notes/quadratic-dealiasing.tex` from the literature project with `latexmk -pdf -outdir=notes -interaction=nonstopmode -halt-on-error notes/quadratic-dealiasing.tex`. The note includes policy definitions, common coordinates, complexity, limitations, retained wave counts versus wavenumber with APV counts, and the recorded timing/error comparison. The generator uses recorded data only.

The generator also works directly from the copied note data directory (`python generateFigures.py . .`). Figure generation used Python 3.12 and Matplotlib 3.11.2. The three-page PDF was compiled with TeX Live 2025 and every rendered page was visually inspected, with no overfull boxes or unresolved references.

The live construction path uses the new policies. Removal of remaining dedicated legacy survey helpers and obsolete documentation is the separate final issue [#42](https://github.com/JeffreyEarly/internal-modes/issues/42). That is the next recommended target: the replacement behavior, calibration, and note are now available, so cleanup can establish the final API boundary. Revisit toolbox-free parallel eigensolves after that cleanup using the refreshed profile; no parallel speedup is claimed by this study.
