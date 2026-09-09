# Fixed sparse advisory API: first implementation increment

`assessWaveQuadraticResolution` assesses already prepared modes in memory and returns an advisory report. It uses the fixed policy supported by issue 400. This first implementation is an authoring API under `tools/aliasing-study`; it is excluded from the runtime package. Constructor defaults, model state, persistence, and the independent family counts are unchanged.

```matlab
data = prepareSourceStudy(resolveStudyCase("cal-constant-17"));
[report,evidence] = assessWaveQuadraticResolution(data,requestedWaveCount=3,quadraticTolerance=.1);
report.status
report.largestSampledCount
report.prefixDiagnostics
```

Preparation solves the declared modes and independent references once. Subsequent advisory calls reuse those modes, samples, physical grid, quadrature weights, and reference samples. The call itself does not solve an EVP, write files, or mutate preparation/model state. `measureSourceProducts` is the shared in-memory source-product calculation; `runSourceSurvey` remains its file-writing offline client. Physical signed projections, positive norms, endpoints, structural zeros, both wave signs, and the existing APV control retain their established calculation.

Each prepared family now stores `modeConvergence`, the InternalModes `assessModeConvergence` result for its two explicit eigenproblem resolutions. Wave and inertial identities include the prepared physical κ, and boundary identities preserve the surface/bottom labels. Required convergence uses equivalent-depth and per-mode F/G H¹ measurements, so constant-mode derivatives do not create artificial relative-error failures. Historical raw derivative diagnostics remain available separately. Neither the shared comparison nor a successful two-resolution check establishes an absolute accuracy bound.

The shared numerical kernel now uses InternalModes `IMProjection.fromPrescribedDual` for the existing signed physical source operators and its positive coefficient-error norm. Prefix operators are prepared once per assessment call, after the budget reservation, and reused across product batches. Physical inventory selection, reference convergence, independent family counts, and the report remain owned by this WVM authoring API. No provider object is added to model state or restart files. Historical study tables retain their recorded provider revision.

The report exposes:

- `status`: `assessed`, `rejected`, or `reference-inconclusive`, with rejection reasons.
- `largestSampledCount`: the largest leading wave prefix passing the sampled interaction checks and the required gates. It is NaN when references or fixed families fail, and zero when no wave prefix passes. `coverage.candidateLimitReached` identifies acceptance of the entire examined band.
- `requestedWaveCount` and `requestedCountAccepted`: an explicit request remains unchanged even if it is rejected. An omitted request produces guidance only; no count is applied to a model.
- `prefixDiagnostics`: separate Gram and quadratic errors, wave-prefix admission, evaluation counts, and limiting input families/labels/signs, exact integer and physical wavevectors, source channel, and the retained output family/labels/signs. Wave-prefix flags alone do not imply acceptance of the independently checked fixed families or reference quality.
- `outputPageDiagnostics`: the same sampled quadratic evidence grouped by prepared output κ and common wave count. At each count, every nonzero wave input/output page uses that same prefix; APV, MDA, inertial and boundary counts stay fixed. Zero-κ output rows include the mean-family source checks and have `outputWaveCount=0`. Untested pages retain NaN errors and `inconclusive` status. Measured pages inherit the global reference/fixed-family gates, then report their sampled quadratic acceptance; their status does not include the separately reported wave Gram check. The maximum over tested output pages recovers the global quadratic error for that common prefix.
- `coverage`: fixed-v1 policy, selected and total valid interactions, all declared source channels and ordered input-family pairs, omitted outputs and dynamics. The second output supplies every tested mode-pair error and structural-zero record.
- `cost`: explicit product budget, reserved inventory, actual nonzero/zero counts, call/assessment time, and the separately reported prior preparation time.

The default budget is 500,000 individual products, including structural zeros. The full candidate plan is reserved before polarizations or projections are prepared; exceeding the budget throws `WVStudy:ProductBudgetExceeded`. Each reserved product may require the model projection, two quadrature references, and an independent-EVP reference. The budget counts unique individual products, not floating-point operations or each repeated reference integration. All prefixes share the computed coefficient data. Requests outside the prepared candidate band are rejected as invalid inputs. The declared reference-stability allowance must be at most 1% of the requested product tolerance; choosing a tighter tolerance requires correspondingly qualified preparation.

The output-page breakdown does not recommend independently selectable counts at different κ and does not qualify a varying-count nonlinear model. The historical study inventory groups roundoff-equivalent radii using its existing `uniquetol` tolerance of `1e-12` relative to the largest radius; `outputKappa` records those prepared page radii. This grouping and the historical calibration data remain unchanged. Linear convergence/grid assessments of an actual model's requested count map are separate evidence.

The existing constructor currently retains sampled mode arrays rather than the complete continuous basis/reference preparation used by this calculation. An instance-method adapter therefore remains a separate integration step: it must preserve or expose the resolved continuous modes and verify exact grid/count correspondence before using this API. This increment supplies the working authoring API and shared engine without introducing an implicit re-solve or claiming that a reconstructed preparation is an existing model's state.

The inherited coverage limits still apply: individual volume-source products; wave, inertial, and MDA outputs; no APV/boundary source-output qualification, boundary-sheet dynamics, arbitrary-superposition bound, or full nonlinear-operator certification.

## Repeated explicit count-map assessment

For fast trials, prepare a fixed evidence snapshot once:

```matlab
data = prepareSourceStudy(resolveStudyCase("cal-constant-17"));
prepared = prepareWaveQuadraticAssessment(data,ensureOutputCoverage=true);
kappa = prepared.inventory.magnitudes;
kappa = kappa(kappa > 0);
counts = mod((1:numel(kappa)).',4); % An explicit demonstration map, including zero.
report = assessWaveQuadraticResolution(prepared,waveModeKappa=kappa,waveModeCount=counts);
second = assessWaveQuadraticResolution(prepared,waveModeCount=3);
```

The source-data overload and its historical common-prefix report remain unchanged. The snapshot overload returns `pages` for one complete map, `requestedCountAccepted`, configuration and physical grid, fixed family counts, reference diagnostics, and cost/coverage. Physical keys accept reordering and consistent duplicates, with exact matches preferred before a 64-ulp roundoff allowance. Every positive prepared page must have a count; unsupported/ambiguous keys and counts beyond the prepared band reject. Zero-wave pages omit wave outputs, but independent mean outputs and fixed boundary inputs remain represented. At zero kappa `requestedWaveCount` is zero; its output measurements concern the independent inertial/MDA families.

Preparation retains the existing single-precision per-product error evidence, all candidate output prefixes, input identities/signs and selection thresholds. It prepares physical projections and independent reference comparisons once. Later calls filter actual input prefixes and select the actual output prefix with no solves, polarizations, reference integration or new product evaluations. `cost` separates source preparation, logical candidate/reference solve calls, projection preparation, product measurement, evidence assembly, retained bytes, the conservative workspace estimate, and repeat assessment time. The workspace estimate is not a measured process-RSS peak; product batches are bounded by the declared candidate inventory and its preflight estimate.

The snapshot is a fixed value result, with no live source-study/provider/model objects or global cache. Pass it alone to assessment. It has no mutation API: editing its internal fields or the derived `prepareSourceStudy` result is outside the contract. A changed grid, candidate/reference basis, normalization or inventory requires fresh source/evidence preparation; reports identify the configuration and physical grid they actually assess. Changing only counts or tolerance reuses the unchanged snapshot. Saved WVM models are not silently re-solved to create this preparation.

`prepareWaveQuadraticAssessment` reserves products before source polarizations/projections, with explicit `productBudget` and `workingMemoryBudget`. The default fixed selection preserves historical geometry and cumulative mode stresses. Unequal maps filter those stresses using actual input counts and the maximum input wave-count band; this is a declared sparse selection, not all possible pairs. `ensureOutputCoverage=true` appends the first valid triad for any missing output kappa before reservation. This addition covers pages, not all triad geometries. `policy="dense"` provides a budgeted small all-products control; optional explicit interaction indices support bounded studies.

Page status combines grid and sampled-product evidence. Untested requested pages are `inconclusive`, zero-wave pages are `not-requested`, and unqualified product references are `reference-inconclusive`; a directly measured Gram or fixed-family failure can still reject. Product-error values accompanied by unqualified references are estimates, not acceptance evidence. The reference gate conservatively covers the entire prepared candidate inventory, even when a smaller map excludes some of those products. Missing coverage prevents the complete map from being accepted. Limiting interactions preserve actual input ordinals/labels/signs, endpoint names, wavevectors, output labels and source channels.

The snapshot retains the established source scope: wave/APV/boundary inputs, and wave/inertial/MDA outputs. Inertial and MDA inputs, APV/boundary outputs, boundary-sheet evolution, arbitrary-superposition bounds and full nonlinear dynamics are not certified. Do not combine per-page results from different maps into an untested retention recommendation. Reference convergence, linear grid support and sampled nonlinear accuracy remain separate evidence.

Run `waveQuadraticResolutionExample` for the original 1 km, 24-candidate full FFT linear sweep plus three explicit quadratic triads on WVM's smaller dealiased inventory. Untested pages remain unqualified, and open error markers indicate failed reference qualification. Supplying `configuration=config` instead runs a complete-map control with that explicit configuration. Run `benchmarkWaveQuadraticAssessment` for timing and calibration; the example is not a nonlinear count recommendation. Both require the authoring study and released dependencies on the path, use a new output directory, and write CSV/JSON evidence. The [issue #425 record](../../Documentation/Validation/Issue425/README.md) documents measured budgets and scientific limits.


## Mixed reference qualification

Source preparation records `configuration.referenceAbsoluteAllowance` (default `1e-10`; set zero before preparation to require a purely relative comparison). This is a fractional allowance on a physical input-factor bound, not an absolute number in arbitrary field units. The existing `referenceAllowance` supplies the relative part; both are recorded in `referenceDiagnostics.referencePolicy`.

For each product, let `P` be the smaller of the two reference product norms. On each reference grid, use `B = min(sup(abs(a))*norm_mu(b),sup(abs(b))*norm_mu(a))`, where `mu` contains physical volume weights and absolute endpoint weights. Derivative and stratification factors are included in `b`. Use the largest B across the three reference grid/EVP evaluations. Each product-norm discrepancy and retained-coefficient discrepancy must satisfy `delta <= referenceAllowance*P + referenceAbsoluteAllowance*B`. Required mode and boundary-derivative/interpolation convergence gates still apply. This criterion is symmetric in the two reference norms and invariant to separate scalar rescalings of the inputs. It introduces no denominator floor or excluded products.

The default absolute fraction `1e-10` is an explicit, stringent per-product reference budget. It is not a guarantee on a coherent sum or time-integrated solution. `referenceQualificationFraction <= 1` indicates that all measured changes fit their mixed budgets; a nonfinite coefficient discrepancy remains inconclusive. Setting the absolute allowance to zero restores strict relative qualification (using the smaller reference norm conservatively).

The original `referenceStability`, `eigenProductStability` and quadratic sampling errors are preserved. `relativeReferencesStable` retains the old relative-only reference outcome. Per-product evidence records the factor scale, relative discrepancy, mixed-budget fraction and whether absolute qualification was required. Count-map pages expose `absoluteReferenceProductCount` and `relativeReferenceError`; earlier snapshots without these fields report that information as unavailable and keep their original reference decisions.

The quadratic sampling-error threshold remains unchanged and conservative: even a negligible product can still reject a count map if its measured sampling error exceeds that threshold. Thus a page passing this advisory has passed the original sampling test with the explicitly reported mixed reference uncertainty. It does not assert relative accuracy of a product flagged as requiring the absolute reference budget. Full candidate-inventory reference and missing-output-coverage gates remain in force. A changed allowance requires fresh preparation; repeat count-map calls continue to reuse the fixed evidence.
