---
layout: default
title: Release checklist
parent: Developers guide
nav_order: 4
---

# Release checklist

Use this checklist for a maintenance release after every issue assigned to the release milestone is complete or explicitly deferred. Release preparation must not introduce scientific capabilities, unannounced API changes, or documentation changes that were not reviewed on the release branch.

## v4.4.1 tracer performance patch

- Qualify the reviewed combined horizontal and Hydrostatic/Boussinesq vertical derivative implementation using the [tracer report](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/Benchmarks/TRACER-DERIVATIVES.md). Retain all three fresh-process samples per Hydrostatic coefficient/composite configuration, unchanged numerical tolerances and integration-work checks, and the final source/module/provider identities.
- Refresh the six source-bound forward-integration configurations, including Boussinesq and downstream tracer evolution, and require the affected native, MATLAB, documentation, analyzer and package checks. Preserve historical receipts whose scientific sources were not changed.
- Keep the authoring manifest at `4.4.0` through qualification and the reviewed PR. Dispatch the immutable release workflow with `bump: patch` to create `4.4.1` using the public MATLAB package API and promote the complete nonempty `Unreleased` section.
- Update the benchmark page with the identified follow-up cohort. Preserve the original v4.4.0 publication results, and distinguish Hydrostatic whole-workload qualification from Boussinesq primitive diagnostics.
- Verify the release tag, authoring version, exported snapshot and installed consumer after publication, following the shared gates below.

## Historical v4.4.0 benchmark qualification

The following records the completed v4.4.0 release campaign; its version transition and publication-cohort requirements are historical.

- Confirm the release commit retains the source-bound implementation qualified by the checked-in issue #507 receipts and the final issue #307 and #310 standard-parity decision. Reuse those passing native, MATLAB, consumer, lifecycle and installed-package results while their tracked scientific and adapter sources remain unchanged; do not repeat unchanged qualification solely for release preparation.
- Confirm the proposed minor release is `v4.4.0`, the authoring manifest still begins at `4.3.0`, and the release workflow will promote the complete nonempty `Unreleased` body. Release-owned version, date, changelog and generated-documentation changes must not alter the measured scientific implementation.
- Complete issue #501's frozen 54-process campaign: constant stratification, Hydrostatic and Boussinesq; MATLAB builtin, MATLAB compiled and standalone C++; coefficient-endpoint and composite dense-output workloads; three fresh-process replicates at `[256 256 129]` over 7,168 seconds. Require all numerical, integration-control, artifact and storage gates before publishing the dataset.
- Bind every published benchmark record to the measured source, executable or module, provider, release-version and environment metadata. Report the measured host, MATLAB release and effective thread policy from recorded provenance; do not substitute a planned machine label or a MATLAB-normalized timing for an absolute interface runtime.
- Run the focused benchmark contract, schema, website and documentation checks affected by issue #501 and require PR #510's passing hosted checks plus the selected checks for subsequent release-candidate changes. Reuse the unchanged passing PR #509 clean-install and exported-package gates, issue #507 all-six installed qualification, and issue #307/#310 parity receipts after confirming their source identities still match.
- Inspect the release workflow's ordinary-clone export, require no Git metadata or package-local compiled build artifacts in the payload, and verify its manifest, runtime paths and representative installed consumer. Record the final campaign receipt, source commit, CI runs and validated export before dispatching the immutable minor-release workflow.

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
