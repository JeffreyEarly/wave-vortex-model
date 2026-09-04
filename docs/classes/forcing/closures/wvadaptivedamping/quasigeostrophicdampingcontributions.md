---
layout: default
title: quasigeostrophicDampingContributions
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 14
mathjax: true
---

#  quasigeostrophicDampingContributions

Return the horizontal and vertical tendencies used by this forcing.


---

## Parameters
+ `wvt`  free-surface QG transform evaluating the closure
+ `physicalState`  optional shared reconstruction containing uvMax

## Returns
+ `horizontal`  horizontal coefficient tendency
+ `vertical`  APV-mode coefficient tendency

## Discussion

Their sum is the complete damping tendency, including any
configured APV cutoff. Both contributions leave MDA unchanged.
