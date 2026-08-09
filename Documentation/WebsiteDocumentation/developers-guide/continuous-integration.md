---
layout: default
title: Continuous integration
parent: Developers guide
nav_order: 3
---

# Continuous integration

WaveVortexModel uses non-mutating continuous integration to check changes without modifying the package, publishing a release, or exporting an OceanKit snapshot. The workflows run on Ubuntu with MATLAB R2025b and resolve runtime dependencies from OceanKit commit `eb6141e837b2a2d52db675d449ed0ac4c9a64bb5`. This fixed dependency snapshot makes a workflow rerun use the same OceanKit packages as the original run.

## Required checks

The required workflow runs for every pull request, every update to `main`, and manual dispatches. It reports three independent jobs:

| GitHub check | Local equivalent |
| --- | --- |
| Smoke / MATLAB R2025b | `buildtool test:smoke` |
| Documentation / MATLAB R2025b | `buildtool docs:check` |
| Code Analyzer / MATLAB R2025b | `buildtool analyze` |

The documentation job installs the authoring-only package `ClassDocumentation@1.3.0` explicitly before checking the committed Markdown. It then builds that exact tree with GitHub Pages' Jekyll action and validates the rendered HTML. This second stage catches malformed front matter, mathematical Markdown, expressions split across rendered table cells, or other source syntax that can pass a link check but disappear or remain raw in the deployed site. Valid math delimiters remain in the Jekyll output for browser-side MathJax. Failed rendered output is uploaded as a temporary diagnostic artifact and is never committed.

Smoke tests, source-and-rendered documentation verification, and Code Analyzer are required to merge into `main`. Branch protection requires the pull request branch to be current with `main` before those checks can satisfy the merge gate.

## Extended checks

The extended workflow runs every Monday at 09:00 UTC and may be started manually. Its Full, Exhaustive, and Optional jobs remain separate so a failure identifies the affected test category. Run the same checks locally with:

```matlab
buildtool test:full
buildtool test:exhaustive
buildtool test:optional
```

The Optional job requests Optimization Toolbox. When MATLAB is available but the toolbox cannot be used, the job records an explicit skip in the workflow notice and summary. Setup, installation, licensing, or other infrastructure failures still fail the job. The extended checks provide deeper scheduled coverage but do not block ordinary pull-request merges.

The public GitHub MATLAB license permits one MATLAB process at a time. The full suite therefore verifies the explicit license-unavailable result from the benchmark's nested fresh-process memory check on GitHub Actions. On hosts that can start a second MATLAB process, the same test requires a complete resident-memory measurement. Any other benchmark-worker failure remains a test failure.

## Routine authoring checks

Each job checks out WaveVortexModel in an isolated `source` directory and the pinned OceanKit repository in a sibling `OceanKit` directory. MATLAB registers that local checkout as the MPM repository and loads the exact dependency snapshots declared by the CI setup. The workflows do not modify the OceanKit checkout.

These routine jobs configure the pinned dependency paths directly because that is faster than creating a fresh native MPM installation for every pull-request check. The native-package gates below remain authoritative for the installed package boundary. The supported runtime and native-package verification use MATLAB R2025b, matching the release engine used to prepare WaveVortexModel distributions.

The OceanKit commit is deliberately recorded in both routine workflow files, the package-verification workflow, and this page. Update all four locations together after compatibility with a newer dependency snapshot has been reviewed.

## Native-package release gates

The package-verification workflow may be started manually and runs on pull requests that change production source, package metadata, documentation, release workflows, or verification tools. Test-only, benchmark-only, and developer-experiment changes do not start it automatically. It reports two independent MATLAB R2025b jobs:

| GitHub check | Purpose |
| --- | --- |
| Clean install / MATLAB R2025b | Installs the authoring checkout non-editably through MPM using only the pinned OceanKit repository. |
| Exported package / MATLAB R2025b | Builds an unpublished release candidate, installs the exported folder in a fresh MATLAB process, and exercises it as a consumer. |

Both jobs use isolated MATLAB preferences and temporary MPM installations. They require the exact declared dependency graph and reject dependencies that resolve from sibling authoring repositories. The installed package path must omit `UnitTests`, test doubles, and `RunAllUnitTests`.

The exported-package job first verifies committed documentation with `ClassDocumentation@1.3.0`. In a temporary clone it promotes the complete `Unreleased` changelog body, regenerates documentation, and exports the next patch candidate outside the source checkout. The source and candidate versions are derived from the manifest so the gate remains valid after a release. Only the manifest, changelog, and generated version history may change during that preparation. A second fresh MATLAB process installs the export and exercises constant- and variable-stratification transforms, linear evolution, and NetCDF state restoration. This dry run creates no tag, GitHub release, or OceanKit snapshot.

Routine authoring checks and native-package gates serve different purposes. The former provide fast feedback on every change; the latter prove that the package manager and exported consumer boundary work on the supported MATLAB floor.

## Clean checkout requirement

Every job runs a final cleanliness check even when its MATLAB command fails. A successful job must leave:

- No tracked modifications.
- No untracked files.
- No ignored NetCDF, MAT-file, autosave, profiling, or test-result artifacts.
- No generated documentation drift.

The check prints every unexpected path before failing. Tests that write files must therefore use managed temporary folders and close all file handles. Run `bash tools/checkCIWorkspaceCleanliness.sh` from a clean checkout to apply the same repository check locally.
