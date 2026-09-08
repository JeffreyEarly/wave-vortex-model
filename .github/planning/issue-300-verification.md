# Hydrostatic model runtime — issue 300

Base: v4 main `79ad2d31ede5b2ee6b46702e5c340d2980a6f835` (#373 / #299). Work is isolated on `issue-300-hydrostatic-runtime`. The user authorized implementation and GitHub integration. The v5 checkout and released package snapshots are untouched.

## Scope and design

- Restore full MATLAB-authored Hydrostatic models through the persisted immutable scientific source. Retain Ap/Am/A0 reference-time phases, inertial oscillations and real mean-density anomalies, without MATLAB execution or a runtime eigensolver.
- Resolve Hydrostatic factories in the existing extension catalog and reuse stable forcing objects. Extend the same MATLAB-generated compatibility matrix to 120 rows: 101 supported pairs and 19 intentional incompatibilities.
- Share stratified field planning/interpolation across SQG and Hydrostatic. Add Hydrostatic integration services for full 3D tracers and particles using the existing observer objects, RK engines and output machinery.
- Generalize the scientific model-output adapter and named coefficient storage to Hydrostatic. Preserve numeric modal data, opaque N2Function, schedules, graph identity, dense output, append/create/replace and segmented restart.
- Add Hydrostatic acceptance to the private MATLAB portable-request inspector. No existing constructor, scientific calculation, save default or public signature changes. Existing transform rejection and request checks retain their behavior.
- Prepared core/forcing execution has bounded owned workspaces. Field reuse is scoped to one RHS; observers may reconstruct fields again. Spatial closures currently project separately. Performance/lifecycle readiness remains #301.

## Verification ledger

- AppleClang warnings-as-errors build and all 38 runtime CTests pass (`/private/tmp/wvm-300-final-contracts.log`). The Hydrostatic contract includes zero prepared core/forcing application allocations, stable storage, alias rejection, invalid metadata and a setup allocation-failure sweep.
- All 11 Hydrostatic MATLAB methods pass across the focused runs and corrected-case reruns. Native FFTW and reference cases cover odd/even grids, transform/explicit antialiasing, all 23 applicable forcing/configuration pairs and their continuations, ordered closures, all three amplitudes, both mean-density forcing settings, nonzero t/t0, a nonuniform-grid southern-latitude retained subset, fields/interpolation, 3D observers, fixed/CFL/default/adaptive integration and multi-file restart. Logs: `/private/tmp/wvm-300-model.log` (four initial passing full-model methods), `wvm-300-corrected-parity.log` (isolated forcing/continuation passes), `wvm-300-final-cases.log` (corrected composition/CFL/rejection passes), `wvm-300-subset.log` (final retained subset), and `wvm-300-parity.log` (field sampling). Earlier failed cases are explicitly superseded by the following corrections.
- ASan/UBSan passes both Hydrostatic C++ contracts and all 11 MATLAB methods, using focused reruns for the corrected retained-subset and opaque-payload fixtures (`/private/tmp/wvm-300-asan-contracts.log`, `wvm-300-asan-parity.log`, `wvm-300-subset.log`, `wvm-300-payload.log`). Local macOS uses `detect_leaks=0:alloc_dealloc_mismatch=1:halt_on_error=1`; the Linux workflow enables leak detection.
- GCC 14.2 warnings-as-errors build and the Hydrostatic runtime contract pass (`/private/tmp/wvm-300-gcc-build.log`, `wvm-300-gcc-contracts.log`). Source-linked ATS rebuild and all seven tests pass (`wvm-300-ats-tests.log`).
- All 35 affected existing MATLAB tests pass: SQG runtime, constant/BQG stable forcing, portable request writer, regenerated compatibility catalog and compiled-kernel source contracts (`/private/tmp/wvm-300-regressions.log`). Source-only export verification also passes (`wvm-300-authoring-rest.log`).
- Code Analyzer is clean for the new Hydrostatic test and the changed catalog tools/tests. The private request writer retains its pre-existing NASGU warning at line 28 (`fileIdentifier = -1`); that line is unchanged. No new production MATLAB warnings were introduced.
- One `docs:check` passes: 2,026 files, 4,145 routes, no failures or generated differences. Whitespace, manifest hashes and repository scope checks pass. No required local assets are missing. No website source/generated output or package dependency/version changed.

## Findings resolved during qualification

- Vertical damping and vertical diffusivity both require the variable-stratification background-density source; the diffusivity flag controls that source only for its own closure.
- Explicit antialiasing changes the effective horizontal and vertical damping resolution. The adaptive vertical prefactor uses the selected retained mode's depth, including non-prefix mode keys.
- The initial tiny non-prefix fixture made MATLAB's adaptive filter evaluate 0/0 when its cutoff equaled the highest retained mode. The final j=[0,2,4,6] fixture filters to j=[0,2,4] and tests the same selection behavior with a finite MATLAB reference; MATLAB scientific code was not modified.
- Exact opaque N2Function bytes are checked before MATLAB reopens a writable result: MATLAB may reserialize the function handle on close. C++ preserves the original bytes.
- An RHS must reject state/output aliases even though the kernel's coefficient-phase API permits exact in-place evolution.
- CFL selection is compared using the same constraint in MATLAB and C++. A bounded CFL-selected RK4 step avoids comparing MATLAB interpolation after overshooting the requested end time against C++'s final shortened step.

## Integration and handoff

Required checks plus focused Hydrostatic Linux release/sanitizer parity are merge gates. Optional Full CI and unrelated SQG performance qualification are not additional foreground gates. After merge, close #300 and update #301 with the runtime APIs, parity evidence and the remaining end-to-end timing/memory/lifecycle scope.
