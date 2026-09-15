# Vertical-derivative study

This authoring study compares dense WKB differentiation with an FFT-backed candidate for isolated kernels and complete nonlinear callbacks. It covers real and complex arrays, derivative orders, reconstructed mixed states, and fresh-process memory measurements.

Pass an explicit external output directory:

```matlab
addpath("tools/vertical-derivative-study")
results = runDerivativeComparison("/external/wvm-studies/vertical-derivative")
```

`denseWKBDerivative` and `fftWKBDerivative` are the isolated kernels. `measureDerivativeMemory` is the fresh-process memory worker. Generated profiles, MAT files, tables, and memory results are excluded from the repository. The investigation is tracked on [issue #452](https://github.com/JeffreyEarly/wave-vortex-model/issues/452).
