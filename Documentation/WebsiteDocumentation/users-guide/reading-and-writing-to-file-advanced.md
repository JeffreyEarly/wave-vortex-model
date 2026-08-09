---
layout: default
title: Reading and writing files: advanced topics
parent: User guide
mathjax: true
nav_order: 12
has_toc: true
---

# Reading and writing files: advanced topics

The `WVModel` supports multiple output files, groups with different output intervals, and groups that start and stop at different model times.

These features let one simulation observe the fluid in several ways and at several intervals. For example, moorings may sample velocity frequently while a sequence of drifter experiments deploys and retrieves particles in bounded five-day windows.

There are three classes that work together to write to file:

- `WVObservingSystem` describes a way of observing the fluid and may or may not require integration.
- `WVModelOutputFile` represents one file on disk and owns one or more output groups.
- `WVModelOutputGroup` writes one or more observing systems at its scheduled output times.

Any `WVObservingSystem` that requires integration is also held by the model. The same integrated observer handle may be written by multiple groups, including groups with different sampling intervals.


## WVObservingSystem

Observing systems include wave–vortex coefficients, Eulerian fields, Lagrangian particles, tracers, moorings, and satellite along-track data.

Subclasses of `WVObservingSystem` describe whether the observing system needs to be integrated in time and how it writes to a `WVModelOutputGroup`. `WVCoefficients` participates in model integration while coefficient storage is provided by the Eulerian field observer. `WVMooring` writes sampled fields without adding integrated state. `WVLagrangianParticles` and `WVTracer` both add integrated state and write their latest state to output.

## WVModelOutputFile

After creating a `WVModel`, you may add one or more `WVModelOutputFile` instances. The model combines their requested output times so coincident times are integrated once and delivered to every file and group that requested them.

The convenience method `createNetCDFFileForModelOutput` creates one file and one evenly spaced group containing the model's ordinary observing systems. For explicit control, construct the layers separately:

```matlab
outputFile = model.addNewOutputFile('experiment.nc');
hourly = outputFile.addNewEvenlySpacedOutputGroup( ...
    'hourly',initialTime=model.t,finalTime=model.t+86400,outputInterval=3600);
hourly.addObservingSystem(model.eulerianObservingSystem);
```

The file remains an in-memory configuration until its first output initialization. This makes it possible to assemble groups and observing systems before any partial file exists on disk.

Each file is an independent restart boundary. `WVModel.modelFromFile(path)` restores the supplied file and all of its groups; it does not reconstruct other files that the original model may also have written. A restart-capable file must contain exactly one group with the complete coefficient stream (`Ap`, `Am`, and `A0` for wave-bearing transforms, or `A0` for QG transforms). Other groups may store fields and observing systems without duplicating that complete coefficient stream.

The file records whether the model used linear or nonlinear dynamics. Files written before that metadata was introduced retain the historical nonlinear restart default. Integrator objects are runtime configuration and must be configured again after restoration.

## WVModelOutputGroup

The most useful `WVModelOutputGroup` subclass is `WVModelOutputGroupEvenlySpaced`, which writes on the lattice `initialTime + k*outputInterval` within the inclusive initial and final bounds. Repeated and segmented integrations remain anchored to that original lattice, and an already written time is not written again.

When an integrated observer is shared by multiple groups, restoration reconnects those groups to one canonical observer handle. At least one of the groups must contain that observer at the coefficient restart time; otherwise the file does not contain a consistent restart state.

Output initialization is transactional. If a group cannot initialize, WaveVortexModel closes and removes the newly created partial file and resets the output objects so the operation can be retried. If a later time-step write fails, all model-owned file handles are closed and the existing file is preserved for inspection. NetCDF does not provide transactional rollback of a partially written time record, so such a file should not be treated as a valid restart until inspected.
