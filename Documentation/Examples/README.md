# Free-surface authoring examples

## Free-surface QG

`makeShortSeasonalQGModel` composes the ordinary `WVTransformFreeSurfaceQG`, forcing and `WVModel` interfaces. `runShortSeasonalQG` runs that model to day 32, closes its standard NetCDF file, restores it through `WVModel.modelFromFile`, explicitly reselects six-hour fixed exponential stepping and continues to day 64.

With the authoring dependencies on the MATLAB path, run this from the WVM repository root. Choose a new output filename:

```matlab
addpath('Documentation/Examples');
model = runShortSeasonalQG(fullfile(pwd,'short-seasonal-qg.nc'));
```

The run writes canonical coefficients plus SSH, QGPV and displacement daily, including day zero: 65 records. It returns the restored model at day 64 with the output file closed. The existing helper accepts explicit `gridSize`, `apvModeCount`, `mdaModeCount` and `timeStep` options when constructing a different bounded control; the run wrapper uses its defaults.

| Setting | Default |
| --- | --- |
| Domain and latitude | 500 km by 500 km by 4000 m; 24 degrees |
| Stratification | `N2=(5.2e-3)^2*exp(2*z/1300)` in s⁻² |
| Sampling and retained counts | `[24 24 65]`; 14 APV and two MDA modes |
| Boundaries | Both active; `g0=-integral(N2)` and `gd=+integral(N2)` |
| Initial condition | Fresh time zero, zero interior QGPV/MDA, six nonparallel surface seed wavevectors with zero mean and 1 cm RMS; initially zero bottom anomaly |
| Source | Strict meridional-mode-5 surface-displacement tendency in m/s; amplitude `10*pi/T`, period `T=365.25` days, phase zero |
| Other processes | Nonlinear advection, quadratic bottom drag `Cd=1e-3`, adaptive damping and vertical diffusivity `1e-5` m²/s |
| Integrator | Fixed exponential stepping, initial and maximum accepted step 21600 s |

The evolved and saved state remains adiabatic `Ag_q`, `Ag_0` and `Amda`. Internal diagonalization of the projected diffusion operator adds no thermal spatial directions. Zero initial bottom anomaly does not deactivate the bottom boundary. The strict source has no direct interior QGPV injection; the subsequent coupled trajectory can develop QGPV.

This is a bounded composition, time-refinement and restart example. It is **not a continuum-qualified seasonal simulation** at 14 APV modes. Increasing vertical sampling while holding the APV count fixed does not resolve omitted adiabatic content. The [spatial study](../Validation/Issue353SpatialAccuracy.md) separates sampling, retained-band, horizontal and damping effects. Changing resolution-dependent damping changes the closure.

Use `WVVerticalDiffusivity.assessSeasonalResponse` for observable-specific accuracy and reference-convergence estimates in its stated linear seasonal problem. Read absolute and relative errors for QGPV and each endpoint separately, and verify reference stability. Its estimates do not certify the complete nonlinear example. There is no universal one-percent target; known high-band seasonal failures remain documented in the [qualification handoff](../Validation/Issue353AdiabaticQualification.md).

The [short-case report](../Validation/Issue353ShortSeasonalQG.md) documents process budgets, actual time refinement and aligned/shifted restart. The [current audit](../Validation/Issue353AdiabaticQualification.md) records 126 passing cases and successful execution of this exact default wrapper on the corrected authoring graph. This directory is excluded from the current MPM export: #354 must adopt and verify supported examples in the released/exported workflow before claiming installed-package support.


## Nonlinear free-surface Boussinesq

`runNonlinearFreeSurfaceBoussinesq` runs a deterministic 200-second, mixed-family inviscid case with fixed five-second RK4 stepping. It constructs the resolved adiabatic inventory with horizontal antialiasing and quadratic qualification, explicitly registers `WVNonlinearAdvection`, and uses ordinary `WVModel` NetCDF output. No nonlinear forcing is installed by Boussinesq construction alone.

```matlab
addpath('Documentation/Examples');
history = runNonlinearFreeSurfaceBoussinesq(fullfile(tempdir,'new-nonlinear-free-surface-run'));
```

Use a new output directory. The example writes native NetCDF, a diagnostic CSV, and PNG/PDF plots of SSH, physical nonlinear energy change, the actual resolved energy rate and parcel-label margins. The small 8-by-8 horizontal grid is for numerical qualification, not realistic surface imagery. It uses 129 vertical samples, four APV/MDA/inertial modes and six wave modes, with both active boundaries. Mean material-label offsets keep parcels inside the prescribed density domain.

`u/v/w` are physical velocities on `z_physical`; `u_hat/v_hat/w_hat` retain the modal variables. `eta` is total displacement and `eta_i=eta-(1+z/Lz)*ssh` uses the reference sample coordinate `z`. `p` is the reconstructed modal pressure used in the manuscript nonlinear terms. See the [field contract](../../tools/nonlinear-study/field-and-runtime-contract.md) for derivative and source meanings.

This is a v5 development/beta prototype with measurable finite-inventory errors. Full nonlinear energy and material/APV moments are not asserted to be exactly conserved. The [direct manuscript refinement study](../Validation/NonlinearFreeSurface/manuscript-evolution-qualification.md) separates timestep error, spatial changes and energy-work accounting. Retained quadratic checks do not certify all rational geometry terms or every nonlinear interaction. Adaptive Boussinesq stepping, portable nonlinear execution and breaking remain outside this example. As with the QG example, this authoring directory is not part of the current MPM export.
