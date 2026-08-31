---
layout: default
title: writeTimeStepToNetCDFFile
parent: WVModelOutputGroup
grand_parent: Model output
nav_order: 21
mathjax: true
---

#  writeTimeStepToNetCDFFile

writes data at time t


---

## Discussion

This is called by the `WVModelOutputFile` when the model
reaches time `t`. The new time is written to file, adn the
observing systems are also told to write to file.
