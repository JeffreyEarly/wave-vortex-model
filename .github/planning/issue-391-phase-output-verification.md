# MATLAB complex phase output repair

Scope: fix the MATLAB `phase`/`conjPhase` diagnostic encoding from v4 main `3c1d598ecc18899c4b3c53465e38049c67cecff9`. The user explicitly waived backward compatibility for these two diagnostic outputs. This does not start or complete the density-profile work or C++ phase evaluation under #391.

Both operations compute complex values but inherited `isComplex=false`. The ordinary Eulerian time-series writer passed that declaration to NetCDF. A direct R2025b observer experiment confirmed that the resulting real variables contained interleaved components instead of the intended complex values. Coefficient-based restart does not read these derived diagnostics: it restores Ap/Am/A0, t and t0, then recomputes phases. Those formulas and restart state remain unchanged.

The production fix adds `isComplex=true` to the two annotations. The existing split-complex writer now supplies `phase_real`/`phase_imag` and `conjPhase_real`/`conjPhase_imag`; no writer, integrator or runtime evaluator is modified. Old malformed diagnostic files are not migrated. The generated catalog changes exactly two identities and sixteen configuration rows, preserving all 23 legacy identities and the 76-identity/666-row inventory. C++ retains 618 implemented and 48 rejected rows; phase rejections now accurately state pending #391 evaluation/persistence qualification.

## Verification ledger

- The new output/restart regression fails before the correction because the complex NetCDF variables are absent; fixed and adaptive parameter cases both reproduce the defect. Initial relative-path discovery selected no tests after MATLAB startup changed directories; the explicit v4 file path selects exactly two cases.
- After correction, both cases pass across constant hydrostatic, constant nonhydrostatic, variable Hydrostatic and Boussinesq: eight configurations. Each uses t0=17, interval 123–125, restart at 124, five ordinary and seventeen dense records. Both complex outputs agree with the independent exponential/conjugate formula within 2e-15, with nontrivial imaginary components. Restart preserves all coefficients exactly and retains t0.
- Six variable-catalog tests and eight strict forward-integration evidence tests pass. No original #289 receipt is rewritten or rerun as new trajectory evidence.
- The generated C++ catalog and diagnostic probe compile; `portable-variable-catalog` passes (0.37 seconds).
- The updated MATLAB diagnostic contract test passes. All four changed MATLAB source/test/generator files have zero Code Analyzer findings.
- Initial documentation check validates all routes but identifies seven expected stale generated pages: the six transform phase pages and version history. That coherent batch was regenerated once and validates 2,026 files / 4,145 routes without failures; required hosted documentation verification is the final comparison gate.
- Repository boundaries, unchanged package dependencies, generated catalog scope and whitespace checks pass. No released OceanKit snapshot or v5 checkout is edited. No optional Full CI or fresh performance/source-consumer campaign is required for this metadata-only production change.

`.github/ci-evidence/issue-391-phase-output.json` records before/after source digests and focused results. Historical #417 and #289 consumer receipts retain their original measured source identity; this successor does not promote them to fresh qualification of changed headers. Hosted verification and integration are recorded in the PR and #391.
