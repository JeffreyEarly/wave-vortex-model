# Issue #353: bounded adiabatic qualification and release handoff

The current bounded free-surface QG requirements are covered by the merged implementation and independent controls. On 8 September 2026, all 126 cases in 13 relevant suites passed on the current authoring dependency graph. The unchanged default example also completed day 64 with a day-32 standard-file restart, both endpoints active, and 65 daily coefficient records. This audit found no additional runtime correction necessary for this scope.

This report is the current #353 evidence handoff. It supersedes historical next-work recommendations in the linked reports that made the thin seasonal diffusion-layer accuracy target a core completion gate. Their numerical results and failed accuracy criteria remain unchanged. Released-provider adoption, exported examples, full scientific CI and installation qualification remain #354.

## State and closure contract

The primary model uses adiabatic APV, wave, zero-APV boundary and applicable mean families. This QG implementation evolves `Ag_q`, `Ag_0` and `Amda`; its wave-bearing Boussinesq sibling retains its own declared families. A shared physical sampling grid does not imply equal coefficient-family counts.

`WVVerticalDiffusivity` projects the closure into the chosen adiabatic space. `WVDensityDiffusionIntegrator` uses a complete square diagonalization of that projected matrix to integrate it efficiently. Its balanced coordinate count is the APV count plus the active endpoint count; the mean block retains all MDA directions. This changes internal integration coordinates without introducing extra spatial modes. Accepted model state, physical reconstruction and persistence remain canonical. Tests check square completeness, zero-diffusion behavior, equality to the full projected matrix exponential, and canonical output with no `Ag_T` variable.

The optional complete thermal-mode study lives in `Documentation/Experiments/Diffusion`, outside core test discovery and the exported package payload. It belongs to #389. The three-cycle adiabatic seasonal application belongs to #367. Neither is needed to close this bounded qualification.

## Requirement-to-evidence audit

| Core requirement | Independent evidence and present checks | Qualification boundary |
| --- | --- | --- |
| Reconstruction and equations | `TestWVTransformFreeSurfaceQG` checks pure and mixed APV/boundary/MDA reconstruction, family shapes, manufactured tendencies and independently formed physical Jacobians for each endpoint configuration. `TestFreeSurfaceQGVerticalCalculus` checks polynomial derivatives, stretched-coordinate metric terms, Gaussian analytical QGPV and stored calculus. | Resolved-mode correctness; round trips alone are not the evidence for derivative physics. |
| Strict source and projected diffusion | `TestFreeSurfaceQGDensityForcing` and `TestFreeSurfaceQGDiffusionQualification` check zero direct interior QGPV/MDA source, surface-only forcing, zero-diffusion integration, independent physical-depth quadrature of the weak operator, and manufactured strong/weak agreement including both boundary-flux signs. `TestDensityDiffusionIntegrator` checks the full discrete propagator and sinusoidal source against independent matrix-exponential references. | Correct projection and integration do not imply that every continuum boundary layer is resolved. |
| Unforced nonlinear invariants and refinement | `TestFreeSurfaceQGDiagnostics` compares modal inventories with independent physical quadrature. `TestFreeSurfaceQGConservation` uses nonparallel horizontal modes and nonzero nonlinear tendencies, constant/exponential stratification, time-step refinement, and horizontal/vertical refinement. The transform's default forcing registry contains nonlinear advection only in this control. | The [#348 report](Issue348InvariantQualification.md) records bounded errors and the signed generalized-energy scale. These are interacting controls, not a single mode with a vanishing Jacobian. |
| Staged coupled QG case | `TestShortSeasonalQG` checks seed/source initialization, all process tendencies and inventory rates, actual accepted steps, time refinement and complete-model restart. Independent drag-work checks are in `TestFreeSurfaceQGBottomFriction`. The [short-case report](Issue353ShortSeasonalQG.md) records omission sensitivities and budgets. | Budget sums verify dispatch/accounting. Independent inventory and drag-work tests supply the physical foundation. Bottom drag is weak in this short surface-seeded case. |
| Sampling versus retained content | `TestShortSeasonalQGSpatialAccuracy` reruns the 17-configuration matrix: fixed-band sampling, time and horizontal refinement, APV-count changes and separate damping sensitivity. `TestSeasonalResponseAssessment` checks public observable-specific error estimates and reference convergence against independent references. | The [spatial report](Issue353SpatialAccuracy.md) preserves unresolved content. Resolution-dependent damping changes the closure and cannot be interpreted solely as discretization error. |
| Restart and resolution transfer | `TestFreeSurfaceResolutionTransfer` preserves independent counts and modal identity, measures discarded physical fields, rejects incompatible physics/forcing conversion, and continues transferred states. `TestFreeSurfaceOutputRestart` exercises QG/Boussinesq committed-prefix recovery, observers, malformed streams and continuation. Integrator tests verify restoration without invoking a scientific factory. | [Transfer](Issue352ResolutionTransfer.md) and [output/restart](Issue352OutputRestart.md) reports retain fresh-process provider-free evidence. These are bounded compatible-problem contracts, not arbitrary forcing conversion or universal adaptive continuation. |
| Supported example and limits | The [authoring example guide](../Examples/README.md) identifies the unchanged composition, exact command, counts, source, restart and limits. The current default run is recorded in `issue-353-adiabatic-example.csv`. | Authoring execution is qualified here; adoption into a released/exported workflow is #354. |

Observable tolerances remain explicit in the tests and linked reports. For example, independent 257/513-point weak-assembly quadrature changes must be below `1e-6`, and the mass-times-generator comparison below `1e-4` in its relative norm; the manufactured strong/weak boundary-flux check uses `1e-10`. The full projected propagator comparison uses a `1e-9` relative bound. Process coefficient and inventory sums use `1e-12` relative to the total or sum-of-absolute-rate scale. Aligned and shifted seasonal restarts use `1e-6` for the maximum state/inventory/output relative residual. These tolerances test different quantities and are not a continuum seasonal error budget.

## Accuracy conclusions that remain unchanged

The reduced 14-APV example demonstrates composition, dynamics, integration and persistence. It is not a continuum-qualified seasonal QGPV simulation. Small time error and physical energy error can coexist with large unresolved QGPV or endpoint error.

The corrected-provider [endpoint sensitivity report](Issue353EndpointSensitivity.md) establishes the fixed-band sampling correction, not retained-band continuum accuracy. The independent [retained-band study](Issue353RetainedBand.md) finds 13.411% QGPV error at day 64 with 217 APV modes, and inadequate bottom convergence through the tested high bands. The [endpoint evolution diagnosis](Issue353EndpointEvolution.md) finds zero direct bottom source, reconciled signed budgets and a dominant retained surface-gradient residual in the bottom action. It does not establish another weak-operator defect. Separate surface/bottom absolute and relative errors must remain visible; a surface-dominated combined norm cannot certify the bottom.

`WVVerticalDiffusivity.assessSeasonalResponse` provides observable-specific estimates and reference-convergence information for its stated linear seasonal problem. Read representation, evolution, total error, absolute scales and reference stability together. Optional user tolerances express a chosen accuracy requirement; there is no default universal one-percent certificate. A linear response assessment is not an error estimator for an arbitrary nonlinear coupled trajectory. The recorded intended-resolution preflight retains its failed reference/accuracy checks.

Further attempts to resolve that demanding diffusion layer, or comparisons with additional physically defined thermal modes, are research under #389. Continuing the long adiabatic application is #367. Closing #353 does not turn their failed numerical targets into passes or change the physical forcing.

## Current verification and reproduction

The audit used MATLAB R2026a on local Apple Silicon and independent authoring checkouts. All checkouts were clean at the start. The exact WVM baseline and actual dependency revisions are:

| Checkout | Revision |
| --- | --- |
| `class-annotations` | `ca212699516e30792bd3e584b7842289c49ca772` |
| `netcdf` | `17d00778fdc79284723139f57d3a88fef53f2247` |
| `spline-core` | `0ce6950e6328e931fe91797dfd707c24ceac8f6f` |
| `chebfun` | `1fe01297a74d9ee765a466c3068b7fb474bee053` |
| `distributions` | `cc0e9fa337de5e308978049c798d5fb6069e05a6` |
| `internal-modes-evp` | `58d8a1247cbf9866839a4c54416eb48fc5939ed9` |
| `wave-vortex-model` | `929619cda20449b51e000d1d7f4bf98ab20c00a6` |

InternalModes `58d8a12` includes corrections from merged provider PRs #15/#16 and the analytical APV-root fix in still-open provider PR #17. This is authoring provenance, not a claim of an available corrected package release. The declared WVM package dependency floor was not changed.

| Test class | Passing cases |
| --- | ---: |
| `TestWVTransformFreeSurfaceQG` | 33 |
| `TestFreeSurfaceQGVerticalCalculus` | 7 |
| `TestFreeSurfaceQGDensityForcing` | 7 |
| `TestDensityDiffusionIntegrator` | 15 |
| `TestFreeSurfaceQGBottomFriction` | 3 |
| `TestSeasonalResponseAssessment` | 8 |
| `TestFreeSurfaceQGDiagnostics` | 7 |
| `TestFreeSurfaceQGConservation` | 3 |
| `TestFreeSurfaceQGDiffusionQualification` | 9 |
| `TestShortSeasonalQG` | 4 |
| `TestShortSeasonalQGSpatialAccuracy` | 2 |
| `TestFreeSurfaceResolutionTransfer` | 8 |
| `TestFreeSurfaceOutputRestart` | 20 |

The [test ledger](issue-353-adiabatic-tests.csv) records all 126 names, statuses and durations; none failed or were incomplete. With this dependency graph on the MATLAB path and the working directory at the WVM authoring root, the ledger selects the same suites:

```matlab
ledger = readtable('Documentation/Validation/issue-353-adiabatic-tests.csv',TextType="string");
classes = unique(extractBefore(ledger.test,"/"),"stable");
results = runtests(fullfile("UnitTests",classes+".m"));
assertSuccess(results);
```

Run the default example as described in its guide, using a new output path. This audit checked day 64, `[24 24 65]` sampling, 14 APV modes, two MDA modes, active endpoints `[1;2]`, exactly zero MDA, 65 daily records from day zero through day 64, and a maximum accepted step of 21600 seconds after restart. The [example ledger](issue-353-adiabatic-example.csv) records its configuration and result. Generated NetCDF/MAT files are local audit artifacts, not committed release assets.

Earlier reports retain their original revisions and numerical tables; those values are not relabeled as freshly regenerated measurements here. Current tests recheck their executable assertions on the graph above. No runtime, test implementation, public API, hierarchy, package metadata, experiment pin or saved trajectory changes were needed. This handoff changes authored documentation and adds verification ledgers only.

Documentation verification (`buildtool("docs:check")`) passed with ClassDocumentation 1.3.2 at `42af499929c331cec3ade0bfb4a34121c4faa76e`: 2358 files, 4819 routes, zero validation failures and zero generated drift. Local links, whitespace, documentation-only scope, unchanged package metadata and unchanged generated artifacts were checked. Code Analyzer was not rerun because no MATLAB source or tests changed.

## Handoff to #354

The bounded #353 core evidence is complete. The release work should now:

1. Review the pending analytical APV-root correction on its numerical merits; release/export the corrected InternalModes provider through the ordinary authoring workflow, and adopt the appropriate declared dependency floor. Do not edit released snapshots in place.
2. Adopt the small QG example and existing linear Boussinesq demonstration into the supported exported workflow. Preserve accuracy disclosures and distinguish supported QG behavior from experimental linear Boussinesq behavior.
3. Complete migration/API documentation, capability declarations and package metadata, then run full scientific, clean-install and exported-package gates on the actual declared graph before publishing v5.

This audit does not qualify nonlinear Boussinesq dynamics, adaptive Boussinesq error control, integrated exponential particle/tracer stepping, arbitrary boundary/mass sources, long seasonal evolution or a new diffusion mode family. Full scientific and package/install checks were intentionally left to #354. No local asset was missing from this bounded audit.
