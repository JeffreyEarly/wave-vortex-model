---
layout: default
title: WVBetaPlanePVAdvection
parent: WVBetaPlanePVAdvection
grand_parent: Classes
nav_order: 1
mathjax: true
---

#  WVBetaPlanePVAdvection

Advection of QGPV from beta


---

## Declaration
```matlab
 WVBetaPlanePVAdvection < [WVForcing](/classes/wvforcing/)
```
## Discussion

  This applies $$\beta v_g$$ to the PV (A0) flux of a simulation.
  
  
  ### Usage
 
  Assuming there is a WVTransform instance wvt, to add this forcing,
 
  ```matlab
  wvt.addForcing(WVBetaPlanePVAdvection(wvt));
  ```
 
  ### Notes
 
  This may not be justified for a hydrostatic or Boussinesq flow, but
  it works.
  
  A doubly-periodic domain with $$\beta$$ has a different $$f$$ at the
  northern and southern boundary. This is fine for quasigeostrophic
  dynamics, which only cares about the gradient of $$f$$, but is not
  okay for internal waves. However, because the wave-vortex model
  evolves coupled QG-wave equations in the spectral domain, we can add
  this effect to only the PV part of the flow. I suspect this is
  actually justifiable with the correct asymptotics. -- Jeffrey
 
    
