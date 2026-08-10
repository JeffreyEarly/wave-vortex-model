---
layout: default
title: A0t
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 6
mathjax: true
---

#  A0t

`A0t` is the zero-frequency coefficient array evaluated at the current transform time. On the supported $$f$$-plane transforms, `A0` has no linear phase winding and therefore


---

## Description
Complex valued property with dimensions $$(j,kl)$$ and units of $$m^2 s^{-1}$$.

## Discussion
`A0t` is the zero-frequency coefficient array evaluated at the current transform time. On the supported $$f$$-plane transforms, `A0` has no linear phase winding and therefore

$$
A_0^{k\ell j}(t) = A_0^{k\ell j}(t_0).
$$

Consequently, `A0t` returns the current stored `A0` coefficients.
