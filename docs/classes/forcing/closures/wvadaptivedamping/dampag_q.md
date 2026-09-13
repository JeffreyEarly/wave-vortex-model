---
layout: default
title: dampAg_q
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 9
mathjax: true
---

#  dampAg_q

Unit-speed damping operator for free-surface APV coefficients.

> Developer documentation: this item describes internal implementation details.


---

## Discussion

This array has the shape of `wvt.Ag_q` for a
free-surface QG or Boussinesq transform and is empty otherwise. It
combines horizontal and APV-mode damping for QG; Boussinesq uses
horizontal damping only.
