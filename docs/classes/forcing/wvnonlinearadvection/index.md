---
layout: default
title: WVNonlinearAdvection
has_children: false
has_toc: false
mathjax: true
parent: Forcing
grand_parent: Class documentation
nav_order: 2
---

#  WVNonlinearAdvection

The advective flux, $$\mathbf{u}\cdot \nabla \mathbf{u}$$ and $$\mathbf{u}\cdot \nabla \eta$$


---

## Declaration

<div class="language-matlab highlighter-rouge"><div class="highlight"><pre class="highlight"><code>WVNonlinearAdvection < <a href="/classes/wvforcing/" title="WVForcing">WVForcing</a></code></pre></div></div>

## Overview
 
The nonlinear advection forcing adds the nonlinear terms to the momentum and thermodynamic equation.
 
The nonlinear terms are all computed in the spatial domain.
 
For nonhydrostatic transforms,
 
$$
\begin{align}
\mathcal{S}_u &= - \left( u \partial_x u + v \partial_y u + w \partial_z u \right) \\
\mathcal{S}_v &= - \left( u \partial_x v + v \partial_y v + w \partial_z v \right) \\
\mathcal{S}_w &= - \left(  u \partial_x w + v \partial_y w + w \partial_z w \right) \\
\mathcal{S}_\eta &= - \left( u \partial_x \eta + v \partial_y \eta  + w \left(\partial_z \eta +\eta \partial_z \ln N^2 \right)
\end{align}
$$
 
for hydrostatic transforms,
 
$$
\begin{align}
\mathcal{S}_u &= - \left( u \partial_x u + v \partial_y u + w \partial_z u \right) \\
\mathcal{S}_v &= - \left( u \partial_x v + v \partial_y v + w \partial_z v \right) \\
\mathcal{S}_\eta &= - \left( u \partial_x \eta + v \partial_y \eta  + w \left(\partial_z \eta +\eta \partial_z \ln N^2 \right)
\end{align}
$$
 
and for quasigeostrophic transforms,
 
$$
\begin{align}
\mathcal{S}_\textrm{qgpv} &= - \left( u \partial_x q + v \partial_y q \right)
\end{align}
$$
 
where $$q$$ is the qgpv.
 
### Notes
 
This is the only forcing added to the transforms by default. You must explicitly remove it if you want to consider linear flows.
 
     



## Topics
+ Initialization
  + [`WVNonlinearAdvection`](/classes/forcing/wvnonlinearadvection/wvnonlinearadvection.html) initialize the WVNonlinearAdvection nonlinear flux
+ Properties
  + [`dLnN2`](/classes/forcing/wvnonlinearadvection/dlnn2.html) variable stratification factor
+ CAAnnotatedClass requirement
  + [`classRequiredPropertyNames`](/classes/forcing/wvnonlinearadvection/classrequiredpropertynames.html) Returns the required property names for the class


---