# Resolved free-surface resolution transfer

This increment of #352 qualifies resolution transfer and subsequent stored continuation for free-surface QG and the forced linear Boussinesq prototype. It retains the existing class hierarchy, scientific factories, Fourier geometry, family-shaped coefficient state, forcing conversion hooks, and annotated restart path. Generic integration and persistence infrastructure acquire no model-specific family names.

## Public use

```matlab
wvt = WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(2*z/700),apvModeCount=3,mdaModeCount=2);
[fine,assessment] = wvt.waveVortexTransformWithResolution([12 10 97]);
[coarse,discard] = fine.waveVortexTransformWithResolution([6 6 65],apvModeCount=2,mdaModeCount=1);
```

Changing `Nz` changes sampling resolution. Each retained family count defaults independently to its source count. Explicit count options change the modal space: QG accepts `apvModeCount` and `mdaModeCount`; Boussinesq additionally accepts `waveModeCount` and `inertialModeCount`. Active endpoint modes remain determined by the unchanged endpoint configuration. New horizontal or vertical modes start at zero. Unrepresented source modes are discarded and quantified.

QG constructor counts are optional strict requests. Omitting them preserves its existing automatic fixed-grid qualification. A requested band that fails the provider's scientific/grid qualification rejects construction; it is never shortened silently. The target is constructed by the normal scientific factory, which can solve a new target representation. This differs from restoring a checkpoint: restoration consumes the saved operators and performs no scientific eigensolve.

For an already constructed compatible target, use the pure operation:

```matlab
[state,assessment] = source.coefficientStateForTransform(target);
for name = string(fieldnames(state)).'
    target.(name) = state.(name);
end
target.t = source.t;
```

The pure operation changes neither object and expresses the source at `source.t` in the target's `t0` convention. The convenience constructor sets both target `t` and `t0` to the source values, adopts the state, and converts its forcing registry. Transfer supports the same model class, physical domain, stratification, rotation, reference density, gravity, and active endpoint configuration. QG-to-Boussinesq model conversion is outside this increment.

## Matching resolved scientific modes

Matching uses Fourier integer pairs, physical vertical mode labels, and surface/bottom endpoint identities. It does not infer identity from storage row alone or assume a common `Nj`. Each matching source polarization is compared with its target polarization on a common refined physical quadrature. A single complex scalar aligns its normalization and reference phase. The operation never combines different vertical modes to fit a source mode or replaces the resolved basis.

The per-mode check uses the positive physical norm of velocity, total displacement, and SSH. Its default relative shape tolerance is `1e-6`; exceeding it raises `WV:TransferModeMismatch`. This is a compatibility check, not a bound on the accuracy of the continuum solution at the user's chosen resolution. The state-dependent report also exposes the actual reconstruction mismatch, including cross terms that can make a mixed state's relative error differ from individual-mode errors.

Matched APV inversion eigenvalues and wave frequencies must also agree to the declared relative tolerance. A scalar amplitude/phase fit alone could conceal inconsistent stored spectral parameters; those would change QGPV inversion or subsequent phase evolution even when the instantaneous fields matched.

Waves retain their two frequency signs and use the existing shared free-surface polarization. Inertial coefficients retain their complex amplitude and conjugate mean reconstruction; MDA remains real. Balanced state reconstruction includes the APV/zero-APV coupling and both active endpoint responses. The mean SSH/pressure gauge is unchanged. Endpoint-inactive families retain their empty shapes.

## Positive physical error report

For a horizontal real field, define the energy per horizontal area and reference density

$$E(X)=\frac12\left\langle\int_{-D}^{0}\left(|u|^2+|v|^2+|w|^2+N^2|\eta|^2\right)\,dz+g|\mathrm{ssh}|^2\right\rangle_{xy}.$$

This is positive physical energy, without signed generalized-energy endpoint weights. In the compact Fourier representation each nonzero stored amplitude includes its conjugate and contributes with factor one; the already real horizontal mean contributes with factor one half. Quadrature uses the finer stored WKB map and `2*max(source.Nz,target.Nz)+1` Gauss points by default. Both stored mode sets are interpolated to those physical depths; this neither fits weights to the retained modes nor changes either transform's operators.

Write the original field as retained content plus missing content, $X=X_r+X_d$, and let $Y$ be the transferred field at the source time. Assessment fields are:

| Field | Definition |
| --- | --- |
| `sourceEnergy`, `targetEnergy` | $E(X)$ and $E(Y)$ |
| `errorEnergy`, `relativeFieldError` | $E(X-Y)$ and $\sqrt{E(X-Y)/E(X)}$ |
| `discardedEnergy`, `relativeDiscardedFieldNorm` | $E(X_d)$ and $\sqrt{E(X_d)/E(X)}$ |
| `retainedRepresentationError` | $\sqrt{E(X_r-Y)/E(X)}$ |
| `maximumModeShapeError` | Largest scalar-aligned relative physical mode residual |
| `familyDiscardedEnergy` | Positive missing-field energy for each family separately |
| `familyMatched` | Matched scalar modes, counted across horizontal columns and means |
| `sourceTime`, `targetReferenceTime`, `quadratureCount` | Comparison time, returned coefficient phase reference, and integration count |

Full-state energies include inter-family and inter-mode cross terms. Consequently `discardedEnergy` is not `sourceEnergy-targetEnergy`, and individual family discarded energies need not sum to the mixed discarded energy. Zero source state gives zero relative errors. A nonzero discrepancy is reported rather than hidden by an energy difference or a coefficient norm. These are instantaneous resolved-field diagnostics; they do not estimate subsequent trajectory divergence or unknown continuum content outside the original representation.

## Forcing and continuation

The fresh target rebuilds each registered forcing through its existing `forcingWithResolutionOfTransform` override. Class, name, priority, evaluation stages, and target ownership must survive. The base `WVForcing` implementation constructs a generic empty forcing, so the new path explicitly rejects that inherited fallback. Unsupported conversion raises `WV:TransferForcing` without adopting a partial target or changing source coefficients/registry.

`WVPrescribedBoussinesqSource` now transfers its four spatial patterns using compact Fourier identities and the stored vertical coordinate maps. The absolute cosine clock (`frequency`, `referenceTime`, `phase`) is preserved. Each pattern must survive a sampled physical-L2 round trip with relative residual at most `1e-8`; otherwise conversion rejects instead of silently discarding forcing content. This pattern check is distinct from the modal state transfer diagnostic. Other existing forcings retain their own conversion contracts; for example, a forcing that requires the same horizontal pattern size can explicitly reject a horizontal grid change.

The controls use ordinary QG nonlinear advection with vertical diffusivity and a prescribed momentum source for linear Boussinesq. Both run through fixed RK4 with an explicit timestep. After transfer, interrupted/restored and uninterrupted controls use the same target scientific representation. This tests continuation consistency, not equality of nonlinear trajectories across different resolutions. Integrator settings are configured explicitly on restoration, as in the existing model API.

## Reproduction and scope

`TestFreeSurfaceResolutionTransfer` checks same-grid transfer, nonsquare Fourier refinement/coarsening, independent retained counts, pure and mixed families, physical label reordering, normalization/phase changes, positive discarded-field reconstruction, strict rejection, all endpoint activity configurations, forcing conversion, and continuation. Independent assessment checks reconstruct complete source/target fields through each public transform and integrate their difference on a denser rule; they do not reuse the transfer's modal polarization assembly.

Run `TestFreeSurfaceResolutionTransfer.runStudy(outputFolder)` to generate `issue-352-resolution-transfer.csv` and four checkpoint/reference pairs. In a fresh MATLAB process with all InternalModes paths removed, call `TestFreeSurfaceResolutionTransfer.verifyRestartWithoutProvider(outputFolder)`. It first asserts solver unavailability, then restores and continues all four transferred checkpoints. This advances those checkpoint files; rerun the study to recreate them.

The domain is 100 km by 100 km by 1000 m, with the constructor latitude defaults (24 degrees for QG and 30 degrees for Boussinesq), and constant $N^2=10^{-4}$ or exponential $N^2=10^{-4}\exp(2z/700)$. Standard endpoint parameters activate both surface and bottom. Sampling changes from `[8 8 65]` to `[12 10 97]`, preserving three APV modes, two MDA modes, two endpoint modes, and (for Boussinesq) four wave modes per sign and three inertial modes. Runs start at 1234 s with `t0=31` s, checkpoint at 1434 s, and finish at 1634 s with `deltaT=10` s. QG diffusivity is `1e-5` m²/s. Boussinesq's prescribed zonal acceleration is $10^{-7}\cos(2\pi x/L_x)(1+z/D)$ m/s² multiplied by a cosine with frequency `0.0003`, reference time `17`, and phase `0.4`. Quadrature stability compares 195 and 389 physical integration points.

| Model | Stratification | Relative physical field error | Maximum mode shape error | Restart coefficient error |
| --- | --- | ---: | ---: | ---: |
| QG | Constant | `9.55e-10` | `1.14e-9` | `0` |
| QG | Exponential | `4.55e-9` | `4.95e-9` | `0` |
| Boussinesq | Constant | `4.40e-11` | `1.16e-9` | `0` |
| Boussinesq | Exponential | `2.25e-10` | `5.11e-9` | `0` |

No resolved content is discarded in these refinements. Doubling comparison quadrature changes the reported field error by less than `8e-18` absolute. The committed CSV retains the full values. Restart error is the largest familywise relative Frobenius coefficient difference; the four controls also have zero error in a separate provider-free MATLAB process. Exact agreement is evidence for these aligned fixed steps, not a universal bitwise-continuation promise. Deliberate truncation is checked separately against the independently reconstructed missing field and is expected to produce nonzero error.

The WVM integration baseline is `0c745f4bdab19bbdd6433f2620566072721c6bc6`; target scientific construction uses corrected InternalModes authoring commit `e7ea60dadc4e947769cda89f7c1116f22ffa404b`. Released provider/install/full scientific CI qualification remains #354. Broader output-graph and committed-prefix stress coverage remains in #352; short staged QG controls remain #353. No package snapshots, manifests, generic output topology, or persistence formats change here. Nonlinear/adaptive Boussinesq qualification and exhaustive forcing conversions remain outside this increment.

## Verification

All eight new scientific transfer tests and 169 affected QG, Boussinesq, forcing, model, and persistence regressions passed on MATLAB R2025b Update 4. The changed forcing round-trip path and continuation passed focused rechecks; the incompatible-domain rejection also passed after resolving an output-variable/error-function naming conflict. Four transferred checkpoints passed fresh-process continuation with InternalModes unavailable.

Production Code Analyzer covered its 235-file inventory plus the four new package helpers explicitly. The naming finding was corrected and its focused recheck has no findings; no blocking findings remain. Existing style/performance advisories and the small forcing-registry growth advisory are nonblocking. The new test file has no Code Analyzer findings. Documentation generation/check passed with 2358 files, 4819 routes, and zero generated drift after public API taxonomy routing was corrected. Generated QG navigation ordering changes accompany the new method; authored site content was not expanded. Package metadata is unchanged. No task assets are missing.
