---
layout: default
title: Amt
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 8
mathjax: true
---

#  Amt

`Amt` is the negative-frequency coefficient array evaluated at the current transform time:


---

## Description
Complex valued property with dimensions $$(j,kl)$$ and units of $$m/s$$.

## Discussion
`Amt` is the negative-frequency coefficient array evaluated at the current transform time:

$$
A_-^{k\ell j}(t) = A_-^{k\ell j}(t_0) e^{-i\omega^{k\ell j}(t-t_0)}.
$$

It is computed from the stored `Am`, `t`, `t0`, and modal frequency without changing `Am`.
