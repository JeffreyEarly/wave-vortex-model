# Issue #479: retained FFT derivative loading experiment

## Decision

Do not adopt this standalone prototype. The initial complete-model screen did not establish a sufficiently large, reproducible benefit. Preserve this branch as an experiment for possible reuse in a broader inverse-transform pipeline; it is not a release candidate and should not be merged as it stands.

The branch starts from merged PR #478. It fuses the existing complex x/y derivative multiplication into retained inverse-FFT tile loading for Hydrostatic and Boussinesq, avoiding derivative-spectrum scratch materialization and its pointwise dispatch. It preserves the cached source spectrum, multiplication order, Hermitian embedding, normalization, derivative capture and materialized oracle. The native ordinary inverse retains a separate compiled load loop. The prototype reports actual successful multiplied inverse executions.

## Exploratory result

Three alternating baseline/candidate pairs per fixture, using the exact accepted PR #478 executable as baseline:

| Fixture | Geometric-mean integration reduction |
| --- | ---: |
| EddyTide 256 × 256 × 28 | 1.29% |
| Larger Hydrostatic composite | 0.46% |
| Boussinesq 256 × 256 × 129 | 1.19% |

These are provisional screen estimates, not qualified speedups. Spotlight indexing used roughly one CPU core throughout the screen, with intermittent activity from other system services. No competing agent builds or model experiment ran, and no unrelated process was altered. The larger H/B integration windows are short, adding uncertainty. All estimates are below the roughly 2% investigation target; the experiment therefore stops before final qualification. This decision is not proof that the operation can never help.

All nine full-output numerical comparisons passed existing tolerances. Integration controls and state decisions were identical, RHS/output duplicate executions were zero, and producer counts confirmed the fused path. Model-owned peak storage increased only by bookkeeping bytes. No whole-model scratch storage reduction is claimed: that scratch remains necessary for other operations.

## Verification ledger

- Clang Release affected operator, Hydrostatic, Boussinesq and runner-policy tests: 4/4 passed. The later independent test-oracle correction was rerun successfully.
- GCC native operator and both family tests: 3/3 passed. Early compilation found two existing portability issues in touched files: a missing explicit `<system_error>` include and misleading indentation in a test. Both are corrected in this prototype.
- ASan/UBSan affected tests: 4/4 passed. The first invocation stopped before test execution because macOS does not support LeakSanitizer; the corrected invocation disabled only that unsupported option.
- Independent Sol review: no actionable correctness finding. Tests cover independent legacy arithmetic and DFT comparison, signed modes, normalization, retained storage layouts, prepared allocation counts, invalid input, provider capability, transformed self-conjugate values, recovery, cached derivatives and family aliases.
- Final prototype sources matched the archived screen snapshots; frozen binary hashes remained unchanged. Detailed sources, binaries, fixtures, comparisons, logs and protocol are preserved in the local benchmark archive `fft-derivative-loading-20260912`.
- Full native suite, MATLAB scientific comparisons, constant control timings, final source-linked receipts and hosted CI were not run: the candidate did not pass the investigation checkpoint. Existing source-selection qualification records and receipts describe historical accepted implementations, not this unqualified prototype.

Root implemented and scheduled all compute; one reused Sol agent handled bounded direct tests and independent review. No team expansion or repeated final qualification was needed.

## Next direction

Use an explicit storage/lifetime design for coordinated fields and derivatives at the inverse-transform boundary. This small fusion removes a narrow pass but leaves FFT calls, tile gather/transpose, Hermitian scatter, normalization, advection and dispatch structure intact. A later multi-field pipeline should assess those larger costs together while preserving cache identities, success-only capture and x/y/z accumulation order. Reuse this prototype only if it helps that pipeline; do not reopen the same isolated multiplication experiment without a changed assumption or better evidence. Carry the two GCC portability fixes forward independently of any performance claim.
