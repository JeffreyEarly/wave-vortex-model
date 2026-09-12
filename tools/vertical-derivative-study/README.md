# FFT-backed WKB derivative assessment (#452)

**Decision: retain production dense differentiation.** This MATLAB FFT candidate does not justify replacing `diffZ` at the measured sizes. The experiment is authoring-only; public methods, stored scientific operators, resolved modes, and release boundaries are unchanged. No shared production abstraction is added merely to remove two short duplicate matrix loops.

The MATLAB assessment is complete; C++/FFTW qualification remains open in #452. Keep this candidate and its tests as a reference. Reusable FFTW DCT-I plans and batched columns may change the performance tradeoff, but need their own kernel and complete-RHS measurements. The higher-order roundoff checks apply to either backend.

## Method and evidence

Baseline: WVM `4502b2cdcce6fb7fb9ded7388f140dae2b49345e`, MATLAB R2026a, Apple M5 Max with 48 GiB RAM. Runtime qualification used InternalModes `v2.0.0-beta.4`, ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0, and the local Chebfun checkout. The default local MATLAB path selects an older InternalModes and must be corrected before reproduction.

`fftWKBDerivative` uses even FFT extensions for Chebyshev coefficients, parity-separated cumulative sums for derivative coefficients, and an FFT to return to samples. It reapplies `dx/dxi` at each physical derivative. Its cost is O(HZ log Z) per order, versus dense O(HZ²), with larger temporary arrays. Complex fields are supported without splitting real and imaginary inputs. The dense comparator includes the same input/output permutations as production.

Kernel measurements cover 8×8 and 32×32 columns, Z=33,129,513, real/complex fields, and orders 1 and 4. Both paths are warmed, measurement order alternates, and reported times are medians of three `timeit` pairs. Final timings ran without another task-owned MATLAB worker. Every measured kernel favored dense multiplication; see [kernel results](results/kernels.csv). This establishes neither a universal crossover nor a limit on optimized DCT/native implementations.

For complete Boussinesq RHS timings, an authoring subclass changes only `diffZ` and otherwise calls the production `coefficientTendency` with nonlinear advection enabled. Tests use variable stratification, 8×8 columns, nonzero phase clocks, and the existing resolved mixed-family seed. Geometry, thermal evaluation, reconstruction, and projection remain in the timed call; optional diagnostics and output are excluded. Metric recovery and restoration are setup work, reported separately in [RHS results](results/rhs.csv).

| Z | Dense RHS (ms) | FFT RHS (ms) | FFT increase |
| --- | ---: | ---: | ---: |
| 33 | 8.19 | 9.17 | 12.0% |
| 65 | 14.06 | 14.35 | 2.1% |
| 129 | 16.80 | 18.38 | 9.4% |

All six coefficient families agree within a maximum relative difference of 8.90e-11 over these states. The comparison asserts a 1e-8 gate. This is operator agreement at the sampled states, not proof of trajectory accuracy or discrete conservation.

Unforced QG advection uses horizontal Jacobians and no `diffZ` calls (confirmed by the profile; the measured 8×8×65 RHS took 4.60 ms). Its full-RHS profile therefore provides a control, not an expected speedup. QG initialization and optional vertical-calculus workloads can still benefit from a future derivative kernel.

## Accuracy and memory limits

Four focused tests pass: analytic variable-metric derivatives through order four on real/complex arrays; constant and highest-degree polynomial endpoint limits; independent refinement of a boundary-localized exponential; and actual zero-APV mode differentiation with alias checks after restoring saved scientific operators without an EVP solve. The restored-state test also compares all four nonlinear sources at two nonzero clocks.

The kernel sweep also records analytic errors independently of the dense comparator. For the smooth test at Z=513, first derivatives remain near roundoff, but fourth-derivative errors exceed the true derivative for both methods. Repeated differentiation amplifies endpoint roundoff severely. The FFT candidate is not a general higher-order accuracy fix, and matching dense output alone would be an inadequate test. No smoothing or truncation was introduced to conceal this result.

Separate `/usr/bin/time -l` workers measured peak process RSS for ten real first-derivative calls on 64×64×513 samples: baseline 642.5 MiB, dense 690.6 MiB, FFT 952.9 MiB ([measurements](results/memory.csv)). All workers construct the same inputs and dense matrix. These single-run process peaks include MATLAB startup, allocator retention, and transform workspace; baseline subtraction is only an approximate incremental footprint, not an exact temporary-allocation trace. They show no memory advantage for this candidate. Full-RHS peak memory was not separately isolated.

## Reproduction and verification

With manifest-compatible dependencies configured, from the WVM root:

```matlab
addpath('tools/vertical-derivative-study');
results = runDerivativeComparison('/tmp/wvm-derivative-results');
assertSuccess(runtests('UnitTests/TestFFTWKBDerivative.m'));
```

For each of `baseline`, `dense`, and `fft`, run a separate worker:

```sh
/usr/bin/time -l matlab -batch "addpath('tools/vertical-derivative-study'); measureDerivativeMemory('fft');"
```

The comparison saves raw hotspot profiles, CSV measurements, and MATLAB metadata to its output directory. Repository results retain the compact measurements only. Production Code Analyzer passed with zero blocking findings. New-file analysis reported only the bounded growth of the analytic oracle polynomial (degree at most four), outside timing. `docs:check` again reported the two previously verified baseline differences in the density-diffusion index and version-history page. No website or package metadata changed.

A later #452 experiment could assess a native real-to-real DCT kernel and its crossover on larger workloads. It should repeat the complete-RHS and higher-order accuracy gates before adoption. The next independent implementation increment can be #453, selective reconstruction; #485 remains deferred research.
