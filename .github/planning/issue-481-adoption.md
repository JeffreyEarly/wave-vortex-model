# Issue #481: shared inverse-y preparation

The candidate shares inverse-y preparation between each physical field and its x derivative. Multiplication by the exact physical kx commutes with the y transform because kx is constant in each Fourier-x column. The row inverse, normalization, derivative capture and x/y/z advection order remain unchanged. Native plans explicitly reject unsupported even-x Nyquist layouts and foreign stages; other providers retain their established path.

A retained stage belongs to the existing prepared-field entry, keyed by immutable view, canonical field and component. Existing evaluation/view invalidation clears readiness. Source and workspace addresses never stand in for state identity. Cold production counts are recorded directly beside each inverse-y FFT call; ready uses skip those calls. Stages publish readiness only after successful execution. All owned capacity is reported.

## Checkpoint decision

The first three-pair screen under background indexing gave 2.74% EddyTide, 2.77% larger Hydrostatic and 3.29% Boussinesq reductions. After indexing stopped, a second three-pair comparison with the exact same frozen binaries gave 3.30% EddyTide improvement, but essentially no Boussinesq benefit (candidate/baseline ratio 1.000795). All 15 paired scientific comparisons and integration decisions passed. This justified narrowing automatic adoption to Hydrostatic; the Boussinesq path remains a correctness-tested explicit C++ experiment.

Automatic retention requires the native compact Hydrostatic runner, reuse policy, and a validated nonlinear forcing dependency. Damping-only, empty, low-memory and Boussinesq runner schedules stay on their existing paths. The direct kernel option defaults off. No MATLAB scientific or checkpoint changes are included.

Additional full-depth active-column storage costs about 39 MB for the EddyTide fixture and 182 MB for the larger fixture. Hydrostatic preallocates four standard field slots, including an unused w stage. A later smaller allocation design would be a separate increment. No low-memory performance or storage claim is made. Changing a previously constructed reuse engine to low-memory does not reclaim its preallocated stages; the runner policy is fixed at construction.

## Verification ledger

- Independent provider/cache/adapter review before initial screen; fixed an unintended vertical-interface declaration and transactional null-stage publication.
- Clang native combined suite: 58/58 passed after final Hydrostatic/reuse/nonlinear gate and runner reporting changes.
- Direct stage tests cover actual FFT executions, both layouts, padding, x-first reuse, copied factors, explicit state invalidation, foreign ownership, self/Nyquist modes, failed preparation and warmed allocation-free execution.
- Native and reference family tests cover alias/component/view boundaries, derivative capture, streaming storage and explicit Boussinesq opt-in. Native forcing tests cover empty, damping-only, nonlinear reuse and nonlinear low-memory schedules.
- GCC native operator and H/B family cases passed; final affected family gate rerun passed 2/2. GCC compilation of the macOS runner encounters pre-existing Mach SDK static-assert macro errors; required Linux GCC CI covers the runner. Do not change platform headers for this optimization.
- Final source-linked forward/restart receipts, focused MATLAB science, sanitizer cases and paired qualification are pending. Compiled source and current source-selection hashes will be committed before source-linked receipt generation. Final runner must embed its frozen commit.

## Final performance protocol

Use the exact accepted PR #478 binary, frozen disposable fixtures and native FFTW provider. Freeze the reviewed candidate and source before timing; root alone schedules compute. Two excluded warmup pairs and eight alternating measured pairs are required. Extend both Hydrostatic integration windows eightfold for stable timing. Boussinesq and constant are unchanged controls; Boussinesq no longer has an improvement requirement because its new algorithm is disabled. EddyTide must improve, and any other integration or complete-lifetime regression above 3% requires investigation. Preserve unchanged scientific tolerances, identical integration decisions and zero duplicate executions. Keep raw snapshots, payload hashes and logs in the benchmark archive.

Archive: `wave-vortex-model-benchmark-artifacts/shared-inverse-columns-20260912` in the shared workspace. Pilot and quiet-confirmation source snapshots and negative Boussinesq evidence are retained. No production experiment was modified.

- Final ASan/UBSan operator and both family cases passed. Source-linked receipts at 23adc8db passed all six family methods (both providers) and the strict catalog check. All 12 focused MATLAB kernel/provenance cases passed. Final source freeze changes only receipt/evidence files; numerical inputs are identical to 23adc8db. No passing scientific suite will be repeated merely for the receipt commit.
