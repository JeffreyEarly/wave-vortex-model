---
layout: default
title: indicesFromWVGridToDFTGrid
parent: WVTransformConstantStratification
grand_parent: Classes
nav_order: 111
mathjax: true
---

#  indicesFromWVGridToDFTGrid

indices to convert from WV to DFT grid


---

## Declaration
```matlab
 [dftPrimaryIndices, wvPrimaryIndices, dftConjugateIndices, wvConjugateIndices] = indicesFromWVGridToDFTGrid(Nz,options)
```
## Parameters
+ `Nz`  length of the outer dimension (default 1)
+ `isHalfComplex`  (optional) set whether the DFT grid excludes modes iL>Ny/2 [0 1] (default 1)

## Returns
+ `dftPrimaryIndices`  indices into a DFT matrix, matches wvPrimaryIndices
+ `wvPrimaryIndices`  indices into a WV matrix, matches dftPrimaryIndices
+ `dftConjugateIndices`  indices into a DFT matrix, matches wvConjugateIndices
+ `wvConjugateIndices`  indices into a WV matrix, matches dftConjugateIndices

## Discussion

  This function returns indices to quickly reformat the memory
  layout of a data structure on a WV grid to one on a DFT grid.
 
  This function is should generally be faster than the function
  transformFromWVGridToDFTGrid if you cache these indices.
 
                
