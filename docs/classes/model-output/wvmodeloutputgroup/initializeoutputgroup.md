---
layout: default
title: initializeOutputGroup
parent: WVModelOutputGroup
grand_parent: Model output
nav_order: 10
mathjax: true
---

#  initializeOutputGroup

initializes a new output group in the NetCDF file


---

## Discussion

This will only be called only once. This creates a new group,
adds the required properties, creates a time dimension, then
tells the observing systems to also initialize their storage.
