---
layout: default
title: initializeOutputFile
parent: WVModelOutputFile
grand_parent: Model output
nav_order: 8
mathjax: true
---

#  initializeOutputFile

tells the output groups to initialize themselves in the NetCDF file


---

## Discussion

  One noteworthy piece of logic handle by this function: we
  want all files to able to re-initialize the model, so we make
  sure that the NetCDFFile has all the required properties of
  the transform. However, we are writing time series data, so
  we need to exclude `t`. Additionally, if we happen to also be
  writing the wave-vortex coefficients, we can neglect writing
  those to file.

  Initialization is transactional. If any group or observing
  system fails, the new file is closed and deleted and every
  storage object returns to its uninitialized state.
