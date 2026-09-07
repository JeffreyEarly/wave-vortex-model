# Free-surface QG invariant diagnostics and qualification (#348)

The public diagnostics now account for physical energy, signed generalized energy, ordinary potential enstrophy, and both active endpoint anomaly variances. They include MDA means and retain cross terms in the existing APV/zero-APV/MDA coordinates. This work uses the physical formulation in `literature/ape-apv-free-surface/main.tex` and the inviscid-invariants section of `notes/gpt-closed-free-surface-qg.tex`.

## Public contract

```matlab
[totals,spectrum,horizontalMean] = wvt.quadraticDiagnostics();
[budget,spectralBudget,meanBudget] = wvt.quadraticDiagnostics( ...
    tendency=wvt.coefficientTendency());
```

Existing physical-energy components and `totalEnergy` retain their definitions. The added fields are `surfaceAnomalyVariance`, `bottomAnomalyVariance`, and `generalizedEnergy`, with matching `Tendency` fields when a tendency is supplied. Optional `state` and row arrays of tendencies remain supported without mutating the transform.

Using horizontal averages and quantities per unit reference density,

$$B_b = \frac12\langle b_b^2\rangle,\qquad H_g = E + g_0 B_0 + g_d B_d.$$

Here $b_0=\eta_i(0)$ and $b_d=\eta_i(-D)$. The endpoint quantities are half second moments, including squared horizontal means; they do not subtract the mean. Their units are m². Energy units are m³ s⁻²; ordinary potential-enstrophy units are m s⁻². Tendency units are the corresponding inventory units divided by seconds.

Inactive endpoint variances are reported as zero, and their weighted terms are omitted before multiplication. A finite zero endpoint weight still has an active, potentially nonzero endpoint variance. Signed generalized energy can be negative. The positive physical energy continues to define numerical state-error norms and adaptive tolerances.

`spectrum` retains the existing compact nonzero-horizontal-Fourier-column ordering. Contributions already include the omitted conjugate; they must not be doubled again. Within each column, full coefficient cross terms are retained. The optional third output gives the horizontal-mean contribution to every inventory and tendency. For each field, summing the spectrum across columns and adding the mean recovers the total. Scalar inventories have scalar means; a row array of tendencies produces one mean contribution per tendency.

The zero-APV coordinates remain normalized by endpoint data. Their generalized-energy block need not be diagonal. Tests explicitly show a nonzero cross term when both coordinates are excited; no internal rotation or change in prognostic coordinates is required.

## Independent accounting checks

Pure APV, pure zero-APV, pure MDA, and mixed states are checked for all four active/inactive endpoint configurations, with constant and exponential stratification. The reconstructed fields are integrated on independent physical-depth Gauss grids with 129 and 257 points, using the analytic map for each prescribed stratification. Physical energy and full enstrophy agree with their modal inventories to the stated numerical regression tolerance of $10^{-7}$; the independent quadrature refinements agree to $10^{-10}$. Endpoint traces and generalized energy are checked against the same physical fields, including mean contributions. These tolerances test diagnostic consistency and are not universal resolution requirements for a simulation.

Additional checks cover negative generalized energy with positive physical energy, finite zero endpoint weights, spectral/mean sums, directional finite differences, multiple tendency inputs, unchanged canonical state, unchanged horizontal advection after adding MDA, and stored-state reconstruction. The previous inventory test's manual insertion of omitted mean QGPV was removed and shown to fail before the reconstruction correction.

## Nonlinear control problem

The tests use a 100 km square, 1,000 m depth, latitude 30°, $N^2=10^{-4}\exp(2z/B)$ s⁻², and two active endpoints with $g_0=-0.1$ and $g_d=0.1$ m s⁻². Instantaneous-rate studies use both $B=\infty$ and $B=700$ m; trajectory studies use $B=700$ m. Only nonlinear QG advection is enabled: no beta, diffusion, drag, damping, or external source.

Let $X=2\pi x/L_x$ and $Y=2\pi y/L_y$. The same physical target is projected at each resolution:

$$q'=10^{-7}\left[(1+0.2\cos(\pi z/D))\cos X+0.8(1+0.4z/D)\sin Y+0.5\cos(2\pi z/D)\cos(X+Y+0.3)\right],$$

$$b_0=0.1[\cos X+0.7\sin Y+0.5\cos(X+Y+0.7)],\qquad b_d=0.06[\sin(X+0.2)-0.8\cos(Y+0.4)].$$

The MDA target displacement is $0.01\cos(\pi z/D)$ m. The three horizontal wavevectors form interacting, nonparallel modes, and the tests require a nonzero modal RHS. The mean SSH gauge is zero. The shared WKB-Chebyshev grid, antialiasing, and resolved modal families are retained.

Trajectories run to $2\times10^6$ seconds (about 23.15 days) with the supported fixed RK4 integrator. Time refinement holds a 12-by-12 horizontal grid and 65 vertical nodes fixed, using 8, 16, 32, and 64 steps. Vertical refinement holds the 12-by-12 horizontal grid and 64 steps fixed, using 17, 33, 65, and 129 nodes. Horizontal refinement holds 65 vertical nodes and 64 steps fixed, using 8, 12, 16, and 24 points per horizontal direction.

## Error definitions and results

Invariant drifts are $(I(T)-I(0))/S_I$. For positive inventories, $S_I=I(0)$. For generalized energy, the denominator is the positive scale $S_H=E(0)+|g_0|B_0(0)+|g_d|B_d(0)$, avoiding cancellation in signed $H_g$. Instantaneous rates use the corresponding initial inventory scale and are multiplied by $L_x/u_{\max}$.

State differences use $\sqrt{E(\Delta A)/E(A_{\rm reference})}$. Time comparisons use the 64-step trajectory at the same spatial resolution. Horizontal comparisons use the 24-by-24 trajectory, embed candidate coefficients on its larger Fourier grid, and retain the reference's unresolved contributions in the error. The code verifies that the compared vertical bases are identical. The finest comparison is a reference estimate, not a certified error bound.

| Vertical nodes | APV modes | Physical-energy drift | Generalized-energy drift |
| ---: | ---: | ---: | ---: |
| 17 | 7 | $1.42\times10^{-7}$ | $9.28\times10^{-8}$ |
| 33 | 14 | $3.76\times10^{-10}$ | $2.45\times10^{-10}$ |
| 65 | 27 | $7.91\times10^{-10}$ | $5.17\times10^{-10}$ |
| 129 | 54 | $6.74\times10^{-12}$ | $4.40\times10^{-12}$ |

The errors improve substantially overall but are not strictly monotone at each intermediate vertical resolution. Enstrophy drift stays below $1.1\times10^{-10}$ in this vertical study; endpoint drifts are near roundoff. At fixed spatial resolution the time-refinement state errors are $1.44\times10^{-9}$, $8.97\times10^{-11}$, and $5.28\times10^{-12}$, consistent with fourth-order convergence. The approximately $7.9\times10^{-10}$ energy-drift plateau at 65 nodes is spatial and is not cured by smaller time steps.

Horizontal state errors are $1.36\times10^{-3}$, $2.75\times10^{-5}$, and $1.34\times10^{-6}$ for 8, 12, and 16 points per direction against the 24-point reference. Their energy drifts are all approximately $7.9\times10^{-10}$. This demonstrates that conservation alone does not establish trajectory accuracy.

Instantaneous physical/generalized-energy rates decrease with vertical refinement in both stratifications. At 129 nodes the dimensionless physical-energy rate is $7.17\times10^{-9}$ for constant stratification and $3.23\times10^{-10}$ for exponential stratification. The coarsest constant-stratification enstrophy rate is $1.47\times10^{-8}$ in magnitude; the refined value is $1.11\times10^{-11}$. No claim is made that every coarse configuration already meets a common threshold.

Positive-energy round-trip errors and relative endpoint residuals remain below $9\times10^{-16}$ and $1.1\times10^{-16}$, respectively. Full QGPV is independently compared with horizontal vorticity minus $f\partial_z\eta$; its relative consistency residual improves from $3.28\times10^{-6}$ to $1.04\times10^{-7}$ for constant stratification and from $3.14\times10^{-5}$ to $1.83\times10^{-7}$ for exponential stratification.

Recorded tables: [instantaneous rates and reconstruction residuals](issue-348-rates.csv), [time refinement](issue-348-time.csv), [vertical refinement](issue-348-vertical.csv), and [horizontal refinement](issue-348-horizontal.csv).

## Reproduction and limits

```matlab
results = runtests({'UnitTests/TestFreeSurfaceQGDiagnostics.m', ...
    'UnitTests/TestFreeSurfaceQGConservation.m'});
assertSuccess(results);
% Run separately when regenerating the recorded tables:
study = TestFreeSurfaceQGConservation.runStudy();
```

These controls qualify the stated unforced f-plane problem and diagnostic accounting. They do not establish convergence of the forced seasonal experiment, arbitrary nonlinear states, or longer integrations. #351 supplies problem-specific linear seasonal response estimates; #353 owns staged nonlinear seasonal qualification. Operation/flow-component integration remains #355. Full/exhaustive and released-package suites are not part of this focused verification; dependency pins, package snapshots, and saved experiment trajectories are preserved.

## Verification record

All 78 distinct focused tests passed: seven diagnostic tests, three nonlinear conservation/refinement controls, and 68 existing transform, diffusion, integrator, and seasonal-response tests. The production Code Analyzer gate passed with zero blocking findings; both changed test files have zero findings. Documentation generation and comparison passed with 2,353 files, 4,809 routes, and zero differences. Whitespace and manifest/scope checks passed.

The study used MATLAB R2025b Update 4 in the independent audit checkout. Runtime revisions: InternalModes `9e2edb3eda96191078e22f5d3a8bc785be38143d`, ClassAnnotations `ca212699516e30792bd3e584b7842289c49ca772`, NetCDF `17d00778fdc79284723139f57d3a88fef53f2247`, SplineCore `0ce6950e6328e931fe91797dfd707c24ceac8f6f`, Chebfun `1fe01297a74d9ee765a466c3068b7fb474bee053`, and Distributions `cc0e9fa337de5e308978049c798d5fb6069e05a6`. These dependency checkouts were clean. The implementation builds on WVM `a2b42882` and the MDA reconstruction change `0d842371`; recorded data accompany the invariant-diagnostics commit in PR #365.
