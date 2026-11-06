# Active-boundary experiments

Add this directory to the MATLAB path after activating WaveVortexModel and its dependencies. These examples use the InternalModes 2.0.0-beta.11 package graph. Each function accepts `profile="constant"` or `profile="exponential"` and returns the evolved transform, reconstructed fields, component fields, energy, and construction evidence.

```matlab
waves = activeBoundaryBoussinesq(profile="exponential");
heated = activeBoundaryQGBuoyancyFlux();
thermal = activeBoundaryThermalQG();
```

- **Linear Boussinesq** evolves surface and internal gravity waves, balanced APV and boundary buoyancy, inertial oscillations, and mean density anomaly. The reported physical energy is the positive quadratic reference-geometry energy. It includes cross terms within the balanced inventory. Finite-amplitude pressure and energy qualification is tracked in #555.
- **Free-surface QG** applies an inward surface buoyancy flux in square meters per cubic second and uses positive vertical diffusivity with an insulated bottom. The 100 m, 10-day case uses enhanced diffusivity to resolve the penetration depth. Compare `columnBuoyancy` with `expectedColumnBuoyancy` to check the nonzero mean input. The separate idealized endpoint-displacement benchmark uses `WVSeasonalSurfaceAnomalyForcing`.
- **ThermalQG** evolves unforced diffusion in its complete WKB polynomial representation with independent mean density anomaly. Its reference checks distinguish mean heat evolution from thermal polynomial resolution. Physical buoyancy-flux forcing for ThermalQG requires a separate adapter.

The examples run without input data and return their results in memory.
