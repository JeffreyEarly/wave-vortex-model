---
layout: default
title: Transform storage benchmark
parent: Developers guide
nav_order: 9
---

# Transform storage benchmark

The `transform-storage-v1` diagnostic answers two different memory questions. First, which large arrays does WaveVortexModel explicitly own? Second, does the MATLAB worker actually retain less resident memory when the FFTW half-complex backend runs under ordinary production caching?

## Exact storage ledger

`WVTransformConstantStratification.transformStorageLedger()` reports explicit transform storage after a production warmup. Entries identify their owner, purpose, shape, class, persistence, allocation state, and byte status. Exact entries cover Fourier/WV mappings, the builtin full-complex inverse buffer, vertical fallback matrices, and the known transient transform arrays. An FFTW plan receives an opaque entry because its internal allocation is not exposed by a supported API.

The FFTW ledger explicitly records the absence of a persistent Fourier spectrum. It also records the potential size and unallocated state of the lazy preserving-c2r scratch. Production inverse calls use uniquely owned destructive c2r input, so a destructive-only WaveVortex transform must leave that scratch unallocated.

The ledger intentionally excludes canonical model coefficients, forcing state, MATLAB's internal FFT work buffers, allocator reserves, and opaque FFTW plan bytes. Those exclusions prevent an exact application-owned byte count from being presented as a whole-process estimate.

## Repeated process measurement

Each backend/case pair runs three times in a fresh MATLAB process. Normal production caches remain enabled. An external sampler records the worker's RSS during baseline, construction, warmup, a persistent plateau, and a state-advanced `nonlinearFlux` call. Holding the returned flux briefly allows the sampler to observe its resident-memory peak without changing the computation being measured.

The final issue #47 readiness benchmark consumes this artifact by fixed SHA-256 rather than repeating or reinterpreting the measurement. It verifies that the measured transform implementation has not changed, then combines the storage gates with same-host `core-v1` timing and correctness. Both exact structural savings and repeated process-RSS improvements are required; one does not substitute for the other.

The artifact preserves every raw RSS sample, sampler identity and interval, per-run increments, medians, minima, and maxima. Unsupported sampling remains a structured result rather than being replaced with an allocation estimate. The benchmark rotates builtin and FFTW process order to reduce systematic ordering bias.

## Gates

The structural comparison requires positive exact persistent-storage savings, no persistent full Hermitian spectrum in the FFTW backend, no allocated preserving scratch, and balanced plan and MEX lifetimes. Repeated RSS must improve by at least 16.125 MiB for `[256 256 65]` and 128.496 MiB for `[512 512 129]` in both the persistent plateau and nonlinear-flux peak comparisons.

Run the diagnostic with:

```matlab
addpath("Benchmarks")
results = runWaveVortexBenchmark(suites="transform-storage-v1")
```

The suite is unscored and does not declare the optional backend ready. The final backend decision combines this memory evidence with correctness and complete nonlinear-advection timing.
