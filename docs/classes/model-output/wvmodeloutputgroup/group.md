---
layout: default
title: group
parent: WVModelOutputGroup
grand_parent: Model output
nav_order: 7
mathjax: true
---

#  group

Reference to the NetCDFGroup being used for model output

> Developer documentation: this item describes internal implementation details.


---

## Type
+ Class: `NetCDFGroup`

## Discussion
Empty indicates no file output. The output group creates the
NetCDFGroup, but the NetCDFFile owns it, hence a WeakHandle.
