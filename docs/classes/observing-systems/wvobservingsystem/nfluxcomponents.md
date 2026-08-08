---
layout: default
title: nFluxComponents
parent: WVObservingSystem
grand_parent: Observing systems
nav_order: 9
mathjax: true
---

#  nFluxComponents

number of components that need to be integrated in time.

> Developer documentation: this item describes internal implementation details.


---

## Type
+ Class: `uint8`

## Discussion

Setting a value greater than zero will require that you
implement,
  -absErrorTolerance
  -initialConditions
  -fluxAtTime
  -updateIntegratorValues
