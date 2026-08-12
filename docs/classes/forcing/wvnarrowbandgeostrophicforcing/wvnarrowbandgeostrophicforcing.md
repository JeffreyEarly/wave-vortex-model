---
layout: default
title: WVNarrowBandGeostrophicForcing
parent: WVNarrowBandGeostrophicForcing
grand_parent: Forcing
nav_order: 7
mathjax: true
---

#  WVNarrowBandGeostrophicForcing

Create narrow-band geostrophic fixed-amplitude forcing.


---

## Declaration
```matlab
 self = WVNarrowBandGeostrophicForcing(wvt,options)
```
## Parameters
+ `wvt`  transform that owns and evaluates the forcing
+ `options.name`  unique forcing-registry name; default `"narrow-band geostrophic forcing"`
+ `options.r`  optional authoritative damping rate in inverse seconds
+ `options.k_r`  arrest wavenumber in radians per meter; default `2*wvt.dk`
+ `options.k_f`  forced-band center in radians per meter; default `20*wvt.dk`
+ `options.j_f`  forced vertical-mode number; default `1`
+ `options.u_rms`  target surface root-mean-square speed in meters per second; default `0.2`
+ `options.initialPV`  `"none"`, `"narrow-band"`, or `"full-spectrum"`; default `"narrow-band"`
+ `options.A0_indices`  canonical persisted selected indices; requires `A0bar`
+ `options.A0bar`  canonical persisted selected values; requires `A0_indices`

## Returns
+ `self`  configured `WVNarrowBandGeostrophicForcing`

## Discussion

Ordinary construction optionally initializes `wvt.A0` before
selecting the forced band. The `A0_indices` and `A0bar` options
form the canonical restart/conversion path: both must be
supplied together, and that path never initializes `wvt.A0`
or consumes random numbers.
