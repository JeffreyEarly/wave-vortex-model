# Matched three-model benchmark and v4 release

Tracking: https://github.com/JeffreyEarly/wave-vortex-model/issues/501

## Scope and ownership

User approved September 12, 2026: replace the historical top MATLAB/C++ timing table with a current matched comparison, preserving its design and adding a model selector. Remove the appended native-increment section. Finish with a qualified version tag and publication. No new runtime optimization is included.

Coordinator owns scientific contract, verification scheduling, release and publication. Bounded inexpensive workers own the benchmark harness and website presentation; the harness was completed and reviewed by a Sol worker after the initial Luna scaffold. Only the coordinator schedules MATLAB, builds and measurements. Authoring checkout: `wvm-v4-cpp-adoption-audit`, branch `bench/three-model-release`, starting at `806ed7ef`. The primary `wave-vortex-model` checkout is v5 and remains untouched.

## Measurement contract

- Three models: existing nonhydrostatic constant stratification, Hydrostatic exponential stratification, Boussinesq exponential stratification.
- Domain `[150e3 150e3 1300]` m; grid `[256 256 129]`; latitude 45 degrees; antialiasing enabled.
- Constant `N2 = 2e-5` s^-2. Both exponential models use `N2(z) = 2e-5 exp(2 z / 1300)` s^-2.
- Retain deterministic seed 4001, GM(1), first-baroclinic red geostrophic spectrum with maximum horizontal geostrophic speed 0.15 m/s. Same initialization recipe across families; one saved state shared across interfaces within each model/workload.
- Fixed simulated duration 7168 s and existing early output schedule. Family-dependent CFL estimates must not change duration or output times.
- RK8(7), existing method tolerances and default maximum-step policy. The initial step is the smaller of the family CFL=0.5 estimate and the default maximum step (one tenth of the integration span), consistently reported by both interfaces. Three interfaces: MATLAB builtin, MATLAB compiled, standalone native C++.
- Two existing workloads: coefficient endpoints; composite including tracer, particles, mooring and early dense output.
- Time integration plus required output delivery, excluding startup, construction, modes, provider planning and preparation. Audit lazy work before freezing the timing contract.
- Integration-phase total process-tree peak RSS remains the primary memory metric. Preserve exact source, provider, threads, fixtures, build identities and process evidence in provenance.
- Three fresh processes per model/workload/interface: 54 measured runs. All three models use all three interfaces. Pilot first; do not expand to the historical four-integrator matrix. Historical integrator/scaling records remain explicitly historical.
- Compare complete scientific outputs and integration controls; no fabricated data, tolerance weakening or extrapolated current timings.

## Increments

1. Harness/schema extension and cheap smoke validation; fix scientific and measurement findings before freeze.
2. Preserve table design, add selector/release metadata, remove appended increment section, test missing coverage and historical selection separately.
3. Pilot for time/storage budget, release checks, frozen qualification campaign, release/tag/export, final website dataset and tracker updates.

## Timing audit

- `WVTransformBoussinesqKernel::create` prepares the retained horizontal FFT/advection operator, vertical matrices/executors, workspaces and worker groups during model construction. The runner constructs the model and calls `prepareStateAfterRestart` before entering its `integrate` phase.
- `prepareStateAfterRestart` prepares integrator storage and applies constraints; it does not evaluate an RHS. Keep scientific first-RHS/field calculations inside the timed integration. Do not pre-evaluate only MATLAB and accidentally grant it a cached RHS. MATLAB JIT/first-execution overhead is not claimed to be eliminated.
- Large initial modes are constructed and saved during fixture setup, outside measured workers. MATLAB and native restoration/loading remain untimed. Any pilot evidence contradicting this boundary must be fixed before publication.

## Release decisions

Authenticated repository owner verified as `JeffreyEarly`; latest release/tag and manifest are v4.3.0. Proposed next minor release v4.4.0 reflects expanded compiled support. Unreleased C++ notes were consolidated to remove obsolete intermediate unsupported-density claims; formal standard-parity sign-off remains separate (#307/#310). Use the public MPM API for metadata changes and the established release/export workflow. Do not manually edit released snapshots. Keep runtime-source equivalence explicit if publication metadata changes after measurement.

## Verification ledger

- Initial checkout clean, source `806ed7ef`; no open PRs at start. Root and repository guidance, MATLAB style, documentation, package/release and C++ workflow read.
- Disk preflight: about 6.2 GiB free; campaign not started. Existing immutable dependency snapshots ClassAnnotations 1.2.1, InternalModes 1.3.0, NetCDF 1.0.2 and SplineCore 2.2.0 are present.
- Presentation worker: existing website test class passed before final cohort validation changes; focused selector regression passed after those changes with `assertSuccess`. Final independent review still checks the negative cases and generated output.
- Clean native MPM install: passed `verifyWaveVortexModelPackage` from an isolated temporary add-on registry using the released dependency graph. Report `/private/tmp/wvm-three-model-release/clean-install.json`; log `clean-install-isolated.log`. Initial attempt encountered a preinstalled 4.2.0 package conflict before switching to an isolated registry; no scientific failure.
- Scientific fixture smoke: all three models at `[32 32 17]` passed deterministic initialization, finite coefficients/flux, positive energies, and 0.15 m/s geostrophic maximum. Report `/private/tmp/wvm-three-model-release/scientific-fixture-smoke.json`; script `check_fixtures.m`, log of the same report stem. This is correctness smoke, not published timing.
- Harness contract and normalization focused tests: 6/6 passed. Full historical/contract class excluding two optional real-run methods: 37/37 passed. The real historical reduced dense-schedule method passed separately (1/1). Logs: `harness-final.log` (original `/private/tmp/wvm-three-model-release-harness-final.log`), `test-three-interface-full-minus-actual.log`, and `test-three-interface-legacy-reduced-dense.log`.
- Real small pilots: all three models passed endpoint/composite output and integration-control comparisons at `[32 32 17]`, one repeat, 256 s. Constant pilot v2, Hydrostatic v1, and Boussinesq v3 are raw-only, publication-ineligible correctness pilots, not current performance claims. Earlier Boussinesq pilot failures exposed a case-struct preallocation mismatch and the default-maximum-step reporting mismatch; both were corrected before the passing pilots.
- Independent harness review found no scientific/publication/legacy regression. Removed an unrelated machine-local reference path from generic storage evidence; the historical 1.445 GiB Boussinesq fixture observation belongs only to preflight planning.
- Website class and focused negative cases passed; final Code Analyzer exposed unintended nested helper functions sharing loop variables, which were converted to ordinary local functions. A fresh whole website class and documentation check qualify that correction; see the final handoff results below.
- Browser component preview used explicitly synthetic, external-only values. All three selectors switched to exactly one visible panel; provenance remained collapsed. At a 375 px content width the table scrolled within its container (608 px table width) without document overflow. This checks the component with actual custom CSS, not a full deployed Jekyll-site render. Synthetic preview files are not committed.
- Repository boundary/compatibility/tracked-artifact checks and whitespace checks passed. The manifest is unchanged. MATLAB contract validators exercise raw and published records; a separate JSON Schema validator was unavailable locally, so formal schema-tool validation is not claimed.
- Pending: full-size pilot/storage/time budget; frozen 54-run campaign; required release CI; final exported candidate verification; version/tag/export; current measured dataset publication. No release was published and no new performance numbers were added.

## Constraints and evidence

Original August M5 raw archives remain unavailable on this host, as recorded in the earlier website audit. New runs generate new evidence; historical normalized records are retained unchanged. Do not delete old artifacts or interrupt running experiments to obtain resources.

## Storage hold and next execution

At handoff the host has about 6.9 GiB free; the coarse full-size guard requires 16.1 GiB, followed by a fixture-size-based retention check. User permission is pending to delete exactly 80 old generated `.bin` files under `/private/tmp/wvm358-worker-screen/*/` (15.65 GiB). Their successful comparison records and recorded hashes have been inspected; the concrete file list is `/private/tmp/wvm-three-model-release/cleanup-proposal.json`. None has been deleted. If approved, verify the file hashes, preserve the manifest/logs/comparison records in the external archive, and remove only those listed payloads.

Then confirm host idleness, run the full-size bounded pilot to estimate total wall time and storage, and freeze source/build identities before the 54-run campaign. Keep one shared task-owned native build directory and one model per artifact. Run release qualification once on the combined candidate. Use the existing minor-release workflow for proposed v4.4.0; preserve measured-source equivalence through metadata-only release changes. Publish actual v4 normalized records/catalog entries, regenerate the top table, and close #501 only after release and website delivery.

## Final preflight handoff

- All 13 website methods passed across the final class run and focused correction (`final-docs-v5.log`, `final-docs-v6.log`). The correction updated an obsolete expected verbose unavailable message; the final generator uses compact cells with one support explanation.
- Final documentation build and check passed: 2026 files, 4145 routes, no validation failures, no generated differences.
- Final Code Analyzer: zero errors, one pre-existing unused-input warning in `threeInterfaceMatlabWorker.m`, plus informational findings. No new correctness warning remains.
- Compact logs, pilot result/worker records, scripts, analyzer report and pending-cleanup manifest are archived outside the authoring repository: `../wave-vortex-model-benchmark-artifacts/three-model-release-preflight-20260913.tar.gz`; SHA-256 `0854be20ac398cb6e4c7b14630ce165168ac115a89605df80ffeb7093e80e282`; 139877 bytes. This archive includes failure evidence and is preflight evidence only, not publication data.

September 13 adapter-campaign handoff: the matched protocol now requires all three interfaces for all three model configurations (54 measured processes across the two workloads and three replicates). All 38 focused TestThreeInterfaceBenchmark full-tag contract methods passed using the combined adapter checkout for MATLAB classes; timing, release qualification and publication remain pending. Historical unavailable preparation records cannot qualify the completed matched campaign.

## Final adapter integration preparation

The preserved harness commits were cherry-picked onto adapter candidate `4592bad2` in `wvm-v4-benchmark-final`, branch `bench/three-model-final`. Once PR #509 merges, rebase only this benchmark series onto its qualified main result; the primary v5 checkout remains untouched.

The all-interface contract review removed the remaining obsolete variable-model unavailable path from current v4 table validation and synthetic fixtures. Existing legacy records remain unchanged. All 51 focused harness/presentation methods pass after this correction (`/private/tmp/wvm503/three-model-website-contract-final-tests.csv`); the original 50/51 run and temporary-driver construction failure remain recorded. Code Analyzer reports informational findings only in the three affected files. Documentation build/check passes: 2,052 files, 4,197 routes, no failures or generated differences (`three-model-website-contract-final.log`). No MEX rebuild or numerical timing was performed for this presentation/fixture correction.

Large-run storage remains blocked pending the existing explicit cleanup approval. Approximately 7.1 GiB is free versus the coarse 16.1 GiB guard before fixture retention. The exact pending 80-file cleanup manifest remains `/private/tmp/wvm-three-model-release/cleanup-proposal.json`; no listed payload has been deleted. Neither v4.4.0 nor a new benchmark dataset has been published.
