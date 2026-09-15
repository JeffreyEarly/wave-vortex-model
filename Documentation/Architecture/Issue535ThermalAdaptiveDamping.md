# Native thermal adaptive damping (#535)

This opt-in route in `WVAdaptiveDamping` constructs a complete energy/generalized-enstrophy coordinate system within the represented thermal pressure space. It reuses the adaptive horizontal law and ordinal SVV taper. It does not fit a truncated APV basis. The existing `WVThermalAPVDamping` class and historical files retain their meaning.

## Public use and ownership

```matlab
w = WVTransformFreeSurfaceThermalQG.fromStratification( ...
    [1e5 1e5 1000],[8 8 129], ...
    N2Function=@(z)1e-4*exp(2*z/1300), ...
    thermalModeCount=17,mdaModeCount=2,kappa_z=1e-5);
damping = WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w);
w.addForcing(WVNonlinearAdvection(w));
w.addForcing(damping);
model = WVModel(w);
model.setupIntegrator(integratorType="exponential",maximumStep=450);
model.integrateToTime(3600,shouldShowIntegrationDiagnostics=false);
```

The factory accepts `generalizedEnstrophyCutoffFraction=NaN` and `boundaryWeightMultiplier=1`. A positive finite common multiplier controls both endpoint weights. The default cutoff uses the existing ordinal rule. The ordinary constructor accepts authoritative `thermalGeneralizedEnstrophyState` for inexpensive restoration; direct thermal construction without this state directs callers to the factory. APV and thermal cutoff options are mutually exclusive. Changing the thermal cutoff rebuilds application data, with no new quadrature or eigensolution.

The transform owns physical diffusivity and its diagonal diffusion generator. The optional forcing owns the closure. Its cached rates are per unit horizontal speed; the supplied stage `physicalState.uvMax` multiplies them once. Direct forcing evaluation falls back to the owning transform's speed. Zero diffusivity does not turn off the closure; zero speed does. The mean `Amda` remains unchanged. The closure is explicit in the exponential integrator because it does not share the thermal diffusion eigenbasis. Portable runtime export remains unavailable for this route.

## Physical factors and complete coordinates

For each positive horizontal radius, use the existing real Legendre pressure polynomials in the physical WKB coordinate. Let `a` be the polynomial pressure coefficients, `psi` pressure divided by Coriolis parameter, `eta` total displacement, `zeta` surface displacement, and `q` QGPV. Use all represented directions, including both active endpoint anomalies. At physical quadrature nodes with depth weights `w`,

\[
F_E=\begin{bmatrix}\sqrt w\,k_h\psi\\\sqrt{wN^2}\,\eta\\\sqrt g\,\zeta\end{bmatrix},\qquad
F_G=\begin{bmatrix}\sqrt w\,q\\\sqrt{\alpha_0}\,\eta_i(0)\\\sqrt{\alpha_d}\,\eta_i(-D)\end{bmatrix}.
\]

Energy uses **total** displacement and positive free-surface energy. The endpoint terms use `eta_i(0)=eta(0)-zeta` and `eta_i(-D)=eta(-D)`. In particular, interior buoyancy and total displacement cannot be substituted for one another in the energy form.

\[
E=\tfrac12a^\dagger M a,\quad M=F_E^\dagger F_E,\qquad
G=Z+\alpha_0 B_0+\alpha_d B_d=\tfrac12a^\dagger H a,\quad H=F_G^\dagger F_G.
\]

The default weights are

\[
\alpha_0=\alpha_d=m f^2/b_{\rm eff},\qquad
b_{\rm eff}=\frac{(\int_{-D}^0 N\,dz)^2}{4\int_{-D}^0N^2\,dz}.
\]

For constant stratification `b_eff=D/4`. For `N^2=N20*exp(2*a*z)`, it is `tanh(a*D/2)/(2*a)`, evaluated with its continuous zero-scale limit. Weights have units `m^-1 s^-2`; generalized eigenvalues have units `m^-2`. Both weights must be finite and positive; zero Coriolis parameter is invalid.

Do not form Gram matrices to solve the generalized eigenproblem. Instead compute

\[
F_E=QR,\quad F_G/R=U\Sigma W^\dagger,\quad
V=R^{-1}W,\quad P=W^\dagger R,\quad \lambda_j=\sigma_j^2.
\]

Sort ascending and retain all directions. Then `PV=I`, `V'*M*V=I`, `V'*H*V=diag(lambda)`, and `c=P*a`. Full polynomial-coordinate `V` and `P` are authoritative arrays. Temporary physical fields are assembled and released one radius at a time. Construction must not populate the whole diagnostic cache described in #530, or invoke another pressure/mode solver.

## Numerical construction contract

Start with `Q=max(w.assemblyQuadratureCount,2*n+1)` and compare with `2*Q`, retaining the fine construction. Compare forms/operators in common native polynomial coordinates normalized by physical energy. The relative gate is `1e-8`. Do not compare individual eigenvectors across quadratures, since signs and repeated-subspace rotations are arbitrary. An unresolved construction fails explicitly; it does not refine without a bound or delete poorly conditioned directions.

Estimate singular-value uncertainty in **singular-value units**. For `A=F_G/R`, use factor reconstruction, orthogonality, two-sided singular residuals, dimension-dependent roundoff and measured coarse/fine drift:

\[
\gamma=\frac{(n_{\rm row}+n)\epsilon}{1-(n_{\rm row}+n)\epsilon},\quad
e_{\rm fac}=\|A-U\Sigma W^\dagger\|_2+\|A\|_2(\|U^\dagger U-I\|_2+\|W^\dagger W-I\|_2+\gamma),
\]
\[
e_j=\max\left(e_{\rm fac},\frac{\sqrt{\|Aw_j-\sigma_j u_j\|_2^2+\|A^\dagger u_j-\sigma_j w_j\|_2^2}}{\sqrt2}\right)+|\sigma_j^{\rm fine}-\sigma_j^{\rm coarse}|.
\]

These are reported numerical uncertainty estimates, not rigorous interval-arithmetic bounds. Intervals `[sigma_j-e_j,sigma_j+e_j]` must exclude zero. Merge connected overlaps. Reject a merged cluster `a:b` with `(lambda_b-lambda_a)/lambda_b>1e-8`. Store the original eigenvalues unchanged, the uncertainty estimates and cluster upper ordinals. A threshold proportional to `eps*norm(H)` would square the conditioning and is deliberately unsuitable here.

## Shared SVV and exact application

The existing horizontal law is unchanged:

\[
r_h=\frac{U\Delta}{\pi^2}k_h^2Q_h,\qquad k_{h,\max}=\pi/\Delta.
\]

Use the same scalar SVV implementation and cutoff logic for every supported transform. In the thermal generalized spectrum the coordinate is ordinal `j=1:n`. Its default cutoff is `j_c=n^(3/4)`; an explicit fraction uses `j_c=fraction*n`. The taper is zero for `j<=j_c`, and otherwise

\[
Q_j=\exp\left[-\left(\frac{j-n}{j-j_c}\right)^2\right],\qquad
r_{G,j}=\frac{U}{\Delta}\frac{\lambda_j}{\lambda_n}Q_j.
\]

The necessary thermal change is the positive generalized spectrum in place of inverse APV deformation radius squared. It includes horizontal and endpoint effects. It is not a relabeling of independently truncated APV modes.

Assign a **common entire rate** to every cluster `a:b`, using `(U/Delta)*(lambda_b/lambda_n)*Q_b`. Equalizing only the taper would not give rotation invariance. A cluster crossing the cutoff is wholly active. Record nominal cutoff, effective last zero ordinal, active count and actual smallest active eigenvalue. The maximum selective rate remains `U/Delta`. No eigenvalues or prescribed nonzero rates are clipped.

For active directions `J`, the selective tendency is `-V_J*(unitRates.*(P_J*a))*U`. Map both factors into thermal coefficient coordinates once. Use the exact dense selective matrix when `2*numel(J)>=n`; otherwise retain factors. This deterministic work-count rule avoids runtime timing and does not approximate the operator. As in the shared legacy filter, ordinary floating-point exponential underflow can make the first few values above the nominal onset exactly zero; the reported effective cutoff and active count describe the computed rates. Add the scalar horizontal action once. The explicit bound is `U*max(r_h_unit+r_G_unit)` over all radii and directions.

Process accounting records `adaptive damping: horizontal` and `adaptive damping: generalized enstrophy` separately. Existing APV and historical thermal labels remain unchanged.

## Guarantees and diagnostics

For nonnegative rates,

\[
\dot E_G=-\sum_jr_{G,j}|c_j|^2\le0,\qquad
\dot G_G=-\sum_jr_{G,j}\lambda_j|c_j|^2\le0,
\qquad -\dot E_G\le\frac{-\dot G_G}{\min_{j:r_{G,j}>0}\lambda_j}.
\]

The selectivity bound applies to the selective contribution. Horizontal damping is separately dissipative in both forms. Independent interior enstrophy and endpoint variances can increase under the selective operator. Report each signed power and the largest eigenvalue of its Hermitian power matrix normalized by positive total energy (`growth/(2E)`), never divided by the potentially vanishing combined-enstrophy loss. Verify the actual mapped floating-point operator as well as the analytic native-coordinate identities.

## State, restoration and transfer

`WVInternal.ThermalGeneralizedEnstrophyState < CAAnnotatedClass` is immutable scientific state. It stores schema/dimensions; domain/profile/gravity/Coriolis/latitude identity; polynomial order, radii and endpoints; weights and effective depth; construction counts/residuals/conditions/uncertainties; full real polynomial eigenvectors and duals; eigenvalues and cluster metadata. The canonical constructor validates arrays directly and performs no scientific construction. Transient application pages belong to the outer forcing.

Outer required properties are `apvCutoffFraction`, `generalizedEnstrophyCutoffFraction`, and `thermalGeneralizedEnstrophyState`. Missing new properties in historical groups use constructor defaults. New nonthermal records persist the nested state as a typed empty annotated array. Do not migrate `WVThermalAPVDamping` files.

Coefficient values, time and diffusivity do not invalidate the closure. Cutoff and effective grid spacing rebuild only rates/application. A compatible change of coefficient basis remaps the stored polynomial arrays. Changed weights require a new factory call. `forcingWithResolutionOfTransform` reuses canonical state for identical physical space/order/radii, reconstructs it for compatible order or radius changes, and rejects changed domain/profile/gravity/latitude/endpoints. `withDiffusivity` continues not to copy forcings; callers can transfer the forcing explicitly.

## Bounded qualification and completion

The new focused test class includes three synthetic smoke methods without thermal provider construction and four full methods with small constant/exponential fixtures. Independent polynomial/exponential integrals establish physical normalization. Algebra/application gates are `1e-10` for small normalized cases and `1e-8` for scientific construction; independent-reference error must fit within one fifth of the relevant allowance. Tests cover complete spectra, clusters, all-state signs, selectivity, shared SVV, exact application, caches, stage speed, process sums, model decay and annotated continuation with scientific construction disabled. Adaptive single-direction decay is rational, `c0/(1+unitRate*U0*t)`, since speed varies with amplitude. A frozen-speed exponential is a separate test.

The explicitly invoked authoring driver uses 8-by-8-by-129 grids, a 100 km square domain of depth 1000 m, constant `N2=1e-4` and exponential `N2=1e-4*exp(2*z/1300)`, and thermal counts 17/33. Populate common low-degree pressure and degrees 14–15 at nonparallel Fourier modes; normalize once below 0.01 m/s and 1% depth endpoint displacement. Compare no closure, horizontal only and the new closure over 12 unforced nonlinear hours at `kappa_z=1e-5`, with maximum steps 450 and 225 s. Report separate signed powers/budgets, large-scale change and timestep consequences. Common weight multipliers 0.1/1/10 are a bounded sensitivity check, not optimization.

For a comparison holding the closure fixed, freeze horizontal spacing/filter and interpolate the reference final clustered unit rates against its unique eigenvalues, including `(0,0)`. Above the reference maximum, extend `lambda/(Delta_ref*lambdaMax_ref)`. Evaluate this scalar function on the target's complete generalized spectrum without applying target ordinal cutoff or cluster flattening. Rates may then exceed `U/Delta_ref`; use the actual bound. Compare common Fourier support at prescribed equal speed. This is an authoring-only comparison, distinct from public resolution transfer, which deliberately retunes the closure.

The cost target on this Mac is 64-by-64-by-385, thermal count 257, mean count 4, assembly count 2057 and product count 769; domain 500 km square/depth 4000 m, latitude 24 degrees, `N2=(5.2e-3)^2*exp(2*z/1300)`, and four compute threads. Fresh serial processes have an external 12 GiB/900 s guard. Record cold construction, canonical/cache bytes, ranks, 5 warmups/21 application samples, 10 paired complete RHS samples, and 3 short integration repetitions. The 10% warm RHS overhead target is advisory; do not alter the law to meet it. Report integration overhead separately because the explicit cap can change stage/step counts.

Correct opt-in behavior plus honest bounded measurements can complete #535 even when cost or physical results are unfavorable. Mathematical or lifecycle failures must be fixed. This work does not establish campaign readiness or optimize the closure. Authoring outputs and verification ledgers go to a caller-selected directory outside the checkout. Record execution findings and remaining decisions in issue #535 and its pull request, following the repository artifact policy.
