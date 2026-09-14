---
layout: default
title: physicalDiagnostics
parent: WVTransformFreeSurfaceThermalQG
grand_parent: Transforms
nav_order: 168
mathjax: true
---

#  physicalDiagnostics

Measure physical RMS, native-grid peaks, radial spectra and horizontal tails.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `options.flowComponent`  optional family/component selection
+ `options.tailFraction`  fraction of maximum retained horizontal radius; default 0.8

## Returns
+ `diagnostics`  rms, peakAbsolute, horizontalTailFraction and tailWavenumber
+ `radialSpectrum`  kRadial and squared-RMS bin sums for each physical field

## Discussion

RMS uses physical-depth quadrature and includes horizontal means. Spectra
are bin sums on the ordinary kRadial axis, not densities per wavenumber;
their sum is the squared RMS. Tails report the fraction of squared RMS at
physical horizontal radii above tailFraction times the largest retained
radius. This diagnoses occupied horizontal bandwidth, not unresolved error
or an APV vertical-mode spectrum. Peaks are sampled on the native grid.
