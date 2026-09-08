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

1. Complete the physical source-channel inventory and independent derivative convergence, then measure pilot peak memory and freeze the bounded case matrix.
2. Implement and calibrate the three policies with independent coefficient-family counts, freeze their budgets and any margin, then evaluate withheld cases.
3. Perform the larger sparse/independent-sample cost check and produce comparison tables, recommendation, and API proposal.

The full acceptance criteria remain in `PLAN.md` and GitHub issue 400. No issue closure or runtime adoption is warranted by this pilot.
