---
layout: default
title: WVDensityDiffusionIntegrator
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 4
---

#  WVDensityDiffusionIntegrator

Integrate canonical free-surface QG with exact linear density diffusion.


---

## Overview

Accepted and trial coordinates are local to each integration. The transform's
Ag_q, Ag_0, and Amda remain directly mutable and persist unchanged.
Diffusion coordinates are square changes of basis, packed only for the
integrator. Reattach explicitly after canonical snapshot restoration.
Positive computed rates are reported, never clipped.

```matlab
wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=1e-5));
model = WVModel(wvt);
model.setupIntegrator(integratorType="exponential");
```

  - Developer: true


## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Density diffusion integration
  + [`WVDensityDiffusionIntegrator`](/classes/developer-internals/wvdensitydiffusionintegrator/wvdensitydiffusionintegrator.html) Obtain exact eigencoordinates from the registered diffusion forcing.
  + [`explicitCoefficientTendency`](/classes/developer-internals/wvdensitydiffusionintegrator/explicitcoefficienttendency.html) Evaluate registered forcings except those integrated analytically.
  + [`fromModes`](/classes/developer-internals/wvdensitydiffusionintegrator/frommodes.html) Invert the complete modal coordinate change.
  + [`integrateToTime`](/classes/developer-internals/wvdensitydiffusionintegrator/integratetotime.html) Advance canonical coefficients with ETDRK4 and physical error control.
  + [`maximumExplicitDampingRate`](/classes/developer-internals/wvdensitydiffusionintegrator/maximumexplicitdampingrate.html) Bound existing parent-transform damping without changing its strength.
  + [`modalState`](/classes/developer-internals/wvdensitydiffusionintegrator/modalstate.html) Read current canonical properties in complete diffusion coordinates.
  + [`operators`](/classes/developer-internals/wvdensitydiffusionintegrator/operators.html) Galerkin operators, reconstruction arrays, and numerical diagnostics.
  + [`physicalErrorNorms`](/classes/developer-internals/wvdensitydiffusionintegrator/physicalerrornorms.html) RMS full QGPV, buoyancy, speed, and active-endpoint displacement.
  + [`rates`](/classes/developer-internals/wvdensitydiffusionintegrator/rates.html) Packed homogeneous rates, including every MDA direction.
  + [`seasonalCoefficients`](/classes/developer-internals/wvdensitydiffusionintegrator/seasonalcoefficients.html) Exact zero-at-time-zero response to strict seasonal endpoint forcing.
  + [`setModalState`](/classes/developer-internals/wvdensitydiffusionintegrator/setmodalstate.html) Restore the canonical properties from integrator-local coordinates.
  + [`toModes`](/classes/developer-internals/wvdensitydiffusionintegrator/tomodes.html) Transform a family-keyed state or tendency without losing rows.
  + [`validateConfiguration`](/classes/developer-internals/wvdensitydiffusionintegrator/validateconfiguration.html) Require setup again after replacing or changing the diffusion forcing.
  + [`wvt`](/classes/developer-internals/wvdensitydiffusionintegrator/wvt.html) Canonical transform; both endpoints must be active.


---