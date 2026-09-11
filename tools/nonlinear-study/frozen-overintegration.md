# Frozen full-C1 horizontal overintegration

> Historical evidence. This report describes the retired weak/pressure implementation or its comparison studies. The executable solvers have been removed; see the [direct runtime qualification](../../Documentation/Validation/NonlinearFreeSurface/direct-runtime-qualification.md) for the current implementation. Historical source links refer to revision `7b9ccda7`.

This authoring study holds the canonical coefficients, clocks, vertical grid, and retained modes fixed. It changes only the horizontal quadrature grid. It supplies a bounded check of the prototype's rational metric and thermodynamic products; it does not establish a universal quadratic-aliasing theorem or qualify an evolved trajectory.

Run `runFreeSurfaceFrozenOverintegrationStudy` after `configureCIEnvironment` and adding `tools/nonlinear-study` to the path. The committed CSV contains the unrounded measurements. The implementation base is `e16ebba8`; no runtime source or manuscript was changed.

## Configuration and independent assembly

Both cases use domain 100 km × 100 km × 1000 m, stored grid 8 × 8 × 65, nEVP 256, antialiasing and quadratic inventory qualification enabled, and counts APV/MDA/inertial 2 and wave 3. The profiles are constant N² = 10⁻⁴ s⁻² and N²(z) = 10⁻⁴ exp(z/650 m) s⁻². Clocks are t = 0 and t0 = −17 s. The existing mixed seed activates all six families and both endpoint anomalies; its additional y-column waves are 0.3 exp(0.41i) times the x-column positive wave, with negative wave 0.2 exp(0.63i) times that y-column positive wave.

Every one of the 206 unit vectors in `freeSurfaceRealCoefficientLayout` is reconstructed once on the native stored grid. Direct column reshaping and horizontal `interpft` then evaluate exactly that same retained basis on padding factors 1, 2, 3, and 4. No EVP or mode selection is repeated for padding. The original packed seed is checked bitwise unchanged after every solve. The native reference physical mass is whitened only to condition dense diagnostic coordinates; all rate comparisons use that same reference physical norm, including N²-weighted displacement and g-weighted surface height.

The study independently assembles dense H and r using the mapped velocity metric R, displacement weight γN²(r), and surface mass g. It evaluates full pressure-free mapped equations on each padded grid with full horizontal FFT derivatives and the same stored vertical derivative matrix. The weak RHS contains the full surface term −w_test π_s. An SVD of the sampled SSH/surface-label/bottom-label traces constructs the retained constraint K and the orthogonal retained/discarded target split. Its rank is checked against the production boundary operator. Solving H v + Kᵀ λ = r and K v = d leaves the canonical inventory unchanged. The native dense total rate is also compared against the independent matrix-free runtime stage.

The thermodynamic helper uses valid parcel labels r = z − η and the explicitly chosen constant-surface-N² continuation above z = 0. This reference density is C1; the exponential reference is not globally analytic across zero. The study uses the full π_s = gζ − J(ζ), surface energy gζ²/2 − K(ζ), A_η = ηN²(r), and A_z = −A_η − B. Analytic constant/exponential integrals independently check buoyancy, surface pressure, and density. The old approximate `energyGeometry` study helper is never called.

The energy gradient is assembled directly from physical velocity and the exact A derivatives. Its surface geometry density is

G = (w hat(w) − |u|²/2)/D + A/D + γ(1 + ξ/D)A_z,

Ψ = ∫G dξ − ∂x∫(1 + ξ/D)w hat(u) dξ − ∂y∫(1 + ξ/D)w hat(v) dξ,

with the additional surface correction π_s − gζ. A centered energy difference with step 0.1 s along the computed rate checks this gradient separately; its absolute errors are 5.42e−13 and 4.93e−13 for the constant and exponential cases. Native dense/runtime total-rate relative differences are 7.00e−13 and 2.32e−11, respectively; the overintegration comparison itself uses only the common dense solver. The work ledger separates grid work, constraint reaction work −(K a)ᵀλ, algebraic solve work, and geometry work from the retained SSH constraint residual. The multiplier is not interpreted as pressure.

## Measurements

| Profile | Padding | Absolute rate error to padding 4 | Relative rate error | Grid-work defect |
|---|---:|---:|---:|---:|
| Constant | 1 | 1.00e−15 | 2.45e−14 | −1.20e−17 |
| Constant | 2 | 2.39e−16 | 5.83e−15 | 1.43e−17 |
| Constant | 3 | 2.86e−16 | 6.98e−15 | 7.87e−19 |
| Exponential | 1 | 5.23e−12 | 1.28e−10 | −2.03e−12 |
| Exponential | 2 | 1.61e−13 | 3.95e−12 | −2.01e−14 |
| Exponential | 3 | 5.68e−14 | 1.39e−12 | −1.94e−14 |

The full rate norms are 0.0409510 and 0.0409010 in the fixed reference physical norm. The exponential grid-work defect at padding 4 is −1.92e−14, about 9.40e−14 of the absolute component-work scale. Refining horizontal quadrature decreases its error substantially; the remaining floor is not attributed uniquely to horizontal quadrature because the vertical grid and differentiation are fixed. Padding 4 is a numerical comparison reference, not an exact answer or a certified upper error bound.

The constant case is already at roundoff. In the exponential case, the changes from padding 2/3 to 4 are much smaller than the native-to-4 change. The retained quadratic-product harmonics of hat(u)², hat(u)hat(η), and hat(η)² agree within 3.12e−16 relative across grids. The reference-mass Gram defect is at most 1.20e−12 in Frobenius norm. These controls verify the selected retained polynomial bands and unchanged sampled basis; the rational metric and piecewise reference functions are not band limited.

The reaction work persists at approximately 6.03117e−6 for constant N² and 2.21349e−6 for exponential N². It accounts for almost all of the nonzero total energy rate after quadrature converges. Discarded target RMS likewise persists near 1.84173e−9 and 2.49326e−9. Thus this study does not remove or relabel the finite-inventory constraint reaction established by the strong-residual study. The retained constraint residual is below 3.5e−18 and the energy/work identity closes within 1.1e−15 absolute.

All sampled labels lie approximately between −998.100 m and −1.80073 m, with no roundoff clipping. The minimum Jacobian exceeds 0.99736, and the minimum parcel N² is positive. Analytic buoyancy errors are below 2.1e−17 m s⁻², surface pressure/rho errors below 3.6e−15 m² s⁻², and density errors below 2.3e−13 kg m⁻³. These are stored-grid label checks; no continuous vertical parcel bound is inferred.

## Scope and verification ledger

For this fixed, small-amplitude mixed state, native horizontal quadrature is a small contributor to the observed prototype residual. Overintegration supports a bounded prototype at this seed; it does not warrant deleting rational-product qualification or replacing it with a generic all-quadratic claim. Finite-inventory reaction work remains the larger separate limitation. Larger surface deformations, other profiles, continuously sampled parcel bounds, vertical quadrature convergence, and trajectories require their own evidence.

The first sweep established convergence and valid labels. A second sweep added native dense/runtime parity and a larger centered finite-difference step to reduce cancellation in the energy-gradient check; it did not change the physical case or relax any acceptance threshold. MATLAB R2026a used `configureCIEnvironment` with `../oceankit-beta-publish`. Code Analyzer returned no issues; repository whitespace and authored-file scope checks passed. The only changed files are this note, the study script, and its CSV; package manifests and generated artifacts are unchanged. No documentation generation is applicable to this standalone authoring note.
