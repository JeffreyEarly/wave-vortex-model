# Shared inverse-y preparation for fields and x derivatives

**Decision: not adopted.** Complete eight-pair measurements show no convincing Hydrostatic model benefit for the additional storage. Main remains on the accepted PR #478 implementation.

Issue [#481](https://github.com/JeffreyEarly/wave-vortex-model/issues/481) tests whether a field and its x derivative can share the first half of their horizontal inverse transforms. It follows the accepted matrix/advection pipeline in PR #478; the unsuccessful derivative-loading prototype in #479 is not included.

For a fixed Fourier-x column, the exact physical kx multiplier is constant over the y wavenumbers. Multiplication by ikx therefore commutes with the inverse-y FFT. The native provider saves its inverse-y result during the field reconstruction, then reuses those columns for the x derivative. Each request still performs its own inverse-x row transform. The y and z derivative algorithms, normalization, derivative capture and x/y/z advection accumulation order remain unchanged.

The stage belongs to the existing prepared-field entry. Its key includes immutable view, canonical field and component. Explicit evaluation/view invalidation clears readiness; addresses and time are never used to infer unchanged state. Each stage rejects foreign workspaces. Failed preparation does not replace the caller's result, and readiness publishes only after successful execution. Actual column FFT counts are incremented beside the producer calls, with warmed reuse and invalidation checked independently of aggregate telemetry.

Native layouts retaining an even-x Nyquist column do not support this reassociation and use the established transform. The original supplied physical k factors are preserved through Hermitian folding. Other providers retain their existing paths.

## Adoption scope and storage

The experimental candidate selected the compact native Hydrostatic runner, reuse policy, and a validated nonlinear forcing dependency. This selection is confined to the unmerged experiment branch. Empty, damping-only and low-memory model construction disables retention. The direct C++ option defaults off. Changing an already-created reuse engine to low-memory does not reclaim its preallocated stages.

All advecting fields must be available before the nonlinear derivatives, so this implementation retains full-depth active Fourier-x/physical-y columns. It preallocates four standard field entries, including an unused Hydrostatic w stage. All capacity is included in reported owned memory. Further reduction of that storage would require a separate scheduling or allocation change.

The first three-pair pilot suggested benefits for both matrix models. Quiet confirmation with exactly the same binaries gave a 3.30% EddyTide integration reduction but no Boussinesq benefit (candidate/baseline ratio 1.000795), for about 182 MB of extra Boussinesq storage. The final candidate therefore keeps Boussinesq disabled in the runner. Its direct C++ opt-in remains correctness-tested, with no performance-support claim.

## Qualification

| Target | Integration change | Paired 95% interval for benefit | Extra owned peak storage |
| --- | ---: | ---: | ---: |
| EddyTide 256 × 256 × 28 | 0.57% faster | −0.70% to +2.11% | 39.46 MB |
| Larger Hydrostatic | 0.30% slower | −2.62% to +2.29% | 181.77 MB |

The intervals include no benefit. This misses the initial roughly 2% credible-model-benefit criterion and does not justify enabling retention. The column FFT execution reduction is real, but extra intermediate storage and movement add costs; their precise contribution has not been isolated by this experiment. The constant control varied by a similar 0.50%, illustrating the scale of measurement noise.

See the [decision](../../.github/ci-evidence/shared-inverse-columns/decision.json), [paired results](../../.github/ci-evidence/shared-inverse-columns/performance-pairs.json) and [summary](../../.github/ci-evidence/shared-inverse-columns/performance-summary.json). All 34 completed comparisons passed unchanged scientific tolerances and exact integration decisions, with zero duplicate executions. Source, fixture, executable and provider hashes were checked after stopping. Interrupted or unrun Boussinesq pairs are excluded. Required hosted CI was not run for a candidate being rejected rather than merged.

The frozen protocol requested two warmup pairs and eight measured alternating pairs per fixture. Both Hydrostatic targets and the constant control completed this protocol. After both targets missed the benefit criterion, the remaining unchanged Boussinesq controls were stopped after two measured pairs; the partial control is not claimed as full qualification. Hydrostatic integration windows are eight times the earlier short fixture; the extended Boussinesq window is retained as an unchanged control. Scientific tolerances, integration controls and decision checks are unchanged. EddyTide must improve; integration or complete-lifetime regressions exceeding 3% require investigation. Only reuse was measured. No policy is adopted from this experiment.

The combined native suite passed 58/58. Native operator and family tests passed under ASan/UBSan; GCC operator and affected family tests passed. The local GCC runner cannot compile against the host Mach SDK macros, so required Linux GCC CI supplies that check. Twelve focused MATLAB kernel/provenance tests passed. Source-linked forward/restart qualification covers all six configurations with both providers.

The [verification ledger](../../.github/planning/issue-481-adoption.md) records the checkpoint decision and one receipt replay caused by stale executable revision metadata. [Issue #488](https://github.com/JeffreyEarly/wave-vortex-model/issues/488) tracks the missing executable-revision guard. Raw profiles, negative screens, payload hashes, exact binaries and source snapshots remain in the workspace benchmark archive `wave-vortex-model-benchmark-artifacts/shared-inverse-columns-20260912`. MATLAB scientific source, checkpoint formats and production experiment files were not changed.

## Recommended next direction

Further retention of full-volume intermediates is not supported by this result. The more substantial alternative is to produce fields, derivatives and advection contributions together over short tiles, reusing intermediates before they leave the working buffers. That needs a coordinated reconstruction/consumer schedule, rather than another independent cache. First screen that schedule at representative sizes; do not repeat full model qualification until it demonstrates a material gain.
