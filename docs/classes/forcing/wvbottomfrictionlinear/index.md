---
layout: default
title: WVBottomFrictionLinear
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 3
---

#  WVBottomFrictionLinear

Apply linear drag at the bottom boundary.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBottomFrictionLinear < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

The parameter $$r$$ is an inverse time scale in $$\mathrm{s^{-1}}$$.
For a three-dimensional transform, the bottom tendency is scaled by
the bottom quadrature weight `z_int(1)` so its vertically integrated
effect does not change with vertical resolution:

$$
r_\mathrm{scaled}=\frac{L_z}{z_\mathrm{int}(1)}r.
$$

A barotropic transform has no vertical quadrature and uses
$$r_\mathrm{scaled}=r$$.

Comparing this with quadratic drag gives the characteristic relation
$$L_z r=C_d\lvert\mathbf{u}\rvert$$.

For both nonhydrostatic and hydrostatic transforms linear bottom drag

$$
\begin{align}
\mathcal{S}_u &= -r_\mathrm{scaled} u(x,y,-D) \\
\mathcal{S}_v &= -r_\mathrm{scaled} v(x,y,-D)  \\
\mathcal{S}_w &= 0 \\
\mathcal{S}_\eta &= 0
\end{align}
$$

and for quasigeostrophic transforms,

$$
\begin{align}
\mathcal{S}_\mathrm{qgpv} &= -r_\mathrm{scaled}\zeta(x,y,-D)
\end{align}
$$

where $$\zeta = \partial_x v - \partial_y u$$.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.addForcing(WVBottomFrictionLinear(wvt,r=1/(200*86400)));
```




## Topics
+ Create the forcing
  + [`WVBottomFrictionLinear`](/classes/forcing/wvbottomfrictionlinear/wvbottomfrictionlinear.html) Create linear bottom friction for a transform.
+ Inspect forcing configuration
  + [`r`](/classes/forcing/wvbottomfrictionlinear/r.html) Configured linear drag rate in $$\mathrm{s^{-1}}$$.
+ Inspect forcing or damping scales
  + [`r_scaled`](/classes/forcing/wvbottomfrictionlinear/r_scaled.html) Drag rate applied at the bottom grid point in $$\mathrm{s^{-1}}$$.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvbottomfrictionlinear/classrequiredpropertynames.html) Returns the required property names for the class


---