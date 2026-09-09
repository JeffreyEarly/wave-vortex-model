# Short-wave product-reference diagnosis

The restored 1 km example's large reference discrepancies are caused by **opposite-boundary products dominated by small spectral tail errors**. The boundary modes themselves agree closely with independent analytical solutions. Their physical surface–bottom overlap is so small that normalizing by the product's own norm demands relative accuracy far beyond what the spectral representation supplies in those tails.

This investigation changes no numerical solver, mode, count-map decision or acceptance threshold. It adds a reproducible per-product diagnosis with separate normalization and coefficient discrepancies. The original linear 13-to-8 count curve and the existing reference-inconclusive outcome remain valid statements of their respective tests.

## Isolated cause

The original row summaries take a maximum over products and output prefixes. Their `modeA`/`modeB` columns identify the largest *sampled projection error*, not the largest reference discrepancy. The new diagnostic reports all four surface/bottom input pairs separately, preventing those two limiting products from being confused.

For interaction 996, integer wavevectors (-2,-1) + (-1,-1) = (-3,-2), the worst reference channel is `u*dx(u)`. Its bottom–surface product has:

| Quantity | Value |
|---|---:|
| Product norm, EVP order 192 | 5.70e-31 |
| Product norm, EVP order 256 | 4.91e-32 |
| Independent analytical exponential product norm | 4.84e-160 |
| Existing normalization discrepancy | 10.60 |
| Existing retained-coefficient discrepancy | 0.440 |
| Absolute error divided by sampled factor bound | 4.44e-13 |

These norms use the study's existing physical source metric and canonical unit endpoint responses. The diagnostic's factor bound is `max(abs(a)) * sqrt(sum(w.*abs(b).^2))` on the reference quadrature nodes, with the derivative multiplier included in `b`. It is invariant to separate nonzero scalar rescalings of the input columns. It is an interpretive scale, not a newly adopted tolerance or a continuum/operator error guarantee.

The largest quadrature-reference discrepancy, about 0.00402, occurs in interaction 590's `v*dy(eta)` bottom–surface product. Its analytical product norm is about 4.18e-242; the numerical norm is about 4.51e-32. Here too, relative comparisons measure changes in numerical tails rather than resolve the extraordinarily small physical overlap. The analytical norm calculation scales columns before squaring to avoid premature underflow.

Every reference-failing row in the original three-triad survey is a boundary–boundary row. The independently checked same-boundary products pass the original reference allowance. The other input-family pairs pass that allowance as well. This is a diagnosis of this bounded survey, not a claim about untested triads or full nonlinear dynamics.

## Independent checks

The reproduction compares the baseline EVP pair 192/256 against 256/384, and reference quadratures 257/513 against 513/1025. Increasing resolution changes the large product-relative discrepancies irregularly while the mode errors and absolute product errors remain small. The output metric is diagonal with reciprocal condition numbers around 5e-6 for these exponential cases; the calculations do not fail the existing 1e-13 conditioning check. Separating the discrepancies identifies normalization as the largest contribution in the two isolated worst cases.

The exponential reference uses the released provider's scaled modified-Bessel analytical solution. A constant-stratification control uses independent endpoint-localized exponentials. For constant N, write `F=a*exp(m*(z-top))+b*exp(-m*(z-bottom))`, `m=k*N/abs(f)`, and `G=-g*Fz/N^2`; the coefficients enforce `G(top)-F(top)` and `G(bottom)` equal to the requested unit endpoint responses. This avoids subtracting nearly identical global hyperbolic columns.

The existing constant-stratification analytical evaluator also loses relative tail accuracy when its global hyperbolic columns cancel. Its independently evaluated cross-boundary product norms were about 1e-33 in a preliminary trial, despite the much smaller localized-exponential tails. Consequently it is not treated as an exact tiny-overlap reference here. Very small localized-exponential values can themselves underflow in double precision; a recorded zero analytical norm in this control means floating-point underflow, not an identically zero mathematical product. Provider code is unchanged.

## Consequence for the model

Increasing EVP resolution until every negligible product passes the current relative gate is not a useful resolution-selection strategy. Nor should we delete opposite-boundary interactions or introduce an arbitrary denominator floor. The actual resolved modes and both boundary families should remain in the model.

The next policy increment should retain the product-relative error as a diagnostic and add an explicitly defined absolute/bilinear-scale criterion for reference qualification and negligible interactions. That criterion must be tied to the model's physical state and tendency norms, cover derivatives and endpoint terms, and be tested against perturbations and assembled tendencies. Small products must not be silently exempted when a coherent sum or state amplitude makes their effect important. The factor scale reported here is evidence for designing that criterion, not a finished certification API.

The direct core-model work remains assembled-tendency convergence and APV/both-boundary output qualification (#426). This investigation supplies a concrete reason to keep mode convergence, grid support and nonlinear evidence distinct rather than reducing wave counts to accommodate an unrelated reference-normalization failure.

## Reproduce

Configure this WVM authoring checkout with the same declared InternalModes beta.4/OceanKit revisions used for issue #425, add `tools/aliasing-study` to the MATLAB path, then run:

```matlab
investigateShortWaveProductReferences("new-investigation-directory");
```

The function refuses an existing directory, reproduces the original three-triad survey, diagnoses every failing boundary row, and runs the two worst channels through the four baseline/refinement/profile configurations. It writes the complete baseline row gates, per-endpoint diagnostics, refinement table, configurations/provenance and focused verification results. Source and measurement artifacts are separate so the recorded source revision can be replayed.

The authoring functions do not change the core advisory or provider. Historical controls and count-map evidence are preserved. See [evidence/](evidence/) for recorded results and [verification.json](evidence/verification.json) for the scientific checks; these checks use the existing mode/reference tolerances without changing acceptance behavior.
