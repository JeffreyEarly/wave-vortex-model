# Issue 395 verification ledger

Scope: v4 main `f5b5f46deb08ea397aebec2e73b9515f33df2d94`, isolated checkout; no scientific C++ or MATLAB implementation changes. Three MATLAB test classes gain an optional supplied-binary path; their default behavior remains unchanged.

## Before deployment

- Baseline: `.github/ci-evidence/issue-395-before.json` records eight hosted runs with all attempts and no incomplete jobs after refresh. The final PR #390 revision consumed about 232 runner-minutes across its workflows, including a 45-minute Extended Full timeout. A preceding healthy central CI run consumed 19 runner-minutes. These are elapsed runner times, not billing charges.
- Reference combined CMake build: 44/44 CTest contracts passed; 16.14 seconds locally. Core compiled once and shared with the runtime. The 52-executable artifact passed source/configuration/hash verification.
- Sanitized combined CMake build: 43/44 contracts passed locally. `output-orchestration` reports an RK78 container-overflow with Apple libc++ annotations. Independently reproduced with the original standalone PortableRuntime build; tracked in #396. No test or sanitizer has been suppressed. Local macOS leak detection is unavailable; hosted Linux keeps leak detection enabled.
- Routing/gate/artifact/workflow contracts: 26 Python tests passed, including negative cases for failed, cancelled, skipped or missing jobs, missing methods/releases, stale artifacts, incomplete tests and changed selection.
- actionlint 1.7.12: all proposed workflows passed; downloaded binary SHA-256 verified against official release metadata. Shell syntax and whitespace checks passed.
- Coverage proof: `.github/ci-evidence/issue-395-coverage-review.json` establishes that all 39 standalone runtime tests and five core tests remain, catalog/diagnostic tests run on both MATLAB releases, and retained qualification/package workflows preserve their scientific commands exactly. Only the three listed long continuation methods are deferred by the focused driver; complete runs restore all three.
- Initial consolidated MATLAB harness run passed 137 smoke tests and exposed a suite-array type mismatch. Corrected to `matlab.unittest.Test.empty`. The corrected broad artifact-backed run passed all 411 tests in 42 classes, plus 137 smoke tests; production Code Analyzer passed with no blocking findings. Documentation validated 2,026 files/4,145 routes with zero generated differences. This local run predates the expectedTests report-field addition; hosted validation covers that final report contract.
- Automatic review initially rejected applying multiple workflow changes before demonstrating replacement coverage. After the static coverage proof, negative-gate tests and actionlint validation, the reviewed local application was accepted. No GitHub protection change occurred.

## Required before integration

- Complete broad MATLAB harness validation, affected-file Code Analyzer and selected documentation checks; record any limitations.
- Validate the hosted combined pipeline and its real required-check bridge. Distinguish hosted Linux evidence from the independently reproduced macOS runtime defect.
- Record representative route tests and hosted timing/cost evidence without claiming the 5–8 minute target as a measured guarantee.
- Change branch protection only after the aggregate is proven. Preserve strict protection, then disable legacy forced phases via the repository variable.
- Integrate, synchronize v4 main and update #395. Keep #396 separate from this CI-only change.

## Hosted proof and subsequent correction

- PR #399 was a temporary, unmerged documentation-only change relative to #398. Run 34248851726 passed its actual aggregate in 354 seconds (5m54s), consuming 6.08 elapsed runner-minutes including migration aliases. C++ release/sanitized, instrumented MATLAB and package jobs were intentionally skipped. R2025b smoke, analyzer, docs comparison and rendering ran successfully. Selection, report and timings are retained in the documentation-proof/route evidence files. PR #399 was closed without merge and its temporary branch removed.
- Initial broad hosted run 34248386552 passed release C++ and both isolated package checks. The expanded sanitizer build exposed a test-helper defect in `TestWVSpectralOperators.cpp`: `memcmp(nullptr,nullptr,0)` violates glibc's nonnull contract. Added an empty-vector guard while preserving bytewise equality. Targeted local sanitized spectral-operator contracts pass; the other runtime defect remains #396.
- A real temporary Git fixture verifies all 353 changed paths, including a deletion and both rename sides; the added regression test passes. Five representative existing paths (documentation, MATLAB, C++, shared persistence and CI) pass routing/gate fault injection. These local fixture results are not hosted timing measurements.
- Affected MATLAB Code Analyzer: the two compiled-kernel test classes have no findings; runtime compatibility retains one pre-existing unused-assignment warning. Removed an unnecessary new suppression in the harness; its focused Code Analyzer recheck has no findings. The empty-vector fix also passes the targeted release contract.

## Measured batching and artifact refinement

- Broad hosted run 34248386552 discovered 411 numerical tests on each release: 410 passed and one optional test was incomplete because its toolbox was unavailable. Both releases passed 137 smoke tests. Serial numerical work alone took 1,556/1,598 seconds. The selected sanitizer failure made the real aggregate and all three legacy aliases fail, providing hosted negative-gate evidence.
- Disposable C++ route run 34251242238 passed all 44 Linux sanitizer CTests and its nine instrumented MATLAB classes. Release CTests also passed, but artifact finalization returned HTTP 403 from an intermediary. The aggregate correctly failed; the run cannot establish a successful required-path timing. No test was retried or suppressed.
- Balanced batches preserve the exact selected inventories; estimates never omit classes. Policy tests reject missing batches, duplicate methods and malformed parameterized-class evidence. Batch-zero local validation passed 137 smoke tests and 18 parameterized diagnostics tests. A separate nonzero batch passed all five integration contracts and correctly omitted common phases. Code Analyzer found no issues in the updated harness.
- Compiler-cache fixtures passed locally with both selected compiler modes, verifying actual reuse and invalidation for source, headers, flags and compiler identity. Hosted validation still must establish cache performance. Finished probe artifacts retain exact checkout/configuration/file hashes.
- Only the 15 consumer probes are now uploaded; local release payload decreases from about 90 MB to 28 MB and sanitizer payload from 419 MB to 132 MB. All 44 CTest executables are still built and tested. Uploads have one bounded infrastructure-only retry and must succeed.
- Final local policy suite: 33 tests passed; actionlint and shell syntax passed. Historical documentation proof predates batching and remains labeled by its original source revision.

- Hosted finalization failures persisted in the next trial; retrying the same unfinished name produced HTTP 409. Retry uploads now use a distinct name, and selection/binary consumers use the successful artifact ID. Content/source/configuration checks remain unchanged; duplicate MATLAB evidence remains an error. The additional wiring contract brings the local policy suite to 34 tests.

- Final broad trial 34255391998 passed all jobs, but the aggregate correctly caught one optional Optimization Toolbox assumption failure per MATLAB release. The correct hosted count is 410 passed plus one incomplete, not 411 passed. Focused selection now honors the existing optional/exhaustive tags; Extended retains those categories. The harness now explicitly fails on any incomplete selected result as well as preserving the aggregate's rejection. Local MATLAB evidence with the toolbox available remains distinct.
