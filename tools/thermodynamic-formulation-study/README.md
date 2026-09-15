# Thermodynamic formulation study

This authoring study compares exact displacement with total-density coordinates while holding modal dynamics, pressure treatment, advection, and projection fixed. `comparison-protocol.json` declares the profiles, states, refinements, and accuracy targets.

`runThermodynamicEquivalenceStudy`, `runProjectedThermodynamicStudy`, and `runThermodynamicTangentStudy` provide analytic and coefficient controls. `runCompleteThermodynamicStudy`, `runSupplementalThermodynamicResolution`, and `runLongThermodynamicControls` perform trajectory refinements. Timing and budget drivers remain separate. Plotting and Python summarization consume the generated tables.

All implicit outputs are under `fullfile(tempdir,"wave-vortex-model-studies","thermodynamic-formulation-study")`. Use a fresh external copy for any durable result and do not commit generated tables, figures, logs, or reports. The formulation comparison is tracked on [issue #487](https://github.com/JeffreyEarly/wave-vortex-model/issues/487).
