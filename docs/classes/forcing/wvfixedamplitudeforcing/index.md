---
layout: default
title: WVFixedAmplitudeForcing
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 5
---

#  WVFixedAmplitudeForcing

Hold selected wave-vortex coefficients at prescribed amplitudes.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVFixedAmplitudeForcing < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

This forcing keeps selected wave-vortex coefficients at prescribed amplitudes while those modes continue to participate in nonlinear interactions.

As a simple example, one can set an internal wave mode with amplitude $$1\ \mathrm{cm\,s^{-1}}$$, and that mode will continue to oscillate and maintain its amplitude. The wave will participate in all the nonlinear dynamics, but its amplitude will be maintained/restored at each time step.

There are several different ways to write this style of forcing mathematically. The equations of motion, written in the spectral domain, take the following form

$$
\frac{\partial}{\partial t} A^{klj} = \sum_i F_i^{klj}
$$

where $$F_i$$ are the contributions from the registered forcing
objects. The transform evaluates physical-space forcing, spectral
forcing, and then spectral-amplitude forcing. This forcing is evaluated
last: it zeros the tendency at selected indices and restores the
prescribed coefficient values after the integration step, giving
$$\partial_t A^{k\ell j}=0$$ for those modes.

In practice, of course, we simply restore the amplitudes to their desired value at the last step, e.g.,

```matlab
A0(self.A0_indices) = self.A0bar
```

### Notes

- This approach is commonly used in forced-dissipative turbulence to maintain some fixed forcing.
- Every fixed mode removes a degree of freedom because it no longer
evolves freely. The setter methods therefore ignore coefficients below
$$10^{-6}$$ times the largest supplied magnitude unless an explicit
mask is provided.
- Avoid selecting modes in a closure's damping range. When
`WVAdaptiveDamping` is registered, the setter methods automatically
remove requested modes with $$K_h>k_\mathrm{damp}$$.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.setGeostrophicModes(kMode=1,lMode=0,j=1,u=0.01);
force = WVFixedAmplitudeForcing(wvt,name="geostrophic-mean-flow");
force.setGeostrophicForcingCoefficients(wvt.A0);
wvt.addForcing(force);
```

In practice you can initialize the flow in any way you want with any arbitrary structure, and then pass those coefficients to the forcing. The `WVFixedAmplitudeForcing` looks for coefficients that are small and ignores those.




## Topics
+ Create the forcing
  + [`WVFixedAmplitudeForcing`](/classes/forcing/wvfixedamplitudeforcing/wvfixedamplitudeforcing.html) Create fixed-amplitude forcing for selected coefficients.
+ Inspect forcing configuration
  + [`A0_indices`](/classes/forcing/wvfixedamplitudeforcing/a0_indices.html) Linear indices of the selected `A0` coefficients.
  + [`A0bar`](/classes/forcing/wvfixedamplitudeforcing/a0bar.html) Prescribed `A0` values in $$\mathrm{m^{2}\,s^{-1}}$$.
  + [`Ap_indices`](/classes/forcing/wvfixedamplitudeforcing/ap_indices.html) Linear indices of the selected `Ap` coefficients.
  + [`Apbar`](/classes/forcing/wvfixedamplitudeforcing/apbar.html) Prescribed `Ap` values in $$\mathrm{m\,s^{-1}}$$.
  + [`Am_indices`](/classes/forcing/wvfixedamplitudeforcing/am_indices.html) Linear indices of the selected `Am` coefficients.
  + [`Ambar`](/classes/forcing/wvfixedamplitudeforcing/ambar.html) Prescribed `Am` values in $$\mathrm{m\,s^{-1}}$$.
+ Configure forcing
  + [`setWaveForcingCoefficients`](/classes/forcing/wvfixedamplitudeforcing/setwaveforcingcoefficients.html) Select positive- and negative-frequency coefficients to fix.
  + [`setGeostrophicForcingCoefficients`](/classes/forcing/wvfixedamplitudeforcing/setgeostrophicforcingcoefficients.html) Select zero-frequency coefficients to fix.
  + [`setNarrowBandGeostrophicForcing`](/classes/forcing/wvfixedamplitudeforcing/setnarrowbandgeostrophicforcing.html) Deprecated 4.x helper for narrow-band geostrophic forcing.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvfixedamplitudeforcing/classrequiredpropertynames.html) Returns the required property names for the class


---