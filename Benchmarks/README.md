# Benchmarks

This folder contains authoring-only performance tools and historical profiling scripts. It is not included on the WaveVortexModel runtime package path.

## Reproducible benchmark suites

`runWaveVortexBenchmark` is the canonical performance and memory entry point. It measures a state-advanced `nonlinearFlux()` call while retaining ordinary production caches. State changes use the public `t`, `Ap`, `Am`, and `A0` setters; the runner never clears the variable cache explicitly.

```matlab
addpath("Benchmarks")
results = runWaveVortexBenchmark(suites="core-v1")
```

The registered suites are:

- `smoke-v1`: small cases for every transform family; no score.
- `core-v1`: the canonical constant-stratification nonlinear-advection score.
- `scaling-standard-v1`: standard horizontal and vertical scaling across transform families.
- `scaling-large-v1`: fixed large-memory scaling cases.

The runner accepts more than one suite and a subset of case IDs. Suite definitions are versioned in `waveVortexBenchmarkSuites`; changing a case matrix or score definition requires a new suite version. Backends are selected independently from transform families through `waveVortexBenchmarkBackends`.

Every scored case is normalized against its matching committed builtin reference. Case score 100 matches the reference. Family and suite scores use geometric means, with transform families weighted equally. Same-host builtin-to-candidate speedups are reported separately.

Ordinary artifacts are written beneath the ignored `results/runs` directory. Immutable reference artifacts live beneath `results/reference`. Memory measurements use a fresh MATLAB process and report baseline, persistent, and peak-observed resident memory; these process measurements include MATLAB runtime and allocator behavior.

The large suites can require substantial time and memory. A partial result is valid, but a family or suite receives no aggregate score unless every required case completes.

`WVTransformConstantStratificationSpeedTest`, `ProfileableSpeedTest`, and `ForcingSpectralMaskPerformanceTest` remain historical investigation scripts. Deterministic correctness checks belong in `UnitTests`; mixed scientific investigations belong in `DeveloperExperiments`.
