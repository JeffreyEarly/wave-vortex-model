---
layout: default
title: quadraticDiagnostics
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 190
mathjax: true
---

#  quadraticDiagnostics

Evaluate physical and generalized invariants and their directional rates.


---

## Declaration
```matlab
 [diagnostics,byWavenumber,horizontalMean] = quadraticDiagnostics(self,options)
```
## Parameters
+ `options.state`  optional Ag_q, Ag_0, Amda structure; default is the current state
+ `options.tendency`  optional row array of family-keyed coefficient tendencies

## Returns
+ `diagnostics`  physical energy components, totalEnergy, potentialEnstrophy, surfaceAnomalyVariance, bottomAnomalyVariance, generalizedEnergy, and optional matching Tendency fields
+ `byWavenumber`  contributions in klNonzero order, excluding the horizontal mean
+ `horizontalMean`  corresponding horizontal-mean contributions, including MDA

## Discussion

The energy is the horizontal average of
$$E=\frac12\int_{-D}^{0}(u^2+v^2+N^2\eta^2)\,dz+\frac12 g\eta_s^2.$$
Potential enstrophy is $$Z=\frac12\int_{-D}^{0}q^2\,dz$$, including
the horizontal-mean QGPV from MDA. Units are m3 s-2 and m s-2.
Endpoint anomaly variances are $$B_b=\frac12\langle b_b^2\rangle$$,
in m2, including the squared horizontal mean (not mean-subtracted variance).
`surfaceAnomalyVariance` and `bottomAnomalyVariance` are zero for inactive
endpoints. Signed generalized energy is
$$H_g=E+g_0 B_0+g_d B_d,$$
in m3 s-2, with inactive terms omitted before multiplying by their weights.
`generalizedEnergy` retains all cross terms in the boundary-normalized
coordinates; it can be negative and must not serve as a positive error norm.
Supply any coefficient tendency to evaluate its instantaneous contribution
using the same metrics, without modifying the transform.
A row array of tendencies shares the inventory and state-dependent products.
Tendency fields then have one row per supplied tendency; by-wavenumber
tendency fields have shape numberOfTendencies by NklNonzero.
The optional `horizontalMean` output contains the MDA contribution to
every inventory and rate. Summing a by-wavenumber field across columns
and adding its horizontal-mean field recovers the corresponding total.
The nonzero columns include the conjugate contribution; do not double
them again. Time derivatives have the inventory units divided by seconds.

```matlab
[inventory,spectrum,meanPart] = wvt.quadraticDiagnostics();
inventory.generalizedEnergy
sum(spectrum.generalizedEnergy)+meanPart.generalizedEnergy
budget = wvt.quadraticDiagnostics(tendency=wvt.coefficientTendency());
```
