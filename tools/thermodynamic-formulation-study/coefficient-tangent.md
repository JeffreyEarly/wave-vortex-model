# Derivative of the thermodynamic coefficient conversion (#487)

The time-dependent finite coefficient conversion is now differentiated and checked against centered differences. The candidate density RHS differs from the transformed displacement RHS at finite retained mode count. For this fixture, the dominant differences decrease with more retained modes, while refining the evaluation grid has little effect. This is consistent with the previous common-pressure physical-tendency agreement and with linear agreement of the two variables.

## Definition and independent check

Let R_t reconstruct hatted fields Y=(hat u,hat v,hat w,eta,zeta), C replace eta by total density displacement h, and P_t be the existing **state** projector expressed in hatted coordinates. Define T_t(a)=P_t C(R_t a). The displacement coefficient RHS F(a,t) uses the current source projector and nonlinear helper, with independent analytic profile integrals as in the previous study.

For b=T_t(a), the rate representing the same finite-dimensional evolution is

$$G=\partial_tT_t(a)+D T_t(a)F(a,t).$$

Let Omega denote the signed phase generator: +i omega for positive waves, -i omega for negative waves, +i f for inertial oscillations, and zero for other families. The sampled field rate is Ydot=R_t(F+Omega a). For an exponential profile with lambda=1/650 m⁻¹, the scalar conversion derivative is

$$\dot h=\alpha\dot\zeta+\exp[-\lambda(\eta-\alpha\zeta)](\dot\eta-\alpha\dot\zeta).$$

The other hatted fields retain their sampled rates. The analytic coefficient derivative is G=P_t Ydot_C-Omega b. Here the projection's explicit time dependence contributes the final phase subtraction. The sampled SSH rate includes the projected nonlinear contribution; it is not replaced by hat w(surface).

The independent reference evaluates

$$G_\epsilon=\frac{T_{t+\epsilon}(a+\epsilon F)-T_{t-\epsilon}(a-\epsilon F)}{2\epsilon}.$$

The six steps are 4, 2, 1, 0.5, 0.25, and 0.125 seconds. No trajectory is integrated. Wave-family errors decrease by approximately four per halving; at the smallest step their absolute errors are 3.9e-15 and 4.6e-15, compared with rate scales 1.9e-6 and 6.0e-7. Fixing t inside T incorrectly leaves errors of 1.6e-7 and 6.3e-7. Other families reach their subtraction-roundoff floors earlier. Constant stratification recovers the existing coefficient evolution, and changing the reference clock preserves the analytic tangent after phase conversion.

## Separating the candidate's differences

Four rates are compared, all in reference-time coefficients:

1. G, the derivative of the finite coefficient map.
2. N, the native h source projected on the original converted grid fields with shared pressure, from the previous increment.
3. S, the density RHS after reconstructing the retained state b, still using the original pressure field.
4. V, that same retained-state RHS using b's directly reconstructed modal pressure.

The recorded increments are N-G, S-N, and V-S. Their vectors telescope to V-G, but their separately reported maximum norms do not add. N-G includes applying the state conversion to the existing projected evolution versus projecting the converted physical equations; it is not a pure scalar differentiation error. S-N measures the additional state reconstruction change. V-S isolates pressure substitution at that retained state.

The shared-pressure control can violate the retained state's surface-pressure relation, because projection also changes SSH. Its maximum boundary mismatch is recorded explicitly. This control isolates an effect; it is not proposed as a closed evolution algorithm. For the shared-pressure calculation, the ordinary gradient of the difference from the retained state's modal pressure is included, as well as its metric corrections. Otherwise the analytic linear cancellation would incorrectly hide part of the pressure effect.

At amplitude 0.1 with exponential stratification and 16×16×65 samples, the maximum coefficient differences are:

| Family | N-G, fewer modes | S-N, fewer modes | V-S, fewer modes | V-G, fewer modes | V-G, more modes |
| --- | ---: | ---: | ---: | ---: | ---: |
| Positive waves | 6.09e-8 | 4.62e-9 | 6.97e-11 | 6.10e-8 | 2.82e-8 |
| Negative waves | 1.34e-7 | 4.62e-9 | 6.97e-11 | 1.34e-7 | 4.84e-8 |
| APV | 2.46e-15 | 9.00e-15 | 4.16e-17 | 8.98e-15 | 5.73e-15 |
| Zero-APV | 6.91e-11 | 2.83e-12 | 1.38e-14 | 6.91e-11 | 4.34e-12 |
| Inertial | 6.42e-21 | 2.18e-11 | 2.45e-12 | 2.19e-11 | 2.61e-12 |
| Mean density | 2.37e-11 | 3.50e-13 | 0 | 2.40e-11 | 7.92e-14 |

Fewer modes means 3 APV, 4 wave, and 2 mean-density modes; more means 6, 8, and 4. Both retain three inertial modes. Coefficient normalizations differ across families, so these are not comparable physical error norms. The increase retains the same seeded low modes. At fixed modes, changing 8×8×33 to 16×16×65 leaves these candidate differences essentially unchanged.

Reducing amplitude by ten reduces the wave and zero-APV candidate differences by approximately 100. APV decreases by about 1,000; the mean-density and inertial differences also decrease faster than quadratic over this amplitude pair. Leading terms can cancel by family: a universal quadratic scaling assertion would be incorrect. These are observations for this fixture, not general convergence orders. They do not demonstrate a linear-order inconsistency.

## Consequence

A native h RHS at fixed mode count is not automatically a coordinate rewrite of the existing finite displacement model. The measured difference is now distinguished from both physical thermodynamic equivalence and the pressure-closure change. No adoption or rejection follows from coefficient differences alone, and no trajectory or invariant claim is made.

A locally inverted coefficient map supplies a density-coordinate reference with the same finite displacement evolution and pressure convention. The [completed assessment](README.md) verifies this control and compares native density using physical errors, trajectories, invariant residuals, and complete-RHS cost. The inverse is a qualification tool, not an assumed efficient production algorithm.
