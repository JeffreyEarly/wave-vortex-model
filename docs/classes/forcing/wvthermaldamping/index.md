---
layout: default
title: WVThermalDamping
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 14
---

#  WVThermalDamping

Thermal damping


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBottomFriction < <a href="/classes/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
  Applies thermal damping to the flow, i.e., $$\frac{dq}{dt} = \alpha \lambda^2 \psi$$.
 
  This is as defined in Scott and Dritschel, but it can be shown that
  it is basically just a vertical diffusivity.
 
    


## Topics
+ Other
  + [`WVThermalDamping`](/classes/forcing/wvthermaldamping/wvthermaldamping.html) initialize the WVNonlinearFlux nonlinear flux
  + [`alpha`](/classes/forcing/wvthermaldamping/alpha.html) 
  + [`alpha_scaled`](/classes/forcing/wvthermaldamping/alpha_scaled.html) 
  + [`classRequiredPropertyNames`](/classes/forcing/wvthermaldamping/classrequiredpropertynames.html) 


---