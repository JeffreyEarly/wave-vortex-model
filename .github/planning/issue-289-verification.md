# Standard forward-integration qualification

Base: v4 main `2e1cc19975a5c812223a19be06b9976f57444504`, after PR #417. Scope: #289 and its typed handoff to #306. MATLAB public behavior and existing saved files remain backward compatible. No v5 checkout or released package snapshot is edited.

## Evidence design

The integration slice enumerates six configurations and five execution profiles (30 support rows). Existing method/configuration fixtures supply exact source witnesses. Six richer representative scenarios fill the audited gaps: constant-hydrostatic CFL RK4, constant-nonhydrostatic RK23, and RK45 on Barotropic QG, Stratified QG, Hydrostatic and Boussinesq. These are six newly executed compositions per provider, not 30 newly executed complete trajectories. The catalog distinguishes source coverage, fresh execution and inherited evidence.

Three isolated agents own C++ method/complex-state tests and a test-only stop launcher; MATLAB continuation qualification; and catalog/schema/validator/generated support documentation. The coordinator owns integration, CI routing/artifacts, source-consumer qualification and final review. MATLAB execution is serialized, and C++ builds use separate temporary directories. No agent publishes independently.

The representative models must evolve unconstrained coefficients and particle/tracer state, retain a fixed coefficient, use two independently restartable output destinations and dense saved values, and exercise whole, segmented, MATLAB-to-C++, C++-to-MATLAB and controlled-stop continuations. Generic method-order, rejection, controller and allocation evidence remains in focused C++ tests. Historical family reports retain their original method/workload/source provenance. Inherited #417 performance evidence is usable only when its measured production sources remain unchanged; it does not become a fresh #289 timing run.

## Coordinator verification ledger

- Fresh source-linked ATS consumer: clean `satmapkit/AlongTrackSimulator` commit `511aa6af9c60353b3de4d371dfe0df43159027cf` compiled against the selected v4 checkout using AppleClang Release, reference FFT and warnings-as-errors. All seven consumer tests pass (13.38 seconds). Source digests, configuration, executable/log hashes and test inventory are in `.github/ci-evidence/issue-289-source-consumer.json`. ATS source was not edited. This does not substitute for the exported-package CI gate.
- CI now packages the deterministic `WVForwardIntegrationProbe`, preserving exact-revision release/sanitized artifact reuse. The new execution/catalog tests and five previously omitted qualification evidence validators are registered for relevant scientific changes and complete selections. No optional Full CI job is added.
- All 38 Python CI tests pass after this routing/artifact batch. Initial discovery lacked the repository-pinned PyYAML dependency; the isolated temporary environment was provisioned with `tools/ci/requirements.txt`, then the complete CI Python suite passed. No repository dependency changed.
- Runtime documentation now includes all supported families and RK45 in current capability descriptions. Historical qualification descriptions are preserved. The new integration guide is included in the retained source inventory, and the ATS link distinguishes the current consumer from the old source-selection baseline.

## C++ method and extension evidence

Reviewed agent commit `db42b2ef44fe633b8202590882f1b3086f3078c0` is integrated as `7e0115aa`. Both focused Release and ASan/UBSan tests pass (2/2 in 0.54 and 1.26 seconds). RK4 global convergence ratios are 17.3957 and 16.682; RK23 ratios are 8.66854 and 8.32717. The cubic continuous extensions approach a local error ratio of 16. A registered integrator-owned required complex block is the only evolving component and drives 10/3/1 adaptive rejections for RK23/RK45/RK78. Stop/resume preserves the uninterrupted trajectory exactly; owning typed-record reconstruction creates independent layout, state and controller storage. Three repeated cycles for each method retain identical storage after diagnostic/dense warmup. This explicitly does not claim MATLAB serialization of an arbitrary custom class. `.github/ci-evidence/issue-289-cpp.json` preserves measured observations and source/executable hashes.

## Outstanding verification

Agent evidence, combined catalog/source-selection checks, changed MATLAB Code Analyzer, one documentation check, repository/package checks and required hosted CI remain to be recorded. No completion or integration claim is made by this draft ledger.
