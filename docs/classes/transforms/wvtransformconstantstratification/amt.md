---
layout: default
title: Amt
parent: WVTransformConstantStratification
grand_parent: Transforms
nav_order: 6
mathjax: true
---

#  Amt

negative-frequency coefficients at current time t


---

## Description
Complex valued property with dimensions $$(j,kl)$$ and units of $$m/s$$.

## Discussion
`Amt` is the negative-frequency coefficient array evaluated at the current transform time:

$$
A_-^{k\ell j}(t) = A_-^{k\ell j}(t_0) e^{-i\omega^{k\ell j}(t-t_0)}.
$$

It is computed from the stored `Am`, `t`, `t0`, and modal frequency without changing `Am`.
