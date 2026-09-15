# Buoyancy evaluation study

This authoring study compares the stable interval recurrence used for nonlinear buoyancy and available potential energy with an independent quadrature calculation. It covers signed intervals, surface crossings, endpoint adjustments, and complete nonlinear right-hand-side evaluation.

Generate the independent oracle with `generateBuoyancyOracle.py`, then pass an external directory to the MATLAB driver:

```matlab
addpath("tools/buoyancy-study")
results = runBuoyancyComparison("/external/wvm-studies/buoyancy")
```

`quadratureNonlinearSources` remains the authoring reference. The output directory contains the generated comparison tables and should remain outside the repository. The study originated with [issue #482](https://github.com/JeffreyEarly/wave-vortex-model/issues/482).
