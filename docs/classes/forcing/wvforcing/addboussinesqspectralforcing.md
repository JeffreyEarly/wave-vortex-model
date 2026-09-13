---
layout: default
title: addBoussinesqSpectralForcing
parent: WVForcing
grand_parent: Forcing
nav_order: 2
mathjax: true
---

#  addBoussinesqSpectralForcing

Add reference-time rates for the six free-surface Boussinesq families.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `wvt`  owning free-surface Boussinesq transform
+ `tendency`  accumulated canonical coefficient rates
+ `physicalState`  shared physical diagnostics, including uvMax

## Returns
+ `tendency`  updated coefficient rates
