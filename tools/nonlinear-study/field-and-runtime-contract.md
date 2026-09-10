# Direct manuscript field and runtime contract

The beta free-surface Boussinesq transform uses the ordinary WVM forcing, operation, integration and annotated-persistence lifecycle. Its nonlinear callback evaluates Appendix C and the projected amplitude equation directly. The [runtime qualification](../../Documentation/Validation/NonlinearFreeSurface/direct-runtime-qualification.md) records verification and limits.

## Fields and caches

| Name | Meaning |
| --- | --- |
| `u`, `v`, `w` | Physical velocity on the moving mesh |
| `ssu`, `ssv` | Physical horizontal surface velocity |
| `u_hat`, `v_hat`, `w_hat` | Hatted modal velocity on the fixed reference column |
| `eta` | Total material displacement |
| `eta_i` | `eta-(1+z/Lz)*ssh`, the parcel-label displacement relative to the fixed column |
| `ssh` | Surface height with the existing zero-mean gauge |
| `z` | One-dimensional physical reference sample coordinate, after undoing WKB sampling |
| `z_physical` | Moving physical height `z+(1+z/Lz)*ssh` |
| `w_i` | Material reference-coordinate rate |
| `p` | Reconstructed modal pressure, including hydrostatic MDA, in Pa |
| `qgpv` | Linear reference-coordinate QGPV, not nonlinear material APV |

`p` is the pressure used in the manuscript's quadratic-order nonlinear approximation. It has no independent solve or forcing-dependent diagnostic variant. The unreleased `p_linear`, `p_full` and `fullPressure` API is removed without aliases. `reconstructSpectralState` reconstructs hatted modal fields; `reconstructFields` supplies the physical variables above.

Component velocities use the total state's geometry, so disjoint contributions add to the physical velocity. With `alpha=1+z/Lz` and `gamma=1+ssh/Lz`,

$$
u_c=\hat u_c/\gamma,\qquad v_c=\hat v_c/\gamma,\qquad w_c=\hat w_c+\alpha(u_c\zeta_x+v_c\zeta_y).
$$

`eta_i,c=eta_c-alpha*ssh_c` and modal pressure have additive component partitions. `z_physical` and `nonlinearEnergy` are total-state quantities. Existing field operations invalidate mapped velocities on any coefficient or linear-clock change, including balanced-component views on wave-deformed geometry. Modal balanced fields remain clock independent. Forcing registration does not change reconstructed pressure for a fixed coefficient state and clock.

## Equations and source meanings

The defining equation is `dA/dt = S - Pi[N+P]` (`eq:projected-amplitude-equation` in the [manuscript](https://www.overleaf.com/project/6317e19111f4547c06f405b1)). The complete linear operator cancels against the time-dependent basis. It is neither integrated again nor subtracted from an auxiliary solved rate.

`WVNonlinearAdvection` calls `nonlinearAdvectionSources`. This reconstructs modal fields and pressure, evaluates parcel buoyancy, and evaluates Appendix C (`eq:projection-ready-nonlinear-advection-terms`, `eq:projection-ready-nonlinear-pressure-terms`, `eq:projection-ready-displacement-advection`). In particular, pressure remains in `H` inside `N_w`. `coefficientTendency` sums the four equation-source arrays and calls `projectSources` once. The six resolved adiabatic coefficient families, per-kappa wave prefixes and inactive zeros remain unchanged.

The advection evaluator uses unforced `H`. A prescribed physical acceleration is mapped separately into

$$
(\hat S_u,\hat S_v,\hat S_w)=(\gamma S_u,\gamma S_v,S_w-\alpha(\zeta_xS_u+\zeta_yS_v)).
$$

The vertical term is precisely the prescribed-source contribution to `H` in Appendix C; including it again in advection would double count it. Reference-coordinate sources already specify hatted rates and are unchanged. `etaRate` is a total-displacement source in either convention. Source clocks use absolute `t-referenceTime`; modal phases use `t-t0`.

`fluxForForcing` projects each named source through this same path; its sum reproduces `coefficientTendency`. `spatialFluxForForcingWithName` and `SpatialForcingOperation` expose those hatted increments, including nonlinear pressure for advection. Their values are equation sources, not standalone physical vector fields. `projectFields` remains the physical-state inverse; it must not replace the generic `projectSources` dual.

There are no weak mass matrices, trace constraints, multipliers, pressure iterations, solver caches or energy corrections in this path. Finite inventories can leave SSH and material-boundary residuals; resolution studies measure them instead of imposing a constrained correction.

## Energy and reference density

The no-motion reference density is constant above physical height zero (`N_+^2=0` there). Parcel labels `r=z_physical-eta` must remain in `[-Lz,0]`; only the reported 32-ulp endpoint allowance is accepted. The manuscript surface-pressure approximation uses `p(surface)=rho0*g*ssh` and omits the corresponding cubic surface-energy correction.

`physicalEnergy` and `totalEnergy` retain their existing positive quadratic reference-geometry inventory, including balanced cross terms. `nonlinearEnergy` instead returns horizontally averaged moving-volume kinetic energy plus parcel APE and `g*ssh^2/2`, in m³/s². Its meaning does not depend on registered forcing.

The optional third output of `coefficientTendency` reports this energy, label bounds and two distinct rates in m³/s³:

- `energyTendency` is the analytic directional derivative of `nonlinearEnergy` along the actual reconstructed state rate, including modal phases and the coefficient-induced SSH rate.
- `prescribedWork` is the physical volume work of the prescribed sources before modal projection, including displacement work `eta*N²(r)*S_eta`.

These rates need not coincide: finite spatial/modal errors and the pressure approximation remain measurable. Neither is used to modify the RHS, and there is no invented constraint-reaction term. The nonlinear inventory has no additive family partition.

## Activation and persistence

Linear dynamics remain the default. Explicit nonlinear registration requires `shouldAntialias=true` and `shouldCheckQuadraticAliasing=true`; registration never reselects modes. `WVModel` uses the existing family-aware fixed-step integrator. Physical-position observations and reference-grid tracer transport retain their qualified coordinate contracts; adaptive and portable nonlinear evolution remain unsupported.

Native files store `fieldConvention="physical-velocity-upper-constant"`, the scientific operators, coefficient families, wave counts, both clocks and forcing inventory. A mismatched convention is rejected rather than interpreted under different physics. No compatibility migration is supplied for the retired beta convention. Restart requires no EVP or pressure solve; only derived thermodynamic primitives are rebuilt. Pressure is reconstructed from the restored coefficients through ordinary operations.
