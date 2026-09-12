---
layout: default
title: Benchmarks
parent: Compiled execution
nav_order: 3
has_toc: true
description: Runtime and memory scaling for WaveVortexModel
permalink: /benchmarks
---

# Benchmarks

The usual starting point is MATLAB at low resolution: it keeps the model easy to inspect while you build physical understanding and establish that the configuration behaves as intended. Once the science is clear, higher resolutions, different integrators, or compiled execution may be useful. This page summarizes measured runtime and memory tradeoffs to help decide when that added complexity is worthwhile.

## MATLAB vs C++

**Setup.** The benchmark evolves a nonhydrostatic, constant-stratification flow in a 150 km × 150 km × 1.3 km domain, initialized with GM(1) waves and a first-baroclinic red geostrophic spectrum, for 0.12 inertial periods. The numerics use a `256 × 256 × 129` grid and the adaptive `ode78 / RK8(7)` integrator. The model and integrator are fixed while the execution path and output workload vary.

**Conclusion.** Read the winner labels and ratios within the selected historical record. They describe the recorded source and environment rather than estimate the performance of later native revisions.

<!-- BENCHMARKS:INTERFACE_SUMMARY:START -->
Published matched interface results will appear here.
<!-- BENCHMARKS:INTERFACE_SUMMARY:END -->

## MATLAB speed scaling

**Setup.** These historical tests evaluate one state-advanced `nonlinearFlux` call using MATLAB's builtin transforms with anti-aliasing enabled. The representative plots use a constant-stratification, nonhydrostatic model in a 15 km × 15 km × 1.3 km domain. Horizontal sweeps vary `Nx = Ny`, holding `Nz = 65` in the standard suite and `Nz = 129` in the large suite; vertical sweeps vary `Nz`, holding `Nx = Ny` at 128 or 512. The model, transform, and operation are otherwise fixed. Each expanded table identifies the recorded WaveVortexModel version, MATLAB release, platform, and suite.

**Conclusion.** Within these MATLAB builtin records, horizontal refinement is the stronger runtime constraint: at large resolutions, doubling both horizontal dimensions increases runtime by roughly fourfold, while doubling the vertical resolution increases it by about two to two-and-a-half times. The scaling plots do not measure the current compiled C++ runtime.

<!-- BENCHMARKS:SPEED_SCALING:START -->
Published runtime scaling results will appear here.
<!-- BENCHMARKS:SPEED_SCALING:END -->

## MATLAB memory scaling

**Setup.** These historical tests repeat the same model, operation, and horizontal and vertical resolution sweeps used above; only the reported metric changes to peak MATLAB process memory, including the language runtime and numerical libraries. The separate [MATLAB builtin transform storage benchmark](/developers-guide/transform-storage-benchmark.html) inventories known application-owned arrays without treating them as total process memory.

**Conclusion.** Within these MATLAB builtin records, horizontal refinement is also the stronger memory constraint: at large resolutions, doubling both horizontal dimensions increases peak memory by roughly three- to fourfold, while doubling the vertical resolution approximately doubles it. Exact storage ledgers and process RSS answer different questions and must not be combined into a synthetic memory estimate.

<!-- BENCHMARKS:MEMORY_SCALING:START -->
Published memory scaling results will appear here.
<!-- BENCHMARKS:MEMORY_SCALING:END -->

## Integrator comparison

**Setup.** This historical comparison reuses the MATLAB-vs-C++ model, initial condition, 0.12 inertial-period duration, and `256 × 256 × 129` grid. Each table fixes the output workload, varies the integrator down the rows, and varies the execution path across the columns; the forcing and anti-aliasing remain fixed. Runtime and memory winners are identified independently within each execution-path column.

**Conclusion.** The highlighted cells identify the fastest runtime and lowest peak memory within each execution-path column of each workload table. These record-specific rankings compare integrators under one matched contract and should not be extrapolated to later source revisions or different workloads.

<!-- BENCHMARKS:INTEGRATOR_COMPARISON:START -->
Published integrator results will appear here.
<!-- BENCHMARKS:INTEGRATOR_COMPARISON:END -->

## Recent native optimization evidence

The following native runtime optimization evidence was measured on September 11–12, 2026. The [shared field and gradient pipeline](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/Benchmarks/SHARED-GRADIENT-PIPELINE.md), [matrix scheduling and immediate advection pipeline](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/Benchmarks/MATRIX-ADVECTION-PIPELINE.md), [tiled advection pipeline](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/Benchmarks/TILED-ADVECTION-PIPELINE.md), and [RK78 combination study](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/Benchmarks/rk78-combinations/RESULTS.md) compare each candidate with its own frozen standalone native baseline. These reports do not revise the selected matched interface record automatically. They use different fixtures and measurement boundaries, so their relative changes cannot be added or applied to the absolute MATLAB versus C++ times above.

The latest native increment measured here is the [prepared projection and assembly pipeline](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/Benchmarks/prepared-pipeline/RESULTS.md), recorded September 12, 2026. These standalone native comparisons use frozen source `ed6049a2` against the accepted `72fc2bdd` implementation from PR #494, with the reuse policy on an Apple M4 Max (16 logical cores, 128 GiB RAM), macOS 26.6.1 and Apple Clang 21. FFTW 3.3.11 NEON/pthreads and Accelerate use one internal FFTW thread, twelve horizontal workers, eight pointwise workers, and one Hydrostatic/eight Boussinesq vertical-group workers. They measure integration of the same saved state and controls, using eight alternating pairs after two warmup pairs per fixture; loading, preparation and final writing are excluded from the integration column.

<div class="benchmark-table-scroll" role="region" aria-label="September 12 native integration comparison" tabindex="0">
<table class="benchmark-results-table">
<thead><tr><th scope="col">Native workload</th><th scope="col">Baseline integration</th><th scope="col">Candidate integration</th><th scope="col">Observed reduction</th></tr></thead>
<tbody>
<tr><td>EddyTide <code>256 × 256 × 28</code>, RK78</td><td>16.862 s</td><td>15.719 s</td><td>6.8%</td></tr>
<tr><td>Composite Hydrostatic <code>256 × 256 × 129</code>, RK4</td><td>5.374 s</td><td>5.294 s</td><td>1.5%</td></tr>
<tr><td>Boussinesq <code>256 × 256 × 129</code>, RK78</td><td>4.419 s</td><td>3.938 s</td><td>10.9% (order-sensitive)</td></tr>
</tbody>
</table>
</div>

EddyTide advances 96 capped 300-second RK78 steps; larger Hydrostatic advances eight 0.5-second RK4 steps; Boussinesq advances four capped 0.5-second RK78 steps. All 30 warmup/measured comparisons preserve scientific agreement and integration decisions, with no owned-memory growth. These workloads establish incremental native behavior and do not update the absolute MATLAB versus C++ comparison above.

Every process passed an idle preflight, but intermittent desktop activity occurred. Boussinesq's ratio is 0.992 in baseline-first pairs and 0.800 in candidate-first pairs; the aggregate is therefore not a stable production-speedup estimate. Its complete-process improvement is only 0.9% because loading and preparation dominate this short continuation. The [full report and linked machine-readable results](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/Benchmarks/prepared-pipeline/RESULTS.md#final-paired-acceptance-september-12) retain all timings, paired intervals, host observations, storage and producer checks.

<details markdown="1">
<summary>Benchmark conditions, environments, and downloads</summary>

The generated interface summary identifies the selected compatible record and its source, platform, provider, and sample count. Comparisons require matching suite contracts, operations, domains, resolutions, numerical options, random seeds, warmup counts, and sample counts. Results from different environments reflect both hardware and toolchain differences.

The normalized public downloads below remain available. The original M5 raw archives for August 27–28 were unavailable in the local artifact repository during the September 12 audit; their recorded hashes and expected paths are preserved in the [benchmark audit](https://github.com/JeffreyEarly/wave-vortex-model/blob/main/.github/planning/benchmark-website-audit-20260912.md).

Benchmark tools are authoring utilities and are not installed on the runtime package path. The [benchmark authoring guide](https://github.com/JeffreyEarly/wave-vortex-model/tree/main/Benchmarks) documents suite definitions, measurement boundaries, correctness gates, provenance, and publication. Missing coverage is reported as unavailable, never as zero or extrapolated performance.

**Test environments**

<!-- BENCHMARKS:COMPUTERS:START -->
Published computer details will appear here.
<!-- BENCHMARKS:COMPUTERS:END -->

<!-- BENCHMARKS:HISTORY:START -->
<!-- BENCHMARKS:HISTORY:END -->

**Downloadable results**

The compact published JSON records contain the measurements and correctness evidence used by this page. Raw worker outputs and RSS samples remain outside the source tree.

<!-- BENCHMARKS:DOWNLOADS:START -->
Published result downloads will appear here.
<!-- BENCHMARKS:DOWNLOADS:END -->

</details>
