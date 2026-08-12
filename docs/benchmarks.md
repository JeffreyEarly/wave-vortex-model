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
| Implementation and platform | Median runtime | Peak process memory | Memory above baseline | Threads |
| --- | --- | --- | --- | --- |
| Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) | 0.1167 s | 1.86 GiB | 1.25 GiB | 18 |
| Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) | 0.1082 s | 1.82 GiB | 1.24 GiB | 16 |
| Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) | 0.1926 s | 1.85 GiB | 1.25 GiB | 10 |
<!-- BENCHMARKS:AT_GLANCE:END -->

## Scaling with model size

The plots separate horizontal and vertical scaling. Each point is the median of the retained timing samples. Memory plots report the peak resident memory of the MATLAB or C++ process, including the language runtime and numerical libraries.

<!-- BENCHMARKS:SCALING:START -->
### Runtime versus horizontal resolution

![Runtime versus horizontal resolution](/assets/benchmarks/runtime-horizontal.svg)

<details markdown="1">
<summary>View accessible data table</summary>

| Suite | Transform | Dataset | Resolution | Value | Status | Reason |
| --- | --- | --- | --- | --- | --- | --- |
| scaling-large-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 2048 | 0.03453 s | complete | — |
| scaling-large-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 2048 | 0.03972 s | complete | — |
| scaling-large-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 2048 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 4096 | 0.124 s | complete | — |
| scaling-large-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 4096 | 0.1439 s | complete | — |
| scaling-large-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 4096 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin. |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 1024 | 2.854 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 0.1856 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 0.1763 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 0.816 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 0.6859 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin. |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 1024 | 3.435 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 0.2345 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 0.201 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 0.9271 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 0.7217 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 0.05811 s | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 0.0614 s | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 0.248 s | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 0.2291 s | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 0.4014 s | complete | — |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 0.4398 s | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 1.54 s | complete | — |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 1.597 s | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 0.1738 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 0.1775 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 0.7167 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 0.66 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 1024 | 0.009262 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 1024 | 0.01047 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 1024 | 0.01742 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.003954 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.006815 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.006729 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.003074 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 0.003979 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.005184 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 512 | 0.004114 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 512 | 0.004362 s | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 512 | 0.006939 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.02826 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.02966 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.05619 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.09103 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 0.0869 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.1598 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.01337 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.01423 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.02684 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.03409 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.03576 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.0696 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.1167 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 0.1082 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.1926 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.02724 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.02937 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.05307 s | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.009861 s | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.01117 s | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.02029 s | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.02719 s | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 0.02942 s | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.05191 s | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.005456 s | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.01227 s | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.01083 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.05228 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.05764 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.1045 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.1817 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 0.1912 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.3497 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.02505 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.03291 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.04632 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.02623 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.02721 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.05178 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.08155 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 0.08305 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.1511 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.01629 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.02567 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.02823 s | complete | — |

</details>

### Runtime versus vertical resolution

![Runtime versus vertical resolution](/assets/benchmarks/runtime-vertical.svg)

<details markdown="1">
<summary>View accessible data table</summary>

| Suite | Transform | Dataset | Resolution | Value | Status | Reason |
| --- | --- | --- | --- | --- | --- | --- |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 0.816 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 0.6859 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 1.801 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 1.43 s | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 0.9271 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 0.7217 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 2.179 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 1.728 s | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 0.248 s | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 0.2291 s | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 0.5596 s | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 0.4844 s | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 1.54 s | complete | — |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 1.597 s | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin. |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 3.508 s | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 0.7167 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 0.66 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 1.642 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 1.356 s | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.0498 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 0.04905 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.08932 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.1009 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 0.08696 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.1628 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.01933 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.01874 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.0365 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.02826 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 0.02966 s | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.05619 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.06709 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 0.06571 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.1153 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.1235 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 0.1062 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.1914 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.02295 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.02228 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.04987 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.03409 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 0.03576 s | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.0696 s | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.01775 s | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 0.01803 s | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.03102 s | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.03073 s | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 0.02928 s | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.05096 s | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.006398 s | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.006322 s | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.01132 s | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.009861 s | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 0.01117 s | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.02029 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.1068 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 0.1163 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.2006 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.2396 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 0.2426 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.4833 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.02798 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.03268 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.05663 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.05228 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 0.05764 s | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.1045 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.04556 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 0.04562 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 0.08205 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.0917 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 0.08277 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 0.1551 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.01616 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.01546 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.03153 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.02623 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 0.02721 s | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.05178 s | complete | — |

</details>

### Peak process memory versus horizontal resolution

![Peak process memory versus horizontal resolution](/assets/benchmarks/memory-horizontal.svg)

<details markdown="1">
<summary>View accessible data table</summary>

| Suite | Transform | Dataset | Resolution | Value | Status | Reason |
| --- | --- | --- | --- | --- | --- | --- |
| scaling-large-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 2048 | 1.57 GiB | complete | — |
| scaling-large-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 2048 | 1.55 GiB | complete | — |
| scaling-large-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 2048 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 4096 | 4.11 GiB | complete | — |
| scaling-large-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 4096 | 3.96 GiB | complete | — |
| scaling-large-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 4096 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin. |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 1024 | 32.8 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 2.8 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 2.75 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 8.79 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 8.74 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin. |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 1024 | 34.6 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 1024 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 2.9 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 2.86 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 8.43 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 9.17 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 1.79 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 1.75 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 4.77 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 4.73 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 3.86 GiB | complete | — |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 3.75 GiB | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 10.6 GiB | complete | — |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 12.3 GiB | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | 2.76 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 256 | 2.71 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 256 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | 8.52 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 512 | 8.46 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 512 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 1024 | 0.952 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 1024 | 0.911 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 1024 | 0.949 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.756 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.706 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.764 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.755 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 0.708 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 0.756 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 512 | 0.8 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 512 | 0.754 GiB | complete | — |
| scaling-standard-v1 | Barotropic QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 512 | 0.801 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.04 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 1.02 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.04 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.81 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 1.75 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.77 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.853 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.802 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.85 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.06 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 1.01 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.05 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.86 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 1.82 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.85 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.856 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.809 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.854 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.913 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 0.871 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 0.906 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.29 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 1.25 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.27 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.819 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.769 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.81 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.17 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 1.12 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.16 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 2.1 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 2.04 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 2.08 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.923 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.873 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.933 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.07 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 128 | 1.03 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 128 | 1.06 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.77 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 256 | 1.75 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 256 | 1.76 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.886 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 64 | 0.83 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 64 | 0.884 GiB | complete | — |

</details>

### Peak process memory versus vertical resolution

![Peak process memory versus vertical resolution](/assets/benchmarks/memory-vertical.svg)

<details markdown="1">
<summary>View accessible data table</summary>

| Suite | Transform | Dataset | Resolution | Value | Status | Reason |
| --- | --- | --- | --- | --- | --- | --- |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 8.79 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 8.74 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 14.9 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 16.7 GiB | complete | — |
| scaling-large-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 8.43 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 9.17 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 16.9 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 17.6 GiB | complete | — |
| scaling-large-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 4.77 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 4.73 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 8.73 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 8.68 GiB | complete | — |
| scaling-large-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 10.6 GiB | complete | — |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 12.3 GiB | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | Not collected on this 48 GiB host because the observed memory requirement left insufficient safety margin. |
| scaling-large-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 30.7 GiB | complete | — |
| scaling-large-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | 8.52 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 129 | 8.46 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 129 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-large-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | 14 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-large-v1 | 257 | 16.2 GiB | complete | — |
| scaling-large-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-large-v1 | 257 | Unavailable | unavailable | No scaling-large-v1 dataset was collected for this environment. |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.31 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 1.26 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.31 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.81 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 1.76 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.77 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.927 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.88 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.92 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.04 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 1.02 GiB | complete | — |
| scaling-standard-v1 | Constant hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.04 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.33 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 1.28 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.34 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.86 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 1.82 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.87 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.929 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.895 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.923 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.06 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 1.01 GiB | complete | — |
| scaling-standard-v1 | Constant nonhydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.05 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.05 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 0.996 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.04 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.32 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 1.27 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.31 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.849 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.806 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.844 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.913 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 0.871 GiB | complete | — |
| scaling-standard-v1 | Stratified QG | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 0.906 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.63 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 1.59 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.6 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 2.87 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 2.82 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 2.89 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.987 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.952 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.995 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.17 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 1.12 GiB | complete | — |
| scaling-standard-v1 | Variable Boussinesq | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.16 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.33 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 129 | 1.27 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 129 | 1.31 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.83 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 257 | 1.78 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 257 | 1.82 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.947 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 33 | 0.907 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 33 | 0.938 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Donut (Apple M5 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.07 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Lyra (Apple M4 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 25.2.0.3150157 (R2025b) Update 4) — scaling-standard-v1 | 65 | 1.03 GiB | complete | — |
| scaling-standard-v1 | Variable hydrostatic | Matilda (Apple M1 Max) — WaveVortexModel MATLAB 4.2.1 (builtin; MATLAB 26.1.0.3312084 (R2026a) Update 4) — scaling-standard-v1 | 65 | 1.06 GiB | complete | — |

</details>
<!-- BENCHMARKS:SCALING:END -->

## Compare computers

Processor, memory, operating-system, toolchain, and thread information accompany every published dataset. Results from different environments remain machine-dependent measurements rather than universal performance guarantees.

<!-- BENCHMARKS:COMPUTERS:START -->
| Implementation | Platform | Processor | Physical memory | OS / architecture | Toolchain | Threads |
| --- | --- | --- | --- | --- | --- | --- |
| WaveVortexModel MATLAB 4.2.1 (builtin) | Donut (Apple M5 Max) | Apple M5 Max | 48 GiB | Darwin 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun  9 22:28:34 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6050 arm64 / maca64 | MATLAB 26.1.0.3312084 (R2026a) Update 4 | 18 |
| WaveVortexModel MATLAB 4.2.1 (builtin) | Lyra (Apple M4 Max) | Apple M4 Max | 128 GiB | Darwin 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun  9 22:28:34 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6041 arm64 / maca64 | MATLAB 25.2.0.3150157 (R2025b) Update 4 | 16 |
| WaveVortexModel MATLAB 4.2.1 (builtin) | Matilda (Apple M1 Max) | Apple M1 Max | 64 GiB | Darwin 25.5.0 Darwin Kernel Version 25.5.0: Tue Jun  9 22:18:58 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6000 arm64 / maca64 | MATLAB 26.1.0.3312084 (R2026a) Update 4 | 10 |
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
| Dataset | Implementation | Platform | Suite | Collected | Normalized | Raw artifact |
| --- | --- | --- | --- | --- | --- | --- |
| scaling-large-v1--matlab-builtin--lyra--20260811T213524Z | WaveVortexModel MATLAB 4.2.1 | Lyra (Apple M4 Max) | scaling-large-v1 | 2026-08-11T21:35:24Z | [Published JSON](/benchmarks/data/scaling-large-v1--matlab-builtin--lyra--20260811T213524Z.json) | [Raw JSON](/benchmarks/raw/scaling-large-v1--matlab-builtin--lyra--20260811T213524Z.json) |
| scaling-large-v1--matlab-builtin--m5-max--20260812T023122Z | WaveVortexModel MATLAB 4.2.1 | Donut (Apple M5 Max) | scaling-large-v1 | 2026-08-12T02:31:22Z | [Published JSON](/benchmarks/data/scaling-large-v1--matlab-builtin--m5-max--20260812T023122Z.json) | [Raw JSON](/benchmarks/raw/scaling-large-v1--matlab-builtin--m5-max--20260812T023122Z.json) |
| scaling-standard-v1--matlab-builtin--lyra--20260811T204835Z | WaveVortexModel MATLAB 4.2.1 | Lyra (Apple M4 Max) | scaling-standard-v1 | 2026-08-11T20:48:35Z | [Published JSON](/benchmarks/data/scaling-standard-v1--matlab-builtin--lyra--20260811T204835Z.json) | [Raw JSON](/benchmarks/raw/scaling-standard-v1--matlab-builtin--lyra--20260811T204835Z.json) |
| scaling-standard-v1--matlab-builtin--m5-max--20260812T020708Z | WaveVortexModel MATLAB 4.2.1 | Donut (Apple M5 Max) | scaling-standard-v1 | 2026-08-12T02:07:08Z | [Published JSON](/benchmarks/data/scaling-standard-v1--matlab-builtin--m5-max--20260812T020708Z.json) | [Raw JSON](/benchmarks/raw/scaling-standard-v1--matlab-builtin--m5-max--20260812T020708Z.json) |
| scaling-standard-v1--matlab-builtin--matilda--20260811T205115Z | WaveVortexModel MATLAB 4.2.1 | Matilda (Apple M1 Max) | scaling-standard-v1 | 2026-08-11T20:51:15Z | [Published JSON](/benchmarks/data/scaling-standard-v1--matlab-builtin--matilda--20260811T205115Z.json) | [Raw JSON](/benchmarks/raw/scaling-standard-v1--matlab-builtin--matilda--20260811T205115Z.json) |
<!-- BENCHMARKS:DOWNLOADS:END -->
