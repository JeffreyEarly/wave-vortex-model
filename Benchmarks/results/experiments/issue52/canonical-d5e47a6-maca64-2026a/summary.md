# Compiled-kernel validation

- Status: `complete`
- Source: `d5e47a6140ed13228d4a593b6be5cb8696a5c0b8`
- Gradient-mask path absent: `true`

| Case | Max error | Persistent core (MiB) | Known max live (MiB) | Persistent RSS (MiB) | Peak RSS (MiB) | Lifecycle |
|---|---:|---:|---:|---:|---:|---:|
| 256x256x65-hydrostatic-antialias | 9.54e-15 | 513.078 | 535.071 | 1256.594 | 1256.609 | true |
| 256x256x65-nonhydrostatic-antialias | 7.73e-15 | 545.578 | 567.571 | 1289.562 | 1289.562 | true |
| 512x512x129-hydrostatic-antialias | 2.25e-14 | 4083.823 | 4261.894 | 8686.109 | 8686.125 | true |
| 512x512x129-nonhydrostatic-antialias | 1.72e-14 | 4341.823 | 4519.894 | 8944.656 | 8944.656 | true |
