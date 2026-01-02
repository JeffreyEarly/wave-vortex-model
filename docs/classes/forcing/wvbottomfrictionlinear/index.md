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

Linear bottom friction


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBottomFrictionLinear < <a href="/classes/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
Applies linear bottom friction to the flow, i.e., $$\frac{du}{dt} =
-r u(x,y,-D)$$. The parameter $$r$$ has units of $$s^{-1}$$ and thus
can be set as an inverse time scale.
 
The linear bottom friction is scaled such that we actually apply,
$$\frac{du}{dt} = -\frac{Lz}{dz} r u(x,y,-D)$$ and the volume
integrated effect of friction remains the same regardless of
resolution. $$Lz$$ is the total domain depth and $$dz$$ is the
spacing at the bottom grid point.
 
To compare with quadratic bottom friction where $$\frac{du}{dt} =
-\frac{Cd}{dz} |u|* $$, note that $$- \frac{Lz}{dz} r = -\frac{Cd}{dz} |u|$$ and you
will find a characteristic velocity $$|u|$$ of about 10 cm/s for
Cd=0.002.
 
For both nonhydrostatic and hydrostatic transforms linear bottom drag
 
$$
\begin{align}
\mathcal{S}_u &= -\frac{Lz}{dz} r u(x,y,-D) \\
\mathcal{S}_v &= -\frac{Lz}{dz} r v(x,y,-D)  \\
\mathcal{S}_w &= 0 \\
\mathcal{S}_\eta &= 0
\end{align}
$$
 
and for quasigeostrophic transforms,
 
$$
\begin{align}
\mathcal{S}_\textrm{qgpv} &= -\frac{Lz}{dz} r \zeta(x,y,-D)
\end{align}
$$
 
where $\zeta = \partial_x v - \partial_y u$.
 
 
     



## Topics
+ Initialization
  + [`WVBottomFrictionLinear`](/classes/forcing/wvbottomfrictionlinear/wvbottomfrictionlinear.html) initialize the WVBottomFrictionLinear
+ Properties
  + [`r`](/classes/forcing/wvbottomfrictionlinear/r.html) bottom friction, $$s^{-1}$$
  + [`r_scaled`](/classes/forcing/wvbottomfrictionlinear/r_scaled.html) scaled bottom friction, $$\frac{Lz}{dz} r$$ with units $$s^{-1}$$
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvbottomfrictionlinear/classrequiredpropertynames.html) Returns the required property names for the class


---