---
layout: default
title: WVHorizontalDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 3
---

#  WVHorizontalDamping

Apply horizontal Laplacian viscosity and diffusivity.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVHorizontalDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

The damping is a simple horizontal Laplacian, designed to mimic the
[HorizontalScalarDiffusivity in
Oceananigans](https://clima.github.io/OceananigansDocumentation/stable/appendix/library/#Oceananigans.TurbulenceClosures.HorizontalScalarDiffusivity)
to allow direct comparison between the models. It applies to
wave-bearing three-dimensional transforms and is intended for use with
[`WVVerticalDamping`](/classes/forcing/closures/wvverticaldamping/).
For an automatically scaled closure, use
[`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/).

The specific form of the forcing is given by

$$
\begin{align}
\mathcal{S}_u &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right) u \\
\mathcal{S}_v &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right)  v \\
\mathcal{S}_w &= \nu \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right)  w \\
\mathcal{S}_\eta &= \kappa \left( \frac{\partial^2}{\partial x^2} + \frac{\partial^2}{\partial y^2} \right)  \eta
\end{align}
$$

These are horizontal Laplacian viscosity, $$\nu$$, and diffusivity,
$$\kappa$$. Combine this closure with
[`WVVerticalDamping`](/classes/forcing/closures/wvverticaldamping/) to
damp vertical gradients as well. For guidance on automatically scaled
coefficients, see
[`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/).

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.addForcing(WVHorizontalDamping(wvt,nu=1e-4,kappa=1e-6));
```

### Notes

This closure is evaluated in the spatial domain.

The configured viscosity and diffusivity are preserved when the
forcing is copied to a transform with a different resolution.




## Topics
+ Create the forcing
  + [`WVHorizontalDamping`](/classes/forcing/closures/wvhorizontaldamping/wvhorizontaldamping.html) Create horizontal Laplacian damping for a transform.
+ Inspect forcing configuration
  + [`nu`](/classes/forcing/closures/wvhorizontaldamping/nu.html) Horizontal momentum viscosity in $$\mathrm{m^2\,s^{-1}}$$.
  + [`kappa`](/classes/forcing/closures/wvhorizontaldamping/kappa.html) Horizontal displacement diffusivity in $$\mathrm{m^2\,s^{-1}}$$.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvhorizontaldamping/classrequiredpropertynames.html) Returns the required property names for the class


---