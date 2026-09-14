---
layout: default
title: quasigeostrophicDampingContributions
parent: WVThermalAPVDamping
grand_parent: Closures
nav_order: 15
mathjax: true
---

#  quasigeostrophicDampingContributions

Return the two actual closure contributions with unchanged MDA.


---

## Discussion
The supplied physicalState.uvMax is authoritative for this stage.
Without it, direct evaluation falls back to native-grid uvMax;
pass the qualified nonlinear speed to compare with a model RHS.
