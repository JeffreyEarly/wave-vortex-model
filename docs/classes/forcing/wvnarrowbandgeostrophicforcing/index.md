---
layout: default
title: WVNarrowBandGeostrophicForcing
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 6
---

#  WVNarrowBandGeostrophicForcing

Initialize and hold a narrow band of geostrophic coefficients.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>classdef WVNarrowBandGeostrophicForcing < WVFixedAmplitudeForcing</code></pre></div></div>

## Overview

`WVNarrowBandGeostrophicForcing` selects the radial band
$$k_f-\Delta k/2<K_h<k_f+\Delta k/2$$ at vertical mode `j_f` and
holds those `A0` coefficients fixed while they continue to participate
in nonlinear interactions. Active `WVAdaptiveDamping` support is
excluded by the inherited fixed-amplitude selection behavior.

The diagnostic `modelSpectrum` is a function of radial wavenumber
$$k$$ in radians per meter. It returns the legacy geostrophic energy
spectrum in $$\mathrm{m^{3}\,s^{-2}}$$,

$$
E(k)=\begin{cases}
\kappa_\epsilon k_r^{-5/3-m}k^m, & k<k_r,\\
\kappa_\epsilon k^{-5/3}, & k_r\le k\le k_f,\\
\kappa_\epsilon k_f^{4/3}k^{-3}, & k>k_f,
\end{cases}
\qquad m=3/2.
$$

Supplying `r` makes it authoritative and derives the effective `k_r`.
Otherwise `k_r` is authoritative and derives the effective `r`. Both
effective values are stored. The hydrostatic/stratified and barotropic
branches retain their distinct surface scaling.

Construction has an intentional transform side effect unless
`initialPV="none"`. The default `"narrow-band"` draws the configured
random spectrum and assigns only the selected band to `wvt.A0`;
`"full-spectrum"` assigns the complete draw. Both choices consume the
global random stream. `"none"` leaves `wvt.A0` unchanged and fixes its
current values in the selected band. Restart and resolution conversion
use persisted selected state, reconstruct `modelSpectrum` from the
scalar configuration, and do not initialize the target transform or
consume random numbers.

### Example

```matlab
wvt = WVTransformBarotropicQG([40e3,40e3],[8,8],latitude=45,shouldAntialias=false);
force = WVNarrowBandGeostrophicForcing(wvt,k_f=2*wvt.dk,u_rms=0.1);
wvt.addForcing(force);
E = force.modelSpectrum(wvt.kRadial);
```




## Topics
+ Create the forcing
  + [`WVNarrowBandGeostrophicForcing`](/classes/forcing/wvnarrowbandgeostrophicforcing/wvnarrowbandgeostrophicforcing.html) Create narrow-band geostrophic fixed-amplitude forcing.
+ Inspect forcing configuration
  + [`A0_indices`](/classes/forcing/wvnarrowbandgeostrophicforcing/a0_indices.html) Linear indices of the selected `A0` coefficients.
  + [`r`](/classes/forcing/wvnarrowbandgeostrophicforcing/r.html) Effective large-scale damping rate in inverse seconds.
  + [`A0bar`](/classes/forcing/wvnarrowbandgeostrophicforcing/a0bar.html) Prescribed `A0` values in $$\mathrm{m^{2}\,s^{-1}}$$.
  + [`k_r`](/classes/forcing/wvnarrowbandgeostrophicforcing/k_r.html) Effective arrest wavenumber $$k_r$$ in radians per meter.
  + [`Ap_indices`](/classes/forcing/wvnarrowbandgeostrophicforcing/ap_indices.html) Linear indices of the selected `Ap` coefficients.
  + [`k_f`](/classes/forcing/wvnarrowbandgeostrophicforcing/k_f.html) Center wavenumber $$k_f$$ of the forced band in radians per meter.
  + [`Apbar`](/classes/forcing/wvnarrowbandgeostrophicforcing/apbar.html) Prescribed `Ap` values in $$\mathrm{m\,s^{-1}}$$.
  + [`j_f`](/classes/forcing/wvnarrowbandgeostrophicforcing/j_f.html) Forced vertical geostrophic-mode number.
  + [`Am_indices`](/classes/forcing/wvnarrowbandgeostrophicforcing/am_indices.html) Linear indices of the selected `Am` coefficients.
  + [`u_rms`](/classes/forcing/wvnarrowbandgeostrophicforcing/u_rms.html) Target surface root-mean-square speed in meters per second.
  + [`Ambar`](/classes/forcing/wvnarrowbandgeostrophicforcing/ambar.html) Prescribed `Am` values in $$\mathrm{m\,s^{-1}}$$.
  + [`initialPV`](/classes/forcing/wvnarrowbandgeostrophicforcing/initialpv.html) Potential-vorticity initialization choice.
  + [`modelSpectrum`](/classes/forcing/wvnarrowbandgeostrophicforcing/modelspectrum.html) Configured radial geostrophic energy-spectrum function.
+ Configure forcing
  + [`setWaveForcingCoefficients`](/classes/forcing/wvnarrowbandgeostrophicforcing/setwaveforcingcoefficients.html) Select positive- and negative-frequency coefficients to fix.
  + [`setGeostrophicForcingCoefficients`](/classes/forcing/wvnarrowbandgeostrophicforcing/setgeostrophicforcingcoefficients.html) Select zero-frequency coefficients to fix.
  + [`setNarrowBandGeostrophicForcing`](/classes/forcing/wvnarrowbandgeostrophicforcing/setnarrowbandgeostrophicforcing.html) Deprecated 4.x helper for narrow-band geostrophic forcing.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvnarrowbandgeostrophicforcing/classrequiredpropertynames.html) Return configuration and selected state required for restart.


---