# Compiled preview memory refinement

- Status: `complete`
- Outcome: `MEMORY-UNCHANGED`
- Preview availability retained: `true`

| Case | Baseline compiled (ms) | Candidate compiled (ms) | Time ratio | Exact reduction | Exact / MATLAB | RSS / MATLAB | Speedup | Error |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 56.060 | 53.047 | 0.946 | 13.32% | 1.666 | 0.088 | 1.823x | 8.880e-15 |
| constant-nonhydrostatic-256x256x65 | 69.895 | 68.728 | 0.983 | 13.32% | 1.666 | 0.079 | 1.664x | 7.987e-15 |
| constant-hydrostatic-512x512x129 | 435.285 | 412.950 | 0.949 | 13.30% | 1.661 | 0.019 | 1.681x | 2.298e-14 |
| constant-nonhydrostatic-512x512x129 | 513.142 | 534.712 | 1.042 | 13.30% | 1.661 | 0.178 | 1.603x | 1.576e-14 |
