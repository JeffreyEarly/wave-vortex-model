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
+ `options.schemaVersion`  exact request schema version, `1` or `2`
+ `options.method`  `fixed-rk4`, `adaptive-rk23`, `adaptive-rk45`, or `adaptive-rk78`
+ `options.finalTime`  requested final integration time
+ `options.initialStep`  explicit RK4 step or adaptive initial step
+ `options.cfl`  CFL number for schema-v2 CFL-selected RK4
+ `options.timeStepConstraint`  `advective`, `oscillatory`, or `min`
+ `options.maximumStep`  adaptive maximum step
+ `options.relativeTolerance`  adaptive relative tolerance
+ `options.absoluteToleranceScale`  adaptive absolute-tolerance scale
+ `options.outputPolicy`  `create`, `replace`, or `append`; default `append`
+ `options.destinations`  string-to-string dictionary keyed by output-file identifier
+ `options.fftProvider`  `native-fftw` or `reference`; default `reference`
+ `options.threads`  positive execution thread count; default `1`
+ `options.reportPath`  report path; default `<request-name>-report.json`

## Discussion

The referenced NetCDF files remain the authoritative scientific model,
including transform configuration, state, forcing, observers, schedules,
and restart progress. This method writes only execution choices and file
routing for `wave-vortex-run --request`.

The metadata-only writer accepts supported
`WVTransformConstantStratification` bundles with complete `Ap`, `Am`, and
`A0` restart state and `WVTransformBarotropicQG` bundles with one compact
`A0` stream declared by `WVCoefficients`. An Eulerian field named `A0`
does not by itself make a Barotropic QG file restart-capable.

Relative model, output, and report paths are interpreted relative to the
request document. Output destinations are keyed by the stable identifiers
returned in validation errors or stored as `portableFileIdentifier` in a
portable-runtime-authored file.
