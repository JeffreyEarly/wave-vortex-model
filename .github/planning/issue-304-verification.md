# Issue #304 verification ledger

Scope: Boussinesq complete-model qualification on v4 after #303/PR #382. No MATLAB scientific methods, save defaults, package manifests, dependencies, snapshots or v5 files are changed. Longer qualification is an explicit goal gate; optional Full CI remains independent.

## Implementation

- Added a declared six-case continuation matrix, reference/native qualification runner and strict machine-readable evidence validator. Cases include measured hydrostatic-limit/nonhydrostatic regimes, all integrators, explicit/CFL/default controls, constrained initial states, mean density, 3D/XY observers, dense schedules and restart.
- Each case compares uninterrupted and segmented C++ execution plus C++-then-MATLAB continuation against MATLAB. Exact wave/opaque payload checks precede writable MATLAB reload.
- Extended the shared lifecycle probe to identify Boussinesq, preserving existing SQG/Hydrostatic behavior. Measures six construct/warmup/advance/destroy cycles with finite state, source release, retained capacity and prepared allocations.
- Focused hosted workflow emits release/sanitizer contract evidence; manual complete scope retains long numerical qualification. Distinct report schemas prevent contract-only evidence from claiming full readiness.

## Verification in progress

Initial fixture check corrected the new test's NetCDF path: scientific arrays are at the root, not in the output group. No runtime behavior changed. Reference/native exploration, compiler and sanitizer checks are underway. No required local assets are missing.

Native Apple Clang, GCC 14 warnings-as-errors and ASan/UBSan lifecycle builds passed. The first six reference/native lifecycle rows reported finite state, zero retained growth, zero prepared allocations and expired source ownership. The initial small-domain continuation matched MATLAB but was dominated by inertial shear, with only ~0.08% initial vertical kinetic energy. Reduced inertial and balanced amplitudes in the nonhydrostatic fixtures, retaining all components and the original >1% vertical kinetic criterion; the representative corrected fraction is 36.4%. Exploratory trajectories are not final readiness evidence.

## Final local qualification

- Complete clean-source reference/native report: `ffc3818c064e779bfd3f92b7604e05f29a56c6f8`; 44 passing tests, 47 forcing/provider rows, twelve continuation/provider rows and seven lifecycle/provider rows. Committed as `PortableRuntime/qualification/boussinesq-apple-silicon-v1.json`; log `/private/tmp/wvm-304-qualification.log`.
- Maximum coefficient-family discrepancy across uninterrupted, segmented and MATLAB-resumed paths: 1.58227e-07; maximum field discrepancy: 7.89183e-08; maximum particle-position discrepancy: 3.36537e-09 m. Nonhydrostatic initial vertical kinetic fractions span 0.264–0.364; the hydrostatic-limit fraction is 1.7423e-8. All declared parity and nontrivial-evolution bounds passed.
- All seven lifecycle cases completed six cycles with finite state, zero retained growth, zero prepared C++ allocations and released scientific ownership. The 64×48×49 / 24-mode native case retained 202,313,652 bytes and took a median 8.7126 seconds per sixteen prepared RK4 steps. This extreme short-domain fixture emits MATLAB mode-projection conditioning warnings; its purpose is finite-state/storage/lifecycle stress, not large-grid accuracy certification. Numerical parity is established by the declared continuation/kernel cases. Timing is descriptive on a shared host.
- Local ASan/UBSan contracts: complete, 43 passing tests, 24 catalog rows and two lifecycle cases (`/private/tmp/wvm-304-sanitized-contracts.json`, `wvm-304-sanitized-contracts.log`). Local Apple Silicon omits unsupported LeakSanitizer; Linux CI enables it.
- Focused stratified-QG/Hydrostatic/Boussinesq C++ kernel/runtime tests passed (5/5); all seven ATS tests passed. Native/GCC 14/sanitizer lifecycle builds passed.
- Code Analyzer was clean for all new/changed MATLAB files and the existing catalog-helper mutation test passed (`wvm-304-authoring.log`). Source-only export contract and docs:check passed (2,026 files, 4,145 routes, zero changes; `wvm-304-export-docs.log`). No MATLAB production code, dependencies, manifests, snapshots or v5 files changed.

Focused Linux release and ASan/UBSan contracts passed on this same source commit (run `34224897599`), each with 43 tests, 24 rows and two lifecycle fixtures, clean source and complete machine-readable reports. Linux leak detection is enabled. All five Boussinesq evidence-validator methods passed, including scope, completeness, restart/regime and numerical/memory mutations. The five historical Hydrostatic and three SQG evidence methods also passed (`/private/tmp/wvm-304-evidence-final.log`). Only required hosted branch checks remain. Changes after the qualified source commit add the measured artifact and verification documentation; numerical qualification need not be repeated for those additions. Optional Full CI is not an additional integration gate. No required local assets are missing.
