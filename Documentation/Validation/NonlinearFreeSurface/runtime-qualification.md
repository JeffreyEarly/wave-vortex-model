# Nonlinear free-surface Boussinesq beta contract

This increment implements the full mapped, inviscid Boussinesq equations as a constrained weak evolution on the existing resolved adiabatic span. It adds no thermal modes or class hierarchy. The implementation baseline is WVM `81987767956fae5aadcb53a9df16482221f5f3e4`, the declared InternalModes `2.0.0-beta.4` export, and the free-surface manuscript `311ebf56c13c30ab4cac423ef7260d3bd693e939`.

The manuscript is *A unified theory for geostrophic and gravity-wave dynamics of the ocean surface and interior*, [Overleaf](https://www.overleaf.com/project/6317e19111f4547c06f405b1). The equation mapping below uses its `appendix:projection-read-eom`, `eq:projection-ready-map-wi`, `eq:projection-ready-geometric-identities`, `eq:projection-ready-horizontal-momentum-tendency`, `eq:projection-ready-exact-vertical-momentum`, and `eq:projection-ready-potential-density-evolution` labels. The manuscript itself is unchanged.

## Equation-to-code contract

| Quantity or equation | Implementation and meaning |
| --- | --- |
| $z=\xi+\alpha\zeta$, $\alpha=1+\xi/D$, $\gamma=1+\zeta/D$ | `freeSurfacePhysicalFields`; `z` remains the one-dimensional reference samples and `z_physical` is the moving mesh, in meters |
| $u_H=\hat u_H/\gamma$, $w=\hat w+\alpha u_H\cdot\nabla_H\zeta$ | `u/v/w` physical velocity; explicit `u_hat/v_hat/w_hat` modal variables, all m/s |
| $\eta_i=\eta-\alpha\zeta$, $r=\xi-\eta_i=z-\eta$ | Total displacement `eta`, interior displacement `eta_i`, unchanged physical parcel density $\rho_{\rm nm}(r)$; density is not inferred from a universal `N2*eta_i` formula |
| $w_i=(\hat w-\alpha\hat w_s)/\gamma$ | Material reference-coordinate rate used for a tracer on the reference grid |
| $\partial_z=\gamma^{-1}D_\xi$, $\partial_x|_z=D_x-\alpha\zeta_x\gamma^{-1}D_\xi$ | `diffZ` differentiates reference depth, already including the WKB sampling metric; `diffX/diffY` hold reference depth fixed |
| Full mapped momentum and displacement tendencies | `freeSurfaceMappedTendency` retains geometric acceleration terms, including horizontal pressure acceleration inside the vertical equation |
| Physical pressure | `freeSurfacePressureSolver` recovers instantaneous collocation pressure with full surface Dirichlet data and bottom acceleration zero; `p_full` is Pa, and `p_linear` is the existing modal polarization |
| Resolved evolution | `freeSurfaceWeakRHS` and `freeSurfaceWeakSolver` solve $Hv+K^*\lambda=r_h$, $Kv=b$ using reconstruction/adjoint actions and reference preconditioners; $\lambda$ is a modal constraint reaction, not pressure |
| Reference-time amplitudes | `coefficientTendency` returns $v-La$: analytical positive/negative wave and inertial phases already account for $La$ |

The pressure matrix is $M=\begin{pmatrix}\gamma I&-\gamma\beta\\-\gamma\beta^T&\gamma^{-1}+\gamma|\beta|^2\end{pmatrix}$ with $\beta=\alpha\nabla_H\zeta/\gamma$. Pressure solves $\nabla_\xi\cdot(M\nabla_\xi\pi)=\nabla_\xi\cdot F$, with $(M\nabla\pi)_w=F_w$ at the bottom and prescribed $\pi_s$ at the top. Boundary rows replace the pressure PDE; endpoint divergence is reported separately from enforced interior divergence. The reduced trajectory additionally has projection and constraint-reaction error, measured in the [strong-residual study](../../../tools/nonlinear-study/strong-residual-refinement.md).

The weak velocity metric is $M^{-1}$; displacement weight is $\gamma N^2(r)$ and SSH weight is $g$. The retained constraints impose $C_\zeta v=\hat w_s$ and advection of active surface/bottom displacement anomalies. Prescribed displacement sources contribute their endpoint traces; an independent SSH mass source is unsupported. Reported discarded boundary-target RMS distinguishes retained constraint satisfaction from pointwise resolution error. Small reference mass/Schur factors and matrix-free iterations preserve independent family counts and inactive wave padding. Rank failure and nonconvergence raise errors rather than deleting modes.

## Full reference pressure and energy

The selected convention continues **reference density as a function of physical height** with constant surface $N^2$ above zero. It is C1 in density, not an extrapolation of the user's stratification function. Parcel density is evaluated only at labels inside $[-D,0]$. This pressure-reference change is equivalent to the manuscript's upper-constant convention when both volume and surface terms are retained; see the [derivation and comparison](../../../tools/nonlinear-study/reference-pressure-choice.md).

For $I(z)=\int_0^zN^2(s)\,ds$, $J'=I$, $K'=J$, with zero primitives at zero, the implementation uses

$$
B=I(r)-I(z),\qquad A=-\eta I(r)-J(r)+J(z),\qquad \pi_s=g\zeta-J(\zeta),
$$

$$
E=\left\langle\int_{-D}^0\gamma\left[\frac12|u|^2+A\right]d\xi+\frac12g\zeta^2-K(\zeta)\right\rangle_H.
$$

Stable polynomial quadrature avoids subtracting nearly equal primitives for small displacement. The domain guard allows only explicitly reported endpoint roundoff adjustments up to `32*eps(D)`; it does not alter coefficients, extend parcel density, or certify label bounds between stored samples. Larger excursions and nonpositive Jacobians fail explicitly.

`physicalEnergy` and `totalEnergy` retain their positive **quadratic** inventories, including balanced cross terms. `nonlinearEnergy` returns the full expression above. Nonlinear energy need not be exactly conserved by the finite retained model: the constraint reaction does work. The [full-reference trajectory report](matrix-free-full-reference-qualification.md) independently verifies the complete identity, including spatial, reaction, solver, and SSH residual work. Passing an energy-work balance does not prove material/APV conservation.

## Supported runtime and API

| Path | Contract |
| --- | --- |
| Default Boussinesq construction | Linear phases, no installed advection; supported reference-coordinate sources use the existing linear projector |
| Explicit nonlinear activation | Construct with `shouldAntialias=true` and `shouldCheckQuadraticAliasing=true`; add `WVNonlinearAdvection(wvt)`; no automatic trimming or renewed EVP selection at activation |
| `WVModel(wvt)` | Ordinary six-family tendency integration; fixed RK4 in this qualification |
| `WVModel(...,shouldUseLinearDynamics=true)` | Frozen amplitudes and analytical phases; registered forcing is not evaluated |
| Prescribed sources | `WVPrescribedBoussinesqSource` persists `sourceCoordinates`, patterns, absolute frequency/phase/time; physical sources require advection in the effective registry |
| Registry changes | Atomic validation after name replacement; only advection and prescribed sources are currently qualified for Boussinesq |
| Flow components | Physical contributions use total surface geometry and add to the total; hatted fields remain explicit; full pressure/geometry/energy are total-state quantities |
| Spatial and coefficient flux diagnostics | Pressure-free hatted increments versus coupled six-family coefficient response, respectively; see the [field contract](../../../tools/nonlinear-study/field-and-runtime-contract.md) |
| Particles and tracers | Physical-position queries invert the moving map; volume tracer transport uses physical horizontal velocity and `w_i`; horizontal-only particles retain prescribed physical heights |
| Native files and restart | Persist `fieldConvention="physical-velocity-full-c1"`, canonical families, counts, stored operators and forcing inventory; derived factors rebuild without InternalModes |
| Rejected or deferred | Unqualified inventories/closures, legacy three-array flux/energy APIs, independent SSH sources, adaptive Boussinesq stepping, portable nonlinear execution, breaking and foam |

Both quadratic-qualification flags are necessary activation conditions, not a certificate for all rational metric terms, nonlinear thermodynamics or pressure resolution. Use the [fixed-inventory overintegration study](../../../tools/nonlinear-study/frozen-overintegration.md), retained-resolution study, and independent pressure residuals to assess those effects. General surface reconstruction and vertical-derivative performance remain #453/#452; finite-amplitude QG dynamics remain #451. QG receives its missing `eta_i` convenience field without changing its existing small-amplitude equations.

The [deterministic authoring example](../../Examples/runNonlinearFreeSurfaceBoussinesq.m) writes native fields and energy/solver plots. The [restart report](nonlinear-runtime-restart.md) covers ordinary model continuation and a separate provider-free process with a variable wave-count map. The [native MPM consumer check](installed-package-qualification.md) also verifies the exported runtime on the MATLAB R2025b floor. A 20-second nonlinear particle/tracer continuation control checks nonzero three-dimensional motion, nonconstant tracer evolution, constant-tracer preservation and native restart agreement. This is bounded by the independently tested coordinate equations and is not a general long-time particle/tracer conservation claim.

## Downstream adoption

This branch is not a new stable release. Current experiment repositories retain their pinned provider revisions. When adopting this WVM revision, update provisional Boussinesq `p` callers to `p_linear` or `p_full` according to purpose. Linear polarization comparisons must request `u_hat/v_hat/w_hat`; physical movies may request `u/v/w`. In `surface-gravity-wave-experiment`, the specialized section reconstruction and its comparison test must make that same choice explicitly: its existing linear vertical velocity is hatted and is not automatically the full moving-map physical vertical velocity. Preserve the surface-only reconstruction path. No dependency pin is advanced before review/release, and no migration alias hides this distinction.
