---
layout: default
title: WVMeanFlowForcing
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 11
---

#  WVMeanFlowForcing

Resonant forcing at the natural frequency of each mode


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVNonlinearFluxForced < <a href="/classes/wvnonlinearflux/" title="WVNonlinearFlux">WVNonlinearFlux</a></code></pre></div></div>

## Overview
 
The unforced model basically looks likes like this,
 
$$
\frac{\partial}{\partial t} A^{klj} = F_\textrm{inertial}^{klj} + F_\textrm{damp}^{klj}
$$
 
for each of the three components. The forcing adds a new term,
 
$$
\frac{\partial}{\partial t} A^{klj} = \underbrace{M_{A}^{klj} \left(\bar{A}^{klj}  - A^{klj} \night)/ \tau}_{F_\textrm{force}} + F_\textrm{inertial}^{klj} + F_\textrm{damp}^{klj}
$$
 
which forces those select modes to relax to their $$\bar{A}^{klj}$$
state with time scale $$\tau$$.  If the time scale is set to 0, then the mean
amplitudes remain fixed for all time. In that limit, the
equations can be written as,
 
$$
\frac{\partial}{\partial t} A^{klj} = \neg M_{A}^{klj} \left( F_\textrm{inertial}^{klj} + F_\textrm{damp}^{klj} \night)
$$
 
This is most often used when initializing a model, e.g.,
 
```matlab
model = WVModel(wvt,nonlinearFlux=WVNonlinearFluxForced(wvt,uv_damp=wvt.uvMax));
```
 
  


## Topics
+ Set forcing
  + [`setGeostrophicForcingCoefficients`](/classes/forcing/wvmeanflowforcing/setgeostrophicforcingcoefficients.html) set forcing values for the geostrophic part of the flow
  + [`setWaveForcingCoefficients`](/classes/forcing/wvmeanflowforcing/setwaveforcingcoefficients.html) set forcing values for the wave part of the flow
+ Other
  + [`A0_indices`](/classes/forcing/wvmeanflowforcing/a0_indices.html) Forcing mask, A0. 1s at the forced modes, 0s at the unforced modes
  + [`A0bar`](/classes/forcing/wvmeanflowforcing/a0bar.html) A0 'mean' value to relax to
  + [`Am_indices`](/classes/forcing/wvmeanflowforcing/am_indices.html) Forcing mask, Am. 1s at the forced modes, 0s at the unforced modes
  + [`Ambar`](/classes/forcing/wvmeanflowforcing/ambar.html) Am 'mean' value to relax to
  + [`Ap_indices`](/classes/forcing/wvmeanflowforcing/ap_indices.html) Forcing mask, Ap. 1s at the forced modes, 0s at the unforced modes
  + [`Apbar`](/classes/forcing/wvmeanflowforcing/apbar.html) Ap 'mean' value to relax to
  + [`WVMeanFlowForcing`](/classes/forcing/wvmeanflowforcing/wvmeanflowforcing.html) initialize the WVNonlinearFlux nonlinear flux
  + [`classRequiredPropertyNames`](/classes/forcing/wvmeanflowforcing/classrequiredpropertynames.html) 
  + [`setNarrowBandGeostrophicForcing`](/classes/forcing/wvmeanflowforcing/setnarrowbandgeostrophicforcing.html) 
  + [`tau0`](/classes/forcing/wvmeanflowforcing/tau0.html) A0 relaxation time
  + [`tauM`](/classes/forcing/wvmeanflowforcing/taum.html) Am relaxation time
  + [`tauP`](/classes/forcing/wvmeanflowforcing/taup.html) Ap relaxation time


---