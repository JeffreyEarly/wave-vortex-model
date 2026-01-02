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

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBottomFriction < <a href="/classes/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
Applies linear bottom friction to the flow, i.e., $$\frac{du}{dt} = -r*u$$.
 
The linear bottom friction is scaled such that we actually apply,
$$\frac{du}{dt} = -(Lz/dz)*r*u$$ and the volume integrated effect of
friction remains the same regardless of resolution.
 
To compare with quadratic bottom friction where $$\frac{du}{dt} =
-(Cd/dz)*|u|*u$$, note that $$-(Lz/dz)*r = -(Cd/dz)*|u|$$ and you
will find a characteristic velocity $$|u|$$ of about 10 cm/s for
Cd=0.002.
 
  


## Topics
+ Other
  + [`WVBottomFrictionLinear`](/classes/forcing/wvbottomfrictionlinear/wvbottomfrictionlinear.html) initialize the WVNonlinearFlux nonlinear flux
  + [`classRequiredPropertyNames`](/classes/forcing/wvbottomfrictionlinear/classrequiredpropertynames.html) 
  + [`r`](/classes/forcing/wvbottomfrictionlinear/r.html) 
  + [`r_scaled`](/classes/forcing/wvbottomfrictionlinear/r_scaled.html) 


---