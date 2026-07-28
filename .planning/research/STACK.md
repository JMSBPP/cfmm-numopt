# Stack Research — GAMS 54.1 Solve Idioms for `(Δᵢ, η)`

**Domain:** Constrained two-control optimization in GAMS 54.1, mirroring Lean 4 existence theorems, under a CONOPT-only solver constraint with Q64.96 / Q128.128 fixed-point magnitudes
**Researched:** 2026-07-27
**Confidence:** HIGH (every recommendation below was executed against the installed GAMS 54.1.0 / CONOPT 4.39.0 and cross-read against the bundled official documentation; exceptions are marked inline)

---

## 0. How this was verified (read this before trusting anything below)

This is **not** a training-data recall document. The machine has a working install at
`/usr/gams/gams54.1_linux_x64_64_sfx/` (GAMS Base Module **54.1.0 37378ce0 Jun 15 2026**, LEG x86 64bit/Linux)
carrying the complete official HTML documentation in `docs/`. Two verification channels were used:

| Channel | What it covers | Marking |
|---|---|---|
| **EXECUTED** | 17 experiment programs actually run through `gams`; outputs quoted verbatim | `[EXEC]` |
| **DOC 54.1** | The bundled `docs/*.html` for exactly this build — not gams.com, not training data | `[DOC]` |
| **INFERRED** | Reasoning from the two above, not directly tested | `[INFER]` |

Both existing repo units (`eta_pi_trader_zero_slippage.gms`, `eta_pi_trader_band_monotone_large.gms`)
were re-run green as a baseline before any experiment.

### License constraint discovered during verification — READ FIRST

`gamslice.txt` on this machine is a **GAMS Demo license**, not a full license. `[EXEC]` — every solve
log prints `*** This solver runs with a demo license. No commercial use.`

Documented demo limits `[DOC — UG_License.html §Additional Solver Limits]`:

| Model class | Demo limit |
|---|---|
| LP / RMIP / MIP | 2000 variables, 2000 constraints |
| **All other types (incl. NLP, MINLP)** | **1000 variables, 1000 constraints** |
| BARON / ANTIGONE / LINDOGLOBAL | **m ≤ 50, n ≤ 50, nlnz ≤ 50** — effectively unusable |
| KNITRO | m ≤ 300, n ≤ 300, nd ≤ 50 |

**Consequence for the roadmap:** a 200-element tick menu formulated as a *single* NLP is trivially
inside the limit; a global-solver (BARON) cross-check on that model is **impossible** on this license
(50-variable ceiling). Do not plan a BARON verification phase without first budgeting a license.

---

## Recommended Stack

### Core Technologies — the three formulations, one per theorem

| Formulation | GAMS mechanism | Mirrors which Lean theorem | Why this one |
|---|---|---|---|
| **F1 — Menu loop** `loop` over `Set menu /1*200/`, one CONOPT NLP in `η` per element, then argmax extraction | `loop(...) Solve ... ;` + `smax`/`smin` | `MeanVarianceOptimization.exists_mv_optimal_tick_menu` (finite `Finset.Icc 1 200`) | **The primary recommendation.** Only formulation that (a) needs nothing but CONOPT, (b) gives *deterministic* tie-breaking, (c) yields the whole comparative-statics profile `mvBest(menu)` for GDX export and monotonicity assertions, (d) is faster than the MINLP. `[EXEC]` 200 subsolves in **0.31 s** |
| **F2 — Joint 2-D NLP** both `Δᵢ` and `η` continuous `Variable`s over the box | `Variable di, eta;` + one `Solve ... using nlp` | `exists_max_on_compact` / `exists_mv_optimal` / `ComparativeStatics.exists_optimizer` (box `[1,200] × [a,b]`) | Corroborates that the *value* attained by F1 is the true box supremum, i.e. that integrality of `Δᵢ` costs nothing. Use as a **cross-check on the value, never as the source of `(Δᵢ*, η*)`** — see §Non-uniqueness below |
| **F3 — Closed-form corner assertion** pure `abort$` on the F1 result, no solve | `abort$(gam = 0 and diStar <> 200) "..."` | `riskNeutral_isMaxOn_corner` / `ComparativeStatics.riskNeutral_corner` | The corner `(200, b)` is *proven*, so the GAMS side must **assert**, not search. `[EXEC]` F1 and F2 both return exactly `(200, 0.900)` at γ = 0 |

`[EXEC]` γ = 0, 200-element menu, λ = 1.0001, 5 positive ticks, box `[1,200] × [0.1,0.9]`:

```
menu_mvMax  menu_diStar  menu_nTies  menu_etaStar   joint_mv  joint_di  joint_eta    gap_mv
     3.340      200.000       1.000         0.900      3.340   200.000      0.900         0
```

F1 = F2 = `riskNeutral_corner`. One tie. This is the phase's acceptance test.

### The finding that should drive the phase design: **the optimizer is not unique**

The payoff family is `priceKernel λ Δᵢ η i_j = λ^(i_j·Δᵢ·η)` (`MeanVarianceOptimization.lean:139`,
`ComparativeStatics.lean:102`). It depends on the two controls **only through the product `Δᵢ·η`**.
Every level set of the objective is therefore a hyperbola `Δᵢ·η = const`, and whenever the optimum is
**interior** the argmax is a *continuum*, not a point. Lean already says this: `g θ` is
`(exists_optimizer θ).choose` — `Classical.choice`, with **no uniqueness lemma anywhere in
`ComparativeStatics.lean`**.

`[EXEC]` γ-sweep, same instance, F1 (menu loop) vs F2 (joint NLP, 3-start):

| γ | F1 value | F1 `Δᵢ*` | F1 ties | F1 `η*` | F2 `Δᵢ*` | F2 `η*` | value gap |
|---|---|---|---|---|---|---|---|
| 0 | 3.340 | 200 | **1** | 0.900 | 200 | 0.900 | 0 |
| 10 | 1.180 | 58 | **6** | 0.801 | 109.242 | 0.425 | 2.2e-16 |
| 100 | 1.022 | 8 | **30** | 0.871 | 24.420 | 0.285 | 2.2e-16 |
| 1000 | 1.002 | 1 | **5** | 0.744 | 7.441 | 0.100 | — |

`[EXEC]` Dumping the γ = 100 tie set confirms the mechanism exactly — all 62 tied menu points
(tolerance 1e-12) carry the **same product**:

```
      mv       eta     Δᵢ·η          prodMin = 6.966
8   1.022    0.871    6.966          prodMax = 6.966
9   1.022    0.774    6.966          prodSpread = 8.47e-7  (objScale = 1)
...                                  prodSpread = 9.94e-13 (objScale = 1e6)
69  1.022    0.101    6.966
```

**Prescription (HIGH confidence, `[EXEC]`):**

- Assert the **coordinates** `(Δᵢ*, η*) = (200, b)` **only** under `γ = 0` (and guard the assertion with
  `$(gam = 0)`), because that is the only case where both controls saturate and the argmax is a point.
- For `γ > 0`, assert the **optimal value** and the **product `Δᵢ*·η*`**, plus `card(tieSet)`. Do **not**
  assert either coordinate — it is not identified, and any such assertion is a test that passes by
  accident and will flip on a CONOPT version bump.
- Export `nTies` and `prodSpread` to GDX as first-class provenance. A silent `nTies = 62` is the
  difference between "we solved it" and "we picked one of 62 equally-good answers".

### Supporting constructs

| Construct | Verified form | Purpose | When to use |
|---|---|---|---|
| `%modelStat.optimal%` = 1, `%modelStat.locallyOptimal%` = 2, `%modelStat.feasibleSolution%` = 7, `%modelStat.integerSolution%` = 8 | `[DOC — UG_GamsCall.html]`, `[EXEC]` | Compile-time constants for status asserts | Always — never hard-code `2` |
| `%solveStat.normalCompletion%` = 1, `%solveStat.iterationInterrupt%` = 2, `%solveStat.terminatedBySolver%` = 4 | `[DOC — UG_GamsCall.html]`, `[EXEC]` | Second half of the status assert | Always — see §Status checking |
| `Model.solveLink = %solveLink.loadLibrary%` (= 5) | `[EXEC]` | In-process solver call, no subprocess spawn | **Mandatory** for any solve inside a `loop`. 200 solves: **4.43 s → 0.31 s (14×)** |
| `Model.solPrint = %solPrint.silent%` (= 2), `Model.limRow = 0`, `Model.limCol = 0` | `[EXEC]` | Suppress 200 solution reports | Mandatory for loops — otherwise the `.lst` becomes unusable |
| `Model.optFile = 1` + `conopt.opt` file | `[EXEC]` | CONOPT option overrides | Only as a fallback; prefer objective scaling |
| `Model.scaleopt = 1` + `x.scale` / `eqn.scale` | `[DOC — UG_LanguageFeatures.html §Model Scaling]`, `[EXEC]` | Solver sees `V_a = V_u / c`, `G_a = G_u / d`, derivatives `× c/d` | When the natural units genuinely must be Q96/Q128 in the equation |
| `Model.numInfes`, `.numNOpt`, `.domUsd`, `.sumInfes`, `.maxInfes`, `.iterUsd`, `.objEst` | `[EXEC]` (full allowable list printed by error $113) | Post-solve diagnostics | Export to GDX for provenance |
| `execute_unload` + `gdxdump ... format=csv dformat=hexbytes` | `[EXEC]` | Bit-exact numeric export | For the differential-testing track — see §GDX fidelity |

### Development tools

| Tool | Purpose | Notes |
|---|---|---|
| `gams <file> idir=<dir>` | Resolve relative `$include` without `cd` | `[EXEC]` — resolved `payoff/_PayoffScaffolding.gms` correctly from an out-of-tree driver. A cleaner alternative to the current "every target `cd`s into `model/` first" constraint in PROJECT.md, and it lets test drivers live outside `model/` |
| `gams <file> o=<path>` | Redirect the `.lst` | Stops `PayoffModule.lst` / `PayoffModuleTest.lst` polluting the worktree (both are currently untracked noise in `git status`) |
| Equation listing (`limRow > 0`) | Read the actual Jacobian entries GAMS hands CONOPT | **The single best scaling diagnostic.** `[DOC — UG_NLP_GoodFormulations.html:145]` recommends exactly this |
| `gdxdiff` | GDX fixture comparison | Already in the repo's testing layer |

---

## Answers to the five questions

### Q1 — Finite menu enumeration vs continuous NLP vs MINLP

**Use the menu loop (F1). Do not use an MINLP.** Confidence: HIGH `[EXEC]`.

Three candidates were built and run on the identical 200-tick instance:

| Candidate | Result | Verdict |
|---|---|---|
| Enumerated `Parameter` + `smin`/`smax` argmax (what the repo does today for the *fixed*-η case) | works, but only covers `η` fixed | Correct as far as it goes; must be extended to a loop-of-solves once `η` becomes free |
| **`loop` over the menu, one NLP in `η` each, then argmax** | `[EXEC]` 200/200 converged, 0.31 s, argmax `(200, 0.9)`, `nTies = 1` at γ=0 | **RECOMMENDED** |
| MINLP with binary selection `z(menu)`, `sum(menu, z) =e= 1`, `di =e= sum(menu, diVal·z)` | `[EXEC]` SBB+CONOPT: 0.53 s, 200 nodes, `modelStat = 8`, returns `Δᵢ = 9, η = 0.774` | **REJECTED** |

Reasons to reject the MINLP, in order of severity:

1. **CONOPT cannot solve MINLP at all.** `[EXEC]` `option minlp = conopt;` is a **compile-time error**:
   `$255 Algorithm not suitable for process`. `[DOC — gmscmpun.txt]` CONOPT's declared capability list is
   `LP RMIP NLP CNS DNLP RMINLP QCP RMIQCP` — MINLP is absent. Any MINLP forces a *different* solver
   (SBB or DICOPT), breaking the CONOPT-only constraint.
2. **No deterministic tie-breaking is possible.** `[EXEC]` at γ=100 the menu loop with smallest-index
   tie-break returns `Δᵢ = 8`; SBB returns `Δᵢ = 9`. Both objective values are `1.022`. SBB returns
   whichever node it happened to fathom first — that is a branch-and-bound implementation detail, not
   a specification. The repo's `tieBreaking /1/` scalar is **unimplementable** under an MINLP.
3. **`modelStat = 8` (integerSolution) is the success code for MINLP,** not 1 or 2. `[EXEC]` The repo's
   existing predicate `abort$(m.modelStat <> %modelStat.locallyOptimal% and m.modelStat <> %modelStat.optimal%)`
   would **falsely abort on a successful MINLP solve**. Anyone adding an MINLP must remember to widen
   the predicate; that is a latent trap.
4. **The MINLP returns one point; the loop returns the whole profile.** `mvBest(menu)` and
   `etaBest(menu)` are exactly the `value θ` / `g θ` curve of `ComparativeStatics`, and are what the
   existing sliding-window monotonicity checks (T1/T1L) operate on. An MINLP throws that away.
5. It is **slower** anyway (0.53 s vs 0.31 s).

**Structural argument, and the reason F1 is not merely a convenience** `[EXEC]`: the repo's own kernel
already *is* a menu in `Δᵢ`.

```gams
* eta slot accepts a Variable — compiles, solves, returns eta.l = 0.900 (the upper bound):
e.. obj =e= tunablePricingKernel('s10','k181', etaV) / Q96;

* di slot does NOT — Delta_i is a SET INDEX into tickSpacingVal:
e.. obj =e= tunablePricingKernel(diV,'k181', 0.5);
****                            $121  Set expected
****                            $148  Dimension different
```

`tunablePricingKernel(di, i, eta)` expands to `tickVal(i) * tickSpacingVal(di) * (eta)`. `Δᵢ` enters
through a **set-indexed `Parameter`**; `η` enters as a plain factor. The macro is *by construction*
"enumerate `Δᵢ`, optimize `η`" — precisely the shape of `exists_mv_optimal_tick_menu`. Fighting that
with an MINLP means rewriting the kernel to take a numeric `Δᵢ` (as `P_Lean_at` does) for no gain.

> **Domain-bound defect to fix in this phase** `[EXEC]`, already flagged in PROJECT.md as a TODO:
> `PricingKernel.gms` declares `Set tickSpacingDomain /s1*s60/` — a **60**-element menu — while the
> Lean box is `Set.Icc (1:ℝ) 200` and `Finset.Icc (1:ℤ) 200`, and `_PayoffScaffolding.gms` declares
> `diMaxInt /200/`. The menu must be `/s1*s200/` (or the kernel re-indexed) before F1 can claim to
> implement the theorem. Today `tunablePricingKernel` **cannot even express** `Δᵢ = 200`.

### Q2 — Extracting the argmax with deterministic tie-breaking

There is no `argmax` operator in GAMS. `[DOC]` — `UG_Parameters.html` documents `smin`/`smax` as value
reductions only; the only sorting facility is `$libInclude rank`, which is inappropriate here (see
§What NOT to Use). The idiom is a two-step reduce-then-select. Working, executed syntax:

```gams
* --- reusable tolerance-aware tie predicate ---
$macro TIED(val, ext, tol) ( abs((val) - (ext)) <= (tol)*max(abs(ext), 1) )

Scalar tieTol      / 1e-12 /;
Scalar tieBreaking / 1 /;              # 1 = smallest index, 2 = largest index

Scalar mvMax ;  mvMax = smax(menu, mvBest(menu));

Set    tieSet(menu);
tieSet(menu)$TIED(mvBest(menu), mvMax, tieTol) = yes;

abort$(card(tieSet) = 0)
    "FAIL: argmax tie set empty — smax/tolerance inconsistency";

Scalar nTies ;  nTies = card(tieSet);
Scalar diStar ;
diStar$(tieBreaking = 1) = smin(tieSet, diVal(tieSet));
diStar$(tieBreaking = 2) = smax(tieSet, diVal(tieSet));

abort$(diStar = 0 or diStar = +inf or diStar = -inf)
    "FAIL: argmax extraction produced a non-finite index", diStar;

Scalar etaStar ; etaStar = sum(menu$(diVal(menu) = diStar), etaBest(menu));
```

Four points, all `[EXEC]`-verified:

**(a) The `+INF` trap is real and silent.** A `smin`/`smax` over an **empty** conditional does not
error — it returns the identity element:

```
Scalar emptySmin ; emptySmin = smin(g$(v(g) = -1), idx(g));   ->  +INF
Scalar emptySmax ; emptySmax = smax(g$(v(g) = -1), idx(g));   ->  -INF
```

That `+INF` then flows into `execute_unload` and lands in a GDX fixture the differential-testing track
consumes. **The `card(tieSet) = 0` guard is not optional.**

**(b) Exact `=` is safe against `smin`/`smax` of the *same stored* `Parameter`, and unsafe otherwise.**
`[EXEC]` over 2000 irrational values `sqrt(ord) * exp(-ord/777) + sin(ord)*1e-17`, exactly **one**
record satisfies `v(g) = smax(g, v(g))`. `smax` returns a bitwise copy of one of the stored doubles,
so the comparison is exact by construction. This means **the existing code is correct**:

```gams
* eta_pi_trader_band_monotone_large.gms:74-75  — SAFE, keep as is
Scalar piMinOnBand ; piMinOnBand = smin(bandGrid$inBand(bandGrid), piGridPlank(bandGrid));
Scalar diArgmin ;    diArgmin    = smin(bandGrid$(inBand(bandGrid)
                                   and piGridPlank(bandGrid) = piMinOnBand), diVal(bandGrid));
```

**(c) …but the moment values come from independent `Solve`s, exact `=` under-counts by ~2×.**
`[EXEC]` at γ = 100:

| Tie rule | Tie count | Smallest-index argmax |
|---|---|---|
| exact `=` | **30** | 8 |
| rel 1e-15 | **57** | 8 |
| rel 1e-12 | **62** | 8 |
| rel 1e-9 | 62 | 8 |
| rel 1e-6 | 63 | — |

The argmax happened to agree here, but it is luck: if the smallest-index member of the true tie set
lands 1 ulp off `mvMax`, the exact rule skips it and silently returns a larger `Δᵢ`. **Rule: exact `=`
for values produced by one vectorized `Parameter` assignment; `TIED(...)` at `diffTolerance = 1e-12`
for values produced by separate solves.**

**(d) `smin(tieSet, diVal(tieSet))` — indexing the subset directly — works and reads better than
`smin(menu$tieSet(menu), diVal(menu))`.** `[EXEC]` Both compile; prefer the former.

### Q3 — Asserting a CONOPT solve against a known closed form

**Status checking.** The repo currently checks `modelStat` only. Widen it:

```gams
abort$( (M.modelStat <> %modelStat.optimal%
         and M.modelStat <> %modelStat.locallyOptimal%)
        or M.solveStat <> %solveStat.normalCompletion% )
    "FAIL: CONOPT did not converge", M.modelStat, M.solveStat;
```

`[EXEC]` with `M.iterLim = 1`: `modelStat = 7` (feasibleSolution), `solveStat = 2` (iterationInterrupt),
`di.l = 30.654` — badly wrong. The current `modelStat`-only check does catch this one, but
`solveStat` costs nothing and covers resource/solver interrupts that can leave `modelStat` at 1 or 2
`[DOC — S_CONOPT.html:299]`.

Two failure modes the status check does **not** cover, and both matter here:

1. `[EXEC]` **`modelStat = 2` is compatible with a 1e-2 wrong answer.** Every raw-objective run below
   reported `Locally Optimal`. `modelStat` is a convergence claim, not an accuracy claim.
2. `[EXEC]` **Execution errors abort before `modelStat` is ever set.** `x ** y` with `x < 0` gives
   `**** Exec Error: rPower: FUNC DOMAIN: x**y, x < 0` and `SOLVE ... ABORTED, EXECERROR = 1` — the
   run dies at model generation. The repo's `(lambdaWad/unity) ** (...)` has base 1.0001 > 0 so it is
   safe today, but any future kernel with a state-dependent base needs a positivity guard on the base,
   not on the result.

**The ~1e-2 precision claim: expected behaviour, but avoidable and worth fixing.**

`[DOC — S_CONOPT.html:258]`, verbatim:

> "The solution is a locally optimal interior solution. The largest component of the reduced gradient
> is less than the optimality tolerance, **Tol_Optimality, with default value 1.e-7**. The value of the
> objective function is very accurate **while the values of the variables can be less accurate due to a
> flat objective function in the interior of the feasible area**."

`[EXEC]` The zero-slippage unit reproduces exactly this. Its listing shows CONOPT 4.39.0, terminating
with `** Optimal solution. Reduced gradient less than tolerance.` and

```
---- VAR di    1.0000   35.4351   200.0000   5.6580668E-8     <- marginal 5.66e-8 < Tol_Optimality 1e-7
analytical Δᵢ*_Plank = 35.122     ->  relative error 8.9e-3
```

The objective `piTrader_Half_Plank` is `sqr(residual)` and evaluates to ~1e-5 near the start and ~1e-9
at the optimum. The reduced gradient is below `Tol_Optimality` essentially *everywhere*, so CONOPT stops
almost immediately. **This is an objective-scaling defect, not a CONOPT limitation.**

`[EXEC]` Mitigation comparison, all on the repo's own macros, same start point `Δᵢ = 17.56`:

| Mitigation | `Δᵢ` returned | relative error | verdict |
|---|---|---|---|
| **baseline (repo today)** | 35.435 | **8.9e-3** | what the `> 1 tick` assertion is working around |
| warm-start at the answer | 35.122 | 0 | meaningless — CONOPT never moves |
| tighten bounds to `[34, 36]` | 35.000 | 3.5e-3 | **does not help**; still stops on the gradient test |
| `conopt.opt` with `Tol_Optimality 1e-11` | 35.122 | **5.8e-10** | works, but needs an external file in the build |
| **`Model.scaleopt = 1` with `p.scale = 1e-9, e.scale = 1e-9, di.scale = 35`** | 35.122 | **1.8e-14** | works |
| **multiply the objective by `1e10` in the equation** | 35.122 | **1.25e-14** | **simplest, best** |

`[EXEC]` Robustness of the `×1e10` fix across six start points `Δᵢ₀ ∈ {1, 5, 20, 60, 120, 200}`:

```
        raw_di    raw_rel     x1e10_di    x1e10_rel
s1      35.390      0.008       35.122     4.25e-15
s2      35.166      0.001       35.122     2.16e-13
s3      35.282      0.005       35.122     5.06e-15
s4      35.513      0.011       35.122     1.21e-15
s5      35.173      0.001       35.122     4.09e-13
s6      35.421      0.009       35.122     1.44e-14
```

Twelve orders of magnitude of accuracy, from one multiplication. **`modelStat = 2` in all twelve runs.**

**Prescription (HIGH confidence):**

- Introduce a scaffolding scalar `objScale` and write every payoff equation as
  `obj =e= objScale * ( <natural expression> );`.
- Choose `objScale` so the objective's **typical magnitude at the starting point** lands in
  **`[1e2, 1e6]`** — i.e. 9–13 orders above `Tol_Optimality = 1e-7`. `[EXEC]` `objScale = 1e6` gave the
  best tie-set product identification (`prodSpread = 9.9e-13`); `objScale = 1e9` **over-scaled** and
  produced repeated `The derivative is discontinuous causing slow convergence` warnings. There is a
  sweet spot; do not just make it huge.
- **Then tighten the assertion.** The current
  `abort$(abs(diSolverRound - diPlankRound) > 1) "... diverged from analytical by more than 1 tick"`
  is honest about the *observed* error but concedes 1e-2. After scaling, the correct assertion is a
  relative tolerance on the *continuous* value:
  `abort$(abs(di.l - refAnalytical)/refAnalytical > 1e-9) "..."`.
  Retiring the "1 tick" tolerance is a real quality gain for the differential-testing consumer.
- The comment `# CONOPT precision on this Q96-flat objective is ~1e-2 relative` should be corrected —
  it reads as a law of nature and it is a scaling bug.

### Q4 — Mixing integer `Δᵢ` with continuous `η`

**Enumerate `Δᵢ`, solve NLP in `η`.** MINLP is **not warranted and not available**. Confidence: HIGH `[EXEC]`.

The decisive facts, restated compactly:

- `option minlp = conopt;` → **compile error $255**. CONOPT has no MINLP capability `[DOC — gmscmpun.txt]`.
- SBB *is* bundled and *does* work under the demo license `[EXEC]` (it branches on NLP subproblems and
  used CONOPT as its subsolver), so "MINLP is impossible" would be too strong — but it violates the
  stated CONOPT-only constraint, cannot tie-break deterministically, returns `modelStat = 8`, discards
  the profile, and is slower.
- DICOPT `[DOC — gmscmpun.txt]` requires **both** an NLP and a MIP subsolver; the MIP side is an extra
  license surface. BARON is capped at **50 variables** on this license — it cannot see a 200-element menu.

Reference implementation (executed end to end, 0.32 s, asserts green):

```gams
Set menu /1*200/;
Parameter diVal(menu); diVal(menu) = ord(menu);

Scalar   diFix;                        # the enumerated Δᵢ, a Scalar not a Variable
Variable eta, mvObj;
Equation defMV;
eta.lo = aLo; eta.up = bHi;
defMV.. mvObj =e= objScale * ( <MV objective in diFix and eta> );

Model MenuNLP /defMV/;
option nlp = conopt;
MenuNLP.solPrint  = %solPrint.silent%;
MenuNLP.solveLink = %solveLink.loadLibrary%;   # 14x faster over 200 solves
MenuNLP.limRow = 0; MenuNLP.limCol = 0;

Parameter mvBest(menu), etaBest(menu), msOf(menu), ssOf(menu);
loop(menu,
    diFix = diVal(menu);
    eta.l = (aLo + bHi)/2;                     # deterministic restart, NOT the previous solution
    Solve MenuNLP using nlp maximizing mvObj;
    msOf(menu) = MenuNLP.modelStat;  ssOf(menu) = MenuNLP.solveStat;
    mvBest(menu) = mvObj.l;          etaBest(menu) = eta.l;
);

Set badSolve(menu);
badSolve(menu)$( (msOf(menu) <> %modelStat.optimal% and msOf(menu) <> %modelStat.locallyOptimal%)
                 or ssOf(menu) <> %solveStat.normalCompletion% ) = yes;
abort$(card(badSolve) > 0) "FAIL: menu subsolve(s) did not converge", badSolve;
```

Two syntax facts that will otherwise cost an afternoon `[EXEC]`:

- **Declarations are illegal inside `loop`/`if`.** `Set st /s1*s3/;` inside a `loop` gives
  `$349 Declaration not allowed inside a LOOP or IF statement`. Hoist every `Set`/`Parameter`/`Scalar`
  above the loop.
- **`prod` is a reserved aggregation operator.** `Parameter prod(menu);` yields
  `$125 Set is under control already` at every use site. Given this project wants to record the product
  `Δᵢ·η`, name it `dieta` / `prodDiEta`, never `prod`.

**Deterministic restart, not warm-start:** `eta.l = (aLo+bHi)/2` is reset every iteration. Carrying
`eta.l` from the previous menu point would make the result **path-dependent** — a different answer if
the loop order changes — which is fatal for a reproducible GDX fixture. `[INFER]` (not separately
benchmarked, but it follows directly from the tie-continuum result: any point on the hyperbola is
optimal, so a warm start biases toward the previous point).

### Q5 — Objective scaling under Q64.96 / Q128.128 dynamic range

**The hazard is real, it is a hard failure, and the remedy is to keep fixed-point magnitudes out of
the `Variable`/`Equation` layer entirely.** Confidence: HIGH `[EXEC]`.

Magnitudes: `Q96 = 2⁹⁶ ≈ 7.92e28`, `Q128 = 2¹²⁸ ≈ 3.40e38`.

`[EXEC]` **Three-way experiment, identical model, only the scaling differs:**

| Variant | Jacobian entries seen by CONOPT | Result |
|---|---|---|
| **(a) objective carries `* Q96`** | `3.46e26`, `6.91e28` | **`solveStat = 10` Solver Failure, `modelStat = 13` Error No Solution.** `*** SOLVER ERROR: Failed solving model`. Variables left at their **initial** values (100, 0.5) |
| **(b) same model + `obj.scale = Q96; eqn.scale = Q96; Model.scaleopt = 1`** | `0.0044`, `0.872` | Normal Completion, Locally Optimal, argmax `(200, 0.900)`, GAMS reports the **unscaled** `2.646e29` |
| **(c) solve dimensionless, rescale into a `Parameter` afterwards** | `0.0044`, `0.872` | Normal Completion, Locally Optimal, argmax `(200, 0.900)`, `objC.l * Q96 = 2.646e29` — identical to (b) |

Variant (a) is the naive formulation and it does not merely lose precision — **it fails outright**, and
it fails in the worst way: `di.l` and `eta.l` are silently the *starting* values, so a script that
exported them without checking `modelStat` would ship fabricated numbers into a GDX fixture.

The mechanisms, from the documentation `[DOC — S_CONOPT.html]`:

- **`Lim_Variable` default `1e15`** — "CONOPT considers a solution to be unbounded if a variable exceeds
  the indicated value of `Lim_Variable` … and it returns ModelStat = 3". `Q96 = 7.9e28` and
  `Q128 = 3.4e38` are **13 and 23 orders past that ceiling**. Any Q96/Q128 quantity promoted to a GAMS
  `Variable` is, to CONOPT, infinity.
- **`Tol_Scale_Min` default `1`** — "very large terms can be scaled down, but **small terms are not
  scaled up**… The modeler is therefore advised to make sure that the expected solution values are not
  very small". This is the other half of the §Q3 result: CONOPT will *not* rescue a 1e-9 objective.
- `[DOC — UG_LanguageFeatures.html §Scaling Data]` — "define the units of the input data such that the
  **largest values expected for decision variables and their marginals is under a million**". Q96 misses
  that target by 23 orders of magnitude.

**Prescription (HIGH confidence), in priority order:**

1. **Keep Q96/Q128 in `$macro`s and `Parameter`s, never in `Variable`s.** This is what
   `_PayoffScaffolding.gms` already does and it is the reason the existing units work at all —
   `sqrtPX96_at(...)` is an *expression*, so the only `Variable`s are `di` (O(10²)) and `piVal`. **Do not
   "clean this up" into explicit fixed-point variables.** `[EXEC]` variant (a) is what that costs.
2. **Solve in Lean coordinates (dimensionless, O(1)); convert to EVM coordinates in a `Parameter` after
   the solve.** Variant (c). This also matches the project's dual-representation spine: the *solve* lives
   in Lean coordinates where the theorems are proven, the *bridge* is a post-solve assignment, and the
   `abort$` compares the two. It needs no `scaleopt`, no `.scale` bookkeeping, and no per-symbol tuning.
3. **Where the natural equation genuinely must carry the fixed-point factor, use `scaleopt`.** Variant (b).
   Syntax `[DOC — UG_LanguageFeatures.html]`: `V_a = V_u / c`, `G_a = G_u / d`,
   `d(G_a)/d(V_a) = d(G_u)/d(V_u) · c/d`. Scale factors must be `> 1e-20` and are **checked only at model
   generation time**. Discrete variables cannot be scaled (`.scale` is `.prior` for them — a real
   footgun). The documentation's own reference-value pattern is the right way to set them:

   ```gams
   y.Scale    = max( abs(<expr at x.lo>), abs(<expr at x.up>), 0.01 );
   yDef.Scale = y.Scale;
   ```
4. **Read the equation listing once per new unit.** `[DOC — UG_NLP_GoodFormulations.html:145]`
   "run the model with a positive value for the option `limrow` and inspect the coefficients in the
   equation listing". `[EXEC]` This is exactly how variant (a)'s `6.91e28` Jacobian entry was found
   before the solver was even called. Target: entries within a few orders of 1.

**Non-hazard, for the record** `[EXEC]`: GAMS `Parameter` arithmetic handles these magnitudes fine —
`sqr(Q128³)` evaluates to `1.55e231` with no error, well inside IEEE double range. The dynamic-range
problem is **entirely** on the solver side. Pure-arithmetic assertion units (no `Model`/`Solve`) are
unaffected.

**GDX fidelity at these magnitudes** `[EXEC]` — relevant to the GAMS↔Solidity differential track:

- `execute_unload` → `$load` round-trips Q96 and Q128 **bit-exactly** (`Q96 = Q96ref` is true, absolute
  difference 0).
- **But `gdxdump` in its default text format truncates to 15 significant digits**:
  `Scalar Q96 / 7.92281625142643E28 /` — the exact integer 79228162514264337593543950336 is gone.
- The exact-fidelity export path is:
  ```
  gdxdump rt.gdx symb=Q96 format=csv dformat=hexbytes        ->  0x45f0000000000000
  gdxdump rt.gdx symb=Q96 format=csv dformat=hexponential    ->  0x1.0p96
  ```
  **Recommend `dformat=hexbytes` for any fixture the Solidity side consumes.** A 15-digit decimal is
  ~1e-16 relative, which sits right at the repo's `diffTolerance = 1e-12` budget and wastes most of it
  before the comparison even starts.

---

## What the existing code already does correctly (do not regress these)

| Existing practice | Why it is right |
|---|---|
| Q96/Q128 live only in `$macro`s and `Scalar`s; `Variable`s are `di` and `piVal` only | `[EXEC]` The single reason CONOPT converges at all — variant (a) proves the alternative fails hard |
| `smin(bandGrid$(... piGridPlank(bandGrid) = piMinOnBand), diVal(bandGrid))` for smallest-index argmin | `[EXEC]` Exact `=` against `smin` of the **same stored `Parameter`** is bitwise-safe |
| `abort$` on `%modelStat.locallyOptimal%` / `%modelStat.optimal%` compile-time constants rather than literals | `[DOC]` Correct names, correct values (2 / 1) |
| `Set bandGrid /1*200/` + `Parameter diVal(bandGrid) = ord(bandGrid)` + `Set inBand(bandGrid)` band mask | Textbook GAMS enumeration; extends directly to the menu loop |
| Sliding-window monotonicity via a break-set + `card()` rather than a `loop` with a flag | Idiomatic, vectorized, and gives a *count* for the abort message |
| One execution unit per theorem, no `$include` aggregator | `[DOC]` GAMS has one global namespace; this is the only structure that scales |
| `tieBreaking /1/` recorded as an explicit, exported scalar | Correct instinct — it just needs an implementation that honours it (§Q2) |

## What should change

| Change | Reason | Severity |
|---|---|---|
| Add `objScale` to `_PayoffScaffolding.gms`; wrap every payoff equation in it | `[EXEC]` 8.9e-3 → 1.3e-14 argmin accuracy | **HIGH** |
| Retire the `> 1 tick` NLP assertion in favour of a `1e-9` relative assertion, once scaled | The 1-tick tolerance is a workaround for the above | HIGH |
| Correct the comment `# CONOPT precision on this Q96-flat objective is ~1e-2 relative` | It states an avoidable bug as a solver property | MEDIUM |
| Add `or M.solveStat <> %solveStat.normalCompletion%` to every status abort | `[EXEC]` `iterLim` interrupt returns `solveStat = 2` | MEDIUM |
| Extend `Set tickSpacingDomain /s1*s60/` to `/s1*s200/` (or re-index) | `[EXEC]` `tunablePricingKernel` cannot currently express `Δᵢ = 200`, so it cannot express the corner the theorem proves | **HIGH — blocks F3** |
| Use `TIED(...)` tolerance ties for solve-derived values; keep exact `=` for `Parameter`-derived | `[EXEC]` exact ties under-count 30 vs 62 across independent solves | HIGH |
| Add a `card(tieSet) = 0` guard before every argmax extraction | `[EXEC]` empty `smin` returns `+INF` silently into GDX | HIGH |
| Export `nTies`, `prodMin/prodMax/prodSpread`, `numInfes`, `iterUsd` to the GDX | Makes non-uniqueness visible to the downstream consumer | MEDIUM |
| Never assert `(Δᵢ*, η*)` coordinates when `γ > 0` | `[EXEC]` up to 62 equally-optimal coordinate pairs; only `Δᵢ·η` is identified | **HIGH** |
| Set `solveLink = %solveLink.loadLibrary%` and `solPrint = %solPrint.silent%` on any looped model | `[EXEC]` 14× wall-clock; keeps the `.lst` readable | MEDIUM |
| Route `.lst` output via `o=` | `PayoffModule.lst` / `PayoffModuleTest.lst` are currently untracked worktree noise | LOW |

---

## Alternatives Considered

| Recommended | Alternative | When the alternative is better |
|---|---|---|
| Menu loop (F1) with CONOPT | SBB MINLP with binary selection | Only if the menu grows past ~10⁴ points, where 10⁴ sequential NLPs become slow. `[INFER]` — at 200 points enumeration wins on every axis measured |
| Menu loop | Joint 2-D NLP (F2) alone | Never alone. F2 is a *value* cross-check; it cannot honour `tieBreaking` and `[EXEC]` returns a different coordinate pair at every γ > 0 |
| Objective rescaling via `objScale` | `Model.scaleopt = 1` + per-symbol `.scale` | When the equation must be written in natural fixed-point units for readability/auditability. `[EXEC]` gives the same accuracy (1.8e-14 vs 1.25e-14) at the cost of per-symbol bookkeeping |
| Objective rescaling | `conopt.opt` with `Tol_Optimality 1e-11` | When the objective magnitude cannot be changed (e.g. an externally-fixed fixture). `[EXEC]` 5.8e-10 — 4 orders worse than rescaling, and it adds an external file to the build |
| Deterministic restart per menu point | Sequential warm start | Only if convergence becomes a bottleneck. `[EXEC]` 6 CONOPT iterations per solve at 200 points — it is not a bottleneck |
| `option nlp = conopt` (resolves to **CONOPT 4.39.0** `[EXEC]`) | IPOPT / MINOS / SNOPT (all bundled) | A second-solver cross-check is cheap and would independently corroborate the argmax. `[INFER]` — not tested; worth one experiment, not a phase |

## What NOT to Use

| Avoid | Why | Use instead |
|---|---|---|
| `option minlp = conopt;` | `[EXEC]` **Compile error `$255 Algorithm not suitable for process`.** CONOPT has no MINLP capability | Menu loop of NLPs |
| Binary-selection MINLP for the tick menu | `[EXEC]` Non-CONOPT solver required; `modelStat = 8` breaks the existing abort predicate; no deterministic tie-break (returned `Δᵢ = 9` where the loop returns `8`); discards the profile; slower | Menu loop |
| BARON / ANTIGONE / LINDOGLOBAL as a global cross-check | `[DOC — UG_License.html]` Demo license caps them at **m ≤ 50, n ≤ 50, nlnz ≤ 50** | Multi-start CONOPT from ≥3 corners of the box |
| Q96/Q128 quantities as GAMS `Variable`s | `[EXEC]` **Solver Failure, `modelStat = 13`**, variables silently left at their starting values. `[DOC]` `Lim_Variable = 1e15` treats them as infinite | Macros + `Parameter`s; solve dimensionless, rescale after |
| Unscaled objectives of magnitude ≲ 1e-7 | `[EXEC]` 8.9e-3 argmin error while reporting `Locally Optimal`. `[DOC]` `Tol_Optimality = 1e-7`, `Tol_Scale_Min = 1` (small terms are never scaled up) | `objScale` targeting `[1e2, 1e6]` |
| `objScale` above ~1e8 | `[EXEC]` Over-scaling: repeated `The derivative is discontinuous causing slow convergence` | Target `[1e2, 1e6]` and check the equation listing |
| Exact `=` ties across independent `Solve`s | `[EXEC]` Under-counts 30 vs 62; the argmax can silently shift | `TIED(val, ext, 1e-12)` |
| `smin`/`smax` over a conditional without a `card() > 0` guard | `[EXEC]` Returns `+INF` / `-INF` with no error, straight into GDX | Build the tie `Set` first, `abort$(card(...) = 0)` |
| `$libInclude rank` for argmax | `[DOC — T_LIBINCLUDE_RANK.html]` Reserves the global names `rank_tmp`, `rank_u`, `rank_p`, and "the first invocation must be outside of a loop". The repo's dominant constraint is the single global namespace | `smax` + tie `Set` + `smin` |
| `Parameter prod(...)` | `[EXEC]` `prod` is the built-in product operator; every use site errors `$125 Set is under control already` | `dieta`, `prodDiEta` |
| Declaring anything inside `loop`/`if` | `[EXEC]` `$349 Declaration not allowed inside a LOOP or IF statement` | Hoist all declarations |
| Default `solveLink` for looped solves | `[EXEC]` 4.43 s vs 0.31 s for 200 solves (spawns a process each time) | `%solveLink.loadLibrary%` |
| `gdxdump` default text format for fixtures | `[EXEC]` Truncates to 15 significant digits — `2⁹⁶` is no longer exact | `format=csv dformat=hexbytes` |
| Asserting `(Δᵢ*, η*)` coordinates at `γ > 0` | `[EXEC]` Up to 62 coordinate pairs are equally optimal; only `Δᵢ·η` is identified. Lean makes no uniqueness claim (`g θ` is `Classical.choice`) | Assert value + product + `nTies` |

## Formulation by theorem

**If the theorem is `exists_mv_optimal_tick_menu` (finite `Finset.Icc 1 200`):**
- Use F1 — `loop` over `Set menu /1*200/`, one CONOPT NLP in `η` per point, `smax` + tie `Set` + `smin`.
- Because the Lean statement is *literally* a finite maximum over a menu, and `tunablePricingKernel`
  already indexes `Δᵢ` through a `Set`.

**If the theorem is `exists_max_on_compact` / `exists_mv_optimal` / `exists_optimizer` (box `[1,200]×[a,b]`):**
- Use F2 — a single 2-D CONOPT NLP, **multi-start from ≥3 box corners**, and assert only that
  `|value_F2 − value_F1| ≤ diffTolerance · |value_F1|`.
- Because the theorem asserts *attainment of the supremum*, which is a statement about the **value**.
  `[EXEC]` at γ ∈ {0, 10, 100} the F1/F2 value gap is `0` or `2.22e-16` while the coordinates differ
  wildly — the value is the theorem's content, the coordinates are not.

**If the theorem is `riskNeutral_isMaxOn_corner` / `riskNeutral_corner` (γ = 0, λ > 1, `i_j > 0`):**
- Use F3 — **no solve**. Guard on the hypotheses and `abort$` on the F1 output:
  ```gams
  abort$(gam = 0 and nTies <> 1)   "FAIL: risk-neutral optimum must be the unique corner", nTies;
  abort$(gam = 0 and diStar <> 200) "FAIL riskNeutral_corner: Δᵢ* must be 200", diStar;
  abort$(gam = 0 and abs(etaStar - bHi) > cornerTol*max(abs(bHi),1))
      "FAIL riskNeutral_corner: η* must be b", etaStar, bHi;
  ```
- Guard the hypotheses too — the theorem needs `1 < λ`, `∀j, 0 < i_j`, `0 ≤ a`. `[EXEC]` this exact
  block runs green in 0.32 s alongside the menu loop.
- **`Δᵢ = 200` is currently unreachable through `tunablePricingKernel`** (`tickSpacingDomain /s1*s60/`);
  fixing that domain is a prerequisite for this assertion, not an optional cleanup.

**If `γ > 0` (the interior case):**
- Assert `mvMax`, `prodMin`/`prodMax`/`prodSpread` over the tie set, and `nTies`. Do not assert
  coordinates.
- `[EXEC]` `prodSpread` is `8.5e-7` at `objScale = 1` and `9.9e-13` at `objScale = 1e6` — the tolerance
  on the product assertion is a direct function of the objective scaling, so scale first, then set it.

## Version compatibility

| Component | Version (verified) | Notes |
|---|---|---|
| GAMS Base Module | **54.1.0 37378ce0 Jun 15 2026**, LEG x86 64bit/Linux | `[EXEC]` matches `Scalar gamsVersion / 54.1 /` in `_PayoffScaffolding.gms` |
| CONOPT (via `option nlp = conopt`) | **4.39.0** | `[EXEC]` from the solver banner. `option nlp = conopt` resolves to CONOPT 4, **not** CONOPT 3 — `CONOPT3` is a separate entry in `gmscmpun.txt` |
| CONOPT capabilities | `LP RMIP NLP CNS DNLP RMINLP QCP RMIQCP` | `[DOC — gmscmpun.txt]` **No MINLP, no MIP** |
| CONOPT `Tol_Optimality` | default `1e-7` | `[DOC — S_CONOPT.html]` The governing constant for every accuracy claim in this document |
| CONOPT `Lim_Variable` | default `1e15` | `[DOC]` Exceeding it ⟹ `modelStat = 3` Unbounded |
| CONOPT `Tol_Scale_Min` / `Tol_Scale_Max` | `1` / `1e15` (prose) vs `1e25` (options table) | `[DOC]` **The bundled S_CONOPT.html contradicts itself** — §Scaling says `1.e15`, the options table says `1.e25`. Not resolved; irrelevant to the recommendations here (both are far above Q96) but worth knowing before relying on `Tol_Scale_Max` |
| License | **Demo** — NLP capped at 1000 vars / 1000 constraints | `[EXEC]` + `[DOC — UG_License.html]`. A 200-point menu loop uses ~2 variables per solve; a 200-binary MINLP uses ~202. Both fit. BARON does not |

## Sources

- `/usr/gams/gams54.1_linux_x64_64_sfx/docs/S_CONOPT.html` — `Tol_Optimality` default and the verbatim
  "values of the variables can be less accurate due to a flat objective function" statement;
  `Lim_Variable`; `Tol_Scale_Min`/`Max`; `Mtd_Scale`; the model/solve status message catalogue. **HIGH**
- `/usr/gams/gams54.1_linux_x64_64_sfx/docs/UG_LanguageFeatures.html` §Model Scaling — The Scale Option —
  `scaleopt`, `.scale` semantics `V_a = V_u/c`, `G_a = G_u/d`, derivative rule `c/d`, the reference-value
  scale-factor pattern, the `> 1e-20` constraint, "discrete variables cannot be scaled". **HIGH**
- `/usr/gams/gams54.1_linux_x64_64_sfx/docs/UG_NLP_GoodFormulations.html` — scaling goals, "inspect the
  coefficients in the equation listing", initial-value guidance. **HIGH**
- `/usr/gams/gams54.1_linux_x64_64_sfx/docs/UG_GamsCall.html` — the complete `%modelStat.*%`,
  `%solveStat.*%`, `%solPrint.*%`, `%solveLink.*%` compile-time constant tables. **HIGH**
- `/usr/gams/gams54.1_linux_x64_64_sfx/docs/UG_License.html` §Additional Solver Limits — demo/community
  model-size caps, per-solver restrictions. **HIGH**
- `/usr/gams/gams54.1_linux_x64_64_sfx/docs/UG_Parameters.html`, `UG_Equations.html`, `UG_Variables.html`,
  `UG_ExecErrPerformance.html`, `T_LIBINCLUDE_RANK.html`, `T_GDXDUMP.html`. **HIGH**
- `/usr/gams/gams54.1_linux_x64_64_sfx/gmscmpun.txt` — authoritative per-solver model-type capability
  table on this install. **HIGH**
- 17 experiment programs executed against this install, retained at
  `/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-wt-gams/6b182941-a422-411e-931d-d359de8b6168/scratchpad/exp/`
  (`e1_argmax`, `e3_minlp`, `e4_q96var`, `e5_menu`, `e6_gamma`, `e7_ties`, `e8_exact`, `e9_precision`,
  `e10_robust`, `e11_status`, `e12_kernel`, `e13_minlp`, `e14_optfile`, `e15_range`, `e16_gdx`,
  `e17_reference`). Scratchpad is session-scoped — **re-run before relying on the numbers in a future
  session**. **HIGH**
- Repo baselines re-run green: `model/payoff/eta_pi_trader_zero_slippage.gms`,
  `model/payoff/eta_pi_trader_band_monotone_large.gms`. **HIGH**
- Web search for a canonical GAMS argmax idiom returned nothing beyond the `smin`/`smax` documentation
  already read locally — **no external idiom was found that improves on the recommendation**. **LOW**
  (negative result, reported for honesty)

## Gaps and open questions

- `[INFER]` **A second NLP solver has not been tried.** IPOPT, MINOS, SNOPT and PATHNLP are all bundled
  and all declare NLP capability. A one-line `option nlp = ipopt;` cross-check would independently
  corroborate the menu-loop argmax at near-zero cost. Recommended as a task, not a phase.
- **Not verified: how the MV objective behaves once the η̃-measure `w` is itself a function of `(Δᵢ, η)`.**
  All experiments used a constant `w` (which is exactly `ComparativeStatics`'s `fun _ => θ.w`), so
  `continuous_J`'s `hw` hypothesis was trivially satisfied. If `w` becomes state-dependent, the
  `Δᵢ·η`-only dependence — and therefore the entire tie analysis — may not survive. **Re-run the γ-sweep
  the moment `w` stops being constant.**
- **Not verified: whether `retVol` / `liqShare` (the `vol_markets` hooks named in PROJECT.md) preserve
  the product structure.** `retVol θ P η = δ·P^(η−1)` depends on `η` *alone*, not on `Δᵢ·η`, so coupling
  it into the objective would **break the degeneracy** and make the optimizer unique. That would be a
  desirable outcome and is worth checking early — it may retire the whole non-uniqueness problem.
- **The `Tol_Scale_Max` documentation contradiction** (`1e15` vs `1e25`) was not resolved against GAMS
  support or a changelog.
- **Demo-license headroom was not stress-tested.** The 1000-variable NLP cap was never approached
  (largest model: 202 variables). If the menu grows or `Fin m` (the tick band) grows, re-check.
- **`tickSpacingDomain /s1*s60/` vs the Lean `[1,200]` box** is recorded here as a blocker for F3, but the
  *correct* fix (extend the domain vs. re-index vs. change the Lean bound) is a modelling decision this
  research does not make. It compounds with the two other unresolved contradictions already listed in
  PROJECT.md (the `maxTick`/`MIN_TICK` conflict and the η WAD-vs-Q0.128 conflict).

---
*Stack research for: GAMS 54.1 solve idioms for two-control CFMM parameter optimization under CONOPT*
*Researched: 2026-07-27*
