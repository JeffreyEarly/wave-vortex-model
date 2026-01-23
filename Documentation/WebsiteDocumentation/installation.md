---
layout: default
title: Installation
nav_order: 2
description: Installation instructions"
permalink: /installation
---

## Installation

The recommended way to install the model is with [OceanKit](https://github.com/JeffreyEarly/OceanKit).

Clone the OceanKit repository
```
git clone https://github.com/JeffreyEarly/OceanKit.git
```
from the command-line (or download [the zip](https://github.com/JeffreyEarly/OceanKit/archive/refs/heads/main.zip)). Within Matlab, add this folder as an MPM repository,
```matlab
mpmAddRepository("OceanKit","path/to/folder/OceanKit")
```
and then
```matlab
mpminstall("WaveVortexModel")
```
will install the [WaveVortexModel](https://wavevortexmodel.org) and its dependencies.

## Advanced

The WaveVortexModel is highly extensible and rarely needs to be modified directly. However, if you do need to make change to the code you will need to install the model with *Authoring* enabled.

You should still download OceanKit and add the mpm repo as above. However, instead of installing model from the OceanKit, you will install it directly from its github repo.

Clone the WaveVortexModel repository
```
git clone https://github.com/JeffreyEarly/wave-vortex-model.git
```
and install with
```matlab
mpminstall("path/to/folder/wave-vortex-model", Authoring=true); 
```
This will still install the dependencies from the mpm repo (and those will not be editable).
