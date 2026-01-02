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

Quadratic bottom friction


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBottomFrictionQuadratic < <a href="/classes/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
Applies quadratic bottom friction to the flow, i.e.,
$$\frac{du}{dt} = -\frac{Cd}{dz}|\mathbf{u}|\mathbf{u}(x,y,-D)$. Cd is unitless, and dz is
(approximately) the size of the grid spacing at the bottom boundary.
 
To compare with linear bottom friction where $$\frac{du}{dt} =
-r u(x,y,-D)$$, note that $$- \frac{Lz}{dz} r = -\frac{Cd}{dz} |u|$$ and you will find a
characteristic velocity $$|u|$$ of about 11.5 cm/s for Cd=0.002 and
r=1/(200 days). If Cd=0.001, then the damping time scale has to
double to 1/(400 days) for and equivalent characteristic velocity.
 
For barotropic QG we want the scaling to work out similarly, but now
have $$-r = -\frac{Cd}{D}|u|$$ where $$D$$ works out to be Lz. Thus, we
will scale the barotropic QG quadratic bottom drag by 4000 m, to match
typical oceanic scales.

 
For both nonhydrostatic and hydrostatic transforms linear bottom drag
 
$$
\begin{align}
\mathcal{S}_u &= -\frac{Cd}{dz} \sqrt{u^2(x,y,-D) + v^2(x,y,-D)} u(x,y,-D) \\
\mathcal{S}_v &= -\frac{Cd}{dz} \sqrt{u^2(x,y,-D) + v^2(x,y,-D)} v(x,y,-D)  \\
\mathcal{S}_w &= 0 \\
\mathcal{S}_\eta &= 0
\end{align}
$$
 
and for quasigeostrophic transforms,
 
$$
\begin{align}
\mathcal{S}_\textrm{qgpv} &= -\frac{Cd}{dz} \left(
\frac{\partial}{\partial x} \left( \sqrt{u^2(x,y,-D) + v^2(x,y,-D)}
v(x,y,-D) \right) - \frac{\partial}{\partial y} \left(
\sqrt{u^2(x,y,-D) + v^2(x,y,-D)} u(x,y,-D) \right) \right)
\end{align}
$$
 
where $\zeta = \partial_x v - \partial_y u$.
 
 
     



## Topics
+ Initialization
  + [`WVBottomFrictionQuadratic`](/classes/forcing/wvbottomfrictionquadratic/wvbottomfrictionquadratic.html) initialize the WVBottomFrictionQuadratic
+ Properties
  + [`Cd`](/classes/forcing/wvbottomfrictionquadratic/cd.html) non-dimensional quadratic drag coefficient
  + [`cd`](/classes/forcing/wvbottomfrictionquadratic/cd_.html) $$\frac{Cd}{dz}$$ scaled quadratic drag coefficient with units $$m^{-1}$$
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvbottomfrictionquadratic/classrequiredpropertynames.html) Returns the required property names for the class


---