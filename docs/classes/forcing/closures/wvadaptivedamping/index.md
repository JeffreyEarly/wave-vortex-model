---
layout: default
title: WVAdaptiveDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 1
---

#  WVAdaptiveDamping

Adapt small-scale spectral damping to the current flow speed.


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVAdaptiveDamping < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

This closure rebuilds its spectral shape when the transform's effective
resolution changes and scales its coefficient tendency by the current
maximum horizontal speed. It is useful when the flow amplitude evolves
substantially, such as during spin-up.

This closure has a number of noteworthy features:

- It does not mix geostrophic and wave modes, which requires setting
the diffusivity equal to the viscosity.
- The properties `k_no_damp` and `j_no_damp` indicate the wavenumber and
mode below which there is zero damping, due to the spectral vanishing
viscosity filter.
- The properties `k_damp` and `j_damp` are *estimates* of the
wavenumber and mode above which significant damping will occur.

The damping operator acts in the spectral domain, directly damping
the wave-vortex coefficients. For free-surface QG, the same closure
acts directly on the canonical coefficient families: `Ag_q` receives
horizontal and APV-mode damping, `Ag_0` receives horizontal damping,
and the horizontally uniform `Amda` family is unchanged.
Native thermal transforms use a complete energy-normalized generalized-
enstrophy basis. The selective contribution dissipates both physical
energy and the combined interior-plus-endpoint quadratic invariant.

Free-surface Boussinesq damps small horizontal scales with one rate
shared by every active mode at a given horizontal wavenumber:
$$\partial_t A_j^{k\ell} = -r(\kappa) A_j^{k\ell},\qquad r(\kappa)=U\Delta\kappa^2 Q(\kappa)/\pi^2.$$
Here U is the maximum physical horizontal speed, Delta is the effective
horizontal grid spacing, and Q is the spectral-vanishing filter.
This preserves cancellation between APV and zero-APV contributions to
boundary anomalies. External surface waves use the same rate as internal
waves. Horizontally uniform inertial and MDA coefficients are unchanged.

For each positive quadratic block I_k, the damping contribution is
$$\dot I_k=-2r(\kappa)I_k.$$
This includes quadratic APV enstrophy, boundary-displacement variance
and wave energy, with their actual normalization and cross terms.
It does not assert monotone full nonlinear energy or exact nonlinear
conservation of unweighted boundary variance. No vertical damping is
supplied for Boussinesq; vertical underresolution needs separate control.
The following horizontal-plus-vertical formulas describe legacy models.

$$
\begin{align}
    \partial_t A_\pm^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_\pm^{k\ell j} - \nu_z \lambda_j^{-2} A_\pm^{k\ell j} \\
    \partial_t A_0^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_0^{k\ell j} - \nu_z \lambda_j^{-2} A_0^{k\ell j}
\end{align}
$$

where

$$
\nu_z = \nu \lambda^2_\textrm{min} k^2_\textrm{max} = \nu \lambda^2_\textrm{min} \left( \frac{\pi}{\Delta} \right)^2
$$

is chosen to make the damping isotropic. The notation here is that
$$\Delta$$ is the horizontal grid resolution and
$$\lambda^2_\textrm{min}$$ is the smallest resolved radius of
deformation. The value of $$\nu$$ is set as

$$
\nu = \frac{U \Delta}{\pi^2}
$$

where $$U$$ is the maximum fluid velocity.

### Example

```matlab
wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
wvt.addForcing(WVAdaptiveDamping(wvt));
```

### Notes

The legacy implementation damps the non-hydrostatic wavemodes the same as the
hydrostatic geostrophic modes. The non-hydrostatic modes would have a
smaller deformation radius, and thus would be damped more strongly.
So arguably they're under-damped in a non-hydrostatic simulation.




## Topics
+ Create the forcing
  + [`WVAdaptiveDamping`](/classes/forcing/closures/wvadaptivedamping/wvadaptivedamping.html) Create adaptive spectral damping for a transform.
+ Inspect forcing configuration
  + [`apvCutoffFraction`](/classes/forcing/closures/wvadaptivedamping/apvcutofffraction.html) Fraction of the largest APV mode below which vertical damping is zero.
+ Inspect forcing or damping scales
  + [`k_no_damp`](/classes/forcing/closures/wvadaptivedamping/k_no_damp.html) Horizontal wavenumber below which damping is exactly zero.
  + [`k_damp`](/classes/forcing/closures/wvadaptivedamping/k_damp.html) Estimated horizontal wavenumber for significant damping.
  + [`j_no_damp`](/classes/forcing/closures/wvadaptivedamping/j_no_damp.html) Vertical mode number below which damping is exactly zero.
  + [`j_damp`](/classes/forcing/closures/wvadaptivedamping/j_damp.html) Estimated vertical mode number for significant damping.
  + [`assumedEffectiveHorizontalGridResolution`](/classes/forcing/closures/wvadaptivedamping/assumedeffectivehorizontalgridresolution.html) Effective horizontal resolution used to construct `damp`, in meters.
  + [`dampingTimeScale`](/classes/forcing/closures/wvadaptivedamping/dampingtimescale.html) Return the inverse maximum unit-speed damping coefficient.
  + [`damp`](/classes/forcing/closures/wvadaptivedamping/damp.html) Unit-speed spectral damping operator in inverse meters.
+ Evaluate forcing budgets
  + [`quasigeostrophicDampingContributions`](/classes/forcing/closures/wvadaptivedamping/quasigeostrophicdampingcontributions.html) Return the horizontal and selective tendencies used by this forcing.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvadaptivedamping/classrequiredpropertynames.html) Returns the required property names for the class
+ Forcing internals
  + [`buildDampingOperator`](/classes/forcing/closures/wvadaptivedamping/builddampingoperator.html) Build the unit-speed spectral damping operator.
  + [`coefficientDampingData`](/classes/forcing/closures/wvadaptivedamping/coefficientdampingdata.html) Materialize native thermal radius operators and construction diagnostics.
  + [`coefficientDampingOperator`](/classes/forcing/closures/wvadaptivedamping/coefficientdampingoperator.html) Return unit-speed damping rates for the Boussinesq families.
  + [`dampAg_0`](/classes/forcing/closures/wvadaptivedamping/dampag_0.html) Unit-speed damping operator for free-surface zero-APV coefficients.
  + [`dampAg_q`](/classes/forcing/closures/wvadaptivedamping/dampag_q.html) Unit-speed damping operator for free-surface APV coefficients.
  + [`fromThermalGeneralizedEnstrophy`](/classes/forcing/closures/wvadaptivedamping/fromthermalgeneralizedenstrophy.html) Construct native thermal generalized-enstrophy damping.
  + [`generalizedEnstrophyCutoffFraction`](/classes/forcing/closures/wvadaptivedamping/generalizedenstrophycutofffraction.html) Fraction of the ordered native generalized spectrum left undamped.
  + [`spectralVanishingViscosityFilter`](/classes/forcing/closures/wvadaptivedamping/spectralvanishingviscosityfilter.html) Build horizontal and vertical spectral-vanishing filters.
  + [`thermalGeneralizedEnstrophyState`](/classes/forcing/closures/wvadaptivedamping/thermalgeneralizedenstrophystate.html) Immutable canonical native thermal closure state.


---