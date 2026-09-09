# Portable phase output qualification

## Scope and prerequisites

The owner approved the next portable increment and agent coordination after the MATLAB density work. PR #424 merged as `84a75ed017d797ca81b27c22e916972bb1ce70fc` after all required CI checks passed. This branch starts from that v4 main revision. The separate v5 checkout is not modified.

Implement `phase` and `conjPhase` for constant hydrostatic, constant nonhydrostatic, Hydrostatic and Boussinesq transforms, with antialiasing on and off. MATLAB's corrected complex metadata from PR #422 remains authoritative. The four density diagnostics remain explicit portable incompatibilities and #391 stays open for them.

## Implementation

The immutable `WVDiagnosticFieldPlan` resolves both outputs as complex coefficient arrays in the existing spectral layout. It requests the same invocation-owned phase vector already used by `Apt` and `Amt`, evaluated from the supplied event's `t` and `t0`. The final output pass copies that vector or its complex conjugate. It adds no writer, registry, persistent cache or integration-state field. The existing alias checks, preflight validation, scratch accounting and output activation apply unchanged.

For each retained coefficient, the defining values are

$$\mathrm{phase}_k(t) = \exp(i\Omega_k(t-t_0)), \qquad \mathrm{conjPhase}_k(t) = \overline{\mathrm{phase}_k(t)}.$$

Phase depends on the transform frequencies and evaluation time, not coefficient amplitudes. Dense output must use the requested observation time rather than the accepted-step endpoint. Restart preserves `t0`; neither reading nor writing these diagnostics changes primary coefficients.

The source supplement enables the two phase records. MATLAB generation changes exactly sixteen configuration rows and two executable-identifier cases: 634 rows implemented and 32 density rows intentionally incompatible. All 76 identities, 666 rows and the original 23 metadata records are preserved. No density row is promoted.

## Focused acceptance and verification ledger

- Six MATLAB variable-catalog methods pass after regeneration. An independent structural comparison confirms that only phase-row status/restriction fields change; all MATLAB-authoritative metadata remains identical.
- Strict standalone C++ compilation of the production translation unit passes. Release and ASan/UBSan field/catalog tests are the focused memory, aliasing and arithmetic gates.
- The phase output fixture covers all four transform families, both antialiasing settings, reference/native providers, odd/nonsquare grids, nonzero `t0`, primary and off-step dense output, C++ restart/append and continuation in both MATLAB/C++ directions. Direct complex exponentials and MATLAB output files provide independent numerical comparisons.
- Existing all-transform diagnostic comparisons exercise sharing with other outputs and unchanged density rejections. Earlier source-bound qualification reports remain historical; this increment receives a separate report and receipt.
- Matched complete-integration measurements will reuse established constant/Hydrostatic/Boussinesq native workloads against an archived source-bound baseline. Timing waits until builds and scientific workloads are idle; no previous report is relabeled as a new run.

Only focused local verification is required for this increment. Normal required CI remains the integration gate; optional Full CI and long new simulations are not additional gates.

## Completed numerical and lifecycle verification

The new focused MATLAB phase method passes all sixteen configuration/provider rows and sixty-four lifecycle scenarios. Maximum phase absolute error is 1.1444e-16. Existing all-transform diagnostic comparisons pass all forty-eight rows with maximum relative error 1.2223e-13 against tolerance 1e-12. The changed MATLAB test class has zero Code Analyzer findings. Both methods passed their first execution; no tolerance was loosened.

Release and ASan/UBSan field/catalog tests pass. The first Release catalog binary caught an incorrect new test expectation that `conjPhase` had a one-node dependency plan; its semantic plan correctly contains `phase` then `conjPhase`. The test was corrected, then only the failing catalog test was rebuilt and rerun. No production change resulted. Field tests independently cover phase dispersion, common time-origin shifts, zero/nonzero amplitudes, phase/Apt/Amt sharing, inactive outputs, scratch release and preserved coefficient state. The existing policy for aliases involving inactive output views remains unchanged.

Independent review of the production and MATLAB lifecycle changes found no material issue. Regenerated changelog documentation once: 2,026 files and 4,145 routes validate with no failures or comparison differences. Only the generated version-history page changes. Repository boundaries, JSON parsing, package-manifest and staged whitespace checks accompany the final handoff; no released OceanKit snapshot or v5 file is edited.

## Performance investigation

The initial eight-pair campaign measured constant +7.603%, Hydrostatic +0.658% and Boussinesq -4.390% runtime. Constant exceeded the declared 3% budget. All runs retained the same 64 steps, 256 RHS evaluations and zero rejections; saved values matched within 4.20e-16. Compiler, target flags, SDK, architecture, provider libraries and inputs matched. Constant timings varied strongly with run order, including a final pair differing by only +0.18%; this suggests variability but does not invalidate the failed result.

Before collecting further results, the coordinator authorized one additional constant-only sixteen-pair comparison with reversed initial order. Both campaigns and their combined twenty-four-pair estimate will be retained. Acceptance requires the combined estimate within the 3% budget and no reproducible slowdown in the follow-up; a remaining failure requires investigation rather than repeated attempts until one passes. Hydrostatic and Boussinesq are not rerun. A receipt-wrapper assertion expecting exact memory equality is corrected to the existing declared 3% budget: Hydrostatic's eight-byte difference is less than 0.00025%, and is reported explicitly.

The authorized follow-up measured constant -2.779% runtime, and the combined twenty-four-pair ratio of medians is -1.403% (median paired change -0.118%). The initial +7.603% result is retained. The wide paired dispersion and time variation support no reproducible regression beyond the 3% budget; they do not justify a speedup claim. Hydrostatic +0.658% and Boussinesq -4.390% remain their original eight-pair results. No further timing runs were performed.

Final local qualification is complete. Maximum saved integration difference across both campaigns is 5.124e-16, with unchanged work counts. Performance source/build audits, exact samples, the predeclared follow-up and comparator are retained in the separate performance receipt. All required local gates pass; no missing local asset prevented completion. Required hosted CI remains the final integration gate.
