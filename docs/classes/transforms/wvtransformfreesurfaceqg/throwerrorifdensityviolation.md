---
layout: default
title: throwErrorIfDensityViolation
parent: WVTransformFreeSurfaceQG
grand_parent: Transforms
nav_order: 218
mathjax: true
---

#  throwErrorIfDensityViolation

checks if the proposed coefficients are a valid adiabatic re-arrangement of the base state

> Developer documentation: this item describes internal implementation details.


---

## Discussion

Given some proposed new set of values for A0, Ap, Am, will
the fluid state violate our density condition? If yes, then
throw an error and tell the user about it.
