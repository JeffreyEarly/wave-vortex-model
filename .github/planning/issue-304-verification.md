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
