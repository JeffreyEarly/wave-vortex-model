---
layout: default
title: WVLagrangianParticles
parent: WVLagrangianParticles
grand_parent: Observing systems
nav_order: 1
mathjax: true
---

#  WVLagrangianParticles

Create a Lagrangian-particle observing system.


---

## Declaration
```matlab
 self = WVLagrangianParticles(model,options)
```
## Parameters
+ `model`  the WVModel instance
+ `name`  name of the observing system
+ `advectionInterpolation`  (optional) `linear` (default) or `spline` interpolation for particle advection
+ `trackedVarInterpolation`  (optional) `linear` (default) or `spline` interpolation for tracked fields

## Returns
+ `self`  a new WVLagrangianParticles instance

## Discussion

  This class is intended to be subclassed, so this initializer
  is generally called by a model particle facade.
