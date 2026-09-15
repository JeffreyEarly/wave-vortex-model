# Surface-crossing buoyancy projection study

This authoring study compares direct endpoint quadrature with a split quadrature that resolves the reference-surface crossing. It holds the modal state fixed while refining vertical samples, crossing-layer order, and horizontal evaluation.

`runCrossingProjectionStudy` produces convergence and independent reference controls. `benchmarkCrossingProjection` compares complete callback cost at matched accuracy. `plotCrossingProjection` reads those external tables and creates the diagnostic figure.

The drivers write by default beneath `fullfile(tempdir,"wave-vortex-model-studies","crossing-projection-study")`. Use a fresh temporary directory when changing the case definition, and keep generated data and figures outside the repository. The study protocol and production decision are discussed on [issue #499](https://github.com/JeffreyEarly/wave-vortex-model/issues/499).
