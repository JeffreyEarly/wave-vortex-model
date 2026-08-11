---
layout: default
title: WVVerticalDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 4
---

#  WVVerticalDamping

Apply vertical Laplacian viscosity and diffusivity.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVVerticalDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

The damping is designed to mimic the VerticalScalarDiffusivity in
Oceananigans to allow for direct comparison between the models. This
applies to wave-bearing three-dimensional transforms and is intended
for use with
[`WVHorizontalDamping`](/classes/forcing/closures/wvhorizontaldamping/).
For an automatically scaled closure, use
[`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/).

The specific form of the forcing is given by

$$
\begin{align}
\mathcal{S}_u &= \nu \frac{\partial^2 u}{\partial z^2} \\
\mathcal{S}_v &= \nu \frac{\partial^2 v }{\partial z^2} \\
\mathcal{S}_w &= \nu \frac{\partial^2 w}{\partial z^2} \\
\mathcal{S}_\eta &= \kappa \frac{\partial^2 \eta}{\partial z^2} - \kappa \frac{\partial}{\partial z} \ln N^2
\end{align}
$$

Here $$\nu$$ is the vertical viscosity and $$\kappa$$ is the vertical
diffusivity. Combine this closure with
[`WVHorizontalDamping`](/classes/forcing/closures/wvhorizontaldamping/)
to damp horizontal gradients as well. For guidance on automatically
scaled coefficients, see
[`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/).

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.addForcing(WVVerticalDamping(wvt,nu=5e-4,kappa=1e-6));
```

### Notes

This closure is evaluated in the spatial domain.

For constant stratification, $$\partial_z \ln N^2=0$$ and the
stratification-gradient correction vanishes. The configured viscosity
and diffusivity are preserved when the forcing is copied to a
transform with a different resolution.




## Topics
+ Create the forcing
  + [`WVVerticalDamping`](/classes/forcing/closures/wvverticaldamping/wvverticaldamping.html) Create vertical Laplacian damping for a transform.
+ Inspect forcing configuration
  + [`nu`](/classes/forcing/closures/wvverticaldamping/nu.html) Vertical momentum viscosity in $$\mathrm{m^{2}\,s^{-1}}$$.
  + [`kappa`](/classes/forcing/closures/wvverticaldamping/kappa.html) Vertical displacement diffusivity in $$\mathrm{m^{2}\,s^{-1}}$$.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvverticaldamping/classrequiredpropertynames.html) Returns the required property names for the class
+ Forcing internals
  + [`dLnN2`](/classes/forcing/closures/wvverticaldamping/dlnn2.html) Precomputed vertical logarithmic stratification gradient.


---