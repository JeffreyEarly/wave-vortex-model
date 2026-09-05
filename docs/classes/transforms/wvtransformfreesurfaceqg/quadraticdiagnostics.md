---
layout: default
title: quadraticDiagnostics
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 185
mathjax: true
---

#  quadraticDiagnostics

Evaluate positive physical energy, full potential enstrophy, and their rates.


---

## Parameters
+ `options.state`  optional Ag_q, Ag_0, Amda structure; default is the current state
+ `options.tendency`  optional row array of family-keyed coefficient tendencies

## Returns
+ `diagnostics`  energy components, totalEnergy, potentialEnstrophy, and optional matching Tendency fields
+ `byWavenumber`  contributions in klNonzero order, excluding the horizontal mean

## Discussion

The energy is the horizontal average of
$$E=\frac12\int_{-D}^{0}(u^2+v^2+N^2\eta^2)\,dz+\frac12 g\eta_s^2.$$
Potential enstrophy is $$Z=\frac12\int_{-D}^{0}q^2\,dz$$, including
the horizontal-mean QGPV from MDA. These are physical inventories; signed
generalized energy is a separate diagnostic. Units are m3 s-2 and m s-2.
Supply any coefficient tendency to evaluate its instantaneous contribution
using the same metrics, without modifying the transform.
A row array of tendencies shares the inventory and state-dependent products.
Tendency fields then have one row per supplied tendency; by-wavenumber
tendency fields have shape numberOfTendencies by NklNonzero.

```matlab
inventory = wvt.quadraticDiagnostics();
budget = wvt.quadraticDiagnostics(tendency=wvt.coefficientTendency());
```
