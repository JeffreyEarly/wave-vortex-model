# Reference pressure and parcel-label domains

This records the formulation comparison and the selected internal nonlinear convention. The runtime now uses this full convention; the manuscript itself is unchanged. It addresses a numerical difficulty in evaluating the full equations at positive surface crests. It does not resolve modal constraint reaction work or authorize parcel labels outside their density domain.

## Two different density arguments

Let $r=z-\eta=\xi-\eta_i$ be a parcel's reference label. Its physical density is $\rho_{\rm nm}(r)$. Evaluating that function requires an explicitly supported label domain. In contrast, a reference density $\bar\rho(z)$ used to subtract hydrostatic pressure is a function of physical height. Its continuation above the reference surface is a pressure convention, provided all corresponding buoyancy and surface terms are retained consistently.

The manuscript's main text uses $\rho_{\rm nm}(r)$ in total density and APE, while the projection-ready appendix sometimes writes $\rho_{\rm nm}^{+}(r)$. Those expressions agree on the original reference column, but should not be treated as interchangeable outside it. A constant upper extension for parcel density also makes density-to-displacement inversion nonunique there; it is not just a numerical extension for reference pressure.

For labels restricted to $[-D,0]$, admissibility requires $\xi\leq\eta_i\leq\xi+D$. Thus the surface anomaly $\theta_s=\eta_s-\zeta$ must satisfy $0\leq\theta_s\leq D$, and the bottom anomaly $\theta_b=\eta_b$ must satisfy $-D\leq\theta_b\leq0$. An arbitrary signed zero-mean endpoint perturbation violates this range somewhere even at small amplitude. Initial controls can use suitable mean offsets, but must check interior labels too. Spectrally projected transport does not itself guarantee preservation of these bounds, or that the chosen reference is the sorted density distribution of the state.

## Smooth reference pressure as an option

The manuscript's `eq:reference-pressure-residual` and `eq:pref-iff` allow reference pressure to be a function of physical height. Suppose $\bar p'(z)=-g\bar\rho(z)$, with $\bar\rho$ a smooth continuation of $\rho_{\rm nm}$ above zero and agreement on the original column. Keep the parcel density unchanged. In the absence of atmospheric loading, define pressure per reference density by

$$
\pi=\frac{p_{\rm tot}-\bar p(z)}{\rho_0},\qquad B=\frac{g}{\rho_0}[\bar\rho(z)-\rho_{\rm nm}(r)].
$$

Changing $\bar p$ changes these two terms together, leaving $-\nabla\pi+B\boldsymbol e_z$ invariant. If $\bar p(z)=-\rho_0gz+\widetilde{\bar p}(z)$ and atmospheric pressure is zero, the dynamic boundary condition is

$$
\pi_s=g\zeta-\frac{\widetilde{\bar p}(\zeta)}{\rho_0}.
$$

The matching energy per reference density contains

$$
\mathscr A=\frac{g\eta\rho_{\rm nm}(r)-p_{\rm nm}(r)+\bar p(z)}{\rho_0},\qquad
\mathcal E_s=\frac g2\int\zeta^2\,dA-\frac1{\rho_0}\int\int_0^\zeta\widetilde{\bar p}(s)\,ds\,dA.
$$

Changes to the reference-pressure part of the volume APE cancel the matching surface-energy change exactly. This cancellation uses the physical volume element $\gamma\,d\xi=dz$.

## Constant-stratification illustration

For a linearly continued reference density with constant $N_0^2$, the smooth convention gives

$$
B=-N_0^2\eta,\qquad \mathscr A=\frac12N_0^2\eta^2,\qquad
\pi_s=g\zeta-\frac12N_0^2\zeta^2,\qquad
\mathcal E_s=\int\left(\frac12g\zeta^2-\frac16N_0^2\zeta^3\right)dA.
$$

For valid labels, the manuscript's upper-constant reference gives $B_+=-N_0^2[\eta-\max(z,0)]$ and $\mathscr A_+=\tfrac12N_0^2[\eta^2-\max(z,0)^2]$. Its volume energy differs from the smooth convention by $-N_0^2\max(\zeta,0)^3/6$ per horizontal area; its surface contribution differs by the opposite amount. Its pressure relates to the smooth-reference pressure by $\pi=\pi_+-N_0^2\max(z,0)^2/2$.

The smooth convention avoids a shrinking nonsmooth reference layer above physical height zero. It can therefore simplify amplitude and quadrature studies. It does not require extending the parcel-density function to out-of-range labels. A variable-stratification implementation would need an explicit smooth reference continuation and would retain the matching surface terms; it should not silently extrapolate a stored density interpolant.

## Decision still required

The current goal plan provisionally selects the manuscript's Boussinesq-small surface-pressure approximation $\pi_s=g\zeta$ and omits the matching cubic surface-energy correction. Switching to the full smooth-reference equations would be an explicit choice to retain those small terms. It is not valid to change the reference while leaving the truncated pressure and energy formulas untouched and claim exact equivalence.

Compare the two exact reference conventions first, with valid parcel labels, consistent pressure boundary data and independently evaluated energy. Then record whether the production target retains the full surface terms or uses the stated approximation. No extra modes, new prognostic state or model hierarchy are needed for either pressure-reference convention.

Manuscript anchors: `eq:total-displacement-definition`, `eq:displacement-coordinate-identity`, `eq:rho-nm-plus-definition`, `eq:physical-height-ape-density`, `eq:available-energy`, `eq:projection-ready-surface-pressure`, `eq:free-surface-quasigeostrophy-exact-displacement-buoyancy-integral`.

Independent review verified the signs, reference-invariant physical acceleration, cancellation of volume and surface energy, and the distinction from parcel-label extension. No numerical or production-equivalence claim follows from that algebraic review. A weak implementation must also replace its surface pressure pairing by $-W_s^T V\pi_s$ and include the nonlinear surface-energy derivative in its energy gradient.

## Selected convention after numerical comparison

The nonlinear prototype now selects the full surface terms with an explicit C1 reference-density continuation above zero. On the original column, define $I(z)=\int_0^z N^2(s)\,ds$, $J'=I$ and $K'=J$, with all primitives zero at zero. Above zero, use $I=N^2(0)z$, $J=N^2(0)z^2/2$ and $K=N^2(0)z^3/6$. This continues reference density linearly; it does not evaluate an arbitrary user function outside its supplied column and does not extend parcel density. It is generally not analytic when the interior derivative of $N^2$ is nonzero.

For $r=z-\eta$ in $[-D,0]$, use $B=I(r)-I(z)$, $\mathscr A=-\eta I(r)-J(r)+J(z)$, $\pi_s=g\zeta-J(\zeta)$ and $\mathcal E_s=g\zeta^2/2-K(\zeta)$. The exact acceleration and total energy are equivalent to the manuscript's full upper-constant reference; matching volume and surface reference changes cancel. This explicitly replaces the plan's provisional small-pressure approximation. Earlier weak-budget and trajectory results using that approximation remain valid evidence for their stated equations and are not relabelled as full-reference trajectory qualification.

The comparison and its numerical limits are in `reference-pressure-comparison.md`. The internal `freeSurfaceThermodynamics` helper uses antiderivatives for the reference pressure/density, and exact polynomial Gauss integration of the represented stratification for displacement integrals and surface corrections. The latter avoids subtracting large nearly equal primitives in the small-displacement limit. Parcel labels outside the original column fail explicitly, except for a reported endpoint roundoff allowance of 32 ulps of the column depth. Pure-wave controls exposed positive labels of roughly `4e-16` to `8e-15` metres from otherwise correct endpoint polarizations. Only such bounded endpoint excursions are evaluated at the endpoint; their maximum adjustment and count are reported, and coefficients are never altered. Larger excursions still fail rather than extending parcel density. Nonlinear runtime activation and its new trajectory qualification remain pending.
