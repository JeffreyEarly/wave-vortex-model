# Issue #130 — Blocked and streamed scratch schedules

- ORIGINAL-GATE: `ORIGINAL-GATE-REJECT`
- CORE-DISPOSITION: `CORE-DISPOSITION-ADOPT`
- Source: `2f064975160c04a2a55dbf4c40d1edf7b41b2731`
- Provider: native FFTW 3.3.11 NEON/pthreads, 18 threads
- Protocol: three fresh processes per implementation and case; 7/3 samples

| Case | Control (ms) | Streamed (ms) | Speedup | Exact live reduction | Absolute live savings | Peak RSS reduction | Error |
|---|---:|---:|---:|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 70.319 | 71.173 | 0.971x | 17.6% | 97.500 MiB | 5.6% | 7.75e-15 |
| constant-hydrostatic-256x256x65 | 57.275 | 52.973 | 1.078x | 12.5% | 65.000 MiB | 3.5% | 9.33e-15 |
| constant-nonhydrostatic-512x512x129 | 548.269 | 533.083 | 1.032x | 17.6% | 774.000 MiB | 9.2% | 1.62e-14 |
| constant-hydrostatic-512x512x129 | 421.880 | 405.829 | 1.036x | 12.4% | 516.000 MiB | 4.8% | 2.56e-14 |

## ORIGINAL-GATE

The streamed schedule did not clear the unchanged 10% speed or exact-and-RSS memory gate.

## CORE-DISPOSITION

The contained streamed schedule reduced exact maximum-live storage by at least 10% for hydrostatic and nonhydrostatic cases at a common size, stayed within the 3% runtime limit, and preserved numerical correctness. Its absolute live-memory savings justify focused integration.

The candidate preserves four half-spectrum channels, streams one target at a time through the existing three-channel derivative inverse, and reduces real scratch from `(q+5)R` to `6R`. It retains no persistent full Hermitian spectrum. RSS is reported as supporting evidence and does not determine CORE-DISPOSITION.
