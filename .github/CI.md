# CI policy for v4

Ordinary pull requests use the `Required / WaveVortexModel` aggregate check. CI runs when a PR is opened, updated, or reopened, and on pushes to `main`; label changes do not start or expand validation. No workflow runs on a recurring schedule. The selector records changed paths, source revision, selected test classes, MATLAB releases, and reasons in the `ci-selection` artifact. A failed, cancelled, missing, or unexpectedly skipped selected job fails the aggregate. MATLAB reports must cover every selected release/configuration and every discovered method. Failures are never retried as though they were infrastructure failures.

## Routing

| Changed surface | Required validation |
| --- | --- |
| Prose, planning, timing evidence | Repository/provenance checks; no MATLAB or result artifacts |
| Trigger-only or comment-only workflow changes | Workflow lint and policy tests; executable changes retain conservative coverage |
| Registered individual MATLAB test | That class plus the validated smoke baseline on R2025b; native builds and sanitized parity only for explicitly registered probe dependencies |
| Documentation sources or rendering tools | Documentation generation comparison and rendered-site validation; documentation tool tests when applicable |
| Transform-specific C++ | All C++ contracts in release and ASan/UBSan builds; that transform's MATLAB parity, forcing, continuation/lifecycle and shared diagnostic contracts on R2025b; instrumented probe parity on R2025b |
| Shared C++ dependencies, diagnostics | All affected transform groups, shared forcing/diagnostic checks, R2025b and sanitizers |
| Shared persistence, model, observer or forcing boundaries | All transform groups plus MATLAB output/restart/persistence compatibility |
| MATLAB source | Explicit scientific dependency groups and Code Analyzer on changed surviving files; documentation checks for API/help changes or uncertain content |
| Packaging, dependencies, unknown paths or CI implementation | Conservative shared coverage; isolated clean installation and package export where selected |

The executable policy is `tools/ci/route.py`. Pull requests compare their head with the merge base of the target branch, covering every PR commit without treating unrelated target-branch changes as part of the PR. Pushes compare the before and after revisions. Workflow content is compared as parsed YAML: only changes confined to triggers or comments can omit execution validation; reusable-workflow inputs remain executable policy. The gate recomputes content classifications from the exact Git diff. Individual-test dependencies are explicitly registered in `tools/ci/test_dependencies.json`; unknown tests and shared helpers remain conservative. Production routing uses the ordered path and family registry in `tools/ci/production_dependencies.json`, with the reviewed before/after contract inventory in [CI-routing-coverage-v4.md](CI-routing-coverage-v4.md). Shared boundaries retain all consumer families; unknown production paths remain broad. Matches are unioned; deleted files are included and renames supply both paths. Unknown paths select broad coverage. An unavailable or empty inventory also selects broad coverage. There are no workflow-level path filters on the aggregate, so documentation-only and unrelated changes still produce a required result.

## Build and setup reuse

`tools/ci/CMakeLists.txt` builds the portable core once per configuration and shares it with the runtime contracts and probes. Release and sanitizer artifacts remain separate. Artifacts record the exact checkout revision, configuration, and SHA-256 of each executable; consumers reject mismatches and restore executable permissions after download. The bundle contains only the 15 probes needed by MATLAB; all 44 CTest contracts still run in the build job. Finished artifacts are reused within the same run, never selected from a previous revision. Compiler objects use ccache with separate compiler/configuration namespaces and compiler-content verification. A real compilation fixture verifies source, header, flag and compiler invalidation before each build. Cache hits never skip contracts or exact-revision packaging.

Selected classes are balanced into at most four concurrent batches per MATLAB release/configuration. Measured class durations in `tools/ci/test_costs.json` affect placement only: each selected class still executes exactly once per release/configuration. The driver and build tasks share validated formal test discovery. Smoke methods in selected classes run with their class batch; only the remaining smoke methods run in batch zero. Reports list the full expected smoke baseline and every executed method, and the gate requires each smoke method exactly once per release. The internal selection/report formats are version 3 and explicitly represent unselected MATLAB work; R2025b release batch zero also executes selected analyzer and documentation phases. Instrumented probes have separate R2025b batches. The aggregate requires every batch report and rejects duplicate test methods across batches. Three test classes accept an optional `WVM_CI_BINARY_DIR`; their normal standalone build behavior is unchanged when it is absent. Existing probe environment variables serve the other classes.

Documentation selection compares the actual MATLAB diff. API help/comments, declarations, property and argument blocks, dynamic annotations, API sidecars, website sources, and generator changes select generation; uncertain syntax does too. Only proven implementation-only changes can omit it. The required gate independently recomputes these facts from Git. Code Analyzer uses its existing `Files` interface for changed surviving MATLAB files, and reports the exact analyzed paths. Analyzer policy, package/dependency, complete, and unknown selections retain production-wide analysis.

Package validation deliberately uses isolated MATLAB preferences, a separate release candidate/export, and an independently built exported runtime. It does not consume the authoring checkout's binary artifact.

Ubuntu downloads have bounded connection timeouts and one apt retry. MATLAB provisioning has a five-minute step limit and at most one retry; the workflow explicitly requires successful setup. Artifact uploads also have one bounded retry with identical contents under a distinct retry name; a successful upload is required. Selection and binary consumers download the successful artifact ID, avoiding unfinished-name conflicts. The aggregate rejects ambiguous duplicate MATLAB reports. Tests, analyzer, documentation generation and qualification have no automatic retry or continue-on-error.

## Broader qualification

The focused driver excludes the existing `optional` and `exhaustive` test categories; their dedicated Extended jobs retain them. Reports list excluded methods and any classes wholly belonging to those categories; a class cannot be silently omitted or both excluded and executed. An assumption failure in any selected test fails both its MATLAB job and the aggregate. Dispatch the central workflow with `complete=true` for complete focused qualification, on both R2025b and R2026a, including all transform groups and the three `longerContinuationMatchesMatlab` methods. Ordinary focused runs retain lifecycle/storage checks and shorter MATLAB–C++–MATLAB continuation fixtures.

The existing transform qualification workflows remain available for explicit campaigns with their original machine-readable qualification reports. Extended Full runs on both R2025b and R2026a on published releases or manual dispatch. Exhaustive and optional suites, sanitizer probes and isolated package validation remain on R2025b. They are not ordinary merge requirements. The published-release trigger validates the release after publication; it is not a pre-publication gate. Package/release work selects isolated package verification; publication continues through the existing release workflow.

## Required-check migration

Until hosted evidence establishes the new aggregate, the default migration bridge actually executes all old required MATLAB phases and reports their existing names only after the aggregate succeeds. Keep `WVM_CI_LEGACY_REQUIRED_CHECKS` unset or true during this phase.

After reviewing successful hosted coverage and negative gate tests, replace the three required check names with `Required / WaveVortexModel`, preserving strict branch protection. Then set `WVM_CI_LEGACY_REQUIRED_CHECKS=false` to enable documentation/prose routing without forced legacy phases. No required check is bypassed during migration.

## Verification and timing

Run `python3 -m pip install -r tools/ci/requirements.txt`, then `python3 -m unittest discover -s tools/ci -p 'test_*.py' -v`. Routing examples include documentation, MATLAB, transform C++, shared persistence, CI changes, deleted/renamed files, and unknown paths. Gate tests inject failures, cancellation, absent jobs/reports/methods, stale revisions, and incompatible artifacts. Workflow contracts check the real dependency graph and infrastructure-only retry.

Use actionlint to validate all workflow files before deployment. `tools/ci/measure_runs.py --run RUN_ID --output FILE` records job/step times across attempts without counting carried-forward successes twice. These are elapsed runner seconds, not invoice charges; incomplete jobs are identified explicitly. Timing evidence lives in `.github/ci-evidence/`.

The ordinary required-path target is roughly 5–8 minutes with healthy provisioning. Documentation rendering, broad scientific changes, sanitizer builds, and complete qualification may exceed that target. Report measured hosted results separately from estimates and local timings.
