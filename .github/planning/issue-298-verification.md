# Stratified QG end-to-end qualification — issue 298

Base: v4 main `dd32ff2b94449c8d7ec7d94421b3c384bdc058b1` (#369 / #297). Work is isolated on `issue-298-stratified-qg-qualification`; the separate v5 checkout and released package snapshots remain untouched. The user authorized the goal and GitHub integration. MATLAB backward compatibility remains mandatory.

## Qualification delivered

- Reuse the existing shared forcing slice and exact-pair fixtures. Add continuation/lifecycle evidence links without introducing another compatibility matrix.
- Add a six-case manifest for 600-second MATLAB/C++ uninterrupted and segmented trajectories, including energy/enstrophy, fields, fixed amplitudes, particles/tracers, moorings, dense output, schedules, ordinals and graph identity. Native and reference providers execute the same cases.
- Add a full-model lifecycle probe across three grid sizes and six construction/destruction cycles per grid/provider. It measures sixteen prepared RK4 steps, allocation calls, retained capacities and work counts; weak ownership verifies release of the authoritative scientific matrices.
- Add `qualifyPortableStratifiedQG` and strict result validation, with machine-readable evidence linked to the exact shared-catalog digest and executed tests. A focused Linux CI workflow runs release and ASan/UBSan qualification independently of optional Full CI.
- Document the exact surface, reproducible qualification command, tolerances, provider coverage and retained-storage limitations in `PortableRuntime/QUALIFICATION.md`.

## Findings and verification ledger

- Initial lifecycle measurements found two metadata-vector allocations per RK4 step. The existing workspace now reserves and reuses its accepted coefficient/block views. No additional state-sized buffer or numerical formula was introduced.
- Refined longer-continuation and lifecycle tests pass with reference/native providers (`/private/tmp/wvm-298-qualification-refined.log`). Prepared steps allocate zero application memory and retain constant reported capacities at `[8,6,9]`, `[12,10,13]` and `[20,16,17]`; all scientific owners expire after destruction.
- MATLAB's fixed RK4 overshoots and interpolates its last step, whereas C++ shortens it. This established endpoint distinction is explicitly documented and checked for convergence. In the tested CFL case, reducing CFL from 0.02 to 0.002 reduces the native coefficient difference from `7.53e-7` to `7.11e-11`; the fine run meets the existing `2e-7` ceiling. No tolerance was loosened to accept the coarse discrepancy.
- Catalog regeneration with the new evidence links passed (`/private/tmp/wvm-298-catalog-generation.log`).
- The complete `qualifyPortableStratifiedQG` invocation passed all 34 tests with reference/native providers in 374 seconds, including constant-stratification/BQG forcing regressions, exact catalog pairs, source exports and modal persistence. The committed artifact `PortableRuntime/qualification/stratified-qg-apple-silicon-v1.json` records clean source commit `b4631ce9cb170cab1720b8d1ff0126c6481066c8`, 41 catalog/provider results, 12 continuation cases and six lifecycle results (`/private/tmp/wvm-298-full-qualification.log`).
- Native C++ contracts passed 35/35 and ATS consumer tests passed 7/7 after the RK4 metadata fix (`/private/tmp/wvm-298-native-contract-tests.log`, `/private/tmp/wvm-298-ats-tests.log`).
- ASan/UBSan reference continuation and lifecycle methods both passed (`/private/tmp/wvm-298-asan-qualification.log`). macOS used `detect_leaks=0`; the focused Linux job enables LeakSanitizer.
- Evidence validation passed the recorded artifact and rejected missing/duplicate/contradictory coverage, changed fixtures, nonfinite or excessive numerical errors, and ownership/storage/allocation failures. New authoring files pass Code Analyzer; the existing source-export test retains its pre-existing style findings.
- `docs:check` passed once: 2,026 files, 4,145 routes, zero validation failures and zero generated differences (`/private/tmp/wvm-298-final-authoring-checks.log`). No canonical website source, MATLAB production behavior, package metadata/dependency or released snapshot changed.
- Hosted focused qualification and required branch checks remain the integration gates. Their final run links and disposition are recorded on the pull request and issues #298/#306.

## Integration

Publish and merge through required checks, diagnose focused qualification/C++ failures, close #298 and hand the evidence to #306. Optional Full CI is not an extra merge gate. Runtime tuning beyond the measured allocation fix remains separate; the report states independent closure/event reconstruction costs rather than promising unmeasured reuse.
