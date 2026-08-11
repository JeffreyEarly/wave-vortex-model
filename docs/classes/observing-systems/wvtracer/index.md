---
layout: default
title: WVTracer
has_children: false
has_toc: false
mathjax: true
parent: Observing systems
grand_parent: Class documentation
nav_order: 4
---

#  WVTracer

Advect a scalar tracer with a WVModel velocity field


---

## Overview

WVTracer evolves a two- or three-dimensional scalar field alongside
the model. The tracer may be antialiased after each flux evaluation.


## Topics
+ Create an observing system
  + [`WVTracer`](/classes/observing-systems/wvtracer/wvtracer.html) create a new observing system
+ Inspect observed state
  + [`absTolerance`](/classes/observing-systems/wvtracer/abstolerance.html) adaptive-integrator absolute tolerance, expressed in the same units as the tracer field


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Observing-system internals
  + [`classRequiredPropertyNames`](/classes/observing-systems/wvtracer/classrequiredpropertynames.html)
  + [`isXYOnly`](/classes/observing-systems/wvtracer/isxyonly.html) logical flag indicating whether advection is restricted to x-y
  + [`phi`](/classes/observing-systems/wvtracer/phi.html)
  + [`shouldAntialias`](/classes/observing-systems/wvtracer/shouldantialias.html) logical flag indicating whether to antialias the tracer


---