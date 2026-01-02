---
layout: default
title: WVThermalDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 6
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
 
### Notes
 
This is only implemented for quasigeostrophic flows. Specifically, it
requires `WVForcingType("PVSpatial")`.
 
  


## Topics
+ Initialization
  + [`WVThermalDamping`](/classes/forcing/closures/wvthermaldamping/wvthermaldamping.html) initialize the WVThermalDamping
+ Properties
  + [`alpha`](/classes/forcing/closures/wvthermaldamping/alpha.html) damping parameter, units of $$s^{-1}$$
  + [`alpha_scaled`](/classes/forcing/closures/wvthermaldamping/alpha_scaled.html) scaled damping parameter, units of $$s^{-1} m^{-2}$$
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvthermaldamping/classrequiredpropertynames.html) Returns the required property names for the class


---