# Independent-source final variable flux qualification

All 160 fresh-process runs passed independent MATLAB and frozen-output comparisons. The frozen production/pruned source is `b157988355d2fabb6cbc62d56de18b203456897f`; the compact/interleaved candidate is `a3acbf4dc9305c4d656399e9f98bc8360ddfa66f`. Separately identified harness/build receipts bind both workers to their sources and binaries. Source and binary postflight passed, and every run used the same hashed FFTW libraries.

Eight process blocks per profile alternate selection order. Each process performs two warmup calls and four measured complete nonlinear-flux calls; its median is the paired observation. Native FFTW internal threads are one; optimized horizontal workers are twelve; candidate pointwise workers are eight. All selections use Accelerate matrices with the recorded process environment unchanged. The general vertical stage has one outer worker; no claim is made about opaque vendor-internal BLAS worker counts.

| Profile | Compact / production time | Compact / prior-pruned time | Compact / candidate-interleaved time | Compact / production peak RSS |
| --- | ---: | ---: | ---: | ---: |
| SQG 256×256×129 | 0.1691 | 0.8065 | 0.8720 | 0.8038 |
| SQG 512×512×257 | 0.1632 | 0.7355 | 0.8002 | 0.7712 |
| Hydrostatic 256×256×129 | 0.2536 | 0.7985 | 0.9290 | 0.6597 |
| Hydrostatic 512×512×257 | 0.2538 | 0.7551 | 0.8829 | 0.6348 |
| Boussinesq 256×256×129 | 0.3927 | 0.4907 | 0.4825 | 0.6685 |

The equally weighted geometric production time ratio is **0.23373**, with paired bootstrap 95% interval **[0.22920, 0.23831]** (10,000 within-profile resamples, seed 455). Geometric complete-process peak RSS is **0.70449** of production. Every profile passes the production time/memory gates, and all owned-capacity ratios are below one. The prior-pruned comparison also passes all profile time/memory gates: aggregate time ratio **0.70607**, interval **[0.69588, 0.71622]**, RSS **0.76936**.

The optimized candidate-interleaved comparison remains separate: aggregate time ratio **0.77309**, interval **[0.75994, 0.78501]**. Compact's geometric peak RSS is 0.109% higher for SQG 256 and 0.043% higher for Hydrostatic 256, so this comparator fails the strict no-profile-RSS-growth check. Its owned capacities decrease in every profile. These observations are retained; they do not erase the passing production and prior-pruned gates.

The archive preserves all 324 text reports, process sample arrays, commands, fixture/build/source/provider identities, failures logs, summary and postflight. The index hashes every archived original. The first 20 successful binary flux payloads remain under `/private/tmp/wvm455-compact-final`; later successfully compared duplicates were hashed and removed according to the frozen protocol. Historical control workers do not report preparation time separately; candidate preparation is recorded, and the separate complete-model worker records preparation for both sources.

This establishes the direct-flux boundary only. Boussinesq 512 is excluded because its scientific matrices alone require about 20.3 GiB before copies. Complete-model qualification, default selection and final integration remain separate gates. No small-grid timing claim, MATLAB API change or public MATLAB-loaded variable-transform support is introduced.
