# Issue #302 verification ledger

Scope: standalone variable-stratification Boussinesq numerical kernel on v4 main after #301/PR #378. Complete-model runtime integration remains #303; end-to-end qualification remains #304. No MATLAB production source, package manifest, released snapshot or v5 file changed.

## Implementation

- Read the default persisted Boussinesq wave matrices, preconditioners, depths and exact one-based `iK2unique` membership. Preserve discontiguous groups without approximate regrouping or per-column matrix expansion.
- Prepare eleven shared/grouped vertical operators through the existing scalar/Accelerate matrix service. Shared F/G and wave Fw/Gw remain distinct. Four-field projection uses the persisted cross-projection and prepared divergence/vertical-velocity products.
- Match compact Ap/Am/A0 factors, phases, constraints, fields/components, three- and four-field projection, raw transforms, MATLAB finite-resolution vertical calculus, energy/enstrophy and four-field nonlinear evolution.
- Retain `7S+5H` complex scratch and eleven real volumes, with zero prepared application allocations and source ownership released on destruction. Setup's temporary Nz-by-Nz Ddelta product is not retained.

## Focused local evidence

- MATLAB R2025b parity: fifteen scientific fixtures per provider, covering exponential, thermocline and weak-surface-stratification profiles; odd/even nonsquare grids; antialiasing on/off; several Nz/Nj; nonuniform z; discontiguous groups; and a non-prefix southern-latitude basis. Reference, native/scalar and native/Accelerate passed. Each quantity uses `2e-10*max(abs(expected)) + 1e-18`. Fields, derivatives, both projections and their MATLAB round trips, raw calculus, invariants, nonlinear flux and four RK4 steps are compared (`/private/tmp/wvm-302-parity.log`, `wvm-302-focused-fixtures.log`, `wvm-302-regressions.log`).
- Two decreasing-wavenumber, small-f/N cases passed the Hydrostatic-limit check using both C++ kernels. Final relative discrepancies are below 1e-5 and decrease by more than 1000 (`/private/tmp/wvm-302-focused-fixtures.log`).
- All 39 runtime CTests passed before the final reader validation refinement (`/private/tmp/wvm-302-ctest.log`). The affected modal-reader and Boussinesq boundary tests passed again after that refinement (`/private/tmp/wvm-302-source-final-contracts.log`).
- Final Apple Clang ASan/UBSan and GCC 14 warnings-as-errors builds and Boussinesq boundary tests passed (`/private/tmp/wvm-302-asan-final-build.log`, `wvm-302-asan-final-boundary.log`, `wvm-302-gcc-final-build.log`, `wvm-302-gcc-final-boundary.log`). Boundary coverage includes malformed grouped payloads, aliases, allocation-failure sweeps, backend/FFT failures, ownership and zero prepared allocations.
- Existing MATLAB modal-reader, Hydrostatic kernel and compiled-kernel integration suites passed after the reader changes; the new test's Code Analyzer result is clean (`/private/tmp/wvm-302-regressions.log`).
- All seven source-linked ATS tests passed (`/private/tmp/wvm-302-ats.log`). The source-only export contract passed and `docs:check` reported 2,026 files / 4,145 routes with zero failures or differences (`/private/tmp/wvm-302-authoring.log`).

## Findings resolved during verification

- Default MATLAB files order equal-radius columns contiguously. The discontiguous fixture now explicitly permutes a temporary record and coefficient state, then reverses that permutation only for spectral comparisons.
- The Hydrostatic-limit helper's optional probe argument initially selected the Boussinesq executable. Correcting its argument-count guard exercises the intended independent Hydrostatic kernel.
- A valid weak surface layer can have N2 below f squared. The reader rejects the singular equality, rather than excluding finite negative projection denominators. The weak-layer MATLAB parity fixture passes all providers.
- GCC's dangling-reference diagnostic on temporary initializer-list pairs was resolved using named arrays of simple records; no diagnostic was disabled.

## Integration gates

The final five-method MATLAB parity suite passed with ASan/UBSan reference probes, covering all fifteen fixtures and the Hydrostatic-limit cases (`/private/tmp/wvm-302-asan-parity.log`). Whitespace, JSON syntax and repository-scope review passed. Hosted required checks plus the focused Boussinesq release/sanitizer workflow remain integration gates. Optional Full CI is not an additional gate. Local Apple Silicon sanitizer runs disable unsupported LeakSanitizer; Linux CI enables it. No required local assets are missing.
