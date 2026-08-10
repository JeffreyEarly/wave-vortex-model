---
layout: default
title: t
parent: WVTransformHydrostatic
grand_parent: Transforms
nav_order: 251
mathjax: true
---

#  t

Current transform time in seconds.


---

## Description
Real valued property with no dimensions and units of $$s$$.

## Discussion

The time `t` is the time of observation. A `WVTransform` instance represents the state of the ocean at time `t`.

Time is considered a dimension, but as far as any `WVTransform` instance is concerned, it is always only one point.
