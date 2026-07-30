---
layout: default
title: spectralGenerationMask
parent: WVPseudoTopographicWaveGeneration
grand_parent: Classes
nav_order: 14
mathjax: true
---

#  spectralGenerationMask

Return the spectral region eligible for bottom-wave generation.


---

## Declaration
```matlab
 [mask,components] = spectralGenerationMask()
```
## Returns
+ `mask`  logical mask applied to both generated wave tendencies
+ `components`  structure containing each constituent and branch-specific effective mask

## Discussion

  The common `mask` combines wave validity, the manual radial
  horizontal-wavenumber and vertical-mode bounds, and the exact
  zero-damping support of active `WVAdaptiveDamping` objects.
  `components` reports those masks separately, including the
  distinct positive- and negative-wave validity masks.
 
        
