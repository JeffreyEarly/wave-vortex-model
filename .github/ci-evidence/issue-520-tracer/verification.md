# Tracer axis derivatives: verification ledger

Runtime base: v4 `939eb5797053a6c5a3a019e411ef807aa1fb3a4d`. Worktree `wvm-v4-tracer-optimization`; branch `perf/520-tracer-derivatives`. The primary authoring checkout uses v5 and was untouched.

The candidate replaces native retained-provider public spatial derivatives with independent axis-only real FFT pairs. It reuses persistent retained workers and x-row plans; two y-axis plans and per-worker bounded scratch are prepared once. The derivative uses all resolved input modes independently of the retained coefficient mapping, preserving current MATLAB behavior including antialias-disabled inputs. Tracer multiplication, final antialias projection, initial conditions, vertical operators and integration remain unchanged.

## Passed development gates

- Apple Clang Release: `WVPrunedHorizontal`, `WVSpectralOperators` (2026-09-13). Orders 1–4, nonsquare odd/even grids, full-spectrum modes, Nyquist, strides, immutable inputs, warmed zero allocations and stable prepared storage.
- Apple Clang Release: `WVNativeFFTWOwnership`, `matlab-raw-primitives`, `hydrostatic-kernel`, `hydrostatic-runtime`. Includes failure of either new y-plan acquisition, cleanup and successful retry.
- MATLAB R2025b: `TestHydrostaticCompiledKernel/variableStratificationMatchesMatlab`, `TestWVCompiledConsumers/sampledObserversShareCompiledStateScope`, `TestWVCompiledPublicAdapters/verticalCalculusPreservesMatlabLayouts` (3 passed, no incomplete).
- Independent review resolved extent arithmetic, active-resource cleanup, idempotent preparation, and numerical-overflow status. Existing guru-plan failure wrappers cover the new acquisition path without a production test seam.
- Exploratory composite output graph comparison against the frozen audit compiled baseline passed existing tolerances. The redundant generated output was removed after comparison; its hash, timing, profile and comparison record remain.

## Exploratory results, not qualification

Warm diffX median: 2.9375 ms compiled, 3.4524 ms MATLAB; previous audit compiled 44.6629 ms. Seven samples retained. Composite profile: 42.6575 s, 199 RHS evaluations. Tracer flux: 12.4569 s, including diffX 0.5182 s, diffY 0.9247 s and diffZF 8.6276 s. Earlier compiled profile: 60.8147 s total and 30.420 s tracer. These separate profiles are diagnostic, not idle-host paired qualification.

The measured tracer reduction is approximately 59%, clearing the 50% development target. Freeze the horizontal candidate first; real vertical calculus remains a separate measured opportunity. Frozen archive contents and published benchmark rows are unchanged.

## Pending

Supported GCC/hosted checks; reviewed frozen baseline/candidate qualification with three fresh processes per coefficient/composite configuration; source-linked receipt refresh and reviewable PR. Each new process must retain its timing and numerical result. Limited disk space requires comparing and hashing redundant output payloads before removing them. Any runtime change invalidates the relevant previous gate and frozen binary identity.
