---
layout: default
title: WVVerticalDiffusivity
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 2
---

#  WVVerticalDiffusivity

Apply vertical diffusivity to the thermodynamic field.


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

Set `shouldForceMeanDensityAnomaly=false` to omit the
$$\partial_z\ln N^2$$ correction for variable stratification. This
option has no effect for constant stratification because the gradient
is zero.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=1e-6));
```

### Notes

This is currently implemented in the spatial domain. It applies to
wave-bearing three-dimensional transforms and has a separate QGPV
pathway for stratified QG. It is not compatible with barotropic QG,
which has no vertical structure.




## Topics
+ Create the forcing
  + [`WVVerticalDiffusivity`](/classes/forcing/closures/wvverticaldiffusivity/wvverticaldiffusivity.html) Create vertical diffusivity for a three-dimensional transform.
+ Inspect forcing configuration
  + [`kappa_z`](/classes/forcing/closures/wvverticaldiffusivity/kappa_z.html) Configured vertical diffusivity in $$\mathrm{m^2\,s^{-1}}$$.
  + [`shouldForceMeanDensityAnomaly`](/classes/forcing/closures/wvverticaldiffusivity/shouldforcemeandensityanomaly.html) Whether to include the variable-stratification correction.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvverticaldiffusivity/classrequiredpropertynames.html) Returns the required property names for the class
+ Forcing internals
  + [`dLnN2`](/classes/forcing/closures/wvverticaldiffusivity/dlnn2.html) Precomputed vertical logarithmic stratification gradient.


---