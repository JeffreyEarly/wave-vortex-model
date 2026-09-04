---
layout: default
title: setupIntegrator
parent: WVModel
grand_parent: Class documentation
nav_order: 53
mathjax: true
---

#  setupIntegrator

Customize the time-stepping


---

## Declaration
```matlab
 setupIntegrator(self,options)
```
## Parameters
+ `integratorType`  "adaptive" (ordinary default), "fixed", or "exponential" (opt-in density diffusion)
+ `deltaT`  (fixed) time step
+ `cfl`  (fixed) cfl condition
+ `timeStepConstraint`  (fixed) constraint to fix the time step. "advective" (default) ,"oscillatory","min"
+ `integrator`  (adapative) function handle of integrator. @ode78 (default)
+ `absTolerance`  (adapative) absolute tolerance for sqrt(energy). 1e-6 (default)
+ `relTolerance`  relative tolerance, 1e-3 by default; coefficient error for adaptive stepping or reconstructed RMS error for exponential stepping
+ `shouldShowIntegrationStats`  (adapative) whether to show integration output 0 or 1 (default)
+ `physicalAbsTolerance`  (exponential) RMS floors [1e-13 1e-11 1e-8 1e-8] for QGPV, buoyancy, speed, and endpoint displacement
+ `initialStep`  (exponential) initial trial step in seconds, default 3600
+ `maximumStep`  (exponential) maximum trial step in seconds, default 86400
+ `exponentialAdaptive`  (exponential) use physical-norm step doubling, default true

## Discussion

By default the model will use adaptive time stepping with a
reasonable choice of values. However, you may find it
necessary to customize the time stepping behavior.

The default is adaptive stepping. A canonical free-surface QG
model with WVVerticalDiffusivity can opt into "exponential":
density diffusion and strict seasonal forcing are evaluated
analytically, and ETDRK4 advances the other registered forcings.
physicalAbsTolerance sets RMS floors for QGPV [s^-1], buoyancy
[m s^-2], speed [m s^-1], and endpoint displacement [m].

The "fixed" integrator selects a step using advection or the
highest oscillatory frequency. Registered free-surface density
diffusion adds a conservative bound for either selection.
An explicit deltaT exceeding that bound raises an error.

The "adaptive" time-step integator uses absolute and relative
error tolerances. It is worth reading Matlab's documentation
on RelTol and AbsTol as part of odeset to understand what
these mean. By default, the adaptive time stepping uses a
a relative error tolerance of 1e-3 for everything. However,
the absolute error tolerance is less straightforward.

The absolute tolerance has a meaningful scale with units, and
thus must be chosen differently for particle positions (x,y)
than for geostrophic coefficients (A0).
