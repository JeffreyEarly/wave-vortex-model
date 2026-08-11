---
layout: default
title: addWaveModes
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 87
mathjax: true
---

#  addWaveModes

add amplitudes of the given wave modes


---

## Declaration
```matlab
 [omega,k,l] = addWaveModes(kMode, lMode, j, phi, u, sign)
```
## Parameters
+ `kMode`  integer index, (k0 > -Nx/2 && k0 < Nx/2)
+ `lMode`  integer index, (l0 > -Ny/2 && l0 < Ny/2)
+ `j`  integer index, (j0 >= 1 && j0 <= nModes), unless k=l=0 in which case j=0 is okay (inertial oscillations)
+ `phi`  phase in radians, (0 <= phi <= 2*pi)
+ `u`  fluid velocity in $$\mathrm{m\,s^{-1}}$$
+ `sign`  sign of the frequency, +1 or -1

## Returns
+ `omega`  wave frequencies in $$\mathrm{rad\,s^{-1}}$$
+ `k`  x-direction wavenumbers in $$\mathrm{rad\,m^{-1}}$$
+ `l`  y-direction wavenumbers in $$\mathrm{rad\,m^{-1}}$$

## Discussion

Add new amplitudes to any existing amplitudes
