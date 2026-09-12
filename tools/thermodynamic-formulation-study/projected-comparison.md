# Projected thermodynamic tendencies and pressure (#487)

Exact displacement eta and total density displacement h agree to linear order. This increment confirms the common-pressure comparison across all six output families and isolates the effect of feeding converted coefficients into the existing modal pressure functional. It makes no production changes.

## What is compared

Start with a retained displacement state containing both wave signs, APV, zero-APV, inertial oscillations, and mean-density modes. Reconstruct its pressure, velocities, surface elevation, and eta. Convert eta to h analytically for constant or exponential stratification. Mean-density offsets keep parcel labels admissible.

Evaluate the h equation independently with Fourier and Chebyshev derivatives. Convert its total rate back to eta before subtracting the displacement linear operator and calling `projectSources`:

$$\eta_t=\alpha\zeta_t+\frac{N^2(\xi)}{N^2(r)}(h_t-\alpha\zeta_t).$$

This compares the same physical tendency with a common pressure. Comparing the native h and eta coefficient rates without this conversion would instead measure their expected nonlinear coordinate difference. The native h source has S_h=h_t-hat w and its vertical momentum source differs by N²(xi)(h-eta), because the linear restoring term is expressed in h. Both comparisons are recorded separately.

The pressure experiment projects the same physical velocities and SSH twice using `projectFields`, with eta and h respectively. Let the resulting reconstructed pressures be p_eta and p_h. Record delta p=p_h-p_eta, along with p_eta-p_original to separate the conversion effect from baseline modal projection error. A further control converts h back to eta before projecting; its pressure should recover p_eta.

The pressure-feedback column projects the change in **total** grid acceleration from replacing p_original by p_original+delta p, holding the physical state fixed. It includes the ordinary pressure gradient and the free-surface metric terms. This is an isolated sensitivity measurement, not a complete alternative RHS: the projected h state also changes other reconstructed fields. Its nonzero surface-pressure difference additionally shows that it cannot be treated as the same prescribed-SSH state without further work. No pressure or boundary repair is applied.

## Results

The amplitude parameter multiplies all seeded coefficients. At amplitude 0.1, with exponential stratification on 16×16×65 samples:

| Quantity | 3 APV, 4 wave, 2 mean-density modes | 6 APV, 8 wave, 4 mean-density modes |
| --- | ---: | ---: |
| max abs(h-eta), m | 0.0463 | 0.0463 |
| Scalar rate after conversion: max error, m/s | 4.1e-18 | 4.1e-18 |
| Conversion residual after scalar modal projection, m | 0.0228 | 0.00510 |
| max abs(delta p), Pa | 0.631 | 1.23 |
| Baseline pressure projection error, Pa | 4.5e-11 | 4.5e-11 |
| Surface max abs(delta p), Pa | 0.00268 | 0.000319 |

The conversion residual is max abs[(reconstructed h-reconstructed eta)-(h-eta)]. It isolates loss of the nonlinear scalar increment from the baseline eta round trip. More retained modes reduce this residual, while the pressure change remains. It is therefore not justified to assume the pressure change disappears with resolution.

Reducing amplitude by ten reduces h-eta and delta p by approximately 100. Native coefficient differences in the five affected families also decrease by approximately 100; the inertial source is unchanged by the native scalar conversion. The constant-profile control has h=eta and pressure differences at roundoff.

At fixed retained modes, refining 8×8×33 to 16×16×65 reduces the exponential scalar-rate discrepancy from 5.2e-13 to 4.1e-18 m/s. At the refined grid, the largest familywise absolute coefficient discrepancy after converting the rate back is 1.7e-20. Coefficient units and normalizations differ by family; individual values, not a combined physical norm, are recorded in the CSV. Tests also cover each input family separately (with admissible mean-density offsets), two phase times, and a change of reference clock representing the same physical state.

These results establish agreement of grid tendencies followed by the existing source projection under shared pressure. They do **not** establish conjugacy of two truncated coefficient evolution systems. In particular, the nonlinear state conversion uses `projectFields`, while the RHS uses `projectSources`; neither the conversion nor its derivative can be assumed to commute with projection.

## Coefficient derivative follow-up

The [coefficient derivative study](coefficient-tangent.md) now completes the gate described below and records its results.

Define the finite coefficient map T_t(a) by reconstructing displacement state a, converting its scalar to h, and projecting. Compare a candidate density RHS against the derivative of this map along the existing evolution:

$$\dot b=\partial_t T_t(a)+D T_t(a)\,\dot a.$$

A centered directional-difference reference with a step-size convergence check can test this derivative without committing to a production implementation. Include the explicit time dependence of the oscillatory basis. Separate the effect of truncating T from the effect of substituting the existing modal pressure formula. A pressure computed through inverse physical conversion provides a control, but is not yet an implemented inverse of the truncated coefficient map.

Only after this gate should trajectories, invariant residuals, and complete-RHS cost at matched physical error guide adoption. A quadratic change in pressure is a measurable closure change; it is not by itself proof of an unacceptable physical error or grounds to reject the density approach.

## Reproduction and verification

With manifest-compatible dependencies and the repository on the MATLAB path:

```matlab
addpath('tools/thermodynamic-formulation-study','tools/nonlinear-study')
runProjectedThermodynamicStudy
results = runtests('UnitTests/TestProjectedThermodynamicEquivalence.m');
assertSuccess(results)
```

[State measurements](results/projected-states.csv) contain 12 cases spanning two profiles, two amplitudes, and three configurations. [Family measurements](results/projected-families.csv) contain 72 rows. The study disables antialias truncation and uses the stated evaluation grid; it is not a dealiasing qualification. Three inertial modes are retained in every configuration. Pressure is in Pa; scalar errors are in m or m/s as labeled. No runtime or memory assessment is included.

Production source revision remains `cf343b95523240a5de658dcfd309401032b9ad80`. Relevant implementations are `@WVTransformFreeSurfaceBoussinesq/projectFields.m`, `projectSources.m`, `reconstructSpectralState.m`, and `+WVInternal/freeSurfaceNonlinearTerms.m`. The prior grid-level report gives manuscript provenance.

All four new focused tests passed on MATLAB R2026a. Code Analyzer reported no findings in the two new study functions and new test class. Whitespace and scope checks passed; production code, package manifests, released snapshots, and generated website files are unchanged. Documentation validation passed, but `docs:check` reported the same two pre-existing differences recorded in the grid-level report (density-diffusion index and version-history). No successful gate was repeated except where the inverse-conversion control subsequently changed.
