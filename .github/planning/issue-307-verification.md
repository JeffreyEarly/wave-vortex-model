# Issue 307: final local qualification

This ledger records current-source execution gates for the standard portable-runtime decision. It does not promote historical family qualification reports or fixture inventories into current readiness. The assembled compatibility matrix and required hosted platform/package checks are separate inputs to the coordinator's final decision.

## Prospective gates

The coordinator approved these bounds before process-memory measurement:

- Rebuild the clean AlongTrackSimulator consumer at `511aa6af9c60353b3de4d371dfe0df43159027cf` against the selected v4 source, using AppleClang Release, the reference FFT provider and warnings as errors. All seven existing consumer tests must pass. This is local source-linked compatibility evidence, not permission to edit the consumer's repository or tracker.
- Reuse the #447 scientific, continuation and runtime/retained-memory evidence only when its measured production sources match the selected checkout. Preserve execution commits and executable hashes; assembly-only changes do not constitute new scientific execution.
- Run the existing shared stratified lifecycle probe for the retained Hydrostatic and Boussinesq representative fixtures with native FFTW. Each must complete six construction/warmup/16-step/destruction cycles, release scientific owners, retain exactly its prepared capacities, and make zero prepared application allocations. These are bounded representative cases, not a claim to have repeated every historical large-grid lifecycle.
- Run five fresh alternating baseline/candidate process pairs for each unchanged constant, Hydrostatic and Boussinesq standard-output workload. Require candidate median process-lifetime peak RSS to be no greater than baseline median plus the larger of 10% of that baseline and 16 MiB. This prospective allowance recognizes allocator/provider/process-baseline variability for small workloads; it establishes bounded nonregression, not an absolute or optimal process-memory bound. Require retained capacities within the existing 3% budget and identical step/RHS work counts.
- Record external RSS samples from process launch to exit with 10 ms pauses between samples. Sampling overhead and `ps` invocation make the effective cadence larger and variable. The parent's `wait4` exit resource usage supplies the primary complete child-lifetime peak; external samples and the runner's integration baseline/post-integration peak are diagnostics. Request-mode runs intentionally retain their exact public requests; `--request` cannot also accept the diagnostic `--phase-file` option.

The process-memory campaign must run on an otherwise idle host after explicit coordination, with frozen baseline/candidate executables. The baseline is the preserved #391 standard-output executable from `be09fe47`, whose compiled sources equal main `4c95835e`; it is not a newly rebuilt executable. All fixtures, binary identities, raw reports and measurements are retained under `.github/ci-evidence/issue-307-qualification/`.

## Remaining decision inputs

The existing ATS hosted workflow pins an older WVM revision and does not qualify the selected WVM merely by being green. The coordinator owns any current-source Linux/platform evidence. WVM required CI supplies Linux GCC Release, Clang ASan/UBSan, MATLAB releases and source-package export. Local Apple Silicon evidence supplies the native FFTW/Accelerate path. No Windows or distributed-binary claim is intended.

An assembly with uncovered supported behavior must remain partial regardless of these execution gates. Historical reports remain historical and original bytes remain unchanged.

## Execution ledger

- ATS configured and built in a fresh `/private/tmp/wvm307-ats-build` directory; all seven tests passed in 13.26 seconds against execution source `f846323900432aaabf76c5c217fcb0b73e721525`.
- Initial lifecycle build command named the shared source file rather than its actual target and failed before compiling. The correct targets are `WVHydrostaticLifecycleProbe` and `WVBoussinesqLifecycleProbe`; the initial log is retained.
- Both native lifecycle cases passed all six cycles, with zero retained growth, zero prepared allocations and released owners.
- Process-memory acceptance was fixed and approved before measurement. A first 30-process campaign passed the bound, but final review found the runner's `processPeak` stops at post-integration before output close. Its unmodified raw artifacts and original harness are preserved as `preliminary-postintegration-memory/` and `measure-postintegration-memory-historical.py`. The corrected harness obtains exact child exit peak through `wait4`; all 30 final processes passed with unchanged prospective bounds and frozen executables on the coordinated idle host.
- Initial collection rejected a broad prefix diff because prerequisite CI repaired `CompiledKernel/source-selection.json`. Collection now verifies the exact enumerated C++/header/CMake inventory and every file's bytes against measured #447 sources, recording the metadata correction separately. This does not relax scientific source identity.

Final median complete process-lifetime RSS, in bytes:

| Workload | Baseline | Candidate | Approved candidate maximum |
| --- | ---: | ---: | ---: |
| Constant nonhydrostatic | 84,410,368 | 84,426,752 | 101,187,584 |
| Hydrostatic | 51,707,904 | 51,593,216 | 68,485,120 |
| Boussinesq | 33,144,832 | 33,275,904 | 49,922,048 |

All measured retained-memory changes were below 3%, with exactly matching step and RHS work counts. The final campaign compares baseline `990de02d401caa4bb6c05f5b832c331e81f6aa8dffede058c42c49097f60b8fe` and candidate `6f57eba3d803c79898a63856d9e6c91b7a0b7907ae045fcd3c8ff1473de2f8d1`; hashes were checked before and after execution. It reuses the existing standard-output fixtures, without requesting density diagnostics; new density-output cost and numerical behavior remain covered separately by #447.

The native lifecycle grids are Hydrostatic 24×18×25 and Boussinesq 16×12×17. Lifecycle timings overlapped ordinary agent work and are not new performance-budget measurements. The historical fixture-authoring script is retained as text for provenance; this task reused the existing NetCDF bytes and did not rerun MATLAB fixture generation.

Local gates pass. The receipt intentionally remains `partial-local-gates-only`, with `standardPortableParity=false`, until the coordinator combines matrix completeness and current required platform/export results. No optional Full CI or long trajectory campaign was run here.

## Assembled partial decision

`standard-parity-decision-20260910.json` binds the historical #306 assembly and its focused local qualification to the original #307 receipts. The matrix contains 1,794 records: 1,206 supported fixture assignments, 22 intentional MATLAB incompatibilities, and 566 unqualified sampling cases under #454. Forty of these are adapter-specific constant-stratification moving-position restrictions; the other 526 lack the relevant diagnostic sampling mode. #306 and #307 remain open. No `STANDARD-PORTABLE-PARITY` claim is made.

The new assembly changes tests, contracts, documentation and CI enforcement without changing C++ or MATLAB production code. The separate integration binding proves equivalence of all 138 measured C++ production files and all 258 original artifacts, while explicitly retaining the prerequisite MATLAB endpoint repair as a separately tested scientific source change. Required hosted integration results are recorded with their actual revisions in the PR and issues.

PR #447 merged as `6cc4fefda70277c8dd373210085016444f1d9c9e` after required CI run `34418658838` passed at head `ec8001a44670e1c7dc04312c1f35349606b5d61a`; #391 and #456 closed. The final run includes Linux Release/sanitizer, both MATLAB releases, sanitized probes and clean/exported packages. `pr447-required-ci-integration.json` retains its exact scope. The new compatibility assembly has its own subsequent PR gate; no prerequisite result is relabeled as an assembly execution.


## Final source-bound decision

`STANDARD-PORTABLE-PARITY` is recorded in `standard-parity-decision.json` for implementation `f70c8908`, tree-identical to qualified PR #509 head `8b40ca8f`. The current assembly contains 1,754 rows: 1,732 supported fixture assignments, 22 intentional incompatibilities, and zero unqualified rows, with 75 registered witnesses. The final hosted receipt binds passing GCC Release, Clang sanitizer, R2025b/R2026a numerical lanes, selected documentation/analyzer phases, and clean/exported package checks. ATS PR #11 is merged with all eleven checks passing and pins scientific source `ebfd9cc9`. All 319 installed adapter/kernel manifest files match the final source. The historical partial decision and its original source identities are retained unchanged under the dated receipt.

The export retry was infrastructure-only: the original job never acquired a runner; already passing numerical jobs were retained. The raw first-attempt logs and final local receipt archive are preserved in the external benchmark artifact directory. Final readiness changes are metadata/documentation only; their focused validation does not require repeating the frozen numerical or performance campaigns. Release/table publication under #501 remains unfinished.

Final readiness verification: 7/7 MATLAB compatibility methods and 6/6 Python provenance/readiness checks pass; the registration gate confirms 1,754 rows and 75 witnesses. Code Analyzer reports informational findings only. Documentation build/check passes (2,052 files, 4,197 routes, zero generated differences). Logs: `/private/tmp/wvm503/final-parity-readiness-v2.log` and `final-parity-readiness-tests.csv`. The first temporary driver omitted the separate compatibility generator; its failed receipt guard is retained in `final-parity-readiness.log`. No failed numerical qualification is hidden by that driver correction.
