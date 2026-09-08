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

The report exposes:

- `status`: `assessed`, `rejected`, or `reference-inconclusive`, with rejection reasons.
- `largestSampledCount`: the largest leading wave prefix passing the sampled interaction checks and the required gates. It is NaN when references or fixed families fail, and zero when no wave prefix passes. `coverage.candidateLimitReached` identifies acceptance of the entire examined band.
- `requestedWaveCount` and `requestedCountAccepted`: an explicit request remains unchanged even if it is rejected. An omitted request produces guidance only; no count is applied to a model.
- `prefixDiagnostics`: separate Gram and quadratic errors, wave-prefix admission, evaluation counts, and limiting input families/labels/signs, exact integer and physical wavevectors, source channel, and the retained output family/labels/signs. Wave-prefix flags alone do not imply acceptance of the independently checked fixed families or reference quality.
- `coverage`: fixed-v1 policy, selected and total valid interactions, all declared source channels and ordered input-family pairs, omitted outputs and dynamics. The second output supplies every tested mode-pair error and structural-zero record.
- `cost`: explicit product budget, reserved inventory, actual nonzero/zero counts, call/assessment time, and the separately reported prior preparation time.

The default budget is 500,000 individual products, including structural zeros. The full candidate plan is reserved before polarizations or projections are prepared; exceeding the budget throws `WVStudy:ProductBudgetExceeded`. Each reserved product may require the model projection, two quadrature references, and an independent-EVP reference. The budget counts unique individual products, not floating-point operations or each repeated reference integration. All prefixes share the computed coefficient data. Requests outside the prepared candidate band are rejected as invalid inputs. The declared reference-stability allowance must be at most 1% of the requested product tolerance; choosing a tighter tolerance requires correspondingly qualified preparation.

The existing constructor currently retains sampled mode arrays rather than the complete continuous basis/reference preparation used by this calculation. An instance-method adapter therefore remains a separate integration step: it must preserve or expose the resolved continuous modes and verify exact grid/count correspondence before using this API. This increment supplies the working authoring API and shared engine without introducing an implicit re-solve or claiming that a reconstructed preparation is an existing model's state.

The inherited coverage limits still apply: individual volume-source products; wave, inertial, and MDA outputs; no APV/boundary source-output qualification, boundary-sheet dynamics, arbitrary-superposition bound, or full nonlinear-operator certification.
