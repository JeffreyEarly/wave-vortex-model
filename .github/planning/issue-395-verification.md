# Issue 395 verification ledger

Scope: v4 main `f5b5f46deb08ea397aebec2e73b9515f33df2d94`, isolated checkout; no scientific C++ or MATLAB implementation changes. Three MATLAB test classes gain an optional supplied-binary path; their default behavior remains unchanged.

## Before deployment

- Baseline: `.github/ci-evidence/issue-395-before.json` records eight hosted runs with all attempts and no incomplete jobs after refresh. The final PR #390 revision consumed about 232 runner-minutes across its workflows, including a 45-minute Extended Full timeout. A preceding healthy central CI run consumed 19 runner-minutes. These are elapsed runner times, not billing charges.
- Reference combined CMake build: 44/44 CTest contracts passed; 16.14 seconds locally. Core compiled once and shared with the runtime. The 52-executable artifact passed source/configuration/hash verification.
- Sanitized combined CMake build: 43/44 contracts passed locally. `output-orchestration` reports an RK78 container-overflow with Apple libc++ annotations. Independently reproduced with the original standalone PortableRuntime build; tracked in #396. No test or sanitizer has been suppressed. Local macOS leak detection is unavailable; hosted Linux keeps leak detection enabled.
- Routing/gate/artifact/workflow contracts: 26 Python tests passed, including negative cases for failed, cancelled, skipped or missing jobs, missing methods/releases, stale artifacts, incomplete tests and changed selection.
- actionlint 1.7.12: all proposed workflows passed; downloaded binary SHA-256 verified against official release metadata. Shell syntax and whitespace checks passed.
- Coverage proof: `.github/ci-evidence/issue-395-coverage-review.json` establishes that all 39 standalone runtime tests and five core tests remain, catalog/diagnostic tests run on both MATLAB releases, and retained qualification/package workflows preserve their scientific commands exactly. Only the three listed long continuation methods are deferred by the focused driver; complete runs restore all three.
- Initial consolidated MATLAB harness run passed 137 smoke tests and exposed a suite-array type mismatch. Corrected to `matlab.unittest.Test.empty`. Broad artifact-backed MATLAB validation is in progress; final results must be recorded before integration.
- Automatic review initially rejected applying multiple workflow changes before demonstrating replacement coverage. After the static coverage proof, negative-gate tests and actionlint validation, the reviewed local application was accepted. No GitHub protection change occurred.

## Required before integration

- Complete broad MATLAB harness validation, affected-file Code Analyzer and selected documentation checks; record any limitations.
- Validate the hosted combined pipeline and its real required-check bridge. Distinguish hosted Linux evidence from the independently reproduced macOS runtime defect.
- Record representative route tests and hosted timing/cost evidence without claiming the 5–8 minute target as a measured guarantee.
- Change branch protection only after the aggregate is proven. Preserve strict protection, then disable legacy forced phases via the repository variable.
- Integrate, synchronize v4 main and update #395. Keep #396 separate from this CI-only change.
