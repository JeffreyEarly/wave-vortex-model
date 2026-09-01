---
layout: default
title: priority
parent: WVForcing
grand_parent: Forcing
nav_order: 15
mathjax: true
---

#  priority

Order within a forcing stage, from 0 first to 255 last.


---

## Type
+ Class: `uint8`

## Discussion

The default is 255. Priority is compared only among forcing objects
in the same evaluation stage: all spatial forcing is evaluated
before spectral forcing, regardless of priority. Nonlinear advection
and explicit antialiasing use priority 127 so they precede ordinary
default-priority forcing in their respective stages.
