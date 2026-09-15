# Linear mode qualification and experiment adoption

Free-surface Boussinesq and QG construction separate linear qualification, vertical quadratic dealiasing, and horizontal antialiasing. The linear prefix is established first by independent resolution comparison and fixed-grid Gram checks. The selected vertical prefix then follows `quadraticDealiasing`, whose default is `"fixedFraction"`. `shouldAntialias` independently controls the horizontal Fourier bandwidth used by nonlinear dynamics.

Use `quadraticDealiasing="none"` when an experiment needs the complete linearly qualified prefix. This skips spectral-bandwidth measurement and records a filtering count equal to the linear count. It preserves convergence, fixed-grid Gram checks, explicit-count strictness, and physical qualification of configured endpoints. The policy intentionally allows nonlinear registration; registration still requires `shouldAntialias=true`.

`fixedFraction` retains `floor(retainedFraction*linearCount)` modes, with default fraction `2/3` and no implicit minimum. `effectiveBandwidth` measures normalized F/G shapes on the shared WKB Chebyshev-Lobatto grid. It retains the contiguous prefix whose effective degrees, evaluated at cumulative energy fraction `energyFraction`, fit within `floor(bandwidthFraction*(Nz-1))`. The default fractions are `energyFraction=0.99` and `bandwidthFraction=2/3`.

These rules are stated filtering heuristics. They do not certify every quadratic product, coherent superposition, or nonlinear trajectory.

## Explicit and automatic counts

Automatic selection uses the filtering capacity after determining the complete independent linear capacity. Explicit wave, inertial, and APV counts are compared with those same full capacities; their requested size does not become the denominator for `fixedFraction`. A positive request above the linear or filtering limit is rejected. An explicit zero wave page is `not-requested`, while an automatic positive linear prefix reduced to zero is `filtered-out` with limiting metric `quadratic-dealiasing`.

MDA selection remains linear. Configured zero-APV endpoint families retain their separate boundary-response checks. QG `assessVerticalResolution` reports `apvLinearCount`, `apvFilteringCount`, the selected `apvModeCount`, and the complete `dealiasing` evidence independently of its horizontal boundary limit.

## Balanced MDA candidate construction

The 513-point exponential-stratification QG experiment exposed a candidate-tail failure in the provider: asking for 517 MDA candidates encountered a zero-norm guard before WVM could select the usable physical-grid prefix. A separate 385-candidate probe at `nEVP=1551` selected 321 modes with Gram error about 0.0054; its full candidate band failed the 0.01 Gram criterion. The usable band was therefore strictly inside a valid candidate band.

WVM catches only that specific normalization failure for automatic MDA candidate construction and brackets a valid candidate count. A shortened search is accepted only when its physical-grid Gram cutoff lies strictly inside the valid candidate band. Exhausting a valid band without establishing a cutoff is an error. Explicit requests remain strict. The construction report records attempted counts and normalization failures; no arbitrary mode cap or weakened provider norm threshold is introduced. Independent balanced references cover the selected prefixes, avoiding an unnecessary invalid reference tail. After bounded convergence refinement, reports may retain rejected candidate evidence beyond the final selected count.

## Inspection and persistence

Wave page reports and the inertial and APV reports expose `linearCount`, `filteringCount`, and `selectedCount`. Top-level `assessment.dealiasing` records `quadraticDealiasing`, `retainedFraction`, `energyFraction`, `bandwidthFraction`, the grid degree, and `coordinateKind="wkb-chebyshev-lobatto"`. The selected scientific state persists the same policy and parameters through native restoration and resolution changes. Detailed construction evidence remains transient.

For a linear-only experiment, choose the policy explicitly:

```matlab
[wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification( ...
    [1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+zeros(size(z)), ...
    quadraticDealiasing="none",shouldAntialias=false);
```

When an experiment does not represent balanced endpoint anomalies, `g0=Inf, gd=Inf` explicitly omits those zero-APV coordinates without changing the free-surface wave boundary condition. Retain any independently justified Gram tolerance and physical wave validation.

## Historical comparison

The CSV, counts, timing, and beta.4 verification ledger under `Documentation/Validation/LinearModePolicy/` compare the old linear path with a retired sampled coupled-product survey. The former “quadratic” counts, product trials, candidate-band doubling, and `quadraticAliasingTolerance` behavior are historical and do not describe `fixedFraction` or `effectiveBandwidth`. The files remain useful for provenance but are not a current-policy calibration or release result.

Current calibration, package verification, and release evidence must use the new policy names and report the linear, filtering, and selected limits separately.

The [quadratic-dealiasing study](../../tools/quadratic-dealiasing-study/README.md) defines the current calibration and construction-cost evidence.
