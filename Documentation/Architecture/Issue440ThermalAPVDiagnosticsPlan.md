# T9: Diagnose saved thermal states with APV and zero-APV modes

Status: accepted implementation plan for [#440](https://github.com/JeffreyEarly/wave-vortex-model/issues/440), 14 September 2026. The implementation is complete; historical [qualification evidence and the T10 handoff](https://github.com/JeffreyEarly/wave-vortex-model/blob/7680110e93a123b5d65b08792ed928fec4e7c221/Documentation/Validation/Issue440/ImplementationHandoff.md) record the final decisions and limits. The original planning verification below remains historical. Baseline: v5 commit `e513f3f81971539a0a74ecf1f856e9bca7d7e132`, merged through [PR #525](https://github.com/JeffreyEarly/wave-vortex-model/pull/525). T2, T7 and T8 are complete; milestone 2 has no open issues. The user approved raising the InternalModes minimum to `v2.0.0-beta.5` (`8d9503e5c7c6e4b0432a5c30b42638829a8b3f37`) or later compatible releases. Use the released beta.5 snapshot for minimum-version verification; preserve installed snapshot payloads, historical case pins and saved trajectories.

## Outcome

A user can read a committed thermal state, choose a separately qualified `WVTransformFreeSurfaceQG` diagnostic basis, and obtain APV coefficients, zero-APV coefficients, physical component reconstructions, spectra and explicit unresolved residuals. Repeated analysis reuses numerical maps. Neither the source nor diagnostic transform's coefficients, clock, forcing inventory or authoritative scientific arrays change during decomposition.

The full physical accounting is **APV + zero-APV + original horizontal mean + unresolved residual**. Diagnostic APV amplitudes are derived results. They never replace the evolved `Ath` state. Offline basis selection is independent of `WVThermalAPVDamping` and cannot change its frozen online band, sampling, weights or filter.

T9 qualifies diagnostic accuracy and measures analysis cost. T10 retains nonlinear spatial accuracy, campaign grid and damping selection, whole-model throughput and campaign readiness. No new integration path, observer hierarchy, restart format, released package or experiment-repository migration belongs to T9.

## Existing implementation and the exact gaps

| Existing code | Reuse | T9 work |
| --- | --- | --- |
| [`transformStateForward`](../../@WVTransformFreeSurfaceQG/transformStateForward.m) and [`transformStateBack`](../../@WVTransformFreeSurfaceQG/transformStateBack.m) | APV-first projection, residual endpoint order, normalization and nonzero Fourier shapes | Supply independently resolved thermal QGPV; qualify the sampled projector against overintegration |
| [`reconstructSpectralState`](../../@WVTransformFreeSurfaceQG/reconstructSpectralState.m), [`freeSurfaceTransferModes`](../../+WVInternal/freeSurfaceTransferModes.m) and [`physicalMetricOperators`](../../@WVTransformFreeSurfaceQG/physicalMetricOperators.m) | APV/zero-APV physical polarizations, surface correction and physical metrics | Apply their stored-array formulas to returned coefficients without temporarily assigning diagnostic state |
| [`thermalPolynomialFields`](../../+WVInternal/thermalPolynomialFields.m) and [`thermalVerticalInterpolation`](../../+WVInternal/thermalVerticalInterpolation.m) | Complete thermal reconstruction at physical depths; original MDA interpolation | Build thermal-to-diagnostic maps on a common refined physical quadrature |
| [`quadraticDiagnostics`](../../@WVTransformFreeSurfaceThermalQG/quadraticDiagnostics.m) and [`physicalDiagnostics`](../../@WVTransformFreeSurfaceThermalQG/physicalDiagnostics.m) | Units, physical metrics, Fourier multiplicities, radial bin sums and directional-rate conventions | Account for APV, zero-APV and residual cross terms; distinguish modal amplitudes from additive physical inventories |
| [`waveVortexTransformFromFile`](../../@WVTransformFreeSurfaceThermalQG/waveVortexTransformFromFile.m) and [`initFromNetCDFFile`](../../@WVTransform/initFromNetCDFFile.m) | Authoritative scientific restoration, committed coefficients, absolute clock and file ownership | A bounded read-only record loop; retain complete-stream selection and corruption rules |
| [`thermalAPVDampingData`](../../+WVInternal/thermalAPVDampingData.m) | Thermal/APV conventions, radius batching, endpoint subtraction and T6 refinement evidence | Reuse compatible mathematics only; its minimum-energy lift is not the APV/zero-APV physical reconstruction |

`coefficientStateForTransform` currently transfers between compatible instances of the same model. Do not widen it into an implicit thermal-to-APV evolution transfer. A lossy diagnostic decomposition needs a distinct name and residual contract.

The APV physical reconstruction methods currently read the transform's own coefficient state. T9 must not implement analysis by assigning `Ag_q`, `Ag_0` or `Amda` and then restoring them. Use existing stateless polarization workers, extracting only a narrow shared worker if the required field set otherwise duplicates substantial code.

## Scientific contract

### Compatible diagnostic basis

Require matching physical domain, horizontal grid/support and Fourier conventions, gravity, Coriolis parameter and stratification, with both endpoints active in the order `[surface; bottom]`. Match Fourier integer pairs explicitly; do not assume compact columns have identical positions. Reject unsupported horizontal truncation or changed physics in T9. Resolution transfer is a separate operation.

The caller constructs or restores the APV transform and explicitly records `g0`, `gd`, requested and actual APV counts, physical mode labels, normalization, `Nz`, `gramTolerance`, `modeConvergenceTolerance`, `boundaryResolutionTolerance`, `muTolerance`, `shouldAntialias`, and `quadraticDealiasing` with its parameters. Use `quadraticDealiasing="none"` for a diagnostic transform that should retain the complete accepted linear prefix; preserve the source's horizontal support. This choice does not disable mode, Gram, boundary, or inversion-separation checks.

For the first comparison, use the existing signed endpoint convention, with explicit values equal to the negative and positive stratification integrals. Also test an alternative admissible pair to demonstrate that decomposition depends on diagnostic weights while the reconstructed total remains the same to its reported accuracy. Signed equivalent depths and modes must be retained. Do not assume a positive generalized energy or silently drop a difficult mode.

A diagnostic APV band may have more coordinates than the thermal space. Unlike the online damping lift, diagnosis does not require a right inverse or full row rank of the thermal-to-APV map. Judge the diagnostic basis's own conditioning and projection accuracy, not the T6 lift's rank requirement.

### Projection and reconstruction

For each nonzero horizontal radius, evaluate the complete thermal polynomial map at physical depths. Let `C` be the pressure-polynomial coefficients, `Q_k` the QGPV reconstruction, and `B` the two endpoint displacement traces. Then `q = Q_k*C` and `theta = B*C`, where QGPV is in s^-1 and endpoint anomalies are in m. These are interior-displacement anomalies, not SSH or a buoyancy-flux surrogate.

On a physical-depth quadrature with diagonal weights `W`, let `F` contain the selected diagnostic APV F modes. Use the existing F-channel Galerkin convention:

$$G_F = F^* W F, \qquad a_q = G_F^{-1}F^*Wq.$$

Implement this with a stable weighted QR/factorization and condition checks. The APV F pairing is the ordinary physical-depth integral; its mode shapes still depend on the signed endpoint weights. Do not import the signed G-channel pairing, physical source dual, Euclidean thermal norm or a DCT coefficient rule into this step. Do not replace the sampled Gram matrix by its continuous `Lz*I` target without accounting for the measured Gram defect. Compare the native-grid path directly with `apvFForward` and `transformStateForward`.

With `E_k = apvEndpointResponse(:,:,page)`, recover residual endpoint coefficients using the existing convention:

$$a_0 = -\frac{g}{f}k_h^2\left(\theta-E_k a_q\right).$$

Both `Ag_q` and `Ag_0` have units s^-1. Their shapes are `apvModeCount × NklNonzero` and `2 × NklNonzero`. The endpoint response maps s^-1 to m and therefore has units m s; audit the existing `apvEndpointResponse` annotation, which currently labels it m, and correct that metadata narrowly if confirmed by the implementation unit check.

Use the diagnostic transform's stored `apvF`, `apvG`, `apvMu`, `zeroAPVF` and `zeroAPVG` for synthesis. In particular,

$$\psi_q=-F\,\operatorname{diag}(\mu^{-1})a_q, \qquad \psi_0=-k_h^{-2}F_0a_0.$$

Apply the corresponding G polarizations, `eta_i = eta - (1+z/Lz)*ssh`, `ssh = (f/g)*psi(0)`, horizontal derivatives and `buoyancy = -N2*eta_i`. Compute the unresolved field as the reconstructed thermal field minus the retained physical components. Never substitute the damping closure's lift for these polarizations.

Use physical Gauss integration, or the existing mapped rule with its explicit `dz/ds` factor. Evaluate thermal polynomials using their analytic physical WKB coordinate; evaluate stored APV arrays through the existing mapped interpolation workers. More quadrature points cannot repair an underresolved stored APV mode or coordinate map. Retain separate diagnostic-grid refinement checks.

### Horizontal mean and reality

Carry the original real thermal `Amda` and its scientific identity as a separate mean contribution. Reconstruct mean displacement, buoyancy, QGPV and endpoints from its stored MDA arrays. Do not copy its indices into the diagnostic transform's potentially different MDA basis or solve a second mean projection in this issue. Diagnostic `Amda` is neither read as input state nor assigned by this API.

Retain the existing zero-mean SSH/streamfunction gauge and zero mean horizontal velocity. Apply APV inversion only at nonzero radii. Use the existing compact Fourier pair weights: nonzero pairs contribute twice to real-field variance; the real mean contributes once. Test conjugate recovery and Nyquist exclusion through shared Fourier layout methods.

### Residuals, spectra and physical budgets

Return absolute and relative residuals for QGPV, buoyancy, velocity, total/interior displacement, SSH and each endpoint separately, plus the positive physical-energy norm of the field difference. Report reference magnitudes alongside relative errors; when a reference is zero, mark the relative measure undefined and retain the absolute measure. Never use a tiny floating-point denominator to imply a meaningful relative error.

Compute residual norms from the difference fields. Do not subtract source and retained energies. For each quadratic inventory, expose the self contributions and cross contributions among APV, zero-APV and residual; the original horizontal mean is orthogonal to nonzero Fourier content. Their sum must recover the complete source inventory. The physical energy convention remains the horizontally averaged depth integral in m3/s2, including total-displacement and SSH terms.

Return modal coefficient power with explicit coefficient-squared units, physical APV mode labels and endpoint labels. Return physical radial spectra as bin sums using `kRadial`, with the mean recorded separately. A diagonal modal-power plot is not an additive physical-energy spectrum: include the required cross terms in physical accounting. A small endpoint residual, which the zero-APV responses can enforce even with a narrow APV band, does not demonstrate resolved interior content.

For supplied canonical thermal tendencies, apply the same fixed linear maps to obtain directional modal rates and residual-field rates. Use full bilinear physical contractions for directional budgets, including cross terms. The caller owns process labels and their order. Recomputed physical tendencies must come from the existing full `coefficientTendency` process breakdown at the saved clock and forcing configuration, including diffusion and the exact seasonal source once. Integrator exclusions are not appropriate for a total physical budget. The decomposition API itself does not evaluate forcings or change state.

State snapshots alone do not establish time-integrated process budgets. The example/report must say whether rates were saved or recomputed, retain actual observation times, and time-refine any claimed integrated budget. An instantaneous directional response is sufficient for the T9 API; long campaign budget convergence remains T10.

## Proposed API and implementation ownership

Add one public instance method to the thermal peer:

```matlab
[diagnosis,reconstruction] = thermal.apvDecomposition(apv, state=state, tendency=tendencies, time=t, quadratureCount=nQuad, fieldNames=["ssh","endpointAnomalies"]);
```

`state` defaults to the current `Ath/Amda` state and `time` to the current physical time. `tendency` follows `quadraticDiagnostics`: an optional row of family-keyed structures. With one output, compute coefficient results, scalar/per-wavenumber accounting and spectra without allocating physical volumes. The optional second output contains only requested real physical fields for `total`, `apv`, `zeroAPV`, `mean` and `residual`, with explicit `x`, `y` and common quadrature `z`; volumes are `Nx × Ny × Nq`, SSH is `Nx × Ny`, endpoints are `Nx × Ny × 2`. Default requested fields are the two endpoint products above. Use existing Fourier geometry configured for the requested vertical count.

The `diagnosis` structure contains `time`, `coefficients.Ag_q`, `coefficients.Ag_0`, `mean.sourceAmda`, modal labels/power, physical inventories and cross terms, radial spectra, residual norms/reference scales, directional results and construction/projection metadata. It is deliberately not a complete prognostic state for the diagnostic transform. No new result class or persisted operator schema is required.

Proposed file ownership:

- `@WVTransformFreeSurfaceThermalQG/apvDecomposition.m`: public validation and output contract.
- `+WVInternal/thermalAPVDecompositionData.m`: quadrature, stored-array polarizations, stable projection factors and radius maps.
- `+WVInternal/thermalAPVDecomposition.m`: map application, residuals and physical accounting; split a further helper only if substantial logic is shared.
- A dedicated private `apvDecompositionData_` cache on the thermal peer, absent from authoritative storage. Keep one entry keyed by diagnostic object identity and quadrature configuration. Scientific arrays and geometry are immutable through the supported APIs; a different diagnostic object or quadrature rebuilds it. Changes to coefficients, time or forcing reuse it. A new source basis or restored object starts with an empty cache. Document this dependency contract and test it.
- `tools/analyzeThermalAPVOutput.m`: authoring convenience for committed record loops and bounded example results; core diagnosis remains available from the installed runtime.
- `tools/qualifyThermalAPVDiagnostics.m` and `UnitTests/TestThermalAPVDiagnostics.m`: reproducible qualification and tests. Keep generated evidence outside the repository and record the reviewed outcome on [issue #440](https://github.com/JeffreyEarly/wave-vortex-model/issues/440).

Do not cache a record's fields or tendencies across mutations. Batch all columns of the same radius. Reuse prepared data across the file loop and only allocate requested reconstructions. Cache diagnostics may be inspected in tests through a focused counter/fixture; do not expose private cache arrays as public API.

## Implementation increments

1. **T9a — establish the projection contract.** Implement the builder and a direct, uncached reference application for one state. Validate geometry and endpoint compatibility; preserve APV labels, means and coefficient units. Compare the native path with `transformStateForward`; qualify overintegration independently. This is the first review checkpoint: agree on sampled versus refined projection and the exact meaning of the residual before optimizing or adding file orchestration.
2. **T9b — reconstruct and account for everything.** Add APV/zero-APV physical synthesis, original means, residual fields, physical inventories/cross terms, coefficient histories and physical radial spectra. Use arbitrary finite state input without mutating either transform. Prove independent field and metric comparisons, not just subtraction identities.
3. **T9c — batch, cache and diagnose directions.** Cache radius maps and factors, test every dependency boundary, and apply the same maps to a row of process tendencies. Extend the actual T7 budget convention. Compare cached and direct results and ensure richer offline bands leave the online closure untouched.
4. **T9d — analyze committed output.** Read a source once with the shared reader in read-only mode, iterate committed records through `initFromNetCDFFile(...,shouldRequireCoefficientState=true)`, and call the same public method. Loading the next record intentionally changes only this private analysis object; decomposition does not mutate its input. Reuse shared complete-state group selection to obtain the committed count; extract that existing selection into a narrow shared helper only if required, instead of implementing a competing search in the utility. Test scalar snapshots, non-root complete streams, incomplete tails, ambiguous streams and file cleanup.
5. **T9e — qualify, document and hand off.** Run the matrix below, measure construction versus cached analysis costs, add the public installed-package example/consumer, generate affected API documentation once and complete final checks. Record all results and limitations in #440. Close T9 only after the implementation and evidence are merged; keep T10 open.

These increments can be reviewable commits within one T9 implementation branch/PR. Projection/synthesis contracts must precede parallel work. If delegating implementation, assign independent manufactured references and validation to one agent, committed-output/example work to another after the result contract is fixed, and keep the core projection/metric implementation with the coordinator. Avoid two agents editing the thermal class or shared reader simultaneously.

## Qualification matrix and acceptance gates

Use constant-stratification controls and the existing exponential profile, both active endpoints, signed endpoint weights, nonparallel Fourier pairs, multiple radii and a nonzero real mean. A six-mode diagnostic band reproduces the T6 convention as one control; larger bands are independent diagnostic choices, not changes to damping. Keep provider construction, stored-mode sampling, projection quadrature and retained band as separate refinement axes.

| Control | Evidence required |
| --- | --- |
| Pure APV, separate surface/bottom zero-APV, mixed states | Expected coefficients, endpoint subtraction, units and reconstructed fields from independent analytical/provider samples; quantify any preliminary fit into the thermal space separately |
| Mean-only and mixed mean/nonzero states | Preserve original Amda, column buoyancy, mean QGPV and both endpoints without assigning diagnostic Amda or applying zero-radius inversion |
| Fixed stored modes, Q/2Q/4Q physical quadrature | Converged projection maps and physical residual norms; distinguish integration of interpolants from accuracy of the stored modes |
| Fixed diagnostic band, refined diagnostic Nz/provider solve | Aligned mode labels/signs and independently converged physical polarizations; preserve signed modes and report construction conditioning |
| Fixed converged quadrature, increasing retained APV band | Visible omitted QGPV/field residual; retained components plus residual recover total; no blanket claim that physical-energy error must decrease monotonically under this projection |
| Thermal surface-layer state | At least one narrow-band result with substantial unresolved content, plus both endpoint residuals and independently refined reference; do not report small endpoints as overall accuracy |
| Frozen online closure | Changing diagnostic band/weights leaves source coefficients, forcing inventory, persisted closure arrays and its computed tendency unchanged |
| Directional tendencies | Linear map action, independently differenced modal coefficients/physical inventories, actual ordered process labels, and total process sum consistent with T7 |
| Current memory versus saved record | Same public diagnosis at the same physical time; coefficients, clock, scientific arrays and forcing unchanged by decomposition; input file bytes unchanged |
| Scientific provider unavailable | Restore saved thermal and diagnostic transforms, build numerical maps and diagnose in a fresh process with InternalModes absent; scientific construction is allowed only when explicitly creating the diagnostic basis |
| Cache and package surface | One preparation across changing records; rebuild for changed target/quadrature; installed-runtime example needs no UnitTests, tools, Documentation or literature files |

Initial acceptance targets must be encoded before the qualification runs, with pass/fail status preserved. Use normalized manufactured controls away from singular inversion:

- Algebraic component recomposition and cached/direct agreement: `5e-12` relative to a sum-of-component scale, including separately checked zero quantities. This tests implementation consistency, not independent physical accuracy.
- Independent modal coefficient recovery and fixed-band quadrature convergence: `1e-8` in a declared coefficient/physical majorant norm. Require the independently estimated reference error to consume at most one fifth of the allowance.
- Independent physical controls: relative allowance `1e-8` with absolute floors of `1e-13 s^-1` for QGPV, `1e-12 m/s2` for buoyancy, `1e-12 m/s` for velocity, and `1e-10 m` for displacement/SSH/each endpoint. Set manufactured amplitudes so the relative term is exercised; include genuine null controls for the absolute terms.
- Field-energy norm and inventory/cross-term accounting: `1e-8` against independently reconstructed, well-scaled nonzero controls. Report near-zero quantities on absolute physical scales instead of unstable relative ratios.
- Read-only coefficients, time, forcing configuration and authoritative arrays: exact equality; input file hash unchanged. Floating-point equality across independently ordered contractions is governed by the declared numerical allowances, not bitwise comparison.

These are diagnostic gates, not new campaign tolerances or silent changes to constructor defaults. If a target is unattainable at the declared diagnostic resolution, retain the failure and refine the reference/grid or explicitly revise the plan with a mathematical explanation before declaring success. A large genuine truncation residual is a valid measured result, not a reason to loosen a projection-accuracy gate.

Start small, then include one 257-direction target-geometry exponential state. Reuse the deterministic T8 saved-state generation path or create its bounded equivalent; no full seasonal trajectory is needed. Reuse T6's 513/1025/2049 fixed-band sampling evidence as context, while independently checking the T9 synthesis and residual contract. Do not require untracked historical literature files to run the tests.

Measure diagnostic basis construction, map preparation, cached per-record coefficients/metrics, optional field reconstruction, file read cost, retained map bytes and peak scratch separately. Use several records after warm-up, record hardware/MATLAB/thread settings and report median timing. These measurements establish analysis cost for T10, not a whole-model speedup.

## Example and verification handoff

The documented example should have this shape; the new method and options below are proposed, while the transform constructors/readers already exist. Counts and tolerances must come from the completed T9 qualification rather than becoming campaign recommendations.

```matlab
[thermal,file] = WVTransform.waveVortexTransformFromFile(inputPath,iTime=1,shouldReadOnly=true);
cleanup = onCleanup(@() file.close());
apv = WVTransformFreeSurfaceQG([thermal.Lx thermal.Ly thermal.Lz],[thermal.Nx thermal.Ny diagnosticNz],N2Function=thermal.N2Function,latitude=thermal.latitude,g=thermal.g,rho0=thermal.rho0,g0=diagnosticG0,gd=diagnosticGd,apvModeCount=diagnosticModeCount,mdaModeCount=1,shouldAntialias=thermal.shouldAntialias,quadraticDealiasing="none",gramTolerance=gramTolerance,modeConvergenceTolerance=modeConvergenceTolerance,boundaryResolutionTolerance=boundaryResolutionTolerance);
[diagnosis,fields] = thermal.apvDecomposition(apv,quadratureCount=nQuad,fieldNames=["ssh","endpointAnomalies"]);
for iTime = committedIndices
    thermal.initFromNetCDFFile(file,iTime=iTime,shouldRequireCoefficientState=true);
    history(iTime) = thermal.apvDecomposition(apv,quadratureCount=nQuad);
end
```

`committedIndices` must come from the shared complete-stream/commit contract, not a root `t` variable or the allocated time dimension. The analysis utility preallocates compact history or processes a bounded record batch; it does not retain every reconstructed volume. Diagnostic MDA count above is only required by the existing constructor; the original thermal mean remains separate. A restored diagnostic transform can replace scientific construction. Save that diagnostic transform through its existing annotated writer to a separate file, and record construction assessment, selected counts/weights, source path/hash, commit range, physical times and projection settings in the analysis provenance. Do not write back to the input trajectory.

Run clean `configureCIEnvironment` setup and verify the unique beta.5 InternalModes path, excluding sibling checkouts. Preserve ClassAnnotations 1.2.1, NetCDF 1.0.2, SplineCore 2.2.0 and the existing chebfun snapshot; documentation uses ClassDocumentation 1.3.2. Record exact dependency revisions at implementation start. Run MATLAB outside the local sandbox per the workspace Apple Silicon policy, and verify the minimum supported R2025b release.

Focused regressions include the new T9 class and affected methods in `TestWVTransformFreeSurfaceQG`, `TestFreeSurfaceQGDiagnostics`, `TestSharedResolvedContracts`, `TestThermalDiagnostics`, `TestThermalDamping`, `TestThermalOutputRestart`, `TestFreeSurfaceOutputRestart` and `TestFreeSurfaceResolutionTransfer`. Only broaden beyond affected methods when the change reaches their shared runtime path. Run Code Analyzer on added/changed MATLAB files and the production inventory. Generate affected canonical API documentation once, run `docs:check` once, and check whitespace, links, scope, package manifest and exported runtime availability. Enable the final integration/package CI policy before merge; reuse the milestone-2 verification discipline without repeating successful gates unnecessarily.

The evidence directory must retain the predeclared matrix/tolerances, independent-reference error estimates, all measured residuals, failures, timings, reproduction commands and any blocked checks. T9 is complete when a saved state is diagnosed reproducibly and read-only, all retained components plus explicitly measured residual account for its physical content, and the small example runs using public installed APIs. T10 then uses these diagnostics to decide actual campaign accuracy, closure and cost.

## Planning verification ledger

- Reviewed the current #440 body and both milestone-2 handoff comments, the merged v5 head, shared projection/reconstruction/metric and committed-reader implementations, and beta.4 F-channel projection semantics.
- Confirmed PR #525 merged at the stated baseline and milestone 2 closed with zero open/five closed issues.
- Planning changes are confined to this architecture document. No MATLAB implementation, experiment, snapshot, manifest or website source changes are part of this planning turn.
- Planning checks passed: all 14 document links resolve locally or point to the referenced GitHub resources; local link targets, code fences, trailing whitespace and repository scope were checked. The unrelated untracked initialization study remains untouched.
- MATLAB R2025b with clean `configureCIEnvironment` setup, unique beta.4 resolution and ClassDocumentation 1.3.2: `buildtool("docs:check")` passed, validating 2653 files and 5413 routes with zero failures and zero generated differences. Setup emitted the existing package-path ordering and Java X11 warnings; neither blocked verification.
- No MATLAB source/tests changed, so numerical tests and Code Analyzer were not run for this planning-only change. Proposed tests and numerical targets above have not yet been executed. No required planning check is blocked.
