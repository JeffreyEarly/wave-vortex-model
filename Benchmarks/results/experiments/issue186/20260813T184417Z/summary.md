# Portable adaptive RK3(2) validation

Source commit: `7271eae91e77b39fe937cf90fb043f6a632d960b`

| Fixture | RelTol | AbsTol | Relative error | Accepted | Rejected | RHS evaluations | FSAL reuse | Time (s) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| forcing-mixed-hydrostatic.nc | 0.01 | 1e-05 | 0.00128 | 3 | 0 | 12 | 0 | 0.0310699 |
| forcing-mixed-hydrostatic.nc | 0.003 | 3e-06 | 0.000242 | 4 | 2 | 22 | 0 | 0.0566358 |
| forcing-mixed-hydrostatic.nc | 0.001 | 1e-06 | 8.69e-05 | 5 | 2 | 26 | 0 | 0.0669442 |
| forcing-mixed-hydrostatic.nc | 0.0003 | 3e-07 | 2.55e-05 | 8 | 3 | 41 | 0 | 0.102418 |
| forcing-mixed-nonhydrostatic.nc | 0.01 | 1e-05 | 0.00143 | 2 | 0 | 8 | 0 | 0.0253124 |
| forcing-mixed-nonhydrostatic.nc | 0.003 | 3e-06 | 0.00038 | 4 | 2 | 22 | 0 | 0.0680178 |
| forcing-mixed-nonhydrostatic.nc | 0.001 | 1e-06 | 9.38e-05 | 5 | 2 | 26 | 0 | 0.079712 |
| forcing-mixed-nonhydrostatic.nc | 0.0003 | 3e-07 | 3.55e-05 | 8 | 3 | 41 | 0 | 0.125321 |
