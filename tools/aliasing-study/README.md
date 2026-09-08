# Sparse quadratic-product assessment (issue 400)

This authoring study is in progress. `PLAN.md` records the initial choices before observing the pilot. There is no runtime-default change or sparse-policy recommendation yet.

## Reproduce the initial pilot

Use the WVM study worktree based on `9fefcc9a528de65e2f348706c45b13f741754a78` and the OceanKit export at `80006f5040da787465860249f975def9831624c8`. From the common parent directory, with those worktrees named `wvm-issue-400` and `wvm400-oceankit`:

```sh
matlab -batch "restoredefaultpath; addpath('wvm-issue-400/tools/aliasing-study'); configureStudyPath('wvm400-oceankit'); results=runtests('wvm-issue-400/tools/aliasing-study/TestProductProjection.m'); assertSuccess(results);"
matlab -batch "restoredefaultpath; addpath('wvm-issue-400/tools/aliasing-study'); configureStudyPath('wvm400-oceankit'); runPilot('wvm-issue-400/tools/aliasing-study/results/pilot-02');"
```

On the local Apple Silicon host, run MATLAB outside the Codex sandbox as specified by the shared workspace instructions. Use a new output directory for each run; preserve previous outputs. Only the explicit exported dependency packages and their manifest-listed folders are added to the path. The authoring helpers are excluded from the runtime package manifest.

## Initial result and limits

`results/pilot-01` contains the complete 224-row vector interaction inventory, 930 channel summaries, and per-product errors for each output prefix. The scalar inventory has 31 distinct magnitude triples and 26,040 unique product evaluations. The same products are integrated with two reference rules; those repeated integrations are additional work beyond this unique-product count. Every actual vector interaction maps to a listed magnitude triple. Direction-independent scalar factors allow this reuse; this does not justify collapsing direction-dependent full vector source projections.

The initial constant-profile run took 2.906 seconds for construction (including the APV control) and 3.628 seconds for assessment. Its maximum reference-integration discrepancy was 2.577e-14 and maximum eigenvalue/F/G shape discrepancy was 4.319e-10. These are pilot feasibility results. The summary's `referencesStable` flag concerns those implemented checks only. Independent derivative-convergence evidence, complete source-channel coverage, and process peak memory are still pending.

The error engine reproduces the provider's trigonometric two-thirds cutoff and signed-APV errors. It also has independent checks for complex products, exact zero products, and exclusion of exterior/truncated content from the aliasing numerator. Projection uses signed Gram solves; magnitudes use the target's positive Hilbert majorant. Zero-wavenumber F outputs use WVM's actual fixed inertial dual and G outputs use the MDA family. This differs from replacing zero outputs with a wave page.

Pilot channels are F*G->G, G*dG->G, G*dF->F, F*F->F, and G*G->F. Nonzero G targets are scalar wave-G projections; nonzero F targets are APV-F projections. Inputs include wave-wave, both orders of wave-APV and wave-boundary, and APV-boundary. Boundary labels 1 and 2 mean surface and bottom. Derivatives in this first pilot use the governing mode relations. The extra GG->F channel is a provider control. This is explicitly an adapter pilot, not the final physical channel inventory. In particular, it does not yet include both signed wave polarizations in the generalized-energy source dual, the stratification-factor term, or boundary output projections. It cannot be used to score or recommend a physical retained-count policy yet.

## Next work

1. Completed: physical source inventory, independent derivative/product references, pilot cost, and case/policy freeze.
2. Calibration and policy freeze are complete. Evaluate the untouched withheld cases next.
3. Perform the larger sparse/independent-sample cost check and produce comparison tables, recommendation, and API proposal.

The full acceptance criteria remain in `PLAN.md` and GitHub issue 400. No issue closure or runtime adoption is warranted by this pilot.

## Physical-source study checkpoint

The physical source engine and four calibration cases are now complete. `SOURCE-PILOT.md` documents reference controls and the short-domain inconclusive finding. `case-inventory.json` fixes calibration, withheld, and larger cases. `POLICIES.md` specifies the three candidates, and `policy-freeze.json` records the final pre-withheld rule hashes and zero count margin.

Both sparse selectors match all 12 calibration quadratic count decisions. The actual current Gram gate is more conservative: it retains 3 or 8 wave modes while the quadratic-only dense band contains 6–7 or 12–14 modes, depending on tolerance. Version-2 tables under `results/calibration-v1/*-scores-v2` report both effects. Withheld validation and actual sparse cost replays remain required before a recommendation.

To run the declared splits, call `runStudyCases("calibration",freshOutputRoot)` or `runStudyCases("withheld",freshOutputRoot)` after `configureStudyPath`. Every completed survey is preserved; a missing scoring stage can resume from its existing saved errors. `runSourceSurvey` also supports `policy="fixed"` or `policy="targeted"` for actual sparse replays, and explicit interaction indices for an independent spot sample.

Full per-product MAT files are preserved in this working copy and listed with SHA-256 checksums in `results/mat-artifact-manifest.json`. Large MAT files are intentionally excluded from Git fixtures; the CSV/JSON result tables, code, case inventory, and reproduction commands are versioned. A fresh checkout can recreate the MAT data by running the declared studies. Preserved inconclusive runs must not be used as validation scores.
