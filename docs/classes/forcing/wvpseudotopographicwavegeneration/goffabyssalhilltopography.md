---
layout: default
title: goffAbyssalHillTopography
parent: WVPseudoTopographicWaveGeneration
grand_parent: Forcing
nav_order: 9
mathjax: true
---

#  goffAbyssalHillTopography

Generate periodic Goff abyssal-hill topography.


---

## Declaration
```matlab
 [virtualDepth,topographicHeight,diagnostics] = WVPseudoTopographicWaveGeneration.goffAbyssalHillTopography(wvt,options)
```
## Parameters
+ `wvt`  periodic `WVTransform` defining the horizontal grid and mean depth
+ `options.rmsHeight`  requested post-filter RMS topographic height in meters
+ `options.cornerWavenumber`  Goff corner wavenumber in radians per meter
+ `options.minimumWavelength`  shortest retained wavelength in meters
+ `options.randomSeed`  nonnegative seed for a local Mersenne Twister stream

## Returns
+ `virtualDepth`  positive water depth of size $$N_x\times N_y$$ in meters
+ `topographicHeight`  upward-positive zero-mean height of size $$N_x\times N_y$$ in meters
+ `diagnostics`  realized statistics and spectral diagnostics

## Discussion

  The isotropic two-dimensional power spectrum is

  $$P_h(K)=\frac{4\pi h_{\mathrm{rms}}^2}{K_c^2}
  \left(1+\frac{K^2}{K_c^2}\right)^{-2}.$$

  The returned height is positive upward, zero mean, and
  normalized to the requested post-filter RMS. Random phases
  use a local stream and do not alter MATLAB's global random
  state.

  ```matlab
  [H,h,diagnostics] = WVPseudoTopographicWaveGeneration.goffAbyssalHillTopography(wvt,minimumWavelength=30e3);
  ```
