---
layout: default
title: Creating new state variables
parent: User guide
mathjax: true
nav_order: 14
---

# Creating new state variables

Custom `WVOperation` objects add derived variables to a transform. Once registered, those variables participate in ordinary field access, caching, NetCDF output, and particle tracking.

## Define and register an operation

A `WVVariableAnnotation` describes the output's name, dimensions, units, and meaning. A `WVOperation` associates one or more annotations with the calculation that produces them.

For example, register the vertical component of relative vorticity:

```matlab
annotation = WVVariableAnnotation('zeta_z',{'x','y','z'},'s-1','vertical component of relative vorticity');
computeVorticity = @(wvt) wvt.diffX(wvt.v) - wvt.diffY(wvt.u);
wvt.addOperation(WVOperation('zeta_z',annotation,computeVorticity));
```

The calculation is lazy: registration records how to compute `zeta_z`, but the operation does not run until the value is requested.

```matlab
zeta_z = wvt.zeta_z;
```

Operations compose, so another operation may use `wvt.zeta_z` as an input. More involved calculations can subclass `WVOperation` and override `compute`.

## Control caching

Computed variables are cached. Set the operation's dependency metadata before registration so the transform knows when to invalidate its outputs:

- `isVariableWithLinearTimeStep=true` invalidates the output when transform time changes.
- `isDependentOnApAmA0=true` invalidates the output when `Ap`, `Am`, or `A0` changes.

Outputs without the relevant dependency remain cached. A multiple-output operation computes and caches its annotations together in annotation order.

Operation names and output-variable names must be unique. Registration rejects conflicts by default. Pass `shouldOverwriteExisting=true` to replace the complete conflicting operation intentionally.

## Write and track the variable

The annotation supplies the metadata needed to write the variable with a transform:

```matlab
ncfile = wvt.writeToFile('state.nc','zeta_z');
ncfile.close();
```

For model output, add the variable to the Eulerian field selection:

```matlab
model.addNetCDFOutputVariables('zeta_z');
```

Variables with spatial dimensions $$(x,y)$$ or $$(x,y,z)$$ can also be sampled along particle trajectories. Pass their names to `addParticles`, `setFloatPositions`, or `setDrifterPositions`.

For details about annotations, multiple outputs, replacement, and cache invalidation, see [`WVOperation`](/classes/operations-and-annotations/wvoperation/) and [`WVVariableAnnotation`](/classes/operations-and-annotations/wvvariableannotation/).
