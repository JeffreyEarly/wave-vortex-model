# Quadratic dealiasing study

This authoring study compares declared free-surface quadratic-dealiasing policies without changing runtime defaults. `setupDealiasingStudy` prepares an isolated dependency path. `calibrateQuadraticDealiasing` evaluates the fixed case matrix, and `measureDealiasingConstruction` records matched construction cost. `measureLegacyRemoval` and `compareLegacyRemoval` support historical policy comparisons. `generateFigures.py` accepts an external results root and destination.

Every MATLAB measurement entry point requires an explicit external output directory:

```matlab
calibrateQuadraticDealiasing("/external/wvm-studies/quadratic/calibration")
measureDealiasingConstruction("/external/wvm-studies/quadratic/construction")
```

Use fresh output directories for changed code or protocols. Keep MAT files, tables, profiler output, logs, figures, and summaries outside the repository. The scientific policy is discussed in the corresponding construction issues and pull requests.
