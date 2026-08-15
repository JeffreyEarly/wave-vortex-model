---
layout: default
title: Benchmarks
nav_order: 8
description: Runtime and memory scaling for WaveVortexModel
permalink: /benchmarks
---

# Benchmarks

These benchmarks cover both state-advanced nonlinear-flux scaling and matched complete-workflow execution. They are intended to help you estimate runtime and memory requirements, compare computers and execution interfaces, and reproduce the measurements on your own hardware.

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

## Complete-workflow interface comparison

The matched comparison below separates a single nonlinear-flux evaluation from fixed-step and adaptive model continuations. Each row uses the same initial model, forcing, integration settings, observer graph, output schedule, provider, thread policy, and fresh-process boundary across MATLAB builtin, MATLAB compiled, and standalone compiled execution. An external process-tree sampler measures every interface from worker launch through exit. Total peak RSS is the primary practical footprint and includes MATLAB itself when MATLAB is used; the increment above the retained model and final RSS are secondary lifecycle diagnostics.

<!-- BENCHMARKS:THREE_INTERFACES:START -->
Published matched interface results will appear here.
<!-- BENCHMARKS:THREE_INTERFACES:END -->

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

The matched workflow comparison uses the large `[256 256 129]` case and requires the validated native FFTW provider. It also creates substantial temporary NetCDF output:

```matlab
results = runThreeInterfaceBenchmark
```

## Methodology and interpretation

The scaling suites advance the coefficient state and evaluate `nonlinearFlux` with ordinary production caches retained; those measurements are not complete model steps. The matched interface suite separately measures one nonlinear-flux call, a fixed-RK4 continuation, and an adaptive RK3(2) continuation with observer and file output. Published cases must pass their numerical correctness tolerance before their timing can be shown.

Scaling runtime is the median of the recorded post-warmup samples. Matched-interface runtime is the median of three independent fresh-process continuations with no within-process warmup. **Peak process memory** is the largest observed resident-memory value for the process. Scaling-suite memory above baseline subtracts the fresh-process value measured before constructing the model; matched-interface incremental RSS subtracts the steady retained-model value measured after constructing the selected backend. Both retain allocator and library behavior.

Only datasets approved in the benchmark catalog are published. Comparisons require the same suite contract, operation, case, domain, resolution, numerical options, random seed, warmup count, and sample count. MATLAB release and update are recorded as part of the toolchain: when two machines use different MATLAB releases, their measurements reflect both hardware and MATLAB implementation differences rather than isolating hardware alone. Missing implementation or suite coverage is reported as unavailable and never as zero runtime or memory.

## Downloadable results

Scaling and compiled-preview datasets use the language-neutral `published-benchmark-v1` contract. Matched workflow datasets use `published-three-interface-v1`. The corresponding raw artifacts retain implementation-specific diagnostics and provenance.

<!-- BENCHMARKS:DOWNLOADS:START -->
Published result downloads will appear here.
<!-- BENCHMARKS:DOWNLOADS:END -->
