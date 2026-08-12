---
layout: default
title: WVBetaPlanePVAdvection
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 7
---

#  WVBetaPlanePVAdvection

Add beta-plane advection to the balanced QGPV tendency.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBetaPlanePVAdvection < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

On a beta plane, material conservation of total quasigeostrophic
potential vorticity gives

$$
\frac{D}{Dt}(q+\beta y)=0,
$$

so the right-hand-side tendency contributed by this forcing is

$$
\left.\frac{\partial q}{\partial t}\right|_\beta=-\beta v_g.
$$

QG transforms evaluate this expression directly in physical QGPV
space. Wave-bearing transforms apply the equivalent spectral tendency
only to the geostrophic `A0` coefficients; `Ap`, `Am`, inertial modes,
and mean-density-anomaly modes receive no direct beta tendency. This
retains beta advection for the balanced flow but is not a full
beta-plane treatment of internal-wave dynamics: wave frequencies and
structures continue to use the transform's constant Coriolis
parameter.

```matlab
wvt.addForcing(WVBetaPlanePVAdvection(wvt));
```




## Topics
+ Create the forcing
  + [`WVBetaPlanePVAdvection`](/classes/forcing/wvbetaplanepvadvection/wvbetaplanepvadvection.html) Create beta-plane QGPV advection for a transform.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvbetaplanepvadvection/classrequiredpropertynames.html)
+ Forcing internals
  + [`betaA0`](/classes/forcing/wvbetaplanepvadvection/betaa0.html) Spectral multiplier mapping `A0` to its beta-plane tendency.


---