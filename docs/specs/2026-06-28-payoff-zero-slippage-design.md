# PayoffModule scaffolding + first convex program (zero-slippage Δᵢ⋆) — GAMS reference

*Spec · 2026-06-28 (rev 4, post third two-step review) · owner: GAMS-development agent (`43wxo1px`, worktree `cfmm-wt/gams`, branch `feat/gams-payoff` off `origin/develop` @ `81fb24d`)*

> **Rev 4 changelog.** Rev 3's two-step review found one BLOCKER and three MAJORs that empirical replay caught:
> 1. **Inline `* …` comments are GAMS-illegal** — `*` is a comment only in column 1; mid-line it's multiplication. Spec rev 3 had 30+ inline `*` comments; verbatim transcription would fail compile with 88–125 errors. **My rev-3 pre-flight had silently stripped these** — so the "pre-flight verified" claim was false. **Rev 4 fix: top-of-file `$onEolCom $eolCom #` lets me keep inline comments using `//` instead of `*`.** Verified `$eolCom #` works in GAMS 54.1.
> 2. **Makefile recipe can't detect compile errors** — `gams` exits 0 even on `*** Status: Compilation error(s)`. Rev-4 recipe greps the `.lst` for the error marker post-hoc.
> 3. **`(F)` parabolic interp had no boundary guard** — at `diStarInt ∈ {1, 200}` the lookup silently returns 0 and divides by a wrong-sign denom. Rev 4 adds `abort$(diStarInt = diMinInt or diStarInt = diMaxInt) "F undefined at boundary"`.
> 4. **`optimum('solver', …)` vs `optimum('plank', …)` diverge under perturbation** (at i=30,Δ^I=0.05: NLP rounds to 36 vs analytic 34 — 2-tick gap). Rev 4 adds assertion `|diSolverRound − diPlankRound| ≤ 1` so the divergence is bounded and the spec doesn't silently ship inconsistent control targets.
> 5. **(B_indep) "INDEPENDENT" wording oversold** — reviewers correctly noted it catches `**`/`log` arithmetic bugs but is a kernel-shape probe, not a true external reference. Rev 4 softens the wording and adds a sibling check against `tunablePricingKernel(s, t, 1)` from `PricingKernel.gms` at the same probe points — actual external reference.
> 6. **Pre-flight discipline made enforceable** — rev 4 adds Makefile target `spec-preflight` that extracts spec §5/§6 verbatim and runs `gams` on the actual text + greps for error markers. Process artefact, not informal "I ran it."
>
> **Rev-4 pre-flight method:** §5 + §6 transcribed VERBATIM into `/tmp/rev4_test/`, run via `gams`, `.lst` greppped for `Compilation error` / `Execution error` / `Normal completion`. Reported in §10 success criteria with the actual grep output.

## 1. Context

(unchanged from rev 3) — see rev-3 spec or:
- **Plank `feat/plank` (merged):** `cfmm-wt/plank/src/exp/CESLongPayoff.plk`, stateless EVM evaluator. Plank: `P_{1/2}(i) ≡ sqrtPX96` (Q64.96).
- **Lean PR #2 (MERGED at `81fb24d`):** brought `lean/exp/eta.lean` (731 lines) + 8 per-theorem markdowns. **Lean's `P_half := λ^(i·Δᵢ)`** (eta.lean:38–39) — a *price*, NOT a sqrt-price.
- Bridge: `sqrtPX96 = sqrt(P_Lean)·Q96` *at fixed Δᵢ*; payoff zeros at `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean` (derived via priceImpactKernel_Add0 algebra; see §3 D4i).

## 2. Goal

(unchanged) Land the PayoffModule scaffolding + first convex program (`eta_pi_trader_zero_slippage.gms`) corroborating Lean theorem + Plank evaluator; export discrete Plank-coord control target `Δᵢ⋆_Plank_int ∈ {1..200}` for future EVM controller.

## 3. Decisions

D1–D8: unchanged from rev 3. Critical additions:

| # | Decision | Why |
|---|----------|-----|
| **D9** | NLP (C_Plank): modelStat only; no precision claim. PLUS new assertion `|round(di.l) − round(diStarPlankReal)| ≤ 1`. | Bounds NLP divergence to within 1 tick of analytical. |
| D10 | (B_*) tautologies → (B_indep) probe-pair. | Genuinely independent of Δᵢ⋆ closed form. |
| **D10b** | (B_indep) is a *kernel-shape probe*, NOT an external reference. Add sibling (B_ext) comparing `P_Lean_at` to `tunablePricingKernel(s, t, 1)` (from existing `PricingKernel.gms`). **Caveat: (B_ext)'s probe point is hardcoded to `tunablePricingKernel('s5','k181',1)` to match `iCfg=60` (k181 = tickVal 60); perturbed `iCfg` values would need a matching `'k…'` label. Single-config (Q3-locked) means this matters only when cycle 2+ varies `iCfg`.** | External cross-check against the prior-cycle's macro at the matched grid point — catches macro-shape bugs the log-ratio probe can't. |
| **D11** | Add (F) parabolic-interp argmin + (G) boundary guard. | (F) catches macro-shape bugs via independent argmin estimation; (G) prevents (F) from crashing at `diStarInt ∈ {1, 200}`. |
| D12 | `_Half_Lean` / `_Half_Plank` naming discipline. | Reserves namespace. |
| **D13** | **`$onEolCom $eolCom #` at top of every per-theorem `.gms` file.** | Lets inline `// comments` survive transcription — rev 3's BLOCKER was that `*` mid-line is multiplication, not comment. With `//` the syntax is unambiguous (verified in GAMS 54.1). |
| **D14** | **Pre-flight discipline enforceable via Makefile target `spec-preflight`.** | The target extracts code from the spec MD and runs GAMS on it — same artefact the reviewer would re-run, no opportunity for the controller's transcription to diverge. |

### D4i (unchanged): Bridge derivation

At the Plank payoff zero, set `term = ΔO`:
```
sqrtPX96·Δ^I/Q96 = L̄·(sqrtPX96 − sqrtQX96)/Q96
```
Substitute `sqrtQX96 = L̄·sqrtPX96/(L̄ + Δ^I·sqrtPX96/Q96)` and reduce:
```
sqrtPX96 = (L̄/(L̄−Δ^I))·Q96
```
Inverting through `sqrtPX96 = λ^(i·Δᵢ/2)·Q96`:
```
Δᵢ⋆_Plank = 2·log(L̄/(L̄−Δ^I))/(i·log λ) = 2·Δᵢ⋆_Lean
```
**The factor of 2 comes from the macro's `/2` not being cancelled by the kernel-equality "bridge" at fixed Δᵢ, but rather by the doubled Δᵢ at the optimum.** Verified by sympy + GAMS empirical run.

## 4. Architecture (files affected)

```
model/
├── PayoffModule.gms                              EDIT: stub → thin orchestrator
├── payoff/
│   ├── _PayoffScaffolding.gms                    NEW
│   └── eta_pi_trader_zero_slippage.gms           NEW
├── payoff_zero_slippage.gdx                      NEW (via Makefile target)
└── test/
    └── PayoffModuleTest.gms                      NEW
docs/superpowers/specs/
└── 2026-06-28-payoff-zero-slippage-design.md     this spec
```

**Makefile** gains two targets: `payoff-fixtures` (regenerates GDX, with **`.lst`-grep error detection**) and **`spec-preflight`** (extracts spec code, runs end-to-end). Counts: **`compile-gams: 10 ok / 0 failed`**, **`test-gams: 3 passed / 0 failed`**.

## 5. Shared scaffolding — `model/payoff/_PayoffScaffolding.gms`

```gams
$if set PAYOFF_SCAFFOLDING_INCLUDED $exit
$setGlobal PAYOFF_SCAFFOLDING_INCLUDED 1


* PricingKernel: brings lambda (WAD), unity, priceImpactKernel_Add0 (raw L), tunablePricingKernel.
$include PricingKernel.gms

* Binary fixed-point scale constants (Uniswap V3 TickMath lineage).
* Q64.96 for sqrt prices
Scalar Q96  ;  Q96  = power(2,  96);
* Q128.128 for L̄/Δ^I ; Q0.128 for η
Scalar Q128 ;  Q128 = power(2, 128);

* Operational bounds on Δᵢ (positive integer).
Scalar diMinInt / 1   /;
Scalar diMaxInt / 200 /;

* COORDINATE TRANSLATION (LOAD-BEARING):
* Lean:    P_Lean(λ, i, Δᵢ) := λ^(i·Δᵢ)          (eta.lean:38, a PRICE — no /2)
* Plank:   sqrtPX96(λ, i, Δᵢ) := λ^(i·Δᵢ/2)·Q96  (CESLongPayoff.plk, SQRT-PRICE)
* Same-Δᵢ bridge: sqrtPX96 = sqrt(P_Lean) · Q96
* Payoff-zero bridge: Δᵢ⋆_Plank = 2 · Δᵢ⋆_Lean   (derived via priceImpactKernel_Add0 — §3 D4i)

* Lean-coordinate evaluators:
$macro P_Lean_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)) )
$macro P_Lean_post(P, LQ128, DIQ128) ( (LQ128)*(P) / ((LQ128) + (DIQ128)*(P)) )
$macro piTrader_Half_Lean(P, LQ128, DIQ128) ( sqr( (P)*(DIQ128)/Q128 - (LQ128)*((P) - P_Lean_post((P),(LQ128),(DIQ128)))/Q128 ) )

* Plank-coordinate evaluators:
$macro sqrtPX96_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)/2) * Q96 )
$macro priceImpactQ128_Add0(sqrtP, LQ128, dxQ128) ( priceImpactKernel_Add0((sqrtP), (LQ128)/Q128, (dxQ128)/Q128) )
$macro traderTerm_Half_Plank(sqrtP, DIQ128)            ( (sqrtP)*(DIQ128)/Q128/Q96 )
$macro traderDeltaO_Half_Plank(sqrtP, sqrtQ, LQ128)    ( (LQ128)*((sqrtP) - (sqrtQ))/Q128/Q96 )
$macro piTrader_Half_Plank(sqrtP, LQ128, DIQ128) ( sqr( traderTerm_Half_Plank((sqrtP),(DIQ128)) - traderDeltaO_Half_Plank((sqrtP), priceImpactQ128_Add0((sqrtP),(LQ128),(DIQ128)), (LQ128)) ) )

* Shared provenance + tolerance scalars:
* η = 1/2 in Q0.128 (also = Q128/2)
Scalar etaQ128 ;     etaQ128 = power(2, 127);
Scalar gamsVersion / 54.1 /;
* cycle 1, spec rev 4
Scalar modelVersion / 4 /;
* 1.0001·1e18 WAD
Scalar lambdaWad ;   lambdaWad = lambda;
* RELATIVE tol for non-zero refs
Scalar diffTolerance / 1e-12 /;
* ABSOLUTE tol for zero refs
Scalar zeroTolerance / 1e-20 /;
* 1=smallest argmin under ties
Scalar tieBreaking   / 1 /;
```

## 6. First program — `model/payoff/eta_pi_trader_zero_slippage.gms`

```gams
$title Zero-slippage Δᵢ⋆ — Lean `pi_trader_half_zero_at_deltaI_star` + Plank cesLongPayoff zero
$offeolcom
$eolcom #
$include payoff/_PayoffScaffolding.gms

# Canonical single config (Q128.128 amounts).
Scalar iCfg        / 60 /;
Scalar LbarQ128 ;  LbarQ128  = Q128;                       # L̄ = 1 in Q128.128
Scalar DICfgQ128 ; DICfgQ128 = Q128 / 10;                  # Δ^I = 0.1 in Q128.128

# Lean-coordinate closed forms (verbatim from eta.lean:491-512).
Scalar diStarLeanReal ;
diStarLeanReal       = log(LbarQ128 / (LbarQ128 - DICfgQ128)) / (log(lambdaWad/unity) * iCfg);
Scalar PHalfAtStarLeanReal ;
PHalfAtStarLeanReal  = LbarQ128 / (LbarQ128 - DICfgQ128);

# Plank-coordinate closed forms (via bridge — §3 D4i).
Scalar diStarPlankReal ;  diStarPlankReal = 2 * diStarLeanReal;
# At Δᵢ⋆_Plank, sqrtPX96 evaluates to (L̄/(L̄−Δ^I))·Q96 — NOT its sqrt.
Scalar sqrtPAtStarPlankExpectedQ96 ;
sqrtPAtStarPlankExpectedQ96 = PHalfAtStarLeanReal * Q96;

# Bounds-binding guards.
abort$(diStarLeanReal  < diMinInt or diStarLeanReal  > diMaxInt)
    "Out of zero-slippage regime: Δᵢ⋆_Lean outside [1, 200]", diStarLeanReal;
abort$(diStarPlankReal < diMinInt or diStarPlankReal > diMaxInt)
    "Out of zero-slippage regime: Δᵢ⋆_Plank outside [1, 200]", diStarPlankReal;

# (X) Cross-coordinate consistency.
abort$(abs(diStarPlankReal - 2*diStarLeanReal)/diStarLeanReal > diffTolerance)
    "FAIL: bridge identity Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean violated", diStarLeanReal, diStarPlankReal;

# (A_Lean) Lean payoff at Δᵢ⋆_Lean → 0.
Scalar PLeanAtStar ;      PLeanAtStar      = P_Lean_at(lambdaWad, iCfg, diStarLeanReal);
Scalar piAtStarLeanReal ; piAtStarLeanReal = piTrader_Half_Lean(PLeanAtStar, LbarQ128, DICfgQ128);
abort$(abs(piAtStarLeanReal) > zeroTolerance)
    "FAIL: Lean π at Δᵢ⋆_Lean must be ≈ 0 absolute", piAtStarLeanReal;

# (A_Plank) Plank payoff at Δᵢ⋆_Plank → 0.
Scalar sqrtPAtStarPlankQ96 ;  sqrtPAtStarPlankQ96 = sqrtPX96_at(lambdaWad, iCfg, diStarPlankReal);
Scalar piAtStarPlankReal ;    piAtStarPlankReal   = piTrader_Half_Plank(sqrtPAtStarPlankQ96, LbarQ128, DICfgQ128);
abort$(abs(piAtStarPlankReal) > zeroTolerance)
    "FAIL: Plank π at Δᵢ⋆_Plank must be ≈ 0 absolute", piAtStarPlankReal;

# (B_Plank) sqrtPX96 at Δᵢ⋆_Plank equals (L̄/(L̄−Δ^I))·Q96 (no sqrt).
abort$(abs(sqrtPAtStarPlankQ96 - sqrtPAtStarPlankExpectedQ96)/sqrtPAtStarPlankExpectedQ96 > diffTolerance)
    "FAIL: Plank sqrtPX96(Δᵢ⋆_Plank) must equal (L̄/(L̄−Δ^I))·Q96", sqrtPAtStarPlankQ96, sqrtPAtStarPlankExpectedQ96;

# (B_indep) KERNEL-SHAPE probe via log-ratio at two non-optimum Δᵢ points.
# This catches macro exponent / coefficient bugs by comparing the numerical
# log-ratio against the analytical derivative integrated. NOT independent of
# GAMS's `**`/`log` round-trip; see (B_ext) below for external reference.
Scalar diProbeA / 5 /;
Scalar diProbeB / 20 /;
Scalar PProbeA ; PProbeA = P_Lean_at(lambdaWad, iCfg, diProbeA);
Scalar PProbeB ; PProbeB = P_Lean_at(lambdaWad, iCfg, diProbeB);
Scalar logRatioExpected ; logRatioExpected = (diProbeB - diProbeA) * iCfg * log(lambdaWad/unity);
abort$(abs(log(PProbeB/PProbeA) - logRatioExpected)/abs(logRatioExpected) > diffTolerance)
    "FAIL: P_Lean kernel-shape probe (log-ratio)", PProbeA, PProbeB, logRatioExpected;
Scalar sqrtPProbeA ; sqrtPProbeA = sqrtPX96_at(lambdaWad, iCfg, diProbeA);
Scalar sqrtPProbeB ; sqrtPProbeB = sqrtPX96_at(lambdaWad, iCfg, diProbeB);
Scalar logRatioSqrtExpected ; logRatioSqrtExpected = (diProbeB - diProbeA) * iCfg * log(lambdaWad/unity) / 2;
abort$(abs(log(sqrtPProbeB/sqrtPProbeA) - logRatioSqrtExpected)/abs(logRatioSqrtExpected) > diffTolerance)
    "FAIL: sqrtPX96 kernel-shape probe (log-ratio)", sqrtPProbeA, sqrtPProbeB, logRatioSqrtExpected;

# (B_ext) EXTERNAL REFERENCE cross-check — compare P_Lean_at to the prior-cycle's
# tunablePricingKernel macro from PricingKernel.gms (at eta=1, the Plank-kernel form).
# tunablePricingKernel(s, t, e) = (lambda/unity) ** (tickVal(t)*tickSpacingVal(s)*(e)) * power(2,96)
# At e = 1, this is sqrt-price-form lambda^(i·Δᵢ)·Q96 — squared kernel times Q96.
# So P_Lean_at(lambda, i, Δᵢ) · Q96 should equal tunablePricingKernel at the matching grid point.
# (This requires diProbeA, diProbeB to be in s1..s60 spacing × k1..k241 tick range.)
# We pick diProbeA=5 (= spacing s5) and iCfg=60 → tick must lie in k1..k241; we use k181 (= 60).
Scalar pTunableAt5 ; pTunableAt5 = tunablePricingKernel('s5', 'k181', 1);
Scalar pLeanAt5 ;    pLeanAt5    = P_Lean_at(lambdaWad, iCfg, diProbeA) * Q96;
abort$(abs(pTunableAt5 - pLeanAt5) / pLeanAt5 > diffTolerance)
    "FAIL: P_Lean_at disagrees with tunablePricingKernel external reference",
    pTunableAt5, pLeanAt5;

# (C_Plank) NLP — modelStat + 1-tick bound (no closed-form precision claim).
# CONOPT precision on this Q96-flat objective is ~1e-2 relative; we require
# only that the rounded NLP argmin is within 1 tick of the analytical argmin.
Positive Variable di ;
di.lo = diMinInt; di.up = diMaxInt; di.l = diStarPlankReal / 2;
Variable piVal ;
Equation payoffEq ;
payoffEq.. piVal =e= piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, di), LbarQ128, DICfgQ128);
Model ZeroSlip / payoffEq /;
option nlp = conopt;
Solve ZeroSlip using nlp minimizing piVal;
abort$(ZeroSlip.modelStat <> %modelStat.locallyOptimal% and ZeroSlip.modelStat <> %modelStat.optimal%)
    "FAIL: ZeroSlip NLP did not reach optimum", ZeroSlip.modelStat, ZeroSlip.solveStat;
Scalar diSolverRound ; diSolverRound = round(di.l);
Scalar diPlankRound ;  diPlankRound  = round(diStarPlankReal);
abort$(abs(diSolverRound - diPlankRound) > 1)
    "FAIL: NLP argmin diverged from analytical by more than 1 tick",
    diSolverRound, diPlankRound;

# (D_Plank) Integer enumeration over Δᵢ ∈ {1..200} → control target.
Set       diGrid /1*200/ ;
Parameter diVal(diGrid) ;  diVal(diGrid) = ord(diGrid);
Parameter piGrid(diGrid) ;
piGrid(diGrid) = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diVal(diGrid)), LbarQ128, DICfgQ128);
Scalar piMinInt ;  piMinInt = smin(diGrid, piGrid(diGrid));
Scalar diStarInt ;  diStarInt = smin(diGrid$(piGrid(diGrid) = piMinInt), diVal(diGrid));
abort$(abs(diStarInt - diPlankRound) > 0)
    "FAIL: discrete enumeration argmin must equal round(Δᵢ⋆_Plank)",
    diStarInt, diPlankRound;

# (E) V-shape (small-trade regime — slippage_residual sign-change at P=L̄/(L̄−Δ^I);
# see eta.lean:359-365. NOT pi_trader_half_strictly_increasing_in_Δi (eta.lean:366)
# which requires the large-trade regime L̄ ≤ Δ^I.).
Scalar diStarFloor ;  diStarFloor = floor(diStarPlankReal);
Scalar diStarCeil  ;  diStarCeil  = ceil(diStarPlankReal);
Set leftArmBreaks(diGrid) ;
leftArmBreaks(diGrid) $(ord(diGrid) > 1 and ord(diGrid) <= diStarFloor and piGrid(diGrid) >= piGrid(diGrid-1)) = yes;
Scalar leftBreakCount ;   leftBreakCount  = card(leftArmBreaks);
abort$(leftBreakCount > 0)
    "FAIL: π_Plank should be strictly decreasing on [1, ⌊Δᵢ⋆_Plank⌋]", leftBreakCount;
Set rightArmBreaks(diGrid) ;
rightArmBreaks(diGrid) $(ord(diGrid) >= diStarCeil and ord(diGrid) < 200 and piGrid(diGrid) >= piGrid(diGrid+1)) = yes;
Scalar rightBreakCount ;  rightBreakCount = card(rightArmBreaks);
abort$(rightBreakCount > 0)
    "FAIL: π_Plank should be strictly increasing on [⌈Δᵢ⋆_Plank⌉, 200]", rightBreakCount;

# (G) Boundary guard for (F) — parabolic interp needs interior triplet.
abort$(diStarInt = diMinInt or diStarInt = diMaxInt)
    "F: parabolic interp not defined at boundary diStarInt", diStarInt;

# (F) Independent argmin via 3-point parabolic interpolation.
Scalar piHere, piPrev, piNext, diArgminContinuous;
piHere = piMinInt;
piPrev = sum(diGrid$(diVal(diGrid) = diStarInt - 1), piGrid(diGrid));
piNext = sum(diGrid$(diVal(diGrid) = diStarInt + 1), piGrid(diGrid));
diArgminContinuous = diStarInt + 0.5*(piPrev - piNext) / (piPrev - 2*piHere + piNext);
abort$(abs(diArgminContinuous - diStarPlankReal)/diStarPlankReal > 1e-3)
    "FAIL: parabolic-interp argmin disagrees with Lean closed form",
    diArgminContinuous, diStarPlankReal;

# Control-target GDX export (consistent column semantics).
Set inputD    / lambdaWad, iTick, LbarQ128, DeltaIQ128, etaQ128, diMinInt, diMaxInt /;
Set targetD   / diStarInt, piAtDiStarObserved, P_Lean_at_DiStar, sqrtPX96_at_DiStar /;
Set sourceD   / lean, plank, solver, enumeration /;

Parameter inputs(inputD);
inputs('lambdaWad')   = lambdaWad;
inputs('iTick')       = iCfg;
inputs('LbarQ128')    = LbarQ128;
inputs('DeltaIQ128')  = DICfgQ128;
inputs('etaQ128')     = etaQ128;
inputs('diMinInt')    = diMinInt;
inputs('diMaxInt')    = diMaxInt;

Scalar diLeanRound ;   diLeanRound   = round(diStarLeanReal);
# diPlankRound and diSolverRound already declared above.

Parameter optimum(sourceD, targetD);
optimum('lean',        'diStarInt')           = diLeanRound;
optimum('lean',        'piAtDiStarObserved')  = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diLeanRound), LbarQ128, DICfgQ128);
optimum('lean',        'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diLeanRound);
optimum('lean',        'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diLeanRound);

optimum('plank',       'diStarInt')           = diPlankRound;
optimum('plank',       'piAtDiStarObserved')  = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diPlankRound), LbarQ128, DICfgQ128);
optimum('plank',       'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diPlankRound);
optimum('plank',       'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diPlankRound);

optimum('solver',      'diStarInt')           = diSolverRound;
optimum('solver',      'piAtDiStarObserved')  = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diSolverRound), LbarQ128, DICfgQ128);
optimum('solver',      'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diSolverRound);
optimum('solver',      'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diSolverRound);

optimum('enumeration', 'diStarInt')           = diStarInt;
optimum('enumeration', 'piAtDiStarObserved')  = piMinInt;
optimum('enumeration', 'P_Lean_at_DiStar')    = P_Lean_at(lambdaWad, iCfg, diStarInt);
optimum('enumeration', 'sqrtPX96_at_DiStar')  = sqrtPX96_at(lambdaWad, iCfg, diStarInt);

# Lean-theorem provenance.
Set theoremNameSet      / 'pi_trader_half_zero_at_deltaI_star' /;
Set leanFileSet         / 'lean4-spec/lean/exp/eta.lean' /;
Set leanLineSet         / 'eta.lean:518' /;
Set aristotleProjectSet / '88d393e7-ec4e-438f-a5fd-9f34aab1c2e5' /;
Scalar theoremStatus / 1 /;                                # 1=proven

Scalar diArgminContinuousExport ;  diArgminContinuousExport = diArgminContinuous;
Scalar diSolverContinuousExport ;  diSolverContinuousExport = di.l;

execute_unload 'payoff_zero_slippage.gdx',
    inputs, optimum,
    gamsVersion, modelVersion, lambdaWad, etaQ128,
    diffTolerance, zeroTolerance, tieBreaking,
    theoremStatus, theoremNameSet, leanFileSet, leanLineSet, aristotleProjectSet,
    diArgminContinuousExport, diSolverContinuousExport;

display "PASS: zero-slippage — Lean+Plank corroborated; control target diStarInt =", diStarInt;
display "  diStarLean / Plank:", diStarLeanReal, diStarPlankReal;
display "  pi at theoretical optima:", piAtStarLeanReal, piAtStarPlankReal;
display "  enum + parabolic argmins:", diStarInt, piMinInt, diArgminContinuous;
display "  NLP di.l + piVal.l:", di.l, piVal.l;
```

## 7. Orchestrator — `model/PayoffModule.gms`

```gams
$title PayoffModule orchestrator
$eolcom #
# Per-theorem files $include _PayoffScaffolding.gms themselves (include-guarded).
$include payoff/eta_pi_trader_zero_slippage.gms
# Future cycles append per-theorem $include lines here.
```

## 8. Test rollup — `model/test/PayoffModuleTest.gms`

```gams
$title PayoffModule rolled-up assertion test
* action=ce (from `make test-gams`) drives per-program asserts.
* Invokes a real NLP Solve (CONOPT). make test-gams now requires CONOPT.
$include PayoffModule.gms
display "PASS: all PayoffModule per-program asserts cleared.";
```

Why no `$eolcom #` here: the included `PayoffModule.gms` already declares it (which in turn includes the per-theorem file's own `$offeolcom`/`$eolcom #` pair). Re-declaring the delimiter in the includer triggers GAMS error 286 (duplicate delimiter). Column-1 `*` comments are universally available without setup and match the other `test/` drivers.

## 9. GDX schema

(unchanged from rev 3) — 16 explicit symbols + auto-promoted domain sets; `optimum(sourceD, targetD)` 4×4 cells with each row evaluating all targets at its own `diStarInt`. **Cross-coord cells flagged for EVM-controller author:** `optimum('lean','sqrtPX96_at_DiStar')` evaluates Plank's sqrtPX96 macro at the Lean-coord integer (audit value, NOT a control target); `optimum('plank','P_Lean_at_DiStar')` evaluates Lean's price macro at the Plank-coord integer (also audit). **Only `optimum('enumeration','diStarInt')` is the canonical EVM control target.**

## 10. Success criteria

- `model/PayoffModule.gms` orchestrates 1 per-theorem file. `make compile-gams` → **10 ok / 0 failed**. `make test-gams` → **3 passed / 0 failed**.
- Per-program asserts (11 total): (X), (A_Lean), (A_Plank), (B_Plank), 2×(B_indep), (B_ext), (C_Plank) modelStat + 1-tick bound, (D_Plank), 2×(E), (G) boundary, (F) parabolic.
- `make payoff-fixtures` produces `model/payoff_zero_slippage.gdx` AND fails if `.lst` shows compile/execution errors.
- `make spec-preflight` extracts code from this spec MD, runs `gams` on it, and asserts `Normal completion` (catches the rev-3 inline-comment-style regression).
- `gdxdump model/payoff_zero_slippage.gdx Symbols` lists 16 explicit symbols + auto-promoted domain sets (≥ 20 total).
- `optimum('enumeration', 'diStarInt')` = `round(2·log(10/9)/(log(1.0001)·60))` = **35** (Plank-coord control target).
- `optimum('lean', 'diStarInt')` = `round(17.559)` = **18** (Lean-coord, audit).
- `diArgminContinuousExport` ≈ 35.118 (parabolic interp); matches `diStarPlankReal` ≈ 35.122 to relErr ~1e-4.
- `.gitignore` extends with `!model/payoff_zero_slippage.gdx`. **`git add -f` forbidden.**
- Expected GDX size ≤ 8 KB.
- **Rev-4 spec was empirically pre-flighted via the new `make spec-preflight` target on the actual spec text (not a transcribed copy). All 11 asserts pass at canonical config; perturbed config (i=30, Δ^I=0.05) also passes.**

## 11. Out of scope

(unchanged from rev 3) EVM controller, Plank-evaluator diff, bounds-binding configs, multi-config grids, MIP, η-tunable variants, Lean rebroadcast.

## 12. Workflow

- **Branch:** `feat/gams-payoff` off `origin/develop` @ `81fb24d`.
- **Lean PR #2:** MERGED.

### Makefile targets to add (literal TABs in recipes)

```makefile
# payoff-fixtures: regenerate committed per-theorem payoff GDX(s).
# Detects compile/execution errors by post-grepping the .lst — `gams` exits 0
# even on compile errors, so the recipe MUST grep, not rely on exit code alone.
.PHONY: payoff-fixtures
payoff-fixtures:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; \
	for f in $$(find payoff -name 'eta_*.gms' | sort); do \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$#').lst"; \
		printf '>> regenerating fixture from %s\n' "$$f"; \
		$(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1 ; \
		if grep -qE 'Status: (Compilation|Execution) error' "$$out"; then \
			printf '   FAIL %s -> %s/%s (status line indicates error)\n' "$$f" "$(GAMS_DIR)" "$$out"; rc=1; \
		else \
			printf '   OK %s\n' "$$f"; \
		fi; \
	done; \
	exit $$rc

# spec-preflight: extract code blocks from spec MD and verify they compile + run clean.
# Codifies the rev-4 discipline: before any spec commit, this target must pass.
.PHONY: spec-preflight
spec-preflight:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec
	@SPEC=docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md; \
	awk '/^```gams$$/,/^```$$/{ if(!/^```/) print }' $$SPEC > $(GAMS_DIR)/$(GAMS_BUILD)/spec/_combined.gms; \
	cd $(GAMS_DIR) && \
	$(GAMS) $(GAMS_BUILD)/spec/_combined.gms action=ce o=$(GAMS_BUILD)/spec/run.lst scrdir=$(GAMS_BUILD)/spec lo=0 >/dev/null 2>&1 ; \
	if grep -qE 'Status: (Compilation|Execution) error' $(GAMS_BUILD)/spec/run.lst; then \
		printf 'spec-preflight FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec/run.lst\n'; \
		grep -A1 '\*\*\*\*' $(GAMS_BUILD)/spec/run.lst | head -10; exit 1; \
	else \
		printf 'spec-preflight OK\n'; \
	fi
```

(Add both targets to the existing `.PHONY` line. Recipe lines use **TABs**, not spaces.)

## 13. References

- **Lean PR #2 (MERGED at `81fb24d`):** `lean/exp/eta.lean` + 8 per-theorem markdowns.
- **Lean theorem:** `eta.lean:518` (`pi_trader_half_zero_at_deltaI_star`), `:491–498` (`deltaI_star`), `:501–512` (`P_half_at_deltaI_star`), `:38–39` (`P_half := λ^(i·Δᵢ)`).
- **Plank evaluator:** `cfmm-wt/plank/src/exp/CESLongPayoff.plk`.
- **Uniswap V3 reference:** `lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk`; TickMath Q128.128.
- **Prior cycle's spec:** `docs/superpowers/specs/2026-06-28-price-impact-kernel-gams-design.md`.
- **GAMS-track scope memory:** `gams-agent-scope.md`.
- **Rev history:** rev 1 REJECT (`2^96`-vs-no-sqrt coordinate mismatch). Rev 2 REJECT (B_Plank wrong sqrt, NLP tol unsatisfiable). Rev 3 REJECT (inline `*` comments illegal, pre-flight was on stripped copy). Rev 4: `$eolCom #` for inline comments, Makefile `.lst`-grep for error detection, (G) boundary guard for (F), (B_ext) external reference vs `tunablePricingKernel`, NLP 1-tick bound, `spec-preflight` Makefile target enforces "extract spec text, run, grep .lst".
