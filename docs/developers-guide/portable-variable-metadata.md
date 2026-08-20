---
layout: default
title: Portable variable metadata
parent: Developers guide
nav_order: 14
---

# Portable variable metadata

WaveVortexModel maintains one shared catalog for the canonical wave-vortex coefficients and the fields currently supported by the portable C++ runtime. MATLAB [`WVVariableAnnotation`](/classes/operations-and-annotations/wvvariableannotation/) instances are authoritative for scientific names, dimensions, units, descriptions, complexity, time dependence, cache dependence, and static NetCDF attributes.

The authoring tool `tools/generatePortableVariableCatalog.m` combines those annotations with `PortableRuntime/contracts/portable-variable-supplement-v1.json`. The supplement contains only portable implementation facts that MATLAB annotations do not express: stable ordinals, natural storage rank, supported sampling modes, primitive field dependencies, and the small moving-field channel mapping.

Generation produces two committed files:

- `PortableRuntime/contracts/portable-variable-catalog-v1.json` is the machine-readable MATLAB/C++ compatibility record.
- `PortableRuntime/include/WaveVortexRuntime/generated/WVPortableVariableCatalog.hpp` is the constexpr C++ representation used by the runtime.

Both files are deterministic products of the same input. Regenerate them from any working directory with:

```matlab
generatePortableVariableCatalog(repositoryRoot="/path/to/wave-vortex-model")
```

## Runtime boundary

Output and field requests use names only while an immutable plan is constructed. Construction resolves each name to a stable `WVPortableVariable` ordinal and its dependency and sampling masks. Numerical evaluation uses those ordinals and explicit exhaustive switches; it performs no field-name comparisons, runtime reflection, or function-pointer dispatch inside element loops.

The catalog contains `Ap`, `Am`, and `A0` plus the twenty portable fields. Observer-owned coordinates, tracer values, and future observer-specific outputs remain in their typed observer contracts rather than being added to this shared field catalog.

Adding a portable field therefore requires a MATLAB annotation first, one deliberate supplement entry, regenerated outputs, an explicit C++ numerical case, and MATLAB/C++ parity tests. Hand-editing either generated file is unsupported.
