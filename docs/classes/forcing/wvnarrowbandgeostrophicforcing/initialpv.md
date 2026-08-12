---
layout: default
title: initialPV
parent: WVNarrowBandGeostrophicForcing
grand_parent: Forcing
nav_order: 9
mathjax: true
---

#  initialPV

Potential-vorticity initialization choice.


---

## Type
+ Class: `string`
+ Size: `(1,1)`

## Discussion

`"none"` preserves current transform coefficients,
`"narrow-band"` initializes only the selected band, and
`"full-spectrum"` initializes the complete geostrophic spectrum.
