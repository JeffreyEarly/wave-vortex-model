# Assembled Boussinesq RHS resolution study

This study evaluates the complete assembled Boussinesq source on independently refined horizontal and vertical grids while holding the modal state and output projection fixed. It separates sampled-source error, fixed-basis projection error, endpoint terms, and reference stability.

`runBoussinesqResolutionStudy` creates the refinement tables, `runRationalGeometryControls` checks a manufactured rational-geometry case, and `plotBoussinesqResolution` builds the figure from those tables.

Outputs default to `fullfile(tempdir,"wave-vortex-model-studies","nonlinear-resolution-study")`. Generated tables and figures remain outside the repository. The bounded assessment and its limitations are tracked on [issue #450](https://github.com/JeffreyEarly/wave-vortex-model/issues/450).
