---
layout: default
title: WVVerticalDiffusivity
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 3
---

#  WVVerticalDiffusivity

Vertical diffusivty


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVVerticalDiffusivity < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
This forcing applies a vertical diffusivity with fixed $$\kappa_z$$
to the thermodynamic equation.

The specific form of the forcing is given by 
 
$$
\begin{align}
\mathcal{S}_u &= 0 \\
\mathcal{S}_v &= 0 \\
\mathcal{S}_w &= 0 \\
\mathcal{S}_\eta &= \kappa_z \frac{\partial^2 \eta}{\partial z^2} - \kappa_z \frac{\partial}{\partial z} \ln N^2
\end{align}
$$
 
Upon initialization you can set `shouldForceMeanDensityAnomaly` to
`false` and the $$\frac{\partial}{\partial z} \ln N^2$$ term will be
neglected.
 
### Usage
 
Assuming there is a WVTransform instance wvt, to add this forcing,
 
```matlab
wvt.addForcing(WVVerticalDiffusivity(wvt, kappa_z=1e-6));
```
 
### Notes
 
This is currently implemented in the spatial domain.
 
     



## Topics
+ Initialization
  + [`WVVerticalDiffusivity`](/classes/forcing/closures/wvverticaldiffusivity/wvverticaldiffusivity.html) initialize the WVVerticalDiffusivity
+ Properties
  + [`dLnN2`](/classes/forcing/closures/wvverticaldiffusivity/dlnn2.html) precomputed dLnN2 term
  + [`kappa_z`](/classes/forcing/closures/wvverticaldiffusivity/kappa_z.html) vertical diffusivity, $$m^2s^{-1}$$
  + [`shouldForceMeanDensityAnomaly`](/classes/forcing/closures/wvverticaldiffusivity/shouldforcemeandensityanomaly.html) whether to include the $$\frac{\partial}{\partial z} \ln N^2$$ term
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvverticaldiffusivity/classrequiredpropertynames.html) Returns the required property names for the class


---