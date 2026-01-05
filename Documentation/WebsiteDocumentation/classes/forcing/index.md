---
layout: default
title: Forcing
parent: Class documentation
mathjax: true
nav_order: 10
has_children: true
permalink: /classes/forcing
---

#  Forcing

Forcing operations are used to apply forcing to the model. See the [users guide on adding forcing](/users-guide/adding-forcing.html).

### Notes
 - All forcing operations are a subclass of [WVForcing](/classes/forcing/wvforcing/).
 - The [`WVNonlinearAdvection`](/classes/forcing/wvnonlinearadvection/) is the only forcing that is added by default when you initialize a new transform.
 - The [*closure*](/classes/forcing/closures) schemes are grouped separately from other forcing mechanisms below for convenience.
 - All transforms have anti-aliasing enabled by default at the transform level (which can act as a partial closure scheme for some dynamics), but you can also explicitly add [antialiasing as a forcing](/classes/forcing/closures/wvantialiasing/)

