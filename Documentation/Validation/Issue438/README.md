# T7 physical diagnostics and process budgets

This increment implements the thermal peer's physical inventory contract and corrects the T5 energy/component mismatches found in the [milestone audit](../../Architecture/BalancedDiffusionMilestone2Audit.md). Source baseline: `875ac2ec` on `implementation/balanced-diffusion-m2`; the implementation commit is recorded by the milestone handoff. The experiment repository and historical qualification pins are unchanged.

## Physical definitions and reuse

`quadraticDiagnostics(state=...,tendency=...)` follows the existing APV peer's calling convention: one inventory, optional individual or batched family-keyed directional rates, compact nonzero horizontal contributions and a separate horizontal mean. Both `totalEnergy` and `totalEnergySpatiallyIntegrated` now mean the horizontally averaged depth integral, in m3 s-2, as they do on the shared APV/Boussinesq interface. Multiply this value by `Lx*Ly` when a whole-domain energy per reference density is wanted. Stored thermal amplitudes, scientific Gram arrays and their normalization are unchanged.

Kinetic energy integrates `(u^2+v^2)/2`, interior potential energy integrates `N2*eta^2/2` using total displacement, and surface gravitational energy is `g*ssh^2/2`. Potential enstrophy integrates the full reconstructed `qgpv^2/2`; it is not an APV coefficient-norm shortcut. Endpoint inventories are half second moments of surface/bottom displacement anomalies, in m2, including the squared horizontal means. Full nonorthogonal cross terms remain within selected states and between selected pieces. Separate component energies therefore need not add to the union's energy. No signed generalized inventory has been assigned to the thermal coordinates.

`physicalMetricOperators` caches immutable physical-depth Gauss-Legendre reconstruction factors and Gram matrices. Inventories and batched rates contract the reconstruction factors directly, avoiding the extra conditioning loss from a squared Gram matrix in nearly cancelling source/null directions. MDA uses authoritative stored native fields interpolated in their WKB coordinate. The cache survives coefficient/time changes and is rebuilt from stored arrays after restoration. It performs no InternalModes solve. Physical factors and nonlinear product quadrature retain their separate purposes.

`physicalDiagnostics` supplies RMS, sampled native-grid absolute peaks, radial spectra and horizontal tail fractions. It uses the existing geometry's `transformToRadialWavenumber` bins; the spectra are squared-RMS bin sums, not densities per rad/m. The zero-wavenumber mean is included exactly once. Default tails count squared RMS at physical radii at least 0.8 of the maximum retained radius. They measure occupied horizontal bandwidth, not unresolved error, vertical accuracy or an APV spectrum inferred from thermal eigenvector order. Peak values are samples, not guarantees of continuous maxima.

The existing field operations and family-mask selection supply the physical fields. There is no additional observer or diagnostic state hierarchy. The optional RHS process breakdown supplies the exact ordered coefficient increments used by evolution; diagnostics contract those increments without reimplementing the physical laws.

## Verification ledger

Clean MATLAB setup used `configureCIEnvironment` with installed OceanKit snapshots, then removed older sibling `/internal-modes*` paths and asserted unique `IMInternalModes` resolution inside `OceanKit/InternalModes-2.0.0-beta.4`. The provider tag is `v2.0.0-beta.4`, revision `f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`. Other dependencies are Distributions 2.0.0, SplineCore 2.2.0, chebfun 5.7.0, NetCDF 1.0.2 and ClassAnnotations 1.2.1. MATLAB R2026a Update 4 ran on `maca64`, double precision, with `maxNumCompThreads(2)` to share the host with concurrent verification. Run all local `matlab -batch` commands outside the Codex sandbox.

```matlab
restoredefaultpath;
root = pwd;
addpath(fullfile(root,'tools'));
configureCIEnvironment(root,fullfile(fileparts(root),'OceanKit'));
p = strsplit(path,pathsep);
old = p(contains(p,'/internal-modes'));
if ~isempty(old), rmpath(strjoin(old,pathsep)); end
assert(contains(which('IMInternalModes'),'OceanKit/InternalModes-2.0.0-beta.4'));
assert(numel(which('IMInternalModes','-all'))==1);
maxNumCompThreads(2);
addpath(fullfile(root,'UnitTests'),fullfile(root,'UnitTests','Fixtures'));
assertSuccess(runtests('UnitTests/TestThermalDiagnostics.m'));
assertSuccess(runtests('UnitTests/TestSharedResolvedContracts.m'));
results = qualifyThermalDiagnostics('Documentation/Validation/Issue438');
```

- Four thermal tests pass: independently reconstructed inventories, batched directional rates, selected-state cross terms/cache lifecycle, and radial spectra/RMS/tails. Tests cover pure thermal, pure mean and mixed states under constant/exponential stratification and signed mean content; inventory and directional-rate allowances are 2e-9 and 2e-8 relative with stated absolute floors. The first cross-term fixture was too weak to satisfy its deliberate nonorthogonality assertion; replacing it with the strongest normalized off-diagonal pair made the test exercise the intended contract. This was a test-fixture correction, not a relaxed scientific tolerance.
- All six shared resolved-contract tests pass, including the new nonzero thermal energy/component test alongside existing APV and Boussinesq field/component/cache controls. Public energy accessors are checked against an independent depth integral.
- Code Analyzer reports zero findings for the four new runtime methods, the thermal test and the qualification tool. Whitespace checks pass. Generated documentation and the combined milestone regressions are owned by the final integration verification.
- The qualification launcher initially used a local helper named `plus`, shadowing MATLAB's numeric operator; renaming it to `combineState` resolved this before any scientific result was produced.

## Bounded nonlinear controls

The retained tables use a 500 km square domain, 1 km depth, 12 by 12 horizontal grid, 129 native depth samples, 17 complete thermal directions and four MDA modes. They compare constant `N2=1e-4` with `N2=1e-4*exp(2*z/1300)`. A deterministic pressure field with degrees 2, 3 and 4, amplitude `1e4 m2/s`, a degree-16 perturbation of `0.5 m2/s`, and signed MDA amplitudes `[0.1,-0.2,0.3,-0.1] m` exercises mixed fields and initial adjustment.

The unforced case retains nonlinear advection with zero diffusivity. The forced case adds diffusivity `0.01 m2/s`, strict surface displacement forcing of amplitude `1e-5 m/s` with period 20000 s and phase pi/2, plus quadratic bottom drag with `Cd=1e-3`. These are bounded mechanism controls, not a replacement for the historically qualified full-depth annual seasonal case or a campaign damping choice.

Integration runs to 20000 s with maximum step 25 s. Budget observations use 5 s intervals for the first 100 s, 50 s to 1000 s and 100 s thereafter. Coarse-budget quadrature uses alternate observations from the same trajectory, separating budget-sampling convergence from trajectory error. The 100 s startup work is retained explicitly. Each process uses the same RHS increment used by integration; actual nonlinear enstrophy/endpoint power is accounted for without asserting an exact conservation law beyond the resolved Galerkin representation.

| Check | Result |
| --- | --- |
| Maximum inventory error against native physical integrals | 3.99e-16 relative |
| Directional powers from independently reconstructed central differences | All error/allowance ratios below 1 |
| Strict-source direct interior-enstrophy power | Below 6.8e-44 m s-3 in these states; finite-precision reference allowance retained |
| Maximum unforced budget residual | 9.07e-14 relative |
| Maximum source/diffusion/drag fine-budget residual | 1.071e-5 relative; gate 2e-5 |
| Budget sampling refinement | Approximately fourfold residual reduction in the forced controls; all predeclared convergence gates pass |

Budget normalization is the maximum of the initial inventory, the absolute inventory change and the sum of absolute integrated individual-process work. This scale remains meaningful when opposing mechanisms cancel. `budgets.csv` records fine/coarse residuals; `work-*.csv` retains each process integral; `trajectory-*.csv` retains inventories and observation times; `directional-rates.csv` retains direct comparison values and allowances.

## Damping-inclusive budget and independent closure audit

The [with-damping tables](with-damping/budgets.csv) repeat the two forced controls with `WVThermalAPVDamping`, a frozen six-coordinate APV band, default signed endpoint weights (`g0=-integral(N2 dz)`, `gd=+integral(N2 dz)`) and `apvCutoffFraction=0.5`. The same RHS exposes distinct horizontal and vertical process increments. All independent inventory/rate checks pass; the maximum fine-budget residual is 1.0696e-5 and temporal sampling refinement again reduces the residual approximately fourfold. Reproduce with the same clean path setup:

```matlab
results = qualifyThermalDiagnostics('Documentation/Validation/Issue438/with-damping', ...
    dampingFactory=@thermalAPVDampingFixture,shouldRunUnforced=false);
```

The closure's minimum-energy lift preserves its selected APV coordinate rates and leaves the vertical complement unchanged. It does **not** guarantee negative physical-energy work. The constant control's integrated vertical work is -0.149258 m3 s-2; the exponential control's is +0.0796516 m3 s-2. Horizontal work is negative in both. The positive exponential value occurs in the ordinary mixed control, not only in a constructed worst-case direction. These signed powers are retained in the individual-process tables and reconcile with the trajectory inventory changes.

The independent [closure energy audit](closure-energy-audit.csv) constructs a physical energy factor `R` from the new GL reconstruction factors and forms `B=R*A/R`, where `A` is the closure's vertical generator per unit speed. The Hermitian part `(B+B')/2` gives the extremal half-fractional physical energy rates. The maximum full fractional growth rate per unit speed is 1.9085e-5 m-1 for constant stratification and 1.9536e-5 m-1 for exponential stratification. Direct evaluation on the maximizing state agrees; the independently computed operator norm agrees with the closure's bound to numerical precision. `auditThermalDampingEnergy(w,thermalAPVDampingFixture(w))` reproduces the per-radius audit for either constructed thermal control. The helper and fixed six-mode fixture have zero Code Analyzer findings.

This is a deliberately named APV-coordinate closure with measured physical consequences. A scientifically energy-dissipative vertical law would be a distinct closure choice and would not preserve all the same diagonal APV rates. The milestone's campaign decision should consider that tradeoff explicitly. Fresh-process continuation is qualified by T8 using the same saved forcing configuration; it is not inferred from these budget tests. No missing local scientific assets blocked these checks.
