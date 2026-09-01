---
layout: default
title: damp
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 5
mathjax: true
---

#  damp

Unit-speed spectral damping operator in inverse meters.


---

## Discussion

This array has `wvt.spectralMatrixSize`. The actual coefficient
damping rate is `wvt.uvMax*damp` in inverse seconds. Free-surface
QG applies its `klNonzero` subset through `dampAg_q` and uses the
separate `dampAg_0` operator for active endpoints.
