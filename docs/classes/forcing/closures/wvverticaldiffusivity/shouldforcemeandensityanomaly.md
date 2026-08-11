---
layout: default
title: shouldForceMeanDensityAnomaly
parent: WVVerticalDiffusivity
grand_parent: Closures
nav_order: 5
mathjax: true
---

#  shouldForceMeanDensityAnomaly

Whether to include the mean-density-anomaly source.


---

## Description
Real valued property with no dimensions and is dimensionless.

## Discussion

The default is `true`. This controls the horizontally uniform
$$-\kappa_z\partial_z\ln N^2$$ source, which projects onto the
mean-density-anomaly component. It has no effect on wave modes,
for constant stratification, or for stratified QG.
