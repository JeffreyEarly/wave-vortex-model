---
layout: default
title: WVNonlinearAdvection
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 2
---

#  WVNonlinearAdvection

Add nonlinear advection to the model equations.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVNonlinearAdvection < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

The nonlinear terms are evaluated in physical space and added to the
momentum, thermodynamic, or quasigeostrophic potential-vorticity
(QGPV) equation appropriate to the transform.

For nonhydrostatic transforms,

$$
\begin{align}
\mathcal{S}_u &= - \left( u \partial_x u + v \partial_y u + w \partial_z u \right) \\
\mathcal{S}_v &= - \left( u \partial_x v + v \partial_y v + w \partial_z v \right) \\
\mathcal{S}_w &= - \left(  u \partial_x w + v \partial_y w + w \partial_z w \right) \\
\mathcal{S}_\eta &= - \left( u \partial_x \eta + v \partial_y \eta  + w \left(\partial_z \eta +\eta \partial_z \ln N^2 \right) \right)
\end{align}
$$

for hydrostatic transforms,

$$
\begin{align}
\mathcal{S}_u &= - \left( u \partial_x u + v \partial_y u + w \partial_z u \right) \\
\mathcal{S}_v &= - \left( u \partial_x v + v \partial_y v + w \partial_z v \right) \\
\mathcal{S}_\eta &= - \left( u \partial_x \eta + v \partial_y \eta  + w \left(\partial_z \eta +\eta \partial_z \ln N^2 \right) \right)
\end{align}
$$

and for quasigeostrophic transforms,

$$
\begin{align}
\mathcal{S}_\mathrm{qgpv} &= - \left( u \partial_x q + v \partial_y q \right)
\end{align}
$$

where $$q$$ is QGPV.

### Notes

Every supported transform installs this forcing by default. A
nonlinear `WVModel` evaluates it automatically. Analytical linear
evolution does not evaluate nonlinear forcing, so the object does not
need to be removed when using linear evolution.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
nonlinearAdvection = wvt.forcingWithName("nonlinear advection");
```




## Topics
+ Create the forcing
  + [`WVNonlinearAdvection`](/classes/forcing/wvnonlinearadvection/wvnonlinearadvection.html) Create nonlinear advection for a transform.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvnonlinearadvection/classrequiredpropertynames.html) Returns the required property names for the class
+ Forcing internals
  + [`dLnN2`](/classes/forcing/wvnonlinearadvection/dlnn2.html) Precomputed vertical logarithmic stratification gradient.


---