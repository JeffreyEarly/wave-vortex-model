---
layout: default
title: torusDist
parent: WVMooring
grand_parent: Classes
nav_order: 4
mathjax: true
---

#  torusDist

Shortest distance on a 2D torus


---

## Discussion
d = torusDist(x, y, Lx, Ly)
    x, y  : 1×2 vectors [x_coord, y_coord] of the two points
    Lx, Ly: domain lengths in x and y directions
 
    Returns the Euclidean distance between x and y
    accounting for periodic wrap in each direction.
