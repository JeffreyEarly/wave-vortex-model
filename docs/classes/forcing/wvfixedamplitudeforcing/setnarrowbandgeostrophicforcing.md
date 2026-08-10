---
layout: default
title: setNarrowBandGeostrophicForcing
parent: WVFixedAmplitudeForcing
grand_parent: Forcing
nav_order: 10
mathjax: true
---

#  setNarrowBandGeostrophicForcing

Initialize and fix a narrow band of geostrophic coefficients.


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
+ `model_spectrum`  conditional radial spectrum function used for initialization
+ `r`  conditional damping-rate estimate computed when `r` is omitted

## Discussion

This legacy helper optionally initializes `wvt.A0`, constructs
a radial geostrophic spectrum, selects the band centered on
`k_f` at vertical mode `j_f`, and passes that selection to
`setGeostrophicForcingCoefficients`. It mutates both the
transform and this forcing. Its eventual replacement is
tracked by [Issue #2](https://github.com/JeffreyEarly/wave-vortex-model/issues/2).

`model_spectrum` is assigned only when `initialPV` is
`"narrow-band"` or `"full-spectrum"`. The returned `r` is
assigned only when `r` is omitted and computed from `k_r`.
Callers should therefore treat both outputs as conditional
legacy diagnostics.
