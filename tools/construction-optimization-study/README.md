# Free-surface construction optimization study

These drivers compare construction revisions while preserving the complete scientific state and assessment reports. Each comparison uses frozen baseline and candidate worktrees, the same dependency snapshots, fresh MATLAB processes, a warmup, repeated unprofiled trials, and a separate profiler pass.

`runConstructionOptimizationStudy` requires WVM, InternalModes, and external output roots. `compareConstructionOptimizationStudy` compares the saved outputs after normalizing worktree paths only for profile matching. `runWaveModePreparationStudy` and `runGramPrefixStudy` isolate the preparation and Gram-prefix operations.

```matlab
runConstructionOptimizationStudy(baselineRoot,internalModesRoot,"/external/wvm-studies/construction/baseline")
runConstructionOptimizationStudy(candidateRoot,internalModesRoot,"/external/wvm-studies/construction/candidate")
compareConstructionOptimizationStudy("/external/wvm-studies/construction/baseline","/external/wvm-studies/construction/candidate")
```

Run baseline and candidate serially without another MATLAB benchmark. Treat inclusive profiler rows as overlapping diagnostic evidence and use matched unprofiled medians for elapsed-time comparisons. Results, profiles, patches, and generated reports remain external. Historical decisions are available on InternalModes issues [#31](https://github.com/JeffreyEarly/internal-modes/issues/31), [#32](https://github.com/JeffreyEarly/internal-modes/issues/32), [#33](https://github.com/JeffreyEarly/internal-modes/issues/33), [#34](https://github.com/JeffreyEarly/internal-modes/issues/34), and [#36](https://github.com/JeffreyEarly/internal-modes/issues/36), together with the associated WVM pull requests.
