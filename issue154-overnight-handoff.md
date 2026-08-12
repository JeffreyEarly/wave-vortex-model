# Issue #154 overnight handoff

Status: **ADVANCE_TO_BENCHMARK**. Exact per-call phase shifting passes the required `1e-12` gate for the hydrostatic and nonhydrostatic horizontal operators. No medium, large, RSS, or reportable timing was run because the other overnight research tasks were active.

## Source identity

- Assigned branch: `experiment/issue-154-exact-phase-shift`
- #128 scaffold: `782e9b41b76628eb0f61b1bd87339dd69b884314`
- Pinned baseline ancestor: `be0f78995c49a2bfe4c43d75827856e3812ac278`
- Native FFTW identity reused from #128: `fftw-3.3.11-neon`, pthread provider `/private/tmp/issue128-native-cache/providers/native-neon-pthreads-d2b85f7a608fbedd/install`
- Issue #154 build/cache root: `/private/tmp/issue154-overnight-cache`

## Discrete proof

Let (R\subset\mathbb Z^2) be the complete Hermitian-symmetric WaveVortex radial retained set and let (K=\max_{(k,l)\in R}|k|), (L=\max_{(k,l)\in R}|l|). The radial set contains the complete axial chains ((-K,0),\ldots,(K,0)) and ((0,-L),\ldots,(0,L)), so the smallest cyclic FFT grid that represents every retained input without collision is (M_x=2K+1), (M_y=2L+1).

For retained inputs (p,q\in R) and retained output (r\in R), a cyclic product aliases exactly when (p+q-r=(aM_x,bM_y)). Because (|p_k+q_k-r_k|\le3K<2M_x) and likewise in (y), the complete possible nonzero alias set lies in ({-1,0,1}^2\setminus\{(0,0)}). Exhaustive enumeration finds all eight images across the tested WaveVortex radial geometries: ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)).

A shift by grid-cell fractions (sigma=(\sigma_x,\sigma_y)) multiplies alias ((a,b)) after inverse shifting by (exp(2\pi i(a\sigma_x+b\sigma_y))). Uniform averaging over ((0,0),(1/2,0),(0,1/2),(1/2,1/2)) factors into (	frac12(1+(-1)^a)\tfrac12(1+(-1)^b)), which is zero for every nonzero alias above. Two diagonal grids ((0,0),(1/2,1/2)) leave diagonal aliases unchanged and have worst residual 1.

Four shifts are minimal for the general radial case. When all eight aliases occur, the sample vectors for the characters (1), (chi_x), (chi_y), and (chi_x\chi_y) must be mutually orthogonal; therefore the number of shift samples is at least four. The tensor half-cell set attains that bound. Degenerate tiny retained sets can require only one or two shifts, but four is the smallest schedule valid for every supported radial geometry. The corresponding alias-free explicit control grid is (E_x=3K+1), (E_y=3L+1).

## Correctness and lifecycle

`WVIssue154PhaseShiftEnumeration` exhaustively covered every (N_x,N_y\in[2,9]), three physical aspect ratios, original odd/even and nonsquare grids, zero and excluded Nyquist boundaries, and both MIMO arities: 192 geometries and 384 hydrostatic/nonhydrostatic operator cases. It compared direct retained-mode convolution, native-style explicit cyclic convolution on ((3K+1)\times(3L+1)), and phase shifting on ((2K+1)\times(2L+1)). Maximum relative infinity errors were `7.9716489297472054e-16` for explicit padding and `8.3845930201022017e-16` for phase shifting.

The native FFTW `phase-shift-tensor4` engine was then exercised through complete compiled `nonlinearFlux` calls against the #128 pthread explicit control. Errors were `8.1325626139410734e-15` for hydrostatic 8×7×7 and `8.1493478106150001e-15` for nonhydrostatic 9×8×7 at both one and four FFTW threads. Worker regions were disjoint, the configured FFTW maximum was four threads, and both the fourteen core FFTW plans and the two phase-shift plans returned to zero active plans with created equal to destroyed.

The engine keeps canonical retained half-spectrum channel storage and one half-spectrum FFT work buffer; it does not retain a full Hermitian spectrum. Each shift is evaluated and combined inside the same convolution call. The general schedule performs four shifted evaluations, so performance remains an open gate.

## Reproduction and next gate

Build with `ISSUE154_STANDALONE_OUTPUT_ROOT=/private/tmp/issue154-overnight-cache/standalone-build Benchmarks/buildIssue154Standalone.sh`. Run the emitted executable with `--variant explicit --reference-output <path>` and the same deterministic case with `--variant phase-shift-tensor4 --reference-input <path>`. Use no more than four threads for the current Lyra follow-up. A medium hydrostatic plus nonhydrostatic correctness-and-screening pair should take under 10 minutes including fresh FFTW planning; reserve roughly 20 minutes for a cautious rotated small/medium screen. Do not run the issue's finalist timing protocol unless the screening candidate remains plausible.
