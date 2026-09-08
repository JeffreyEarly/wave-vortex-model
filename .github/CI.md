# CI policy for v4

Ordinary pull requests use the `Required / WaveVortexModel` aggregate check. The selector records changed paths, source revision, selected test classes, MATLAB releases, and reasons in the `ci-selection` artifact. A failed, cancelled, missing, or unexpectedly skipped selected job fails the aggregate. MATLAB reports must cover every selected release/configuration and every discovered method. Failures are never retried as though they were infrastructure failures.

## Routing

| Changed surface | Required validation |
| --- | --- |
| Prose, planning, timing evidence | Repository checks and R2025b smoke |
| Documentation sources or rendering tools | Smoke, documentation generation comparison and rendered-site validation; documentation tool tests when applicable |
| Transform-specific C++ | All C++ contracts in release and ASan/UBSan builds; that transform's MATLAB parity, forcing, continuation/lifecycle and shared diagnostic contracts on R2025b/R2026a; instrumented probe parity on R2025b |
| Shared C++ dependencies, diagnostics | All affected transform groups, shared forcing/diagnostic checks, both MATLAB releases and sanitizers |
| Shared persistence, model, observer or forcing boundaries | All transform groups plus MATLAB output/restart/persistence compatibility |
| MATLAB source | Relevant scientific groups plus Code Analyzer and documentation checks; MATLAB public behavior must remain backward compatible |
| Packaging, dependencies, unknown paths or CI implementation | Conservative shared coverage; isolated clean installation and package export where selected |

The executable policy is `tools/ci/route.py`. Matches are unioned; deleted files are included and renames supply both paths. Unknown paths select broad coverage. An unavailable or empty inventory also selects broad coverage. There are no workflow-level path filters on the aggregate, so documentation-only and unrelated changes still produce a required result.

## Build and setup reuse

`tools/ci/CMakeLists.txt` builds the portable core once per configuration and shares it with the runtime contracts and probes. Release and sanitizer artifacts remain separate. Artifacts record the exact checkout revision, configuration, and SHA-256 of each executable; consumers reject mismatches and restore executable permissions after download. Artifacts are reused within the same run, never selected from a previous revision.

Each selected MATLAB release has one shared validation job. R2025b also executes selected analyzer and documentation phases. A separate R2025b job consumes instrumented probes. Three test classes accept an optional `WVM_CI_BINARY_DIR`; their normal standalone build behavior is unchanged when it is absent. Existing probe environment variables serve the other classes.

Package validation deliberately uses isolated MATLAB preferences, a separate release candidate/export, and an independently built exported runtime. It does not consume the authoring checkout's binary artifact.

Ubuntu downloads have bounded connection timeouts and one apt retry. MATLAB provisioning has a five-minute step limit and at most one retry; the workflow explicitly requires successful setup. Tests, analyzer, documentation generation and qualification have no automatic retry or continue-on-error.

## Broader qualification

The central workflow runs complete focused qualification weekly, or explicitly with `complete=true`, or on a `final-integration` PR. This includes all transform groups and the three `longerContinuationMatchesMatlab` methods. Ordinary focused runs retain lifecycle/storage checks and shorter MATLAB–C++–MATLAB continuation fixtures. Hydrostatic and Boussinesq long continuation was already explicit; SQG's long continuation moves off ordinary PRs.

The existing transform qualification workflows remain available for explicit campaigns with their original machine-readable qualification reports. Extended full, exhaustive and optional suites remain scheduled and manually dispatchable. They are not ordinary merge requirements. Package/release work selects isolated package verification; publication continues through the existing release workflow.

## Required-check migration

Until hosted evidence establishes the new aggregate, the default migration bridge actually executes all old required MATLAB phases and reports their existing names only after the aggregate succeeds. Keep `WVM_CI_LEGACY_REQUIRED_CHECKS` unset or true during this phase.

After reviewing successful hosted coverage and negative gate tests, replace the three required check names with `Required / WaveVortexModel`, preserving strict branch protection. Then set `WVM_CI_LEGACY_REQUIRED_CHECKS=false` to enable documentation/prose routing without forced legacy phases. No required check is bypassed during migration.

## Verification and timing

Run `python3 -m pip install -r tools/ci/requirements.txt`, then `python3 -m unittest discover -s tools/ci -p 'test_*.py' -v`. Routing examples include documentation, MATLAB, transform C++, shared persistence, CI changes, deleted/renamed files, and unknown paths. Gate tests inject failures, cancellation, absent jobs/reports/methods, stale revisions, and incompatible artifacts. Workflow contracts check the real dependency graph and infrastructure-only retry.

Use actionlint to validate all workflow files before deployment. `tools/ci/measure_runs.py --run RUN_ID --output FILE` records job/step times across attempts without counting carried-forward successes twice. These are elapsed runner seconds, not invoice charges; incomplete jobs are identified explicitly. Timing evidence lives in `.github/ci-evidence/`.

The ordinary required-path target is roughly 5–8 minutes with healthy provisioning. Documentation rendering, broad scientific changes, sanitizer builds, and complete qualification may exceed that target. Report measured hosted results separately from estimates and local timings.

<!-- Temporary documentation-route timing probe for issue 395; do not merge. -->
