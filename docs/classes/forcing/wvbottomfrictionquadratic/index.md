---
layout: default
title: WVBottomFrictionQuadratic
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 4
---

#  WVBottomFrictionQuadratic

Apply quadratic drag at the bottom boundary.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBottomFrictionQuadratic < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

The dimensionless drag coefficient $$C_d$$ is divided by the bottom
quadrature weight for a three-dimensional transform:

$$
c_d=\frac{C_d}{z_\mathrm{int}(1)}.
$$

Barotropic QG uses a fixed 4000 m reference depth,
$$c_d=C_d/(4000\,\mathrm{m})$$. Comparing quadratic and linear drag
gives the characteristic relation $$L_z r=C_d\lvert\mathbf{u}\rvert$$.

Using the notation that

$$
|\mathbf{u}(x,y,-D)| = \sqrt{u^2(x,y,-D) + v^2(x,y,-D)}
$$

is the magnitude of the total velocity at the bottom boundary. For
hydrostatic and nonhydrostatic transforms,

$$
\begin{align}
\mathcal{S}_u &= -c_d |\mathbf{u}(x,y,-D)| u(x,y,-D) \\
\mathcal{S}_v &= -c_d |\mathbf{u}(x,y,-D)| v(x,y,-D)  \\
\mathcal{S}_w &= 0 \\
\mathcal{S}_\eta &= 0
\end{align}
$$

and for quasigeostrophic transforms,

$$
\begin{align}
\mathcal{S}_\mathrm{qgpv} &= -c_d \left[ \partial_x \left( |\mathbf{u}|v \right) - \partial_y \left( |\mathbf{u}|u \right) \right]_{z=-D}
\end{align}
$$

The free-surface QG transform projects the bottom stress
into its canonical APV and active-endpoint families through a signed
boundary load. Its stress products use a doubled horizontal grid.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.addForcing(WVBottomFrictionQuadratic(wvt,Cd=0.001));
```




## Topics
+ Create the forcing
  + [`WVBottomFrictionQuadratic`](/classes/forcing/wvbottomfrictionquadratic/wvbottomfrictionquadratic.html) Create quadratic bottom friction for a transform.
+ Inspect forcing configuration
  + [`Cd`](/classes/forcing/wvbottomfrictionquadratic/cd.html) Configured dimensionless quadratic drag coefficient.
+ Inspect forcing or damping scales
  + [`cd`](/classes/forcing/wvbottomfrictionquadratic/cd_.html) Drag coefficient applied at the bottom in $$\mathrm{m^{-1}}$$.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvbottomfrictionquadratic/classrequiredpropertynames.html) Returns the required property names for the class


---