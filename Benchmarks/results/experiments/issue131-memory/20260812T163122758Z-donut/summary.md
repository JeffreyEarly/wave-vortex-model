# Issue #131 corrected memory reassessment

- Status: `complete`
- Core: `CORE-COMPLETE`
- Memory: `MEMORY-REGRESSION`
- Integration: `INTEGRATION-NOT-READY`
- Frozen speed evidence: artifact `d023626`, JSON SHA-256 `9bf05e1d...`

The prior artifact's timing, correctness, provider, and lifecycle fields remain authoritative. Its memory fields and integration decision are superseded.

## Corrected comparison

Ratios are median paired-process ratios with the observed minimum–maximum range in brackets.

| Case | MATLAB retained (MiB) | C++ retained (MiB) | Retained ratio | MATLAB peak RSS increment (MiB) | C++ peak RSS increment (MiB) | RSS ratio | Frozen speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 253.907 | 422.797 | 1.665 [1.665–1.665] | 396.562 | 847.891 | 2.137 [2.137–2.138] | 1.669x |
| constant-nonhydrostatic-256x256x65 | 253.907 | 422.797 | 1.665 [1.665–1.665] | 452.297 | 847.188 | 1.874 [1.873–1.876] | 1.586x |
| constant-hydrostatic-512x512x129 | 2023.893 | 3361.577 | 1.661 [1.661–1.661] | 3089.203 | 6684.344 | 2.164 [1.635–2.164] | 1.688x |
| constant-nonhydrostatic-512x512x129 | 2023.893 | 3361.577 | 1.661 [1.661–1.661] | 3527.547 | 6203.859 | 1.759 [1.450–1.895] | 1.690x |

## Accounting correction

- Each backend/case/repeat ran in a separate fresh process.
- No sampled process invoked the other backend or a correctness reference.
- Exact retained bytes include reachable application arrays; unobservable MATLAB temporaries and FFT plan storage remain opaque and are covered by operation-only RSS.
