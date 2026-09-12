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

- A coordinator freeze error rebuilt the runner static library but did not relink the executable. The first receipt run assigned checkout 23adc8db even though the runner still embedded 60287e19. Its implementation matched the tested candidate, but those receipts are superseded, archived locally and removed from the final tree. Correctly relinked runner and probe both embed 0e46b3bc; the six-family receipt run and strict catalog check passed again at that revision. No kernel/scientific suite was repeated. Issue #488 records the missing report.source.commit guard. This rework cost one additional approximately five-minute receipt pass.
- Before timing, build the actual `wave-vortex-run` executable target after reconfiguration and verify its embedded revision. The final campaign additionally asserts every reported source commit equals the frozen candidate commit. Source/provenance-only changes do not warrant another numerical campaign.

- Final decision: do not adopt. Complete eight-pair EddyTide gain is 0.57% (95% benefit interval −0.70% to +2.11%) for 39.46 MB extra owned peak; larger Hydrostatic is 0.30% slower (interval −2.62% to +2.29%) for 181.77 MB. The roughly 2% credible-benefit objective is not met. Preserve the experiment, keep main unchanged and do not submit an unnecessary production CI campaign.
- Both Hydrostatic targets and constant control completed two warmup/eight measured pairs. Stop only this task's remaining Boussinesq control harness after two warmup/two measured pairs, because completing unchanged controls cannot reverse rejection. All 34 completed comparisons and integration decisions passed. The interrupted pair is excluded. Explicit postflight checks confirmed all source, binary, provider and fixture hashes unchanged; analysis and stop rationale are archived.
- Effort chronology (approximate UTC): implementation and early review began 12:44; the 30–45 minute checkpoint narrowed to Hydrostatic around 13:25; verification, receipt preparation and the one identity replay occupied the interval through 13:47; idle-host preflight and paired measurement ran about 13:48–14:07. These are chronological intervals, not measured active-time categories. Three existing agents were reused; root exclusively scheduled compute. No hosted CI wait was incurred for this rejected candidate.
