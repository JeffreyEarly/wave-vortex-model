# Controlled termination and MATLAB interoperability repairs

Base: v4 main `23aa3f0d2e436e51b423231dcb16c5bd0a90258a`. Scope: #288, #392, #393, #409. MATLAB public APIs, existing valid saved files and unaffected scientific results remain compatible. The v5 checkout, released package snapshots and unrelated #407/#412 work are outside this batch.

## Coordination and review

Three isolated worktrees own controlled termination, scoped coordinate restart, and energy/adaptive-damping repairs. The coordinator reviews shared contracts, cherry-picks verified commits and runs combined qualification. Agents do not publish or merge independently. MATLAB batches are serialized; each C++ build has a separate directory. Required CI follows the complete batch; optional Full CI is not an ordinary gate.

The stop contract must distinguish successful controlled termination from integration, output and callback failures. Saved-output stops must preserve an accepted endpoint and committed output occurrences, and each destination must be independently restartable. Review rejected merely closing after an interior dense occurrence: its output can be newer than its last coefficient checkpoint. The chosen policy drains to an authored complete restart occurrence without extending past the requested final time; absence of such an occurrence is an explicit failure. Schedule lookahead must use bounded scratch cursors, preserve committed cursors and ensure ordinal progress despite floating-point tolerances. Existing exact event grouping remains unchanged.

## Verified scoped restart repair (#393)

Commit `855c653d37a5d7c0add55d20806c3f5d00c5159f` was reviewed and integrated as `0c06681c`. Constant geometry derives j from Nz and excludes j from its persistence contract. Its reader now avoids fetching that unused inherited input from descendant output groups. Other inherited optional values and generic NetCDF ambiguity errors remain unchanged. Variable-stratification/QG geometries retain their authoritative owned coordinates. The direct diagnostics fixture now includes Apt/Amt/A0t, where applicable, in the dense group.

Fifteen distinct focused MATLAB R2025b methods passed: six transform configurations with single/multiple spectral groups (12 configurations), initial/populated restoration and segmented append; an owned-coordinate/ambiguous-child control; all ten existing legacy coordinate/field persistence methods; both fixed/adaptive ordinary observer continuation methods; and the direct diagnostics lifecycle matrix (six transform configurations, two providers, three scenarios: 36 scenarios, tolerance 1e-12). Code Analyzer checked all three changed files with zero blocking findings. The source-hashed receipt is preserved in `PortableRuntime/qualification/scoped-spectral-restart-v1.json` (original `/private/tmp/wvm393-qualification.json`).

During test development, assertions were corrected for filename-bearing ncinfo results, infinite schedule metadata, NetCDF dimension ownership, output-group orientation and QG's available fields. A new warning-free assertion in the legacy nonlinear barotropic fixture encountered its existing undamped-flow warning and was removed; the failing method then passed. No production changes followed the initial scoped fix. These failures are retained in the local test ledger. The subsequent combined documentation gate is recorded below.

## Verified numerical repairs (#392/#409)

Reviewed commit `3289df5cf01af54649901eb4a08170c293845ea3` integrated as `aa775dff`. The energy factory uses authoritative family presence and selected component masks while preserving ordinary wave summation order. Missing standard energy operations restore without replacing user operations. Degenerate adaptive filters preserve uniform vertical flow, retain nondegenerate formulas and refresh after effective-vertical-only changes; a matching narrow C++ filter correction removes artificial damping at effective vertical maximum zero. Undefined horizontal maximum-zero full-rate construction is rejected explicitly; the pre-existing allocated Nj<=2 fallback remains unchanged.

All 12 focused methods and the C++ forcing regression passed. Seven MATLAB files have zero blocking analyzer findings. Direct forcing qualification covers 24 cases/336 channels with maximum relative error 5.217735914948311e-15; the direct diagnostic matrix covers 48 cases/2,232 variables with maximum error 1.2222953475043186e-13. Full details and development failures are preserved in `.github/planning/issues-392-409-verification.md` and its qualification JSON. The two independent `TestPortableDiagnostics` edits merged cleanly; the combined native validation below covers their interaction.

## Combined verification

One combined docs:check passed: 2,026 files, 4,145 routes, zero validation failures and zero generated changes. It ran after the final MATLAB production changes were combined. C++ README/implementation edits do not alter generated MATLAB documentation.

An exact baseline runner was rebuilt from v4 main23aa3f0d with Release, native FFTW and Accelerate. Six established benchmark inputs were copied to an isolated directory and hashed. The final matched comparison is recorded below.

The controlled-stop implementation was integrated as `6a358c09`, with cross-review warmup fixes in `778d7d6d`. Cross-review found that the benchmark warmup could discard a one-shot request or misclassify a callback exception. The final runner skips measured advancement after a warmup stop, preserves the original request, aggregates callback counts and uses the same structured failure report in both phases. Six new regression scenarios and the full runner suite pass in Release and ASan/UBSan. See `.github/planning/issue-288-verification.md` and `.github/ci-evidence/issue-288-matlab-restart.json` for the twelve independently reopened/continued MATLAB files and source bindings.

Required CI discovers all three new MATLAB regression classes in this PR. Review also identified that future production-only changes and complete selections would omit them without explicit registration. Commit `9a0d336e` adds the classes to the existing numerical/persistence lists; all 13 routing tests pass, including both supported releases and unique shard inclusion. This does not add optional Full CI.

The combined Release native FFTW/Accelerate build passes five directly affected C++ suites: forcing/RK4, output orchestration, model output NetCDF, model facade and standalone runner (9.77 seconds total). Six focused MATLAB methods pass: direct all-transform diagnostics, multi-file lifecycle continuation, degenerate adaptive damping, and three source-selection contracts. The combined diagnostic test file has zero blocking analyzer findings. Its two independent edits were the only MATLAB file requiring a combined analyzer repeat. Other changed MATLAB files retain their agents' passing source hashes.

The MATLAB diagnostic and continuation methods ran with the initial combined native runner; the final benchmark-warmup-only CLI addendum was built while the remaining forcing checks completed. The retained provenance records that initial executable and the later final runner separately. These MATLAB paths do not use benchmark warmup; no kernel, writer or MATLAB production code changed after their qualification. The final native runner suite verifies the addendum. Repository boundaries/tracked artifacts and whitespace checks pass after integration.

## Final native non-regression qualification

The separate v5 task confirmed an idle CPU window after its MATLAB jobs finished. Eight alternating measured baseline/candidate pairs per transform, after one excluded warmup pair, compare identical authored runs with 64 accepted RK4 steps and 256 RHS evaluations including scheduled output. Runtime changes were +0.342% constant, +0.059% hydrostatic and +0.077% Boussinesq; retained-memory growth was at most 0.004%. All pass the 3% budget. No passing benchmark was repeated.

Numeric readback covers 43, 55 and 65 variables respectively. Maximum normalized differences are 4.7162e-16, 5.0883e-16 and zero; shapes and finite/NaN/infinity masks match. The first temporary comparison harness failed because it discarded parent paths for nested NetCDF groups. Correcting that harness and rerunning the comparison passed without source or benchmark changes. The original failure log is retained locally.

`PortableRuntime/qualification/coordinated-termination-repairs-apple-silicon-v1.json` binds the combined source, executable/fixture hashes, all samples, source-specific MATLAB receipts, direct numerical results, analyzer, documentation and C++ checks. Historical source-selection hashes remain historical; additive extension provenance identifies issues288 and409. No versioned package snapshots, v5 code, public MATLAB API signatures or generated website files changed.

## Hosted integration

Required hosted CI is the merge gate after publication. Its result and the eventual integration commit are recorded in the PR/issue handoff rather than guessed in this local qualification receipt. Optional Full CI is not requested.
