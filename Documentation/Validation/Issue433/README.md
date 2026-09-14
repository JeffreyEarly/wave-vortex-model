# T2: Complete thermal construction and reconstruction

WVM authoring baseline: `451ce2cf21be9ba9185872be2eb31dcf0721279f`. InternalModes: `v2.0.0-beta.4` (`f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51`), loaded exclusively from the OceanKit snapshot. This increment implements construction, physical reconstruction, state/source projection, polynomial calculus, and canonical snapshots. It does not implement WVModel thermal integration, nonlinear products, forcing adapters, full stream restart, or campaign readiness.

## Implemented surface

`WVTransformFreeSurfaceThermalQG` is a peer of the adiabatic QG transform. `fromStratification` builds every requested Legendre/WKB direction, diagonalizes the unit-diffusivity generator, and gives `Ath` velocity units using unit depth-mean positive-energy normalization. The full nonorthogonal energy Gram matrix is retained. `Amda` is an independent real displacement family using the existing provider normalization and conservative mean diffusion operator. No APV modes are constructed for thermal evolution.

Scientific construction supports positive constant/exponential N2, nonzero f, nonnegative scalar diffusivity, and both active endpoints. Counts are explicit; sampling never silently truncates them. All eigenvalues and null directions are retained. Failed inverse/eigenvector, sampling Gram, endpoint-source or MDA convergence checks reject construction with diagnostics. Positive computed rates remain reported, including roundoff-sized values. This is not a claim that the highest individual eigenvectors resolve continuum eigenfunctions.

`scientificState` contains flat numeric arrays sufficient for cheap construction and annotated restoration. `withDiffusivity` returns a new object with the same basis and physical coefficients, including at zero diffusivity. Neither restoration nor changed diffusivity runs a scientific eigensolve. Spatial caches are derived separately. Compact Fourier completion acts on reconstructed physical coefficients; stored complex thermal eigenvectors carry their conjugate-direction permutation. Nonzero retained Fourier columns exclude self-conjugate Nyquist modes; the zero column uses real MDA coefficients.

Physical fields implement the T1 formulas for psi, velocity, total/interior displacement, physical buoyancy, QGPV, SSH and both endpoint anomalies. Direct and ordinary endpoint-only requests use endpoint maps without constructing a full volume. State fitting minimizes physical-depth weighted QGPV error subject to endpoint constraints. Source projection uses the distinct physical weak dual with independently integrated polynomial test functions. External source means reject explicitly. MDA state means must agree with the supplied mean displacement.

The inherited rigid-lid F/G matrices are empty bootstrap inputs, not alternate coefficient families; legacy projection methods reject. Time evolution, registered forcing, adaptive tolerances, and automatic resolution transfer also reject with actionable errors. The current output is a canonical snapshot, not the full stream/restart interface promised by T8.

## Prototype comparison

`tools/qualifyThermalConstruction.m` invokes the preserved `TestCompleteThermalModes` harness without changing its implementation or reference. Runtime construction is compared in physical fields after its normalization change. A scalar analytic convolution drives this assessment only; T3 retains the requirement to reproduce the seasonal checks through the actual WVModel integrator.

The original 500-km-domain mode-5 problem corresponds to horizontal wavelength 100 km. Depth is 4000 m, latitude 24 degrees, N2=(5.2e-3)^2 exp(2z/1300), diffusivity 1e-5 m2/s, and strict annual source amplitude 10*pi/T. Compare all six observables on days 1, 8, 32, 64 and 91.3125. Assembly/observation quadrature uses 2049 physical-depth Gauss points and the unchanged 385-direction physical-depth reference. Reference accuracy retains the separately refined historical evidence; this task additionally refines runtime assembly to 4097 at fixed 257 directions.

| Complete directions | Reference checks passed | Worst error / original allowance | Worst runtime–prototype difference / allowance |
| --- | ---: | ---: | ---: |
| 129 | 26/30 | 7.84640 | 2.31847e-5 |
| 257 | 30/30 | 0.0124819 | 6.05841e-5 |
| 385 | 30/30 | 0.00119453 | 1.13355e-4 |

The 129-direction failure remains intact. The largest fixed-space assembly-refinement difference is 0.000191499 of the observable allowance, below the 0.2 control allocation. These are physical-state differences, not differences between aggregate error norms.

At 257 directions, the normalized eigen residual is 1.35e-16, inverse round-trip residual 8.16e-14, and eigenvector condition number 20.8084. The amplitude-scaled strict-source QGPV residual is 1.83e-23 s^-2 and endpoint residual 4.43e-18 m/s. The native FFT-backed buoyancy derivative differs from its analytic evaluation by 3.26e-13 relative. At 385 directions the derivative error is 4.02e-12; additional points are not assumed to improve every floating-point diagnostic. The largest dimensional positive rate among the tested spaces is 1.73e-22 s^-1; none was clipped. See the CSV files for every observable and control.

## Focused tests and reproduction

`TestFreeSurfaceThermalQG` covers independent manufactured pressure/velocity/displacement/QGPV relations, state and weak source inversion, first/second mapped derivatives and resampling, signed mean preservation, zero diffusivity, strict surface/bottom sources, mean-source rejection, cache invalidation, family components, corrupted canonical state, and unsupported-operation rejection. A 257-direction actual transform is constructed on 513 physical samples at the target wavelength and exercises source cancellation and physical vertical differentiation. Snapshot recovery is exercised after removing InternalModes from the active MATLAB path; this is a same-process construction test, not T8's fresh-process full-model restart gate.

Use the clean snapshot setup in [T1](../../Architecture/Issue432ThermalTransform.md), then:

```matlab
addpath('UnitTests','tools');
results = runtests('UnitTests/TestFreeSurfaceThermalQG.m');
assertSuccess(results);
evidence = qualifyThermalConstruction(outputDirectory);
```

The qualification writes `runtime-construction.csv`, `runtime-evidence.csv` and `assembly-refinement.csv`, plus untracked prototype outputs in the chosen output directory. Committed CSVs here are the bounded results, not restart inputs or runtime dependencies. The reference harness, versioned snapshots, dependency manifests and experiment case pins remain unchanged.

## Design clarifications

The implemented factory exposes construction settings as ordinary named arguments rather than a nested `constructionOptions` struct, matching existing WVM conventions. Thermal product qualification is explicitly unavailable in T2: `shouldCheckQuadraticAliasing=false` is the default, and requesting true rejects until T4. No quadratic tolerance is accepted without an implemented assessment. `gramTolerance` applies to native thermal sampling and provider MDA sampling; `modeConvergenceTolerance` applies to the independently checked MDA modes; `boundaryResolutionTolerance` bounds the separate endpoint-source construction identity. Complete thermal operator/response evidence remains separate from those constructor gates. The inverse and normalized eigen-residual guards are respectively 1e-8 and 1e-10; the physical response checks above provide the independent scientific qualification.

The scientific constructor uses at least as many physical samples as either family has coefficients. Actual acceptance still depends on sampling/endpoint/MDA evidence. Explicit native/assembly counts and all physical residuals are recorded; 257 is not a default or a nonlinear recommendation. `thermalToPolynomial`, its inverse, source duals and energy/rate arrays are canonically complex-capable on both construction and restore, even when their imaginary values are zero.

## Verification ledger

Verified on MATLAB R2026a Update 4 (`26.1.0.3312084`), using `matlab -batch` outside the macOS sandbox. `configureCIEnvironment` loaded InternalModes 2.0.0-beta.4, SplineCore 2.2.0, Distributions 2.0.0, chebfun 5.7.0, NetCDF 1.0.2 and ClassAnnotations 1.2.1; documentation used ClassDocumentation 1.3.2. `which(...,'-all')` returned exactly one definition each for `IMSolverSpectral` and `IMInternalModes`, both inside `OceanKit/InternalModes-2.0.0-beta.4`. Sibling authoring paths were excluded before tests.

| Gate | Result |
| --- | --- |
| New thermal tests | 8/8 passed |
| Shared resolved contracts | 5/5 passed |
| Existing QG density forcing/integration | 7/7 passed |
| Existing QG coefficient discovery, independent-family round trip and persisted tolerances | 3/3 passed |
| Prototype response and assembly refinement | Passed the controls described above; expected 129-direction failures preserved |
| Code Analyzer | No messages for added MATLAB class, helpers, tests or qualification utility |
| `buildtool docs:build` and one `buildtool docs:check` | 2614 files, 5333 routes, zero validation failures; zero generated differences |
| Runtime-only layout | Construction, field evaluation and exact canonical snapshot recovery passed with only root classes/packages and manifest runtime folders copied to a temporary directory; no authoring tools or experiments on the active path |
| Whitespace, manifest and repository scope | Passed; dependency manifest, released snapshots and experiment pins unchanged |

The runtime-layout check is not an MPM release/install qualification. Full-model restart, nonlinear qualification, performance measurements and actual WVModel thermal integration remain downstream. No required T2 check was blocked. Package-path ordering and Java/X11 startup warnings did not prevent any gate.

To reproduce the focused regression selection after the clean setup:

```matlab
suite = testsuite({'UnitTests/TestFreeSurfaceThermalQG.m', ...
    'UnitTests/TestSharedResolvedContracts.m', ...
    'UnitTests/TestFreeSurfaceQGDensityForcing.m'});
other = testsuite('UnitTests/TestWVTransformFreeSurfaceQG.m');
selected = contains(string({other.Name}), ...
    ["coefficientAnnotationsDriveIntegratorState", ...
     "canonicalFamiliesRoundTripIndependentlyAndTogether", ...
     "initializationTolerancesArePersisted"]);
results = run([suite,other(selected)]);
assertSuccess(results);
buildtool docs:check
```

## T3 handoff (subsequently implemented)

See the [T3 implementation report](../Issue434/README.md) for actual model evolution and its verification. The T2 evidence above remains a construction-only record.

Connect these stored arrays to the existing exponential integrator through `linearEvolutionData()`. Keep thermal amplitudes in their current coordinates; provide the MDA eigencoordinate adapter from `mdaGeneratorPerDiffusivity`. Multiply the unit-diffusivity generators exactly once. Physical error control must use reconstructed observables and the retained full metric, including both endpoint errors.

Adapt the APV-specific constructor, state conversion, source projection and norm boundaries of `WVDensityDiffusionIntegrator`; preserve its controller and accepted-state lifecycle. Connect seasonal source ownership and its absolute clock without also adding the analytically integrated source in explicit stages. Qualify zero diffusion, signed means, rejected-stage restoration and seasonal evolution through actual `WVModel` calls, preserving the six historical observable allowances. Keep nonlinear products, closure choice and full restart qualification assigned to their later increments.
