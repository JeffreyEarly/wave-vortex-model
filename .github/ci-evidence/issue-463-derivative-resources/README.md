# Bounded derivative resources: initial qualification

The retained horizontal workspace now prepares one full-spectrum horizontal plane for spatial derivatives instead of a full-depth real/half-spectrum pair. Every resolved frequency remains supported, including frequencies outside the retained transform. Preparation and execution are unchanged for the full-FFT baseline. Production variable defaults remain unchanged.

This is an independent-source resource screen, not final #455 adoption. Candidate source is `ed66d2f1`; control source is merged v4 main `b157988355d2fabb6cbc62d56de18b203456897f`. Both use the same author harness, separately compiled against those sources. Scientific fixtures retain their original `55dd8ae` identity and MATLAB payload hashes. The prospective protocol is in [the combined goal plan](../../planning/issue-455-complete-variable-adoption.md).

All 96 large runs and 18 smoke runs pass their scientific comparisons. Large sizes are 256×256×129 and 512×512×257, SQG/Hydrostatic, complete direct flux plus analytical full-frequency horizontal scalar advection. Four blocks use three selections: frozen production, prior pruned/streamed, and bounded-resource pruned/streamed. Each process has two warmups and four measured calls. No application tests or builds competed with timing.

| Workload | Time / prior pruned, 256 / 512 | Peak RSS / production, 256 / 512 |
|---|---|---|
| SQG flux | 1.0338 / 1.0012 | 0.8049 / 0.7718 |
| Hydrostatic flux | 0.9848 / 0.9956 | 0.6594 / 0.6350 |
| SQG horizontal scalar | 0.9076 / 0.8393 | 0.8772 / 0.8593 |
| Hydrostatic horizontal scalar | 0.8860 / 0.8422 | 0.7341 / 0.7162 |

The QG-256 flux comparison exceeds the declared 1.03 prior-candidate gate. Preserve that result: #463 stays open and this increment cannot enable a default. Other time profiles pass, and every profile avoids peak-memory growth against production. Final compact/interleaved and model/event qualification remains in the combined goal. Horizontal manufactured advection excludes vertical advection and filtering; its results do not stand in for those workloads.

Focused Release horizontal/spectral tests, ASan/UBSan horizontal checks and three Release variable-kernel suites pass. The prepared tests cover omitted retained frequencies, Nyquist rules, arbitrary positive strides and padding, input/alias guarantees, plan release and no warmed allocations. A first CTest selection used the wrong test-name spelling and selected no tests; the corrected lowercase selection ran all three kernels and passed. No success is attributed to the empty selection. Initial harness compilation required the modal-record definition include; the analytical oracle was corrected during code review before the recorded smoke. Tolerances were unchanged.

`screen-decision.json` records every acceptance result. Per-size summaries are directly readable. `campaign-text.json.gz` is a compressed JSON mapping of original provenance, worker stdout/stderr, per-sample journals, comparisons, source/binary/provider hashes and checks; `campaign-index.json` hashes every member. All source/binary postflights pass. Binary scientific payloads are not repository products: first payloads per profile/selection and all failures remain locally under `/private/tmp/wvm463-{smoke,256-screen,512-screen}`. Later successful duplicate outputs were hashed and removed only after comparison, under the declared retention policy. No prior evidence was deleted.
