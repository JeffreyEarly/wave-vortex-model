# Stable linear-cost buoyancy evaluation (#482)

The thermodynamic evaluator now integrates the represented Chebyshev polynomial with a divided-difference recurrence. It computes buoyancy, available potential energy (APE), and the nonlinear buoyancy remainder in O(HZP) work, replacing a Gauss rule with O(P) nodes and approximately O(HZP²) profile-sampling work. P is the represented profile degree, H the horizontal grid size, and Z the vertical sample count.

The displacement formulation, surface continuation, returned fields, and parcel-label rules are unchanged. The existing transform-owned thermodynamic context prepares and reuses the coefficients. Its profile-only construction is separated into an internal helper so accuracy tests need no unrelated modal solve. Restart rebuilds the same derived context. No public transform API or additional field cache is introduced.

## Stable interval calculation

Let a be the bounded density label, d its roundoff adjustment, c=max(z,0), and delta=eta-d-c. Let I'=N² and J''=N². The second divided differences

$$q_I=I[a,a,a+\delta],\qquad q_J=J[a,a,a+\delta]$$

remain finite as delta tends to zero. With A=N²(a)+delta q_I, the evaluator computes

$$B=-\delta A,\qquad \mathrm{APE}=c\delta A+\delta^2q_J,$$

$$R_B=\delta\left[N^2(a)-N^2(\xi)+\delta q_I\right]-N^2(\xi)(c+d).$$

The remainder is evaluated directly, preserving the original eta in the linear term when the density label is adjusted. Signed intervals and crossings of the zero-above-surface stratification continuation use the same formulas. Rounded parcel labels and profile evaluation still set an absolute accuracy floor; this does not promise uniform relative accuracy for a vanishing remainder.

For normalized Chebyshev endpoints x and y, Q_n=T_n[x,x,y] satisfies

$$Q_{n+1}=2yQ_n+2T'_n(x)-Q_{n-1},\qquad Q_0=Q_1=0.$$

Coupled recurrences for T_n and T'_n evaluate both primitive series in a single O(P) pass. Physical-coordinate divided differences include the factor (2/D)². There is no subtraction of nearby primitive values or division by the interval. Primitive coefficients are integrated directly without trimming their small tail terms. Density and reference-pressure primitives retain their previous normalization.

After the existing Chebfun representation is constructed, the additional coefficient preparation costs O(P). The fixed number of remaining profile/primitive evaluations also costs O(HZP). For a fixed profile, thermodynamic work is O(HZ). Modal and Fourier costs elsewhere in the RHS are unchanged.

## Accuracy evidence

15 focused tests passed: interval recurrence, thermodynamics, nonlinear evolution, and RHS/cache/restart controls. Existing analytic tests include constant, linear, exponential, and high-degree profiles; tiny displacement energy; signed intervals; surface crossings; and accepted/rejected endpoint roundoff adjustments.

The new test has 210 independent cases for positive Chebyshev profiles of degrees 0, 1, 8, 32, 64, and 128. A Python standard-library Decimal calculation with 100-digit precision integrates their monomial expansions, independently of the MATLAB recurrence and quadrature. Cases include zero intervals, signed displacements down to 1e-14 m, long intervals, surface crossings, and endpoint adjustments. The oracle follows the existing rounded-label and original-displacement conventions.

The test separately bounds profile values, buoyancy, APE, and the remainder. Its tiny-remainder error allowance includes the measured profile-value error times interval length, plus arithmetic roundoff; it does not divide by a nearly zero reference. The profile-value error itself must stay below 3e-16 in absolute N² units. Across the full-RHS timing cases, maximum relative coefficient-family difference from frozen quadrature was 2.6e-16.

## Runtime evidence

Baseline: the quadrature evaluator from `fbd95036`, with the same optimized reconstruction and projector on both paths. MATLAB R2026a on the local Apple Silicon host, using the manifest-compatible dependency setup from the preceding studies, including InternalModes v2.0.0-beta.4. Setup is recorded separately. Three alternating batches of ten warmed evaluations provide median times.

Evaluator measurements cover 8×8×65 and 32×32×65 grids and amplitudes 0.1, 1e-7, and 1e-12 m. Requested monomial degrees 0, 8, 32, and 64 produce represented Chebyshev degrees 0, 8, 29, and 44. Evaluator speedups range from 1.15× to 3.90×; the higher represented degrees show the largest gains.

| Represented degree | Quadrature RHS (ms) | Recurrence RHS (ms) | Reduction |
| --- | ---: | ---: | ---: |
| 0 | 13.34 | 9.82 | 26% |
| 8 | 5.58 | 4.52 | 19% |
| 29 | 5.98 | 4.48 | 25% |
| 44 | 6.35 | 3.97 | 37% |

These complete unforced RHS measurements use cold field caches and populated six-family states on 8×8×65 grids, with unequal retained counts. Compare implementations within each row: the stratification and corresponding modes change between rows. These are local measurements, not cross-platform speed guarantees. Full data: [evaluator](results/evaluator.csv), [RHS](results/rhs.csv).

Adopt the recurrence for the measured accuracy-preserving benefit. Retain quadrature as an authoring reference, not a runtime backend switch. The displacement-versus-density assessment (#487) remains a separate mathematical and numerical comparison.

## Reproduction and checks

With manifest-compatible dependencies configured, from the WVM repository:

```matlab
addpath('tools/buoyancy-study');
runBuoyancyComparison('/tmp/wvm-buoyancy');
assertSuccess(runtests('UnitTests/TestBuoyancyIntervalRecurrence.m'));
```

Regenerate the independent oracle with `python3 tools/buoyancy-study/generateBuoyancyOracle.py`. It needs only Python's standard library. The frozen quadrature implementation is confined to authoring/tests.

Production Code Analyzer reports zero blocking findings. The new internal code, tests, frozen reference, and study subclass have no findings; the timing script has two array-growth notices outside its timed evaluations. `docs:check` reports only the previously established density-diffusion index and version-history differences. No website, package manifest, or released snapshot changed.
