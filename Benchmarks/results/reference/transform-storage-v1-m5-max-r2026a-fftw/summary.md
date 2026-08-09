# WaveVortex benchmark

- Status: `complete`
- Run: `transform-storage-v1-m5-max-r2026a-fftw`
- MATLAB: `2026a`
- Architecture: `maca64`

## Suite scores

| Suite | Backend | Score |
|---|---|---:|

## Family scores

| Suite | Family | Backend | Score |
|---|---|---|---:|

## Timing and scores

| Suite | Case | Transform | Backend | Median (ms) | Reference score | Same-host speedup | Error |
|---|---|---|---|---:|---:|---:|---:|

## Construction and cache diagnostics

| Suite | Case | Backend | Construction (s) | First call (ms) | Same-state cache hit (ms) |
|---|---|---|---:|---:|---:|

## Memory

| Suite | Case | Backend | Persistent increment (MiB) | Peak increment (MiB) | Provider |
|---|---|---|---:|---:|---|

## Transform-storage diagnostic

Exact totals include only explicitly owned arrays with known byte counts. FFTW plan memory and MATLAB-internal buffers remain opaque and participate only in repeated RSS measurements.

### Exact persistent storage

| Case | Backend | Known persistent (MiB) | Known transient (MiB) | Opaque plans | Full persistent spectrum | Preserving scratch (MiB) |
|---|---|---:|---:|---:|---|---:|
| constant-nonhydrostatic-256x256x65 | builtin | 65.260 | 97.500 | 0 | yes | 0.000 |
| constant-nonhydrostatic-256x256x65 | fftw | 0.260 | 98.008 | 2 | no | 0.000 |
| constant-hydrostatic-256x256x65 | builtin | 65.260 | 97.500 | 0 | yes | 0.000 |
| constant-hydrostatic-256x256x65 | fftw | 0.260 | 98.008 | 2 | no | 0.000 |
| constant-nonhydrostatic-512x512x129 | builtin | 517.037 | 774.000 | 0 | yes | 0.000 |
| constant-nonhydrostatic-512x512x129 | fftw | 1.037 | 776.016 | 3 | no | 0.000 |
| constant-hydrostatic-512x512x129 | builtin | 517.037 | 774.000 | 0 | yes | 0.000 |
| constant-hydrostatic-512x512x129 | fftw | 1.037 | 776.016 | 3 | no | 0.000 |

### Repeated process RSS

| Case | Backend | Persistent runs (MiB) | Persistent median (MiB) | Peak runs (MiB) | Peak median (MiB) | Status |
|---|---|---|---:|---|---:|---|
| constant-nonhydrostatic-256x256x65 | builtin | 1240.375, 1241.016, 1243.250 | 1241.016 | 1241.062, 1241.875, 1243.875 | 1241.875 | complete |
| constant-nonhydrostatic-256x256x65 | fftw | 1368.562, 1368.703, 1370.719 | 1368.703 | 1369.453, 1369.812, 1371.594 | 1369.812 | complete |
| constant-hydrostatic-256x256x65 | builtin | 1188.844, 1189.719, 1186.812 | 1188.844 | 1189.688, 1190.469, 1187.719 | 1189.688 | complete |
| constant-hydrostatic-256x256x65 | fftw | 1310.484, 1308.281, 1310.047 | 1310.047 | 1311.703, 1309.469, 1311.047 | 1311.047 | complete |
| constant-nonhydrostatic-512x512x129 | builtin | 8492.094, 8317.125, 8490.188 | 8490.188 | 8492.859, 8317.828, 8490.969 | 8490.969 | complete |
| constant-nonhydrostatic-512x512x129 | fftw | 8619.172, 8621.656, 8622.188 | 8621.656 | 8620.047, 8622.516, 8623.031 | 8622.516 | complete |
| constant-hydrostatic-512x512x129 | builtin | 8049.438, 8051.547, 8051.766 | 8051.547 | 8050.391, 8052.484, 8052.781 | 8052.484 | complete |
| constant-hydrostatic-512x512x129 | fftw | 8213.891, 8213.172, 8207.828 | 8213.172 | 8214.984, 8214.203, 8208.859 | 8214.203 | complete |

### Memory gates

| Case | Exact savings (MiB) | Persistent RSS improvement (MiB) | Peak RSS improvement (MiB) | Threshold (MiB) | Exact | No full spectrum | No scratch | Persistent RSS | Peak RSS |
|---|---:|---:|---:|---:|---|---|---|---|---|
| constant-nonhydrostatic-256x256x65 | 65.000 | -127.688 | -127.938 | 16.125 | pass | pass | pass | fail | fail |
| constant-hydrostatic-256x256x65 | 65.000 | -121.203 | -121.359 | 16.125 | pass | pass | pass | fail | fail |
| constant-nonhydrostatic-512x512x129 | 516.000 | -131.469 | -131.547 | 128.496 | pass | pass | pass | fail | fail |
| constant-hydrostatic-512x512x129 | 516.000 | -161.625 | -161.719 | 128.496 | pass | pass | pass | fail | fail |
