---
layout: default
title: WVSeasonalSurfaceBuoyancyFlux
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 8
---

#  WVSeasonalSurfaceBuoyancyFlux

Apply a sinusoidal surface buoyancy flux to free-surface QG.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVSeasonalSurfaceBuoyancyFlux < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

The prescribed inward surface flux is

$$
\mathcal Q_{\mathfrak b,0}(x,y,t)
=Q_*P(x,y)\sin\left(\frac{2\pi t}{T}+\phi\right).
$$

The flux enters the balanced equation as a weak boundary load
using total displacement. The supplied `pattern` retains its
amplitude and mean. Its mean drives the column buoyancy inventory
through the `Amda` family. The default is $$P=\sin(2\pi y/L_y)$$.
The surface endpoint must be active.

```matlab
wvt = WVTransformFreeSurfaceQG([100e3 100e3 100],[8 8 65], ...
    N2Function=@(z)1e-4*ones(size(z)),g0=.02,gd=.03,shouldAntialias=false, ...
    quadraticDealiasing="none",apvModeCount=24,mdaModeCount=24);
wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=1e-2));
wvt.addForcing(WVSeasonalSurfaceBuoyancyFlux(wvt,amplitude=1e-8,period=10*86400));
```




## Topics
+ Create the forcing
  + [`WVSeasonalSurfaceBuoyancyFlux`](/classes/forcing/wvseasonalsurfacebuoyancyflux/wvseasonalsurfacebuoyancyflux.html) Create seasonal surface buoyancy-flux forcing.
+ Inspect forcing configuration
  + [`pattern`](/classes/forcing/wvseasonalsurfacebuoyancyflux/pattern.html) Exact horizontal surface-flux pattern.
  + [`amplitude`](/classes/forcing/wvseasonalsurfacebuoyancyflux/amplitude.html) Peak buoyancy-flux amplitude in $$\mathrm{m^{2}\,s^{-3}}$$.
  + [`period`](/classes/forcing/wvseasonalsurfacebuoyancyflux/period.html) Seasonal period in seconds.
  + [`phase`](/classes/forcing/wvseasonalsurfacebuoyancyflux/phase.html) offset $$\phi$$ in radians.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvseasonalsurfacebuoyancyflux/classrequiredpropertynames.html) Return persisted constructor property names.


---