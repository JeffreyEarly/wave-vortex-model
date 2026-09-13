---
layout: default
title: WVCoefficients
has_children: false
has_toc: false
mathjax: true
parent: Observing systems
grand_parent: Class documentation
nav_order: 6
---

#  WVCoefficients

Integrate and record the wave-vortex coefficients


---

## Overview

WVCoefficients supplies the ordered coefficient families declared by
`coefficientStateAnnotations` to a WVModel integrator.


## Topics
+ Create an observing system
  + [`WVCoefficients`](/classes/observing-systems/wvcoefficients/wvcoefficients.html) Create a coefficient observer with local spectral tolerances.
+ Inspect observed state
  + [`absTolerance`](/classes/observing-systems/wvcoefficients/abstolerance.html) coefficient-error scale used to construct mode-dependent adaptive tolerances


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Observing-system internals
  + [`bottomAbsTolerance`](/classes/observing-systems/wvcoefficients/bottomabstolerance.html) bottom displacement spectral amplitude scale (m3/2); empty selects reference calibration
  + [`classRequiredPropertyNames`](/classes/observing-systems/wvcoefficients/classrequiredpropertynames.html)
  + [`errorTolerances`](/classes/observing-systems/wvcoefficients/errortolerances.html)
  + [`observingSystemWithResolutionOfTransform`](/classes/observing-systems/wvcoefficients/observingsystemwithresolutionoftransform.html) create a new WVObservingSystem with a new resolution
  + [`pvAbsTolerance`](/classes/observing-systems/wvcoefficients/pvabstolerance.html) PV spectral amplitude scale (m s-1); empty selects reference calibration
  + [`surfaceAbsTolerance`](/classes/observing-systems/wvcoefficients/surfaceabstolerance.html) surface displacement spectral amplitude scale (m3/2); empty selects reference calibration
  + [`tolerancePolicy`](/classes/observing-systems/wvcoefficients/tolerancepolicy.html) energy or family adaptive coefficient metric


---