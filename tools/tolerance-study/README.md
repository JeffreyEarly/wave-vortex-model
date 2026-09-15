# Adaptive-tolerance study

This authoring study compares adaptive integration tolerances against independently tightened references. It keeps physical field error, invariant drift, significant-wave phase error, reference uncertainty, and accepted/rejected-step behavior separate.

Every entry point that writes evidence requires an explicit external output folder. `runTolerancePolicyStudy` evaluates bounded manufactured cases, `runEvolvingToleranceStudy` and `runWaveWeakeningStudy` cover evolving wave amplitudes, and `runProductionToleranceQualification` applies the declared production controls. The collection and summary helpers read the same caller-owned folders.

```matlab
outputDirectory = "/external/wvm-studies/tolerance";
results = runTolerancePolicyStudy(outputDirectory)
summary = summarizeToleranceStudy(outputDirectory)
```

Use a new folder when changing the physical setup or solver policy. Generated states, traces, tables, figures, and provenance remain outside the repository. The policy discussion is recorded on the associated WVM adaptive-integration issues and pull requests.
