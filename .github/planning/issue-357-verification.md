# Issue 357 implementation and verification

Target: `JeffreyEarly/wave-vortex-model#357`, WaveVortexModel 4.3.0. Worktree `wvm-v4-cpp-adoption-audit`, branch `audit/v4-cpp-spectral-adoption`, starting commit `98b496735c9b9f11523429972e2ba1d188be4087` (completed issue #356). The separate v5 checkout remains on `feature/v5.0-free-surface-qg` at `3f3da755e776ac5a17a597dd503369497acdbbad` and was not edited.

## Delivered behavior

- Added internal contract `wave-vortex-spectral-operators-v1` with checked split/interleaved views, capacities, strides, exact ordered mode and family identities, placement, normalization and accumulation policies. Existing kernel contract 4 and portable source API v1 remain unchanged.
- Added immutable retained-horizontal preparation and separately owned workspaces. Execution uses the supplied full FFT provider with explicit gather/embed, Hermitian completion, zero omitted modes, DC/Nyquist handling and three normalization conventions. Caller arrays are preserved; only workspace scratch is destructive inverse input.
- Added immutable vertical reconstruction `[Nz,Nj]`, projection `[Nj,Nz]` and cross-family `[Nj,Nj]` preparation. Explicit source/action/family identities and exact discontiguous groups determine matrix reuse. Conflicting values under one exact identity are rejected; equal matrices with different identities remain distinct. No approximate radius grouping or per-mode matrix expansion occurs.
- Added scalar reference multiplication and optional Accelerate split two-DGEMM/interleaved ZGEMM adapters. Interleaved matrices are prepared once with zero imaginary values. Contiguous valid BLAS views execute directly; other views use bounded prepared packing. This includes the single-column case whose unused column stride is smaller than the required BLAS leading dimension.
- Workspaces retain immutable dependencies and reject stale ownership or active reentry. Separate workspaces may run concurrently. Successful prepared calls make zero application C++ allocations; setup and failure diagnostics may allocate. Vendor internals remain opaque.
- Removed allocating `std::function` batch recursion from the reference FFT provider's horizontal path without changing its numerical algorithm. Reference vertical real-to-real allocation is outside this new service contract.
- Moved the allocation test's global new/delete overrides into one translation unit, avoiding GCC's false mismatched-allocation warning caused by inlining. Isolated FFTW acquisition renaming in a test-only object target so the new numerical tests call unmodified native FFTW symbols.
- Added contract, ownership, normalization and memory-accounting documentation in `CompiledKernel/README.md`, and additive source-selection identity/hashes. No modal checkpoint decoding, pruned FFT schedule, existing kernel replacement, MATLAB preview expansion, package version or website change was made.

## Acceptance evidence

| Criterion | Evidence |
| --- | --- |
| Exact horizontal output | Independent long-double DFT and retained synthesis oracles for 8x6 and 9x7 unequal-domain grids; masked/unmasked exact WVM descriptor sets in reversed order; three vertical planes with a truncated descriptor basis; split/interleaved storage and all normalization conventions; separate explicit DC/Nyquist sets and retained round trips. Tested reference DFT and FFTW. |
| Matrix values and groups | Independent long-double matrix oracle for all three actions with `(Nz,Nj)` equal to `(5,3)`, `(8,4)` and `(1,1)`; split/interleaved, overwrite/add, direct/packed, padded/strided inputs, discontiguous/reordered groups, zero columns/operators; scalar and Accelerate. Separate single-column regression checks packed BLAS leading dimensions. |
| Ownership and immutable data | Input byte comparisons and padding checks; mutation of original scientific matrices cannot change existing preparation; changed source identity rebuilds and produces changed output; old workspaces rejected by rebuilt operators; workspace can outlive operator; two horizontal or vertical workspaces execute concurrently. |
| Validation and failure cleanup | Invalid shapes, strides, spans, capacities, placement, aliases, out-of-domain and duplicate Hermitian modes, imaginary self-conjugate input, stale workspaces, matrix family/action/source mismatch, nonfinite addressed matrix values, conflicting same-identity matrices, repeated/missing group membership. Both FFT plan setup positions fail and retry with balanced plan/engine counters. Application-allocation failures are swept through horizontal/vertical operators and workspace setup. |
| Prepared allocation and storage | Repeated forward/inverse and matrix execution counts zero application new/new[] calls after setup. Prepared storage does not grow. Exact matrix capacity confirms one prepared matrix per identity rather than per mode. Accounting separates shared preparation, numerical workspace, provider/plan lower bounds and opaque allocations. |
| Portable/source compatibility | C++17 GCC build with Accelerate disabled, shell-only fallback, in-repository extension composition and source API contract checks pass. Vendor headers stay outside the portable core. Current ATS main consumes the API unchanged. The historical ATS baseline predates its already-merged migration, as described below. |

## Verification ledger

Local host: Apple silicon macOS, AppleClang 21, GNU GCC 14.2, pinned FFTW 3.3.11 NEON/pthreads and system Accelerate. Builds are outside tracked source, under `/private/tmp`. No Linux-host run is claimed; GCC and the disabled-adapter path were exercised on macOS.

- Release kernel suite `/private/tmp/wvm-357-core`: 5/5 passed (`WVKernelContract`, `WVBarotropicQGKernel`, `WVPreparedModeExecutor`, `WVNativeFFTWOwnership`, `WVSpectralOperators`). The spectral test was rerun successfully after the single-column fix and expanded basis-size cases.
- AddressSanitizer + UndefinedBehaviorSanitizer Debug suite `/private/tmp/wvm-357-asan`: 5/5 passed, then the updated spectral test passed without sanitizer diagnostics. Vendor heap internals are not covered by the application allocation probe.
- GNU GCC 14.2 Release, Accelerate disabled, `/private/tmp/wvm-357-gcc-portable`: 4/4 passed. The final expanded spectral test passed after fixing a warnings-as-errors range-loop copy diagnostic. Native FFTW was not enabled in this build.
- ThreadSanitizer Debug, Accelerate disabled, `/private/tmp/wvm-357-tsan`: spectral numerical, failure and concurrency tests passed without race diagnostics.
- Shell fallback `/private/tmp/wvm-357-shell-fallback`: all four portable tests passed with CMake removed from PATH. Descriptor and QG fixture utilities also compiled. The fallback explicitly disables Accelerate/native FFTW.
- Focused native runtime `/private/tmp/wvm-v4-audit-runtime`: 13/13 passed: `portable-implementation-contract`, `checkpoint-reader`, `forcing-and-rk4`, `unified-integration`, `barotropic-qg-integration`, `barotropic-qg-forcing`, `model-facade`, `field-evaluation`, `lagrangian-particles`, `barotropic-qg-native-fftw`, `extended-runner-composition`, `runtime-architecture-source-policy`, `barotropic-qg-architecture-source-policy`.
- MATLAB `TestCompiledKernelIntegration`: 5/5 passed, including current source hashes, source API/provenance, tracked-source products and portable host/vendor dependency boundaries. No MATLAB source or MEX gateway changed; production MEX parity was already verified in #356 and was not rerun for these additive unused services. Code Analyzer is not applicable.
- `buildtool docs:check` passed once after the implementation documentation batch: 2026 files, 4145 routes, zero failures and zero generated differences.
- Final whitespace checks (including new files), shell syntax, additive source-selection hashes, v4.3.0 manifest preservation, repository scope and generated-artifact checks passed. All required local assets were available. No package snapshots, MATLAB source, runtime source API headers or website files were changed. The separate v5 checkout retained its original branch and HEAD.

Successful tests were not repeated unless a later change affected their coverage. The last test-only edit uses a reference instead of copying a pair in the basis-size loop; the GCC and shell fallback runs include that edit. It does not alter production behavior or the previously successful sanitizer/runtime gates.

### Current external consumer and historical baseline

Current `satmapkit/AlongTrackSimulator` main is `511aa6af9c60353b3de4d371dfe0df43159027cf`. Its already-merged PR #9 removed the obsolete factory callbacks on 2026-08-20. The earlier investigation checked only a historical source-selection pin and missed that existing fix. On the publication follow-up, fetched ATS and fast-forwarded its clean local main from `3366458` to `511aa6a`; no new ATS code change or compatibility shim is needed.

Built the unchanged current ATS checkout in `/private/tmp/wvm-357-ats-current` with `ALONGTRACK_BUILD_WAVEVORTEX_EXTENSION=ON`, `ALONGTRACK_WARNINGS_AS_ERRORS=ON`, `ALONGTRACK_WAVEVORTEX_SOURCE_DIR` pointing to this v4 worktree and `WV_ENABLE_ACCELERATE=OFF`. All seven consumer tests passed, including source-linked end-to-end execution. The ATS checkout is clean and synchronized with origin/main. This replaces the temporary historical-copy migration as the current consumer acceptance evidence.

Publication verification reused the already-passed numerical, sanitizer, portability and documentation gates: no production source changed after those checks. Only this planning ledger was corrected and expanded; it does not generate website output.

Source-selection pins `satmapkit/AlongTrackSimulator` commit `ba57981f336ad5bbbc0907dcd74fcd4fcd137708`. A local git archive was extracted to `/private/tmp/wvm-357-ats-consumer`; the actual ATS checkout was not modified, and no third-party communication occurred.

The unmodified archive fails to compile because `cpp/extensions/wavevortex/src/wavevortex_extension.cpp` supplies seven arguments to `WVObserverFactoryRegistration`, including two obsolete empty callbacks. Current v4 accepts five arguments. The same five-argument header exists in starting commit `98b49673`; its last relevant change predates this task (`53f6b0f0`, v4.3 integration). This is a pre-existing baseline mismatch, not a compatibility change introduced by #357. It would be incorrect to claim that this historical consumer builds unchanged against current v4.

In the temporary archive only, removed the two empty legacy arguments so the factory uses the documented five-argument v1 API. With `ALONGTRACK_BUILD_WAVEVORTEX_EXTENSION=ON`, `ALONGTRACK_WARNINGS_AS_ERRORS=ON`, `ALONGTRACK_WAVEVORTEX_SOURCE_DIR` pointing to this v4 worktree and `WV_ENABLE_ACCELERATE=OFF`, the full consumer compiled and passed 7/7 tests: portable core, core source policy, runner composition, runner end-to-end, extension, routing and extension source policy. This establishes current API consumption after that explicit migration. It does not claim an unchanged historical-baseline build. The in-repository current API consumers compile and pass without modification.

## Reproduction

Configure `tools/compiled-kernel` as shown in `CompiledKernel/README.md`. Native FFTW uses `-DWV_KERNEL_FFTW_ROOT=/path/to/provider`; Accelerate is enabled by default on Apple and can be disabled with `-DWV_ENABLE_ACCELERATE=OFF`. Sanitizer builds set `CMAKE_CXX_FLAGS` to `-fsanitize=address,undefined -fno-omit-frame-pointer` or `-fsanitize=thread -fno-omit-frame-pointer`. GCC sets `CMAKE_CXX_COMPILER` explicitly. Run `ctest --test-dir <build> --output-on-failure`.

The initial implementation goal made no commit, push or tracker changes. The subsequent user-authorized publication commits and pushes this work on `audit/v4-cpp-spectral-adoption` and updates the related v4 issues. Main integration remains a separate step.

The user clarified that backward compatibility is not required for the C++ code under development. MATLAB code, APIs and persisted-file compatibility must be preserved. Future C++ source/record contracts may be changed coherently with current consumers and fixtures; do not add legacy adapters solely to compile obsolete historical pins. Scientific correctness and current MATLAB/C++ agreement remain required.
