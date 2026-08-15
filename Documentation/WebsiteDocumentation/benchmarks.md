---
layout: default
title: Benchmarks
nav_order: 8
description: Runtime and memory scaling for WaveVortexModel
permalink: /benchmarks
---

# Benchmarks

These benchmarks help estimate the integration time and total peak memory required by a model. The primary comparison uses the same constant-stratification model through MATLAB's builtin implementation, MATLAB with the compiled C++ core, and the standalone C++ runtime. Additional scaling results cover MATLAB's builtin transforms across other model families and computers.

## Constant-stratification execution comparison

The comparison uses identical initial state, forcing, integration settings, observer graph, output schedule, hardware, thread policy, and measured work for all three interfaces. MATLAB builtin remains the default. The compiled interfaces are source-built options for the supported constant-stratification configuration; see the [compiled constant-stratification preview](https://wavevortexmodel.org/users-guide/compiled-preview.html) for availability and build instructions.

<!-- BENCHMARKS:INTERFACE_COMPARISON:START -->
Published matched interface results will appear here.
<!-- BENCHMARKS:INTERFACE_COMPARISON:END -->

## MATLAB builtin scaling across transform families

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

The matched interface comparison uses `[256 256 129]` and `[512 512 257]` and requires the validated native FFTW provider. The larger run requires substantial memory and temporary NetCDF output:

```matlab
results = runThreeInterfaceBenchmarkComparison
```

## Methodology and interpretation

The scaling suites advance the coefficient state and evaluate `nonlinearFlux` with ordinary production caches retained; those measurements are not complete model steps. The matched interface suite separately measures one nonlinear-flux call, a fixed-RK4 continuation, and an adaptive RK3(2) continuation with observer and file output. Published cases must pass their numerical correctness tolerance, execute the requested integrator and provider, and reproduce the complete saved output graph before their runtime and memory can be shown.

Scaling runtime is the median of the recorded post-warmup samples. Matched-interface runtime is the median numerical-operation or integration time from three independent fresh processes; process launch and model construction are excluded. **Peak process memory** is the largest observed process-tree resident-memory value over the complete run, including MATLAB where applicable.

Only datasets approved in the benchmark catalog are published. Comparisons require the same suite contract, operation, case, domain, resolution, numerical options, random seed, warmup count, and sample count. MATLAB release and update are recorded as part of the toolchain: when two machines use different MATLAB releases, their measurements reflect both hardware and MATLAB implementation differences rather than isolating hardware alone. Missing implementation or suite coverage is reported as unavailable and never as zero runtime or memory.

## Downloadable results

Scaling and compiled-preview datasets use the language-neutral `published-benchmark-v1` contract. Matched workflow datasets use `published-three-interface-v1`. Their compact records include the filename, SHA-256, and size of a compressed author archive retained outside the source tree; verbose samples are not distributed with the website or package.

<!-- BENCHMARKS:DOWNLOADS:START -->
Published result downloads will appear here.
<!-- BENCHMARKS:DOWNLOADS:END -->
