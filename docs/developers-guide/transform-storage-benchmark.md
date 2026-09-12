---
layout: default
title: MATLAB builtin transform storage benchmark
parent: Developers guide
nav_order: 9
---

# MATLAB builtin transform storage benchmark

This developer benchmark covers MATLAB's builtin transform implementation. It is separate from the matched compiled interface measurements on the [Benchmarks](/benchmarks) page. The diagnostic separates exact application-owned arrays from whole-process resident memory; it does not infer MATLAB copy-on-write behavior or internal FFT work buffers from source code.

## Exact storage ledger

`WVTransformConstantStratification.transformStorageLedger()` is a hidden developer contract used by the benchmark. It records compact Fourier/WV mappings, the builtin full-complex inverse buffer, dense DCT/DST matrices, and known transient transform results. Each record includes its owner, purpose, shape, MATLAB class, allocation state, persistence, and byte status. The aggregate distinguishes the sum of all recorded transient arrays from maximum known live storage, which combines persistent arrays with the larger mutually exclusive forward or inverse result.

MATLAB's FFT workspace is recorded as opaque. Canonical wave-vortex coefficients, forcing state, and unrelated model caches are outside the ledger, so `knownPersistentBytes` must not be interpreted as total model memory.

## Repeated process RSS

`runWaveVortexBuiltinStorageBenchmark` launches three fresh MATLAB workers per case by default. An external sampler records RSS during startup, construction, warmup, the persistent plateau, and a state-advanced `nonlinearFlux` call. Production caches remain enabled.

```matlab
addpath("Benchmarks")
results = runWaveVortexBuiltinStorageBenchmark
```

The JSON artifact retains raw samples, medians, ranges, sampler identity, exact ledgers, source identity, and structured failures. The Markdown summary reports known storage and RSS without combining them into a synthetic memory estimate. Storage artifacts are engineering diagnostics rather than cataloged public performance datasets.
