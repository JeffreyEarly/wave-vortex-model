# Optional diffusion research

This authoring experiment belongs to [#389](https://github.com/JeffreyEarly/wave-vortex-model/issues/389). It is separate from the adiabatic APV/wave model and is outside core test discovery and the released package payload. It introduces no runtime dependency or model coordinate change.

With the corrected authoring dependencies available, explicitly run:

```matlab
addpath("Documentation/Experiments/Diffusion")
results = runtests("Documentation/Experiments/Diffusion/TestCompleteThermalModes.m");
assertSuccess(results)
```

The class also supplies `runCompleteThermalStudy` and `compareCompleteThermalStudies`. Its private physical-depth reference and observation helpers are self-contained research copies; core tests do not call into this experiment. Scientific results, tolerances, refinement controls and full reproduction are in [the validation report](../../Validation/Issue353CompleteThermalModes.md).

The primary WVM remains entirely in adiabatic modes. Thermal-mode results do not set its milestone completion criteria. Preserve the strict-source/flux distinction, both endpoint settings and saved-run provenance when extending this experiment.
