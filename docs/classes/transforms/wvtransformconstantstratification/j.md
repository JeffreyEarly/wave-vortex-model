---
layout: default
title: j
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 168
mathjax: true
---

#  j

Dimensionless `Nj`-by-1 vertical-mode index vector.


---

## Discussion
Dimensionless `Nj`-by-1 vertical-mode index vector.

`j` is an `Nj`-by-1 column vector of dimensionless nonnegative mode numbers. Three-dimensional rigid-lid transforms include the barotropic index `j=0`; wave motions occupy internal modes with `j>0`.

```matlab
j = (0:(wvt.Nj-1))';
```
