---
layout: default
title: NetCDF conventions
parent: User guide
nav_order: 18
mathjax: true
---

# NetCDF conventions

WaveVortexModel writes named dimensions, variables, units, descriptive attributes, transform metadata, and history information through its annotated persistence system. This metadata makes model files self-describing and provides the information required to reconstruct supported transforms, forcing, observing systems, and restart state.

## Scientific variables

Each registered variable has a `WVVariableAnnotation` that defines its name, dimensions, units, and description. Canonical coefficient families use `WVCoefficientAnnotation`, which additionally records auxiliary coordinates, canonical basis, persistence role, numeric domain, and empty-family policy. The output system uses those annotations when creating NetCDF dimensions and variables. Eulerian fields, coefficients, particles, tracers, and moorings add the dimensions and metadata needed for their own stored state.

## Committed time records

Each output group uses an unlimited `t` coordinate with a `NaN` fill value. WaveVortexModel writes and synchronizes all payload variables before writing the corresponding finite time, then synchronizes the committed coordinate. Only the contiguous finite prefix of `t` is a valid output or restart sequence. A fill-valued hole marks the first uncommitted record, and a later finite time is rejected as a corrupted commit sequence. Files created before this convention retain their legacy raw-time behavior.

The package uses established names and units where they are defined, but the metadata should still be reviewed before a file is distributed or deposited in an archive.

## CF conventions

The [Climate and Forecast metadata conventions](https://cfconventions.org) provide standard names, coordinate rules, and structural guidance for interoperable geoscience data. WaveVortexModel supplies useful CF-oriented metadata, but it does not claim that every possible output configuration is automatically a complete CF-compliant data product.

Users preparing a distributed dataset should verify coordinate attributes, standard names, units, missing-value treatment, and any project-specific requirements with an appropriate CF checker.

## Discovery metadata

The [Attribute Convention for Data Discovery](https://wiki.esipfed.org/Attribute_Convention_for_Data_Discovery_1-3) describes global attributes used by repositories and search systems. Dataset title, summary, creator, institution, spatial and temporal coverage, license, and persistent identifiers depend on the scientific project and are therefore the responsibility of the file producer.

Add project-specific global attributes as part of the output workflow and validate the finished file before publication. WaveVortexModel's automatically recorded class, package version, creation date, references, and history complement this dataset-level metadata but do not replace it.

## Related guidance

- [Reading and writing files](/users-guide/reading-and-writing-to-file.html) covers transform persistence, ordinary model output, and restart.
- [Reading and writing files: advanced topics](/users-guide/reading-and-writing-to-file-advanced.html) covers multiple files, schedules, observing systems, restoration, and failure behavior.
- [Creating new state variables](/users-guide/creating-new-state-variables.html) explains how annotations supply names, dimensions, units, and descriptions for custom output variables.
