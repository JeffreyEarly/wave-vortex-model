# C++ density foundation

Scope: the supplied-profile primitive and runtime execution contract under #391, based on v4 main `c298dfde3784afabdee67d89670c5c0d0e283c4d` after PR #429. This increment does not recover a no-motion profile from the current density distribution, implement APV or promote density output rows.

`WVNoMotionProfile` owns normalized monotone PCHIP coefficients and supplies density, safeguarded inverse material height and derivative-integral APE. Construction and scalar queries preserve previous outputs on failure. Successful queries allocate no heap workspace; retained storage depends only on the vertical knots. Plateaus, out-of-domain queries and unrepresentable arithmetic fail explicitly. There is no new provider, registry, persistence schema or external dependency.

Run-request v2 accepts optional `execution.densityDiagnostics` metadata. Omission selects actual `rho_nm`; an explicit initial-profile approximation is available. Contract version `wave-vortex-density-diagnostics-v1` fixes actual-profile recovery to `dampedLeastSquares`; arbitrary legacy solver selections are rejected. Reports expose the intended selection and `outputEvaluation: unavailable`. This metadata does not currently cause any density calculation. MATLAB production code and restart schemas are unchanged, and v1 syntax remains unchanged.

The numerical fixtures reuse the retained, successfully fitted JAMES day3000/day3250 profiles from the MATLAB work. Their original solver, snapshot and source provenance is preserved. These are given-profile calculus tests with deterministic queries, not fresh profile-recovery or full-state qualifications.

## Verification ledger

- Release `no-motion-profile`, `run-request` and `portable-variable-catalog` pass. After the test owner added allocation-failure/subnormal cases, only the changed profile test was rebuilt and rerun; it passes. The initial cached CMake configuration did not know the new target; reconfiguration resolved that build setup issue.
- ASan/UBSan versions of the same three tests pass with the final C++ sources. Tests cover independent polynomial/quadrature references, weak and steep gradients, tiny and multi-interval displacements, endpoint tolerances, malformed inputs and failure preservation. Seventy thousand query triplets perform zero probed heap allocations and preserve retained storage.
- Four MATLAB numerical methods pass across twelve cases: independent linear/nonlinear truth, convergence, irregular/weak profiles and both retained JAMES profiles. A fifth method passes three real runner requests (absent, empty and explicit initial selection), verifies report provenance and compares primary coefficients exactly. Its first attempt assumed split-complex storage for real coefficients; the corrected test accepts both valid NetCDF representations. The failed log is retained and no numerical tolerance changed.
- The MATLAB fixture generator and final test class have zero Code Analyzer findings. Documentation is generated once after the coherent change batch and checked once. Generated changes are limited to version history.
- CI artifact packaging includes the new probe, and its two Python tests pass. Independent review caught a missing persistent test registration; the new class now belongs to shared MATLAB and sanitizer selections, with all sixteen routing tests passing. The new MATLAB class uses the existing CI diagnostic-probe directory and builds both required executables for standalone local runs.
- Independent production and contract review, JSON validation, source-digest verification, whitespace and repository-scope checks complete the handoff. The catalog remains 76 identities / 666 rows, with 634 implemented and 32 intentional density incompatibilities. MATLAB production, dependencies, package snapshots and the v5 checkout are unchanged.

The source-bound receipt and logs are in `.github/ci-evidence/issue-391-density-foundation/`. Full CI and a complete-integration timing campaign are deferred: the primitive is not called by integration or output, and request selection adds only report metadata. This increment makes no performance claim for production density diagnostics. Required PR checks still apply.

## Next increment

Implement bounded current-distribution profile recovery using the corrected MATLAB moment and damped least-squares contract, with independent and captured-distribution references, explicit failure/convergence reporting and memory/performance qualification. Then connect shared event intermediates for density, displacement and APE, followed by APV and persistence/continuation qualification. Keep all density rows rejected until each complete execution chain meets its promotion gates; #391 stays open.
