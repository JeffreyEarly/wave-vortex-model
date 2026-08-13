# Portable integration contract traffic

- Base: `4d67051828cde19ffab55e5df2d929cdd20983b6`.
- Scope: one untimed accepted RK4 step, nonlinear-only `core-v1` schedule, exact integration-boundary arrays. FFT-plan and kernel-scratch internals are deliberately excluded.
- Historical input: the immutable issue #116 evidence commit `65518c11262522df45d3e997d3354c812db09478` and the existing published direct-compiled `core-v1` artifact. Provider selection and the readiness baseline were not repeated.
- `M = Nj*Nkl`; one complex value is 16 bytes.

## Exact schedule

| Category | Reads | Writes |
|---|---:|---:|
| Stage-state construction | `21M` | `12M` |
| Stage-tendency clear | 0 | `12M` |
| Weighted-tendency clear | 0 | `3M` |
| Weighted RK accumulation | `24M` | `12M` |
| Final accepted-state update | `6M` | `3M` |
| Forcing accumulator clear | 0 | `12M` |
| Temporary-tendency clear | 0 | `12M` |
| Shared-kernel output initialization | 0 | `12M` |
| Temporary accumulation | `24M` | `12M` |
| Forcing output copy | `12M` | `12M` |
| **Instrumented total** | **`87M`** | **`102M`** |

The shared kernel's `12M` output-initialization writes also occur in a direct compiled `nonlinearFlux` call. The standalone forcing wrapper and RK4 schedule therefore add `87M` reads and `90M` writes, or `177M*sizeof(WVComplex64)` bytes, beyond 32 direct kernel calls during the historical eight-step run.

## Core-v1 cases

| Case | Instrumented traffic/step | Increment beyond direct kernel/step | RK retained | Forcing retained | Integration arrays max-live |
|---|---:|---:|---:|---:|---:|
| Hydrostatic 256 | 2.214 GB | 2.073 GB | 105.4 MB | 308.8 MB | 449.4 MB |
| Nonhydrostatic 256 | 2.214 GB | 2.073 GB | 105.4 MB | 342.9 MB | 483.5 MB |
| Hydrostatic 512 | 17.714 GB | 16.590 GB | 843.5 MB | 2.456 GB | 3.581 GB |
| Nonhydrostatic 512 | 17.714 GB | 16.590 GB | 843.5 MB | 2.727 GB | 3.851 GB |

`WVFixedStepRK4` retains exactly `9M` complex values. The forcing engine retains `6M` complex values plus `4R` reconstruction doubles and `qR` forcing-field doubles, where `q` is three for hydrostatic and four for nonhydrostatic execution. The caller owns `3M` accepted-state values. `WVAcceptedStep`, `WVDenseOutput`, `WVOutputSchedule`, and `WVIntegrationOutputSink` add no array-sized storage in issue #182, so retained and maximum-live integration arrays are equal.

## Historical timing reconciliation

| Case | 32 direct compiled calls (s) | #116 standalone RK4 (s) | Median delta (s) | Implied traffic bandwidth |
|---|---:|---:|---:|---:|
| Hydrostatic 256 | 1.8471 | 1.8534 | 0.0062 | below process-resolution noise |
| Nonhydrostatic 256 | 2.1338 | 2.4014 | 0.2676 | 62.0 GB/s |
| Hydrostatic 512 | 12.5701 | 14.1949 | 1.6248 | 81.7 GB/s |
| Nonhydrostatic 512 | 16.8530 | 18.5749 | 1.7219 | 77.1 GB/s |

The hydrostatic direct-call and standalone process ranges overlap, so their median difference is not separable from process variation. Where the difference is resolved, the exact incremental byte count implies 62--82 GB/s, a consistent memory-traffic cost for the unchanged schedule. The diagnostic therefore accounts for the direct-kernel/standalone difference within the available measurement uncertainty without timing the counters themselves.
