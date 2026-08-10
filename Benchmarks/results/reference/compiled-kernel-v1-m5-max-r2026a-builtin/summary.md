# Compiled-kernel builtin baseline

- Status: `complete`
- Source: `7531c8cd0ee370864883798e45dea1179a8b4757`
- MATLAB: `2026a`
- Architecture: `maca64`

## Complete nonlinear flux

| Case | Samples | Median (s) | Relative error | Active backend |
|---|---:|---:|---:|---|
| constant-nonhydrostatic-256x256x65 | 7 | 0.148618 | 0 | builtin |
| constant-hydrostatic-256x256x65 | 7 | 0.192126 | 0 | builtin |
| constant-nonhydrostatic-512x512x129 | 3 | 1.652899 | 0 | builtin |
| constant-hydrostatic-512x512x129 | 3 | 0.976592 | 0 | builtin |

## Storage and fresh-process RSS

| Case | Known persistent (MiB) | Maximum known live (MiB) | Persistent RSS (MiB) | Peak RSS (MiB) |
|---|---:|---:|---:|---:|
| constant-nonhydrostatic-256x256x65 | 65.260 | 130.260 | 1232.000 | 1232.562 |
| constant-hydrostatic-256x256x65 | 65.260 | 130.260 | 1178.312 | 1179.594 |
| constant-nonhydrostatic-512x512x129 | 517.037 | 1033.037 | 8455.031 | 8455.641 |
| constant-hydrostatic-512x512x129 | 517.037 | 1033.037 | 8016.641 | 8017.219 |
