---
layout: default
title: group
parent: WVModelOutputGroup
grand_parent: Classes
nav_order: 5
mathjax: true
---

#  group

Reference to the NetCDFGroup being used for model output


---

## Discussion
Empty indicates no file output. The output group creates the
  NetCDFGroup, but the NetCDFFile owns it, hence a WeakHandle.
