# Portable fixed-RK4 dense output

Decision: **DENSE-OUTPUT-QUALIFIED**

| Case | Baseline no output (s/step) | Candidate no output ratio | One output overhead | Four output overhead | Dense method bytes | Driver bytes | Error |
|---|---:|---:|---:|---:|---:|---:|---:|
| constant-hydrostatic-256x256x65 | 0.229731 | 0.9845 | 0.9774 | 1.0186 | 92244096 | 23061024 | 4.962e-17 |
| constant-nonhydrostatic-256x256x65 | 0.280847 | 0.9993 | 1.0245 | 1.0615 | 92244096 | 23061024 | 4.576e-17 |
| constant-hydrostatic-512x512x129 | 1.765879 | 0.9675 | 1.0653 | 1.0388 | 746884800 | 186721200 | 8.187e-17 |
| constant-nonhydrostatic-512x512x129 | 2.289763 | 1.0238 | 0.9659 | 0.9826 | 746884800 | 186721200 | 6.996e-17 |
