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

## Final gates

Pending: reference/native qualification and recorded evidence, evidence-rejection tests, shared SQG probe regression, source export, source-linked ATS regression, Code Analyzer and focused release/sanitizer CI. Optional Full CI is not an additional gate.
