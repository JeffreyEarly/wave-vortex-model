# FFTW WaveVortex Disposition

Issue [#97](https://github.com/JeffreyEarly/wave-vortex-model/issues/97) records **RETIRE** for the lightweight WaveVortex FFTW integration. FFTWTransforms remains an independent reusable package, but WaveVortexModel retains only the optimized MATLAB builtin path and the backend-neutral Fourier-storage abstraction.

## Why the lightweight path was retired

The isolated FFT kernel was faster and the half spectrum reduced exact application-owned storage, but repeated WV-grid reshuffling and fine-grained MATLAB/MEX crossings consumed most of that advantage. A coarse C++ boundary recovered part of the lost time, but not enough to justify a new public backend, package dependency, ownership contract, and maintenance surface.

### Fine-grained readiness (#47)

| Case | Builtin (ms) | FFTW (ms) | Speedup | Error |
|---|---:|---:|---:|---:|
| 256 nonhydrostatic | 109.280 | 116.927 | 0.935x | 3.85e-15 |
| 256 hydrostatic | 91.085 | 92.149 | 0.988x | 3.01e-15 |
| 512 nonhydrostatic | 948.697 | 845.437 | 1.122x | 1.28e-14 |
| 512 hydrostatic | 779.996 | 713.626 | 1.093x | 1.28e-14 |

The adapter saved 65 MiB and 516 MiB of exact persistent storage at the two sizes, but its repeated-process RSS was 121–162 MiB worse before the later JVM-path correction.

### Adapter decomposition (#92)

- Mapping and assembly cost exceeded the FFT kernel in several gate cases.
- Batch-first mapping suggested an 18–33% ceiling.
- Three batched inverse transforms were about twice as fast as three separate inverse calls.
- Reusable half-spectrum storage regressed medium workloads.
- Output allocation and destructive-method detachment were too small to explain the full model gap.
- The fixed capability-query RSS increase was traced to JVM initialization and corrected independently in FFTWTransforms #9.

### Immutable dispatch cache (#93)

| Case | Uncached (ms) | Cached (ms) | Speedup | Peak RSS change |
|---|---:|---:|---:|---:|
| 256 nonhydrostatic | 125.052 | 116.708 | 1.071x | +0.22% |
| 256 hydrostatic | 106.999 | 100.205 | 1.068x | +0.25% |
| 512 nonhydrostatic | 786.419 | 781.952 | 1.006x | -0.03% |
| 512 hydrostatic | 656.488 | 669.590 | 0.980x | +0.02% |

The cache missed its 10% contained-change gate and was not retained.

### Remaining MATLAB mappings (#96)

The existing compact half-x assignment won every mapping stage. Batch-first MATLAB storage changed complete `nonlinearFlux` by approximately -2.3% to +0.9% and increased maximum-live bytes by about 50%. Contiguous-run and fixed-block variants were materially slower. No local mapping change cleared the 5% gate.

### Coarse gateway (#94)

| Case | Builtin (ms) | Coarse gateway (ms) | Speedup | Peak RSS change |
|---|---:|---:|---:|---:|
| 256 nonhydrostatic | 130.696 | 125.658 | 1.040x | +3.1% |
| 256 hydrostatic | 116.624 | 106.378 | 1.096x | +3.8% |
| 512 nonhydrostatic | 958.573 | 872.823 | 1.098x | +12.9% |
| 512 hydrostatic | 808.466 | 701.314 | 1.153x | +11.5% |

Maximum relative error was `1.28e-14`, but no common hydrostatic/nonhydrostatic region reached the 20% architectural speed or memory gate. The gateway and all experimental adapters remain unmerged.

## Retained production boundary

- Canonical coefficients remain `[Nz,Nkl]`.
- The builtin backend retains compact two-dimensional mappings and one reusable full-complex inverse buffer.
- `WVFourierStorageLayout` continues to describe full, half-x, and half-y representations for future compiled backends.
- Explicit expanded mappings remain available through `indicesFromWVGridToDFTGrid`; replicated compatibility properties are removed.
- Generic exact-storage and external-RSS diagnostics remain available for future kernel comparisons.

The compiled constant-stratification kernel milestone now compares against this optimized builtin baseline and retains its 25% complete-`nonlinearFlux` gate.

## Historical identities

| Issue | Source commit | Result identity |
|---|---|---|
| #47 | `f07e0c065314dea4430925b45c2ca1fe6715f6bc` | `fftw-readiness-v1-m5-max-r2026a-bundled` |
| #92 | `7e576f8fa3952681b598667769ad648882e841ea` | `20260809-m5-max-r2026a` |
| #93 | `33b2e40611c02d102889365de0425f0fd153c49c` | `20260810T140527Z` |
| #96 | `b9bbb1c6556a0a968e5840ae6e10ccd50ae69582` | `20260810T054714Z` |
| #94 | `97b7e71` through `1bc9806` | `20260810T151002Z` |

Fixed artifact hashes and the original branch inventory remain in [`fftw-integration-inventory.json`](fftw-integration-inventory.json).
