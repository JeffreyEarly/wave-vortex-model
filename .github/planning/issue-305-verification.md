# Issue 305: diagnostic evaluation and output

Branch: `issue-305-diagnostic-evaluation`, based on v4 main `980e9061b6a109f0bbaeb87a6ac76d3565e9aaac` (#314).

## Implementation

The existing field service constructs an immutable, transform-aware diagnostic plan from catalog ordinals and configuration contracts. Total, geostrophic, wave, inertial and mean-density-anomaly component requests share underlying field plans. Surface outputs slice reconstructed volumes; energy, extrema and mean-density reductions share their inputs. Coefficient and intermediate scratch belongs to the evaluation invocation. The observer evaluator and generic sink carry complex diagnostic values using the existing split-complex NetCDF encoding. Rebinding an observer service reconstructs its diagnostic plans before releasing the previous transform owner.

The only MATLAB runtime change restores missing built-in component-energy operations when constructing a saved Eulerian observer. Existing operations are preserved; numerical formulas and saved-file contracts are unchanged. The catalog retains all 76 identities, all 666 configuration records, all original ordinals and all original MATLAB annotations. The 23 legacy metadata records remain byte-for-byte equal to their #314 fixture.

Six output identities have explicit, tested intentional incompatibilities, as permitted by #305:

- `phase`, `conjPhase`: MATLAB annotations declare real values while their operations compute complex values. Internal phase use for `Apt`/`Amt` remains supported.
- `rho_nm`: saved v4 files do not identify MATLAB's environment-selected `lsqnonlin` versus `fminsearch` solver.
- `eta_true`: `shouldUseTrueNoMotionProfile` is intentionally runtime-only and resets during MATLAB save/reload.
- `ape`, `apv`: depend on the preceding unpersisted numerical choices.

These are preflight rejections, not replacement algorithms or silent defaults. Forcing diagnostics remain #315. Issue #391 tracks the backward-compatible persistence extension and separately qualified solver/profile implementation needed to remove these incompatibilities.

## Verification ledger

- Initial native C++ build passed.
- Full-grid numerical matrix passed: six transform families × both antialias settings × odd/even horizontal grids × reference/native FFT, relative error <= 1e-12. Every applicable executable catalog diagnostic was compared; direct and batched results agree and coefficient state is unchanged. Source log: `/private/tmp/wvm305-matlab.log` (first passing matrix, before later validation-only changes).
- Focused existing C++ catalog, field, and observer tests passed (3/3).
- Extended observer test passed for linear/nonlinear plans, complex outputs, component diagnostics, duplicate observers and service rebinding.
- Direct MATLAB phase-complexity and unsaved true-profile contract tests passed.
- Complete output continuation passed for all six families, reference/native providers, ordinary and segmented runs, with primary coefficient output and dense spatial/scalar output. The later instrumentation assertion was corrected for SQG: copying `A0t` needs zero intermediate scratch when invariant outputs are already saved.
- The full native C++ suite passed (40/40). Focused ASan/UBSan and GCC 14 tests passed (3/3 each). GCC's full Apple SDK runner build is incompatible with SDK Mach static-assert macros; the runtime library, dump and focused tests compile with warnings as errors. Focused GCC tests were built with Make's `/fast` targets after the library build to avoid the unrelated runner dependency.
- Final MATLAB catalog generation and 6 catalog methods passed. The full numerical matrix and the MATLAB operation-preservation/contract methods passed. Corrected continuation instrumentation passed. Code Analyzer covered all 7 touched MATLAB files: zero blocking findings.
- Documentation check passed in a fresh process: 2,026 files, 4,145 routes, zero differences or validation failures. The initial attempt crashed inside MATLAB after dependency switching in a process that had already run the test suite; no source fix was needed.
- The final native suite passed again (40/40) after the metrics/report and applicability changes. This repeat was needed to verify the changed report and public field-name inventory.
- Final expanded matrix passed 3,348 comparisons: 2,232 reference/native comparisons and 1,116 reference comparisons under ASan/UBSan, across six transform families, both antialias settings, and grids `[8,6,9]` / `[9,7,10]`. Maximum relative error: `1.2222953475043186e-13`. Diagnostic scratch returns to zero after each evaluation.
- Two-file output graphs passed for all six families and both providers with fixed RK4, segmented continuation and adaptive RK45, including dense output. The final test-file Code Analyzer pass had zero blocking findings.
- Matched before/after nonlinear integrations (64 steps, adaptive damping, primary and dense output) passed the 3% runtime and retained-memory budgets. Eight measured runs per executable followed an excluded warmup, with alternating process order. Median runtime changes: constant -5.585%, hydrostatic +0.099%, Boussinesq +0.165%. Retained-memory changes: +0.005%, +0.016%, +0.025%, respectively. Steps and RHS evaluation counts agree; all numeric output values agree within `4.52e-16`.
- Evidence is committed in `PortableRuntime/qualification/diagnostics-apple-silicon-v1.json`, including source commits, executable/input hashes, numerical rows, all performance samples and memory measurements. The performance source is `0fabf4b`; final numerical evidence is from `ffc15eba`, which preserves Barotropic QG’s existing speed-reduction formula. The constant-stratification/Hydrostatic/Boussinesq performance paths are unchanged by that correction.
- The first hosted diagnostic matrix failed before numerical evaluation because the new test helper retained MATLAB's Linux library path. The helper now uses the same clean subprocess environment as the existing portable tests; both hosted releases must pass before integration.

## Fixture findings

The generic MATLAB `energy` factory fails on QG's empty wave families; the longstanding C++ `energy` alias is compared to the registered QG `totalEnergy` invariant. No existing behavior is changed.

A MATLAB-authored file with derived coefficient diagnostics in two groups repeats the `j` coordinate, and MATLAB's existing recursive property read reports ambiguous `j`. Dense spatial/scalar groups avoid that unrelated ambiguity; derived coefficients remain covered on the primary record schedule. This limitation also occurs before C++ touches the file.

Only local MATLAB R2025b is installed. R2026a verification belongs to the focused hosted matrix. Optional Full CI is not a goal or merge gate. No required local fixture is missing.

- Hosted R2025b then caught exact direct/batched rounding disagreement for Barotropic QG `uvMax`: the shared reduction used `hypot` while its existing kernel uses `sqrt(u*u + v*v)`. Matching the existing kernel fixes this without changing MATLAB behavior. The complete native suite (40/40), focused ASan/UBSan (3/3), and all 3,348 numerical comparisons passed again after this correction. The final hosted matrix must confirm Linux parity.
