---
layout: default
title: assessSeasonalResponse
parent: WVVerticalDiffusivity
grand_parent: Closures
nav_order: 2
mathjax: true
---

#  assessSeasonalResponse

Estimate resolved-mode seasonal-response errors by reference refinement.


---

## Declaration
```matlab
 assessment = assessSeasonalResponse(self,forcing,times,options)
```
## Parameters
+ `forcing`  seasonal surface anomaly forcing owned by this transform
+ `times`  nonnegative finite elapsed times in seconds
+ `referenceTransforms`  required cell containing two progressively finer free-surface QG transforms
+ `quadratureCount`  common integration count; zero selects max(129,2*finestNz+1)
+ `stratificationTolerance`  compatibility tolerance for maximum relative N2 difference; default `1e-6`
+ `absoluteTolerance`  optional struct of absolute total-error tolerances
+ `relativeTolerance`  optional struct of relative total-error tolerances
+ `referenceAbsoluteTolerance`  optional struct of absolute reference-refinement tolerances
+ `referenceRelativeTolerance`  optional struct of relative reference-refinement tolerances

## Returns
+ `assessment`  error decomposition, refinement differences, optional acceptance tables, and configuration

## Discussion

This explicit preflight evolves the supplied zero-mean surface
source and this diffusivity from rest, using the same Galerkin
generators as model integration. Times are elapsed seconds from
that initial condition; current coefficients, model time, other
forcing, and nonlinear advection do not enter the assessment.
No coefficients or registered forcing are changed. Derived
operator caches may be populated.

Supply two progressively finer compatible resolved-mode
transforms. Their refinement difference is reported separately;
it is evidence of reference convergence, not a certified bound.
References must share the horizontal layout, physical parameters,
stratification, and two active endpoints. This initial API
assesses the zero-MDA seasonal perturbation only.

The finest reference is projected by a continuous QGPV L2
fit into the candidate APV modes, followed by a zero-APV
endpoint correction. Representation compares that projection
with the reference; evolution compares the candidate response
with the projection; total compares candidate with reference.
Error norms do not add. Evolution relative errors use the
projected reference magnitude; other errors use the fine
reference magnitude. Zero over zero is zero; nonzero over zero
is Inf. Errors are estimates for this source and these times.

Each comparison contains absolute, relative, and reference
magnitude tables. Field errors are horizontal/depth RMS;
endpoint and SSH errors are horizontal RMS. Energy and
enstrophy use horizontal means of half depth integrals,
including free-surface potential energy. Their tendencies are
directional derivatives along the forced linear response.
Per-wavenumber comparisons use the same conventions. Units are
provided in `assessment.units`.

Optional tolerance structs use observable names from those
tables (except `time`), with finite nonnegative scalar values.
Acceptance tests absolute error <= absolute tolerance + relative
tolerance * reference magnitude, separately for each time and
specified observable. Omitted tolerance components are zero.
With no tolerances, acceptance is an empty table. Reference
acceptance is separate from total-error acceptance.
