---
layout: default
title: densityDiffusionModes
parent: WVVerticalDiffusivity
grand_parent: Closures
nav_order: 4
mathjax: true
---

#  densityDiffusionModes

Return lazily diagonalized operators for exact linear evolution.

> Developer documentation: this item describes internal implementation details.


---

## Returns
+ `operators`  generators augmented with complete eigencoordinates and diagnostics

## Discussion

Reuses the same Galerkin generators as the ordinary forcing
callback. A diffusion-configuration change invalidates both caches.
