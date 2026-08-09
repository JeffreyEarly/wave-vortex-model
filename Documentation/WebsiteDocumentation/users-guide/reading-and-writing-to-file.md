---
layout: default
title: Reading and writing files
parent: User guide
mathjax: true
nav_order: 10
has_toc: true
---

# Reading and writing files

WaveVortexModel uses NetCDF files for transform persistence, model output, and restart. A transform file stores the geometry and wave–vortex state needed to reconstruct a `WVTransform`. A restart-capable model file additionally stores forcing, observing systems, output groups, and the latest integrated state.

## Save and restore a transform

Write a transform and close the returned file handle:

```matlab
wvt = WVTransformConstantStratification( ...
    [50e3 50e3 1300],[32 32 17],N0=5.2e-3,latitude=45);
wvt.initWithRandomFlow();

ncfile = wvt.writeToFile('transform.nc');
ncfile.close();
```

Restore the transform through the static factory. The one-output form closes its read handle before returning:

```matlab
wvtRestored = WVTransform.waveVortexTransformFromFile('transform.nc');
```

Horizontal backend selection is runtime-only and is not written into the NetCDF file. Restoring a constant-stratification transform therefore uses builtin transforms by default, regardless of the backend used when the file was written. Request the optional backend again when appropriate for the current machine:

```matlab
wvtRestored = WVTransform.waveVortexTransformFromFile( ...
    'transform.nc',fastTransform="fftw");
```

If FFTWTransforms is unavailable or fails validation, restoration continues with builtin transforms after one warning. Other transform families reject an FFTW restoration request.

Pass additional registered variable names to `writeToFile` when physical fields or diagnostics should be stored alongside the reconstructable state:

```matlab
ncfile = wvt.writeToFile('transform-with-fields.nc','u','v','rho');
ncfile.close();
```

## Read a transform time series

Model output may contain many time records. Creating the transform once and updating its coefficients is less expensive than reconstructing its geometry for every record.

Request the second output to retain a caller-owned, read-only `NetCDFFile`, and close it explicitly:

```matlab
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile('model-output.nc');
cleanup = onCleanup(@()ncfile.close());
t = ncfile.readVariables("wave-vortex/t");

for iTime = 1:numel(t)
    wvt.initFromNetCDFFile(ncfile,iTime=iTime);
    energy(iTime) = wvt.totalEnergy;
end
```

Use `shouldReadOnly=false` only when the returned file genuinely needs writable access.

## Write model output

For a model with one ordinary output schedule, create the file through the convenience method and integrate:

```matlab
model = WVModel(wvt,shouldUseLinearDynamics=true);
outputFile = model.createNetCDFFileForModelOutput( ...
    'model-output.nc',outputInterval=600);
model.integrateToTime(3600);
outputFile.closeNetCDFFile();
```

The physical file is created lazily when output is first initialized. Before integration you may add Eulerian variables, particles, tracers, or other observing systems to the model's output configuration.

## Restore and continue a model

Restore a model from one restart-capable file:

```matlab
model = WVModel.modelFromFile('model-output.nc');
model.setupIntegrator();
model.integrateToTime(model.t + 3600);
model.outputFiles(1).closeNetCDFFile();
```

Runtime integrator objects are not persisted, so configure the desired fixed or adaptive settings after restoration. `modelFromFile` restores only the supplied file's output graph; other files written by the original run are independent restart boundaries.

For multiple schedules, bounded output windows, shared observing systems, and handle ownership, continue with [Reading and writing files: advanced topics](/users-guide/reading-and-writing-to-file-advanced.html). For metadata conventions, see [NetCDF conventions](/users-guide/netcdf-output.html).
