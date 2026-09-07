# Issue 356 implementation and verification

Target: `JeffreyEarly/wave-vortex-model#356`, v4.3.0 main baseline `da764d03404215be708c4bae3e8d046811773e06`. Implementation worktree: `wvm-v4-cpp-adoption-audit`, branch `audit/v4-cpp-spectral-adoption`. The separate v5 checkout was not edited. This work does not adopt pruned transforms or matrix kernels.

## Delivered behavior

- Native out-of-place preserving r2c/DCT-I/DST-I plans explicitly request preservation. Preserving multidimensional c2r and unsupported in-place horizontal placement are rejected at setup. In-place vertical plans require matching strides and identical execution pointers. Out-of-place plans reject overlapping addressed spans before execution. Plan setup validates ranks, positive strides, overflow and buffer capacities.
- Planning surrogates and raw plans have RAII owners. Normal destruction and cleanup after failed wrapper allocation use the same planning mutex. Raw-plan lifetime counters balance across partial construction. A failed plan setup preserves an existing output plan.
- The coefficient executor prepares its background workers once, retains the existing contiguous partitions and waits for every worker before each FFT stage. Serial execution is retained. Partial startup joins already-created workers; operation exceptions wait for all workers before propagation.
- Successful F/G derivative validation now returns success directly; the old internal diagnostic sentinel allocated a string on each valid call.
- Existing scalar preparation, three RHS forms, particle/tracer velocity reuse, canonical coefficients, normalization, forcing order, checkpoint records and source API v1 are retained. No numerical formula, public method signature, package version or snapshot was changed.
- Known executor storage is included in `kernelManagementBytes`. MEX accounting identifies FFTW and native-thread storage as opaque. `CompiledKernel/README.md` documents execution, placement, ownership, preparation and accounting. Source-selection hashes record changed implementation files and issue provenance.

## Acceptance evidence

| Criterion | Evidence |
| --- | --- |
| Preservation, rejection, aliasing, numerical output, immutable inputs | `WVNativeFFTWOwnership`: preserving r2c and DCT/DST, unsupported preserving c2r and horizontal in-place rejection; identical/partial overlap and null checks; round trips; native/reference even/odd hydrostatic/nonhydrostatic results; immutable coefficients, scalar and supplied velocity |
| Allocation/plan/worker setup failure cleanup | Native test fails each surrogate allocation, raw-plan creation and wrapper allocation; sweeps application allocations through complete kernel setup; fails all 17 base-plan positions and scalar-plan setup, then retries; checks native counters, raw handles and surrogate ownership. Executor test fails launches after 0, 1 and 3 successful launches, checks no surviving worker, and checks exception completion barriers. Concurrent plan creation/destruction must never overlap. |
| Prepared execution allocation/thread gate | Native repeated execution covers ordinary, velocity-producing and velocity-consuming RHS, inverse and forward transforms, F/G derivatives, scalar advection with/without antialiasing, and repeated scalar preparation: zero application C++ allocations, no new plans and stable known storage. Executor dispatch performs zero allocations and no additional launches over repeated serial/parallel partitions. |
| Numerical/runtime regressions | Portable kernel fixtures, native QG comparison, focused constant/QG runtime tests, scalar advection, forcing, checkpoint handling and particle/tracer reuse pass. See verification ledger below. |
| Honest storage reporting | Descriptor, scratch, engine, plan wrappers and executor C++ storage are accounted separately. FFTW opaque allocations and thread-runtime heap state, stacks and OS resources remain excluded; no RSS or complete native heap bound is claimed. |

## Verification ledger

Completed locally on Apple silicon with AppleClang 21, C++17 and the pinned FFTW 3.3.11 NEON/pthreads provider. All generated build artifacts are in ignored caches or `/private/tmp`.

- Release C++ suite, `/private/tmp/wvm-356-core`: `WVKernelContract`, `WVBarotropicQGKernel`, `WVPreparedModeExecutor`, `WVNativeFFTWOwnership` passed (4/4).
- AddressSanitizer + UndefinedBehaviorSanitizer Debug build, `/private/tmp/wvm-356-asan`: the same four tests passed without sanitizer diagnostics (4/4). This does not claim a complete FFTW heap leak audit; acquisition/counter tests establish owned-resource balance.
- ThreadSanitizer Debug build, `/private/tmp/wvm-356-tsan`: `WVKernelContract` and `WVPreparedModeExecutor` passed without race diagnostics (2/2).
- Serial kernel build with `WV_KERNEL_COEFFICIENT_WORKERS=1`, `/private/tmp/wvm-356-serial`: native ownership, setup failure and numerical/allocation tests passed for all four grid/physics cases.
- Focused runtime build, `/private/tmp/wvm-v4-audit-runtime`, native provider enabled: `checkpoint-reader`, `forcing-and-rk4`, `unified-integration`, `barotropic-qg-integration`, `barotropic-qg-forcing`, `model-facade`, `field-evaluation`, `lagrangian-particles`, `barotropic-qg-native-fftw`, `runtime-architecture-source-policy`, `barotropic-qg-architecture-source-policy` passed (11/11). The particle test checks two tracers with mixed antialiasing, eager scalar-plan setup, one shared RHS velocity reconstruction and unchanged persistent storage.
- Exact audit geometry `[16,12,9]`, `Nj=5`, `Nkl=36`, one FFTW thread: warmed hydrostatic and nonhydrostatic flux each report **0 application allocations / 0 requested bytes**, versus baseline 28/672 and 36/864. Caller coefficients remain byte-identical. Native plans and planning-surrogate bytes return to zero after destruction. This reran the allocation portion of the original audit probe; its historical preserving-c2r expectation is now intentionally rejected and is covered by the regression test.
- Production MEX build and its native self-validation passed after the namespace correction; maximum MATLAB/native relative error `2.6291e-15` against the existing `1e-12` threshold, deterministic hydrostatic/nonhydrostatic lifecycle checks passed.
- `TestWVCompiledBackend/compiledPreviewExecutesWithoutFallback` passed, including native/MATLAB nonlinear parity, resolution changes, restart/backend restoration and final zero live plans/kernels.
- `TestCompiledKernelIntegration` passed all 5 methods, including source API/provenance, current source hashes and portable dependency boundaries. `TestCompiledKernelContract` passed its descriptor comparison across even/odd and hydrostatic/nonhydrostatic MATLAB cases.
- `buildtool docs:check` passed once after the documentation batch: 2026 files, 4145 routes, zero failures, no generated differences. Website sources and generated pages were not edited.
- Final scope, source-selection hashes, manifest/snapshot preservation, whitespace (including new files), shell syntax and generated-artifact checks passed. No MATLAB source was edited, so Code Analyzer was not applicable. Final Release C++ suite passed 4/4 after the namespace correction and additional derivative rejection/input-preservation assertions. All required local assets were available; no acceptance check remains blocked.

The forward-projection test deliberately gives the balanced coefficients much larger physical amplitude than the wave component. Direct-summation reference FFT roundoff is amplified when recovering the tiny waves. At the even hydrostatic case, both the unchanged baseline kernel and this implementation produce exactly the same measured native/reference discrepancy: `9.81041e-16` absolute / `7.22985e-12` relative. Only this forward-projection comparison uses `1e-10` relative tolerance. RHS, inverse fields, F/G derivatives and scalar comparisons retain `2e-12`; the separate MATLAB comparison uses its existing acceptance tolerances.

Sanitizer and serial runs preceded the final namespace-only compatibility correction; production execution semantics were unchanged by that correction. The new executor forward declaration initially collided with `runtime::detail` in the MEX gateway's using-directives. It now uses `kernel_detail`; final C++ and MEX builds verify the correction.

## Reproduction

From the v4 worktree, set `WV_KERNEL_FFTW_ROOT` to the installed provider prefix when configuring `tools/compiled-kernel`. See `CompiledKernel/README.md` for commands. Sanitizer builds additionally set `CMAKE_CXX_FLAGS` to `-fsanitize=address,undefined -fno-omit-frame-pointer` or `-fsanitize=thread -fno-omit-frame-pointer`. Serial execution sets `-DWV_KERNEL_COEFFICIENT_WORKERS=1` in those compiler flags.

No source was pushed, PR published or issue closed as part of this implementation goal.
