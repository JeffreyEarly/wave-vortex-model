# Issue #303 verification ledger

Scope: complete-model Boussinesq runtime integration on v4 main after #302/PR #381. Longer readiness qualification remains #304. Work is isolated in the v4 checkout; no v5 files, package manifests, dependencies or release snapshots changed.

## Implementation

- Added Boussinesq forcing/integration adapters using the shared catalog, integration state, field service and transactional persistence machinery. Spatial closures include vertical momentum and use the four-field projection. Topographic forcing uses exact grouped wave F boundary values; adaptive tolerances use the kernel's wave/balanced energy factors.
- Added passive scalar advection and allocation-free wave-structure extraction to the Boussinesq kernel. Existing kernels and their numerical formulas are unchanged.
- Persisted complete default MATLAB scientific state, including all grouped wave matrices, membership, depths, preconditioners and opaque N2Function bytes. Full wave-array equality participates in multi-file compatibility checks.
- MATLAB's run-request writer accepts Boussinesq additively and validates its wave arrays. Existing accepted request behavior, scientific routines and default saves are preserved.
- Extended the MATLAB-derived shared forcing catalog to 144 rows: 124 supported and 20 intentional incompatibilities. Boussinesq contributes 23 supported pairs and the double-antialias rejection. No hand-authored applicability overrides.

## Numerical and model verification

- Native/reference Boussinesq field sampling passed (`/private/tmp/wvm-303-numerical.log`). This initial run exposed two integration gaps: the run-request helper's transform allowlist and missing catalog rows. Both were implemented before rerunning the affected methods.
- All applicable forcing tendencies passed across odd/even grids and antialias settings, together with a non-prefix southern-latitude/nonuniform-grid case and all-integrator model continuation (`/private/tmp/wvm-303-parity.log`). The subset fixture explicitly retains all wave matrix axes/scales.
- Remaining native/reference model methods passed: linear passive and horizontal-only observers, CFL/default stepping, create/replace/append and segmented restart, exact wave/opaque persistence, incompatible/malformed models, per-forcing continuations and ordered compositions (`/private/tmp/wvm-303-models.log`).
- Wave-operator mismatch testing checks both MATLAB request validation and C++ preflight, with byte-preserving failure for an existing request and both destination files (`/private/tmp/wvm-303-regressions.log`).

## C++ and extension verification

- 39 of 40 runtime CTests passed initially (`/private/tmp/wvm-303-ctest.log`). The sole failure was an old unsupported-transform fixture using Boussinesq. Changed it to an unknown transform, preserving the rejection assertion; the focused reader test then passed (`/private/tmp/wvm-303-reader.log`).
- Boussinesq forcing/runtime contracts and generated forcing-catalog checks passed (`/private/tmp/wvm-303-contracts.log`). Coverage includes invalid state, aliases, allocation-failure sweeps, zero prepared allocations, adaptive tolerance factors, tracer advection and exact wave structures.
- GCC 14 warnings-as-errors and ASan/UBSan boundary builds passed (`/private/tmp/wvm-303-gcc-boundary.log`, `wvm-303-asan-boundary.log`). GCC caught a redundant nested forward declaration introduced while adding the new forcing friend; it was removed without suppressing diagnostics.
- All seven source-linked ATS tests passed (`/private/tmp/wvm-303-ats.log`).

## Qualification catalog provenance

Adding Boussinesq changes the shared catalog's whole-file digest even though all 24 SQG rows and all 24 Hydrostatic rows remain exactly unchanged. Archived the original catalog bytes and updated only the recorded reports' catalog paths, preserving their original digest, source revision, timings and results. Validation requires the recorded digest plus exact equality of the current transform configurations, rows, inventory and referenced evidence definitions. No old measurement is relabeled as a new run. Focused tests cover altered digests, paths, own rows/evidence and unrelated transform additions; both recorded evidence suites and the regenerated catalog tests passed (`/private/tmp/wvm-303-evidence.log`).

## Remaining gates

Existing MATLAB run-request, Hydrostatic and SQG regression suites passed. The wave-mismatch test initially expected the generic request-contract error, while MATLAB correctly reported its established inconsistent-bundle error; the corrected focused test passed under ASan/UBSan (`/private/tmp/wvm-303-mismatch-final.log`). Final native and instrumented ownership-release checks passed. Source export and docs:check passed (2,026 files / 4,145 routes, zero differences). Code Analyzer is clean for all new/changed test and tooling files; the request helper retains its pre-existing NASGU diagnostic at line 28 (`/private/tmp/wvm-303-authoring.log`). The full instrumented Boussinesq run completed with only that expected-error-identifier failure; all other methods passed (`/private/tmp/wvm-303-sanitized-models.log`). The corrected single-method rerun resolves it. Pending: focused hosted release/sanitizer plus required branch checks. Optional Full CI and long SQG/Hydrostatic trajectories are not additional integration gates. Apple Silicon sanitizer runs disable unsupported LeakSanitizer; Linux CI enables it. No required local assets are missing.

## Hosted test discovery correction

The first hosted smoke run rejected the new historical-catalog test because it lacked a primary test-category tag. Added `TestTags="full"`, matching the existing qualification-evidence tests. The test had already passed when run directly; numerical/runtime code is unchanged.

The focused hosted MATLAB command also required a cell array of character vectors rather than a cell array of string scalars for its two test paths. Corrected that invocation; its C++ release build and both boundary tests had passed.

Local `test:smoke` then passed all 137 tests (`/private/tmp/wvm-303-smoke-final.log`).
