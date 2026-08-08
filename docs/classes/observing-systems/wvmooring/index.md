---
layout: default
title: WVMooring
has_children: false
has_toc: false
mathjax: true
parent: Observing systems
grand_parent: Class documentation
nav_order: 5
---

#  WVMooring

Sample transform fields at fixed horizontal locations


---

## Overview

WVMooring records vertical profiles of selected fields at stationary
points in a three-dimensional periodic domain.


## Topics
+ Create an observing system
  + [`WVMooring`](/classes/observing-systems/wvmooring/wvmooring.html) create a new observing system
+ Inspect observed state
  + [`trackedFieldNames`](/classes/observing-systems/wvmooring/trackedfieldnames.html) tracked field names
  + [`x`](/classes/observing-systems/wvmooring/x.html)
  + [`x_index`](/classes/observing-systems/wvmooring/x_index.html)
  + [`y`](/classes/observing-systems/wvmooring/y.html)
  + [`y_index`](/classes/observing-systems/wvmooring/y_index.html)


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Observing-system internals
  + [`classRequiredPropertyNames`](/classes/observing-systems/wvmooring/classrequiredpropertynames.html)
  + [`cvtTorus`](/classes/observing-systems/wvmooring/cvttorus.html) Centroidal Voronoi tessellation on a 2D torus
  + [`torusDist`](/classes/observing-systems/wvmooring/torusdist.html) Shortest distance on a 2D torus
  + [`trackedFieldNamesCell`](/classes/observing-systems/wvmooring/trackedfieldnamescell.html)


---