---
layout: default
title: WVFourierStorageLayout
has_children: false
has_toc: false
mathjax: true
parent: Developer internals
grand_parent: Class documentation
nav_order: 1
---

#  WVFourierStorageLayout

Describe how horizontal Fourier storage maps to the WaveVortex grid.


---

## Overview

WVFourierStorageLayout is developer infrastructure shared by horizontal
transform backends. It describes indexing only: the class does not
execute an FFT, normalize coefficients, own a backend buffer, or select
a transform backend. Model code continues to expose coefficients on the
canonical WV grid with shape [Nbatch,Nkl].

Four representations appear in this contract:

* Spatial arrays have shape [Nx,Ny,Nbatch].
* Fourier storage has its natural backend shape. Full-complex storage is
  [Nx,Ny,Nbatch], half-x storage is [floor(Nx/2)+1,Ny,Nbatch], and
  half-y storage is [Nx,floor(Ny/2)+1,Nbatch].
* A Fourier row view reshapes the first two storage dimensions to
  [nFourierStorageRows,Nbatch]. No data is reordered by this reshape.
* The WV grid has shape [Nbatch,Nkl] and uses the ordering defined by
  WVGeometryDoublyPeriodic.

For real spatial fields, Fourier coefficients obey

$$\hat u(-k,-l)=\overline{\hat u(k,l)}.$$

A full-complex layout stores both sides of this relation. A
hermitian-half layout stores one side and recovers WV modes with a
negative compressed-direction mode by conjugating the stored positive
mode. On zero and even-grid Nyquist boundaries, the other horizontal
mode may still require explicit Hermitian completion. Modes that are
their own conjugates are made exactly real during insertion.

Mapping indices are one-based uint64 column vectors. They never contain
Nbatch- or Nz-replicated offsets. A performance-sensitive backend may
consume these properties directly, instead of calling the convenience
mapping methods, when doing so preserves a measured MATLAB indexing and
assignment expression.

This visible, sealed class is intended for WaveVortex backend developers.
It is not an end-user modeling API and is not a supported subclassing
point.


## Topics


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Describe Fourier storage
  + [`Nkl`](/classes/developer-internals/wvfourierstoragelayout/nkl.html) Number of horizontal coefficients in the canonical WV grid.
  + [`WVFourierStorageLayout`](/classes/developer-internals/wvfourierstoragelayout/wvfourierstoragelayout.html) Create a Fourier-storage mapping for a doubly periodic geometry.
  + [`compressedDimension`](/classes/developer-internals/wvfourierstoragelayout/compresseddimension.html) Compressed horizontal dimension for Hermitian-half storage.
  + [`fourierStorageSize`](/classes/developer-internals/wvfourierstoragelayout/fourierstoragesize.html) Natural two-dimensional Fourier storage shape.
  + [`fourierStorageType`](/classes/developer-internals/wvfourierstoragelayout/fourierstoragetype.html) Fourier storage representation, "full-complex" or "hermitian-half".
  + [`horizontalGridSize`](/classes/developer-internals/wvfourierstoragelayout/horizontalgridsize.html) Physical horizontal grid shape [Nx,Ny].
  + [`mappingMethod`](/classes/developer-internals/wvfourierstoragelayout/mappingmethod.html) Measured MATLAB mapping implementation used by the layout.
  + [`nFourierStorageRows`](/classes/developer-internals/wvfourierstoragelayout/nfourierstoragerows.html) Number of rows in the two-dimensional Fourier row view.
+ Manage Fourier storage
  + [`allocateFourierStorage`](/classes/developer-internals/wvfourierstoragelayout/allocatefourierstorage.html) Allocate a zeroed complex Fourier row view.
  + [`reshapeFourierRowsToStorage`](/classes/developer-internals/wvfourierstoragelayout/reshapefourierrowstostorage.html) Reshape a row view to natural Fourier-storage dimensions.
  + [`reshapeFourierStorageToRows`](/classes/developer-internals/wvfourierstoragelayout/reshapefourierstoragetorows.html) Reshape natural Fourier storage to its two-dimensional row view.
+ Map Fourier storage and WV grid
  + [`conjugatedWVIndices`](/classes/developer-internals/wvfourierstoragelayout/conjugatedwvindices.html) WV-grid indices recovered by conjugating stored Fourier rows.
  + [`directWVIndices`](/classes/developer-internals/wvfourierstoragelayout/directwvindices.html) WV-grid indices supplied directly by stored Fourier rows.
  + [`fourierRowsForConjugatedWVIndices`](/classes/developer-internals/wvfourierstoragelayout/fourierrowsforconjugatedwvindices.html) Fourier rows conjugated while recovering the corresponding WV modes.
  + [`fourierRowsForDirectWVIndices`](/classes/developer-internals/wvfourierstoragelayout/fourierrowsfordirectwvindices.html) Fourier rows copied directly to the corresponding WV indices.
  + [`hermitianCompletionRows`](/classes/developer-internals/wvfourierstoragelayout/hermitiancompletionrows.html) Destination rows filled from Hermitian partners before an inverse FFT.
  + [`hermitianSourceRows`](/classes/developer-internals/wvfourierstoragelayout/hermitiansourcerows.html) Stored rows whose conjugates fill hermitianCompletionRows.
  + [`hermitianSourceWVIndices`](/classes/developer-internals/wvfourierstoragelayout/hermitiansourcewvindices.html) WV-grid indices corresponding to hermitianSourceRows.
  + [`selfConjugateFourierRows`](/classes/developer-internals/wvfourierstoragelayout/selfconjugatefourierrows.html) Fourier rows representing modes equal to their own Hermitian partner.
  + [`transformFromFourierStorageToWVGrid`](/classes/developer-internals/wvfourierstoragelayout/transformfromfourierstoragetowvgrid.html) Map a Fourier row view to canonical WV-grid ordering.
  + [`transformFromWVGridToFourierStorage`](/classes/developer-internals/wvfourierstoragelayout/transformfromwvgridtofourierstorage.html) Insert WV-grid coefficients into caller-owned Fourier storage.
+ Legacy compatibility
  + [`expandedLegacyMappings`](/classes/developer-internals/wvfourierstoragelayout/expandedlegacymappings.html) Materialize the vertically expanded legacy full-storage mappings.
+ Inspect Fourier storage
  + [`mappingMemoryBytes`](/classes/developer-internals/wvfourierstoragelayout/mappingmemorybytes.html) Exact bytes occupied by all one-based uint64 mapping arrays.
  + [`mappingMemoryUsage`](/classes/developer-internals/wvfourierstoragelayout/mappingmemoryusage.html) Return exact memory usage for each mapping array.


---