# Short seasonal QG spatial accuracy (#353)

> Current scope: the [adiabatic qualification handoff](Issue353AdiabaticQualification.md) supersedes this report's historical next-work recommendations. Numerical results and failed accuracy criteria below remain unchanged. Thin-layer diffusion research is #389; the long adiabatic application is #367; release/install/export work is #354.

The short seasonal model can be composed and restarted through existing v4-style interfaces, but those properties do not establish its spatial accuracy. This study separates vertical sampling, retained APV bandwidth, horizontal resolution, time error, and resolution-dependent adaptive damping. Every transform uses its resolved modes; no production basis, runtime class, model hierarchy, forcing interface or persistence contract changes.

The principal result is that additional vertical samples at fixed modal bandwidth cannot recover missing QGPV content. At day 64, the undamped 14-mode case changes by about `7.15e-8` relatively in QGPV when increasing 65 to 129 samples, while 56 versus 84 retained APV modes still differs by about 48%. The latter is an unresolved reference comparison, not an estimate with a converged continuum reference. Accurate SSH alone is insufficient to qualify QGPV or the bottom anomaly.

## Physical case and bounded comparison matrix

All nonlinear cases use `makeShortSeasonalQGModel`: a 500 km square, 4 km depth, latitude 24 degrees, $N^2=(5.2\times10^{-3})^2\exp(2z/1300)$, both finite endpoint parameters equal to the negative/positive stratification integral, a deterministic 1 cm RMS surface seed, zero initial interior QGPV and MDA, and the annual mode-5 strict surface-anomaly source. Nonlinear advection, $\kappa_z=10^{-5}$ m2/s and quadratic drag with $C_d=10^{-3}$ are present throughout. The physical forcing is reconstructed on each grid, with the existing unresolved-pattern rejection. MDA count is independently fixed at two; MDA stays zero.

| Comparison | Horizontal samples | Vertical samples | APV counts | Adaptive damping |
| --- | --- | --- | --- | --- |
| Sampling at the original bandwidth | 24 x 24 | 65, 97, 129 | 14 | Off |
| Retained bandwidth | 24 x 24 | 257 | 14, 28, 56, 84 | Off |
| Sampling at the highest bandwidth | 24 x 24 | 257, 385, 513 | 84 | Off |
| Horizontal refinement | 24 x 24, 36 x 36, 48 x 48 | 257 | 84 | Off |
| Complete-case resolution sensitivity | Same horizontal series | 257 | 84 | On |

The finite matrix has 17 configurations, including three half-step controls. Observations are at days 32 and 64. Main runs use one-day fixed ETDRK4 steps; half-day controls cover the 129-node/14-mode sampling reference and both 48 x 48 x 257/84-mode horizontal references. Every accepted step is checked against the requested step; adaptive tolerance settings are not used as a substitute for timestep refinement. The two observation times align with all steps.

Scientific construction retains its existing Gram and quadratic-product certification. The configuration CSV records actual sample and family counts, certification diagnostics and timing. High-band sampling comparisons are required separately: certification alone is not a nonlinear trajectory-convergence test. The existing constructor also changes its scientific EVP resolution as `nEVP=max(96,3*(Nz+4))` and requests `Nz+4` basis modes. Thus these fixed-count grid comparisons include both sampling/quadrature and the changed scientific solve; they do not isolate quadrature error while holding the provider basis exactly fixed. In the fixed-257-sample bandwidth series, that scientific solve resolution stays fixed. All grids are stored WKB Chebyshev-Lobatto grids with their existing positive physical quadrature.

## Comparison and acceptance definitions

Fields are reconstructed through `reconstructSpectralState` and `transformStateBack`. The stored WKB coordinate map is interpolated to one common physical-depth Gauss rule, using `qgVerticalOperators` and `qgVerticalInterpolation`. The rule contains twice the larger native sample count plus one point. It is doubled for the 56/84-mode comparison. This interpolates the stored resolved fields without fitting or replacing modal functions.

Fourier columns are matched by the union of their integer wavevectors, with absent columns filled with zero. This retains high-wavenumber content missing from a coarse run. Parseval weights are two for compact nonzero columns and one for the horizontal mean. The bounded case requires zero MDA; this study helper is not a general cross-model comparison API. An independent manufactured Fourier-tail test verifies that an added mode beyond the coarse cutoff contributes exactly its positive physical energy to the measured difference. It uses `coefficientStateForTransform` to express compatible shared content and checks against `quadraticDiagnostics`.

QGPV and buoyancy differences are depth/horizontal RMS. Buoyancy is reconstructed as $b=-N^2[\eta-(1+z/D)\zeta]$, where $\zeta$ is SSH. SSH and endpoint-anomaly differences are horizontal RMS. The positive energy norm is

$$\|\delta s\|_E=\left[\frac12\int_{-D}^0\langle\delta u^2+\delta v^2+N^2\delta\eta^2\rangle\,dz+\frac12 g\langle\delta\zeta^2\rangle\right]^{1/2}.$$

The reported relative energy norm divides by the same positive norm of the reference. Cross terms are retained by differencing complete physical fields before squaring. Signed generalized energy uses the positive denominator $E+|g_0|B_0+|g_d|B_d$; it never serves as an error norm. Inventories and process rates use existing native `quadraticDiagnostics`; each process is isolated with `coefficientTendency(excludingForcing=...)`. Spectral errors sum absolute per-Fourier-integer energy or enstrophy differences, normalized by the reference inventory. Native spectra and all process budgets are included in the CSVs.

The following targets were declared before comparing the results. They express one bounded study's requirements, not model defaults or a universal accuracy threshold. An individual comparison passes when its absolute difference is at most $a+rM$, with absolute tolerance $a$, relative tolerance $r$, and reference magnitude $M$.

| Observable | Absolute tolerance | Relative tolerance |
| --- | ---: | ---: |
| QGPV RMS | `1e-13` s-1 | 5% |
| Buoyancy RMS | `1e-10` m/s2 | 0.1% |
| SSH RMS | `1e-8` m | 0.01% |
| Each endpoint anomaly RMS | `1e-8` m | 0.1% |
| Positive physical energy norm | 0 | 0.01% |
| Physical/generalized energy inventories | 0 | 0.02% |
| Endpoint second moments | 0 | 0.2% |
| Enstrophy inventory/spectrum | 0 | 10% |
| Energy spectrum | 0 | 0.1% |
| Each process inventory rate | `1e-6` times the sum of absolute reference process rates for that inventory | 1% |

Velocity and displacement RMS are also reported, without assigned tolerances. A missing tolerance is recorded as NaN; a false `withinTolerance` there does not denote scientific failure. Zero error divided by zero magnitude is zero; a nonzero error divided by zero is Inf, with the absolute error retained.

Passing a candidate/reference difference alone does not qualify a resolution. For a recommendation from this matrix, the last reference-pair difference must also be at most one fifth of that observable's tolerance and the measured time contribution at most one tenth. These are reference-stability checks, not upper error bounds. Comparisons at a roundoff/operator-solve floor need not decrease monotonically. The fixed-band series qualifies sampling of that band only.

## Nonlinear results

At day 64, the main relative differences are:

| Candidate / reference | QGPV | Buoyancy | SSH | Bottom anomaly | Positive energy norm |
| --- | ---: | ---: | ---: | ---: | ---: |
| 65 / 129 samples, 14 APV | `7.15e-8` | `1.42e-10` | `5.38e-12` | `6.38e-7` | `1.61e-10` |
| 14 / 84 APV, 257 samples | 94.8% | 0.437% | `9.45e-6` | 107% | 0.306% |
| 28 / 84 APV, 257 samples | 81.7% | 0.350% | `6.69e-6` | 93.0% | 0.246% |
| 56 / 84 APV, 257 samples | 48.1% | 0.199% | `2.44e-6` | 45.9% | 0.143% |
| 24 / 48 horizontal, damping off | 0.0159% | `3.87e-5` | `2.73e-5` | `6.23e-5` | `3.80e-5` |
| 36 / 48 horizontal, damping off | 0.00634% | `1.46e-5` | `9.47e-6` | `1.31e-5` | `1.44e-5` |
| 24 / 48 horizontal, damping on | 6.18% | 0.0375% | 0.0129% | 4.75% | 0.0283% |
| 36 / 48 horizontal, damping on | 2.86% | 0.0162% | `1.73e-5` | 2.22% | 0.0114% |

All entries without a percent sign are dimensionless fractions. The error CSV includes absolute errors, reference magnitudes, allowances and individual tolerance results at both times; it also includes every inventory, spectrum and process-rate comparison.

The retained-band reference is not adequate for QGPV, bottom-anomaly or positive-energy-norm qualification. For example, the day-64 56/84 QGPV difference is `7.21e-9` s-1 RMS, versus a reference magnitude `1.50e-8` s-1. Its bottom-anomaly difference is `4.90e-4` m. These are not hidden by a small denominator or rescued by accurate SSH. The study therefore does not recommend 84 modes as a generally accurate seasonal solution.

The 84-mode sampling controls expose an additional limit. At day 64, 257/513-node QGPV and positive-energy-norm differences are `5.17e-5` and `7.25e-8` relatively, but the bottom-anomaly difference is `2.40e-6` m (0.224%). The 385/513-node bottom-anomaly difference is `3.65e-6` m (0.341%), reaching 0.402% at day 32. It fails the stated endpoint tolerance and does not decrease monotonically. These differences are much smaller than the retained-band endpoint difference, but high-band endpoint accuracy is not qualified. The data do not distinguish provider-solve sensitivity, endpoint reconstruction conditioning and sampled evolution; that attribution requires a controlled follow-up with the scientific basis held fixed.

Across all comparisons, doubling the common comparison quadrature changes absolute errors by at most `1.02e-17` and relative errors by at most `3.33e-15`. This rules out the comparison quadrature as the source of the large measured differences. One-day/half-day QGPV differences are below `2.0e-11` without damping and `1.30e-8` with damping; positive-energy-norm differences are below `4.0e-11`.

The useful resolution choices are therefore conditional:

- 65 vertical samples adequately represent the original 14-mode case against this study's sampling targets and reference checks. That conclusion does not establish adequate retained bandwidth.
- At 84 modes, the 257/385/513 sample series supports small QGPV and positive-energy-norm sampling differences, but does not qualify the bottom anomaly.
- For the undamped 84-mode finite-band case, 24 x 24 horizontal sampling meets the declared observable and process-rate comparison targets, with the 36/48 reference change and measured time error below their allocated fractions. This remains conditional on the retained vertical problem. The source is a single low Fourier mode and the short seeded case is weakly nonlinear; this result does not qualify a developed turbulent cascade or a long production trajectory.
- The tested low modal bands do not qualify QGPV, endpoint anomalies, generalized energy or all process budgets. Even 56/84-mode reference differences exceed the relevant targets. SSH and total physical energy are much less sensitive; their success cannot be extended to the other quantities.
- The complete damped case needs a separate closure/resolution decision. Its 36/48 QGPV reference sensitivity still consumes 57% of the 5% QGPV tolerance, exceeding the one-fifth reference allocation, and bottom-anomaly and energy-norm targets fail.

Without adaptive damping, horizontal and temporal differences are small in the specified finite band. Enabling adaptive damping changes the resolution dependence: its QGPV and bottom-anomaly differences are materially larger. Those comparisons change a resolution-dependent closure and are labeled `dampedSensitivity`, not same-equation discretization errors. Retaining the same closure class name does not keep its effective operator fixed.

## Linear intended-resolution preflight

`runShortSeasonalQGLinearPreflight` calls the public `WVVerticalDiffusivity.assessSeasonalResponse` API. A 100 km mode-1 horizontal proxy has exactly the same forced wavenumber as mode 5 in the 500 km case and the same sinusoidal pattern RMS, vertical physics and forcing amplitude. It evaluates the response from rest at days 64 and 91.3125. This isolated linear problem excludes the seed, nonlinear advection, drag and adaptive damping; it cannot certify a full 64 x 64 nonlinear production run.

The reduced candidate retains 14 APV modes on 65 samples with progressively finer 129/257-node references. The intended 513-node candidate explicitly retains 217 APV modes, the experiment bandwidth previously assessed in #351, with 325/433-mode references on 769/1025 samples. Explicit prefixes still pass the existing scientific qualification; they avoid an unnecessary search over larger unrequested bands. All retain two MDA modes and both active boundaries. The CSV records actual retained counts, representation/evolution/total differences and reference convergence. No comparison changes the resolved production basis. At day 64, the reduced linear candidate has 95.5% QGPV difference against 108 APV modes, but the 54/108 reference pair itself differs by 57.7%; this is another underresolved comparison. Its SSH difference is only `1.05e-5` relatively. The public preflight therefore exposes the same observable dependence as the nonlinear study without claiming a nonlinear error bound.

The intended-resolution results are:

| Observable | 217/433 difference, day 64 | 325/433 reference change, day 64 | 217/433 difference, quarter year | 325/433 reference change, quarter year |
| --- | ---: | ---: | ---: | ---: |
| QGPV RMS | 12.54% | 5.74% | 9.21% | 4.18% |
| Buoyancy RMS | 0.0196% | 0.00680% | 0.0163% | 0.00552% |
| SSH RMS | `1.96e-7` | `3.63e-8` | `1.97e-7` | `3.31e-8` |
| Surface anomaly RMS | 0.0226% | 0.00413% | 0.0138% | 0.00228% |
| Bottom anomaly RMS | 238.6% | 130.8% | 186.5% | 108.4% |
| Physical energy inventory | `1.46e-7` | `1.78e-8` | `1.31e-7` | `7.35e-9` |
| Enstrophy inventory | 2.64% | 0.509% | 1.32% | 0.237% |

The large bottom-relative differences must be read with their absolute scales: at day 64 the candidate/reference difference is `3.87e-4` m, the reference-pair difference is `2.12e-4` m, and the finest reference magnitude is `1.62e-4` m. Both fail the absolute-plus-relative endpoint target. This does not establish the true error of the 217-mode model, because the reference itself is unstable. Do not combine both endpoints into a surface-dominated norm and conclude that the bottom is accurate.

The 217-mode linear candidate meets this study's buoyancy, SSH, surface-anomaly and energy inventory targets with sufficiently small reference changes, but QGPV and the bottom anomaly remain unqualified. QGPV's representation component is 12.47% at day 64, versus 1.30% evolution error relative to the projected reference; missing retained content dominates this particular comparison. The independent #351 reference remains separate evidence rather than being silently replaced by this finite resolved-band reference.

## Reproduction and limits

With the corrected authoring dependency graph on the MATLAB path:

```matlab
addpath('Documentation/Examples','Documentation/Validation','UnitTests');
result = TestShortSeasonalQGSpatialAccuracy.runStudy(outputFolder);
linear = runShortSeasonalQGLinearPreflight(outputFolder);
results = runtests('UnitTests/TestShortSeasonalQGSpatialAccuracy.m');
assertSuccess(results);
```

The study writes CSVs and local sampled-state snapshots for inspection; generated MAT files are not committed. CSVs are named `issue-353-spatial-{configurations,errors,quadrature,budgets,spectra,linear}.csv`. Construction and evolution timing is diagnostic, not a performance benchmark.

Baseline WVM is `8a9d7ca1fccb456a62923fdfc5b9f03eae8e4b1a`; InternalModes is the corrected authoring commit `e7ea60dadc4e947769cda89f7c1116f22ffa404b`. Existing #348/#351 independent invariant, diffusion and drag checks remain the evidence for operator physics. This increment provides bounded resolution evidence and explicitly unmet criteria, not a continuum certificate or a replacement for those independent tests.

Experiment pins and saved trajectories are unchanged. Provider release/export, installed-example adoption and full scientific CI remain #354; long seasonal production runs remain #367. The unresolved retained-band reference is explicit scientific follow-up in #353, not a reason to rewrite the existing class hierarchy.

## Verification

Two new scientific tests and eleven affected seasonal tests passed on MATLAB R2025b Update 4. The initial test run used the 15-case matrix; the final expanded 17-case study then passed its finite-output, declared-step, doubled-quadrature, fixed-count sampling and time-error assertions, and regenerated the committed tables. The explicit-band linear preflight completed with all 144 reported absolute differences finite. Code Analyzer returned no findings for the new test and finalized preflight function. Documentation generation/check passed with 2358 files, 4819 routes and zero generated drift. Whitespace, manifest scope and generated-artifact checks passed. The final report records scientific criteria that remain unmet; test success does not turn them into accuracy passes. No task assets are missing.
