# T9 implementation and T10 handoff

The public entry point is [`WVTransformFreeSurfaceThermalQG.apvDecomposition`](../../../@WVTransformFreeSurfaceThermalQG/apvDecomposition.m). It diagnoses an arbitrary canonical thermal state through an independently constructed or restored `WVTransformFreeSurfaceQG`. The returned APV/zero-APV coefficients are analysis results; the evolved state remains `Ath/Amda`.

The [accepted design](../../Architecture/Issue440ThermalAPVDiagnosticsPlan.md), [scientific qualification](README.md), [output qualification](OutputQualification.md), and [dependency qualification](DependencyQualification.md) document the contract and evidence. The [verification ledger](VerificationLedger.md) records integration checks.

## Resolved implementation decisions

1. **One public method and a private prepared-map cache.** The thermal peer owns one cache entry, keyed by diagnostic object identity and physical quadrature count. Coefficients, clocks, forcing and damping rates never enter that cache. A restored source starts empty. Fixed scientific parameters are required; changed gravity/rotation parameters are rejected after preparation. A new basis requires new transforms.
2. **Physical F projection and stored-array synthesis.** The builder uses weighted QR on the refined physical-depth F Gram matrix. Endpoint subtraction follows existing QG conventions. The worker reconstructs from the existing APV/zero-APV F/G arrays; the damping closure's minimum-energy lift is never used. APV F/G interpolation and thermal polynomial fields are shared across radius batches instead of duplicating large component maps for every radius.
3. **Original horizontal mean.** The thermal MDA basis and amplitudes are retained separately, with zero mean horizontal velocity, streamfunction and SSH. The diagnostic transform's MDA coordinates are neither copied nor assigned. Both active endpoints are retained in surface/bottom order.
4. **Explicit loss and cross terms.** The full state is APV + zero-APV + original mean + residual. Inventories retain every self and cross term. A small endpoint residual does not establish a small interior residual. Coefficient power is in s^-2 and is not additive physical energy. Undefined zero-reference relative errors remain `NaN` alongside absolute errors.
5. **Directional rates keep the existing process contract.** Callers pass the ordered `coefficientTendency` breakdown, evaluated at the physical clock. The method never evaluates forcing. Directional inventories are signed instantaneous rates; residual-rate norms are positive norms of the rate fields. State histories alone do not establish time-integrated budgets.
6. **Shared committed-record discovery.** `groupContainingCompleteVariableSet` was extracted verbatim from the existing restart reader and is used by both the reader and the authoring analysis loop. Corruption, ambiguity, commit-prefix and file-ownership rules remain shared. The loop holds a private restored source object, limits retained records explicitly, and hashes all source bytes before and after analysis.
7. **Authoritative arrays provide restoration.** Numerical preparation needs stored arrays, shared WVM workers and Chebfun; it does not need an InternalModes solve. Output provenance fingerprints diagnostic numerical arrays and quadrature. Constructor assessment is retained once when available, with explicit absence after restoration. Existing transforms do not retain requested counts, so the result reports `requestedAPVModeCount=NaN` rather than substituting the selected count. Save constructor options and the diagnostic transform separately when requested-count provenance matters.
8. **Compatible provider floor.** The package accepts `InternalModes@^2.0.0-beta.5`. Minimum-version CI uses the immutable beta.5 OceanKit export. Older evidence and experiment pins remain historical. WVM is still the unreleased v5 authoring branch; T9 does not publish a release.

The only existing scientific metadata correction is `apvEndpointResponse` units: **m s**, because it maps QGPV amplitudes in s^-1 to endpoint displacement in m. Shared integration, forcing and persisted scientific schemas do not change.

## Small public example

This bounded example uses public installed APIs and constructs its own state. Counts are controls, not campaign recommendations.

```matlab
lengths = [1e5 1e5 1000];
grid = [8 8 65];
profile = @(z) 1e-4 + zeros(size(z));
thermal = WVTransformFreeSurfaceThermalQG.fromStratification(lengths,grid,N2Function=profile,thermalModeCount=17,mdaModeCount=2);
thermal.Ath(2,1) = 1e-4 + 2e-4i;
thermal.Amda = [0.01;-0.02];
thermal.t = 1234;
apv = WVTransformFreeSurfaceQG(lengths,grid,N2Function=profile,latitude=thermal.latitude,apvModeCount=3,mdaModeCount=1,shouldAntialias=thermal.shouldAntialias,shouldCheckQuadraticAliasing=false);
[diagnosis,fields] = thermal.apvDecomposition(apv,quadratureCount=257);
diagnosis.residuals.qgpv
diagnosis.inventories.totalEnergy
fields.residual.endpointAnomalies
```

The second output defaults to SSH and endpoint anomalies. Supported field names are `psi`, `u`, `v`, `eta`, `eta_i`, `buoyancy`, `qgpv`, `ssh` and `endpointAnomalies`; `x/y/z` accompany the returned fields. A one-output call avoids full spatial volumes. Nonzero coefficient columns use diagnostic Fourier order; physical per-wavenumber inventories use source order, both explicitly recorded in metadata. Radial spectra use the existing bin-sum convention and keep the mean separate.

For authoring-repository output analysis, add `tools` and call:

```matlab
analysis = analyzeThermalAPVOutput(inputPath,apv,indices=1:10,maximumRecords=10,quadratureCount=257);
```

Choose indices from the file's actual committed prefix; invalid or ambiguous streams reject the request. Omitting `indices` analyzes at most the first 100 committed records by default; `indices=Inf` selects the last committed record. The utility returns compact history, provenance and separate hashing/restoration/read/analysis timings. It does not recompute tendencies (`rateSource="none"`). Provider-free reproduction restores a separately saved APV transform, as demonstrated in the output qualification.

## Next increment: T10

[T10/#441](https://github.com/JeffreyEarly/wave-vortex-model/issues/441) remains the nonlinear accuracy, complete-workload cost and campaign-readiness gate. Its first bounded increment should freeze the observable and reference-error allowances, then measure a seeded nonlinear pilot with the intended seasonal forcing, diffusivity, quadratic drag and explicit damping choice. Keep temporal refinement, thermal bandwidth, horizontal resolution, product sampling and closure changes as separate axes.

Use the T9 residual and component inventories at recorded physical times, retain the ordered T7 process rates, and choose an offline APV band independently of the frozen online closure. Report each endpoint independently and carry the residual through every budget. Refine diagnostic stored sampling separately from integration quadrature; adding quadrature cannot repair an unresolved stored mode.

The T9 timing and memory measurements are bounded offline-analysis observations under the recorded host load. T10 must measure actual accepted/rejected steps, setup amortization, process peak memory, output/restart, diagnostic cadence and storage before estimating campaign horizons. Compare candidate configurations at matched physical accuracy where possible. No T9 result selects campaign damping, certifies nonlinear spatial accuracy, or supersedes the historical 257/385-direction linear qualification and 129-direction failure.
