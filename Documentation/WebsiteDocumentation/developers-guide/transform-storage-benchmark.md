---
layout: default
title: Transform storage benchmark
parent: Developers guide
nav_order: 9
---

# Transform storage benchmark

The builtin storage diagnostic separates exact application-owned arrays from whole-process resident memory. It does not infer MATLAB copy-on-write behavior or internal FFT work buffers from source code.

## Exact storage ledger

`WVTransformConstantStratification.transformStorageLedger()` is a hidden developer contract used by the benchmark. It records compact Fourier/WV mappings, the builtin full-complex inverse buffer, dense DCT/DST matrices, and known transient transform results. The builtin inverse buffer is allocated on first builtin inverse use; before allocation its ledger entry reports zero exact retained bytes and its potential size separately. Each record includes its owner, purpose, shape, MATLAB class, allocation state, persistence, and byte status. The aggregate distinguishes the sum of all recorded transient arrays from maximum known live storage, which combines persistent arrays with the larger mutually exclusive forward or inverse result.

MATLAB's FFT workspace is recorded as opaque. Canonical wave-vortex coefficients, forcing state, and unrelated model caches are outside the ledger, so `knownPersistentBytes` must not be interpreted as total model memory.

## Repeated process RSS

`runWaveVortexBuiltinStorageBenchmark` launches three fresh MATLAB workers per case by default. An external sampler records RSS during startup, construction, warmup, the persistent plateau, and a state-advanced `nonlinearFlux` call. Production caches remain enabled.

```matlab
addpath("Benchmarks")
results = runWaveVortexBuiltinStorageBenchmark
```

The JSON artifact retains raw samples, medians, ranges, sampler identity, exact ledgers, source identity, and structured failures. The Markdown summary reports known storage and RSS without combining them into a synthetic memory estimate.
