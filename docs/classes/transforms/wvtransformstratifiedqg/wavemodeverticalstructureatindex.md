---
layout: default
title: waveModeVerticalStructureAtIndex
parent: WVTransformStratifiedQG
grand_parent: Transforms
nav_order: 187
mathjax: true
---

#  waveModeVerticalStructureAtIndex

Return wave vertical-structure factors at one vertical grid index.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 [F,dGdz] = waveModeVerticalStructureAtIndex(iZ)
```
## Parameters
+ `iZ`  integer vertical grid index between 1 and `Nz`

## Returns
+ `F`  wave $$F$$ factors at `z(iZ)`
+ `dGdz`  wave $$\partial_zG$$ factors at `z(iZ)`

## Discussion

For a wave coefficient matrix `Apm`, the horizontal Fourier values of
the corresponding $$F$$ field and the vertical derivative of the
corresponding $$G$$ field at `z(iZ)` are

$$
\widehat F(z_{iZ}) = \sum_j F_j(z_{iZ})A_{j\boldsymbol{k}},
\qquad
\partial_z\widehat G(z_{iZ}) =
\sum_j \partial_zG_j(z_{iZ})A_{j\boldsymbol{k}}.
$$

Both returned arrays have dimensions `[Nj Nkl]`. Request only `F` when
the derivative factors are not needed.
