# Benchmarks

This folder contains authoring-only performance tools. It is excluded from the WaveVortexModel runtime package.

## Artifact policy

Benchmark runs write to an external directory. When a runner's `outputDirectory` is omitted, it uses a run-specific folder beneath `fullfile(tempdir,"wave-vortex-model-benchmarks")`. Copy results elsewhere before the operating system clears its temporary directory.

Recorded benchmark results, logs, archives, and generated figures do not belong in this repository. Keep reviewed artifacts in an external archive and link the relevant GitHub issue or pull request when a durable record is needed. The schemas in `schemas/` remain the versioned contracts for exchanging results.

Scored suites require an external catalog:

```matlab
addpath("Benchmarks")
results = runWaveVortexBenchmark(suites="core-v1",catalogPath="/external/benchmarks/catalog.json")
```

Paths in the catalog's `rawArtifact` fields are resolved relative to the catalog file. Reference generation remains explicit: set `shouldCreateReference=true` and supply an external `referenceDirectory`. The runner never edits a catalog.

## Reproducible suites

`runWaveVortexBenchmark` measures a state-advanced `nonlinearFlux()` call while retaining ordinary production caches. Suite definitions live in `waveVortexBenchmarkSuites`; changing a case matrix or score definition requires a new suite version. Backends are selected independently through `waveVortexBenchmarkBackends`.

The registered suites are:

- `smoke-v1`: small unscored cases for every transform family.
- `core-v1`: the canonical constant-stratification nonlinear-advection score.
- `scaling-standard-v1`: standard horizontal and vertical scaling.
- `scaling-large-v1`: fixed large-memory scaling cases.
- `transform-layout-v1`: an unscored comparison of full-complex WV/DFT mapping expressions.

Memory workers use fresh MATLAB processes and report baseline, persistent, and observed peak resident memory. These measurements include MATLAB runtime and allocator behavior.

## Specialized runners

`runCompiledPreviewBenchmark` compares the public MATLAB and compiled nonlinear-flux entry points. Each backend, case, and repeat runs in a fresh MATLAB process. Its artifact records backend identity, correctness, runtime, storage, and process memory.

`runThreeInterfaceBenchmarkComparison` compares MATLAB builtin, MATLAB compiled, and standalone C++ execution for fixed RK4 and MATLAB-compatible adaptive methods. It generates matched temporary fixtures for coefficient-only and output-graph workloads. The raw benchmark and any compressed archive remain external.

`runWaveVortexObserverCostBenchmark` separates endpoint and dense-output delivery costs for coefficient-only and composite observer graphs.

`runFreeSurfaceQGCoefficientStorageBenchmark` compares separate and packed free-surface QG coefficient storage while preserving the same public setters and integrator behavior.

`runWaveVortexBuiltinStorageBenchmark` reports application-owned transform arrays and process memory. `runWaveVortexRetirementBenchmark` compares an archived source tree with the current tree in isolated processes.

`runWVFourierStorageLayoutIntegrationBenchmark` compares the production Fourier-storage layout with an external reference artifact. Supply it explicitly:

```matlab
results = runWVFourierStorageLayoutIntegrationBenchmark(referencePath="/external/benchmarks/transform-layout/benchmark.json")
```

`WVTransformConstantStratificationSpeedTest`, `ProfileableSpeedTest`, and `ForcingSpectralMaskPerformanceTest` are retained investigation scripts. Deterministic correctness checks belong in `UnitTests`.

## Published result conversion

`publishedWaveVortexBenchmarkFromMatlabArtifact`, `publishedWaveVortexBenchmarksFromCompiledPreviewArtifact`, and the three-interface composition helpers convert external raw artifacts into the schemas under `schemas/`. They return MATLAB structures and do not write to the repository. Issue [#139](https://github.com/JeffreyEarly/wave-vortex-model/issues/139) defines the website comparison model, and issue [#140](https://github.com/JeffreyEarly/wave-vortex-model/issues/140) records the publication workflow.
