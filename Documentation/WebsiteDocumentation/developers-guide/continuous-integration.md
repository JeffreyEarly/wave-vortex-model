---
layout: default
title: Continuous integration
parent: Developers guide
nav_order: 3
---

# Continuous integration

WaveVortexModel uses non-mutating continuous integration to check changes without modifying the package, publishing a release, or exporting an OceanKit snapshot. The workflows run on Ubuntu with MATLAB R2024b and install runtime dependencies from OceanKit commit `eb71bc7b05e74776afd678b27c964cf53cd9d547`. This fixed dependency snapshot makes a workflow rerun use the same OceanKit packages as the original run.

## Required checks

The required workflow runs for every pull request, every update to `main`, and manual dispatches. It reports three independent jobs:

| GitHub check | Local equivalent |
| --- | --- |
| Smoke / MATLAB R2024b | `buildtool test:smoke` |
| Documentation / MATLAB R2024b | `buildtool docs:check` |
| Code Analyzer / MATLAB R2024b | `buildtool analyze` |

The documentation job installs the authoring-only package `ClassDocumentation@1.3.0` explicitly before checking the committed site. Smoke tests, documentation verification, and Code Analyzer are required to merge into `main`. Branch protection requires the pull request branch to be current with `main` before those checks can satisfy the merge gate.

## Extended checks

The extended workflow runs every Monday at 09:00 UTC and may be started manually. Its Full, Exhaustive, and Optional jobs remain separate so a failure identifies the affected test category. Run the same checks locally with:

```matlab
buildtool test:full
buildtool test:exhaustive
buildtool test:optional
```

The Optional job requests Optimization Toolbox. When MATLAB is available but the toolbox cannot be used, the job records an explicit skip in the workflow notice and summary. Setup, installation, licensing, or other infrastructure failures still fail the job. The extended checks provide deeper scheduled coverage but do not block ordinary pull-request merges.

## Package installation

Each job checks out WaveVortexModel in an isolated `source` directory and the pinned OceanKit repository in a sibling `OceanKit` directory. MATLAB registers that local OceanKit checkout as the MPM repository and installs WaveVortexModel in authoring mode. The workflows do not inspect or modify the OceanKit checkout beyond using it as the package source.

The OceanKit commit is deliberately recorded in both workflow files and this page. Update all three locations together after compatibility with a newer dependency snapshot has been reviewed. Clean-install and exported-package testing are separate release gates and do not replace these authoring checks.

## Clean checkout requirement

Every job runs a final cleanliness check even when its MATLAB command fails. A successful job must leave:

- No tracked modifications.
- No untracked files.
- No ignored NetCDF, MAT-file, autosave, profiling, or test-result artifacts.
- No generated documentation drift.

The check prints every unexpected path before failing. Tests that write files must therefore use managed temporary folders and close all file handles. Run `bash tools/checkCIWorkspaceCleanliness.sh` from a clean checkout to apply the same repository check locally.
