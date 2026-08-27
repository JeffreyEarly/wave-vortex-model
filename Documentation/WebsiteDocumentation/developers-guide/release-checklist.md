---
layout: default
title: Release checklist
parent: Developers guide
nav_order: 4
---

# Release checklist

Use this checklist for a maintenance release after every issue assigned to the release milestone is complete or explicitly deferred. Release preparation must not introduce scientific capabilities, unannounced API changes, or documentation changes that were not reviewed on the release branch.

## v4.3 portable-runtime qualification

- Confirm issue #287 is the only final open item in milestone 14 before qualification and that its focused branch targets `feature/v4.3-portable-runtime`, not `main`.
- On Matilda with MATLAB R2026a Update 4, run portable C++ tests; focused MATLAB request, schema, runtime, restart, and interoperability tests; `buildtool test:full`; `buildtool test:optional`; `buildtool analyze`; and `buildtool docs:check`.
- Verify omitted and explicit v2 defaults are equivalent for constant stratification and Barotropic QG, including post-restoration CFL `0.5`, the one-tenth continuation maximum step, requested-versus-active report fields, v1 round trips, explicit overrides, and no provider fallback.
- Build the pinned native FFTW runner on Apple silicon and run only short functional provider and integration checks. Confirm the actual automatically bounded thread count and provider identity, and prove native unavailability leaves model output unchanged.
- Verify fixed RK4 and MATLAB-compatible `ode23`, `ode45`, and `ode78`; supported forcing and observers; compact QG state; exact and dense output; multi-file policies; restart; MATLAB continuation; and tracked-files-only source/export policy.
- Run the clean exported-package verification and inspect generated-documentation determinism and stable compiled-execution routes. Record any unavailable hosted Linux/R2025b structured-unavailability check explicitly.
- Treat issue #312's accepted Donut `[256 256 129]` record as frozen release evidence. Do not rerun the canonical performance suite, generate replacement timing or RSS data, commit raw benchmark results, or present startup time as a primary metric.
- Confirm larger matched-interface cases and unsupported transforms, forcing, observers, platforms, and plug-in models remain documented as deferred rather than inferred from the accepted evidence.

## Review the candidate

- Confirm the package version, MATLAB compatibility floor, dependency ranges, and package folders in `resources/mpackage.json`.
- Confirm `UnitTests` and other authoring-only folders are not on the installed package path.
- Review the complete `Unreleased` changelog section. It must be nonempty, describe the shipped changes, and contain no issue-planning language.
- Verify that benchmark claims cite the reviewed source results and remain explicitly machine dependent.
- Run `buildtool docs:check` with exactly `ClassDocumentation@1.3.2`, inspect the rendered website, and confirm the generated version history agrees with the changelog.

## Require green verification

- Required CI: Smoke, Documentation, and Code Analyzer on the final commit.
- Extended CI: Full, Exhaustive, and Optional, with any unavailable optional dependency reported explicitly.
- Native-package CI: Clean install and Exported package on MATLAB R2025b.
- Local or CI reruns leave no NetCDF files, MAT-files, generated documentation, open handles, or other repository artifacts.

The native-package checks must resolve dependencies from the immutable OceanKit snapshot rather than sibling authoring repositories. The exported-package check must install the unpublished export in a fresh MATLAB process and exercise transform construction, model evolution, variable stratification, and NetCDF restoration.

## Inspect release preparation

- Use the immutable OceanKit release workflow referenced by `.github/workflows/release-mpm.yml`.
- Require documentation verification before the workflow mutates the authoring checkout.
- For a real version bump, require the workflow to promote the complete `Unreleased` body into the dated version section and create a new empty `Unreleased` section.
- Confirm the release-body file, promoted changelog section, and generated version-history entry agree.
- Inspect the exported package manifest, runtime paths, and representative consumer behavior before publication.
- Confirm the authoring commit and OceanKit snapshot do not already exist under the proposed version or tag.

## Publish in order

The release workflow publishes the authoring commit first, the OceanKit package snapshot second, the immutable version tag third, and the GitHub release last. If OceanKit publication fails, stop with no tag or GitHub release and reconcile the repositories explicitly. Do not rewrite published history or replace an existing package snapshot as part of an ordinary release.

After publication, install the released OceanKit snapshot on a clean MATLAB path, repeat the focused consumer verification, inspect the public documentation, and record links to the final CI runs, tag, release, and exported snapshot.
