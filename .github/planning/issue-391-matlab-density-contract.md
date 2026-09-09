# MATLAB density diagnostic contract

This increment starts from v4 main `6fed53701480d031fcc1d495fbd6cfe2dc7cd593`. Its goal is to establish and qualify the MATLAB physical and numerical contract before implementing C++ density diagnostics. The C++ phase and density catalog rows remain rejected throughout this work.

## Physical contract

The actual no-motion profile is the stably rearranged current density distribution. Material height is its inverse evaluated at the parcel density, and `eta_true` is current height minus material height. APE and APV must use that same displacement and profile. A changed, stable, motionless profile must produce zero displacement, APE and APV even when it differs from `rho_nm0`.

`literature/ape-apv-free-surface/main.tex` defines this contract in its displacement, density-moment, APE and APV sections. Substitution of the initial profile is an approximation motivated by earlier runtime and convergence limitations. An optimizer's successful termination does not establish that its recovered profile represents the current distribution accurately.

## Compatibility decision

The owner explicitly approved corrected diagnostics using actual `rho_nm` by default on 2026-09-09. All three stratified transforms now default to `shouldUseTrueNoMotionProfile=true`. Explicit `false` retains an original-reference approximation, with the same corrected interpolation and consistent APE reference. It is not a bitwise legacy numerical mode. The flag remains runtime-only; existing restart files load without schema changes and use the new default when diagnostics are recomputed. Copies preserve an explicit selection.

## Independent qualification

- Analytic linear and nonlinear stable rest profiles, including profiles different from the initial stratification.
- An exact area-preserving polar twist supported inside the vertical domain, with a known inverse material height, mild displacement and overturning. Continuous volume preservation is tested by grid convergence; it is not assumed exact at sampled quadrature nodes.
- Explicit discrete weighted-parcel distributions, including unequal vertical weights. This is a reference for the discrete distribution, not an automatic prescription for smooth interpolation between nodes.
- Weak gradients, steep smooth gradients, out-of-range targets and nonunique inverses at plateaus.
- APE against an independent analytic integral, both displacement signs and small displacement, and APV against analytic material-height derivatives.
- Profile and diagnostic cache invalidation, request ordering, copied transforms and ordinary saved-file reconstruction.

Captured experiments are `along-track-velocity-decomp/data/run18_restart_day3000.nc` (256×256×43) and `run18_restart_day3250.nc` (512×512×86). Qualification reconstructs these states without time integration, retains their provenance, and separates density extraction, moment formation, solver and diagnostics timings. Compact solver inputs permit routine reproduction without committing the full snapshots. No multi-thousand-day experiment is run in CI.

## Adopted numerical design

The shared profile calculation uses a monotone piecewise cubic, safeguarded inversion with a height tolerance, and exact local polynomial integration for APE. Using local integral differences avoids cancellation between large hydrostatic pressures at small displacements. It explicitly rejects plateaus and density outside the represented range rather than silently returning an endpoint. `EtaTrueOperation` inverts `wvt.rho_total`; `APEOperation` uses the same selected profile and recovered material height. APV consumes the corrected displacement.

The captured comparisons support retaining the raw-moment objective. The normal `lsqnonlin` fit is within 0.52%/0.79% of the optimal fixed-mass discrete Wasserstein floor. The tested equal-weight shifted-Legendre objective improves Jacobian rank but worsens distribution recovery, and is rejected. An augmented-QR damped least-squares candidate improves raw residuals, weighted mean displacement and discrete distribution fit on both states. It is now the default for both `WVNoMotionProfileOperation()` (including `solver="auto"`) and `find_rho_nm(...)`, independent of Optimization Toolbox availability. Explicit `lsqnonlin` and `fminsearch` preserve their legacy solver choices. Direct solver callers must inspect its output. Operation evaluation retains `lastSolverOutput` and rejects a failed, nonfinite, nonmonotone or residual-above-1e-8 result before caching it.

The stable-rest shortcut returns a horizontally uniform strictly stable profile exactly, including changed extrema. Default nonuniform fits use current density extrema, with the original normalized profile as their starting shape. Explicit legacy solvers retain their original endpoint policy. Moment formation now recurs through powers after normalizing once; this matches all captured target moments within 1.12e-16 and reduced the measured day3250 extraction from 6.48 to 0.36 seconds. These single-run timings are observations, not a formal performance guarantee.

The shared profile calculation is connected to the production transform diagnostics. C++ implementation remains separate: neither phase nor density catalog rows become supported as part of this MATLAB change. This PR therefore does not close all of #391.

## Foundation verification ledger (historical)

- Goal created and clean v4 main isolated on `issue-391-matlab-density-contract`.
- Shared MATLAB, package, caching, documentation and profiling guides read.
- Baseline source audit confirms mixed profile references, discarded optimizer status, unchecked inverse bounds and incomplete cache invalidation when the profile-selection flag changes.
- Thirty focused MATLAB methods pass across the final affected batches: fourteen independent reference/calculus methods, seven solver methods and nine existing eta_true/default/copy/restart/cache methods. The changed stable-rest/dimension checks fail before the fix and pass afterward.
- New precision tests cover both displacement signs down to one-ulp height changes, knot crossings, two-node interpolation, zero endpoint slope and 3D composition. Independent review identified and corrected cancellation by switching the APE primitive to its derivative-integral form.
- Solver checks cover both compact JAMES moment fixtures, exhausted iteration/evaluation budgets, zero-iteration reporting, unqualified-result rejection before caching, and an exact equal-volume parcel rearrangement. A new Code Analyzer finding exposed the empty-loop counter case and was corrected with an explicit counter regression.
- New/changed numerical helper, solver and test files have zero Code Analyzer findings. The three existing transform classes retain precisely their main-branch warning inventories (36/65/38); no unrelated warning cleanup was performed.
- Fourteen CI routing tests pass; the two new scientific test classes are included in the ordinary focused MATLAB inventory. No long experiments or optional full suite were run.
- Canonical flag documentation and changelog were regenerated once. The final documentation comparison reports 2,026 files, 4,145 routes and no differences or validation failures.
- Dependencies and package metadata are unchanged. No released OceanKit snapshot or v5 checkout was edited.
- Captured baseline and experimental reports are in `.github/ci-evidence/issue-391-density/`. Their source hashes remain tied to the measured versions; newer edits are not relabeled as fresh full-state measurements. The detailed chronological ledger is `issue-391-density-qualification.md` beside this plan.

## APV boundary qualification successor

After the foundation commit, one additional focused method qualifies the existing APV operation with the new inverse at its displacement-input boundary. A disk-supported, volume-preserving polar twist generates overturning material-height fields in the x–z and y–z planes. Analytic divergence-free velocity is projected through the actual WV transform; all three reconstructed vorticity components are checked. APV is compared against the independent absolute-vorticity dot analytic material-height-gradient definition, not a copy of the production eta-derivative expression.

On 16/32/64 horizontal grids (17/33/65 vertical nodes), APV RMS errors decrease from 8.17e-4 to 2.15e-5 s^-1 and from 9.46e-4 to 2.75e-5 s^-1. Finest relative RMS errors are 0.0338% and 0.0423%. The compact-support map is C2, so convergence is algebraic. The final test explicitly budgets spectral-roundtrip roundoff separately from differentiated-field accuracy. It passes, and the changed test class has zero Code Analyzer findings.

This brings focused coverage to 31 methods across the affected batches. `apv-receipt.json` records the successor's scope and hashes; the original foundation receipt is preserved as historical evidence. No production source changed in this successor, and the prior successful documentation check does not need repetition. This receipt predates the approved default and transform-level adoption; those are qualified separately below.

## Approved adoption verification ledger

- Actual `rho_nm` is now the default in constant-stratification, hydrostatic and Boussinesq transforms. All use the shared monotone profile for inverse and APE, and APV consumes the corrected displacement. Explicit false uses the original profile consistently. No new persistent profile cache or output registry was added.
- Nine solver methods pass, including current-extrema recovery after an equal-volume rearrangement, a noninvertible constant distribution, infeasible fixed-node fits, bounded controls and both compact JAMES fixtures.
- Eleven transform methods pass across focused batches: default true, explicit false, analytic linear diagnostics, changed nonlinear rest and extrema, actual default parcel rearrangement, failure/retry, copies, flag invalidation, and restart behavior. A coefficient-driven stable mean-density anomaly verifies requested `rho_nm`, `eta_true`, `ape` and `apv` across four NetCDF records through restart, continuation and append.
- The fifteen existing reference/calculus/APV methods pass against the adopted production sources. The independent APV displacement-boundary test retains x-z/y-z finest relative RMS errors of 0.0338%/0.0423%.
- The additional full default-pipeline overturning regression passes on 16/32/64 grids, bringing the reference class to sixteen methods and the final affected MATLAB coverage to forty methods across focused batches. Displacement RMS error decreases from 3.83e-4 to 2.11e-9 m; APE RMS error from 1.08e-6 to 1.38e-11 m2/s2; APV relative RMS error from 1.36% to 0.0338%. This test and its reproducible authoring qualifier have zero Code Analyzer findings.
- Both metadata/default contract methods and the affected domain-documentation method pass. The existing coarse-grid spatial energy-flux conservation test passes with the corrected default without changing its tolerance.
- Production Code Analyzer on twelve affected MATLAB files reports zero blocking findings; its 152 nonblocking findings include the existing transform warning inventories, existing growth advice, and unused operation-signature inputs. Focused solver and transform test classes and the captured-state qualifier have zero ordinary Code Analyzer findings.
- Regenerated the portable catalog and canonical documentation once after the coherent adoption batch. The two metadata tests pass; documentation validation and comparison pass with 2,026 files / 4,145 routes and no differences. The initial metadata batch encountered startup path contamination involving the separate v5 checkout; a fresh `restoredefaultpath`, explicit v4 root and pinned packages resolved it without a source change.
- The original hosted draft run failed because the router treated a reference helper as an executable test class. The corrected router selects top-level `Test*.m` suites while retaining consumer coverage; all fifteen routing regressions pass. The construction-only C++ planner compiles with strict warnings and passes against the regenerated header. No C++ diagnostic row was promoted.
- Repository boundaries, whitespace, JSON evidence and generated-artifact scope checks pass. Package dependencies and manifest are unchanged, and no released package snapshot or v5 file was edited. The broader optional Python workflow tests were not needed; an attempted run found that the local system Python lacks PyYAML. No optional full MATLAB/C++ suite or long integration was run locally.
- Captured production qualification is recorded separately in `final-production-*.json`. Both full-resolution states pass with actual defaults, no injected profile and no integrations. The day3250 load retains its warning about the absent original `GMSpinUpExperiment.m` function-handle path, but state reconstruction and every diagnostic check succeed using the retained modal data.

The MATLAB density increment is ready for review in PR #424. Issue #391 remains open for separate portable phase and density implementation/qualification.
