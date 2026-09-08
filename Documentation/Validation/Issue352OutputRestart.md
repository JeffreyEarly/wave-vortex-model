# Shared free-surface output and restart

This bounded increment of #352 qualifies the existing output and restart architecture for free-surface QG and the forced linear Boussinesq prototype. Both use ordinary `WVModel`, annotated scientific state, independently shaped coefficient families, and the shared output-file/group hierarchy. The production change is confined to the particle and tracer readers; no persistence schema, provider, model hierarchy, or resolved transform changes are needed.

## Defect and correction

Output records are written in two phases: write and sync payloads, then commit each group by writing its finite time coordinate. A payload can extend the NetCDF unlimited dimension before the record is committed. The coefficient and output-group readers already use the contiguous committed prefix, but `WVLagrangianParticles` and `WVTracer` read the raw last record. Consequently an interrupted write could restore correct coefficients together with wrong particle positions, tracked fields, and tracer concentrations.

The new fault-injection tests reproduced this disagreement in both models by writing an uncommitted particle displacement of 1000 m and tracer offset of 7. Both readers now use `WVModelOutputGroup.committedRecordCountForGroup`. A group with no committed records supplies its persisted observer configuration and an empty state candidate. Existing file-level reconciliation selects a shared observer saved at the coefficient restart time and replaces the empty candidate. Empty state is never accepted as the model's restart state: when no current saved candidate exists, restoration rejects. Legacy files continue to use the shared helper's existing legacy-record interpretation.

This preserves the original distinction between a group's committed output history and the integrated model state. A diagnostic group can already have committed output beyond the coefficient checkpoint. On restoration, the model adopts observer state from the group at the coefficient checkpoint, retains the diagnostic group's committed prefix, and resumes its schedule without duplicating those diagnostic records. A group with an uncommitted next payload overwrites that record on its next scheduled write.

## Qualification matrix

`TestFreeSurfaceOutputRestart` has 20 parameterized cases across both peers:

- Incomplete writes containing only the first coefficient variable, or all observer payloads with deliberately corrupted values and no committed time.
- Interrupted/restored and uninterrupted evolution with different coefficient and diagnostic schedules, including diagnostic output ahead of the coefficient checkpoint.
- Shared particles and tracers in a later-starting group, with either no record or an entirely uncommitted first payload; successful reconciliation and the group's first subsequent committed write.
- Rejection when a unique particle or tracer observer has no saved state at the coefficient checkpoint.
- Separate restart-capable files restoring only their own output graph.
- Rejection of files with no committed coefficient record, and holes in either the coefficient or diagnostic group's committed prefix.
- Rejection of duplicate complete coefficient streams before file creation and when reading a malformed file. Coefficient discovery uses each transform's declared families.

Continuation compares every coefficient family, reconstructed `u`, `v`, `eta`, `ssh`, and `qgpv`, positive total and every registered flow-component energy inventory, particle positions and tracked fields, and tracer values. Selected scientific grid/mode/derivative/quadrature operators, `t`/`t0`, and persisted forcing and integrated-observer configuration are also checked. Output comparison covers all time-dependent stored variables, including Boussinesq `w` and `p`, moorings, particles, tracers, and real/imaginary coefficient payloads, with identical time vectors and variable inventories. Component energies are compared through the public diagnostic API at checkpoint and final time; they are not new serialized state.

## Controls and error norms

The domain is 100 km by 100 km by 1000 m at latitude 30 degrees, sampled on `[8 6 65]`. Constant stratification has $N^2=10^{-4}$ s$^{-2}$; exponential stratification has $N^2=10^{-4}\exp(2z/700)$ s$^{-2}$. Both endpoints are active. Each model retains three APV and two MDA modes and two active endpoint modes. Boussinesq additionally retains four wave modes per frequency sign and three inertial modes. Deterministic mixed coefficients populate all retained families, including real MDA and nonzero horizontal means.

QG uses nonlinear advection and vertical diffusivity `1e-5` m²/s. Linear Boussinesq uses the persisted prescribed zonal acceleration $10^{-7}\cos(2\pi x/L_x)(1+z/D)$ m/s² multiplied by a cosine with frequency `0.0003`, reference time `17`, and phase `0.4`. Both integrate with fixed RK4 and `deltaT=5` s, explicitly reselected after restoration. Runs start at 127 s with `t0=31` s, checkpoint at 207 s, and finish at 367 s. The interrupted run first reaches 227 s, so committed diagnostic output is ahead of the coefficient checkpoint, before incomplete payloads are injected into both groups.

| Output group | Initial time | Interval | Final scheduled time | Final record count |
| --- | ---: | ---: | ---: | ---: |
| `wave-vortex` | 127 s | 40 s | 367 s | 7 |
| `fields` | 137 s | 30 s | 347 s | 8 |

Two particles begin at `(12000,23000,-250)` m and `(53000,71000,-650)` m and track `u` and `eta` with linear interpolation. Their stored horizontal/vertical absolute tolerances are `3e-4`/`7e-5` m. The initial tracer is $\cos(2\pi x/L_x)\sin(2\pi y/L_y)(1+z/(2D))$, with tolerance `2e-7` and antialiasing enabled. QG uses horizontal particle and tracer advection at fixed depths; Boussinesq uses three-dimensional advection. Two moorings sample `u` and `eta` at `(0,0)` and `(25000,50000)` m. Particles and tracer are shared between both output groups, using the same canonical handles after restoration.

For each numeric array, relative error is its flattened Euclidean difference norm divided by the reference norm (bounded below by `realmin`). Snapshot error is the maximum over coefficient families, reconstructed fields, component energies, particle coordinates, tracked fields, and tracer. Output error is the maximum over the stored time-dependent arrays. The declared continuation bound is `1e-12`. Exact operator/configuration/time comparisons are separate. Particle displacement and relative tracer change establish that the controls exercise evolving observer state.

The four controls give zero initial-restoration, final-continuation, and saved-output residuals. Their observer evolution is nonzero:

| Model | Stratification | Combined particle displacement (m) | Relative tracer change |
| --- | --- | ---: | ---: |
| QG | Constant | `0.05228` | `2.579e-6` |
| QG | Exponential | `0.05134` | `3.112e-6` |
| Boussinesq | Constant | `0.76449` | `3.010e-5` |
| Boussinesq | Exponential | `0.75570` | `3.013e-5` |

Particle displacement is the Euclidean norm across both particles' integrated coordinates. The committed CSV retains full precision. Exact agreement is evidence for these aligned fixed steps and selected controls, not a universal bitwise-continuation promise.

## Reproduction and scope

Run the test class with the authoring dependencies on the MATLAB path. `TestFreeSurfaceOutputRestart.runStudy(outputFolder)` generates four constant/exponential QG/Boussinesq controls, interrupted checkpoints, reference snapshots, and `issue-352-output-restart.csv`. In a fresh MATLAB process, remove every InternalModes path and call `TestFreeSurfaceOutputRestart.verifyRestartWithoutProvider(outputFolder)`. It asserts solver unavailability, restores all four checkpoints, continues their observers and forcing, and compares snapshots and complete scheduled output with the uninterrupted controls. It advances checkpoint files; rerun the study to recreate them.

The WVM integration baseline is `28e169a0781b41f651f41627ceb57ae77e68b997`, with corrected InternalModes authoring provider `e7ea60dadc4e947769cda89f7c1116f22ffa404b` for initial construction. Checkpoint restoration consumes stored scientific operators without an eigensolve. No released package payload, manifest, or dependency changes are made.

These are short, aligned fixed-step controls and deterministic faults at the existing payload/commit boundary. They do not simulate every filesystem or hardware failure, qualify adaptive continuation, prove continuum accuracy, or cover all observer/forcing combinations. The actual staged seasonal/drag/damping QG restart handoff remains #353 and the last #352 gate. Released corrected-provider/install/full scientific CI remains #354; nonlinear Boussinesq qualification is separate.

## Verification

All 20 new cases and 69 affected regressions passed on MATLAB R2025b Update 4. The affected suites cover existing output persistence, NetCDF handle ownership, free-surface QG, forced Boussinesq evolution, resolution transfer, and model integration. After adding explicit observer-configuration assertions, all 20 new cases passed again and the four-case study reproduced the same results. All four checkpoints also restored and continued in a fresh process with both `IMSolverSpectral` and `InternalModesWKBSpectral` unavailable, yielding zero snapshot and output residuals.

Production Code Analyzer covered its 235-file inventory with zero blocking findings; existing style, performance and accepted false-positive advisories remain. The final new test file has no Code Analyzer findings. Documentation generation/check passed with 2358 files, 4819 routes, and zero generated drift. Only generated version history changes; authored website scope is unchanged. Whitespace and package-metadata checks pass. No task assets are missing.
