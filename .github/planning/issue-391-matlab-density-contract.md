# MATLAB density diagnostic contract

This increment starts from v4 main `6fed53701480d031fcc1d495fbd6cfe2dc7cd593`. Its goal is to establish and qualify the MATLAB physical and numerical contract before implementing C++ density diagnostics. The C++ phase and density catalog rows remain rejected throughout this work.

## Physical contract

The actual no-motion profile is the stably rearranged current density distribution. Material height is its inverse evaluated at the parcel density, and `eta_true` is current height minus material height. APE and APV must use that same displacement and profile. A changed, stable, motionless profile must produce zero displacement, APE and APV even when it differs from `rho_nm0`.

`literature/ape-apv-free-surface/main.tex` defines this contract in its displacement, density-moment, APE and APV sections. Substitution of the initial profile is an approximation motivated by earlier runtime and convergence limitations. An optimizer's successful termination does not establish that its recovered profile represents the current distribution accurately.

## Compatibility decision

Existing MATLAB defaults and the runtime-only `shouldUseTrueNoMotionProfile` flag are covered by the owner's general compatibility requirement. The owner has been asked whether this density increment may change that default and retire the approximation. Until that answer arrives, dependent default and persistence changes are pending. The earlier compatibility exception for malformed phase diagnostic encoding does not cover density diagnostics.

## Independent qualification

- Analytic linear and nonlinear stable rest profiles, including profiles different from the initial stratification.
- An exact area-preserving polar twist supported inside the vertical domain, with a known inverse material height, mild displacement and overturning. Continuous volume preservation is tested by grid convergence; it is not assumed exact at sampled quadrature nodes.
- Explicit discrete weighted-parcel distributions, including unequal vertical weights. This is a reference for the discrete distribution, not an automatic prescription for smooth interpolation between nodes.
- Weak gradients, steep smooth gradients, out-of-range targets and nonunique inverses at plateaus.
- APE against an independent analytic integral, both displacement signs and small displacement, and APV against analytic material-height derivatives.
- Profile and diagnostic cache invalidation, request ordering, copied transforms and ordinary saved-file reconstruction.

Captured experiments are `along-track-velocity-decomp/data/run18_restart_day3000.nc` (256×256×43) and `run18_restart_day3250.nc` (512×512×86). Qualification reconstructs these states without time integration, retains their provenance, and separates density extraction, moment formation, solver and diagnostics timings. Compact solver inputs permit routine reproduction without committing the full snapshots. No multi-thousand-day experiment is run in CI.

## Numerical design under evaluation

The shared profile prototype uses a monotone piecewise cubic, safeguarded inversion with a height tolerance, and exact local polynomial integration for APE. Using local integral differences avoids cancellation between large hydrostatic pressures at small displacements. It explicitly rejects plateaus and density outside the represented range rather than silently returning an endpoint. This prototype is not yet connected to transform diagnostics.

The captured comparisons support retaining the raw-moment objective. The normal `lsqnonlin` fit is within 0.52%/0.79% of the optimal fixed-mass discrete Wasserstein floor. The tested equal-weight shifted-Legendre objective improves Jacobian rank but worsens distribution recovery, and is rejected. An augmented-QR damped least-squares candidate improves raw residuals, weighted mean displacement and discrete distribution fit on both states. It is now available explicitly as `WVNoMotionProfileOperation(solver="dampedLeastSquares")` or through `find_rho_nm(...,solver="dampedLeastSquares")`; automatic solver selection is unchanged. Direct solver callers must inspect its output. Operation evaluation retains `lastSolverOutput` and rejects a failed, nonfinite, nonmonotone or residual-above-1e-8 result before caching it.

The stable-rest shortcut returns a horizontally uniform strictly stable profile exactly, including changed extrema. Nonuniform fits still use reference endpoints. Moment formation now recurs through powers after normalizing once; this matches all captured target moments within 1.12e-16 and reduced the measured day3250 extraction from 6.48 to 0.36 seconds. These single-run timings are observations, not a formal performance guarantee.

The shared profile primitive is qualified independently and on fixed fitted JAMES profiles, but it remains disconnected from `EtaTrueOperation` and `APEOperation`. Production APV still derives from the existing eta_true. Consistent transform-level adoption, default/legacy policy, APV integration tests and a portable C++ contract remain unfinished. This foundation PR must not be presented as completing #391 or the full active goal.

## Verification ledger

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

This brings focused coverage to 31 methods across the affected batches. `apv-receipt.json` records the successor's scope and hashes; the original foundation receipt is preserved as historical evidence. No production source changed in this successor, and the prior successful documentation check does not need repetition. Default selection, consistent transform-level operation adoption and their persistence qualification remain pending the owner's compatibility answer.
