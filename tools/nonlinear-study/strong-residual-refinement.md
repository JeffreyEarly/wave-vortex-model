# Modal stage versus instantaneous strong equations

> Historical evidence. This report describes the retired weak/pressure implementation or its comparison studies. The executable solvers have been removed; see the [direct runtime qualification](../../Documentation/Validation/NonlinearFreeSurface/direct-runtime-qualification.md) for the current implementation. Historical source links refer to revision `7b9ccda7`.

The strong velocity and displacement residuals decrease with vertical inventory and grid refinement for the specified mixed seed. The pressure integration-by-parts defect is at roundoff throughout. The remaining **retained** strong residual is the nonzero constraint reaction, not a physical pressure defect. This supplies bounded consistency evidence, but does not establish exact finite-dimensional momentum or qualify an evolved trajectory for activation.

## Control and comparison

Run `addpath('tools/nonlinear-study'); results=runFreeSurfaceStrongResidualStudy();` after configuring the pinned package dependencies. The attached CSV records all absolute numerators, term scales, solver residuals, and boundary diagnostics. The default run evaluates all three levels; a vector of levels can select a subset, with seed fingerprints always compared to level 1.

The domain is $10^5\times10^5\times1000$ m, horizontal grid $8\times8$, antialiasing enabled, $N^2=10^{-4}$ s$^{-2}$, and `nEVP=256`. Levels use $(N_z,n_q=n_{\rm mda}=n_{\rm io},n_w)=(65,2,3),(129,4,6),(257,8,12)$. The common `seedState` helper supplies the initial state, augmented by $A_{w,p}^{(y)}=0.3e^{0.41i}A_{w,p}^{(x)}$ and $A_{w,m}^{(y)}=0.2e^{0.63i}A_{w,p}^{(y)}$. Clocks are $t=0,t_0=-17$. Physical seed fingerprints on a common $24\times24\times257$ grid agree to $1.09\times10^{-14}$ relative; labels stay in $[-998.10,-1.8007]$ m on that grid. The seed is admissible without any parcel-label extension.

`stage.totalRate` is reconstructed through the current phase-aware transform. This includes the analytical linear generator; comparing only the returned nonlinear remainder would omit that generator. The other side of the comparison calls the full mapped tendency with zero pressure to obtain $F$, solves the instantaneous collocation pressure using the full C1 surface value $\pi_s=g\zeta-J(\zeta)$, and calls the mapped tendency again using $\rho_0\pi$ and the same exact buoyancy. No modal projection is applied to these strong fields.

For a hatted acceleration $a$, the positive frozen-geometry norm is

$$\|a\|_R^2=\left\langle\int\left[\frac{a_u^2+a_v^2}{\gamma}+\gamma(a_w+\beta_xa_u+\beta_ya_v)^2\right]d\xi\right\rangle,$$

and the displacement-rate norm is $\|d\|_\eta^2=\langle\int\gamma N^2(r)d^2\,d\xi\rangle$. Horizontal brackets mean area average, and vertical integration uses the stored positive quadrature. Both norms have units m$^{3/2}$ s$^{-2}$. Velocity residuals are divided by $\|F\|_R+\|M\nabla\pi\|_R$; displacement residuals by the sum of the physical-vertical-velocity and transport-term norms. These term scales are approximately $0.1538805$ and $0.001614859$, respectively. The CSV also provides the norms of the complete modal and strong rates, so cancellation in their sums is visible.

| Level | Velocity residual | Velocity / term scale | Displacement residual | Displacement / term scale |
| --- | --- | --- | --- | --- |
| 1 | $6.038\times10^{-5}$ | $3.924\times10^{-4}$ | $4.495\times10^{-5}$ | $2.783\times10^{-2}$ |
| 2 | $8.777\times10^{-7}$ | $5.704\times10^{-6}$ | $7.878\times10^{-7}$ | $4.878\times10^{-4}$ |
| 3 | $4.400\times10^{-7}$ | $2.859\times10^{-6}$ | $1.912\times10^{-7}$ | $1.184\times10^{-4}$ |

The velocity improvements are factors 68.8 then 2.0; displacement improves by factors 57.1 then 4.1. The slower final improvement does not establish an asymptotic rate or a particular error floor. Horizontal inventory and sampling remain fixed. On level 3, tightening pressure tolerance from $10^{-12}$ to $10^{-14}$ changes the pressure-gradient acceleration by only $2.15\times10^{-10}$ in the same norm, less than 0.05% of the remaining velocity residual. Its scaled pressure residual falls to $4.79\times10^{-15}$.

## Pressure, reaction, and boundary distinctions

Let $C$ denote reconstruction, $H$ the sampled positive weak mass, and $K$ the retained boundary map. The stage solves $H v+K^T\lambda=f_{\rm weak}$. Define $f_{\rm strong}$ by testing the independently evaluated strong fields with the same metric, and define the pressure integration-by-parts defect directly by

$$d_\pi=C_u^TW\partial_x\pi+C_v^TW\partial_y\pi+C_w^TW\partial_\xi\pi-C_{w,s}^TV\pi_s.$$

Then $f_{\rm weak}-f_{\rm strong}=d_\pi$, and

$$H v-f_{\rm strong}=d_\pi-K^T\lambda.$$

The study evaluates $d_\pi$ independently from pressure derivatives and the surface pairing, rather than defining it as the difference of two RHS calls. Dual norms use the existing positive reference-mass inverse. The decomposition closes within $3.02\times10^{-14}$ absolute dual norm; the independent pressure-defect construction agrees with the RHS difference within $2.61\times10^{-17}$.

| Level | Relative pressure IBP defect | Reaction dual norm | Reaction work |
| --- | --- | --- | --- |
| 1 | $9.50\times10^{-16}$ | $4.103\times10^{-5}$ | $6.031\times10^{-6}$ |
| 2 | $5.14\times10^{-15}$ | $7.433\times10^{-7}$ | $6.603\times10^{-8}$ |
| 3 | $1.94\times10^{-15}$ | $1.529\times10^{-7}$ | $5.884\times10^{-9}$ |

Reaction work is $-(Ka)^T\lambda$, in m$^3$ s$^{-3}$ per horizontal area and reference density. It is a separate diagnostic, not an energy-conservation assertion. The retained strong residual dual norm equals the reaction dual norm to displayed precision. Consequently, even after integrating by parts consistently, a nonzero reaction cannot simply be relabeled as the physical collocation pressure. A change of volume pressure with unchanged dynamic boundary data has zero retained divergence-free pressure pairing when the IBP identity holds; it cannot remove this defect. The scalar strong equation is also independent of instantaneous pressure. Finite-inventory approximation and its reaction must be explicitly accepted and qualified, or changed, before exact trajectory momentum is claimed.

Retained kinematic constraint residuals are below $1.85\times10^{-18}$, and the pointwise SSH-rate residual is below $7.0\times10^{-18}$ m s$^{-1}$. The discarded boundary-target RMS remains $1.842\times10^{-9}$ m s$^{-1}$ at fixed horizontal inventory. These are different from the strong velocity/displacement residuals.

The pressure solve uses 3–4 iterations, with scaled relative residual at most $3.58\times10^{-13}$. Its interior divergence maxima are $3.60\times10^{-14}$, $5.98\times10^{-13}$, and $6.64\times10^{-12}$ s$^{-2}$; surface-divergence maxima are $6.42\times10^{-14}$, $1.38\times10^{-12}$, and $1.85\times10^{-11}$ s$^{-2}$. Endpoint divergence is reported independently because boundary conditions replace those PDE rows. Bottom acceleration is below $1.26\times10^{-11}$ m s$^{-2}$ and the pressure boundary error below $1.78\times10^{-14}$ m$^2$ s$^{-2}$. These raw derivative residuals increase on the finer grids even while the strong field residual decreases; they must not be hidden by the small scaled GMRES residual. The full mapped momentum call agrees with the pressure solver's corrected acceleration within $1.90\times10^{-13}$ m s$^{-2}$.

## Verification ledger and limits

All three level assertions passed. The finest level was rerun only after adding the tighter-pressure sensitivity control. Code Analyzer reports no findings for the final study. One `docs:check` passed with 2,362 files, 4,827 routes, zero failures and zero differences. Whitespace and repository-scope checks passed. Only this authoring study, its CSV, and this note are changed; package metadata, core source, manuscript, and website remain untouched. No missing assets or dependencies blocked the study.

This is one instantaneous, constant-stratification seed. It does not qualify variable stratification, amplitude ranges, evolving label bounds, horizontal refinement, accumulated momentum residual, or exact finite-dimensional energy conservation. The finite reaction and the slower finest-level velocity improvement remain material limitations for activation claims.
