---
layout: default
title: Class annotations
parent: Developers guide
mathjax: true
---

# Class annotations

WaveVortexModel uses the shared OceanKit annotated persistence convention described in the OceanKit developers guide:

- [`Annotated persistence`](/developers-guide/annotated-persistence-style-guide)

That shared guide defines the generic contract for `CAAnnotatedClass`, `writeToFile(...)`, source-specific `roleFromFile(...)` factories, `roleFromGroup(...)`, and the helper structure used to adapt persisted NetCDF state back into constructor arguments.

This page only records the WaveVortexModel-specific extensions and naming patterns built on top of that shared contract.

## Core annotation types in WaveVortexModel

WaveVortexModel uses class annotations to describe persisted properties, generated API documentation, and file-backed reconstruction.

The core annotation classes are:

- `CAPropertyAnnotation`
- `CADimensionProperty`
- `CANumericProperty`
- `CAFunctionProperty`
- `CAObjectProperty`
- `CAMethodAnnotation`

WaveVortexModel also defines `WVVariableAnnotation`, a specialized `CANumericProperty` subclass for variables exposed through `WVOperation` instances. These variables may be computed on demand rather than declared as stored MATLAB properties, but they still participate in the model's annotation and documentation system.

## WaveVortexModel constructor and reconstruction shape

A common WaveVortexModel pattern is:

- required positional arguments for the core scientific identity, such as `[Lxy, Nxy]` or `[Lxyz, Nxyz]`
- grouped name-value options for optional settings contributed by one or more subsystems

For example, a geometry or transform constructor may take the domain size and grid size positionally, then gather rotation, stratification, or transform-specific settings through name-value groups.

This is why WaveVortexModel commonly uses helper methods such as:

- `requiredPropertiesForGeometryFromGroup(...)`
- `requiredPropertiesForTransformFromGroup(...)`
- `requiredPropertiesForStratificationFromGroup(...)`

Those helpers adapt the persisted property set into the constructor shape expected by the specific WaveVortexModel class.

## WaveVortexModel naming pattern

WaveVortexModel keeps persisted-role helper names tied to the scientific role of the class:

- `propertyAnnotationsForGeometry()`
- `propertyAnnotationsForTransform()`
- `propertyAnnotationsForStratification()`
- `namesOfRequiredPropertiesForGeometry()`
- `namesOfRequiredPropertiesForTransform()`
- `namesOfRequiredPropertiesForStratification()`
- `geometryFromFile(...)`
- `transformFromGroup(...)`
- `waveVortexTransformFromFile(...)`

This is the WaveVortexModel realization of the shared OceanKit `propertyAnnotationsFor<Role>()`, `namesOfRequiredPropertiesFor<Role>()`, `requiredPropertiesFor<Role>FromGroup(...)`, `roleFromFile(...)`, and `roleFromGroup(...)` pattern.

## Composition and multiple inheritance

WaveVortexModel makes heavy use of composed persistence contracts. A subclass may:

- inherit persisted state from more than one parent role
- add new required persisted properties
- remove inherited properties that are fixed, derived, or no longer needed for reconstruction

The usual pattern is:

- combine parent required-property lists with `union(...)`
- remove intentionally nonrequired inherited values with `setdiff(...)`
- combine annotation arrays explicitly with `cat(...)`

Representative examples include:

- `WVGeometryDoublyPeriodic`
- `WVGeometryDoublyPeriodicBarotropic`
- `WVGeometryDoublyPeriodicStratified`
- `WVTransformBarotropicQG`

These classes are the best package-specific references when extending the WaveVortexModel persistence structure.

## Generic versus specialized reconstruction

The generic `CAAnnotatedClass.annotatedClassFromFile()` path is useful for simple annotated objects whose constructors can be called directly from the required-property set.

WaveVortexModel classes often need more structure than that. Geometries, stratifications, transforms, forcings, observing systems, and model output groups commonly reconstruct through specialized factories so they can:

- validate a richer set of persisted properties
- derive positional constructor inputs from stored dimensions
- combine options from multiple parent roles
- perform post-construction initialization from file-backed state

That specialization is intentional and should remain explicit in WaveVortexModel code.
