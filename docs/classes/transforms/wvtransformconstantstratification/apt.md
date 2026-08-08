---
layout: default
title: Apt
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 11
mathjax: true
---

#  Apt

positive-frequency coefficients at current time t


---

## Description
Complex valued property with dimensions $$(j,kl)$$ and units of $$m/s$$.

## Discussion
`Apt` is the positive-frequency coefficient array evaluated at the current transform time:

$$
A_+^{k\ell j}(t) = A_+^{k\ell j}(t_0) e^{i\omega^{k\ell j}(t-t_0)}.
$$

It is computed from the stored `Ap`, `t`, `t0`, and modal frequency without changing `Ap`.
