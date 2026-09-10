# Variable-matrix optimization: first increment

Issue #455 remains the adoption umbrella. The constant schedule is already adopted. This increment introduces an explicit C++ execution option for Stratified QG, Hydrostatic and Boussinesq; its default remains the established full horizontal FFT and nonlinear path. MATLAB APIs, persisted coefficients, scientific contracts and runtime support declarations are unchanged.

## Evidence and design

The spectral-kernel-benchmarks control is commit `6f2e4cd9e2f092433a584645e573d818ecaca42b`. Published issue-021 and issue-025 results establish the importance of avoiding representation bridges and fusing boundary movement, but measure synthetic spectral boundaries. Issue-008's split DGEMM advantage excludes packing and does not establish complete WVM adoption.

The current shared-matrix vertical service already passes direct contiguous-row, strided-column interleaved views to ZGEMM. Preserve that control. First expose the prepared pruned horizontal operator and stream hydrostatic physical tendencies through one target buffer. Borrow validated event-owned velocity/displacement inputs. Keep projected modal U/V/eta until their existing canonical combination, preserving arithmetic ordering and phase rules. Boussinesq retains its exact persisted groups, cross-family operators and four-target projection; only its horizontal schedule and prepared-field borrowing participate in this first increment.

Full-grid passive-scalar derivatives retain their separate prepared FFT resources. These bytes must remain in the ledger; a pruned field transform cannot silently truncate passive-scalar derivatives. No environment mutation, allocation or worker launch belongs in warmed execution.

## Prospective screening protocol

Declared before candidate timing:

- Baseline source: main `55dd8ae1929cb0f6edd26ba5fda87476aaed543a`. This first screening uses the explicit frozen and candidate branches of the same recorded source/binary; it is not the independent-source final adoption campaign.
- Primary profiles: Stratified QG and Hydrostatic at 256×256×129, exponential N2, antialiasing enabled, deterministic mixed coefficients with nonzero phases, inertial and mean-density modes where applicable. Authoritative MATLAB outputs are generated independently and frozen with SHA-256 hashes.
- Work: complete direct-kernel nonlinear flux including coefficient construction, vertical multiplication, horizontal transforms, pointwise products and projection. Time neither fixture I/O nor setup. This screen does not claim complete-model, MATLAB-loaded, forcing/event or long-integration speedups.
- One native FFTW provider thread and Accelerate matrix backend for every selection. Pruned horizontal workers: 12. Leave BLAS defaults unchanged and record the environment. No small-grid timing targets or crossover calibration.
- Compare `frozen`, `pruned`, `streamed`, `pruned-streamed` in four fresh-process blocks; alternate forward/reverse order. Each process executes two warmups and four measured fluxes. Preserve every timing and output, including failures. Stop competing MATLAB/build/test jobs during timing.
- Record source diff/files, binary and provider hashes, host, selections, worker counts, fixture hashes, raw timings, C++ retained capacity and process peak RSS. Require every payload to match independent MATLAB and the frozen output at relative L2 and max-error/max(1,max|reference|) ≤1e-10; reject nonfinite data and length mismatches. Screening evidence cannot change a default.
- Follow promising shared-matrix results with 512×512×257, split-DGEMM versus direct-interleaved complete-path comparison, MATLAB-loaded and full-model continuation/event cases. Exact-group Boussinesq matrix optimization has its own next increment. Available disk/RSS must be checked before large grouped fixtures; do not discard previous evidence to make space silently.

Final default adoption still requires prospectively frozen independent source/binary controls, the complete #455 workload matrix, a ≥10% complete-flux geometric-mean improvement, no declared large profile slower than 1.03×, confidence intervals excluding a tie, no peak-memory growth, and unchanged scientific tolerances. This first increment is candidate infrastructure and scientific qualification, not a completed adoption decision.

## Verification ledger

Complete: three Release and three ASan/UBSan C++ suites, ten MATLAB parity methods with all requested provider/schedule combinations, zero warmed allocation checks, three-family author-harness smoke, and all 64 declared large-profile runs. Five source/provenance checks pass; Code Analyzer has no messages. Failures, repairs and exact receipts are in [the evidence ledger](../ci-evidence/issue-455-variable-screening/README.md). QG peak-memory growth prevents final adoption and is tracked by #463. No MATLAB production source or generated website output is changed, so documentation regeneration is unnecessary.

### Larger-profile screen declaration

After the four-block 256×256×129 screen passed all scientific comparisons, its combined candidate/frozen time ratios were 0.1959 (SQG) and 0.3037 (Hydrostatic). Peak RSS ratios were 1.0510 and 0.7812. The SQG memory increase fails a final no-growth requirement; this screen therefore cannot authorize adoption. Preserve the complete first screen.

Before measuring 512×512×257, declare the same two families, source/binary, four selection order, four fresh-process blocks, twelve pruned workers, two warmups, four measured samples and two scientific tolerance gates. Generate new independent MATLAB fixtures with the same profile and coefficient construction. Retain the full derivative workspace to preserve currently supported scalar operations; investigate its memory overlap as follow-up work rather than removing support to pass the flux memory screen.
