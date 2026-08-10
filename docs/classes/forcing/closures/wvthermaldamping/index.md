---
layout: default
title: WVThermalDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 5
---

#  WVThermalDamping

Apply large-scale thermal damping to QGPV.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVThermalDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

For each deformation scale $$L_r$$, the implementation adds

$$
\mathcal{S}_q=\frac{\alpha}{L_r^2}\psi.
$$

This follows the large-scale thermal-damping formulation considered
by [Scott and Dritschel](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/halting-scale-and-energy-equilibration-in-twodimensional-quasigeostrophic-turbulence/BD0CAFC9019691ADC9B18A95D15445F9).

### Notes

This forcing is compatible only with stratified and barotropic QG
transforms through their physical-space QGPV forcing stage.

### Example

```matlab
wvt = WVTransformBarotropicQG([40e3,30e3],[8,6],h=0.8,latitude=45);
wvt.addForcing(WVThermalDamping(wvt,alpha=1/(200*86400)));
```




## Topics
+ Create the forcing
  + [`WVThermalDamping`](/classes/forcing/closures/wvthermaldamping/wvthermaldamping.html) Create thermal damping for a QG transform.
+ Inspect forcing configuration
  + [`alpha`](/classes/forcing/closures/wvthermaldamping/alpha.html) Configured thermal-damping rate in $$\mathrm{s^{-1}}$$.
+ Inspect forcing or damping scales
  + [`alpha_scaled`](/classes/forcing/closures/wvthermaldamping/alpha_scaled.html) Deformation-scaled damping coefficient in $$\mathrm{s^{-1}\,m^{-2}}$$.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvthermaldamping/classrequiredpropertynames.html) Returns the required property names for the class


---