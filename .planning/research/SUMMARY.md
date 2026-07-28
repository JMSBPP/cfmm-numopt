# Project Research Summary

**Project:** cfmm-gams — Dual-Representation Geometry for CFMM Parameter Solving
**Domain:** Executable-assertion algebraic modelling in GAMS 54.1, mirroring a Lean 4 real-valued specification and EVM 256-bit fixed-point semantics
**Researched:** 2026-07-27
**Confidence:** HIGH (all four research files are execution-based, not recall-based; ~90 probe programs run against the pinned GAMS 54.1.0 `37378ce0`)

## Executive Summary

This is a **verification project wearing a modelling project's clothes**. The Lean substrate is fully proven (`ComparativeStatics` 15/0 `sorry`, `MeanVarianceOptimization` 10/0, `vol_markets` 169/0), so almost nothing here is mathematical discovery — it is the construction of a GAMS layer whose numbers can be *trusted* as both theorem instances and on-chain predictions. Four independent researchers each executed probes against the real toolchain rather than recalling syntax, and they converge on one uncomfortable finding: **the repo's current green is substantially uninformative.** Three gates (`payoff-fixtures`, `spec-preflight`, `spec-preflight-band`) are false-pass by construction; the strictest-looking tolerance in the codebase (`zeroTolerance = 1e-20`) is in fact its weakest assertion by 900×; the global `diffTolerance = 1e-12` holds by two independent numerical accidents; and two exported provenance scalars (`etaQ128`, `tieBreaking`) are read by no assignment anywhere and are therefore fabricated claims sitting inside committed binary artifacts.

The recommended approach follows directly. **Do not port anything until the measuring instruments are honest.** Sequence: fix the exit-code gates (a Makefile change, hours); unify the number representation into one canonical `Scales.gms` built from `power(2,k)` and never `$eval`; build the assertion vocabulary and a degree-correct, exponent-dependent tolerance policy *before* 134 theorem units are born using it. Only then does the `(Δᵢ, η)` solve become meaningful — and it must be scoped honestly, because the measured payoff depends on both controls **only through the product `Δᵢ·η`**, giving 62 equally-optimal coordinate pairs at γ=100 and a Lean side that concedes the point (`g θ` is `Classical.choice`, no uniqueness lemma anywhere). The solve phase can deliver the optimal *value*, the *product*, the tie count, and the γ=0 corner. It cannot deliver identified coordinates, and a roadmap that promises them is promising something the mathematics does not contain.

The dominant risk class is **silent wrongness, not loud failure**. Arithmetic overflow does not produce `INF` — an `x = INF` guard tests false and the run continues at rc=0. A scale error of exactly 2^96 or 2^128 produces *no precision signal at all*, because multiplying by a power of two is exact in IEEE-754, so scale bugs must be caught by magnitude assertions and can never be caught by tolerance assertions. `UNDF` satisfies both sides of a comparison, so counting successes is unsafe and only counting failures is safe. A one-sided `|x| < ε` zero assertion cannot fire on a collapsed computation (`INF − INF = 0` passes a 1e-20 test). Every mitigation is cheap and executable; none of them exist today. The single highest-value line in all four documents is the exponent-budget guard `abort$(|i|·Δᵢmax > diffTolerance / 1.101e-17)`, which converts an unstated assumption into a red build.

## Verdicts

Four cross-document items required explicit resolution. Each verdict is binding on the roadmap.

### V1 — Tick-spacing domain shape: **two levels, not one**

**Verdict.** Replace `Set tickSpacingDomain /s1*s60/` with a **parent theorem grid `/s1*s200/` carrying values as data, plus a declared subset `tickSpacingMenu(tickSpacingAll) / s1, s10, s60, s200 /`** for the deployable Uniswap fee-tier spacings. Neither research prescription works alone: STACK.md correctly read the Lean statement as `Finset.Icc (1:ℤ) 200` — a 200-element finite menu, which is what `mvBest(menu)`, the sliding-window monotonicity profiles (T1/T1L), and the `Δᵢ = 190` band fixture are all stated over — so collapsing to four elements would break the existing green band test and make the comparative-statics profile inexpressible. PITFALLS.md is equally correct that optimising over `[10,190]` optimises over 188 spacings no pool can be deployed with, making T2/T3's "argmin at 10 / argmax at 190" statements about a fictitious object. The two-level structure keeps both true: the theorem is asserted on the parent, deployability is asserted on the subset, and the relationship between them is stated rather than conflated.

**Cost.** `tickSpacingVal(d) = ord(d)` must become data-driven (`ord` is what makes the current 60-grid a continuum in disguise); both committed GDX fixture schemas change and must be re-baselined; every literal `'s10'` / `'k181'` reference is re-checked; and the `(B_ext)` cross-representation obligation grows from 1 covered point to at minimum the 4 menu points (ideally the whole parent), which is a real coverage debt made visible rather than a new one created. T2/T3 must be restated explicitly as claims about the *relaxation*, with a separate menu-restricted claim alongside. Blocking for the `riskNeutral_corner` assertion (F3): `tunablePricingKernel` today **cannot express `Δᵢ = 200` at all**, so the corner the theorem proves is currently unreachable.

### V2 — `zeroTolerance = 1e-20`: **not a tolerance, an artifact of algebraic degree**

**Combined finding.** ARCHITECTURE.md and PITFALLS.md reached the same conclusion by different routes and neither knew of the other. ARCHITECTURE measured, on the repo's own fixture at the analytic optimum, that the *squared* payoff is `1.73334e-33` (clears 1e-20) while the *unsquared* residual is `4.16334e-17` (does not) — so the constant is satisfiable only because the payoff is a square. PITFALLS computed the same fact backwards: a tolerance τ on a squared quantity is `√τ` on the residual, so 1e-20 is a 1e-10 absolute / **9e-10 relative** residual tolerance — **900× weaker than `diffTolerance = 1e-12`** in the very same scaffolding file, with thirteen orders of magnitude of slack over the 3.7e-16 actually achieved. Independent corroboration by two routes elevates this from an observation to a settled defect: **the strictest-looking number in the repo is its weakest assertion, and the weakness is invisible because it hides behind `sqr()`.**

**Required policy change (four parts, all binding).** (1) Assert at the **residual** level; `sqr()` is for display and GDX only. (2) Replace the global absolute constant with a scale-derived floor `absFloor(scale) = epsSlack · machEps · |scale|`; where a squared quantity genuinely must be asserted, the tolerance is squared too and the symbol is *named* `zeroToleranceSquared`. (3) General rule to codify: **a tolerance may only be applied at the same algebraic degree as the quantity it was calibrated for.** (4) Every zero assertion gets a **non-degeneracy companion** at a nearby off-optimum point asserting strict positivity and a magnitude floor — because `abort$(|π| > ε)` can never fire on a collapsed computation, and `INF − INF = 0` demonstrably passes a 1e-20 test. Enforce with a lint: any `abort$` whose argument comes from a macro whose body contains `sqr(` is a review failure. Keep `zeroTolerance / 1e-20 /` as a named constant for compatibility, with its assumption documented in the same file.

### V3 — `diffTolerance = 1e-12`: **must become exponent-dependent; it is currently two accidents**

**Verdict.** Not a sound global constant. GAMS computes `x**y` as `exp(y·log x)`, so the −1.101e-17 relative error in `fl(1.0001)` is amplified **linearly and with a systematic sign** by the exponent: `rel_err(λ**n) ≈ 1.101e-17 · n`. Measured, not modelled: −1.2556e-13 at the band fixture (`i·Δᵢ = 11,400`, 8.0× margin), −9.771e-12 at Uniswap MAX_TICK (`887,272`, **9.8× over budget**), with the budget exhausted at exponent **≈ 90,800** — a value *inside the domain the repo already declares* (`diMaxInt = 200` with any tick `i > 454`). The green is additionally an accident of λ's binary representation: `fl(1.0001)` lands at 0.099 ulp, roughly 10× luckier than typical, and **3 of 6 plausible alternative WAD λ values flip the existing band test red with no other edit.** The tolerance is therefore partly a property of the number 1.0001 and not of the code.

**Required change.** Ship the guard as the minimum (`Scalar tolExponentBudget = diffTolerance / 1.101e-17; abort$(|iCfg| · diMaxBand > tolExponentBudget)`) and move to a function as the target: `tol(n) = max(3 · 1.101e-17 · |n|, 4 / sqrtPX96, 1e-15)`. The second term is not decoration — below tick ≈ −596,180 the **EVM's own Q96 quantization becomes coarser than a double's ulp** (2.33e-10 at `MIN_SQRT_RATIO = 4295128739`), so there no tolerance tighter than `1/sqrtPX96` is meaningful in *either* direction.

**What the roadmap must therefore forbid.** No phase may state "agreement at 1e-12" as an unqualified acceptance criterion. Every tolerance claim must ship with (a) the exponent range it is valid over, (b) the λ it was calibrated at, and (c) the budget guard as executable code. No phase touching Uniswap's real tick range may claim 1e-12 at all. See "Phases must not claim" below.

### V4 — Phase ordering: **the hook moves early; the port does not**

**Verdict.** The `vol_markets` *port* stays where PROJECT.md puts it — after the `(Δᵢ, η)` solve. But the **identifiability hook moves into the solve phase**, and the decisive reason is a distinction neither research file made explicitly: `retVol` and `liqShare` are **`ComparativeStatics` members, not `vol_markets` members**. The solve phase is already grounded in `ComparativeStatics.box` / `.g` / `.value`, so coupling `retVol θ P η = δ·P^(η−1)` into the objective introduces **no new module dependency and costs nothing in sequencing.** Since `retVol` depends on η *alone* rather than on the product `Δᵢ·η`, it is the exact structure that breaks the hyperbolic degeneracy and makes the argmax a point instead of a continuum. It should be run as a spike *inside* the solve phase, not deferred behind a 134-theorem port.

The corollary is the more important half of the verdict. **Solving for the two coordinates separately is not well-posed except at γ = 0**, where both saturate. STACK measured 62 equally-optimal `(Δᵢ, η)` pairs at γ=100, all carrying the identical product 6.966; the F1 menu loop and the F2 joint NLP agree on the *value* to 2.2e-16 while returning wildly different *coordinates* at every γ > 0; and Lean makes no uniqueness claim. So the solve phase's deliverable is **value + product `Δᵢ·η` + `nTies` + `prodSpread` + the γ=0 corner** — with `nTies` and `prodSpread` exported to GDX as first-class provenance, because a silent `nTies = 62` is the difference between "we solved it" and "we picked one of 62 equally-good answers." Coordinate identifiability becomes a deliverable *of the coupling*, which means the solve phase is revisited after the spike rather than claimed complete before it.

**Resulting phase order:** 0 → honest gates; 1 → representation unification; 2 → test architecture; then **3 (solve, ending in the identifiability spike) and 4 (moments/ingestion) in parallel** — they share no dependency chain; then 5 → `vol_markets` port, carrying the spike's result, with `Upsilon`/`retVol` promoted early in the port's internal dependency order if the coupling did break the degeneracy; then 6 → the solve revisited to claim coordinates, if and only if it did.

### V5 — Bonus resolution: the "CONOPT can only reach 1e-2" claim

Not in the required set, but STACK and PITFALLS disagree and it directly bounds what a phase may promise. PITFALLS M4 states it as a law: "You can never assert a solved interior optimum against a closed form at 1e-12." STACK measured that **multiplying the objective by 1e10 takes the argmin error from 8.9e-3 to 1.25e-14** across six start points, all reporting `modelStat = 2`, and traces the cause to `Tol_Optimality = 1e-7` against an objective evaluating at ~1e-9 near the optimum — an objective-*scaling* defect, not a solver limitation. **Both are right about different halves.** The square costs half the digits (PITFALLS), and the missing scaling costs the other twelve orders (STACK); the fixes compose. Verdict: after introducing `objScale` targeting `[1e2, 1e6]` (above ~1e8 over-scales and produces discontinuous-derivative warnings), a **1e-9 relative assertion on the continuous value is defensible and the "> 1 tick" tolerance should be retired**; 1e-12 against a closed form remains out of reach unless stationarity is solved as a square CNS system, which CONOPT does support (`CNS` is in its declared capability list). The comment "CONOPT precision on this Q96-flat objective is ~1e-2 relative" states an avoidable bug as a law of nature and must be corrected.

## Key Findings

### Recommended Stack

The stack is fixed (GAMS 54.1.0 + CONOPT 4.39.0) and the research is about *idioms* within it. The governing discovery is that the repo's own kernel is already shaped like the theorem: `tunablePricingKernel(di, i, eta)` takes `Δᵢ` as a **set index into a Parameter** and `η` as a plain factor, so it is by construction "enumerate `Δᵢ`, optimize `η`" — precisely the shape of `exists_mv_optimal_tick_menu`. The formulation that follows is a `loop` over the menu with one CONOPT NLP in `η` per element (200 subsolves in 0.31 s), with a joint 2-D NLP retained only as a cross-check on the *value*. An MINLP is not merely unwise but partly unavailable: `option minlp = conopt;` is a **compile-time error** (`$255`, CONOPT declares no MINLP capability), SBB returns `modelStat = 8` which the repo's existing abort predicate would falsely reject, it cannot honour the `tieBreaking` scalar deterministically, it discards the profile the monotonicity checks operate on, and it is slower anyway.

**Core technologies and idioms:**
- **F1 menu loop (`loop` + `Solve ... using nlp`)** — the primary formulation; the only one that needs nothing but CONOPT, tie-breaks deterministically, and yields the whole comparative-statics profile for GDX export
- **`solveLink = %solveLink.loadLibrary%` + `solPrint = %solPrint.silent%`** — mandatory for any looped solve; measured **14× wall-clock** (4.43 s → 0.31 s over 200 solves) and keeps the `.lst` readable
- **`objScale` wrapping every payoff equation, targeting `[1e2, 1e6]`** — twelve orders of accuracy from one multiplication; see V5
- **`smax` → tie `Set` → `smin`, with a mandatory `card(tieSet) = 0` guard** — there is no `argmax` in GAMS, and an empty `smin`/`smax` returns `+INF`/`−INF` **silently, straight into a GDX fixture**
- **Q96/Q128 confined to `$macro`s and `Parameter`s, never `Variable`s** — CONOPT's `Lim_Variable` default is `1e15`, so Q96 (7.9e28) and Q128 (3.4e38) are 13 and 23 orders past the ceiling. Measured: the naive formulation gives **Solver Failure, `modelStat = 13`, variables silently left at their starting values** — a script exporting them unchecked ships fabricated numbers
- **`gdxdump format=csv dformat=hexbytes`** for any fixture the Solidity side consumes — the default text format truncates to 15 significant digits, which is ~1e-16 relative and wastes most of the 1e-12 budget before comparison begins

**License constraint discovered during verification:** the machine holds a **GAMS Demo license** — NLP capped at 1000 variables / 1000 constraints, and BARON/ANTIGONE/LINDOGLOBAL capped at **50 variables**, making a global-solver cross-check impossible. A 200-point menu loop uses ~2 variables per solve and fits comfortably; do not plan a BARON verification phase without budgeting a license first.

### Expected Features

The moments/ingestion layer is governed by a single constraint that decides its entire architecture: `make compile-gams` compiles every `.gms` under `model/` with `action=c` and `GAMS_SKIP` is empty, so `PricingKernelMoments.gms` **must compile with no data file anywhere on disk**. Compile-time `$gdxIn`/`$load` fails hard (rc=2) whenever the file is absent — which is always, for an undecided source. `execute_loadDC` is therefore the only admissible ingestion verb. That choice then triggers three verified GAMS laws, all of which bite immediately, and all of which are resolved by one pattern: a **model-owned static capacity grid** as the parent, with the producer supplying only membership and values.

**Must have (table stakes):**
- **Static capacity grids `tAll /o1*o4096/`, `winAll /w1*w256/`** — without them `execute_load*` silently returns an empty set at rc=0 and the model computes moments of nothing; `ord()`/lag are also illegal on a runtime-assigned set
- **`execute_loadDC` as the sole ingestion verb** — execution-time (keeps `action=c` green) *and* domain-checked; bare `execute_load` silently drops every off-grid observation (measured: a wrong mean of 100 instead of 101, rc=0)
- **`tObs(tAll)` as a subset, never a bare `Set`** — a set used as a domain cannot be `execute_load`ed (`$188`)
- **`hasRet` mask guarding on the *predecessor's value*** — unguarded log returns divide by zero at the series head, and the guard also handles interior gaps
- **`mean_tick` / `realized_variance` as `Parameter(winAll)`** — the current `$macro` stub has no domain and cannot be unloaded to GDX
- **`rv_bar` normalization** — with blocked windows the first window structurally owns one fewer return (measured `rvCard = 3, 4, 4`), so raw `realized_variance` is **not comparable across windows**
- **Position-weighted `seriesChecksum` re-derived consumer-side** — a plain sum cannot detect a reordered series, which is exactly the demonstrated silent failure mode

**Should have (defer until a real source exists):** producer-supplied `winMap` for calendar windows; `obsTimestamp` + gap detection; rolling/overlapping windows for a control loop; time-scaled RV.

**Defer (v2+):** bipower variation / jump-robust estimators; a multi-pool series dimension (adds an index to every contract symbol for an unvalidated need); annualization (the correct scalar is unknowable without a real sampling frequency); the Python API producer (explicitly out of scope per PROJECT.md).

**Correction to the project record:** PROJECT.md calls `PricingKernelMoments.gms` "an invalid stub." Verified — it **compiles cleanly at rc=0**, because `Set TimeWindow` is legally closed by EOF and the space before `(` makes GAMS parse a zero-argument *text* macro. CI is green on a file that computes nothing, which is materially harder to notice than a syntax error would have been.

### Architecture Approach

The repo's core test architecture is **correct and should be codified essentially as-is** — one execution unit per theorem, `abort$` assertions, `action=ce`, GDX provenance, a registry that deliberately does not aggregate. This is not merely defensible; it is independently the same architecture GAMS Development themselves use for their ~1000-model `testlib` quality suite (`testmod.inc` registry, `quality.gms` orchestrator, one file per test). Crucially it is also **structurally forced, not stylistic**: `$onMulti` cannot rescue aggregation, because it relaxes Set and Parameter re-declaration but `$150 Symbolic equations redefined` is unconditional — so any two theorem units carrying a `Solve` are un-aggregable in GAMS. The process boundary *is* the namespace boundary.

**Major components:**
1. **Orchestration (Makefile/CI)** — exit-code gating, unit discovery, tier partitioning, `gdxdiff`. Owns no assertion logic; assertions live in GAMS
2. **Driver layer (`test/<Name>Test.gms`)** — exactly one `$include` of one theorem unit plus a banner. The unit of process isolation
3. **Theorem-unit layer (`<module>/<lean_name>.gms`)** — fixtures, closed forms, assertions, `Model`/`Solve`, `execute_unload` **as the last statement, after every assertion** (load-bearing: a failed run then leaves no new GDX)
4. **Scaffolding + `_AssertLib.gms` (NEW)** — include-guarded, idempotent, no fixture values; assertion macros with scratch scalars declared once, because **`abort` accepts identifiers only, never expressions** (`abort$(1) "msg", abs(x-y);` is a compile error), which dictates the entire macro design
5. **Kernel and artifact layers** — pure definitions compile-checkable without a solver; committed golden GDX with provenance sets

**The one BLOCKER, independently re-confirmed.** `payoff-fixtures`, `spec-preflight` and `spec-preflight-band` grep the `o=` listing for `Status: (Compilation|Execution) error`. That string is written to the **log stream only, never to the listing** — confirmed for every `lo` value 0/1/2/3/4 — and `lo=0 >/dev/null` destroys it twice over, while the `;` before `if` discards the exit code. Measured end to end: a broken unit returns rc=2, the recipe prints **OK**, and the previously committed `.gdx` survives untouched, so a stale fixture persists behind a green build. The premise behind the workaround is false: `gams` returns **2 on compile error and 3 on execution error**, so the exit code was always trustworthy. The orchestrator independently reproduced this. Fix: `if gams ...; then` with `lo=2 lf=<file>`, and demote the grep to error-message extraction from the *log*.

**The four genuine exit-0-on-failure hazards** that do remain, and must be handled explicitly: `abort.noError` halts silently at rc=0 (**ban by lint**); a non-optimal or infeasible `Solve` returns rc=0 (an infeasible LP gave `modelStat = 19` at rc 0 — hence a mandatory `assertModelOptimal` after every `Solve`); `execute 'cmd'` ignores the child's status (use `execute.checkErrorLevel`); `$call 'cmd'` likewise (use `$call.checkErrorLevel` — note `$onCheckErrorLevel` governs **`$call` only**, not `execute`, a correction to a common misreading).

### Critical Pitfalls

1. **Overflow is silent and does not produce `INF`** — an `x = INF` guard tests false and the run continues at rc=0, so a model that loses hundreds of orders of magnitude reports PASS. GAMS is additionally *inconsistent*: `**` saturates silently while a subsequent `*` raises an overflow error. Avoid with `assertFinite` on every `**` result (threshold well below the saturation point — by the time a value *equals* it, the information is gone) plus `assertUint160`/`assertUint128` on every on-chain-width quantity. **Treat the exact saturation constant as unconfirmed** — see Gaps.
2. **The η scale conflict is the most dangerous representation defect** — WAD (`eta_x_y/unity`) vs Q0.128 (`etaQ128 = 2^127`) differ by `2^128/1e18 ≈ 3.4e20`, and the mismatch is **silent in both directions with plausible-looking results**: η_WAD read as Q0.128 gives 1.47e-21 ≈ 0, collapsing the CES cone to pure cash and the price kernel to a **flat, tick-independent λ^0 = 1** that passes every positivity assertion; η_Q128 read as WAD gives 1.7e20 and drives `λ**(...)` into silent saturation at rc=0. Only a **tick-sensitivity assertion** catches the first, and none exists. Worse, `etaQ128` is already fabricated provenance: it is declared, exported to both committed GDX fixtures, and **read by no computation anywhere** — η = 1/2 is instead hard-coded structurally as a literal `/2` inside `sqrtPX96_at`.
3. **A scale error produces no precision signal at all** — because multiplying by `2^k` is exact in IEEE-754, every Q-scale wrapper in this codebase costs literally nothing, and a *wrong* scale factor shows up only as a magnitude error of exactly 2^96, 2^128 or 3.4e20. **Scale bugs must be caught by magnitude assertions and can never be caught by tolerance assertions.** Corollary: `$eval 2**96` renders through a 15-digit decimal string and is **wrong by exactly 2^45** (orchestrator re-verified: log2 of the difference is 45.0000, while `power(2,96)` is exact) — so a canonical constants module built from compile-time `$eval` macros would be silently wrong, and worse, would destroy the exactness of every power-of-two bridge in the codebase. **Hard rule: binary scale constants come from `power(2,k)` at execution time or from a GDX, never from `$eval`, `$set`, or a decimal literal.**
4. **The declared tick bounds are numerically fatal, not merely wrong** — `primitives.gms` declares `maxTick = 16777215` (evaluates to `UNDF` with an overflow error) and `minTick = +8388607`, a **positive minimum** identical to `PricingKernel`'s `MAX_TICK`. `LiquidityKernel.gms:36` already consumes the unusable one. Uniswap's real bounds are ±887,272, chosen precisely so the sqrt price fits a `uint160`. Fix with four *distinctly named* concepts (`INT24_MIN/MAX` storage, `TICK_MIN/MAX` usable, `SQRT_RATIO_MIN/MAX` derived) plus three consistency aborts — the single line `abort$(INT24_MIN <> -(INT24_MAX+1))` would have caught the off-by-one at first run.
5. **`UNDF` satisfies both sides of a comparison**, so `1$(UNDF > 1e-12)` and `1$(UNDF <= 1e-12)` are *both* 1. **Rule: always count failures, never count successes.** The repo happens to use the safe idiom everywhere; codify it before someone doesn't. Related, and equally silent: lag/lead off the end of a Set yields 0, which makes an *increasing* monotonicity check fail loudly at the boundary (annoying, safe) and a *decreasing* one **pass silently** (dangerous) — extract the boundary guard into one macro rather than the three hand-written copies that exist today.

## Implications for Roadmap

### Phase 0: Make the gates honest
**Rationale:** Until this lands, every other gate's green is uninformative — including any gate added later. It is a Makefile change plus two lint greps, measured in hours, and it is the cheapest high-value work in the entire project.
**Delivers:** `if gams ...; then` exit-code gating with `lo=2 lf=<file>` log capture in `payoff-fixtures` / `spec-preflight` / `spec-preflight-band`; the grep demoted to error extraction from the log; CI lints banning `abort.noError`, `$onMulti*`, `execError =` assignment, and bare `execute`/`$call`.
**Avoids:** The false-pass gate (ARCHITECTURE BLOCKER); `execError = 0` restoring exit 0 (M1); `$onMultiR` silently overriding a canonical definition (P8).
**Research flag:** None. Executable recipe already written and verified.

### Phase 1: Representation unification
**Rationale:** Owns 5 of the 9 critical pitfalls including the most dangerous one, and **every other phase's assertions are only as trustworthy as the constants they compare against.** PITFALLS is unambiguous that this must block everything else.
**Delivers:** One canonical `model/Scales.gms` (include-guarded, sole definer, `power(2,k)` only); η canonicalized to Q0.128 with `etaWadToQ128` as the *only* bridge plus a tick-sensitivity assertion so an η→0 collapse can never pass again; the four-concept tick module with consistency aborts; `tickVal` derived from `card(tick)` rather than the magic constant 121; the `inventory` set renamed (**never** `$onMultiR`); the V1 two-level tick-spacing domain; `assert-before-export` enforced so `etaQ128` and `tieBreaking` either acquire a reader or leave the GDX.
**Avoids:** Pitfalls 2, 6, 8, 9 and the η verdict — all S1 "silently produces a wrong number that a green test reports as correct."
**Research flag:** None. PITFALLS supplies the concrete `Scales.gms` design and the lint script.

### Phase 2: Test architecture
**Rationale:** Owns the remaining 4 critical pitfalls and supplies the vocabulary every later phase consumes. **134 units must be *born* using these macros** — retrofitting 134 files is the expensive path, and every ported theorem picks a tolerance on day one, so the rule must be right first.
**Delivers:** `model/test/_AssertLib.gms` (hard + soft assertion macros, `assertFinite`, `assertUintN`, `assertIntegral`, `assertAdd0Branch`, `assertModelOptimal`, the sliding-window macro); the V2 degree-correct tolerance policy with `absFloor(scale)` and non-degeneracy companions; the V3 exponent-budget guard and `kernelTol(n)`; the residual-signature taxonomy separating rounding-direction bias from λ amplification from FP noise from scale bugs; a machine-readable registry with `unitTier`/`unitSkip` carrying **reason strings**; tiered `test-gams-pure` / `test-gams-nlp` with `STRICT=1` for CI; the `check-fixtures` protocol via `gdxdiff` with `execute_unload` last.
**Uses:** Soft `check*` + `assertNoFailures` — the single biggest usability win measured, collapsing up to 12 edit-run cycles into one.
**Research flag:** None. ARCHITECTURE supplies `_AssertLib.gms` as executed source.

### Phase 3: The `(Δᵢ, η)` solve — value, product, ties, corner *(parallel with Phase 4)*
**Rationale:** First phase whose green means anything. Scoped per V4: the payoff depends on the controls only through `Δᵢ·η`, so this phase delivers what is identified and explicitly does not deliver what is not.
**Delivers:** F1 menu loop with `solveLink=loadLibrary`, deterministic per-point restart (never warm-start — it makes the result path-dependent and biases toward the previous tie-set member), `objScale` in `[1e2, 1e6]`; `TIED(...)` tolerance ties for solve-derived values with exact `=` retained only for single-`Parameter`-assignment values (measured: exact ties under-count 30 vs 62); the `card(tieSet) = 0` guard; F2 as a *value* cross-check only; F3 as a pure `abort$` on the proven γ=0 corner, guarded on its hypotheses; `nTies` / `prodMin` / `prodMax` / `prodSpread` / `numInfes` / `iterUsd` exported to GDX as first-class provenance. **Ends with the identifiability spike**: couple `retVol θ P η = δ·P^(η−1)` (a `ComparativeStatics` member, so free of new dependencies) into the objective and measure whether `nTies` and `prodSpread` collapse.
**Avoids:** Asserting coordinates at γ > 0; the CONOPT flat-objective defect (V5); Q96/Q128 promoted to `Variable`s; `**` domain holes at solver trial points (`abort$(base <= 0)` and `M.numDomErr = 0`); the demo-license 1000/1000 ceiling asserted before every `Solve`.
**Research flag:** **NEEDS `/gsd:research-phase`.** Three open questions: whether the `retVol` coupling actually breaks the degeneracy; whether stationarity is formulable as a CNS square system under CONOPT (CNS *is* in its capability list, untested here); and the `objScale` sweet spot on the real MV objective rather than the probe.

### Phase 4: Moments / ingestion *(parallel with Phase 3)*
**Rationale:** Shares no dependency chain with the solve — its chain is static grids → legal `ord`/lag → `hasRet` → `realized_variance` — so it parallelizes cleanly once Phases 1–2 land. It must precede `vol_markets` because `Upsilon` consumes realized variance, and because negative ticks (real half the time) are where the `floor`-vs-`trunc` compression trap bites.
**Delivers:** `_MomentsContract.gms` (declarations only), `MomentsKernel.gms`, a replaced `PricingKernelMoments.gms`; `execute_loadDC` ingestion with contract `abort$`s; `mean_tick` / `realized_variance` / `rv_bar`; the free `RV_log = (log λ)² · RV_tick` identity assertion (measured 4.01e-13, inside budget) — the *only* independent check available before a real source exists; one deterministic producer so the contract has a real client; the fixed `tickPerPriceKernel` (round-trips at 1.11e-15).
**Acceptance test for the whole design:** `make compile-gams` green with `model/data/` absent.
**Avoids:** All three silent-empty ingestion failure modes; `$offOrder` (which "works" but hands ordering back to the producer, the exact determinism hole demonstrated); committing a churning production GDX.
**Research flag:** **LIGHT.** Formulations are executed end-to-end; open items are grid sizing (`winMap` is O(|winAll|·|tAll|) worst case, unmeasured) and the producer choice, which is a Plank-schema dependency.

### Phase 5: `vol_markets` port
**Rationale:** Largest phase (9 modules, 134 theorems) and the one that inherits the most from every predecessor. Carries the Phase 3 spike result: if the coupling broke the degeneracy, `Upsilon`/`retVol` are promoted early in the port's internal dependency order.
**Delivers:** `PosSpec → Main → Flow → RiskDesign → GeomProfile → Panoptic → FeeSchedule → Upsilon → VolInstrument`, each as a per-theorem execution unit born using `_AssertLib.gms`.
**Avoids:** M7 (the `LiquidityKernel` geometric normaliser is singular at ξ=1 and semantically empty at ι=1 — guard before building on it); M5 (CONOPT scaling — read the equation listing once per new unit); the demo-license ceiling, which becomes a hard wall here rather than an invisible one.
**Research flag:** **NEEDS `/gsd:research-phase`.** The pricing-kernel ↔ volatility link **does not exist in Lean** (`vol_markets` is import-disjoint from `exp/`) and is established in GAMS via shared symbols and `abort$` — that bridge is unspecified and is the phase's real risk.

### Phase 6: Coordinate identification *(conditional)*
**Rationale:** Exists if and only if the Phase 3 spike showed the coupling breaks the degeneracy. Revisits the solve to claim `(Δᵢ*, η*)` at γ > 0 with a uniqueness argument rather than `Classical.choice`.
**Research flag:** Determined by Phase 3's result; cannot be scoped before it.

### Phase Ordering Rationale

- **Instrument honesty precedes measurement.** Phases 0–2 produce no model results at all. That is the point: three of the current gates cannot fail, the strictest tolerance is the weakest assertion, and the canonical constants are contradictory. Any modelling result produced before these land is unfalsifiable.
- **Representation before assertion before solve** is a strict dependency, not a preference. An assertion compares against a constant; if the constant is ambiguous (η at two scales, four contradictory tick bounds), the assertion is decorative. PITFALLS reaches this independently: representation unification owns 5 of 9 criticals and "every other phase's assertions are only as trustworthy as the constants they compare against."
- **Phases 3 and 4 parallelize** because FEATURES shows the ingestion dependency chain is entirely self-contained (static grids → lag legality → returns → RV) and shares nothing with the solve. This is the only genuine parallelism available and it should be taken.
- **The port is last because it inherits everything.** 134 units born without `_AssertLib.gms`, without a degree-correct tolerance policy, and without canonical scales would each need retrofitting — the expensive path, multiplied by 134.
- **Grouping follows the namespace constraint.** One process per theorem is not a style choice; `$onMulti` provably cannot rescue aggregation of solver-bearing units (`$150` is unconditional). Every phase's file layout is therefore forced, which removes a whole category of roadmap debate.

### Research Flags

**Needs `/gsd:research-phase` during planning:**
- **Phase 3 (the solve)** — identifiability under `retVol` coupling; CNS stationarity formulation; `objScale` calibration on the real objective
- **Phase 5 (`vol_markets` port)** — the pricing-kernel ↔ volatility bridge has no Lean counterpart and must be *designed* in GAMS

**Light research only:**
- **Phase 4 (moments)** — grid sizing and `winMap` density; the producer choice is blocked on the Plank schema

**Standard patterns, skip research:**
- **Phases 0, 1, 2** — ARCHITECTURE and PITFALLS already deliver executed, copy-ready prescriptions: the corrected Makefile recipe, the full `_AssertLib.gms` source, and the `Scales.gms` design with its lint script. There is nothing left to research; only to implement.

## Blocking prerequisites

Ordered. Each must be true before the `vol_markets` port may start.

1. **The gates fail when they should.** Exit-code gating in all three affected targets; a deliberately broken unit turns the build red. Without this, 134 units' green is uninformative.
2. **Lints active** — `abort.noError`, `$onMulti*`, `execError =`, bare `execute`/`$call`, and canonical-constant redefinition outside `Scales.gms`.
3. **One canonical `Scales.gms`**, built from `power(2,k)` (never `$eval`), sole definer of every scale, bound, and menu.
4. **η canonicalized to a single representation** with one named bridge, plus a tick-sensitivity assertion that fails if η collapses to 0.
5. **Tick bounds resolved** into four distinctly named concepts with consistency aborts; `LiquidityKernel.gms:36` repointed off the unusable `maxTick`.
6. **The V1 two-level tick-spacing domain** in place, with `Δᵢ = 200` expressible and the deployable menu declared as a subset.
7. **`_AssertLib.gms` adopted by the two existing units** — proving the macros work on real fixtures before 134 more depend on them.
8. **Degree-correct tolerance policy** — residual-level assertions, `absFloor(scale)`, non-degeneracy companions, `zeroToleranceSquared` named where a square is genuinely asserted.
9. **Exponent-budget guard shipped** (`tolExponentBudget`), with `kernelTol(n)` as the target form.
10. **Machine-readable registry + tiered targets + `STRICT=1`** — otherwise 134 units are unmanageable and skipped units become invisible in a green summary.
11. **Assert-before-export enforced** — every symbol in an `execute_unload` list is read by an assignment or an `abort$` in the same unit; `etaQ128` and `tieBreaking` resolved.
12. **Moments layer landed** — `Upsilon` consumes realized variance, and the negative-tick `floor`-vs-`trunc` compression semantics are settled where they actually bite.
13. **The Phase 3 identifiability result recorded** — determines whether `retVol`/`Upsilon` are promoted early in the port's dependency order.
14. **`LiquidityKernel` ξ→1 singularity guarded** — the port builds directly on this module.
15. **Demo-license position decided** — model size asserted below 1000/1000 before every `Solve`, or a licensed runner budgeted. A BARON global cross-check is impossible at the 50-variable cap and must not appear in any plan.

## Phases must not claim

Statements a phase would be **wrong** to promise, each with the measurement that forbids it.

- **Bit-exact GAMS↔EVM equality.** The bottom ~43 bits of every Q96 sqrt price and ~75 bits of every Q128 value are structurally absent from a binary64. Already Out of Scope in PROJECT.md; restated here because the *reason* matters — the loss is in the transcendental kernel, not in the Q-scaling, which is exact.
- **A uniquely-identified `(Δᵢ*, η*)` anywhere except γ = 0.** Measured 62 equally-optimal coordinate pairs at γ=100 sharing one product; F1 and F2 disagree on coordinates at every γ > 0 while agreeing on value to 2.2e-16; Lean's `g θ` is `Classical.choice` with no uniqueness lemma. Assert value, product, and `nTies`. Never coordinates.
- **A global `1e-12` tolerance valid at every exponent.** Exhausted at `i·Δᵢ ≈ 90,800`, which is inside the already-declared domain; 9.8× over at Uniswap MAX_TICK; and 3 of 6 alternative λ values flip the existing band test red with no other edit.
- **Any tolerance tighter than `1/sqrtPX96` below tick ≈ −596,180.** There the EVM's own Q96 grid (2.33e-10 at `MIN_SQRT_RATIO`) is coarser than a double's ulp, and no tolerance is meaningful in either direction.
- **An interior NLP argmin asserted against a closed form at 1e-12.** Defensible at ~1e-9 *after* `objScale` (measured 1.25e-14 on the probe); never before scaling; and 1e-12 requires solving stationarity as a square system rather than minimising the square.
- **That a green build excludes silent overflow.** Overflow does not yield `INF` — an `x = INF` guard tests false and the run continues at rc=0. Guard on *magnitude* with `assertFinite`, and do not hard-code any specific saturation constant as the detection mechanism (see Gaps).
- **That a canonical constants module can be built at compile time.** `$eval 2**96` is wrong by exactly 2^45; `power(2,96)` is exact. Both independently re-verified.
- **That an exported provenance scalar means anything.** Unless an assignment or assertion in the same unit reads it, it is a fabricated claim in a binary artifact — `etaQ128` and `tieBreaking` fail this today, in both committed fixtures.
- **That the two representations "agree" on the strength of a single-point check.** `(B_ext)` covers 1 of the 190 band points; 130 points have no cross-representation check of any kind. Additionally, `P_Lean_at` and `sqrtPX96_at` **share `fl(1.0001)`, so the λ error is common-mode and cancels between them** — the current Lean↔Plank checks structurally cannot see the error they appear to bound. Only a GAMS↔EVM diff can.
- **That `spec-preflight` says anything about the GAMS side.** The sorry/admit gate proves the *Lean* module is sound. It is silent on whether the GAMS macro computes the same function.
- **That an MINLP or a global-solver cross-check is available.** `option minlp = conopt` is a compile error (`$255`); BARON is capped at 50 variables on this license.
- **That the `priceImpactKernel_Add0` mirror covers the EVM function.** It models only the `mulDivRoundingUp` branch; the `divRoundingUp` fallback is a *different formula*, and it is reachable at the top of the tick range for a large-supply 18-decimal token. It is also homogeneous of degree 0 in `(L, dx)` while the EVM function is not — so a GAMS test green at `L = 0.1` says nothing about the on-chain call.
- **That rounding direction is negligible.** True only in the current fixture regime (price ≈ 1, `L = 1e18`, 18 decimals, 13 orders below tolerance). It is *dominant* at low ticks, at thin liquidity (`L < 1e12`), and on any non-18-decimal token (USDC 1e-6, WBTC 1e-8 — both over budget on a single wei).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | 17 experiment programs executed against GAMS 54.1.0 / CONOPT 4.39.0, cross-read against the *bundled* docs for exactly this build; `[EXEC]`/`[DOC]`/`[INFER]` marked inline. Caveat: experiments live in a session-scoped scratchpad and must be re-run before being relied on in a future session |
| Features | **HIGH** | Every syntax claim executed; error codes (`$510/$502`, `$188`, `$197`, `$141`, `$125`), exit codes and numeric results quoted verbatim; formulations verified end to end against hand computation. Two web-doc claims marked MEDIUM and corroborating only |
| Architecture | **HIGH** | ~40 purpose-built probes; cross-read against GAMS Development's own `testlib`/`quality.gms`; `_AssertLib.gms` executed as written. The one BLOCKER was **independently re-confirmed by the orchestrator**. Honest self-reported limits: demo license only, `gdxdiff` rc set incomplete, no timing at 134 units |
| Pitfalls | **HIGH** for GAMS behaviour and Uniswap semantics; **MEDIUM** on intent | 15 probe programs plus exact-arithmetic references at 80 digits and a faithful `TickMath.getSqrtRatioAtTick` reimplementation; Uniswap claims read from `v3-core` source. MEDIUM only where the document itself flags intent (the `Q128` liquidity labelling, which needs Plank-side confirmation) |

**Overall confidence:** **HIGH.** The unusual property of this research set is that it is adversarial toward the repo rather than toward alternatives — each researcher tried to make the existing green fail, and three of the four succeeded. Two findings (the false-pass gate, `$eval` lossiness) were re-verified by a fifth party. Where the documents disagreed, the disagreements were about *shape* and *scope* rather than about measured numbers, which is the healthy kind.

### Gaps to Address

- **The exact overflow saturation constant is single-source.** PITFALLS reports GAMS saturating at `1.0e299`; the orchestrator observed `UNDF` instead and did not reproduce the specific value. The *behavioural* claim — not `INF`, not an error, rc=0, silently continues — **is** corroborated. **Handling:** guards must key on a magnitude threshold plus `assertFinite`, never on the literal constant; a CI grep for the saturation value is a supplement, not the mechanism. Re-probe during Phase 2.
- **The η̃-measure `w` was constant in every experiment.** This is the **single largest open risk to Verdict 4**: `continuous_J`'s `hw` hypothesis was trivially satisfied, so if `w` becomes state-dependent the `Δᵢ·η`-only dependence — and therefore the entire tie analysis and the identifiability argument — may not survive. **Handling:** re-run the γ-sweep the moment `w` stops being constant, and treat the Phase 3 scoping as provisional until then.
- **Whether the Plank harness genuinely uses a Q128.128 notional.** Determines whether `LbarQ128 = 2^128` / `DICfgQ128 = 2^128` (each exactly one greater than `uint128` max) is a naming defect or a semantic one. **Handling:** cross-session confirmation with the Plank track before renaming, per the ownership map.
- **No second NLP solver cross-check.** IPOPT, MINOS, SNOPT and PATHNLP are all bundled; `option nlp = ipopt;` would corroborate the menu-loop argmax at near-zero cost. **Handling:** a task inside Phase 3, not a phase.
- **Grid sizing for `tAll /o1*o4096/` and `winAll /w1*w256/` is a placeholder.** `winMap` is O(|winAll|·|tAll|) worst case and was never measured. **Handling:** measure before enlarging the grids in Phase 4.
- **Demo-license headroom was never approached** (largest model built: 202 variables against a 1000 ceiling). **Handling:** assert model size before every `Solve` from Phase 3 onward; the ceiling becomes a hard wall in Phase 5.
- **The `Tol_Scale_Max` documentation contradicts itself** (`1e15` in prose, `1e25` in the options table) in the bundled 54.1 docs. **Handling:** irrelevant to every current recommendation (both are far above Q96); note it before relying on `Tol_Scale_Max`.
- **`$loadDC` compile-time domain-violation behaviour** was not exercised against an off-grid GDX. **Handling:** low risk (it is the compile-time analogue of a verified behaviour); confirm if a producer file ever needs it.
- **Origin of the "gams exits 0 on compile error" belief** — ARCHITECTURE could not reproduce it for any ordinary compile error and hypothesized shell-level `$?` clobbering. The orchestrator's confirmation that the `;` before `if` discards the exit code makes this the near-certain explanation. **Handling:** treat as resolved; the workaround it justified is being removed regardless.

## Sources

### Primary (HIGH confidence)

- **GAMS 54.1.0 `37378ce0 Jun 15 2026`, LEG x86 64bit/Linux, executed locally** — ~90 probe programs across the four research tracks covering exit codes, `action=c`/`ce`, `$onMulti`, `$macro` semantics, `abort` payload restrictions, `execute_load*` phase behaviour and the three runtime-set laws, `ord`/lag/lead, `power`/`round`/`trunc`/`floor`/`mod`, `**` domain errors, overflow and `INF`/`UNDF` semantics, `$eval` precision, GDX round-trip exactness, `gdxdiff` return codes, `system.SolverPlatformMap`, and CONOPT behaviour on the repo's own `payoffEq`
- `/usr/gams/gams54.1_linux_x64_64_sfx/docs/` — the bundled documentation for *exactly this build*: `S_CONOPT.html` (`Tol_Optimality`, `Lim_Variable`, `Tol_Scale_Min/Max`, status catalogue), `UG_LanguageFeatures.html` (model scaling), `UG_NLP_GoodFormulations.html`, `UG_GamsCall.html` (compile-time constant tables), `UG_License.html` (demo limits), `UG_GAMSReturnCodes.html`, `UG_DollarControlOptions.html`
- `/usr/gams/gams54.1_linux_x64_64_sfx/gmscmpun.txt` — authoritative per-solver model-type capability table on this install (CONOPT: `LP RMIP NLP CNS DNLP RMINLP QCP RMIQCP` — **no MINLP**)
- **GAMS Test Model Library** (`testlib`) — `testmod.inc`, `quality.gms`, `assign1.gms`: the vendor's own ~1000-unit test architecture, which the repo independently converged on
- **`Uniswap/v3-core` contract source** — `SqrtPriceMath.sol` (both branches of `getNextSqrtPriceFromAmount0RoundingUp`, `getAmountXDelta` rounding directions), `TickMath.sol` (±887272, `MIN_SQRT_RATIO`, `MAX_SQRT_RATIO`)
- **Exact-arithmetic references** — Python `decimal` at 80 digits, plus a faithful reimplementation of `TickMath.getSqrtRatioAtTick` with the Q128.128 constant chain, used to measure GAMS error against ground truth
- **Repository sources read and re-run** — `.planning/PROJECT.md`, `Makefile`, `model/primitives.gms`, `model/PricingKernel.gms`, `model/TradingRegion.gms`, `model/LiquidityKernel.gms`, `model/PricingKernelMoments.gms`, `model/payoff/*`, `model/test/*`, `model/PriceImpactKernelFixture.gms`, `model/BUILD.md`
- **Orchestrator re-verification** — independently confirmed the `$eval 2**96` 2^45 error, the not-`INF` silent-overflow behaviour, and the false-pass gate (broken program returned rc=2 while the recipe printed OK)

### Secondary (MEDIUM confidence)

- `https://www.gams.com/latest/docs/UG_GDX.html` — corroborates the compile-vs-execution phase split and `execute_load`'s silent-ignore of absent labels
- `https://www.gams.com/latest/docs/UG_OrderedSets.html` — corroborates the static/ordered requirement for `ord()` and linear-vs-circular lag endpoint handling
- `https://www.gams.com/blog/2017/08/scaling/`, `https://support.gams.com/solver:some_notes_on_scaling` — CONOPT scaling guidance
- The `Q128.128` labelling of `L̄` / `Δ^I` as an *intent* claim — flagged MEDIUM by PITFALLS itself, pending Plank-side confirmation

### Tertiary (LOW confidence)

- Web search for a canonical GAMS argmax idiom returned nothing beyond the local `smin`/`smax` documentation — **a negative result, reported for honesty**; no external idiom improves on the recommendation
- `model/BUILD.md` — known stale (claims no `Model`/`Solve` exists; two CONOPT NLPs do), used only where independently re-verified

---
*Research completed: 2026-07-27*
*Ready for roadmap: yes*
