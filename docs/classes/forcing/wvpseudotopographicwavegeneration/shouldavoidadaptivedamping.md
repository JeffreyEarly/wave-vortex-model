---
layout: default
title: shouldAvoidAdaptiveDamping
parent: WVPseudoTopographicWaveGeneration
grand_parent: Forcing
nav_order: 13
mathjax: true
---

#  shouldAvoidAdaptiveDamping

Whether generation avoids active adaptive damping.


---

## Type
+ Class: `logical`
+ Size: `(1,1)`

## Description
Real valued property with no dimensions and is dimensionless.

## Discussion

When true, modes for which an active `WVAdaptiveDamping` has a
nonzero spectral operator are excluded from the generated wave
tendency.
