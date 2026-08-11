---
layout: default
title: Installation
nav_order: 2
description: Install WaveVortexModel and its dependencies
permalink: /installation
---

# Installation

WaveVortexModel requires MATLAB R2025b or newer. MPM installs the declared OceanKit dependencies automatically.

## Install from OceanKit

Clone or download the [OceanKit repository](https://github.com/JeffreyEarly/OceanKit), then register its local folder with MPM:

```matlab
mpmAddRepository("OceanKit","local/path/to/OceanKit")
```

Install WaveVortexModel and its dependencies:

```matlab
mpminstall("WaveVortexModel")
```

The installed package can be inspected with:

```matlab
mpmlist("WaveVortexModel")
```

See [OceanKit installation](https://jeffreyearly.github.io/OceanKit/installation/) for repository management, updates, and removal.

## Install an authoring checkout

Ordinary users should install the released OceanKit package. Clone the authoring repository only when developing WaveVortexModel or rebuilding its documentation:

```text
git clone https://github.com/JeffreyEarly/wave-vortex-model.git
```

Install that checkout with authoring files enabled:

```matlab
mpminstall("local/path/to/wave-vortex-model",Authoring=true)
```

Runtime dependencies still come from the registered OceanKit repository. Documentation generation additionally requires the authoring-only package `ClassDocumentation@1.3.2`; it is not a WaveVortexModel runtime dependency.
