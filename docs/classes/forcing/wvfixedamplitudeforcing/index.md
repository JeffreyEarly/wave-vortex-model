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

Fixed amplitude forcing at the natural frequency of each mode


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVFixedAmplitudeForcing < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
The fixed-amplitude forcing maintains the amplitude of the wave or geostrophic features, while allowing energy and enstrophy to flux from the feature.
 
As a simple example, one can set an internal wave mode with amplitude 1 cm/s, and that mode will continue to oscillate and maintain its amplitude. The wave will participate in all the nonlinear dynamics, but its amplitude will be maintained/restored at each time step.
 
 
There are several different ways to write this style of forcing mathematically. The equations of motion, written in the spectral domain, take the following form
 
$$
\frac{\partial}{\partial t} A^{klj} = \Sum_i F_i^{klj}
$$
 
where $F_i$ are the different forces applied. The transform computes the spatial forcing (which includes nonlinear advection), the spectral forcing, followed by the spectral amplitude forcing. The `WVFixedAmplitudeForcing` is a spectral amplitude forcing and is thus comptued last. This forcing thus simply adds back the flux the from the spatial and spectral forcing, so that $$\frac{\partial}{\partial t} A^{klj} =0$$ for the modes in question.
 
In practice, of course, we simply restore the amplitudes to their desired value at the last step, e.g.,
 
```matlab
A0(self.A0_indices) = self.A0bar
```
 
### Notes
 
- This approach is commonly used in forced-dissipative turbulence to maintain some fixed forcing.
- Every mode that is used in `WVFixedAmplitudeForcing` essentially removes a degree-of-freedom from the model, as that mode is no longer free to fully evolve. The when you pass the forcing wave-vortex coefficients, e.g. `A0`, it does not fix the amplitude of coefficients that are small to avoid removing degrees-of-freedom.
- One must also be careful not to forcing in the damping region. If you have some sort of small scale damping enabled, you probably do not want to be forcing at those smallest scales.
 
### Usage
 
To setup a geostrophic mean flow,
 
```matlab
% initialize a transform
wvt = WVTransformHydrostatic([Lx, Ly, Lz], [Nx, Ny, Nz], N2=@(z) N0*N0*exp(2*z/L_gm),latitude=33);
 
% set a geostrophic mode, with no flow at the bottom boundary
wvt.setGeostrophicModes(k=0,l=5,j=1,phi=0,u=u0);
wvt.setGeostrophicModes(k=0,l=5,j=0,phi=0,u=max(max(wvt.u(:,:,1))));
 
% pass the vortex coefficients to the forcing
force = WVFixedAmplitudeForcing(wvt,name="geostrophic-mean-flow");
force.setGeostrophicForcingCoefficients(wvt.A0);
wvt.addForcing(force);
 
```
 
In practice you can initialize the flow in any way you want with any arbitrary structure, and then pass those coefficients to the forcing. The `WVFixedAmplitudeForcing` looks for coefficients that are small and ignores those.
 
       



## Topics
+ Setting the forcing
  + [`setGeostrophicForcingCoefficients`](/classes/forcing/wvfixedamplitudeforcing/setgeostrophicforcingcoefficients.html) set amplitude to fix for the geostrophic part of the flow
  + [`setNarrowBandGeostrophicForcing`](/classes/forcing/wvfixedamplitudeforcing/setnarrowbandgeostrophicforcing.html) sets a narrow waveband of geostrophic forcing for forced-dissipative modeling
  + [`setWaveForcingCoefficients`](/classes/forcing/wvfixedamplitudeforcing/setwaveforcingcoefficients.html) set the amplitude to fix for the wave part of the flow
+ Properties
  + [`A0_indices`](/classes/forcing/wvfixedamplitudeforcing/a0_indices.html) indices of modes in the `A0` matrix to fix
  + [`A0bar`](/classes/forcing/wvfixedamplitudeforcing/a0bar.html) amplitudes of the fixed modes in the `A0` matrix
  + [`Am_indices`](/classes/forcing/wvfixedamplitudeforcing/am_indices.html) indices of modes in the `Am` matrix to fix
  + [`Ambar`](/classes/forcing/wvfixedamplitudeforcing/ambar.html) amplitudes of the fixed modes in the `Am` matrix
  + [`Ap_indices`](/classes/forcing/wvfixedamplitudeforcing/ap_indices.html) indices of modes in the `Ap` matrix to fix
  + [`Apbar`](/classes/forcing/wvfixedamplitudeforcing/apbar.html) amplitudes of the fixed modes in the `Ap` matrix
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvfixedamplitudeforcing/classrequiredpropertynames.html) Returns the required property names for the class
+ Other
  + [`WVFixedAmplitudeForcing`](/classes/forcing/wvfixedamplitudeforcing/wvfixedamplitudeforcing.html) initialize the WVFixedAmplitudeForcing


---