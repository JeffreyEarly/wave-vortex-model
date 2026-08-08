---
layout: default
title: totalEnergy
parent: WVTransform
grand_parent: Transforms
nav_order: 92
mathjax: true
---

#  totalEnergy




---

## Discussion
%
The horizontally-averaged depth-integrated energy computed from the wave-vortex coefficients

$$
\sum_{jkl} \alpha_{jkl}A_+^2 + \alpha_{jkl} A_-^2 + \beta_{jkl} A_0^2
$$

In code,

```matlab
App = self.Ap; Amm = self.Am; A00 = self.A0;
energy = sum(sum(sum( self.Apm_TE_factor.*( App.*conj(App) + Amm.*conj(Amm) ) + self.A0_TE_factor.*( A00.*conj(A00) ) )));
```
