---
layout: default
title: Release checklist
parent: Developers guide
nav_order: 4
---

# Release checklist

Use this checklist for a maintenance release after every issue assigned to the release milestone is complete or explicitly deferred. Release preparation must not introduce scientific capabilities, unannounced API changes, or documentation changes that were not reviewed on the release branch.

## Review the candidate

- Confirm the package version, MATLAB compatibility floor, dependency ranges, and package folders in `resources/mpackage.json`.
- Confirm `UnitTests` and other authoring-only folders are not on the installed package path.
- Review the complete `Unreleased` changelog section. It must be nonempty, describe the shipped changes, and contain no issue-planning language.
- Verify that benchmark claims cite the reviewed source results and remain explicitly machine dependent.
- Run `buildtool docs:check` with exactly `ClassDocumentation@1.3.0`, inspect the rendered website, and confirm the generated version history agrees with the changelog.

## Require green verification

- Required CI: Smoke, Documentation, and Code Analyzer on the final commit.
- Extended CI: Full, Exhaustive, and Optional, with any unavailable optional dependency reported explicitly.
- Native-package CI: Clean install and Exported package on MATLAB R2025a.
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
