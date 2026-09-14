---
layout: default
title: quadraticDiagnostics
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 182
mathjax: true
---

#  quadraticDiagnostics

Evaluate physical inventories and individual or batched directional rates.


---

## Parameters
+ `options.state`  Ath/Amda structure; defaults to current state
+ `options.tendency`  optional row of Ath/Amda directional tendencies

## Returns
+ `diagnostics`  energy components, total energy, potential enstrophy and endpoint second moments
+ `byWavenumber`  compact nonzero contributions including conjugate partners
+ `horizontalMean`  independent MDA inventories and rates

## Discussion

Energy is the horizontal average of
$$E=\frac12\int_{-D}^{0}(u^2+v^2+N^2\eta^2)\,dz+\frac12 g\eta_s^2$$
in m3 s-2. Potential enstrophy is the full reconstructed
$$Z=\frac12\int_{-D}^{0}q^2\,dz$$ in m s-2. Both endpoint anomaly
variances are half second moments in m2, including their horizontal means.
All nonorthogonal cross terms are retained. No signed generalized inventory
is implied by the thermal eigenvector normalization.

A row of tendencies shares the same reconstructed state. Rate fields have
suffix Tendency and one row per input tendency; spectra have one column per
klNonzero. Conjugate partners are included once. Summing a spectrum and its
horizontalMean term recovers the total. Rate units are inventory units/s.
