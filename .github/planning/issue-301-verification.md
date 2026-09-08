# Issue #301 verification ledger

Scope: Hydrostatic end-to-end qualification on v4 main after #300/PR #376. MATLAB production behavior is unchanged. The shared lifecycle probe preserves the SQG executable and reports the loaded transform's schema.

## Initial measurements and corrections

- Native CMake build of `WVHydrostaticLifecycleProbe`: passed (`/private/tmp/wvm-301-build.log`).
- Initial lifecycle cases at 8×6×9 and 20×16×17: six cycles each for reference/native; zero prepared allocations, zero retained growth, all scientific owners released. The 20×16×17 sample records 64 RHS, 128 physical reconstructions and 192 spatial projections over sixteen RK4 steps (about 16.4 seconds reference / 0.052 seconds native).
- Oversized 32×24×25 reference measurement deliberately stopped after measuring the reference DFT cost. Final reference matrix uses 8×6×9, 12×10×13 and 20×16×17; 64×48×49/24 modes is native-only.
- Initial continuation fixture encountered the existing MATLAB adaptive-damping degeneracy when explicit antialiasing left one positive mode. Increased fixture mode count; no MATLAB scientific code changed.
- Test helper corrected to avoid an unavailable toolbox-specific `struct2array` dependency.

## Focused verification

- Twelve longer continuation/provider rows passed before the final initial-amplitude constraint refinement (`/private/tmp/wvm-301-continuations.log`). Maximum coefficient-family parity error was about 5.2e-9 in default RK7(8); explicit cases were near roundoff. The final qualification reruns these fixtures after constraining the initial amplitudes, ensuring that initial antialias removal cannot satisfy the nontrivial-evolution gate.
- 38 C++ runtime CTests passed (`/private/tmp/wvm-301-ctest.log`).
- Seven source-linked ATS tests passed (`/private/tmp/wvm-301-ats.log`).
- Shared lifecycle probes built with native Apple Clang, reference GCC 14 and reference ASan/UBSan (`/private/tmp/wvm-301-probes.log`, `wvm-301-gcc-probes.log`, `wvm-301-asan-probe.log`).
- Code Analyzer reported no diagnostics in the four new MATLAB files; source-only export contract passed (`/private/tmp/wvm-301-authoring-checks.log`).

## Final local evidence

- `qualifyPortableHydrostatic`: complete, 41 passing tests, 47 forcing/provider rows, twelve continuation rows, seven lifecycle rows (`/private/tmp/wvm-301-qualification.log`, `/private/tmp/wvm-301-native.json`). Recorded source: `93d84d4faba2c47bfe0b5203ef38abb0c6b33ffd`, clean working tree. The report is committed as `PortableRuntime/qualification/hydrostatic-apple-silicon-v1.json`.
- Maximum coefficient-family error: 5.1862e-9; maximum field error: 2.5683e-9; maximum particle-position discrepancy: 2.6102e-6 m. Nonlinear coefficient changes span 0.253–0.471; the linear case preserves coefficients exactly.
- All seven lifecycle rows completed six construct/advance/destroy cycles with finite state, expired scientific owners, zero retained growth and zero prepared C++ allocations. The 64×48×49 / 24-mode native case reports 66,545,802 retained bytes and a median 2.9093 seconds per sixteen RK4 steps. Timings are descriptive on a shared development host. Forcing-service counters exclude reconstruction performed by independent sampling/output services.
- Local ASan/UBSan lifecycle probe: six full-3D observer model cycles passed with zero allocations/growth and expired ownership (`/private/tmp/wvm-301-sanitized-lifecycle.log`, `/private/tmp/wvm-301-sanitized-lifecycle.json`). Apple Silicon uses `detect_leaks=0`; focused Linux CI uses LeakSanitizer with `detect_leaks=1`.
- SQG's existing recorded catalog digest was stale after #300 expanded the catalog. Refreshed the actual reference/native qualification; no digest checks were weakened. The refresh exposed a pre-existing opaque-byte assertion that ran after MATLAB writable reload. Capturing input bytes and checking C++ output before reload fixes that ordering and prevents append from comparing a file to itself. All six policy/provider combinations passed the focused rerun (`/private/tmp/wvm-301-sqg-persistence.log`); the subsequent complete SQG report passed (`/private/tmp/wvm-301-sqg-refresh.log`, `/private/tmp/wvm-301-sqg-native.json`).
- `docs:check`: 2,026 files / 4,145 routes, zero failures or differences (`/private/tmp/wvm-301-final-authoring.log`). The command's subsequent strict-empty Code Analyzer assertion encountered three pre-existing SQG-test diagnostics; detail review confirms unchanged code: ALIGN at line 72 and local `executable` PROP notices at lines 211/214. New qualification tools have no diagnostics (`/private/tmp/wvm-301-analyzer-detail.log`).

## Integration gates

Both recorded-evidence suites passed all six methods, including malformed/contradictory numerical and memory evidence rejection (`/private/tmp/wvm-301-evidence-tests.log`). Whitespace and repository-scope checks passed. Pending: focused hosted release/sanitizer and required branch checks. Optional Full CI is not an additional gate. No required local assets are missing; no MATLAB production source, package manifests, release snapshots or v5 files changed.

## Hosted workload adjustment

The initial hosted SQG release/sanitizer qualification passed (run `34184626299`). Its release JSON records 1,177 seconds total and 463 seconds in the SQG lifecycle test. Comparing matched reference measurements with the local report shows approximately sixfold direct-DFT cost. At that rate, including both the large reference Hydrostatic lifecycle and redundant SQG lifecycle in each Hydrostatic job would exceed its 35-minute limit.

Reference-only qualification therefore uses the manifest's two smaller lifecycle grids and leaves the SQG lifecycle to its dedicated workflow. All six Hydrostatic continuation cases, kernel/forcing parity and other regression tests remain required. The native-plus-reference scope and committed measurements are unchanged. This changes qualification scheduling only, with no numerical/runtime or MATLAB production changes.

The adjusted two-grid reference lifecycle passed under local ASan/UBSan, and the unchanged native artifact passed its three existing evidence tests (`/private/tmp/wvm-301-reference-scope.log`). A new focused evidence test confirms that reference-only scope still requires all six continuations and both lifecycle fixtures (`/private/tmp/wvm-301-reference-evidence.log`).

## Separate full numerical and instrumented contract gates

On `52f6ad72`, all required checks and general C++ contract/ASan/UBSan checks passed (run `34186467838`). Full Linux Hydrostatic release qualification passed in 28m13s (run `34186467822`), recording 40 tests, 24 forcing rows, six continuations and two lifecycle cases, complete and clean. Its numerical continuation method took 1,111 seconds; that complete-scope workload is unchanged by the following scheduling adjustment.

The sanitizer job reached the 35-minute timeout. Its log (`/private/tmp/wvm-301-ci-sanitized.log`) contains no assertion or sanitizer failure and shows the long-continuation test completing before lifecycle testing began. Repeating long numerical trajectories under instrumentation consumed the budget. The sanitizer job now runs the separate `contracts` scope: all 39 short numerical/forcing/integration/persistence and lifecycle tests, including all integrators, dense output, restart, malformed inputs and repeated ownership release. Its distinct `wave-vortex-hydrostatic-contracts-v1` schema cannot substitute for full continuation qualification. Full release/native evidence remains required and unchanged.

Automatic Hydrostatic jobs now run contracts in both configurations; manual dispatch defaults to complete release qualification plus sanitized contracts. This keeps long milestone qualification explicit. The successful full Linux release report above and committed native report remain the full numerical evidence: only scheduling/report scope changed afterward, so another long release run is not an integration gate.

The optional Full run on `52f6ad72` completed 838/839 methods, with an opaque-byte assertion failure in Hydrostatic multi-file output. The local sanitizer contract run reproduced it. Inspection traced this to the test expectation: create/replace writes the selected restart's shared immutable source to every new destination, while append leaves each existing file's source intact. Independently serialized MATLAB handles can have different opaque bytes even for the same function. Both Hydrostatic and SQG tests now compare create/replace against the selected primary restart and append against saved per-file input bytes, still before writable MATLAB reload. No runtime or MATLAB production behavior changed.

The corrected Hydrostatic and SQG multi-file methods passed all twelve policy/provider combinations, and all five Hydrostatic evidence-validator methods passed (`/private/tmp/wvm-301-final-contract-fixes.log`). Code Analyzer is clean for the changed Hydrostatic test and qualification tools; SQG retains only its three previously documented diagnostics. The local sanitizer contract run reproduced the old assertion before this correction; final Linux contract reports will verify the corrected test under instrumentation. All required helper executables are now built.
