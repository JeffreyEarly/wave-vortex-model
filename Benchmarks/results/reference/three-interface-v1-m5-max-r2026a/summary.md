# Matched three-interface benchmark

Status: `complete`.

| Case | Interface | Process wall (s) | Integration (s) | Peak RSS (GiB) | Increment RSS (GiB) |
|---|---|---:|---:|---:|---:|
| nonlinear-flux | matlab-builtin | 5.147671 | 0.366496 | 2.774 | 0.540 |
| nonlinear-flux | matlab-compiled | 24.038388 | 0.136302 | 3.401 | 0.031 |
| nonlinear-flux | standalone-compiled | 18.415725 | 0.130502 | 1.907 | 0.002 |
| fixed-rk4-continuation | matlab-builtin | 20.336098 | 12.554711 | 6.342 | 0.312 |
| fixed-rk4-continuation | matlab-compiled | 37.410718 | 10.313583 | 6.856 | 0.315 |
| fixed-rk4-continuation | standalone-compiled | 22.203558 | 3.683529 | 4.306 | 1.439 |
| adaptive-rk23-observer-output | matlab-builtin | 20.071681 | 12.195384 | 6.343 | 0.310 |
| adaptive-rk23-observer-output | matlab-compiled | 37.349312 | 10.426888 | 6.859 | 0.318 |
| adaptive-rk23-observer-output | standalone-compiled | 22.407631 | 3.767547 | 4.428 | 1.454 |
