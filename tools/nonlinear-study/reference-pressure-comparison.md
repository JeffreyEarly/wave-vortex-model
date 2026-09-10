# Exact reference-pressure comparison

Recommendation: use the full equations with an explicit $C^1$ physical-height density reference and the complete surface pressure and energy terms. Continuing surface $N^2(0)$ as a constant above zero is a defensible, deterministic pressure convention that removes the buoyancy derivative kink without arbitrary evaluation of a user function above its declared domain. It adds no prognostic variables or hierarchy. It does not extend parcel-density labels. The simpler approximate surface condition remains a separate, explicitly approximate scientific choice; selecting the full convention must explicitly update the provisional plan.

## Equations checked

Write $q(z)=g[\bar\rho(z)-\rho_0]/\rho_0$ and $H(z)=\widetilde{\bar p}(z)/\rho_0$, so $H'=-q$ and $H(0)=0$. Parcel density uses only $r=z-\eta\in[-D,0]$, where the smooth reference and original parcel-density profile agree. The upper-constant convention is $q_+(z)=q(\min(z,0))$ and $H_+(z)=H(\min(z,0))$, assuming $q(0)=0$.

With total pressure per reference density $P=p_{\rm tot}/\rho_0$, the smooth equations use

$$\pi=P+gz-H(z),\qquad B=q(z)-q(r),\qquad \mathscr A=(z-r)q(r)-H(r)+H(z).$$

Replacing only the physical-height occurrences of $q,H$ by $q_+,H_+$ defines the exact upper-constant convention. Both give the same physical acceleration $-\nabla P-[g+q(r)]\boldsymbol e_z$. Their horizontal reference-pressure gradients vanish in physical coordinates; the paired vertical pressure-gradient and buoyancy changes cancel. This statement requires the physical gradient, including metric terms when evaluated on the mapped domain.

For zero atmospheric pressure, the smooth surface condition and surface energy per horizontal area and reference density are

$$\pi_s=g\zeta-H(\zeta),\qquad E_s=\frac12g\zeta^2-\int_0^\zeta H(s)\,ds,\qquad E_s'=g\zeta-H(\zeta).$$

The difference between smooth and upper-constant volume energies is $\int_0^\zeta[H(s)-H_+(s)]\,ds$; the surface difference is its negative. The study integrates the full volume energies independently with $\gamma\,d\xi$ and checks physical-height quadrature as a second coordinate representation. It also checks pointwise APE by integrating $q(r)-q_{\rm ref}(s)$ from $r$ to $z$, without using the pressure primitive.

For constant $N^2$, $q=-N^2z$ and $H=N^2z^2/2$, yielding $B=-N^2\eta$, $\mathscr A=N^2\eta^2/2$, $\pi_s=g\zeta-N^2\zeta^2/2$, and $E_s=g\zeta^2/2-N^2\zeta^3/6$. Upper-constant APE subtracts $N^2\max(z,0)^2/2$ and its surface energy subtracts $N^2\min(\zeta,0)^3/6$ from $g\zeta^2/2$.

For the proposed variable-stratification convention, define $I(z)=\int_0^z N^2(s)\,ds$, $J(z)=\int_0^z I(s)\,ds$, and $K(z)=\int_0^z J(s)\,ds$ on $[-D,0]$. Above zero set $I=N^2(0)z$, $J=N^2(0)z^2/2$, and $K=N^2(0)z^3/6$. Then $q=-I$, $H=J$, and the formulas are

$$B=I(r)-I(z),\qquad \mathscr A=-\eta I(r)-J(r)+J(z),\qquad \pi_s=g\zeta-J(\zeta),\qquad E_s=\frac12g\zeta^2-K(\zeta).$$

The independently checked derivatives are $\partial_\eta\mathscr A|_z=\eta N^2(r)$ and $\partial_z\mathscr A|_\eta=-\eta N^2(r)-B$. Density is $C^1$, pressure $C^2$, and $K$ is $C^3$ at zero when the column profile is smooth there. Generally this is not an analytic continuation: the derivative of $N^2$ may jump. Relative to the exact upper-constant convention the volume-energy change is still $N^2(0)\max(\zeta,0)^3/6$, with its negative in surface energy. The nonlinear reference terms beyond this regularity remain a discretization concern; the comparison does not establish spectral convergence of a production solver.

## Bounded numerical evidence

Run `addpath('tools/nonlinear-study'); [results,quadrature]=runReferencePressureComparison();` from this repository. The study requires only MATLAB. It uses $D=1000$ m, $N_0^2=10^{-4}$ s$^{-2}$, and 16 surface samples of $\zeta=5\cos x+1.5\sin(2x)$ m. Three controls are checked: constant stratification; an explicitly continued exponential profile $q(z)=-N_0^2L[\exp(z/L)-1]$, $L=700$ m; and the same exponential column with constant $N^2(0)$ continuation above zero. All parcel labels lie in $[-970,-30]$ m; density evaluation asserts the original label bounds. The manufactured states need not have the original reference distribution as their sorted distribution. No claim of material evolution, bound preservation, or a globally minimal sorted-state APE is made.

The final run gave physical acceleration error below $1.17\times10^{-9}$ m s$^{-2}$ against an independently prescribed total pressure and density force, using centered physical-height pressure differences. Surface pressure residuals were zero. Matched total energy differences were below $7.11\times10^{-15}$ m$^3$ s$^{-2}$, physical versus mapped volume errors were below $4.73\times10^{-13}$ m$^3$ s$^{-2}$, and independent density-integral APE errors were below $6.08\times10^{-15}$ m$^2$ s$^{-2}$. Both APE derivatives agreed with independent centered differences within $1.07\times10^{-11}$ m s$^{-2}$. The finite-difference surface-energy derivative canceled the exact reference-volume transport rate within $3.10\times10^{-13}$ m$^3$ s$^{-3}$. These are reference-convention identities, not evidence of conservation by a reduced modal evolution scheme.

Omitting the smooth correction at these amplitudes changes surface pressure by up to $1.62\times10^{-3}$ m$^2$ s$^{-2}$ and surface energy by up to $3.07\times10^{-3}$ m$^3$ s$^{-2}$. Their small size does not make a mixed exact/truncated formulation equivalent. A weak formulation must pair $-\pi_s$ with the surface normal flux, including its surface measure, and use the matching full energy gradient. Retaining $\pi_s=g\zeta$ while changing only the bulk reference is insufficient.

An additional valid-label constant-$N$ control uses $r=\xi$ and a 5 m crest. Smooth APE is quadratic in $\xi$; the upper-constant correction occupies only the physical layer $0<z<5$ m. Unsplit Gauss quadrature therefore provides a direct test of the artificial kink's cost. Errors in volume APE per horizontal area are:

| Gauss nodes | Smooth error (m$^3$ s$^{-2}$) | Upper-constant error (m$^3$ s$^{-2}$) |
| --- | --- | --- |
| 16 | $1.17\times10^{-15}$ | $2.08\times10^{-3}$ |
| 32 | $8.88\times10^{-16}$ | $2.34\times10^{-4}$ |
| 64 | $7.22\times10^{-16}$ | $3.49\times10^{-5}$ |
| 128 | $7.22\times10^{-16}$ | $1.63\times10^{-6}$ |

The independent adaptive energy comparisons explicitly split at $z=0$ and close for both conventions.

## Variable-stratification requirements and verification

For production, define a physical-height reference over the entire permitted surface excursion, including explicit behavior outside the sampled reference column. Specify and validate its smoothness at zero and derive $H$ and its surface integral consistently from that same reference. A gridded density interpolant's default extrapolation is not a specification. Parcel density and its admissible label domain remain separate and unchanged. These choices do not remove the existing questions of reduced-basis constraint reaction work, nonlinear mode completeness, or label-bound preservation.

Verification ledger: independent study assertions passed for all three profiles, both APE derivatives, cubic surface energy, and unsplit quadrature. Code Analyzer returned no findings for the final study source. No core source, manuscript, package metadata, or generated website file is changed. No missing assets or external packages are required.
