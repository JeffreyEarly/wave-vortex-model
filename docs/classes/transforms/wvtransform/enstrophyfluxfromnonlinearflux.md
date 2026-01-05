---
layout: default
title: enstrophyFluxFromNonlinearFlux
parent: WVTransform
grand_parent: Classes
nav_order: 29
mathjax: true
---

#  enstrophyFluxFromNonlinearFlux

converts nonlinear flux into enstrophy flux


---

## Declaration
```matlab
 Z0 = enstrophyFluxFromNonlinearFlux(F0,options)
```
## Parameters
+ `F0`  nonlinear flux into the A0 coefficients
+ `deltaT`  (optional) include the deltaT term in the Euler time step

## Returns
+ `Z0`  energy flux

## Discussion

  Multiplies the nonlinear flux F0 by the appropriate coefficients
  to convert into an energy flux.
 
          
