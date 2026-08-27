---
layout: default
title: writePortableRunRequest
parent: WVModel
grand_parent: Class documentation
nav_order: 61
mathjax: true
---

#  writePortableRunRequest

Write a portable-runtime request for a MATLAB-authored NetCDF bundle.

> Developer documentation: this item describes internal implementation details.


---

## Declaration
```matlab
 WVModel.writePortableRunRequest(path,modelFiles,options)
```
## Parameters
+ `path`  destination JSON request path
+ `modelFiles`  ordered complete set of source NetCDF paths
+ `options.schemaVersion`  exact request schema version; default `2`
+ `options.method`  `fixed-rk4`, `adaptive-rk23`, `adaptive-rk45`, or `adaptive-rk78`; v2 default `adaptive-rk78`
+ `options.finalTime`  requested final integration time
+ `options.initialStep`  explicit RK4 step or adaptive initial step
+ `options.cfl`  CFL number for schema-v2 CFL-selected RK4
+ `options.timeStepConstraint`  `advective`, `oscillatory`, or `min`
+ `options.maximumStep`  adaptive maximum step
+ `options.relativeTolerance`  adaptive relative tolerance
+ `options.absoluteToleranceScale`  adaptive absolute-tolerance scale
+ `options.outputPolicy`  `create`, `replace`, or `append`; default `append`
+ `options.destinations`  string-to-string dictionary keyed by output-file identifier
+ `options.fftProvider`  `native-fftw` or `reference`; v2 default `native-fftw`
+ `options.threads`  positive execution thread count; v2 default automatically bounded hardware concurrency
+ `options.reportPath`  report path; default `<request-name>-report.json`

## Discussion

The referenced NetCDF files remain the authoritative scientific model,
including transform configuration, state, forcing, observers, schedules,
and restart progress. This method writes only execution choices and file
routing for `wave-vortex-run --request`.
Run-request v2 is the default. Omitted execution controls select MATLAB's
standard `ode78` configuration: relative tolerance `1e-3`, absolute
tolerance scale `1e-6`, an initial step from CFL `0.5` after state
restoration, and a maximum step equal to one tenth of the continuation
interval. The standalone runtime selects native FFTW with an automatically
bounded thread count. These defaults do not recover custom MATLAB-session
settings that were never persisted.

The metadata-only writer accepts supported
`WVTransformConstantStratification` bundles with complete `Ap`, `Am`, and
`A0` restart state and `WVTransformBarotropicQG` bundles with one compact
`A0` stream declared by `WVCoefficients`. An Eulerian field named `A0`
does not by itself make a Barotropic QG file restart-capable.

Relative model, output, and report paths are interpreted relative to the
request document. Output destinations are keyed by the stable identifiers
returned in validation errors or stored as `portableFileIdentifier` in a
portable-runtime-authored file.
