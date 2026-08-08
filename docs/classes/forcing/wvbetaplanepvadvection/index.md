---
layout: default
title: WVBetaPlanePVAdvection
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 6
---

#  WVBetaPlanePVAdvection

Advection of QGPV from beta


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVBetaPlanePVAdvection < <a href="/classes/forcing/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview

This applies $$\beta v_g$$ to the PV (A0) flux of a simulation.

### Usage

Assuming there is a WVTransform instance wvt, to add this forcing,

```matlab
wvt.addForcing(WVBetaPlanePVAdvection(wvt));
```

### Notes

This may not be justified for a hydrostatic or Boussinesq flow, but
it works.

A doubly-periodic domain with $$\beta$$ has a different $$f$$ at the
northern and southern boundary. This is fine for quasigeostrophic
dynamics, which only cares about the gradient of $$f$$, but is not
okay for internal waves. However, because the wave-vortex model
evolves coupled QG-wave equations in the spectral domain, we can add
this effect to only the PV part of the flow. I suspect this is
actually justifiable with the correct asymptotics. -- Jeffrey




## Topics
+ Create forcing and closures
  + [`WVBetaPlanePVAdvection`](/classes/forcing/wvbetaplanepvadvection/wvbetaplanepvadvection.html)


## Developer Topics
These items document internal implementation details and are not part of the primary public API.
+ Forcing internals
  + [`betaA0`](/classes/forcing/wvbetaplanepvadvection/betaa0.html)
+ Forcing persistence
  + [`classRequiredPropertyNames`](/classes/forcing/wvbetaplanepvadvection/classrequiredpropertynames.html)


---