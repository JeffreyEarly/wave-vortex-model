# Nonlinear RHS reuse (#484)

The nonlinear RHS now requests only `u_hat,v_hat,w_hat,eta,p,ssh` through the existing reconstruction cache. A cold call synthesizes five volume fields and obtains SSH from the pressure endpoint. Warm and overlapping requests reuse eligible cached fields with the existing coefficient/clock invalidation. It no longer reconstructs QGPV or transforms vertically repeated SSH.

Wave synthesis and source projection now batch wavenumbers with the same vertical modes. Both propagation signs share their vertical matrix products. This is exact algebraic factorization of the existing basis, with unchanged retained modes, phases, normalization, and source equations. APV, zero-APV, inertial, and mean-density formulas retain their existing meanings.

## Factored wave operations

For each horizontal-wavenumber group, let `a+` and `a-` include their respective time phases. Synthesis combines their sum and difference before applying F or G. Each requested field uses one Z-by-M matrix application to the group's M-by-C amplitudes, replacing separate arithmetic over both signs for each column.

For projection, first form the four weighted pairings

$$U=F^*(q S_u),\quad V=F^*(q S_v),\quad W=G^*(q S_w),\quad E=G^*(q N^2 S_\eta).$$

Here q contains vertical quadrature weights. With horizontal magnitude k_h, equivalent depth h, and positive frequency omega, the two unnormalized sign pairings are `common ± signed`, where

$$\mathrm{common}=(kU+lV)/k_h+i k_h h W,\qquad \mathrm{signed}=\frac{i f}{\omega k_h}(lU-kV)-\frac{k_h h}{\omega}E.$$

Division by 2h and removal of the corresponding time phase are unchanged. Zero-horizontal-wavenumber families use their separate projectors.

## Operation ledger

One unforced cold coefficient RHS, excluding optional speed/energy diagnostics and setup:

| Operation | Previous schedule | Current schedule |
| --- | --- | --- |
| Volume inverse horizontal 2D transforms | 6 | 5 |
| Volume forward horizontal 2D transforms for sources | 4 | 4 |
| Volume directional FFT passes for horizontal derivatives | 20 | 20 |
| Surface directional FFT passes | 8 | 8 |
| Volume vertical derivative applications | 5 | 5 |
| Wave synthesis, each active wavenumber group | 5 products per column, with 2M sign columns | 5 batched Z-by-M products |
| Wave projection, each active wavenumber group | 4 products per column, with 2M sign rows | 4 batched M-by-Z products |
| QGPV-only synthesis | APV products and mean-density derivative | None |

A directional pass means one forward or inverse 1D FFT batch. The balanced x/y passes above correspond to 10 volume and 4 surface 2D-transform equivalents. Thus the current cold schedule has 19 volume equivalents plus 4 surface equivalents; these are schedule counts, not a minimum. On a warm call, the five reconstruction inverses and modal synthesis are skipped. Thermodynamic evaluation, flux derivatives, and source projection still run.

The modal work remains O(KZM); batching and sharing signs reduce its constant. Horizontal work remains O(HZ log H). This increment retains dense MATLAB vertical differentiation and the corrected quadrature thermodynamics. It makes no claim to implement the entire ideal accounting-note schedule.

## Measured result

MATLAB R2026a on the local Apple Silicon host, with the same manifest-compatible dependency setup as #453. The nonlinear wrapper and projector references come from `082a3423`; the full spectral reconstruction reference preserves the earlier full-state algebra from `1353067a`. The preceding diagnostic request in the overlap case uses the same current shared path on both objects, isolating the RHS difference.

| Evaluation grid | Cold RHS before (ms) | Cold RHS after (ms) | Reduction |
| --- | ---: | ---: | ---: |
| 8×8×33 | 3.69 | 3.36 | 9% |
| 8×8×65 | 3.73 | 3.33 | 10% |
| 8×8×129 | 15.21 | 12.86 | 15% |
| 16×16×65 | 32.70 | 22.72 | 31% |

Successive-state calls improved by 8–31%, warm calls by 32–41%, and overlapping requests by 6–32% in this run. Maximum relative coefficient-family difference was 6.5e-13. These are local measurements, not platform-independent speed guarantees. See [RHS timings](results/rhs.csv), [pressure-gradient timings](results/pressure.csv), and [recorded call counts](results/operation-counts.csv).

The 8×8×65 cold profile confirms six reconstruction inverse transforms becoming five, with source forward transforms unchanged at four. Twenty wave-polarization constructions across synthesis/projection become zero. The algebraic matrix counts in the ledger explain the removed work; profiler wall times are not used as benchmark timings.

23 focused tests passed across RHS reuse, Boussinesq transforms, nonlinear evolution, unequal wave inventories, and selective reconstruction. Production Code Analyzer reports zero blocking findings. The new tests, references, and study subclass have no Code Analyzer findings; the timing script has two array-growth notices outside its timed evaluation loops. `docs:check` reports only the two previously established baseline differences: the density-diffusion index and version-history page. No website, package manifest, or released snapshot changed.

## Qualification and reproduction

The frozen references retain the pre-change full reconstruction and wave projector. Controls cover six-family contributions with mean-density offsets that keep parcel labels valid, mixed states, phase clocks, partial and warm caches, coefficient changes, restart, and unequal wave inventories. Full-source and tendency agreement use the existing nonlinear relative tolerance of 3e-10, with absolute floors of 1e-17 and 1e-18 respectively for near-zero results. A separate same-source comparison isolates projection arithmetic with a 2e-12 relative scale and 1e-22 absolute floor. This distinguishes projector accuracy from roundoff propagated through reconstructed fields and nonlinear cancellations.

Configure manifest-compatible MATLAB dependencies, including InternalModes v2.0.0-beta.4. From the authoring repository:

```matlab
addpath('tools/rhs-reuse-study');
runRHSReuseComparison('/tmp/wvm-rhs-reuse');
assertSuccess(runtests('UnitTests/TestFreeSurfaceRHSReuse.m'));
```

The study compares complete unforced coefficient tendencies with setup excluded. Cold calls clear field caches; warm calls reuse them; overlap includes the preceding `u_hat,p,ssh` request; successive calls advance the clock. Five alternating batches of 30 evaluations give median call times. States populate all six families with variable stratification and unequal retained counts. These measurements concern runtime and accuracy only.

Direct spectral pressure gradients are assessed separately, assuming pressure is already available in spectral form. Production keeps the directional derivatives: using the candidate in the cache-backed RHS would require sharing the transient spectral pressure from reconstruction, and the isolated kernel timings alone do not establish a complete-RHS benefit. No new pressure cache or derivative backend is introduced.

## Follow-up

The [remaining scheduling assessment](../rhs-scheduling-study/README.md) completes #484 against the later optimized thermodynamic baseline. It records the final pressure/setup decision, coefficient-copy and source-assembly improvements, and fresh-process complete-callback timings. The measurements above remain the evidence for the earlier wave-factorization increment.
