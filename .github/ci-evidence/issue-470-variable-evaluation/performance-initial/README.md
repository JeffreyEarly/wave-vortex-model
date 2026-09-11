# Initial frozen performance campaign

This is the complete first campaign at candidate `c657c99c`, retained before investigating the constant-stratification regression. It is **not a successful final qualification**. The protocol contains frozen source, binary, fixture and environment identities; `pairs.json` contains all two warmup and eight alternating measured runs for each policy and profile. All scientific comparisons, exact integration decisions and postflight identity checks passed.

| Workload | Reuse integration / baseline | Low-memory integration / baseline | Low-memory peak owned storage / baseline |
| --- | ---: | ---: | ---: |
| EddyTide 256 × 256 × 28 | 0.574867 | 0.576558 | 1.000269 |
| Constant nonhydrostatic 256 × 256 × 129 | 1.030822 | 1.039580 | 1.006186 |
| Variable Hydrostatic 256 × 256 × 129 | 0.785767 | 0.785134 | 1.000067 |

The constant case exceeded the 3% default-policy investigation threshold. Its integration time increased from 1.551937 s to 1.599795 s on average; approximately 25 ms of the increase occurred outside the measured flux, tracer and clear phases of the RHS. Observer time increased by approximately 13 ms. Complete-process time increased by 0.86%, with a 95% paired bootstrap interval of [0.59%, 1.10%]. The full integration ratio interval was [1.017440, 1.043671]. These differences are preserved rather than discarded or hidden by a new timing campaign.

A focused validation investigation found 18 state validations, each scanning three coefficient arrays and checking phase products (36.3 MB total per validation). The serial coefficient scan measured approximately 0.704 ms per validation. A branchless form vectorized but measured slightly slower (0.723 ms), so it was rejected. The existing prepared executor reduced coefficient scan time to approximately 0.12–0.20 ms. Phase preparation also repeated the overflow check of an already validated immutable scope. These observations motivated a bounded validation optimization; they do not by themselves establish its end-to-end performance.

Raw reports and frozen copies of both executables are retained locally in `/private/tmp/wvm470-final-performance-c657c99c`. The running production experiment was not modified. Final qualification must use a newly frozen candidate and preserve this initial result alongside the subsequent campaign.
