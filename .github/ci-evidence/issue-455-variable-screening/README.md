# First variable-transform execution screen

This is an opt-in candidate under #455. Production defaults remain frozen. The [prospective protocol](../../planning/issue-455-variable-matrix-qualification.md) declares the workload and separates this direct-kernel screen from final adoption. Follow-up #463 addresses the QG memory increase.

All 64 large-grid runs pass independent MATLAB and frozen-output comparisons. Each of four profiles runs four selections in four alternating fresh-process blocks, with two warmups and four measured complete nonlinear flux calls per process. The same source/binary implements explicit frozen and candidate branches; this is not the independent-source final adoption campaign.

| Transform/grid | Combined/frozen flux time | Combined/frozen peak RSS |
| --- | ---: | ---: |
| Stratified QG, 256×256×129 | 0.1959 | 1.0510 |
| Stratified QG, 512×512×257 | 0.2098 | 1.0278 |
| Hydrostatic, 256×256×129 | 0.3037 | 0.7812 |
| Hydrostatic, 512×512×257 | 0.3164 | 0.7600 |

Time ratios use geometric means of per-process medians; RSS ratios compare each selection's maximum fresh-process peak. The four-way summaries retain pruned-only and streamed-only results. The horizontal path supplies most of this flux speedup. Hydrostatic streaming reduces real numerical scratch from 10R to 6R without increasing spectral scratch. QG retains both pruned and full-grid derivative workspaces, so it fails a final no-memory-growth gate. No default adoption, complete-model speedup, MATLAB-loaded speedup, confidence-interval result or small-grid performance claim is made.

## Evidence and provenance

`campaign-text.json.gz` is a JSON mapping of text paths to their exact contents. `campaign-index.json` records each text member's SHA-256. It contains raw process reports/stdout/stderr, source diffs and hashes, executable/provider hashes, fixture manifests, compiler/link flags, all comparison metrics, initial/repaired qualification logs and the original author-harness sources used for timing. The measured provider was FFTW 3.3.11 with one internal thread, twelve prepared outer workers for pruned selections and Accelerate matrix multiplication. No process-wide BLAS environment settings were changed. Each fixture records MATLAB's version and independent generator hash.

Complete binary payloads and original manifests remain locally at `/private/tmp/wvm455-variable-{256,512}-screen` and `/private/tmp/wvm455-variable-{256,512}-fixtures`. The original three-family correctness smoke is at `/private/tmp/wvm455-variable-smoke-screen`, using `/private/tmp/wvm455-variable-smoke-fixtures-v2`. Every successful and failed local artifact was preserved; no previous campaign payload was deleted to make space. Binary payloads are not committed to the source repository.

After the successful screens, the author harness gained stricter family/grid/schedule/backend/thread/sample metadata validation, explicit fixture-source provenance and per-sample stderr journaling so a later failure preserves earlier samples. All 64 recorded reports pass the stronger validation; six deliberately corrupted metadata variants are rejected. A deliberate output failure preserves both earlier sample journal entries. A fresh twelve-run correctness smoke passes for the final harness. These author-only changes did not change the measured kernel or relabel the original binary hash; the original timing-harness text remains in the bundle. `harness-validation.json` records these checks.

## Scientific and implementation verification

- Three focused Release C++ contract suites pass, including candidate/control flux parity, borrowed input preservation, spatial-only output, untouched coefficient sentinels, 6R/10R capacity accounting and zero warmed application allocations.
- The same three suites pass with ASan/UBSan. LeakSanitizer is disabled on this host and is not claimed.
- Ten MATLAB parity methods pass across reference/scalar, native/scalar and native/Accelerate with both execution selections. They cover odd/even and nonsquare grids, antialiasing, non-prefix bases, nonzero phases, special modes, density/vertical derivatives, independent nonlinear flux and short trajectories; Boussinesq includes discontiguous exact groups and the Hydrostatic limit.
- Five staged source/provenance/vendor-boundary checks pass. Code Analyzer reports no messages in the four changed MATLAB files.
- Initial failures were test/harness setup defects: expected schedule labels did not match actual fallback/native identifiers; one sanitizer test was built before its input-constraint repair; the new fixture writer initially requested three SQG outputs. The repaired affected checks pass. Review caught and repaired a projected-modal lifetime overlap in Hydrostatic before numerical qualification. Scientific tolerances were not relaxed.

Grouped Boussinesq performance, split-DGEMM/direct-interleaved comparison, shared derivative workspace memory, MATLAB-loaded calls, complete-model continuation/events/output and final default selection remain open under #455/#463.
