# Automatic resolved-mode selection in v5

The free-surface constructors first establish an independent linear prefix with one `gramTolerance`, whose default is `1e-2`, and an independently solved higher-resolution reference. They then apply one vertical quadratic-dealiasing policy to that complete prefix. Boussinesq wave, inertial, and APV families and QG APV use the same policy and parameters. MDA selection remains linear. Horizontal `shouldAntialias` is a separate Fourier-bandwidth choice.

```matlab
N2 = @(z) 1e-4*ones(size(z));
[wvt, assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification( ...
    [1e5 1e5 1000],[8 8 65],N2Function=N2,latitude=30);
assessment.pages(:,["kappa","linearCount","filteringCount", ...
    "selectedCount","limitingMetric"])
```

The default policy is `quadraticDealiasing="fixedFraction"` with `retainedFraction=2/3`. `quadraticDealiasing="none"` retains the complete linear prefix and deliberately allows nonlinear registration; its report records that no spectral-bandwidth measurement was made. `quadraticDealiasing="effectiveBandwidth"` uses `energyFraction=0.99` to measure each normalized F/G mode's effective degree on a shared WKB Chebyshev-Lobatto sample grid, then accepts the contiguous prefix whose degrees do not exceed `floor(bandwidthFraction*(Nz-1))`, with `bandwidthFraction=2/3` by default. These policies are filtering heuristics rather than rigorous nonlinear qualification claims.

Omitting a count selects it automatically. APV and MDA use the same builder and linear policy as `WVTransformFreeSurfaceQG`, independently of wave and inertial counts. Each positive horizontal wavenumber has its own wave prefix, shared by the two frequency signs. The inertial prefix is independent. Every configured zero-APV endpoint remains present and retains its physical boundary-resolution gate.

Explicit counts are strict and independently configurable:

```matlab
[wvt, assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification( ...
    [1e5 1e5 1000],[8 8 65],N2Function=N2, ...
    apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4);
```

A scalar wave count broadcasts to all positive pages. A vector uses `waveModeKappa` keys and must cover the complete supported positive-wavenumber inventory. Explicit zero counts omit waves on those pages. The constructor still determines the full independent linear and filtering capacities before checking an explicit positive request, so the filter fraction is never applied to the smaller requested count. A request above either limit is rejected rather than silently reduced. Other omitted family counts remain automatic.

## Independent checks

- `gramTolerance=1e-2` bounds fixed-physical-quadrature normalized-Gram error. The resolved bases and prescribed physical pairings are preserved; weights are not fitted.
- `modeConvergenceTolerance=1e-6` checks equivalent depths and physical H1 fields against an independently solved, higher-resolution EVP. References are computed even when the caller requests only the model. Agreement between two resolutions is evidence, not a rigorous absolute error bound.
- `quadraticDealiasing`, `retainedFraction`, `energyFraction`, and `bandwidthFraction` select a contiguous sub-prefix after the linear checks. The `none` and `fixedFraction` policies do not compute spectral bandwidths. `effectiveBandwidth` evaluates normalized F/G shapes in a common simulation WKB coordinate.
- `boundaryResolutionTolerance=1e-2` checks each fixed endpoint at every retained positive wavenumber: physical derivatives, endpoint normalization, and coupled physical and signed energy. Reducing other mode counts cannot hide an unresolved endpoint response.

QG's `assessVerticalResolution` applies the same APV prefix policy and brackets a horizontal limit with the boundary-resolution check. Vertical filtering and the boundary limit remain separate evidence.

Wave and inertial candidates extend through `Nz-1`. `nEVP` is a starting solve resolution, raised to at least `Nz+4` for the full candidate inventory. At most three candidate/reference resolution pairs are tried before construction accepts the converged prefix. An explicit `referenceNEVP` fixes the comparison pair. Balanced families preserve their independent linear candidate solve and reference comparison.

## Quadratic-dealiasing policies

For `fixedFraction`, a family with linear capacity M has filtering capacity `floor(retainedFraction*M)`, including zero when M is zero or the fraction removes the sole mode. There is no implicit minimum. `none` has filtering capacity M. Both policies skip the shape bandwidth calculation.

For `effectiveBandwidth`, WVM reuses the fine candidate fields already prepared for the independent convergence comparison. APV likewise reuses its prepared reference-grid values. The provider measures the Chebyshev coefficient tail of each normalized F and G column on that common coordinate; WVM cumulatively accepts modes only through the first rejected column. The calculation is shared and bounded, and the production path does not call the retired sampled-product survey.

The same filtering rule covers inertial modes. A page explicitly requested with count zero is reported `not-requested`. An automatic page with a positive linear capacity and zero filtering capacity is instead `filtered-out`, and its limiting metric remains `quadratic-dealiasing`.

## Inspection and reproducibility

`assessment.pages` separates `candidateCount`, `convergedCount`, `gridSupportedCount`, `linearCount`, `filteringCount`, and `selectedCount`. An automatic request has `requestedCount=NaN`; `selectedCount` is the number stored in the model. Each page's `dealiasing` report preserves the policy inputs and applicable per-mode evidence. `assessment.inertial` and `assessment.apv` use the same linear/filtering/selected count vocabulary. Top-level `assessment.dealiasing` records the policy, parameters, vertical grid degree, and common coordinate kind. `assessment.cost.quadraticDealiasingSeconds` reports construction time attributable to vertical filtering.

Both models expose `constructionAssessment` after scientific construction. The selected counts, operators, Gram errors, convergence and boundary tolerances, and quadratic-dealiasing policy parameters persist as canonical scientific state. The complete construction report is transient and empty after canonical restore; save it separately when retaining detailed provenance. Restore does not solve modes or rerun selection.

Run `DeveloperExperiments/freeSurfaceModeSelectionExample.m` from the authoring checkout for a figure and optional CSV/MAT output. It uses the same constructor and report as ordinary initialization.

## Historical sampled-product evidence

The artifacts in `Documentation/Validation/AutomaticModeSelection/` and their beta.4 verification ledger describe the retired sampled coupled-product policy. Counts such as `[10 19 19 10]`, the 12 map trials, and the reported product workspace are retained as historical evidence and are not results from any current `quadraticDealiasing` policy. They cannot be reproduced by translating the removed option names.

## Linear experiment configuration

A free-surface gravity-wave experiment can retain one explicit external mode with `quadraticDealiasing="none"`. When the experiment does not represent balanced endpoint anomalies, `g0=Inf, gd=Inf` explicitly omit those zero-APV coordinates. This does not change the external wave EVP's free-surface boundary condition. It is a model configuration decision, never an inference from zero initial amplitudes. Retain the experiment's independently justified Gram tolerance and physical wave validation.

The policy and family coverage describe construction; they do not certify a later nonlinear forcing or arbitrary nonlinear trajectory. Nonlinear registration separately requires `shouldAntialias=true`. No additional mode families or class hierarchy are introduced.

The [linear-policy adoption ledger](LinearModePolicy.md) records the present policy contract and marks the earlier sampled-product comparison as historical evidence.
