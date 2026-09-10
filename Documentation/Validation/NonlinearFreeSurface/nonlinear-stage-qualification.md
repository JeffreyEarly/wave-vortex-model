# Internal full-C1 nonlinear stage composition

`context = WVInternal.freeSurfaceNonlinearStage(wvt)` creates an internal unforced evaluator. `[rate,diagnostics,stage] = context.evaluate(state)` accepts the canonical reference-time coefficient structure; omitting it uses current coefficients. Evaluation does not mutate coefficients or either clock. This factory is not registered as a forcing, flux operation, integrator, or public nonlinear activation.

The evaluator explicitly selects `freeSurfaceThermodynamics` from commit `0d13ee48`: the no-motion density has its C1 constant-surface-$N^2$ physical-height continuation, with the matching full nonlinear surface pressure and energy. It neither clips nor extends parcel density. Physical labels $z-\eta$ must remain in $[-D,0]$ on the stored sample grid. The helper reports that grid's minimum and maximum labels; this is not an oversampled domain certificate.

Each evaluation reconstructs the base hatted state once, maps it to physical fields, evaluates the chosen thermodynamics, assembles the metric and weak RHS, and calls the matrix-free constrained solver. Krylov mass actions reconstruct their own variations. Existing `wvt.diffX` and `wvt.diffY` use the full FFT backend with its symmetric-IFFT Nyquist convention; `wvt.diffZ` applies the stored vertical derivative matrix. The stage adds no private Fourier implementation and does not project differentiated products prematurely into a retained modal basis.

If the full weak solve returns $v$, the returned reference-time coefficient rate is $v-La$, since reconstruction already carries the analytical phases. In particular, the helper subtracts $i\omega A_{w+}$, subtracts $-i\omega A_{w-}$, and subtracts $if A_{io}$; the balanced and MDA linear generators are zero. The linear contribution is subtracted algebraically, without replacing small residual rates by zero. `stage.totalRate` and `stage.linearRate` expose these components for internal validation.

Diagnostics contain the coupled solver report, retained kinematic target, discarded target RMS, label bounds, reference convention, and the stored-quadrature energy components

$$
E_{\rm kin}=\left\langle\int\tfrac12\gamma|u|^2\,d\xi\right\rangle,\qquad E_{\rm APE}=\left\langle\int\gamma\mathscr A\,d\xi\right\rangle,\qquad E_s=\left\langle\tfrac12g\zeta^2-K(\zeta)\right\rangle.
$$

The third output contains hatted fields, physical fields, thermodynamic fields, metric, assembled covector, solved/linear rates, and physical boundary targets. The diagnostic reaction remains a coefficient-space constraint reaction, not recovered physical pressure. Contexts must be rebuilt when their modes, counts, geometry, or reference parameters change; changing clocks alone does not require rebuilding.

## Verification ledger

The worktree was clean before rebasing this bounded increment onto root commit `0d13ee48`, which already contained the reviewed primitive helpers. This increment authors only the new stage helper, its focused test, and this note.

`UnitTests/TestFreeSurfaceNonlinearStage.m` verifies:

- A valid nonflat mixed state with both horizontal surface slopes and both wave signs agrees with an independently assembled dense physical Gram and constrained RHS solve within $2\times10^{-9}$ relative physical norm. The test uses the same full C1 thermodynamic stage, not the earlier approximate-surface trajectory equations. The raw covector, full positive kinetic metric, displacement weight, surface pressure work, and retained constraints enter the dense calculation independently of the matrix-free solve.
- For constant stratification, reported total energy agrees with the direct analytic expression containing $N^2\eta^2/2$ and the cubic surface term $-N^2\zeta^3/6$ within $2\times10^{-13}$ relative tolerance. The supplied surface pressure equals $g\zeta-N^2\zeta^2/2$ within $2\times10^{-13}$ absolute tolerance.
- Constant and exponentially varying stratification pass positive one-sided linear controls with both wave signs and independent balanced, inertial, and MDA families. Amplitudes $10^{-3}$ and $5\times10^{-4}$ retain admissible mean endpoint offsets. Extrapolated total rates agree with analytical linear evolution within $2\times10^{-7}$ relative physical norm; the nonlinear rate norm decreases by a factor between 3.7 and 4.3 under amplitude halving. No invalid negative-amplitude endpoint state is used and no roundoff clipping is introduced.
- Explicit input and default current-state evaluation agree. A context constructed before clock changes gives exactly the same result as a fresh context after both $t$ and $t_0$ change; coefficients and clocks remain untouched by evaluation.
- Reversing the valid MDA endpoint offsets triggers `WV:ParcelLabelDomain` without changing the transform. The finite-amplitude constant-profile fixture also passes the study's existing dense label checkpoints as an independent test-only check.

All three focused tests passed; after strengthening clock reuse, only the affected dense-stage/default-state method was rerun. Code Analyzer passed for the helper and test, and whitespace/scope checks passed. No existing runtime or public class, package metadata, released snapshot, or generated documentation was changed. This is instantaneous stage qualification on small grids. It does not establish physical pressure recovery, long-time integration, nonlinear energy/APV conservation, or trajectory convergence under the newly selected full C1 equations.

## Variable counts and pure-wave endpoint follow-up

On root commit `707c4683` (including the thermodynamic single-polynomial fix `aae3fa03`), the new `variableWavePagesPreservePaddingAtChangingClocks` method uses an exponentially stratified 8-by-8-by-65 grid. Wave counts cycle through 3, 2, 1, and 0 by wavenumber page. Both endpoint families remain active; the mixed seed uses the existing strictly admissible MDA mean offsets. One composed context is evaluated at $(t,t_0)=(13,7),(1301,-31),(-17,17)$. The test passed in approximately 9.21 s: padded frequencies and all returned padded wave rates (total, linear, and nonlinear) are finite and exactly zero, labels remain strictly admissible, the solve converges, and coefficients/clocks remain unchanged. Code Analyzer passed for the updated test. Only this new focused method was run; previously passing composed-stage cases were not repeated.

A separate exploratory pure-wave check exposes a remaining strict-domain limitation. The fixture has 4-by-4-by-65 samples, APV/wave/MDA/inertial counts 2/3/2/2, `nEVP=128`, and zero coefficients except the first positive-frequency wave at the first positive zonal wavenumber. Its complex coefficient is $\exp(0.37i)/(2|C_{w+}|)$, where $C_{w+}$ is that mode's SSH polarization, giving a 1 m cosine amplitude. No mean endpoint offsets or balanced anomalies are introduced: the physical wave should have zero surface/bottom density anomalies. The probe reconstructed the fields, measured labels and endpoint residuals, then called the unmodified stage evaluator.

| Profile | $t$ (s), $t_0=0$ | Maximum positive label (m) | Maximum absolute bottom displacement (m) | Evaluation result |
| --- | ---: | ---: | ---: | --- |
| $N^2=10^{-4}$ | 0 | $7.32747\times10^{-15}$ | $2.91043\times10^{-16}$ | `WV:ParcelLabelDomain` |
| $N^2=10^{-4}$ | 327 | $5.88418\times10^{-15}$ | $2.31712\times10^{-16}$ | `WV:ParcelLabelDomain` |
| $N^2=10^{-4}$ | 100000 | $7.66054\times10^{-15}$ | $3.04248\times10^{-16}$ | `WV:ParcelLabelDomain` |
| $N^2=10^{-4}\exp(2z/700)$ | 0 | $7.77156\times10^{-16}$ | $7.34932\times10^{-16}$ | `WV:ParcelLabelDomain` |
| $N^2=10^{-4}\exp(2z/700)$ | 327 | $4.44089\times10^{-16}$ | $5.84305\times10^{-16}$ | `WV:ParcelLabelDomain` |
| $N^2=10^{-4}\exp(2z/700)$ | 100000 | $5.55112\times10^{-16}$ | $6.06487\times10^{-16}$ | `WV:ParcelLabelDomain` |

The surface anomaly $\eta_s-\zeta$ has both signs, with extrema equal in magnitude to the positive-label values shown. The reported minimum label is exactly $-1000$ m in each case; the small bottom displacement is below the subtraction resolution at that depth. Thus numerical stored-mode/reconstruction endpoint residuals suffice to trigger the exact upper-label inequality even for these otherwise admissible pure-wave states. All six stage calls were rejected. The probe did not clip labels, alter endpoint modes, add artificial mean offsets, or change the evaluator. This failure is reported as an unresolved domain/reconstruction gate rather than asserted as desired permanent behavior in a passing unit test. Pure-wave stage acceptance is not qualified by the valid-offset mixed controls above.
