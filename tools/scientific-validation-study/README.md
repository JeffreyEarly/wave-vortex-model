# Nonlinear scientific validation study

This study evolves the declared wave, balanced, and mixed states over bounded physical intervals and compares independently refined time steps, mode counts, horizontal grids, and vertical grids. `protocol.json` is the source case definition.

`runScientificValidationStudy` takes an explicit external work folder for restartable MAT receipts and writes compact tables beneath `fullfile(tempdir,"wave-vortex-model-studies","scientific-validation-study")`. `auditValidationSnapshots` performs independent energy, source, and spectrum controls. `plotScientificValidation` consumes the generated tables.

Keep the work folder and all generated tables and figures outside the repository. Start with a fresh folder whenever the protocol, dependency set, or implementation changes. The bounded validation question is tracked on [issue #500](https://github.com/JeffreyEarly/wave-vortex-model/issues/500).
