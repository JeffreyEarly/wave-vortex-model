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

The comparison uses identical frozen initial models, forcing, integration interval, numerical controls, observer graph, output schedule, hardware, and thread policy for all three interfaces. MATLAB builtin remains the default. Different integrators are not assumed to perform identical work: accepted and rejected steps, RHS evaluations, FSAL diagnostics, and dense-extension evaluations accompany the downloadable evidence. The compiled interfaces are source-built options for the supported constant-stratification configuration; see the [compiled MATLAB backend preview](https://wavevortexmodel.org/users-guide/compiled-preview.html) for availability and build instructions.

The v4.3 presentation is frozen to the accepted issue #312 Donut record `three-interface--m5-max--20260827T151230Z`: one `[256 256 129]` nonhydrostatic case, four integrators, two workloads, three interfaces, and three independent fresh-process repeats. It is release evidence, not a benchmark to refresh during final qualification. The primary published metrics are integration-only runtime and total peak process memory; startup remains outside the runtime boundary and is not presented as a primary metric.

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

## Accepted benchmark scope

Benchmark tools are authoring utilities and are not installed on the runtime package path. The [benchmark authoring guide](https://github.com/JeffreyEarly/wave-vortex-model/tree/main/Benchmarks) documents suite contracts and publication, but the v4.3 release uses the already accepted matched-interface record without rerunning it or generating replacement timing or RSS claims. Larger matched-interface grids and unsupported transform/backend combinations remain deferred rather than being reported as zero or extrapolated from the accepted case.

The matched interface comparison uses one medium `[256 256 129]` nonhydrostatic case in a 150 km by 150 km by 1300 m domain and requires the validated native FFTW provider. Its deterministic physical state combines GM energy level 1 with a first-baroclinic red geostrophic spectrum that rolls on below mode 4, follows a `k^(-5/3)` range through mode 16, and transitions to `k^(-3)`. The geostrophic component is rescaled to a 0.15 m/s maximum horizontal speed; GM(1) remains at its requested energy level. Default anti-aliasing stays enabled. The accepted record retains compact correctness and provenance evidence for every repeat; raw NetCDF worker outputs and RSS samples remain outside the source tree.

## Methodology and interpretation

The scaling suites advance the coefficient state and evaluate `nonlinearFlux` with ordinary production caches retained; those measurements are not complete model steps. The matched interface suite measures fixed RK4 and MATLAB-compatible RK3(2), RK5(4), and RK8(7) integration for the physical nonhydrostatic state. Fixed RK4 uses the largest power-of-two step no greater than the frozen-state CFL=0.25 estimate (128 s for the canonical state); adaptive methods start from the frozen-state CFL=0.5 estimate (approximately 295.794 s) with no user `MaxStep`. The 7168 s interval is 56 fixed steps. Each method runs both a coefficient-only endpoint workload and a composite output graph with one persisted restart record followed by four first-step records for fields, particles, a tracer, and source-linked mooring state; three of those times are interior to the fixed step. Published rows must execute the requested integrator and provider without fallback, match adaptive controls, preserve accepted endpoint trajectories when interior output is added, pass method-appropriate numerical tolerances, and reproduce the complete saved output graph.

Scaling runtime is the median of the recorded post-warmup samples. Matched-interface runtime is the median integration-only time from three independent fresh processes, beginning immediately before integration and ending after required output delivery. **Peak process memory** is the largest externally sampled total process-tree RSS while the worker reports the integration or required output-delivery phase. Process launch, MATLAB startup, model and provider construction, FFT planning, NetCDF inspection, parsing, and cleanup are outside both primary boundaries. Retained, incremental, final, and process-lifetime RSS remain diagnostics.

Only datasets approved in the benchmark catalog are published. Comparisons require the same suite contract, operation, case, domain, resolution, numerical options, random seed, warmup count, and sample count. MATLAB release and update are recorded as part of the toolchain: when two machines use different MATLAB releases, their measurements reflect both hardware and MATLAB implementation differences rather than isolating hardware alone. Missing implementation or suite coverage is reported as unavailable and never as zero runtime or memory.

## Downloadable results

Scaling and compiled-preview datasets use the language-neutral `published-benchmark-v1` contract. The current matched integrator study uses `published-three-interface-v3`; earlier matched workflow records remain available under their versioned contracts. Compact study records retain the requested/active method, work counts, exact standalone integrator storage ledgers, explicit MATLAB storage-opacity notes, fixture and raw-artifact hashes, and the location, SHA-256, and size of a compressed author archive outside the source tree. Verbose RSS samples and worker records are not distributed with the website or package.

<!-- BENCHMARKS:DOWNLOADS:START -->
Published result downloads will appear here.
<!-- BENCHMARKS:DOWNLOADS:END -->
