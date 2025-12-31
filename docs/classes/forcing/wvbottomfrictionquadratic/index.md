---
layout: default
title: WVBottomFrictionQuadratic
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 8
---

#  WVBottomFrictionQuadratic

Quadratic bottom friction


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBottomFrictionQuadratic < <a href="/classes/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

Applies quadratic bottom friction to the flow, i.e.,
$$\frac{du}{dt} = -(Cd/dz)*|u|*u$$. Cd is unitless, and dz is
(approximately) the size of the grid spacing at the bottom boundary.

To compare with linear bottom friction where $$\frac{du}{dt} =
-r*u$$, note that $$-(Lz/dz)*r = -(Cd/dz)*|u|$$ and you will find a
characteristic velocity $$|u|$$ of about 11.5 cm/s for Cd=0.002 and
r=1/(200 days). If Cd=0.001, then the damping time scale has to
double to 1/(400 days) for and equivalent characteristic velocity.

For barotropic QG we want the scaling to work out similarly, but now
have $$-r = -(Cd/D)*|u|$$ where $$D$$ works out to be Lz. Thus, we
will scale the barotropic QG quadratic bottom drag by 4000 m, to match
typical oceanic scales.





## Topics
+ Other
  + [`Cd`](/classes/forcing/wvbottomfrictionquadratic/cd.html) non-dimensional
  + [`WVBottomFrictionQuadratic`](/classes/forcing/wvbottomfrictionquadratic/wvbottomfrictionquadratic.html) initialize the WVNonlinearFlux nonlinear flux
  + [`cd`](/classes/forcing/wvbottomfrictionquadratic/cd_.html) units of inverse length
  + [`classRequiredPropertyNames`](/classes/forcing/wvbottomfrictionquadratic/classrequiredpropertynames.html) 


---