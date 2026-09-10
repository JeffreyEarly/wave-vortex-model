# Matrix-free full-reference trajectory review

`runMatrixFreeNonlinearTrajectoryStudy.m` runs the composed full C1 stage for 200 s with steps 10, 5, and 2.5 s. The two executed configurations use 8-by-8 horizontal samples with the transform's retained antialiased band, 65/129 vertical samples, APV/MDA/inertial counts 2/4, and wave counts 3/6. Thus refinement changes both vertical quadrature and retained vertical families at fixed horizontal bandwidth. The optional larger horizontal configuration was not run. These full-surface-reference equations differ from the earlier `mapped-weak-*` approximate-surface trajectories, whose evidence remains unchanged.

## Independent algebra and clock review

The physical energy derivative differentiates the reconstructed hatted fields through the moving-volume map, including $\dot\gamma$, both slope derivatives in physical $\dot w$, total-displacement APE derivatives, and the full surface energy derivative $\pi_s\dot\zeta$. For the unforced weak system $Hv+K^*\lambda=r$, let $J=g\zeta-\pi_s$, let $\Psi$ be the volume geometry gradient, and set $s=\hat w_s$. The independently assembled energy-production defect is

$$
D_{\rm grid}=a^*r+\langle(\Psi-J)s\rangle.
$$

It uses the RHS covector and state geometry, not the solved rate. With $e=Hv+K^*\lambda-r$, the complete finite-solve accounting is

$$
\dot E=D_{\rm grid}-(Ka)^*\lambda+a^*e+\langle(\Psi-J)(Cv-s)\rangle.
$$

The final script records the actual energy contribution `reactionWork=-(Ka)'*lambda`, separate solver work $a^*e$, and separate SSH-geometry residual work. The original uncommitted draft called the opposite-signed pairing “reaction work” and compensated with a plus sign in its residual; that draft's arithmetic was correct, but the final naming/sign convention now matches energy contributions directly. `energyBudgetResidual` is direct energy change minus the integral of all four terms. `quadratureDefect` is the existing column name for $D_{\rm grid}$; it is the weak spatial energy-production defect and should not be interpreted as an isolated quadrature-error estimate.

RK4 advances the canonical reference-time coefficients using the stage's $v-La$. Every stage sets the current $t$, while $t_0=-17$ s remains fixed during each run. Consequently reconstruction's analytical phases and the returned nonlinear coefficient rate together give the full field evolution. Final reconstructions occur at the common final time. No extra phase is applied to the integrated coefficients.

The comparison vector samples hatted velocity, total displacement, and SSH on a common 24-by-24-by-257 grid, with fixed positive trapezoidal vertical weights, $N^2$ displacement weight, and $g$ SSH weight. It is a fixed reference quadratic norm, not the state-dependent nonlinear physical kinetic metric. `relativeFinalStatePreviousStepDifference` compares successive requested steps; `relativeFinalStateFinestStepDifference` compares every step with 2.5 s. Resolution differences use the finer configuration in the denominator. Initial coarse/refined comparison is $2.19\times10^{-15}$, supporting a fixed physical initial-state comparison.

## Executed trajectory evidence

The six cases in `matrix-free-full-reference-summary.csv` and 286 accepted-time rows (including initial values) in `matrix-free-full-reference-history.csv` include the new work and material diagnostics. The trajectory equations and final-state comparisons match the original draft outputs; only diagnostics and the explicit reaction-work sign convention changed.

| Configuration | Step (s) | Energy change | Accumulated energy-budget residual | Relative final-state difference from 2.5 s |
| --- | ---: | ---: | ---: | ---: |
| Coarse | 10 | $1.9970175\times10^{-3}$ | $1.14682\times10^{-10}$ | $4.90855\times10^{-10}$ |
| Coarse | 5 | $1.9970174\times10^{-3}$ | $5.23617\times10^{-12}$ | $2.88470\times10^{-11}$ |
| Coarse | 2.5 | $1.9970174\times10^{-3}$ | $2.09177\times10^{-13}$ | 0 |
| Vertical/count refinement | 10 | $7.2857839\times10^{-6}$ | $1.14595\times10^{-10}$ | $4.90909\times10^{-10}$ |
| Vertical/count refinement | 5 | $7.2856746\times10^{-6}$ | $5.22721\times10^{-12}$ | $2.88501\times10^{-11}$ |
| Vertical/count refinement | 2.5 | $7.2856695\times10^{-6}$ | $1.82993\times10^{-13}$ | 0 |

Successive-step state differences have a ratio approximately 16, consistent with fourth-order behavior over this bounded test. The finest-step coarse/refined state difference is $1.01662\times10^{-3}$ in the fixed norm; it is not an exact-solution error estimate. Energy growth is overwhelmingly accounted for by constraint reaction work. At 2.5 s, integrated solver work is approximately $-5.90\times10^{-13}$ coarse and $1.47\times10^{-13}$ refined, while integrated grid defect is approximately $-10^{-14}$ and SSH-geometry work is below $1.2\times10^{-19}$. The independently reconstructed instantaneous budget identity residual stays below $2.20\times10^{-16}$.

Every observed stage uses at most four projected-CG iterations; maximum stationarity residual is $1.26\times10^{-12}$ and the packed retained-constraint residual norm is below $3.71\times10^{-18}$. Discarded boundary target RMS remains approximately $2.54\times10^{-8}$ m/s. Stored-grid stage labels remain between approximately $-998.0964$ and $-1.8007$ m, so no endpoint roundoff canonicalization is active. No oversampled trajectory label-domain certification is claimed here.

## Material-label and APV budgets

The accepted-step diagnostics reuse the independently checked physical material/APV helper. It evaluates $r=z-\eta$ and $q=(\operatorname{curl}_{\rm physical}u+fe_z)\cdot\nabla_{\rm physical}r-f$, with $D_x=\partial_x|_\xi-\beta_x\partial_\xi$, $D_y=\partial_y|_\xi-\beta_y\partial_\xi$, and $D_z=\gamma^{-1}\partial_\xi$. These definitions do not change with the hydrostatic pressure-reference convention. Moments are volume, $\int\gamma r$, $\int\gamma r^2$, $\int\gamma q$, and $\int\gamma q^2$, using horizontal area averages. Their units are respectively m, m$^2$, m$^3$, m/s, and m/s$^2$. Positive scales use initial integrals of absolute integrands for signed moments and initial second moments otherwise. No state or budget correction is applied.

| Moment | Coarse absolute change at 2.5 s step | Refined absolute change | Coarse scaled change | Refined scaled change |
| --- | ---: | ---: | ---: | ---: |
| Volume | $4.55\times10^{-13}$ | $1.25\times10^{-12}$ | $4.55\times10^{-16}$ | $1.25\times10^{-15}$ |
| First label moment | 0.636186 | 0.387905 | $1.27325\times10^{-6}$ | $7.76347\times10^{-7}$ |
| Second label moment | 10680.7 | 415.329 | $3.21015\times10^{-5}$ | $1.24830\times10^{-6}$ |
| First APV moment | $2.19608\times10^{-11}$ | $2.37027\times10^{-12}$ | $4.21040\times10^{-8}$ | $4.54446\times10^{-9}$ |
| Second APV moment | $8.15869\times10^{-12}$ | $3.19717\times10^{-15}$ | $1.98045\times10^{-2}$ | $7.76083\times10^{-6}$ |

The coarse second-APV moment drifts by approximately 1.98%, despite tight energy-work and solver identities. Vertical/count refinement improves it substantially, but does not establish exact APV conservation. First-label improvement is modest, and final-time cancellation matters: its maximum coarse absolute change is 3.80589, compared with its final 0.636186. Maximum coarse second-label change is 10925.3. The CSVs retain both final and maximum observed changes. These diagnostics demonstrate unresolved material-conservation defects rather than qualifying exact invariants or a general convergence rate.

## Verification and scope

The author supplied the initial script and energy-only CSVs; this independent review retained the equations, added material/APV moments and missing finite-solve work terms, clarified sign and comparison conventions, and reran only the six existing cases. Existing APV analytic controls were not repeated because the reused helper was unchanged. Code Analyzer initially identified a shared nested-loop index; renaming the outer diagnostic indices removed those warnings without changing numerical outputs. The final Analyzer and whitespace/scope checks passed. Construction took approximately 4.82–4.98 s per configuration; trajectories with the added diagnostics took 3.62–14.43 s each after setup. These are single observations, not a benchmark suite. No core source, runtime class, or earlier approximate-study artifacts were modified. No physical-pressure, long-time, arbitrary-stratification, or exact nonlinear conservation qualification follows from this bounded study.
