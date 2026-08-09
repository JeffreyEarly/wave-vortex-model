---
layout: default
title: WVFastTransformDoublyPeriodicFFTW
parent: WVFastTransformDoublyPeriodicFFTW
grand_parent: Developer internals
nav_order: 2
mathjax: true
---

#  WVFastTransformDoublyPeriodicFFTW

Create a half-x FFTW horizontal-transform adapter.

> Developer documentation: this item describes internal implementation details.


---

## Parameters
+ `wvg`  doubly periodic WaveVortex geometry
+ `Nz`  positive number of horizontal transform batches
+ `nCores`  FFTW thread count
+ `planner`  FFTW planning strategy
+ `alignmentMode`  FFTW new-array alignment policy
+ `plannerTimeLimitSeconds`  planning limit for each plan
+ `forwardMappingMethod`  compact forward mapping implementation used by authoring benchmarks
+ `inverseMappingMethod`  compact inverse mapping implementation used by authoring benchmarks

## Returns
+ `self`  configured adapter

## Discussion

The mapping-method options are authoring benchmark controls.
Production construction uses the general layout method for
forward extraction and the benchmark-selected specialized
compact-row assignments for inverse assembly. The options
remain available so authoring benchmarks can compare both
implementations with complete adapter calls.
