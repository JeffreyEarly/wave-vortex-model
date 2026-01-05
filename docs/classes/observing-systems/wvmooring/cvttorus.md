---
layout: default
title: cvtTorus
parent: WVMooring
grand_parent: Classes
nav_order: 3
mathjax: true
---

#  cvtTorus

Centroidal Voronoi tessellation on a 2D torus


---

## Discussion

    [x,y] = cvtTorus(N, Lx, Ly)
    [x,y] = cvtTorus(N, Lx, Ly, nIter)
 
    N      – number of generators
    Lx,Ly  – domain size (periodic in both x and y)
    nIter  – number of Lloyd iterations (default: 20)
 
    x,y    – N×1 vectors of final seed positions in [0,Lx)×[0,Ly)
 
  Example:
    [x,y] = cvtTorus(100, 4, 2, 30);
    scatter(x,y,20,'filled'); axis equal; xlim([0 4]); ylim([0 2]);
