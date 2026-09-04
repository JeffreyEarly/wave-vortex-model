---
layout: default
title: densityDiffusionOperators
parent: WVVerticalDiffusivity
grand_parent: Closures
nav_order: 5
mathjax: true
---

#  densityDiffusionOperators

Return Galerkin generators without computing diffusion eigenmodes.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

These value arrays are derived from fixed canonical modes and
are not persisted. Changing kappa_z or the MDA flag invalidates
the cache; coefficients and time do not affect it.
Use densityDiffusionModes only when exponential evolution needs
eigencoordinates. Physical metrics belong to the transform.
