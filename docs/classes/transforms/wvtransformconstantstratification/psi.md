---
layout: default
title: psi
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 211
mathjax: true
---

#  psi

geostrophic streamfunction


---

## Description
Real valued property with dimensions $$(x,y,z)$$ and units of $$m^2/s$$.

## Discussion

The geostrophic streamfunction $$\psi$$ is computed from,

$$
\hat{\psi} = \frac{g}{f_0} A_0
$$

and then transformed back to the spatial domain with the $$F$$ modes using [transformToSpatialDomainWithF](/classes/transforms/wvtransform/transformtospatialdomainwithf.html).

In code,

```matlab
f = @(wvt) wvt.transformToSpatialDomainWithF(A0=(wvt.g/wvt.f) * wvt.A0t);
```
