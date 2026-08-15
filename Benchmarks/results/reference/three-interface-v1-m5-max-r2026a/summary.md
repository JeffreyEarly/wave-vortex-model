# Matched three-interface benchmark

Status: `complete`.

| Case | Interface | Process wall (s) | Integration (s) | Peak RSS (GiB) | Increment RSS (GiB) |
|---|---|---:|---:|---:|---:|
| nonlinear-flux | matlab-builtin | 4.592677 | 0.077589 | 0.841 | 0.005 |
| nonlinear-flux | matlab-compiled | 5.824119 | 0.005310 | 0.847 | 0.003 |
| nonlinear-flux | standalone-compiled | 1.287441 | 0.003978 | 0.031 | 0.001 |
| fixed-rk4-continuation | matlab-builtin | 5.546368 | 0.973202 | 0.923 | 0.026 |
| fixed-rk4-continuation | matlab-compiled | 7.105105 | 0.733741 | 0.938 | 0.026 |
| fixed-rk4-continuation | standalone-compiled | 1.448557 | 0.147102 | 0.051 | 0.018 |
| adaptive-rk23-observer-output | matlab-builtin | 5.573089 | 0.977385 | 0.926 | 0.029 |
| adaptive-rk23-observer-output | matlab-compiled | 7.121738 | 0.741129 | 0.940 | 0.026 |
| adaptive-rk23-observer-output | standalone-compiled | 1.459628 | 0.149222 | 0.052 | 0.019 |
