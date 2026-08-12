---
layout: default
title: Benchmarks
nav_order: 8
description: Runtime and memory scaling for WaveVortexModel
permalink: /benchmarks
---

# Benchmarks

These benchmarks measure the cost of one state-advanced nonlinear-flux evaluation across WaveVortexModel transform families and grid sizes. They are intended to help you estimate runtime and memory requirements, compare computers, and reproduce the measurements on your own hardware.

## Performance at a glance

The representative comparison uses the nonhydrostatic constant-stratification case with resolution `[256 256 65]`. Absolute measurements are shown because benchmark scores can obscure the practical time and memory required by a model.

<!-- BENCHMARKS:AT_GLANCE:START -->
Published benchmark results will appear here.
<!-- BENCHMARKS:AT_GLANCE:END -->

## Compiled constant-stratification preview

The source-only compiled preview is an explicit opt-in for ordinary constant-stratification nonlinear flux. MATLAB remains the default. Availability, speed, numerical error, exact retained application storage, and isolated operation memory are shown together because the preview intentionally prioritizes a substantial speed gain while its memory use remains a target for future refinement.

<!-- BENCHMARKS:COMPILED_PREVIEW:START -->
Published compiled-preview results will appear here.
<!-- BENCHMARKS:COMPILED_PREVIEW:END -->

## Scaling with model size

The plots separate horizontal and vertical scaling for the representative nonhydrostatic constant-stratification transform. Limiting each chart to one transform keeps the machine and suite comparisons legible; the expandable tables retain results for every transform family. Each point is the median of the retained timing samples. Memory plots report the peak resident memory of the MATLAB or C++ process, including the language runtime and numerical libraries.

<!-- BENCHMARKS:SCALING:START -->
Published scaling results will appear here.
<!-- BENCHMARKS:SCALING:END -->

## Compare computers

Processor, memory, operating-system, toolchain, and thread information accompany every published dataset. Results from different environments remain machine-dependent measurements rather than universal performance guarantees.

<!-- BENCHMARKS:COMPUTERS:START -->
Published computer details will appear here.
<!-- BENCHMARKS:COMPUTERS:END -->

<!-- BENCHMARKS:HISTORY:START -->
<!-- BENCHMARKS:HISTORY:END -->

## Run the benchmark yourself

Benchmark tools are authoring utilities and are not installed on the runtime package path. From a clean WaveVortexModel authoring checkout, run:

```matlab
addpath("Benchmarks")
results = runWaveVortexBenchmark(suites="scaling-standard-v1")
```

The larger `scaling-large-v1` suite can require substantially more memory. The [benchmark authoring guide](https://github.com/JeffreyEarly/wave-vortex-model/tree/main/Benchmarks) explains suite selection, reference generation, raw artifacts, and normalization for publication.

## Methodology and interpretation

The measured operation advances the coefficient state and evaluates `nonlinearFlux` with ordinary production caches retained. It is not a complete model time step. Published cases must pass their numerical correctness tolerance before their timing can be shown.

Runtime is the median of the recorded post-warmup samples. **Peak process memory** is the largest observed resident-memory value for the process. **Memory above baseline** subtracts the fresh-process value measured before constructing the model; it is the better estimate of the additional memory associated with WaveVortexModel, while still including allocator and library behavior.

Only datasets approved in the benchmark catalog are published. Comparisons require the same suite contract, operation, case, domain, resolution, numerical options, random seed, warmup count, and sample count. MATLAB release and update are recorded as part of the toolchain: when two machines use different MATLAB releases, their measurements reflect both hardware and MATLAB implementation differences rather than isolating hardware alone. Missing implementation or suite coverage is reported as unavailable and never as zero runtime or memory.

## Downloadable results

The normalized files use the language-neutral `published-benchmark-v1` contract. The corresponding raw artifacts retain implementation-specific diagnostics and provenance.

<!-- BENCHMARKS:DOWNLOADS:START -->
Published result downloads will appear here.
<!-- BENCHMARKS:DOWNLOADS:END -->
