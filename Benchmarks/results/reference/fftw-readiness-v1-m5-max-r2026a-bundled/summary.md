# FFTW WaveVortex readiness

- Outcome: **NOT READY**
- Run: `fftw-readiness-v1-m5-max-r2026a-bundled`
- MATLAB: `2026a`
- Architecture: `maca64`
- Source commit: `f07e0c065314dea4430925b45c2ca1fe6715f6bc`
- Required release boundary: `v4.2.1`
- Provider: `matlab-bundled`
- Library: `fftw-3.3.8` at `/Applications/MATLAB_R2026a.app/bin/maca64/libmwfftw3.3.dylib`

## End-to-end timing and correctness

| Case | MATLAB builtin (ms) | FFTW (ms) | Speedup | Error | Speed gate | Correctness |
|---|---:|---:|---:|---:|---|---|
| constant-nonhydrostatic-256x256x65 | 109.280 | 116.927 | 0.935 | 3.85e-15 | fail | pass |
| constant-hydrostatic-256x256x65 | 91.085 | 92.149 | 0.988 | 3.01e-15 | fail | pass |
| constant-nonhydrostatic-512x512x129 | 948.697 | 845.437 | 1.122 | 1.28e-14 | pass | pass |
| constant-hydrostatic-512x512x129 | 779.996 | 713.626 | 1.093 | 1.28e-14 | fail | pass |

## Storage and lifecycle gates

| Case | Exact savings (MiB) | Persistent RSS improvement (MiB) | Peak RSS improvement (MiB) | No full spectrum | No scratch | Lifecycle | Persistent RSS | Peak RSS |
|---|---:|---:|---:|---|---|---|---|---|
| constant-nonhydrostatic-256x256x65 | 65.000 | -127.688 | -127.938 | pass | pass | pass | fail | fail |
| constant-hydrostatic-256x256x65 | 65.000 | -121.203 | -121.359 | pass | pass | pass | fail | fail |
| constant-nonhydrostatic-512x512x129 | 516.000 | -131.469 | -131.547 | pass | pass | pass | fail | fail |
| constant-hydrostatic-512x512x129 | 516.000 | -161.625 | -161.719 | pass | pass | pass | fail | fail |

## Dispatch and configuration

| Case | Backend | Fourier storage | Mapping | Vertical dispatch records | Spatial derivative dispatch |
|---|---|---|---|---:|---|
| constant-nonhydrostatic-256x256x65 | builtin | full-complex | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=composed-current |
| constant-nonhydrostatic-256x256x65 | fftw | hermitian-half-x | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=modal-direct |
| constant-hydrostatic-256x256x65 | builtin | full-complex | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=composed-current |
| constant-hydrostatic-256x256x65 | fftw | hermitian-half-x | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=modal-direct |
| constant-nonhydrostatic-512x512x129 | builtin | full-complex | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=composed-current |
| constant-nonhydrostatic-512x512x129 | fftw | hermitian-half-x | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=composed-current |
| constant-hydrostatic-512x512x129 | builtin | full-complex | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=composed-current |
| constant-hydrostatic-512x512x129 | fftw | hermitian-half-x | two-dimensional-rows | 5 | diffX=matlab-1d, diffY=matlab-1d, diffZF=dense-matrix, diffZG=dense-matrix, F-all=composed-current, G-all=composed-current |

## Failed criteria

- `constant-nonhydrostatic-256x256x65`: `speedPassed`, `persistentRSSPassed`, `peakRSSPassed`
- `constant-hydrostatic-256x256x65`: `speedPassed`, `persistentRSSPassed`, `peakRSSPassed`
- `constant-nonhydrostatic-512x512x129`: `persistentRSSPassed`, `peakRSSPassed`
- `constant-hydrostatic-512x512x129`: `speedPassed`, `persistentRSSPassed`, `peakRSSPassed`

The thresholds were fixed before this run. A complete `NOT READY` result is a successful benchmark outcome and does not advertise or release the optional backend.
