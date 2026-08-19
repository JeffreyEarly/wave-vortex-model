---
layout: default
title: Continuous integration
parent: Developers guide
nav_order: 3
---

# Continuous integration

WaveVortexModel uses non-mutating continuous integration to check changes without modifying the package, publishing a release, or exporting an OceanKit snapshot. The workflows run on Ubuntu with MATLAB R2025b and resolve runtime dependencies from OceanKit commit `96f0b801c565406dd5a4ba2480334a3a481c3e2c`. This fixed dependency snapshot makes a workflow rerun use the same OceanKit packages as the original run.

## Gate selection

Pull requests targeting an unreleased integration branch use the focused gate by default. Pull requests targeting `main`, pull requests carrying the `final-integration` label, pushes to `main`, scheduled extended verification, and manual workflow dispatches use the full gate. Adding or removing the `final-integration` label starts a replacement run so the selected evidence always agrees with the current milestone status.

The `final-integration` label is the explicit opt-in for the last cumulative integration PR before it targets `main`. Manual dispatch remains available from any branch and always runs every job in the selected workflow; it never selects the focused gate.

## Stable required check

The required workflow always reports `Required / WaveVortexModel`. This aggregate check succeeds only after the portable C++ job and the MATLAB jobs selected for the current gate succeed. Branch protection for an integration branch should require this aggregate check so conditional jobs cannot leave auto-merge pending indefinitely or allow it to merge before the focused evidence completes.

The full-gate job names remain stable for `main` and final integration branch protection:

| GitHub check | Local equivalent |
| --- | --- |
| Portable C++ kernel contract | `buildtool kernel:contract` plus the portable runtime CMake/CTest suite and source policy |
| Smoke / MATLAB R2025b | `buildtool test:smoke` |
| Documentation / MATLAB R2025b | `buildtool docs:check` plus rendered-site verification |
| Code Analyzer / MATLAB R2025b | `buildtool analyze` |

## Focused integration-branch gate

An ordinary integration-branch PR runs the portable C++ kernel contract and one `Focused MATLAB / R2025b` job. The MATLAB job checks out the pinned OceanKit snapshot, sets up MATLAB once, and invokes MATLAB once for the selected tasks. Smoke and compatibility tests always run. Code Analyzer runs when the PR changes MATLAB files, and the documentation source check runs when the PR changes canonical or generated documentation, documentation tooling, or the required workflow.

Focused documentation verification checks committed sources against a clean generation in the shared MATLAB invocation. Rendered-site verification remains in the full documentation job because it requires a Jekyll build between two MATLAB operations.

The focused job records provisioning and MATLAB execution durations separately in the workflow summary. MATLAB caching is enabled. `setup-matlab@v3` exposes only its MATLAB root as an action output, so cache restore or population details remain in the setup step log. The setup step has a ten-minute timeout; failure to reach MATLAB test execution within that budget is reported as a provisioning incident instead of waiting for the complete job timeout. Under normal GitHub service conditions, an ordinary focused PR should complete in approximately ten minutes or less.

## Final integration and main gates

The full gate preserves every release and compatibility protection:

- The required workflow runs the portable C++ contract, smoke tests, generated and rendered documentation verification, and Code Analyzer.
- The package-verification workflow runs clean-install and exported-package verification.
- The extended workflow runs the Full, Exhaustive, and Optional MATLAB categories.

The package and extended workflows are triggered for every pull request so their conditional job names are present, but their MATLAB jobs run only for PRs targeting `main` or carrying the `final-integration` label. Starting any of the three workflows manually runs that workflow's complete matrix from the selected branch.

The documentation job installs the authoring-only package `ClassDocumentation@1.3.2` explicitly before checking the committed Markdown. It then builds that exact tree with GitHub Pages' Jekyll action and validates the rendered HTML. This second stage catches malformed front matter, mathematical Markdown, expressions split across rendered table cells, or other source syntax that can pass a link check but disappear or remain raw in the deployed site. Valid math delimiters remain in the Jekyll output for browser-side MathJax. Failed rendered output is uploaded as a temporary diagnostic artifact and is never committed.

## Workflow lifecycle

Same-PR concurrency retains `cancel-in-progress: true`, so a superseding commit or gate-label change cancels the earlier run. Closing or merging a focused integration PR starts a no-job lifecycle run in the same concurrency group, which cancels obsolete focused work. A closed full-gate PR uses a distinct lifecycle concurrency group so its final evidence is not canceled after close.

Branch protection remains authoritative for merge readiness. Require `Required / WaveVortexModel` on the integration branch before enabling auto-merge. Continue requiring the complete smoke, documentation, analyzer, clean-install, exported-package, and comprehensive MATLAB check set for `main` and the final milestone integration path.

## Extended checks

The extended workflow runs every Monday at 09:00 UTC, on full-gate pull requests, and by manual dispatch. Its Full, Exhaustive, and Optional jobs remain separate so a failure identifies the affected test category. Run the same checks locally with:

```matlab
buildtool test:full
buildtool test:exhaustive
buildtool test:optional
```

The Optional job requests Optimization Toolbox. When MATLAB is available but the toolbox cannot be used, the job records an explicit skip in the workflow notice and summary. Setup, installation, licensing, or other infrastructure failures still fail the job.

The public GitHub MATLAB license permits one MATLAB process at a time. The full suite therefore verifies the explicit license-unavailable result from the benchmark's nested fresh-process memory check on GitHub Actions. On hosts that can start a second MATLAB process, the same test requires a complete resident-memory measurement. Any other benchmark-worker failure remains a test failure.

## Routine authoring checks

Each job checks out WaveVortexModel in an isolated `source` directory and the pinned OceanKit repository in a sibling `OceanKit` directory. MATLAB registers that local checkout as the MPM repository and loads the exact dependency snapshots declared by the CI setup. The workflows do not modify the OceanKit checkout.

These routine jobs configure the pinned dependency paths directly because that is faster than creating a fresh native MPM installation for every pull-request check. The native-package gates below remain authoritative for the installed package boundary. The supported runtime and native-package verification use MATLAB R2025b, matching the release engine used to prepare WaveVortexModel distributions.

The OceanKit commit is deliberately recorded in both routine workflow files, the package-verification workflow, and this page. Update all four locations together after compatibility with a newer dependency snapshot has been reviewed.

## Native-package release gates

The package-verification workflow may be started manually and runs its two MATLAB R2025b jobs for every full-gate pull request:

| GitHub check | Purpose |
| --- | --- |
| Clean install / MATLAB R2025b | Installs the authoring checkout non-editably through MPM using only the pinned OceanKit repository. |
| Exported package / MATLAB R2025b | Builds an unpublished release candidate, installs the exported folder in a fresh MATLAB process, and exercises it as a consumer. |

Both jobs use isolated MATLAB preferences and temporary MPM installations. They require the exact declared dependency graph and reject dependencies that resolve from sibling authoring repositories. The installed package path must omit `UnitTests`, test doubles, and `RunAllUnitTests`.

The exported-package job first verifies committed documentation with `ClassDocumentation@1.3.2`. In a temporary clone it promotes the complete `Unreleased` changelog body, regenerates documentation, and exports the next patch candidate outside the source checkout. The source and candidate versions are derived from the manifest so the gate remains valid after a release. Only the manifest, changelog, and generated version history may change during that preparation. A second fresh MATLAB process installs the export and exercises constant- and variable-stratification transforms, linear evolution, and NetCDF state restoration. This dry run creates no tag, GitHub release, or OceanKit snapshot.

Routine authoring checks and native-package gates serve different purposes. The former provide fast feedback on every change; the latter prove that the package manager and exported consumer boundary work on the supported MATLAB floor.

## Clean checkout requirement

Every job runs a final cleanliness check even when its MATLAB command fails. A successful job must leave:

- No tracked modifications.
- No untracked files.
- No ignored NetCDF, MAT-file, autosave, profiling, or test-result artifacts.
- No generated documentation drift.

The check prints every unexpected path before failing. Tests that write files must therefore use managed temporary folders and close all file handles. Run `bash tools/checkCIWorkspaceCleanliness.sh` from a clean checkout to apply the same repository check locally.
