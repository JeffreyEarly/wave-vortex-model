# Half-x FFTW adapter benchmark

- Status: `complete`
- Run: `fftw-horizontal-v1-m5-max-r2026a-bundled`
- MATLAB: `2026a`
- Architecture: `maca64`
- Source commit: `927c602c92b675414017970bee240e457a9518b0`

## Complete-call timings

| Case | Antialias | Gate | Candidate | Forward (ms) | Inverse (ms) | Forward error | Inverse error |
|---|---:|---|---|---:|---:|---:|---:|
| fftw-half-x-64x48x17-antialias-0 | 0 | no | builtin | 0.354 | 0.521 | 0 | 0 |
| fftw-half-x-64x48x17-antialias-0 | 0 | no | layout-methods | 0.595 | 0.823 | 3.16e-16 | 3.28e-16 |
| fftw-half-x-64x48x17-antialias-0 | 0 | no | specialized-rows | 0.548 | 0.708 | 3.16e-16 | 3.28e-16 |
| fftw-half-x-64x48x17-antialias-1 | 1 | no | builtin | 0.356 | 0.393 | 0 | 0 |
| fftw-half-x-64x48x17-antialias-1 | 1 | no | layout-methods | 0.532 | 0.698 | 3.04e-16 | 3.15e-16 |
| fftw-half-x-64x48x17-antialias-1 | 1 | no | specialized-rows | 0.486 | 0.630 | 3.04e-16 | 3.15e-16 |
| fftw-half-x-65x63x17-antialias-0 | 0 | no | builtin | 0.526 | 0.590 | 0 | 0 |
| fftw-half-x-65x63x17-antialias-0 | 0 | no | layout-methods | 11.373 | 11.496 | 3e-16 | 3.64e-16 |
| fftw-half-x-65x63x17-antialias-0 | 0 | no | specialized-rows | 11.194 | 11.262 | 3e-16 | 3.64e-16 |
| fftw-half-x-65x63x17-antialias-1 | 1 | no | builtin | 0.404 | 0.501 | 0 | 0 |
| fftw-half-x-65x63x17-antialias-1 | 1 | no | layout-methods | 10.684 | 10.685 | 3.2e-16 | 4.88e-16 |
| fftw-half-x-65x63x17-antialias-1 | 1 | no | specialized-rows | 10.928 | 10.863 | 3.2e-16 | 4.88e-16 |
| fftw-half-x-256x256x65-antialias-0 | 0 | yes | builtin | 5.638 | 6.046 | 0 | 0 |
| fftw-half-x-256x256x65-antialias-0 | 0 | yes | layout-methods | 5.642 | 5.434 | 3.54e-16 | 4.28e-16 |
| fftw-half-x-256x256x65-antialias-0 | 0 | yes | specialized-rows | 5.612 | 5.465 | 3.54e-16 | 4.28e-16 |
| fftw-half-x-256x256x65-antialias-1 | 1 | yes | builtin | 3.860 | 3.120 | 0 | 0 |
| fftw-half-x-256x256x65-antialias-1 | 1 | yes | layout-methods | 2.280 | 2.909 | 3.92e-16 | 4.09e-16 |
| fftw-half-x-256x256x65-antialias-1 | 1 | yes | specialized-rows | 2.470 | 2.779 | 3.92e-16 | 4.09e-16 |
| fftw-half-x-512x512x129-antialias-0 | 0 | yes | builtin | 46.840 | 38.946 | 0 | 0 |
| fftw-half-x-512x512x129-antialias-0 | 0 | yes | layout-methods | 44.841 | 41.426 | 3.37e-16 | 4.44e-16 |
| fftw-half-x-512x512x129-antialias-0 | 0 | yes | specialized-rows | 43.686 | 42.014 | 3.37e-16 | 4.44e-16 |
| fftw-half-x-512x512x129-antialias-1 | 1 | yes | builtin | 30.250 | 24.706 | 0 | 0 |
| fftw-half-x-512x512x129-antialias-1 | 1 | yes | layout-methods | 19.761 | 23.019 | 3.27e-16 | 4.34e-16 |
| fftw-half-x-512x512x129-antialias-1 | 1 | yes | specialized-rows | 19.281 | 22.702 | 3.27e-16 | 4.34e-16 |

## Mapping selection

| Direction | Selected | Specialized / layout ratios on gate cases |
|---|---|---|
| forward | layout-methods | 0.995, 1.083, 0.974, 0.976 |
| inverse | specialized-rows | 1.006, 0.955, 1.014, 0.986 |

## Persistent adapter storage

Each FFTW adapter owns one plan, compact layout mappings, and zero persistent array-sized transform buffers. Exact repeated-process memory measurement remains issue #75.

