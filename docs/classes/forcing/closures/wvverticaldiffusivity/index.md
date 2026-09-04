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

The horizontally uniform
$$-\kappa_z\partial_z\ln N^2$$ source projects onto the
mean-density-anomaly component. Set
`shouldForceMeanDensityAnomaly=false` to omit this source. The option
has no effect for constant stratification because the gradient is
zero, and it does not modify the wave modes.

For `WVTransformStratifiedQG`, the QGPV definition

$$
q=\partial_xv-\partial_yu-f\partial_z\eta
$$

maps the displacement source
$$\mathcal{S}_\eta=\kappa_z\partial_{zz}\eta$$ to

$$
\mathcal{S}_q=-f\partial_z\mathcal{S}_\eta
=-f\kappa_z\partial_{zzz}\eta.
$$

Stratified QG contains only nonzero-horizontal-wavenumber geostrophic
modes, not a mean-density-anomaly component. Consequently,
`shouldForceMeanDensityAnomaly` does not alter its QGPV pathway.
`WVTransformFreeSurfaceQG` instead applies density diffusion with a
Galerkin operator on the complete `Ag_q`, boundary-normalized `Ag_0`, and
`Amda`; setting `shouldForceMeanDensityAnomaly=false` suppresses only
the resulting `Amda` tendency.
Both endpoints must be active for this diffusion discretization.
The forcing owns rebuildable operators derived from the transform's
stored modes. `WVModel.setupIntegrator(integratorType="exponential")`
uses these same operators for exact linear stepping. Ordinary stepping
includes the diffusion tendency through this forcing's callback.
Ordinary integration builds Galerkin generators only; diffusion
diagonalization and eigenvalue diagnostics are lazy and opt-in.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=1e-6));
```

### Notes

Wave-bearing transforms use the spatial callback, stratified QG uses
its QGPV callback, and free-surface QG uses canonical spectral tendencies.
Barotropic QG has no vertical structure and is not supported.




## Topics
+ Create the forcing
  + [`WVVerticalDiffusivity`](/classes/forcing/closures/wvverticaldiffusivity/wvverticaldiffusivity.html) Create vertical diffusivity for a three-dimensional transform.
+ Inspect forcing configuration
  + [`kappa_z`](/classes/forcing/closures/wvverticaldiffusivity/kappa_z.html) Configured vertical diffusivity in $$\mathrm{m^{2}\,s^{-1}}$$.
  + [`shouldForceMeanDensityAnomaly`](/classes/forcing/closures/wvverticaldiffusivity/shouldforcemeandensityanomaly.html) Whether to include the mean-density-anomaly source.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvverticaldiffusivity/classrequiredpropertynames.html) Returns the required property names for the class
+ Forcing internals
  + [`dLnN2`](/classes/forcing/closures/wvverticaldiffusivity/dlnn2.html) Precomputed vertical logarithmic stratification gradient.
  + [`densityDiffusionModes`](/classes/forcing/closures/wvverticaldiffusivity/densitydiffusionmodes.html) Return lazily diagonalized operators for exact linear evolution.
  + [`densityDiffusionOperators`](/classes/forcing/closures/wvverticaldiffusivity/densitydiffusionoperators.html) Return Galerkin generators without computing diffusion eigenmodes.
  + [`explicitTimeStepLimit`](/classes/forcing/closures/wvverticaldiffusivity/explicittimesteplimit.html) Return a conservative explicit diffusion timescale in seconds.


---