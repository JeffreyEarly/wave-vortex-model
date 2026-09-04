---
layout: default
title: WVSeasonalSurfaceAnomalyForcing
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 10
---

#  WVSeasonalSurfaceAnomalyForcing

Force surface displacement without a direct interior QGPV source.


---

## Overview

The imposed tendency is b0_t = amplitude*pattern*sin(omega*t+phase).
b0 is an endpoint displacement in meters, not physical buoyancy.
The corresponding buoyancy tendency is -N2(0)*b0_t. This is not a
weak buoyancy-flux load and has no surface quadrature-weight factor.

```matlab
force = WVSeasonalSurfaceAnomalyForcing(wvt,pattern=sin(10*pi*wvt.Y(:,:,1)/wvt.Ly),amplitude=1e-7);
wvt.addForcing(force);
```




## Topics
+ Create the forcing
  + [`WVSeasonalSurfaceAnomalyForcing`](/classes/forcing/wvseasonalsurfaceanomalyforcing/wvseasonalsurfaceanomalyforcing.html) Create strict seasonal endpoint forcing.
+ Inspect forcing configuration
  + [`pattern`](/classes/forcing/wvseasonalsurfaceanomalyforcing/pattern.html) Dimensionless horizontal pattern; required, zero mean for diffusion MVP.
  + [`amplitude`](/classes/forcing/wvseasonalsurfaceanomalyforcing/amplitude.html) Endpoint displacement tendency amplitude in meters per second.
  + [`period`](/classes/forcing/wvseasonalsurfaceanomalyforcing/period.html) Seasonal period in seconds.
  + [`phase`](/classes/forcing/wvseasonalsurfaceanomalyforcing/phase.html) at time zero in radians.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvseasonalsurfaceanomalyforcing/classrequiredpropertynames.html)


---