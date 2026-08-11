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

WVCoefficients supplies the Ap, Am, and A0 state variables used by a
WVModel integrator and writes their current values to model output.


## Topics
+ Create an observing system
  + [`WVCoefficients`](/classes/observing-systems/wvcoefficients/wvcoefficients.html) create a new observing system
+ Inspect observed state
  + [`absTolerance`](/classes/observing-systems/wvcoefficients/abstolerance.html) coefficient-error scale used to construct mode-dependent adaptive tolerances


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Observing-system internals
  + [`classRequiredPropertyNames`](/classes/observing-systems/wvcoefficients/classrequiredpropertynames.html)
  + [`errorTolerances`](/classes/observing-systems/wvcoefficients/errortolerances.html)
  + [`observingSystemWithResolutionOfTransform`](/classes/observing-systems/wvcoefficients/observingsystemwithresolutionoftransform.html) create a new WVObservingSystem with a new resolution


---