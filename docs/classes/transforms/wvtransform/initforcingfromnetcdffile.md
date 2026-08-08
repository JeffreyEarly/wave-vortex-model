---
layout: default
title: initForcingFromNetCDFFile
parent: WVTransform
grand_parent: Transforms
nav_order: 44
mathjax: true
---

#  initForcingFromNetCDFFile

forcingGroupName = join( [string(class(self)),"forcing"],"-");

> Developer documentation: this item describes internal implementation details.


---

## Discussion
group = ncfile.groupWithName(class(self));
