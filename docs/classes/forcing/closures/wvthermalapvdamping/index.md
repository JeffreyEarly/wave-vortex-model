---
layout: default
title: WVThermalAPVDamping
has_children: false
has_toc: false
mathjax: true
parent: Closures
grand_parent: Forcing
nav_order: 7
---

#  WVThermalAPVDamping

Apply a fixed APV-coordinate closure with a complete thermal complement.


---

## Overview

For each horizontal radius, P diagnoses APV and zero-APV coordinates
from the complete thermal state. L is the minimum-positive-energy right
inverse of P. Vertical damping is L*D*P; P*L=I and the complement I-L*P
is unchanged. Horizontal damping acts on every Ath direction. MDA is
unchanged. This named closure matches the selected APV coordinate rates,
not the full reconstructed APV trajectory. Physical energy includes cross
terms and its vertical damping work is measured, not assumed negative.

The canonical constructor accepts frozen diagnostic arrays. It rebuilds
numerical maps without a scientific mode solve; fromAPVTransform freezes
an explicitly selected, independently constructed APV diagnostic band.

```matlab
force = WVThermalAPVDamping.fromAPVTransform(thermal,apv,apvCutoffFraction=.5);
thermal.addForcing(force);
```




## Topics
+ Create the forcing
  + [`WVThermalAPVDamping`](/classes/forcing/closures/wvthermalapvdamping/wvthermalapvdamping.html) Restore the closure from authoritative diagnostic arrays.
  + [`fromAPVTransform`](/classes/forcing/closures/wvthermalapvdamping/fromapvtransform.html) Freeze an existing APV band and its actual adaptive filter rates.
+ Inspect forcing configuration
  + [`apvCutoffFraction`](/classes/forcing/closures/wvthermalapvdamping/apvcutofffraction.html) APV ordinal cutoff fraction; NaN records the legacy automatic cutoff.
  + [`apvEndpointNumerator`](/classes/forcing/closures/wvthermalapvdamping/apvendpointnumerator.html) Endpoint response numerator in seconds per meter.
  + [`apvForward`](/classes/forcing/closures/wvthermalapvdamping/apvforward.html) Frozen sampled QGPV-to-APV projection, dimensionless.
  + [`apvInverseLr2`](/classes/forcing/closures/wvthermalapvdamping/apvinverselr2.html) Inverse squared APV deformation radii, in m^-2.
  + [`apvVerticalRates`](/classes/forcing/closures/wvthermalapvdamping/apvverticalrates.html) Frozen vertical APV damping rates per physical speed, in m^-1.
  + [`apvZ`](/classes/forcing/closures/wvthermalapvdamping/apvz.html) Frozen physical APV sampling depths in meters.
  + [`dampingAPVMode`](/classes/forcing/closures/wvthermalapvdamping/dampingapvmode.html) Ordinal coordinates of the frozen diagnostic APV band.
  + [`dampingEndpoint`](/classes/forcing/closures/wvthermalapvdamping/dampingendpoint.html) Ordered surface and bottom coordinates of the frozen response.
  + [`horizontalCutoff`](/classes/forcing/closures/wvthermalapvdamping/horizontalcutoff.html) Frozen horizontal cutoff wavenumber in m^-1.
  + [`horizontalResolution`](/classes/forcing/closures/wvthermalapvdamping/horizontalresolution.html) Frozen horizontal filter resolution in meters.
  + [`sourceDepth`](/classes/forcing/closures/wvthermalapvdamping/sourcedepth.html) Fixed column depth in meters.
  + [`sourceG0`](/classes/forcing/closures/wvthermalapvdamping/sourceg0.html) Frozen APV surface acceleration in m/s^2.
  + [`sourceGd`](/classes/forcing/closures/wvthermalapvdamping/sourcegd.html) Frozen APV bottom acceleration in m/s^2.
  + [`sourceGravity`](/classes/forcing/closures/wvthermalapvdamping/sourcegravity.html) Fixed gravity in m/s^2.
  + [`sourceInverseScale`](/classes/forcing/closures/wvthermalapvdamping/sourceinversescale.html) Exponential inverse stratification scale, in m^-1.
  + [`sourceLatitude`](/classes/forcing/closures/wvthermalapvdamping/sourcelatitude.html) Fixed latitude in degrees.
  + [`sourceN20`](/classes/forcing/closures/wvthermalapvdamping/sourcen20.html) Surface squared buoyancy frequency defining the frozen profile.
+ Evaluate forcing budgets
  + [`quasigeostrophicDampingContributions`](/classes/forcing/closures/wvthermalapvdamping/quasigeostrophicdampingcontributions.html) Return the two actual closure contributions with unchanged MDA.


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/closures/wvthermalapvdamping/classrequiredpropertynames.html) Return the frozen arrays and physical configuration.
+ Forcing internals
  + [`coefficientDampingData`](/classes/forcing/closures/wvthermalapvdamping/coefficientdampingdata.html) Return fixed coordinate maps and norm bounds for audit/diagnosis.


---