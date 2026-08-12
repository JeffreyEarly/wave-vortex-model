---
layout: default
title: setNarrowBandGeostrophicForcing
parent: WVNarrowBandGeostrophicForcing
grand_parent: Forcing
nav_order: 16
mathjax: true
---

#  setNarrowBandGeostrophicForcing

Deprecated 4.x helper for narrow-band geostrophic forcing.


---

## Declaration
```matlab
 [model_spectrum,r] = setNarrowBandGeostrophicForcing(options)
```
## Parameters
+ `r`  optional large-scale damping rate in inverse seconds; when supplied, determines `k_r`
+ `k_r`  optional arrest wavenumber in radians per meter; default `2*dk`
+ `k_f`  optional forcing-band center in radians per meter; default `20*dk`
+ `j_f`  optional forced vertical-mode number; default `1`
+ `u_rms`  optional target surface root-mean-square speed in meters per second; default `0.2`
+ `initialPV`  optional initialization choice `"none"`, `"narrow-band"`, or `"full-spectrum"`; default `"narrow-band"`

## Returns
+ `model_spectrum`  configured radial spectrum function
+ `r`  effective damping rate in inverse seconds

## Discussion

New callers should construct `WVNarrowBandGeostrophicForcing`
directly. This compatibility entry point remains silent in
WaveVortexModel 4.x, initializes the same transform state, and
copies the subclass's selected coefficients into `self`.
