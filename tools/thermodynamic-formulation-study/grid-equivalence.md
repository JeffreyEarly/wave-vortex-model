# Grid-level thermodynamic equivalence (#487)

The intended comparison is exact displacement eta versus the older total density displacement h. They agree to linear order, and exactly for constant stratification. Their independently evaluated equations give the same instantaneous physical tendencies under a shared pressure. A separate physical-height density variable d appears in the main manuscript; its continuation at the surface is a distinction between variable definitions, not a failure of linear agreement between h and eta.

The grid-level checks below are supplemented by the [projected-tendency and pressure comparison](projected-comparison.md). Production evolution and public APIs are unchanged. No trajectories, timings, or adoption decision are included.

## Variables and common pressure

Write z=xi+alpha zeta, alpha=1+xi/D, gamma=1+zeta/D, q=N²(xi), and r=z-eta. The parcel label r lies in [-D,0]. Let I'=N² below zero, with I(0)=0 and constant continuation I_+(z)=I(min(z,0)). Then rho_nm⁺(z)=rho0-(rho0/g)I_+(z). All three variables below describe the same density:

$$e=\frac{I(\xi)-I(r)}q,\qquad h=e+\alpha\zeta,\qquad d=\frac{I_+(z)-I(r)}q.$$

Thus rho=rho_nm(xi)+(rho0/g)q e=rho_nm⁺(z)+(rho0/g)q d. Here e is the older notes' eta_e, h their total density displacement, and d the main manuscript's physical-height density displacement. These names are local to this study.

Use the current physical-height reference pressure throughout: p_total=p_nm⁺(z)+p, with the same approximation p(surface)=rho0 g zeta. If using the older split p_ref,old=p_nm(xi)-g rho_nm(xi)alpha zeta, its excess pressure must be changed to p_old=p+p_nm⁺(z)-p_ref,old. Copying the old excess pressure unchanged changes the physical momentum equation. The older notes already derive e with the current pressure reference in `sec:nonlinear-perturbation-equations-new-reference-pressure`.

## Instantaneous equations and chain rule

Let b=zeta_t=hat w(surface), u=hat u/gamma, v=hat v/gamma, w=hat w+alpha(u zeta_x+v zeta_y), and w_i=(hat w-alpha b)/gamma. All coordinate derivatives below hold xi fixed, and

$$D_t=\partial_t+u\partial_x+v\partial_y+w_i\partial_\xi.$$

For a physical density source S_rho, set sigma=(g/rho0)S_rho=N²(r)S_eta. The equivalent scalar equations are

$$D_t\eta=w+S_\eta,$$
$$D_te=w_i-e w_i\frac{q'}q+\frac\sigma q,$$
$$D_th=w-(h-\alpha\zeta)w_i\frac{q'}q+\frac\sigma q,$$
$$D_td=\frac{N_+^2(z)}q w-d w_i\frac{q'}q+\frac\sigma q.$$

At fixed xi, z_t=alpha b and r_t=alpha b-eta_t. The independent conversion check is

$$e_t=-\frac{N^2(r)}q r_t,\qquad h_t=e_t+\alpha b,\qquad d_t=\frac{N_+^2(z)\alpha b-N^2(r)r_t}q.$$

Physical density tendencies follow from rho_t|xi=-(rho0/g)N²(r)r_t and rho_t|z=rho_t|xi-(alpha b/gamma)rho_xi. The reference oracle differentiates rho(r) directly in physical coordinates and evaluates -u rho_x-v rho_y-w rho_z+S_rho.

The common buoyancy is

$$B=I(r)-I_+(z)=-qd=-q(h-\alpha\zeta)-[I_+(z)-I(\xi)].$$

With this B and shared p, the momentum equations are D_tu=fv-(p_x-alpha zeta_x p_xi/gamma)/rho0, D_tv=-fu-(p_y-alpha zeta_y p_xi/gamma)/rho0, and D_tw=B-p_xi/(rho0 gamma). The fixture independently evaluates these physical equations and transforms their tendencies back to hat u, hat v, hat w for comparison with the production Appendix C helper. This checks the full instantaneous grid tendency, including linear terms, before any modal projection.

The thermodynamic source contributes the same APE work eta N²(r)S_eta=eta sigma=q eta S_e, where S_e=S_h=S_d=sigma/q. This source-work identity is tested. It is not a claim of discrete total-energy conservation; modal residuals, momentum forcing, and the energy consequences of the chosen surface-pressure approximation remain separate checks.

## Surface and linear-limit distinction

For smooth stratification and valid labels, h-eta=-(q'/2q)(eta-alpha zeta)²+O(A³) as amplitude A tends to zero. Constant stratification gives h=eta exactly. At xi=0 and a positive crest, however, d=h-zeta, because I_+(zeta)=I(0)=0. Consequently d-eta=-zeta+O(A²). For constant stratification, d=eta-max(z,0) throughout the grid.

The continuation therefore gives d a derivative corner where a crest column crosses physical z=0. Interior small-amplitude expansions cannot justify using the unchanged displacement endpoint basis for d. The smooth e/h description avoids this particular corner in the prognostic scalar, although its buoyancy still includes the common piecewise reference term.

## Reproducible checks

With the repository and manifest-compatible dependencies on the MATLAB path:

```matlab
addpath('tools/thermodynamic-formulation-study')
runThermodynamicEquivalenceStudy
results = runtests('UnitTests/TestThermodynamicFormulationEquivalence.m');
assertSuccess(results)
```

The fixture uses constant and exponential stratification, signed displacement, surface crossings, and admissible parcel labels. A smooth, y-independent velocity has analytic hatted continuity and boundary transport conditions; v is nonzero. Analytic profile integrals use closed forms and expm1, independently of the production Chebyshev thermodynamic evaluator. The excess pressure obeys the current surface approximation but is prescribed, not obtained from a modal pressure solve. This is an instantaneous algebraic fixture, not a dynamically pressure-compatible solution.

`results/analytic.csv` records both profiles at amplitudes 1e-6, 0.01, and 1, with and without a prescribed thermodynamic source. `results/refinement.csv` independently refines Fourier samples Nx and Chebyshev samples Nz for the exponential case. All errors are absolute: scalar rates in m/s, density rates in kg/m³/s, density reconstruction in kg/m³, inverse labels in m, buoyancy in m/s², pressure in Pa, and source work in m²/s³. `productionError` is the maximum of componentwise hatted tendency errors, mixing velocity-rate and displacement-rate units; it is only a regression envelope, not a physical error norm. RMS columns are unweighted sample RMS, not volume norms.

Analytic conversion and scalar-rate checks agree to roundoff. On the 32 by 65 grid, the physical-equation oracle agrees with the production helper to 2.3e-14 in the above regression envelope. The h tendency reaches roundoff with refinement. For d, at Nx=128 and Nz=17 to 129 the rate-error sample RMS decreases from 1.5e-7 to 2.6e-8 m/s, while maximum error remains around 5–6e-7 m/s. This finite-grid study demonstrates the corner's practical differentiation cost; it does not establish an asymptotic convergence rate. Grid points avoid the nondifferentiable interface itself.

## Next gate and cost implications

Compare **h and exact displacement** after projection onto the retained families, first with a common pressure. Then assess the pressure closure explicitly. If the existing modal pressure is a function L of displacement coefficients, a pure change of variables requires composing L with the inverse state conversion. Substituting h coefficients into the same linear pressure reconstruction is a different closure unless equivalence is demonstrated. Nonlinear conversion and finite modal projection need not commute.

For the smooth total density variable, q and q'/q are precomputed. Its scalar RHS and buoyancy require O(HZ) pointwise work plus the existing derivatives; the reference difference I_+(z)-I(xi) must still be evaluated accurately, costing O(HZP) for a degree-P representation in general. Constant profiles simplify this further. Inverting density to exact displacement for diagnostics, forcing, or a pulled-back pressure closure can reintroduce profile work and nonlinear inversion. Thus a cheaper scalar equation alone does not yet imply a cheaper complete RHS. The current displacement evaluator already costs O(HZP) after #482, so the next comparison must measure total work at matched physical error.

The [projected comparison](projected-comparison.md) isolates the pressure-closure discrepancy, and the [coefficient-map derivative](coefficient-tangent.md) includes explicit time dependence. The completed inverse-map controls, trajectories, budgets, and matched-accuracy timings are reported in the [assessment](README.md), which recommends retaining displacement.
