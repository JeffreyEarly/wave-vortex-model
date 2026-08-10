---
layout: default
title: Apt
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 12
mathjax: true
---

#  Apt

`Apt` is the positive-frequency coefficient array evaluated at the current transform time:


---

## Description
Complex valued property with dimensions $$(j,kl)$$ and units of $$m/s$$.

## Discussion
`Apt` is the positive-frequency coefficient array evaluated at the current transform time:

$$
A_+^{k\ell j}(t) = A_+^{k\ell j}(t_0) e^{i\omega^{k\ell j}(t-t_0)}.
$$

It is computed from the stored `Ap`, `t`, `t0`, and modal frequency without changing `Ap`.
