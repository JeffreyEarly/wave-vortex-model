---
layout: default
title: WVPseudoTopographicWaveGeneration
parent: WVPseudoTopographicWaveGeneration
grand_parent: Classes
nav_order: 1
mathjax: true
---

#  WVPseudoTopographicWaveGeneration

Create a prescribed bottom wave-generation forcing.


---

## Declaration
```matlab
 forcing = WVPseudoTopographicWaveGeneration(wvt,options)
```
## Parameters
+ `wvt`  supported wave-bearing `WVTransform` receiving the forcing
+ `options.topographicHeight`  real stationary terrain of size $$N_x\times N_y$$ in meters
+ `options.barotropicVelocityAmplitude`  finite complex two-component velocity amplitude in meters per second
+ `options.frequency`  custom positive angular frequency in radians per second
+ `options.darwinSymbol`  astronomical tidal constituent used to select the frequency
+ `options.rampDuration`  nonnegative startup-ramp duration in seconds
+ `options.startTime`  finite forcing start time in seconds
+ `options.shouldAvoidAdaptiveDamping`  whether to exclude modes damped by `WVAdaptiveDamping`
+ `options.maximumForcedHorizontalWavenumber`  largest forced radial horizontal wavenumber in radians per meter
+ `options.maximumForcedVerticalMode`  largest forced vertical wave-mode index
+ `options.name`  forcing name registered with the transform

## Returns
+ `forcing`  configured `WVPseudoTopographicWaveGeneration`

## Discussion

  Supply either `frequency` or `darwinSymbol`, but not both.
  Omitting both selects M2. Supported Darwin symbols are `M2`,
  `S2`, `N2`, `K1`, and `O1`. A zero ramp duration activates
  the harmonic current immediately at `startTime`. The
  transform must contain a wave component and implement
  `waveModeVerticalStructureAtIndex`. Generation avoids active
  adaptive damping by default. Manual bounds use radial
  horizontal wavenumber and vertical wave-mode index.
 
                            
