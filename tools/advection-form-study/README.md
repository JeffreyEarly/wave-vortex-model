# Advection-form study

This authoring study compares divergence, advective, split, and quadrature-compatible discretizations of the nonlinear advection terms. It keeps the same modal reconstruction and projection so the comparison isolates the sampled transport formula.

The declared case matrix and accuracy targets are in `comparison-protocol.json`. `runAdvectionManufacturedStudy` exercises analytic scalar transport, `runAdvectionBudgetControls` checks discrete budget identities, `runAdvectionSourceStudy` refines sampled sources and projected families, and `runAdvectionTrajectories` performs the physical trajectory comparison. `runAdvectionTimings` and `countAdvectionDerivatives` collect cost evidence. `plotAdvectionStudy` and `summarizeAdvectionStudy.py` consume the generated tables.

Add this directory and `tools/nonlinear-study` to the MATLAB path before running the drivers. By default, their outputs are written beneath `fullfile(tempdir,"wave-vortex-model-studies","advection-form-study")`. Run timing studies without another simulation process and copy any result that must outlive the temporary directory to external storage.

The mathematical motivation and implementation discussion are recorded on [issue #483](https://github.com/JeffreyEarly/wave-vortex-model/issues/483). Generated CSV, JSON, figures, logs, and measurement reports are deliberately excluded from the repository.
