# Explicit count-map quadratic assessment

## Performance contract established before expansion

The initial Apple Silicon / MATLAB R2025b timing trial used the unchanged beta.4 advisory on `cal-constant-17` and `cal-exponential-17`: eight candidate waves, independent three-mode APV/MDA/inertial families, both boundaries, an 8 by 8 horizontal grid and 17 vertical points. The [baseline measurements](baseline-costs.csv) record approximately 2.3–3.2 seconds of mode/reference preparation, 4–5 seconds for the first advisory, and 3.5–4.3 seconds for another common-prefix request. Each request repeats 79,968 reserved products and retains about 9.7 MB of evidence.

Before expanding the inventory, the implementation targets are: at most 10 seconds for complete preparation on these calibration cases, at most 0.25 seconds for a repeated count-map assessment, and at most 64 MiB of retained evidence. The bounded companion example targets at most 60 seconds of preparation, 0.5 seconds per repeat assessment, and 128 MiB retained evidence. These are local benchmark targets, not cross-hardware API guarantees. A default 500,000-product reservation and explicit working-memory estimate protect larger preparations; exceeding a budget fails before source products are evaluated.

The intended reuse boundary is an explicit evidence snapshot: preparation computes qualified product errors for a declared candidate band and interaction inventory; later assessments receive that snapshot alone and select the actual input/output prefixes. A changed grid, basis, reference, normalization or inventory requires a new preparation. There is no keyed global cache, retained provider object in WVM state, or implicit assessment during ordinary construction/restart.

The figure and final verification/cost ledger will be added with the implementation. APV/boundary outputs remain separate under #426.
