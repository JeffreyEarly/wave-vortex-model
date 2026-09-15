# Nonlinear RHS reuse study

`runRHSReuseComparison` compares the production nonlinear right-hand side with a frozen authoring reference while preserving reconstructed sources, projected coefficient tendencies, and pressure calculations. It uses the `RHSReuseReference` fixture in this directory.

Pass an explicit external output directory:

```matlab
addpath("tools/rhs-reuse-study")
results = runRHSReuseComparison("/external/wvm-studies/rhs-reuse")
```

The driver writes timing, accuracy, and optional profiler artifacts to that directory. Generated outputs are excluded from the repository. The related implementation discussion is on [issue #481](https://github.com/JeffreyEarly/wave-vortex-model/issues/481).
