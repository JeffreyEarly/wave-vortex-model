---
layout: default
title: quasigeostrophicDampingContributions
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 18
mathjax: true
---

#  quasigeostrophicDampingContributions

Return the horizontal and selective tendencies used by this forcing.


---

## Parameters
+ `wvt`  free-surface QG transform evaluating the closure
+ `physicalState`  optional shared reconstruction containing uvMax

## Returns
+ `horizontal`  horizontal coefficient tendency
+ `vertical`  APV-mode or native generalized-enstrophy coefficient tendency

## Discussion

Their sum is the complete damping tendency, including any
configured cutoff. Thermal selective damping acts in complete
generalized-enstrophy coordinates. Both contributions leave MDA
unchanged.
