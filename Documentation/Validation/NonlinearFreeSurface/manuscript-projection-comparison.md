# Direct manuscript projection: first comparison

This is the first review point in the 10 September pressure-revision plan. It implements the manuscript's direct nonlinear residual in authoring tools and compares it with PR #459's alternative weak stage. It does not replace the runtime or qualify nonlinear trajectories. PR #459 remains draft; its earlier tests do not establish that the weak stage is necessary.

The manuscript is *A unified theory for geostrophic and gravity-wave dynamics of the ocean surface and interior*, [Overleaf](https://www.overleaf.com/project/6317e19111f4547c06f405b1), at `311ebf56c13c30ab4cac423ef7260d3bd693e939`. The implementation baseline is `a2088e8acac7fca67f3c5ae56b73dbfe7183091e`; dependencies remain the declared InternalModes `2.0.0-beta.4` and existing pinned exports. No manuscript, package metadata or released snapshot was changed.

## Equation-to-code contract

The defining equation is `eq:projected-amplitude-equation`,

$$
\dot A_\alpha^\nu = \mathcal S_\alpha^\nu - \Pi_\alpha^\nu[\mathcal N + \mathcal P].
$$

`Pi` denotes the manuscript's source-coefficient functional, implemented by `projectSources`. The state basis already contains the linear phases. The direct evaluator therefore projects only the nonlinear residual, with no second subtraction or addition of the linear generator in the amplitude RHS. Adding the phase derivative is required only when reconstructing the total field time derivative for a diagnostic.

| Manuscript equation | Evaluation in the direct path |
| --- | --- |
| `eq:projection-ready-map-wi`, `eq:projection-ready-geometric-identities` | Reconstruct hatted velocity, total displacement, SSH and modal pressure; form physical velocity and the scalar-transport flux on the fixed reference samples |
| `eq:projection-ready-surface-pressure` | Use the stated approximation `p_hat(0)=rho0*g*ssh`; continue physical-height reference density as a constant above zero, as in the manuscript |
| `eq:projection-ready-x-advection`, `eq:projection-ready-y-advection` | `N.u` and `N.v` are the conservative transport divergences of physical horizontal velocity |
| `eq:projection-ready-x-pressure-nonlinearity`, `eq:projection-ready-y-pressure-nonlinearity` | `P.u` and `P.v` contain the SSH times pressure-gradient and surface-slope times vertical-pressure-gradient terms |
| `eq:projection-ready-horizontal-momentum-tendency` | `H.u/H.v` include advection, Coriolis, linear pressure and nonlinear pressure before entering `N.w` |
| `eq:projection-ready-vertical-advection` | `N.w` retains all physical-velocity, moving-coordinate and `H` terms |
| `eq:projection-ready-vertical-pressure-nonlinearity` | `P.w` combines the vertical pressure metric term with the exact supplied integral of `N_+^2-N2(xi)` |
| `eq:projection-ready-displacement-advection` | `N.eta` retains total-displacement transport and the surface-deformation term |
| `eq:projection-coefficient-and-projector` and the family source formulas | Pass `(-N.u-P.u,-N.v-P.v,-N.w-P.w,-N.eta)` to the generic source projector |

The [evaluator](../../../tools/nonlinear-study/evaluateManuscriptNonlinearTerms.m) performs no projection, pressure solve, nonlinear mass solve or constraint correction. The [comparison driver](../../../tools/nonlinear-study/runManuscriptProjectionComparison.m) supplies modal pressure and the manuscript reference, then calls `projectSources`. Its unforced scope is deliberate. Prescribed sources must subsequently respect the Appendix C `H` bookkeeping: include their horizontal contribution in `H`, or map their physical acceleration separately, without doing both.

## Independent checks

Six [source-projector controls](manuscript-source-projection.md) pass against independent quadrature and analytic formulas. They cover arbitrary sources, pressure gradients with zero/nonzero surface trace, complete linear cancellation, both active boundaries, phase clocks and variable/empty wave counts. Four `TestManuscriptNonlinearTerms` controls pass against independently evaluated Cartesian material equations, including sloping-surface pressure in `H`, the flat inertial/hydrostatic limit and individual term signs. Neither the weak solve nor the pressure solver supplies those test oracles.

The sampled Appendix C transcription also agrees with the separately written mapped-equation helper at identical supplied pressure and buoyancy, with maximum absolute component difference `7.81e-18`. The phase-only SSH identity has maximum absolute error `4.17e-16` m/s. Reconstructed modal-rate divergence is at most `2.62e-17` s^-2 in the initial comparison. These are bounded instantaneous identities, not trajectory results.

## Pressure approximation order

The manuscript explicitly states that using linear pressure in `P` is consistent through quadratic order. The direct path uses that pressure everywhere it appears in Appendix C, including `H` inside `N.w`. The geometric pressure factors are first order in amplitude. Consequently a second-order pressure correction is expected to enter the projected nonlinear residual at third order in a resolved asymptotic regime; this must be checked rather than assumed.

An optional diagnostic solve uses the **same upper-constant reference, buoyancy and approximate surface value** as the direct path. It is not the runtime's differently referenced full-C1 pressure. Its pressure is substituted into every Appendix C pressure occurrence, then only the nonlinear residual is projected. The [eight-row pressure-order study](manuscript-pressure-order.csv) uses the finest tested inventory and horizontal padding two.

For the exponential profile, reducing amplitude successively by one half gives pressure-difference orders `2.0012, 2.0004, 1.9993`, and projected-rate-difference orders `3.0015, 3.0002, 2.9999`. The projected-rate differences at amplitudes `1, 0.5, 0.25, 0.125` are `3.310e-7, 4.133e-8, 5.166e-9, 6.458e-10` in the quadratic hatted-field tendency norm. Constant stratification gives projected orders `3.0072, 3.0312, 2.8208`; the smallest amplitude is less clean, so uniform cubic convergence through arbitrarily small crests is not claimed.

This supports the manuscript's quadratic-order use of modal pressure. It does not establish an all-orders nonlinear pressure closure or exact physical-pressure reconstruction from linear polarization. The reference transition at physical height zero remains a quadrature concern. No pressure solve was used in the direct baseline RHS.

## Retained resolution and comparison with the old method

The [36-row initial study](manuscript-projection-comparison.csv) uses a 100 km square, 1 km deep domain, 8-by-8 horizontal samples, both active boundaries, clocks `t=327`, `t0=-17`, constant `N2=1e-4` or `N2=1e-4*exp(xi/650)`, and a low-mode mixed seed with both wave signs, APV, zero-APV, inertial motion and valid MDA endpoint offsets. The same low-mode/endpoint prescription is used across refinement; an independent common-grid fingerprint of the cross-resolution seed was not included in this first study. At each individual resolution, the methods use exactly the same sampled state.

APV and wave counts apply at each retained nonzero horizontal wavenumber; the horizontally uniform MDA and inertial families use the listed APV count. The following table uses **native-grid rows for both methods**, at amplitude one. The difference is normalized by the direct nonlinear rate in the positive quadratic **hatted-field** norm; it is not the physical tangent norm on the moving geometry.

| Profile | Nz | APV/MDA/inertial count | Wave count | Direct/weak rate difference | Direct SSH-rate error (m/s) | Direct surface-anomaly rate error (m/s) | Direct bottom-anomaly rate error (m/s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Constant | 65 | 2 | 3 | 3.88% | 3.61e-8 | 5.45e-5 | 5.82e-5 |
| Constant | 129 | 4 | 6 | 0.0137% | 6.65e-9 | 8.51e-7 | 5.50e-7 |
| Constant | 257 | 8 | 12 | 0.00712% | 1.06e-9 | 1.21e-7 | 7.86e-8 |
| Exponential | 65 | 2 | 3 | 3.59% | 9.29e-8 | 1.36e-4 | 1.02e-4 |
| Exponential | 129 | 4 | 6 | 0.0819% | 1.39e-8 | 3.32e-6 | 5.41e-7 |
| Exponential | 257 | 8 | 12 | 0.0779% | 1.93e-9 | 4.11e-7 | 5.81e-8 |

The comparison weak solve is supplied the same manuscript buoyancy and surface approximation; it is an adapter of the old discretization, not an untouched full-C1 runtime run. Its retained boundary constraints are enforced by construction and cannot serve as an independent correctness oracle. The table records actual Appendix C nonlinear residuals, not arbitrary manufactured volume sources.

The [fixed-count control](manuscript-fixed-counts.csv) keeps counts at `2/3` while increasing Nz from 65 to 257. The boundary residuals change by less than `5e-10` relative. Thus the improvement above is driven by increasing retained families, rather than simply sampling the same low-count fields more finely, for these states. Halving amplitude reduces the boundary errors by approximately four. The errors are finite-inventory nonlinear errors; they are not eliminated by the projector identities alone.

Horizontal padding is applied only to the direct residual; the weak comparison, boundary target and strong-equation reference remain native-grid quantities. Padding changes the direct rate by approximately `1.1e-5` to `6.2e-5` relative in the fixed-count controls, while leaving the listed boundary errors essentially unchanged. This does not qualify an overintegrated weak solve. The `strongResidual` column is explicitly the difference against the fixed native-grid supplied-modal-pressure equations. It includes unrepresented pressure-gradient acceleration and other unresolved components; it is not a projected modal error or proof of PDE convergence.

## Energy, cost and the unresolved boundary question

The energy diagnostic differentiates physical kinetic energy plus the manuscript's upper-constant-reference APE and approximate `g*ssh^2/2` surface energy. The latter matches the selected pressure boundary condition; omitted matching cubic terms are not automatically an energy defect. Twelve fixed-count controls compare the analytic directional derivative with independent centered differences at steps `1, 0.1, 0.01` s; the largest best-step absolute discrepancy is `1.10e-12` m^3/s^3. Individual step errors were printed in the local run output. This checks the derivative, not conservation by either projected evolution.

Instantaneous energy rates are generally nonzero and are recorded for both methods. No favorable scalar energy rate is used to choose a correction, and no APV or trajectory-conservation claim is made in this first handoff. Direct assembly/projection and the weak solve are timed separately; these are single observations excluding reconstruction and different setup costs, not a controlled speedup benchmark.

Let `C(t)` reconstruct SSH. Modal phases give `C_t A=hat(w)_s`, so the remaining kinematic requirement is `C dot(A)=0`. Direct projection therefore needs `C Pi[S-N-P]=0` to the intended retained accuracy. The source-projector formulas alone do not establish this for every finite inventory. Likewise, active endpoint anomalies must follow their projected material-advection equations. The measurements above locate a finite-count error that decreases with retained resolution; they do not yet define an acceptable nonlinear count policy or prove exact finite-dimensional boundary preservation.

The next decision is how to qualify that retained error, with dimensionally meaningful boundary scales and short trajectories, while following the direct manuscript equation. A nonzero finite-count residual is not by itself a justification for replacing that equation with the old constraint reaction. Public runtime replacement and removal of unused weak-stage machinery follow that review.

## Reproduction and verification ledger

After `configureCIEnvironment` with the pinned exports, add `tools/nonlinear-study` and run:

```matlab
runManuscriptProjectionComparison('comparison.csv',levels=[1 2 3],amplitudes=[1 .5 .25]);
runManuscriptProjectionComparison('pressure-order.csv',levels=3,amplitudes=[1 .5 .25 .125],padding=2,shouldCompareDiagnosticPressure=true);
runManuscriptProjectionComparison('fixed-counts.csv',levels=[1 2 3],amplitudes=1,padding=[1 2],fixedModeCounts=[2 3],shouldCheckEnergyDerivative=true);
```

Ten new focused tests passed, with separate Analyzer checks on both new test classes. The three studies completed 36, 8 and 12 measurement rows, respectively; those are study observations, not 56 additional unit tests. Independent algebra/code review confirmed term signs, source phases and the energy derivative, and required the norm/padding qualifications recorded above. Later optional diagnostics add CSV columns containing NaN when not requested; older committed measurement files retain their original columns.

The two study files have zero active or blocking Code Analyzer findings; the driver has one suppressed dynamic-allocation performance advisory for study rows. One documentation check passed with ClassDocumentation 1.3.2: 2,362 files, 4,827 routes, zero failures and zero generated differences. No generated API documentation or website source changed. Final review also restricted profile names to the two implemented reference formulas so a typo cannot select inconsistent stratification and thermodynamics.
