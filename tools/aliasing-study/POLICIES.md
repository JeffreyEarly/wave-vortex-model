# Candidate policies before calibration

Version 1. The bounded case inventory is fixed in `case-inventory.json`. Four calibration cases, four withheld cases, and one larger sparse/spot-sample case are declared before scoring. The wider-domain choice and independent fixed counts follow the documented source pilots. No withheld nonlinear errors have been examined. Changes to the reference apparatus require a recorded numerical reason; they do not authorize retuning a policy using withheld outcomes.

The physical dense inventory is every retained vector-closed ordered interaction with nonzero inputs on each actual Fourier grid, eight declared ordered family pairs, all input modes and both wave signs, and the 13 volume channels in `sourceChannelInventory`. Mean-w outputs are structurally absent. The independent APV control is unchanged. Only the common wave prefix varies; each case's APV, MDA, and inertial counts remain strict and independent.

Every policy requires the per-page wave Gram gate and reference convergence. A fixed-family Gram failure reports the explicit configuration as rejected; it must not silently reduce an independent count. An unstable reference makes the score inconclusive. The comparison examines individual retained-product coefficients and uses the exact same saved error matrices for every policy. No single product metric is a superposition/operator bound.

## Linear baseline

Use eigenmode/reference-resolution checks and the existing wave Gram gate only. The policy evaluates no quadratic stress products. The dense reference remains available offline to identify errors that the baseline misses.

## Fixed sparse tests

Use up to six evenly spaced anchors among the positive retained magnitude pages. At each anchor select up to four distinct valid vector interactions: largest relative output magnitude, strongest cancellation, widest input-scale separation, and most transverse input directions. The total budget is at most 24 ordered interactions. Input mode stresses for each candidate count include the external mode, the next mode, the middle mode, and the top three retained modes. Preserve all APV and both boundary modes and both wave signs. Retain previously tested input pairs as the prefix grows. Cumulative reuse makes a prefix decision monotone and avoids discarding already-computed evidence.

## Targeted sparse tests

Start with the fixed set. Add at most 12 interactions greedily ranked by normalized geometric distance from selected tests, multiplied by one plus the normalized largest mode/derivative Chebyshev-tail indicator on the interaction's input pages. Ties use the original interaction index. Use the same cumulative mode-pair stresses. The indicator is a candidate whose observed performance will be measured; it is not a nonlinear guarantee.

The tail uses the last four coefficients on the model's fixed WKB-Chebyshev grid, normalized by the full coefficient-vector norm. It is computed from F, G, and their relevant derivatives, including localized boundary modes. This selection uses modes and geometry only, not withheld product errors.

## Calibration, freeze, and cost

Version 1 initially has zero count margin. Calibration may support a modest additional count margin or a documented change to the candidate rule. Freeze any final choice before accessing withheld product errors; if withheld failures motivate retuning, new withheld cases are required. Negative results are acceptable.

Report both the full candidate-plan product count and the count through the first failing prefix (or the end of the candidate band). A product evaluation produces every retained output coefficient; output-prefix norms reuse that result. Structural zeros are counted separately. Assessment time includes finer reference work; construction time includes both EVP resolutions, reference setup, polarizations, and source contexts. Use separate actual sparse replays to validate virtual scoring and measure cost. The larger independent sample uses seed 400 and 64 interactions drawn without consulting the policy selection or observed errors; its mode-pair coverage is dense within those interactions.

## Scoring clarification before withheld access

The dense quadratic-only count is computed independently of the linear Gram gate. Report the jointly admissible count separately. `retainedCountLoss` is the loss relative to the quadratic-only dense band, including the conservative linear gate shared by every policy. `additionalQuadraticLoss` is the loss relative to the jointly admissible band. This prevents an apparently zero-penalty policy from hiding substantial count loss imposed by its linear prerequisite. The original calibration-v1 scores combined these two concepts; preserve them as superseded diagnostics and generate version-2 score tables from the unchanged saved errors. This is a reporting correction, not a selection-rule change.

Before withheld access, the targeted rule was clarified to use input-page tails only. This avoids letting an unused derivative on a mean-output page dominate the heuristic. The geometric features still include the output magnitude and angle. Calibration version-2 scores use this final rule; there is still no count margin.

A second diagnostic table removes the linear prerequisite solely to expose the quadratic selectors' coverage. These are not usable constructor counts. The common strict Gram gate currently masks differences at larger counts, so this diagnostic reports sparse quadratic false acceptance and count loss across the full predeclared candidate band. It reuses the exact same prefix errors and selected interactions. The actual policy table always retains the required linear gate.
