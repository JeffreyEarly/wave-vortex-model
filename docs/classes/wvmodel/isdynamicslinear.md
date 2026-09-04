---
layout: default
title: isDynamicsLinear
parent: WVModel
grand_parent: Class documentation
nav_order: 34
mathjax: true
---

#  isDynamicsLinear

Whether the model uses analytical linear dynamics.


---

## Discussion
When `false`, the model integrates registered coefficient and
observing-system tendencies. When `true`, `integrateToTime`
advances the transform and output schedule analytically.
