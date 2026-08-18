---
layout: default
title: Paired MATLAB and C++ implementations
parent: Developers guide
nav_order: 13
---

# Paired MATLAB and C++ implementations

MATLAB is the authoritative scientific implementation of WaveVortexModel. The portable C++ runtime is a narrower speed-and-portability product: a feature is portable only when its MATLAB behavior has a versioned data contract and a matching source-level C++ implementation.

The initial contract is `wave-vortex-portable-pair-v1`. Every paired observer or forcing identifies its MATLAB class, positive contract version, immutable parameters, named dynamic state blocks, field dependencies, outputs, and restart requirements. The C++ implementation reports `supported`, `unavailable`, `versionMismatch`, or `invalidContract` with an actionable reason.

## Runtime boundary

The runtime resolves type identifiers, versions, dependencies, layouts, and dispatch targets during descriptor construction and preflight. Unsupported or version-mismatched features fail before coefficient-sized allocation, state advancement, or output mutation.

Configuration descriptors are immutable after construction. Evolving particle, tracer, forcing, and coefficient values live in explicit integration-state blocks. Observer output is produced through the existing output plan, driver, and sinks; observers do not define or write NetCDF storage themselves.

The source-level extension surface deliberately provides no binary plug-in ABI and does not execute MATLAB subclass code in C++. It introduces no second persistence graph, per-element virtual dispatch, hot-loop string lookup, or state-sized façade copy.

## Add a paired implementation

1. Define or update the authoritative MATLAB behavior.
2. Return the versioned data-only contract from the feature's portable-contract hook. The base MATLAB class defaults to unsupported.
3. Add the matching typed C++ descriptor and source registration.
4. Declare immutable parameters, state blocks, dependencies, outputs, constraints, and restart data.
5. Add MATLAB/C++ compatibility fixtures and unavailable/version-mismatch tests.
6. Verify that the integrator, output driver, persistence sink, and central dispatch code require no feature-specific edits.
7. Run numerical, lifecycle, complete-integration runtime, and retained-memory checks.

The MATLAB hooks and concrete observer and forcing records are added by their focused implementation issues. The common contract defines their shared identity and capability behavior without imposing a generic mutable base class.

## Performance budget

Commit `5940f4e4e206fbfb9a6cb4760af2ba2347e3571f` is the pre-façade baseline. Complete integration runtime and retained memory may regress by no more than 3%, and a façade may introduce no state-sized copy or persistent state-sized storage. When valid implementations are within 3% in speed and memory, choose the simpler implementation.

The C++ API remains provisional until the milestone's final extension and performance proof. The final proof stabilizes source compatibility, not binary compatibility.
