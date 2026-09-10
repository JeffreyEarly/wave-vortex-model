# Candidate weak evolution on the existing free-surface modal span

This note derives a finite-dimensional experiment, not a qualified production model. Its inputs are WVM physics at `81987767956fae5aadcb53a9df16482221f5f3e4`, manuscript `311ebf56` as identified in the planning task, and the constrained-source study in `a043a61af9a3595da1b17e823b2b6bdf5445b17f`. The candidate retains the existing APV, zero-APV, positive/negative wave, inertial, and mean-density-anomaly coefficient families. It does not introduce thermal modes or replace `WVModel`.

The target is the full mapped inviscid Boussinesq equations under the manuscript's selected surface approximation, with modal pressure satisfying $\hat p(0)=\rho_0 g\zeta$. Prescribed atmospheric loading is zero in the first experiment. This is not the unapproximated pressure condition containing $\tilde p_{\rm nm}^{+}(\zeta)$. The corresponding cubic surface-energy correction is omitted consistently. Finite-displacement buoyancy and the moving-domain volume and kinetic-energy factors remain present.

## 1. State, quadrature, and pressure elimination

Use a real coefficient vector $a$ containing independent real/imaginary Fourier degrees of freedom and the real mean degrees of freedom. This avoids hidden factors of two and conjugacy constraints. Work with instantaneous amplitudes at one evaluation time; existing interaction-picture phases can be restored after computing the total coefficient derivative. Let the existing reconstruction matrices be

$$
h=Ua=(\hat u,\hat v,\hat w),\qquad \eta=Ea,\qquad \zeta=Ca,\qquad s=W_s a=\hat w(0).
$$

The velocity trial functions satisfy reference-coordinate divergence and bottom impermeability. These spatial identities do not imply the time-dependent surface condition $C\dot a=s$. The nonlinear mass matrices below couple horizontal Fourier columns; the preceding one-column source study is not an implementation of this evolution system.

Define the geometry and physical velocity by

$$
\alpha=1+\xi/D,\qquad \gamma=1+\zeta/D,\qquad z=\xi+\alpha\zeta,\qquad \beta=\alpha\nabla_H\zeta/\gamma,
$$

$$
u_H=\hat u_H/\gamma,\qquad w=\hat w+\beta\cdot\hat u_H.
$$

After collecting every pressure contribution, write the total mapped tendencies as

$$
\partial_t h=F(a)-M(a)\nabla_\xi\pi,\qquad \partial_t\eta=d(a),\qquad \pi=\hat p/\rho_0,
$$

$$
M=\begin{pmatrix}\gamma I_2&-\gamma\beta\\-\gamma\beta^T&\gamma^{-1}+\gamma|\beta|^2\end{pmatrix},\qquad R=M^{-1}=\begin{pmatrix}\gamma^{-1}I_2+\gamma\beta\beta^T&\gamma\beta\\\gamma\beta^T&\gamma\end{pmatrix}.
$$

Here $F$ is the **total pressure-free momentum tendency**, including Coriolis, full finite-displacement buoyancy, transport, and geometric acceleration. It is not just the nonlinear source residual. Pressure inside $\mathcal H=\partial_t\hat u_H$ in the appendix's vertical equation must be collected into $M$ before forming $F$. A correctly assembled full mapped-RHS evaluator can supply $F$ by setting pressure to zero. Similarly, $d$ includes the linear $\hat w$ contribution to total-displacement evolution.

The positive physical kinetic-energy density is

$$
\frac12\gamma|u|^2=\frac12 h^T R h.
$$

Let $W$ be common overintegrated volume quadrature, $W_3$ its velocity-block version, and $V$ horizontal surface quadrature. Testing mapped momentum with $R U$ gives

$$
U^T W_3 R U\dot a=U^T W_3 R F-U^T W_3\nabla_\xi\pi.
$$

With compatible divergence, gradient, boundary traces, and quadrature, integration by parts gives

$$
U^T W_3\nabla_\xi\pi=W_s^T V\pi(0)=gW_s^T VCa.
$$

Thus interior pressure disappears from this weak equation. The surface pressure contribution remains and has a prescribed value. This is the physical metric identity behind a possible weak formulation; it does not identify the coefficient-space KKT multiplier as pressure.

Before relying on this cancellation, measure the complete discrete operator defect $U^T W_3\nabla_\xi-W_s^TV\operatorname{trace}_0$ on the chosen pressure sample space. Testing only $C\,\mathrm{projectSources}(\nabla\pi)$ is insufficient. Evaluate geometry on a common quadrature grid; truncating $M$ and $R$ separately before multiplying them can destroy $RM=I$.

## 2. Finite-amplitude APE derivatives

Write $\mathscr A(z,\eta)$ for the manuscript's physical-height APE density divided by $\rho_0$, and let $r=z-\eta$ be the no-motion parcel label. On a specified differentiable no-motion reference-density domain,

$$
\mathscr A(z,\eta)=\frac{g\eta\rho_{\rm nm}(r)-p_{\rm nm}(r)+p_{\rm nm}^{+}(z)}{\rho_0},\qquad B=\frac{g}{\rho_0}\left[\rho_{\rm nm}^{+}(z)-\rho_{\rm nm}(r)\right].
$$

Direct differentiation gives

$$
\partial_\eta\mathscr A=\eta N_{\rm nm}^2(r),\qquad \partial_z\mathscr A=-\eta N_{\rm nm}^2(r)-B.
$$

The distinction between the label argument $r$ and the physical-height argument $z$ is essential. In particular, $\partial_\eta\mathscr A$ is not generally $N^2(\xi)\eta$, and it is not simply $-B$. In material coordinates, $D\eta/Dt=Dz/Dt=w$ for adiabatic motion, so these two derivatives yield $D\mathscr A/Dt=-Bw$, as required by buoyancy work.

The selected finite-amplitude energy, per reference density, is

$$
\mathcal E(a)=\int\left[\frac12h^TRh+\gamma\mathscr A(z,\eta)\right]\,dV_\xi+\frac g2\int\zeta^2\,dA.
$$

Define the thermodynamic weight

$$
m_\eta=\gamma N_{\rm nm}^2(r).
$$

This motivates testing the total-displacement equation with $m_\eta E$. It uses the actual APE derivative because $m_\eta\eta=\gamma\partial_\eta\mathscr A$. Positivity requires a suitable monotone reference-density label domain. If the permitted label density has flat intervals, this thermodynamic weight can vanish; positive definiteness of the assembled mass matrix then needs a separate rank check.

Changing $\zeta$ at fixed $h,\eta$ also changes kinetic energy, physical height, and the volume Jacobian. Denote their surface energy derivative by $\Psi$. For periodic horizontal boundaries it is

$$
\Psi=\int_{-D}^0\left[\frac{w\hat w-|u|^2/2}{D}-\nabla_H\cdot(\alpha w\hat u_H)+\frac{\mathscr A}{D}+\gamma\alpha\partial_z\mathscr A\right]d\xi.
$$

The divergence in this expression is the adjoint of the horizontal-gradient variation. For computation, differentiate the actual quadrature energy and use the adjoints of the actual discrete operators; do not assume a sampled continuum product rule is exact. With compatible quadrature and adjoints,

$$
\nabla_a\mathcal E=H(a)a+C^TV\Psi,
$$

$$
H(a)=U^TW_3RU+E^TWm_\eta E+gC^TVC.
$$

$H(a)$ is a state-dependent positive weak mass matrix under the stated rank and stratification assumptions. It is not the Hessian of the nonlinear energy. It includes all balanced-family cross terms. Replacing the full energy gradient by $H(a)a$ would omit the geometry contribution.

## 3. A testable weak mass system

Adding the weighted momentum and displacement equations, and adding the known surface kinematic contribution to both sides, gives the candidate right side

$$
f(a)=U^TW_3RF+E^TWm_\eta d-gW_s^TVCa+gC^TVs.
$$

First compute the unconstrained weak derivative

$$
H(a)v_0=f(a).
$$

This is an energy-weighted Petrov-Galerkin candidate on the existing span. It does not guarantee $Cv_0=s$. At zero geometry, the positive physical pairing also differs from the current generalized-energy source projection for arbitrary truncated sources; adopting it in production would be an explicit projection-contract change, not an invisible implementation optimization. Resolved admissible linear tendencies are the relevant common limit.

Then compute a constrained candidate

$$
\begin{pmatrix}H(a)&K^T\\K&0\end{pmatrix}\begin{pmatrix}v\\\lambda\end{pmatrix}=\begin{pmatrix}f(a)\\b(a)\end{pmatrix}.
$$

For SSH alone, $K$ is an independent representation of $C$ and $b=s$. With active endpoint anomaly coordinates, define

$$
\theta_s=(E_s-C)a=\eta_s-\zeta,\qquad \theta_b=E_ba=\eta_b,
$$

and optionally append their independent reconstruction rows to $K$, with targets

$$
\dot\theta_s=P_H[-u_{H,s}\cdot\nabla_H\theta_s],\qquad \dot\theta_b=P_H[-u_{H,b}\cdot\nabla_H\theta_b].
$$

$P_H$ is the explicitly chosen retained horizontal projection. The nonlinear boundary products contain higher horizontal harmonics, so these are retained boundary equations, not pointwise equality to an untruncated product. For a frozen-reference displacement source, add its endpoint values to the respective targets. Independent surface mass sources are outside this formulation. Use independent real/Fourier constraint rows, rather than treating redundant physical-grid surface samples as independent constraints.

The KKT system is a precise constrained weak approximation. Its constraint force is a finite-dimensional reaction resulting from the chosen tests and trial span. It is not an omitted ordinary pressure gradient: the current continuous dual obeys $C\,\mathrm{projectSources}(\nabla\pi)=0$ for every pressure profile because of the opposite wave SSH polarizations.

To return to the existing reference-time coefficient convention, subtract the known linear phase derivative from $v$ and apply the inverse current phase map. Do not advance exact linear phases a second time. Before evaluating nonlinear cases, feed the analytical linear equations into this system and check the existing exact modal derivative and vanishing constraint reaction.

## 4. An energy-defect identity to measure, not impose

Let $\mathcal W$ be the physical external work associated with the selected equations. It is zero in the first inviscid unforced experiment. For instantaneous prescribed sources with a frozen reference, the volume contributions are

$$
\mathcal W=\int\gamma\left[u\cdot S_{u,\rm physical}+(\partial_\eta\mathscr A)S_\eta\right]dV_\xi.
$$

The density contribution equals the manuscript's $\gamma g\eta S_\rho/\rho_0$ when $S_\eta=-S_\rho/\rho_{\rm nm}'(r)$. A changing sorted reference requires additional reference-evolution terms and is not qualified here. Prescribed atmospheric load, when included consistently, adds its boundary work; it is absent from the first experiment.

Define a directly evaluable continuum/quadrature defect

$$
\mathcal D=a^Tf+\Psi^TVs-\mathcal W.
$$

With exact calculus, the mapped PDE and selected pressure boundary condition give $\mathcal D=0$. With sampled products and quadrature it measures failures of the required calculus identities before any modal solve. It is therefore useful independently of the modal truncation.

The unconstrained weak derivative satisfies the algebraic identity

$$
(\nabla_a\mathcal E)^Tv_0-\mathcal W=\mathcal D+\Psi^TV(Cv_0-s).
$$

The constrained derivative with strong retained SSH kinematics satisfies

$$
(\nabla_a\mathcal E)^Tv-\mathcal W=\mathcal D-(Ka)^T\lambda.
$$

These formulas use the same scaling for $K,b,\lambda$ as the actual KKT system. If constraints are rescaled for conditioning, transform the multipliers consistently. The physical surface quadrature is already included in the definitions of $H,f,\Psi$; $K$ can use any independent equivalent coordinate representation.

For a nonzero linear-solve residual $e=Hv+K^T\lambda-f$ and a nonzero SSH residual, the general identity to check is

$$
(\nabla_a\mathcal E)^Tv-\mathcal W=\mathcal D+\Psi^TV(Cv-s)-(Ka)^T\lambda+a^Te.
$$

The shorter constrained formula assumes both residual terms are negligible; the experiment should record them rather than assume that solver tolerances made them zero.

Thus enforcing kinematics removes one energy-defect term but can introduce reaction work. Endpoint constraints introduce additional components of the same reaction work. Nothing in full row rank or small kinematic residual makes this work vanish. The preceding constant-stratification study already demonstrates this issue for the quadratic source-work budget: satisfying all three boundary source constraints changes the mixed-state work rate and does not eliminate its defect.

The thermodynamic weight $m_\eta$ is justified by the APE derivative, and $R$ by physical kinetic energy. These are not coefficients selected to cancel a measured energy drift. In contrast, appending an energy equation, changing multipliers to force one global power to zero, or rescaling tendencies after each solve would require a separate physical/variational justification. A scalar energy correction alone cannot establish the intended momentum and density equations.

## 5. What can be exact at finite count

The spatial divergence and bottom conditions can be exact properties of the retained span. Independent retained surface and endpoint equations can be enforced to solver precision if the corresponding constraint rows have adequate rank and conditioning. The algebraic energy-defect decomposition above can also be verified to roundoff, given a consistent energy derivative.

The proposed weak/KKT system does **not** generally give an exact nonlinear physical-energy identity at finite count: reaction work and quadrature defects can remain. These are legitimate, measurable defects of an explicitly stated approximation if they decrease under an appropriate simultaneous refinement and the resulting evolution is stable. Decrease is an acceptance requirement to establish, not a consequence already proved by this derivation. Increasing only wave count while fixing balanced and mean-density counts is not a completeness study.

There is no dimensional argument here proving that exact energy conservation is impossible with the same families. A consistently reduced variational or Poisson formulation might achieve it, but it would require deriving the compatible bracket/action, thermodynamic transport, and boundary treatment. That result has not been established by this note. In particular, the current continuous modal dual plus a KKT correction is not such a derivation.

## 6. Reference-domain and small-amplitude qualifications

The manuscript extends the reference density as a constant above physical height zero. It does not thereby authorize arbitrary evaluation of the parcel-label density below the reference bottom. Active bottom modes can produce $r<-D$. A study must either restrict its state and perturbations to a stated reference-density label domain or supply an explicitly chosen physical extension. It must report violations rather than silently extrapolating an interpolant or polynomial.

If labels are restricted to $-D\leq r\leq0$, both inequalities matter. Since $r=\xi-\eta_i$, the pointwise requirement is $\xi\leq\eta_i\leq\xi+D$. Thus the surface requires $0\leq\theta_s\leq D$, and the bottom requires $-D\leq\theta_b\leq0$. A nonzero boundary anomaly with zero horizontal mean necessarily violates one of these sign conditions somewhere, however small its amplitude. Mixed boundary controls therefore need suitable mean offsets, for example from the retained MDA family. Check the full interior and oversampled horizontal/vertical label field, not only endpoint signs.

Choosing instead to extend parcel-label density with $\rho_{\rm nm}^{+}(r)$ changes the derivative domain: the APE must then also use $p_{\rm nm}^{+}(r)$, and $m_\eta=\gamma N_+^2(r)$ can degenerate above zero. That is a separate specification. Do not combine a clipped label density with the unextended label pressure or a nonzero extrapolated label $N^2$.

The upper extension also makes a naive pointwise amplitude test invalid. For a wave at the surface with $\eta_s=\zeta>0$, one has $r_s=0$, $z_s=\zeta$, and $B_s=0$, whereas the formal reference-domain linear buoyancy is $-N^2(0)\eta_s$. Their difference is pointwise $O(\epsilon)$ in a layer of thickness $O(\epsilon)$ near the surface. It need not be uniformly $O(\epsilon^2)$ at the endpoint.

For constant interior $N_0^2$ and valid labels $r\leq0$, the exact formulas illustrate the issue:

$$
\mathscr A=\frac{N_0^2}{2}\left[\eta^2-\max(z,0)^2\right],\qquad B=-N_0^2\left[\eta-\max(z,0)\right].
$$

These formulas apply only on the declared lower label domain. They do not prescribe a below-bottom extension. At the positive wave crest $\eta=z>0$, the APE and buoyancy vanish, while their partial derivatives and the geometry terms still combine correctly along a material displacement.

Use weak/integrated amplitude tests with quadrature that resolves the shrinking layer, or state the distinguished amplitude/resolution limit. A fixed endpoint quadrature weight can turn an unresolved $O(\epsilon)$ endpoint correction into a spurious $O(\epsilon)$ weak residual as amplitude decreases. This is not evidence against the mapped equations. Pressure derivatives can likewise have nonuniform boundary-layer scaling; do not assume every derivative of a nominally second-order pressure correction is uniformly second order.

## 7. Next bounded computation

1. Build a tiny global realified basis, including mean families, from the existing reconstruction. Use a small horizontal grid and two vertical/count resolutions. Keep all endpoint and mean-density degrees needed by the selected state. A single Fourier-column solve cannot represent the nonlinear metric coupling.
2. Prepare deterministic mixed states with $\gamma>0$ and explicitly valid parcel labels. For energy finite differences, keep labels strictly inside the declared density domain or use directions that preserve boundary labels and the appropriate one-sided derivative. Include a case with a resolved positive-surface layer.
3. Evaluate physical geometry, exact $B$, exact $\mathscr A$, pressure-free $F$, and full $d$ on the same quadrature grid. Build $H,f,K,b$ and compute both $v_0$ and the constrained $v$. Record mass conditioning, independent constraint rank, and equation residuals.
4. Check the pressure integration-by-parts matrix independently. Check the analytical energy derivative against directional finite differences of the actual quadrature energy, respecting label admissibility. The kinetic geometry derivative and $\partial_z\mathscr A$ must participate in this check.
5. Record $\mathcal D$, $Cv_0-s$, all selected endpoint residuals, $(Ka)^T\lambda$, and both independently computed energy rates. Verify the two defect decompositions rather than asserting that either energy rate is zero. This distinguishes a calculus implementation error from a constraint-reaction effect.
6. Repeat with increased quadrature and with simultaneous balanced, wave, inertial, and mean-density resolution where relevant. Then use a bounded fixed-step evolution to determine whether reaction work and accumulated energy errors converge, rather than cancelling instantaneously by construction.

This experiment can decide whether the candidate is a useful convergent weak model and identify the next missing discrete identity. It cannot yet qualify a complete nonlinear pressure diagnostic, a conservation-exact time integrator, or arbitrary reference-density extensions.

## 8. Executed instantaneous budget experiment

`runFreeSurfaceWeakBudgetStudy.m` now implements the bounded experiment, with results in `Documentation/Validation/NonlinearFreeSurface/mapped-weak-budget-study.csv`. It uses all six coefficient arrays in a global realified trial basis. The coarse configuration has 86 real coefficients and the refined configuration has 156; both have 26 independent retained surface/endpoint constraints. The same low-mode state, including MDA mean endpoint offsets of +2 m and -2 m, is multiplied by amplitudes 0.25 and 1. The state agrees between resolutions within $2.3\times10^{-15}$ in the common checkpoint norm, rather than being renormalized independently for each retained count.

The declared parcel-label domain is $[-1000,0]$ m. Labels remain strictly inside it on a common 24-by-24-by-257 checkpoint grid. At amplitude 0.25 the sampled bounds are approximately $[-999.525,-0.4502]$ m, and at amplitude 1 they are approximately $[-998.10,-1.8007]$ m. No parcel-label extrapolation or clipping was used. The physical-height density extension above zero and its associated APE correction were retained.

The analytical linear modal derivative is recovered with relative coefficient error below $1.1\times10^{-14}$. The full energy gradient agrees with directional finite differences to approximately $4.4\times10^{-12}$ or better when taking the best of steps $10^{-4}$, $10^{-5}$, and $10^{-6}$; the CSV retains each step's error as well. Both energy-defect decompositions agree with independently contracted energy rates within about $7.1\times10^{-17}$ in the experiment's power units. These are checks of the implemented algebra, not assertions that the physical energy rate vanishes.

At amplitude 1, increasing vertical quadrature from 65 to 129 nodes and simultaneously increasing APV/wave/MDA/inertial counts from 2/3/2/2 to 4/6/4/4 reduces constraint reaction work from approximately $4.780\times10^{-6}$ to $5.987\times10^{-8}$, an approximately 80-fold reduction. This is joint vertical/count refinement at a fixed 4-by-4 retained horizontal grid. The grid energy defect is approximately $10^{-10}$ to $10^{-11}$, so reaction work dominates the constrained instantaneous energy rate in these cases. Increasing horizontal quadrature from 8 to 12 points per direction at fixed retained modes leaves the reaction work essentially unchanged. This is bounded instantaneous refinement evidence; it does not establish full-PDE convergence, a convergence rate, or an integrated trajectory.

SSH and retained endpoint-rate residuals are below approximately $8\times10^{-17}$ m/s. The unprojected boundary advection contains higher horizontal harmonics: its discarded target RMS is approximately $1.74\times10^{-6}$ m/s at amplitude 1 and $1.09\times10^{-7}$ m/s at amplitude 0.25. These values are unchanged by the vertical/count refinement because the retained horizontal band is fixed. The CSV distinguishes these discarded harmonics from residuals in the retained equations.

Pressure integration by parts is also qualified by the tested pressure space. The relative full collocation operator defect decreases from approximately $4.50\times10^{-5}$ to $1.38\times10^{-5}$ and is not roundoff. On a fixed smooth pressure test space of degree-eight vertical polynomials and the retained basic horizontal harmonics, the defect is below $3.7\times10^{-15}$. Exact resolved linear recovery therefore must not be presented as proof of pressure cancellation for every collocation pressure profile.

The helper records single observed construction, basis setup, mapped-RHS evaluation, mass/RHS assembly, and two-solve timings. In this run, construction took 2.59–3.14 s and basis setup 0.56–0.81 s per configuration. Mapped-RHS evaluation took 2.57–5.34 ms, combined mass/RHS assembly 6.47–24.09 ms, and the two dense weak solves 0.23–0.40 ms per evaluated state. These observations include warm-up and diagnostic overhead and are not a separate performance benchmark. These instantaneous measurements alone do not qualify a trajectory, nonlinear pressure recovery, broad arbitrary stratification, or exact finite-dimensional energy conservation. The following section records a separate short-trajectory control.

## 9. Executed 200-second interaction-picture controls

`runFreeSurfaceWeakTrajectoryStudy.m` uses the same weak/KKT formulation, plus reference, linear surface-pressure approximation, seed, and admissible label domain. Shared basis, physical geometry, energy, and constraint routines now reside in the study-local `freeSurfaceWeakStudyHelpers.m`; no production API or `WVModel` path is activated. Its initial weak energy rates agree with the reviewed instantaneous CSV within approximately $9\times10^{-16}$ relative error (`initialEnergyRateRelativeDifference`). This scalar check establishes initial energy-budget agreement, not full RHS agreement. The extracted instantaneous driver still uses the same routines.

The analytical linear reconstruction defines a generator $L$ in whitened real coefficient coordinates. The driver uses $a=\exp(Lt)A$ and advances $A'=\exp(-Lt)[v(a)-La]$ by RK4. A separate linear control supplies the independently assembled linear weak equations rather than a zero RHS; it leaves $A$ unchanged within $7.7\times10^{-15}$ over 200 s. The numerical phase-group defect is below $9\times10^{-16}$.

For each of the coarse and refined vertical/family configurations, trajectories use steps 10, 5, and 2.5 s on the fixed 4-by-4 retained horizontal grid with 8-by-8 horizontal quadrature. At every nonlinear RK stage the driver checks labels on both the quadrature grid and the common dense checkpoint grid, evaluates retained kinematics and divergence on the quadrature samples, and accumulates grid, reaction, solver, and SSH-geometry work using the same RK4 weights. Summary results are in `mapped-weak-trajectory-study.csv`; per-step direct energy and accumulated budgets are in `mapped-weak-trajectory-history.csv` under `Documentation/Validation/NonlinearFreeSurface`.

At the 2.5 s step, coarse energy increases by approximately $1.75385\times10^{-4}$, while integrated reaction work is $1.75391\times10^{-4}$ and the accumulated budget residual is $4.81\times10^{-10}$. The refined energy increase is approximately $3.16877\times10^{-6}$, with reaction work $3.16629\times10^{-6}$ and budget residual $5.34\times10^{-12}$. The grid-work contributions are approximately $-6.87\times10^{-9}$ and $2.47\times10^{-9}$, respectively. Thus the energy change is predominantly the measured constraint reaction, rather than unexplained conservation drift, for these controls.

The final interaction-coefficient differences between the 10/5 s trajectories and the 2.5 s trajectory are at most $5.7\times10^{-11}$ relative to the latter. These three steps do **not** give clean fourth-order ratios; the coarse energy-budget residual is also not monotone in step size. No RK4-order qualification follows from small absolute differences, and no wider timestep trial was added to improve their appearance. The norm of the finest-step coarse/refined final-state difference is approximately $9.31\times10^{-4}$ on the common checkpoint grid, using the full reference quadratic state norm, including SSH. This compares two truncations rather than providing an exact-solution error estimate.

All stage labels remain admissible, approximately between $-998.1001$ and $-1.8007$ m. Maximum stage divergence is below $5.5\times10^{-16}$ s$^{-1}$, retained SSH-rate residual below $1.3\times10^{-17}$ m/s, and retained endpoint-rate residual below $5.8\times10^{-17}$ m/s. Unrepresented boundary harmonics remain: their maximum discarded target RMS is approximately $1.82\times10^{-6}$ m/s. No enlarged retained horizontal band was run. The numerical budget identity holds at stages within approximately $2.2\times10^{-16}$ in the power units used here.

The six diagnostic trajectories took approximately 0.58–2.98 s each after setup on this host; these are single observed timings, including diagnostics, not a benchmark. The qualification is limited to these short, small-grid, constant-stratification trajectories with the stated reference-domain offsets. It does not establish long-time stability, full-PDE convergence, arbitrary endpoint distributions, or a deployable nonlinear model.

## 10. Executed material-label and APV budgets

A separate follow-up reruns only the two existing 2.5 s trajectories. `mapped-weak-material-budget-study.csv` contains their initial/final moments, absolute changes, noncancelling initial scales, and maximum observed absolute changes; `mapped-weak-material-budget-history.csv` records all 160 accepted steps. The earlier six-case timestep CSV/history are preserved. The driver supports selecting timesteps and output prefixes; the one-step-size follow-up's zero self-comparison timestep error is not new timestep-accuracy evidence.

With $r=z-\eta=\xi-\eta_i$, the diagnostic computes physical velocity from the mapped state and uses

$$
D_x=\partial_x|_\xi-\beta_x\partial_\xi,\qquad D_y=\partial_y|_\xi-\beta_y\partial_\xi,\qquad D_z=\gamma^{-1}\partial_\xi,\qquad q=(\operatorname{curl}_{\rm physical}u+f e_z)\cdot\nabla_{\rm physical}r-f.
$$

It measures $\int\gamma$, $\int\gamma r$, $\int\gamma r^2$, $\int\gamma q$, and $\int\gamma q^2$ using the same quadrature as the energy. Horizontal integration is an area average, so the respective units are m, m$^2$, m$^3$, m/s, and m/s$^2$. The noncancelling scale for a signed first moment is the initial integral of its absolute integrand, and the positive second moments use their initial values. These diagnostics apply no correction to the state or equations. Labels remain checked at every RK stage; material/APV moments are measured at accepted steps.

| Moment | Coarse absolute change at 200 s | Refined absolute change at 200 s | Coarse scaled change | Refined scaled change |
| --- | ---: | ---: | ---: | ---: |
| Volume | $1.02\times10^{-12}$ | $5.68\times10^{-13}$ | $1.02\times10^{-15}$ | $5.68\times10^{-16}$ |
| First label moment | $4.1344$ | $0.017531$ | $8.27\times10^{-6}$ | $3.51\times10^{-8}$ |
| Second label moment | $4174.2$ | $2.6178$ | $1.25\times10^{-5}$ | $7.86\times10^{-9}$ |
| First APV moment | $1.43\times10^{-11}$ | $5.28\times10^{-12}$ | $2.08\times10^{-8}$ | $7.69\times10^{-9}$ |
| Second APV moment | $1.98\times10^{-13}$ | $4.21\times10^{-14}$ | $2.78\times10^{-4}$ | $5.93\times10^{-5}$ |

Final defects improve under this joint vertical/count refinement at fixed horizontal bandwidth. Final-time cancellation matters: maximum absolute first/second label moment changes are $7.46$/$7479$ in the coarse trajectory and $0.0175$/$12.11$ in the refined trajectory. Maximum second APV moment changes are $4.84\times10^{-13}$ and $1.65\times10^{-13}$, respectively. The budgets are therefore not established as exact finite-dimensional invariants. These two truncations do not establish a convergence rate, isolate horizontal truncation error, or qualify general material/APV conservation. Tight retained endpoint constraints and successful energy-work accounting are insufficient to establish those properties.

`mapped-weak-material-budget-controls.csv` records flat inertial controls with horizontally uniform, vertically sheared velocity and zero displacement, for which $q=0$. An additional flat polynomial displacement $\eta=a\alpha(1-\alpha)$ with $a=2$ m has the analytic $q=-fa(1-2\alpha)/D$ and analytically integrable label/APV moments. The maximum pointwise APV error divided by $|f|$ is $1.63\times10^{-11}$; analytic moment errors in the stated natural units are below $5.8\times10^{-15}$. These controls check the diagnostic formula and vertical derivatives; they are not a manufactured nonflat APV convergence study. The two diagnostic trajectories took approximately 1.71 and 3.15 s after setup, including the new accepted-step diagnostics.

## Source map and verification ledger

The manuscript anchors are `eq:projection-ready-map-wi`, `eq:projection-ready-geometric-identities`, `eq:projection-ready-horizontal-momentum-tendency`, `eq:projection-ready-exact-vertical-momentum`, `eq:projection-ready-displacement-advection`, `eq:rho-nm-plus-definition`, `eq:physical-height-ape-density`, `eq:available-energy`, and `eq:projection-ready-surface-pressure`. The code anchors are `reconstructSpectralState.m`, `projectSources.m`, `physicalEnergy.m`, and `freeSurfaceWavePolarization.m` in the free-surface Boussinesq implementation.

The source/KKT feasibility study, instantaneous weak-budget experiment, and 200-second trajectory controls were executed with their CSV outputs. The weak helpers use the independently authored mapping and full-tendency helpers from commits `43ed50ef` and `74569724`. The trajectory control also checks agreement with the committed instantaneous energy-rate baseline after helper extraction. The material/APV follow-up ran only the two finest-step trajectories and four analytic controls. MATLAB Code Analyzer and whitespace/scope checks passed for the final study sources. Only diagnostic helpers, this note, and validation CSV files are authored in this workstream. No production evolution API or generated website source was changed. The stated instantaneous and short-trajectory controls are the current qualification boundary.

An independent review checked the weak-budget algebra and sharpened the two-sided label-domain conditions and solver-residual accounting above. This review is not numerical qualification of the proposed model.
