---
layout: default
title: priority
parent: WVForcing
grand_parent: Classes
nav_order: 13
mathjax: true
---

#  priority

determines the order in which the WVForcing will be


---

## Discussion
applied. Highest priority (0) will get called first, lowest (255)
  will get called last. The default is 255. The priority level is
  relativity to the ForcingType: i.e., spatial forcing is always
  called before spectral forcing, regardless of priority. Nonlinear
  advection and Antialiasing have priorities set to 127, and thus
  by default they will be called before other forcings in their
  type.
