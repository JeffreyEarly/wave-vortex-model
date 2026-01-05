---
layout: default
title: writeTimeStepToOutputFile
parent: WVModelOutputFile
grand_parent: Classes
nav_order: 20
mathjax: true
---

#  writeTimeStepToOutputFile

tells the output groups to write data at time t


---

## Discussion

  This will only be called if the
  `outputTimesForIntegrationPeriod` previously returned this
  time `t`. Thus, the actual NetCDF file will be created if
  it does not yet exist, and then the output groups can write
  to file.
 
  
