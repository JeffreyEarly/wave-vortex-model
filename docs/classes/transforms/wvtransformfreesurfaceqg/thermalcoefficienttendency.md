---
layout: default
title: thermalCoefficientTendency
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 214
mathjax: true
---

#  thermalCoefficientTendency

Project weak vertical buoyancy diffusion and endpoint fluxes.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 tendency = thermalCoefficientTendency(self,kappaT,options)
```
## Parameters
+ `kappaT`  constant vertical diffusivity in square meters per second
+ `options.surfaceBuoyancyFlux`  inward surface buoyancy flux on the horizontal grid
+ `options.bottomBuoyancyFlux`  inward bottom buoyancy flux on the horizontal grid

## Returns
+ `tendency`  scalar structure with `Ag_q`, `Ag_0`, and `Amda` tendencies

## Discussion

The complete interior displacement and buoyancy are

$$
\eta_i(z)=\eta(z)-\left(1+\frac{z}{D}\right)\frac{f}{g}\psi(0),
\qquad \mathfrak b=-N^2\eta_i.
$$

On unconstrained grid rows the weak update is

$$
W\mathcal T_{\mathfrak b}
=-D_z^T W\kappa_TD_z\mathfrak b
+e_0\mathcal Q_{\mathfrak b,0}
+e_d\mathcal Q_{\mathfrak b,d}.
$$

Positive endpoint flux is inward. Inactive endpoint rows are constrained
to zero and reject nonzero imposed flux. The resulting displacement and
QGPV tendencies are projected into `Ag_q`, residual `Ag_0`, and `Amda`.
