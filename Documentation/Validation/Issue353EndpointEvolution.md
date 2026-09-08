# Issue #353: endpoint evolution and retained-band error

The retained-band study in PR #385 found nonmonotone bottom-displacement error even with analytical APV modes. This follow-up traces that error through signed endpoint tendencies and independently accumulated source/diffusion budgets. It preserves the existing resolved scientific modes, both active endpoints and the current weak diffusion operator. It adds authoring diagnostics and a scientific regression, with no runtime or public API change.

## Fixed problem and diagnostic coordinates

Use the same 4000 m exponential-stratification column, latitude 24 degrees, 100 km horizontal wavelength, `N2=(5.2e-3)^2 exp(2z/1300)`, `g=9.81`, and finite endpoint parameters `g0=-integral(N2)`, `gd=integral(N2)` as PR #385. Start from rest with strict surface-displacement source `10*pi/T*sin(2*pi*t/T)`, `T=365.25 days`, and constant buoyancy diffusivity `1e-5 m^2/s`. The isolated nonzero horizontal page has zero MDA; nonlinear advection, seed, drag and damping remain excluded.

Retain 217, 433, 865, 1297 and 1729 analytical APV modes plus the two canonical zero-APV boundary modes. Observe days 1, 8, 32, 64 and 91.3125. Use raw analytical normalization and the existing positive-energy diffusion coordinates, as verified in #385. The independent physical-depth reference uses 385 Legendre polynomials. The common quadrature has 8193 points.

Write the modal and reference equations as

$$\dot y_N=A_N y_N+s_N\sin(\omega t),\qquad \dot y_R=A_R y_R+s_R\sin(\omega t).$$

Here $E_Ny_N$ and $E_Ry_R$ are the two endpoint sine amplitudes. Let $V_N,V_R$ reconstruct the common positive physical-energy vectors. Define the diagnostic projection

$$P=(V_N^*V_N)^{-1}V_N^*V_R,\qquad e=y_N-Py_R.$$

This projects reference states onto the unchanged scientific columns for error accounting. It is not a production transform, a fitted modal basis or a proposed public API. In particular, this positive-energy projection does not preserve endpoint values. The representation/evolution split depends on this explicitly stated projection; total physical error and source/diffusion budgets do not.

The endpoint state error decomposes exactly as

$$E_Ny_N-E_Ry_R=(E_NP-E_R)y_R+E_Ne.$$

The first term measures representation under this diagnostic projection; the second measures evolution relative to the projected reference. Its equation is

$$\dot e=A_N e+(A_NP-PA_R)y_R+(s_N-Ps_R)\sin(\omega t).$$

The CSV separately reports the endpoint action of feedback $E_NA_Ne$, operator residual $E_N(A_NP-PA_R)y_R$, representation derivative $(E_NP-E_R)A_Ry_R$, and projected source residual. The first three sum to the difference of the diffusion endpoint tendencies. A nonzero operator residual here is a finite-space consistency measure, not by itself evidence of a coding defect.

## Signed budgets and physical localization

The augmented matrix exponential contains separate accumulators for $\int E A y\,dt$ and $\int E s\sin(\omega t)\,dt$. Thus the state is compared against independently accumulated diffusion and source contributions, including sign; this does not infer an integral by subtracting the source from the final state. The CSV also separates APV-column and zero-APV-column endpoint states and instantaneous diffusion tendencies.

To localize the operator residual, apply the endpoint weak kernel to the buoyancy-gradient difference between the projected reference and the reference itself. Integrate separately over the upper 100 m, the interior, and the lower 100 m. These fixed diagnostic windows partition the column; they are not new model boundaries. Keep the difference between cross-space weak evaluation and the reference generator as a separate `referenceWeakResidual`. This prevents a weak-reference discrepancy from being silently attributed to missing modal gradients.

## Findings

The direct bottom source vanishes. Its difference from the independent reference source is below `7.82e-20 m/s`; integrated source differences are below `3.93e-13 m`. The bottom response and its error are accounted for by accumulated diffusion. Maximum bottom budget residuals are `7.35e-13 m` for the modal solutions and `1.46e-10 m` for the reference. These are below the reference allocation at every reported time. Adding budget accumulators changes the earlier #385 endpoint RMS error estimates by at most `1.37e-10 m`.

At day 64, the independent bottom sine amplitude is approximately `40.3229` micrometres. The error decomposition is:

| APV modes | Representation error (micrometres) | Evolution error (micrometres) | Total signed error (micrometres) |
| --- | ---: | ---: | ---: |
| 217 | +41.8283 | +242.9434 | +284.7717 |
| 433 | -18.1193 | +69.9059 | +51.7866 |
| 865 | -18.4506 | +17.9750 | -0.4756 |
| 1297 | -13.4150 | +9.0635 | -4.3515 |
| 1729 | -9.6201 | +6.2031 | -3.4170 |

These are signed sine amplitudes, not RMS errors. The particularly small 865-mode result combines two much larger, opposite-signed terms under the stated projection. Its total error changes from `+0.8424` micrometres at day 32 to `-0.4756` at day 64 and `-3.7305` at quarter year. This is a cancellation at selected times, not uniform convergence. The APV-column and boundary-column bottom state contributions are both positive at day 64; the table does not claim cancellation between those two physical reconstruction contributions.

The physical-gradient localization provides information beyond an algebraic error split. At day 64, the signed upper-100-m contribution accounts for about 93–100% of the bottom action of the projected-reference operator residual:

| APV modes | Total operator-residual tendency (m/s) | Upper 100 m gradient contribution (m/s) | Lower 100 m gradient contribution (m/s) |
| --- | ---: | ---: | ---: |
| 217 | `3.47274e-10` | `3.47086e-10` | `-4.76881e-13` |
| 433 | `1.82761e-10` | `1.82058e-10` | `3.51551e-13` |
| 865 | `9.41380e-11` | `9.24124e-11` | `1.86644e-12` |
| 1297 | `6.46356e-11` | `6.17595e-11` | `3.10066e-12` |
| 1729 | `5.00450e-11` | `4.63883e-11` | `3.96069e-12` |

Interior contributions and reference weak residuals are retained in the CSV. The day-64 bottom reference weak residual is below `2e-19 m/s` in every band. Thus the measured operator residual is dominated by representing the surface buoyancy gradient in a finite band, with its endpoint effect transmitted through the balanced weak operator. It is not evidence that heat physically diffuses through 4000 m over 64 days. The annual diffusion length is about 10 m, consistent with the difficult surface structure identified in #351's mathematics.

The operator-residual tendency is also not the entire endpoint tendency error. Feedback and the derivative of representation error partially cancel it. For example, at 865 modes/day 64 these three terms are approximately `-8.84493e-11`, `+9.41380e-11` and `-6.70390e-12 m/s`; their sum is the diffusion-tendency discrepancy of approximately `-1.01522e-12 m/s`. Reporting the isolated operator residual as the actual error rate would overstate it.

## Verification and decision

Retain #385's separate endpoint RMS allowances `1e-8 m + 0.001*abs(referenceAmplitude)/sqrt(2)` and one-fifth reference allocation. Check state, error-component and integral changes against this allocation. For tendency diagnostics, use the same allowance divided by a quarter year; this is an explicit diagnostic stability test, not a universal production rate tolerance.

Repeat the 865/1729 bands with 16385 quadrature points and all five bands with 257 reference polynomials. The largest fractions of the allocated one-fifth allowance are:

| Control | States, error components and integrals | Tendency decomposition | Spatial gradient localization |
| --- | ---: | ---: | ---: |
| Doubled quadrature | 0.00484 | 0.0256 | 0.1476 |
| 257/385 reference | 0.0154 | 0.6521 | 0.2824 |

Every control passes. `issue-353-endpoint-evolution-controls.csv` identifies the worst field, band, time and endpoint for each group; the source control tables retain all individual values. Spatial windows introduce discontinuous integration masks, so their quadrature changes are checked separately. At days 64 and 91.3125, their maximum bottom change is less than `4.20e-6` of the operator-residual magnitude.

The eight affected diffusion-qualification tests pass, including a new scientific regression for strict source action, integrated endpoint budgets, nonmonotone error, and surface-gradient localization. The final affected method is rerun after adding localization; Code Analyzer has no findings after removing an obsolete suppression. Documentation comparison has zero generated drift. No website source changed, and no new documentation regeneration was needed. Full scientific and clean-install/export suites remain outside this diagnostic increment. No missing task assets prevented completion.

This closes the proposed endpoint-budget diagnosis, but not #353's intended-resolution qualification. The evidence supports a retained surface-gradient limitation and time-dependent endpoint cancellation. It supplies no independently justified correction to the current weak diffusion operator. Keep the existing hierarchy and resolved-mode transform.

The next work should target a feasible surface-gradient accuracy strategy within the scientific vertical representation, explicitly retaining the bottom target. A successful strategy must improve the surface-gradient residual and endpoint response over the whole bounded time set, not merely the bulk norm or an isolated day. The current 217-mode configuration cannot meet the stated contract; if that count must remain fixed, any change to the required accuracy is an explicit scientific decision, not a numerical fix. Do not silently change the source, diffusivity, endpoint criterion or physical problem to obtain a pass, and do not start another unrestricted high-mode search or claim nonlinear qualification from this result.

## Reproduction and scope

With the independent corrected dependencies and `UnitTests` on the MATLAB path:

```matlab
base = TestFreeSurfaceQGDiffusionQualification.runEndpointEvolutionStudy(baseFolder);
quadrature = TestFreeSurfaceQGDiffusionQualification.runEndpointEvolutionStudy(quadratureFolder, ...
    bands=[865 1729],quadratureCount=16385);
reference = TestFreeSurfaceQGDiffusionQualification.runEndpointEvolutionStudy(referenceFolder,referenceCount=257);
```

Each call writes `issue-353-endpoint-evolution.csv` to its own output directory. The control copies are committed with `-quadrature` and `-reference` suffixes. All state/integral entries are signed sine amplitudes in metres; tendencies are signed sine amplitudes in metres per second. Divide an absolute amplitude difference by `sqrt(2)` to compare with the RMS allowances used in #385. The `APV` column excludes the two boundary modes.

The baseline is WVM `c99a28bac5f6d366a7289d881ff5f0d4ed4a58e7` (PR #385), with corrected InternalModes `425e603e6af7f5914b5279262fdf47d18c627931`. These are local MATLAB R2026a authoring results. Analytical high-band controls do not qualify construction/sampling of numerical WVM transforms at those counts. Experiment pins, saved trajectories, released snapshots and package metadata remain unchanged. #354 retains released-provider/install/export and full scientific CI qualification; #367 retains the long seasonal experiment.
