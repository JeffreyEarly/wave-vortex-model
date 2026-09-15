# Selective reconstruction study

This authoring study compares selective free-surface field reconstruction with the frozen grouped operation. It separates cold misses, warm reads, successive-clock requests, cached-array bytes, and process-level memory sampling.

Pass an explicit external output directory to the comparison:

```matlab
addpath("tools/selective-reconstruction-study")
results = runSelectiveReconstructionComparison("/external/wvm-studies/selective-reconstruction")
```

`measureReconstructionMemory` is the fresh-process worker used by the comparison. Generated states, tables, and memory measurements remain outside the repository. The implementation investigation is tracked on [issue #453](https://github.com/JeffreyEarly/wave-vortex-model/issues/453).
