---
layout: default
title: coefficientDampingOperator
parent: WVAdaptiveDamping
grand_parent: Closures
nav_order: 6
mathjax: true
---

#  coefficientDampingOperator

Return unit-speed damping rates for the Boussinesq families.

> Developer documentation: this item describes internal implementation details.


---

## Returns
+ `operator`  six-family rate structure, empty for other models

## Discussion

Rates have units m^-1 and the shapes of coefficientState().
Multiply by the current maximum physical horizontal speed.
