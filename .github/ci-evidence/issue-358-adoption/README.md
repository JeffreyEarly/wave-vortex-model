# Constant schedule adoption decision

**Default adoption rejected.** The opt-in implementation passes scientific and lifecycle qualification, but its complete-model integration time exceeds the predeclared 1.03 per-profile limit. The existing default remains selected. Follow-up [#460](https://github.com/JeffreyEarly/wave-vortex-model/issues/460) owns a general small-work execution policy and renewed qualification.

The frozen v4 control is `8d08ba48b554a84b9920e349e6d4c69dccd6c0dd`. This campaign ran on an Apple M4 Max with 12 performance and 4 efficiency cores, FFTW 3.3.11 NEON/pthreads, and MATLAB R2025b. The prospective protocol is preserved verbatim in `frozen-protocol.md`; `final-provenance.json` binds source files, binaries, compiler flags, provider libraries, worker selection and author tools.

## Completed final model campaign

Each profile has eight alternating measured control/candidate pairs and two excluded warmup pairs. Every run executes 64 fixed RK4 steps and 256 RHS evaluations. Complete coefficient, field, particle, tracer, dense-output and NetCDF comparisons pass against both frozen C++ and independent MATLAB controls.

| 32×24×33 profile | Integration/control | Retained C++ storage/control |
| --- | ---: | ---: |
| Hydrostatic, coefficient only | 1.185672 | 0.969265 |
| Hydrostatic, composite output | 1.196659 | 0.978604 |
| Nonhydrostatic, coefficient only | 1.206686 | 0.969250 |
| Nonhydrostatic, composite output | 1.193681 | 0.978604 |

The overall integration ratio is 1.195651, paired 95% interval [1.180051, 1.209747]. Complete-lifetime peak RSS ratio is 0.976470, interval [0.971047, 0.982487]. Faster setup reduces complete process time to ratio 0.426821, but does not satisfy the separate integration gate. `model-summary.json` and `decision.json` retain the precise values and decision.

## Screening and intentionally incomplete timing

The worker screen tested pointwise 1, 2, 4, 8 and 12, equally weighting four native and four MATLAB-loaded large-flux profiles. The predeclared rule selected 12 with exploratory geometric flux ratio 0.497513. All screen numerical comparisons pass. Horizontal outer workers are 12, horizontal FFTW internal workers 1, Type-I internal workers 16 and coefficient workers 2. These screening results do not establish adoption or a final large-flux speedup.

Once the completed model campaign failed the mandatory integration gate, the remaining expensive measurements were stopped. Native final timing contains three complete pairs for one 256² profile and an intentionally terminated fourth control process. Final MATLAB-loaded timing was not started. Partial native samples are not used to claim a completed timing result. The orchestrator's generic `Scientific qualification failed` log message reflects the intentional SIGTERM, not a numerical discrepancy. Original logs and partial records are retained.

## Scientific and source qualification

- Pruned horizontal reference/native numerical, shared-resource ownership, concurrency and allocation tests pass in Release and ASan/UBSan.
- The 22-case compact matrix passes in Release and ASan/UBSan, including canonical restored A→B→A reuse, full-grid F/G scalar derivatives, special modes, input preservation and configured warmed allocation freedom.
- Four complete-model correctness pairs pass after the scalar storage correction. The initial composite owned-memory regression is retained as a negative result; streaming scalar derivatives through `max(4C,H)+6R` removes it.
- Two MATLAB lifecycle methods cover constant hydrostatic/nonhydrostatic with reference/native providers, including adaptive integration, dense output, MATLAB↔C++ continuation, segmentation and controlled stop/resume. All four cases pass.
- Twenty isolated comparator mutation tests pass. MATLAB-only output-group completion `history` is the sole documented provenance exclusion; all scientific values and C++ metadata checks remain strict. Original comparator rejection and corrected comparisons are retained without rerunning those integrations.
- The unchanged current ATS consumer `511aa6af9c60353b3de4d371dfe0df43159027cf` builds against the candidate and passes 7/7 tests.
- Source-selection smoke tests pass. The author worker's three unused instrumented-output warnings were corrected; its final Code Analyzer run has zero findings.
- Fresh candidate and actual-default public MEX builds pass numerical, metadata, scratch and lifecycle self-tests. Their detailed receipts are in `../issue-358-compact-correctness`; the pre-existing source-link closure fix is also tracked in #458.

## Retained artifacts

The three `.json.gz` files are compressed UTF-8 JSON metadata bundles, not native binaries. Each contains original artifact paths, SHA-256 hashes and exact text, preserving raw timings, comparison norms, setup/stage/liveness metrics, requests, reports, manifests and failure logs. Read one with `gzip -dc worker-screen.json.gz`. The uncompressed decision, summary, protocol and provenance provide the review entry points.

Large binary flux payloads, NetCDF model outputs and execution binaries remain in the exact local `/private/tmp/wvm358-*` locations recorded by the manifests. They are omitted from git; their hashes and authoring recipes are retained. No required local asset was missing. Linux required CI qualifies source portability separately; this local campaign makes no performance claim for another platform.
