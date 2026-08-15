<!-- TEST-09 MUTANT. Derived from docs/specs/2026-06-28-payoff-band-monotone-large-design.md by injecting one line of
     invalid GAMS at the end of section ## 6.'s gams block. Do not edit by
     hand; regenerate with the snippet in 00-02-PLAN.md task 3. -->

---
title: PayoffModule Cycle 2 — large-trade band monotonicity (3 Lean theorems bundled)
rev: 1
date: 2026-06-28
branch: feat/gams-payoff-c2-band
cycle: 2
prev_cycle_spec: docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md
prev_cycle_branch: feat/gams-payoff
prev_cycle_pr: 7
---

# PayoffModule Cycle 2 — Large-trade band monotonicity

## 1. Context

Cycle 1 (PR #7, branch `feat/gams-payoff`) shipped the PayoffModule scaffolding
and the first per-theorem program corroborating
`pi_trader_half_zero_at_deltaI_star` (eta.lean:518) at canonical config
`L̄=1·Q128, Δ^I=0.1·Q128, i=60` (small-trade regime). Cycle 2 reuses that
scaffolding to bundle three more proven Lean theorems on the **same**
`pi_trader_half` payoff function in the **large-trade regime** (L̄ ≤ Δ^I).

Bundling is justified by the math: theorems T2 and T3 are direct corollaries of
T1 — they all hinge on the strict monotonicity of π in Δᵢ that the large-trade
precondition unlocks. One GAMS per-theorem file with one canonical config
exercises all three theorems via a shared band sweep.

## 2. Goal

Produce one per-theorem GAMS program + one binary GDX fixture that:

- Corroborates the three Lean theorems numerically at a canonical large-trade
  configuration.
- Exports the worst-case and best-case trader slippage payoff at the endpoints
  of an admissible tick-spacing band as on-chain control targets for a future
  EVM controller.
- Preserves the rev-4 spec discipline (spec MD is source of truth; Python regex
  extracts code blocks verbatim; `make spec-preflight-band` enforces it).
- Carries Lean provenance (theorem names, file:line, Aristotle project UUID,
  proof status) in the GDX in the same shape as Cycle 1's.

## 3. Decisions

### D1. Three theorems bundled in one program

- `pi_trader_half_strictly_increasing_in_Δi` (eta.lean:366) — primary
  monotonicity theorem; corollaries T2 and T3 follow from it. Aristotle-proven.
- `pi_trader_half_band_min_at_left` (eta.lean:477) — corollary: on any band
  [Δᵢ_min, Δᵢ_max], π(Δᵢ_min) ≤ π(Δᵢ) for all Δᵢ in the band. **Weak inequality
  (≤), not strict.** A 4-line inline corollary of T1; **no Aristotle record**
  (the Lean-side companion `eta_pi_trader_band_min.md` line 32 explicitly says
  "Proved inline, no Aristotle needed.").
- `pi_trader_half_band_max_large_trade` (eta.lean:609) — corollary: on any band,
  argmax is at Δᵢ_max. Aristotle-proven (shares project with T1).

All three share the precondition L̄ ≤ Δ^I. Verified proven (no `sorry`/`admit`
in any theorem body) at spec-write time; the one `sorry` in eta.lean:602 is
in a comment about a different (small-trade upper sub-regime) theorem.

On T2's weak inequality: the GAMS T2 assert uses `smin(... , diVal)` which picks
the smallest tied argmin. At canonical config the floating-point payoff has no
ties on the integer grid (verified by Python replication), so the strict-min
land at `diMinBand` holds operationally. If a future config produces ties (e.g.
extreme Q128 round-off), `smin` still returns the leftmost = `diMinBand` and
the assert still passes correctly.

### D2. Canonical config (large-trade, 10× ratio)

- `lambdaWad = 1.0001e18` (same as Cycle 1, Uniswap-style tick base)
- `iCfg = 60` (same as Cycle 1)
- `LbarQ128 = Q128 / 10` → L̄ = 0.1 in Q128.128
- `DICfgQ128 = Q128` → Δ^I = 1.0 in Q128.128
- Ratio Δ^I/L̄ = 10 (strict large-trade; precondition satisfied with margin)
- Band: `diMinBand = 10`, `diMaxBand = 190` (properly interior to [1, 200])

The config is the role-swap mirror of Cycle 1 (which had L̄=1, Δ^I=0.1). The
10× spread maximizes signal-to-noise for asserting strict monotonicity over
the 200-tick grid.

### D3. EVM control targets are payoff VALUES, not argmin/argmax integers

The argmin/argmax integers are trivially equal to the band endpoints (which
are inputs). The load-bearing values for an EVM controller are:

- `optimum('enumeration', 'piAtDiMin')` → worst-case trader slippage cost at
  the band's lower endpoint.
- `optimum('enumeration', 'piAtDiMax')` → best-case trader slippage cost at
  the band's upper endpoint.

Both argmin/argmax integers AND payoff values are exported for schema parity
with Cycle 1's GDX shape.

### D4. Reuse Cycle 1's scaffolding unchanged

`model/payoff/_PayoffScaffolding.gms` provides `piTrader_Half_Lean`,
`piTrader_Half_Plank`, `P_Lean_at`, `sqrtPX96_at`, `priceImpactQ128_Add0`,
Q128/Q96 constants, `lambdaWad`, tolerances. Cycle 2 needs no new macros.

### D5. Single NLP solve (asymmetric defense-in-depth)

CONOPT NLP runs only for band-min. Integer enumeration covers both argmin
and argmax. Running NLP both ways is redundant — both methods agree by
construction in the monotone regime.

### D6. Lean integration is a permanent series-wide gate

Every cycle of the PayoffModule series must carry Lean provenance in the
same GDX shape Cycle 1 established (`theoremNameSet`, `leanFileSet`,
`leanLineSet`, `aristotleProjectSet`, `theoremStatus`), and the spec must
cite each theorem by Lean identifier and `file:line`. `theoremStatus = 1`
requires verified proof in Lean AND check in Aristotle.

### D7. Aristotle project UUID covers T1 and T3 only; T2 is inline-proven

Verified: Cycle 1's UUID `88d393e7-ec4e-438f-a5fd-9f34aab1c2e5` is the
project under which the Lean4+math peer has been proving the eta-CES theorem
family. The Lean-side md companions confirm:

- `eta_pi_trader_delta_control.md` (line 35) → UUID present, T1 Aristotle-proven.
- `eta_pi_trader_band_max.md` (lines 26, 92) → UUID present, T3 Aristotle-proven.
- `eta_pi_trader_band_min.md` (line 32) → UUID **absent**, says "Proved inline,
  no Aristotle needed." T2 is a 4-line corollary of T1.

GDX provenance accordingly distinguishes per-theorem Aristotle status via the
`theoremProvenance` tuple set (see §6 and §9). `aristotleProjectSet` carries
the single UUID that covers the Aristotle-proven members; T2 is annotated
`inline_corollary` and has no Aristotle record.

### D7b. GDX payoff-value units and Q-scale contract

The payoff scalars exported as control targets (`piAtDiMin`, `piAtDiMax`,
`piAtDiMinContinuousExport`, `piAtDiMaxContinuousExport`) are **bare GAMS
real numbers** with all Q128/Q96 scale factors cancelled inside the macro:

- `traderTerm_Half_Plank` = `sqrtP/Q96 · DIQ128/Q128` = `sqrt(P_real) · Δ^I_real`
  (dimensionless × token units).
- `traderDeltaO_Half_Plank` = `LQ128/Q128 · (sqrtP - sqrtQ)/Q96`
  = `L̄_real · (sqrt(P_real) − sqrt(P_post_real))` (token units).
- `piTrader_Half_Plank` = `sqr(traderTerm − traderDeltaO)` → **units of
  (token output)²** with `Δ^I_real = DICfgQ128/Q128 = 1.0` at canonical config.

Numerically: `piAtDiMin ≈ 0.877`, `piAtDiMax ≈ 2.563` (both dimensionless real,
both O(1) — Cycle 1's flat-Q96 objective issue does not recur here because
this regime's payoff has visible curvature).

**For on-chain consumers (gamsdiff peer, future EVM controller):**

- The value is NOT pre-scaled to Q128 or Q256. It is a real-domain scalar.
- A Q128 fixed-point encoding for uint256 storage requires `value × Q128`.
  This places `piAtDiMax × Q128 ≈ 8.7e38` — **fits uint256 (max 1.16e77) but
  exceeds uint128 (max 3.4e38)**. uint256 storage is required for the payoff
  cells; uint128 is insufficient.
- A Q256.256 representation (squared quantity → square the scale factor) is
  application-specific and not exported. Consumers should NOT naively apply
  `× Q128²` (would overflow uint512 territory and serve no semantic purpose
  unless the consumer arithmetically needs (Q128)² intermediate products).

The gamsdiff peer's pipeline is the canonical consumer; its conversion
discipline (which Q-scale to apply at which boundary) is the binding contract.
This spec exports the raw real-valued payoff; downstream owns the encoding
choice.

### D8. Tolerances inherited from Cycle 1

`diffTolerance = 1e-12` for relative comparisons; `zeroTolerance = 1e-20`
for absolute zero checks. The 1-tick NLP bound on CONOPT (rev-3 lesson)
applies here too.

### D9. spec-preflight-band is a new Makefile target, not an extension

`spec-preflight` (Cycle 1) extracts §5/§6/§7/§8 from
`docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md`.
`spec-preflight-band` (Cycle 2) extracts only §6 from THIS spec, mirrors
it into the production layout next to the already-shipped Cycle 1
scaffolding, and drives via the orchestrator. Both targets remain runnable
independently; both must pass before each cycle's PR can merge.

### D10. No new asserts on Cycle 1's already-corroborated claims

The cross-coord macro consistency (Lean vs Plank), the bridge identity at
Δᵢ⋆, and the B_Plank sqrt-vs-no-sqrt check were locked down in Cycle 1.
Cycle 2 does not re-verify them; it relies on the scaffolding's stability.

## 4. Architecture (files affected)

```
model/
├── PayoffModule.gms                              # MODIFY: append 1 $include line
├── payoff/
│   ├── _PayoffScaffolding.gms                    # UNCHANGED
│   ├── eta_pi_trader_zero_slippage.gms           # UNCHANGED (Cycle 1)
│   └── eta_pi_trader_band_monotone_large.gms     # CREATE — Cycle 2's program
├── test/
│   └── PayoffModuleTest.gms                      # UNCHANGED — transitively picks up new file
├── payoff_zero_slippage.gdx                      # UNCHANGED (Cycle 1)
└── payoff_band_monotone_large.gdx                # CREATE — Cycle 2's GDX fixture

Makefile                                          # MODIFY: parameterize payoff-fixtures; add spec-preflight-band
.gitignore                                        # MODIFY: add !model/payoff_band_monotone_large.gdx re-include
docs/superpowers/specs/
└── 2026-06-28-payoff-band-monotone-large-design.md  # CREATE — THIS spec
```

## 5. Shared scaffolding — `model/payoff/_PayoffScaffolding.gms`

**Unchanged from Cycle 1.** No new macros. All needed primitives
(`piTrader_Half_Lean`, `piTrader_Half_Plank`, `P_Lean_at`, `sqrtPX96_at`,
`priceImpactQ128_Add0`, Q-scale constants, `lambdaWad`, `diMinInt`,
`diMaxInt`, tolerances) are already defined.

The spec deliberately does NOT re-quote the scaffolding code — it lives in
the prior cycle's spec MD (`2026-06-28-payoff-zero-slippage-design.md` §5)
and is already extracted, compiled, and tested.

## 6. First program — `model/payoff/eta_pi_trader_band_monotone_large.gms`

```gams
$title Large-trade band monotonicity — Lean strictly-increasing + band-min + band-max
$offeolcom
$eolcom #
$include payoff/_PayoffScaffolding.gms

# ── Canonical large-trade config ──
Scalar iCfg        / 60 /;
Scalar LbarQ128 ;  LbarQ128  = Q128 / 10;          # L̄ = 0.1 in Q128.128
Scalar DICfgQ128 ; DICfgQ128 = Q128;               # Δ^I = 1.0 in Q128.128
Scalar diMinBand  / 10  /;
Scalar diMaxBand  / 190 /;

# ── (G1) Large-trade precondition guard ──
# Lean theorem pi_trader_half_strictly_increasing_in_Δi requires L̄ ≤ Δ^I.
abort$(LbarQ128 > DICfgQ128)
    "FAIL G1: large-trade precondition L̄ ≤ Δ^I violated", LbarQ128, DICfgQ128;

# ── (G2) Band guard ──
abort$(diMinBand < diMinInt or diMaxBand > diMaxInt or diMinBand >= diMaxBand)
    "FAIL G2: band must satisfy diMinInt ≤ diMinBand < diMaxBand ≤ diMaxInt",
    diMinBand, diMaxBand;

# ── Integer enumeration over the band ──
Set       bandGrid /1*200/;
Parameter diVal(bandGrid) ;  diVal(bandGrid) = ord(bandGrid);
Set       inBand(bandGrid) ;
inBand(bandGrid) $(ord(bandGrid) >= diMinBand and ord(bandGrid) <= diMaxBand) = yes;

Parameter piGridPlank(bandGrid) ;
piGridPlank(bandGrid) $inBand(bandGrid) =
    piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diVal(bandGrid)), LbarQ128, DICfgQ128);

Parameter piGridLean(bandGrid) ;
piGridLean(bandGrid) $inBand(bandGrid) =
    piTrader_Half_Lean(P_Lean_at(lambdaWad, iCfg, diVal(bandGrid)), LbarQ128, DICfgQ128);

# ── (A) Payoff positivity (corollary of theorems — large-trade π is strictly positive) ──
Scalar piAtDiMinPlank ;   piAtDiMinPlank = sum(bandGrid$(ord(bandGrid) = diMinBand), piGridPlank(bandGrid));
Scalar piAtDiMaxPlank ;   piAtDiMaxPlank = sum(bandGrid$(ord(bandGrid) = diMaxBand), piGridPlank(bandGrid));
Scalar piAtDiMinLean  ;   piAtDiMinLean  = sum(bandGrid$(ord(bandGrid) = diMinBand), piGridLean(bandGrid));
Scalar piAtDiMaxLean  ;   piAtDiMaxLean  = sum(bandGrid$(ord(bandGrid) = diMaxBand), piGridLean(bandGrid));
abort$(piAtDiMinPlank <= 0 or piAtDiMaxPlank <= 0)
    "FAIL A_Plank: payoff must be strictly positive in large-trade regime",
    piAtDiMinPlank, piAtDiMaxPlank;
abort$(piAtDiMinLean <= 0 or piAtDiMaxLean <= 0)
    "FAIL A_Lean: payoff must be strictly positive in large-trade regime",
    piAtDiMinLean, piAtDiMaxLean;

# ── (T1) Strict monotonicity (Plank coords) — corroborates eta.lean:366 ──
# Sliding-window check: NO i in [diMinBand, diMaxBand-1] with π(i) ≥ π(i+1).
Set monoBreaksPlank(bandGrid) ;
monoBreaksPlank(bandGrid) $(inBand(bandGrid) and ord(bandGrid) < diMaxBand
                            and piGridPlank(bandGrid) >= piGridPlank(bandGrid+1)) = yes;
Scalar monoBreaksPlankCount ;  monoBreaksPlankCount = card(monoBreaksPlank);
abort$(monoBreaksPlankCount > 0)
    "FAIL T1 (Plank): pi_trader_half_strictly_increasing_in_Δi violated on the band",
    monoBreaksPlankCount;

# ── (T1L) Strict monotonicity (Lean coords) — complementary Δᵢ window ──
# T1 evaluates piTrader_Half_Plank at integer di ∈ [10, 190]; because
# sqrtPX96_at raises λ to the (i·di/2) power, this is algebraically equivalent
# to piTrader_Half_Lean at Δᵢ_Lean = di/2 ∈ [5, 95]. T1L evaluates
# piTrader_Half_Lean directly at integer di ∈ [10, 190] — a complementary
# window, not a duplicate. Together T1 and T1L cover Δᵢ_Lean ∈ [5, 190].
Set monoBreaksLean(bandGrid) ;
monoBreaksLean(bandGrid) $(inBand(bandGrid) and ord(bandGrid) < diMaxBand
                           and piGridLean(bandGrid) >= piGridLean(bandGrid+1)) = yes;
Scalar monoBreaksLeanCount ;  monoBreaksLeanCount = card(monoBreaksLean);
abort$(monoBreaksLeanCount > 0)
    "FAIL T1L (Lean): pi_trader_half_strictly_increasing_in_Δi violated in Lean coords",
    monoBreaksLeanCount;

# ── (T2) Band-min argmin = diMinBand — corroborates eta.lean:477 ──
Scalar piMinOnBand ;  piMinOnBand = smin(bandGrid$inBand(bandGrid), piGridPlank(bandGrid));
Scalar diArgmin ;     diArgmin = smin(bandGrid$(inBand(bandGrid) and piGridPlank(bandGrid) = piMinOnBand), diVal(bandGrid));
abort$(diArgmin <> diMinBand)
    "FAIL T2: pi_trader_half_band_min_at_left — argmin must equal diMinBand",
    diArgmin, diMinBand;

# ── (T3) Band-max argmax = diMaxBand — corroborates eta.lean:609 ──
Scalar piMaxOnBand ;  piMaxOnBand = smax(bandGrid$inBand(bandGrid), piGridPlank(bandGrid));
Scalar diArgmax ;     diArgmax = smax(bandGrid$(inBand(bandGrid) and piGridPlank(bandGrid) = piMaxOnBand), diVal(bandGrid));
abort$(diArgmax <> diMaxBand)
    "FAIL T3: pi_trader_half_band_max_large_trade — argmax must equal diMaxBand",
    diArgmax, diMaxBand;

# ── (B_ext) PricingKernel label-consistency gate ──
# Confirms at runtime: tickSpacingVal('s10') = 10 AND tickVal('k181') = 60.
# Both macros (tunablePricingKernel and P_Lean_at) algebraically reduce to
# (λ/u)^600·Q96 — this check does NOT independently verify the P_Lean_at
# exponent structure (B_indep covers that). It catches PricingKernel set
# label-to-ordinal drift, which would silently corrupt downstream consumers.
Scalar pTunableAtMin ;  pTunableAtMin = tunablePricingKernel('s10', 'k181', 1);
Scalar pLeanAtMin    ;  pLeanAtMin    = P_Lean_at(lambdaWad, iCfg, diMinBand) * Q96;
abort$(abs(pTunableAtMin - pLeanAtMin) / pLeanAtMin > diffTolerance)
    "FAIL B_ext: PricingKernel label mapping drifted (expected s10→10, k181→60)",
    pTunableAtMin, pLeanAtMin;

# ── (B_indep) Kernel-shape probe at two non-endpoint Δᵢ points ──
# Catches macro exponent/coefficient bugs independent of the closed-form claim.
Scalar diProbeA / 50 /;
Scalar diProbeB / 100 /;
Scalar PProbeA ; PProbeA = P_Lean_at(lambdaWad, iCfg, diProbeA);
Scalar PProbeB ; PProbeB = P_Lean_at(lambdaWad, iCfg, diProbeB);
Scalar logRatioExpected ; logRatioExpected = (diProbeB - diProbeA) * iCfg * log(lambdaWad/unity);
abort$(abs(log(PProbeB/PProbeA) - logRatioExpected) / abs(logRatioExpected) > diffTolerance)
    "FAIL B_indep: P_Lean kernel-shape probe (log-ratio)",
    PProbeA, PProbeB, logRatioExpected;

# ── (C_min) NLP minimize π over band — CONOPT modelStat + 1-tick bound ──
Positive Variable di ;
di.lo = diMinBand; di.up = diMaxBand; di.l = (diMinBand + diMaxBand) / 2;
Variable piVal ;
Equation payoffEq ;
payoffEq.. piVal =e= piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, di), LbarQ128, DICfgQ128);
Model BandMin / payoffEq /;
option nlp = conopt;
Solve BandMin using nlp minimizing piVal;
abort$(BandMin.modelStat <> %modelStat.locallyOptimal% and BandMin.modelStat <> %modelStat.optimal%)
    "FAIL C_min: CONOPT NLP did not reach optimum", BandMin.modelStat, BandMin.solveStat;
Scalar diSolverRound ;  diSolverRound = round(di.l);
abort$(abs(diSolverRound - diMinBand) > 1)
    "FAIL C_min: NLP argmin diverged from band-min by more than 1 tick",
    diSolverRound, diMinBand;

# ── GDX export ──
Set inputD    / lambdaWad, iTick, LbarQ128, DeltaIQ128, etaQ128,
                diMinInt, diMaxInt, diMinBand, diMaxBand /;
Set targetD   / diMinArgmin, diMaxArgmax, piAtDiMin, piAtDiMax /;
Set sourceD   / analytical, solver, enumeration /;

Parameter inputs(inputD);
inputs('lambdaWad')   = lambdaWad;
inputs('iTick')       = iCfg;
inputs('LbarQ128')    = LbarQ128;
inputs('DeltaIQ128')  = DICfgQ128;
inputs('etaQ128')     = etaQ128;
inputs('diMinInt')    = diMinInt;
inputs('diMaxInt')    = diMaxInt;
inputs('diMinBand')   = diMinBand;
inputs('diMaxBand')   = diMaxBand;

Parameter optimum(sourceD, targetD);

optimum('analytical', 'diMinArgmin')  = diMinBand;
optimum('analytical', 'diMaxArgmax')  = diMaxBand;
optimum('analytical', 'piAtDiMin')    = piAtDiMinPlank;
optimum('analytical', 'piAtDiMax')    = piAtDiMaxPlank;

optimum('solver',     'diMinArgmin')  = diSolverRound;
optimum('solver',     'diMaxArgmax')  = diMaxBand;
optimum('solver',     'piAtDiMin')    = piVal.l;
optimum('solver',     'piAtDiMax')    = piAtDiMaxPlank;

optimum('enumeration', 'diMinArgmin') = diArgmin;
optimum('enumeration', 'diMaxArgmax') = diArgmax;
optimum('enumeration', 'piAtDiMin')   = piMinOnBand;
optimum('enumeration', 'piAtDiMax')   = piMaxOnBand;

# Lean-theorem provenance.
# Note: theoremNameSet uses ASCII transliteration `Delta_i` for the Lean
# identifier `Δi` (unicode Δ). GDX set elements are opaque quoted strings;
# the Lean identifier is recoverable via leanLineSet + a fresh grep.
Set theoremNameSet      / 'pi_trader_half_strictly_increasing_in_Delta_i',
                          'pi_trader_half_band_min_at_left',
                          'pi_trader_half_band_max_large_trade' /;
Set leanFileSet         / 'lean4-spec/lean/exp/eta.lean' /;
Set leanLineSet         / 'eta.lean:366', 'eta.lean:477', 'eta.lean:609' /;
Set aristotleProjectSet / '88d393e7-ec4e-438f-a5fd-9f34aab1c2e5' /;
Set aristotleStatusD    / aristotle_proven, inline_corollary /;

# theoremProvenance pairs each theorem with its line + Aristotle status.
# Replaces the parallel-sets convention (which had no positional binding
# between theoremNameSet and leanLineSet). A downstream consumer reads this
# 3-tuple set to recover the canonical pairing; aristotleProjectSet then
# names the project for any tuple whose status = aristotle_proven.
Set theoremProvenance(theoremNameSet, leanLineSet, aristotleStatusD) /
    'pi_trader_half_strictly_increasing_in_Delta_i' . 'eta.lean:366' . aristotle_proven,
    'pi_trader_half_band_min_at_left'               . 'eta.lean:477' . inline_corollary,
    'pi_trader_half_band_max_large_trade'           . 'eta.lean:609' . aristotle_proven /;

Scalar theoremStatus / 1 /;                                # 1=proven in Lean (all 3 verified no sorry/admit at spec-write + at preflight time)

Scalar piAtDiMinContinuousExport ;  piAtDiMinContinuousExport = piVal.l;
Scalar piAtDiMaxContinuousExport ;  piAtDiMaxContinuousExport = piAtDiMaxPlank;

execute_unload 'payoff_band_monotone_large.gdx',
    inputs, optimum,
    gamsVersion, modelVersion, lambdaWad, etaQ128,
    diffTolerance, zeroTolerance, tieBreaking,
    theoremStatus, theoremNameSet, leanFileSet, leanLineSet, aristotleProjectSet,
    aristotleStatusD, theoremProvenance,
    piAtDiMinContinuousExport, piAtDiMaxContinuousExport;

display "PASS: large-trade band monotonicity — 3 Lean theorems corroborated.";
display "  Band:", diMinBand, diMaxBand;
display "  Enum argmin / argmax:", diArgmin, diArgmax;
display "  pi at band endpoints (Plank):", piAtDiMinPlank, piAtDiMaxPlank;
display "  NLP solver continuous di.l + piVal.l:", di.l, piVal.l;
this line is not GAMS syntax )))

```

## 7. Orchestrator delta — `model/PayoffModule.gms`

Append one `$include` line:

```gams
$title PayoffModule orchestrator
$eolcom #
# Per-theorem files $include _PayoffScaffolding.gms themselves (include-guarded).
$include payoff/eta_pi_trader_zero_slippage.gms
$include payoff/eta_pi_trader_band_monotone_large.gms
# Future cycles append per-theorem $include lines here.
```

## 8. Test rollup — `model/test/PayoffModuleTest.gms`

**Unchanged.** It already `$include`s `PayoffModule.gms`, which transitively
picks up the new per-theorem file. `make test-gams` count stays at 3 passed.

## 9. GDX schema

`model/payoff_band_monotone_large.gdx`:

| Symbol | Type | Shape |
|---|---|---|
| `inputs` | Parameter | 9 entries (9-element `inputD` set) |
| `optimum` | Parameter | 3×4 (3-element `sourceD` × 4-element `targetD`) |
| `gamsVersion`, `modelVersion`, `lambdaWad`, `etaQ128` | Scalar | 4 |
| `diffTolerance`, `zeroTolerance`, `tieBreaking` | Scalar | 3 |
| `theoremStatus` | Scalar | 1 |
| `theoremNameSet`, `leanFileSet`, `leanLineSet`, `aristotleProjectSet`, `aristotleStatusD` | Set | 5 |
| `theoremProvenance(theoremNameSet, leanLineSet, aristotleStatusD)` | 3-tuple Set | 3 entries |
| `piAtDiMinContinuousExport`, `piAtDiMaxContinuousExport` | Scalar | 2 |

= **18 explicit symbols** + auto-promoted domain sets (`inputD`, `targetD`,
`sourceD`, `bandGrid`, `inBand`, `monoBreaksPlank`, `monoBreaksLean`).

**Provenance reading rule for downstream consumers:**

1. Read `theoremProvenance` to get the canonical `(name, line, status)` tuples.
2. For each tuple with `status = aristotle_proven`, look up `aristotleProjectSet`
   to find the project under which the proof is checked.
3. For `status = inline_corollary`, the proof is a direct corollary in the Lean
   source; no Aristotle record exists. Treat as proven-in-Lean only.

The flat sets `theoremNameSet` / `leanLineSet` / `aristotleProjectSet` are kept
for backward compatibility with the Cycle 1 GDX schema; `theoremProvenance` is
the canonical pairing for cycles with multiple theorems.

**Payoff-value units:** see §3 D7b. `piAt*` values are bare GAMS reals in units
of (Δ^I_real)². Q-scale encoding for on-chain consumption is the consumer's
responsibility; uint256 storage is required, uint128 is insufficient.

**Canonical control target for EVM controller consumption:**
`optimum('enumeration', 'piAtDiMin')` — worst-case trader slippage cost at
the band's lower endpoint. `optimum('enumeration', 'piAtDiMax')` — best-case
at the upper endpoint.

## 10. Success criteria

- `make compile-gams` = **11 ok / 0 failed** (was 10; +1 for new
  `payoff/eta_pi_trader_band_monotone_large.gms`).
- `make test-gams` = **3 passed / 0 failed** (count unchanged; new program
  picked up transitively through the orchestrator).
- `make spec-preflight-band` = **PASS** (new target).
- `make spec-preflight` = still **PASS** (Cycle 1 target untouched).
- `make payoff-fixtures` produces BOTH GDXs cleanly
  (`payoff_zero_slippage.gdx` + `payoff_band_monotone_large.gdx`).
- New GDX `model/payoff_band_monotone_large.gdx` exists, ≤ 8 KB,
  18 explicit symbols + auto-promoted sets, all 10 labeled asserts pass.
- `gdxdump model/payoff_band_monotone_large.gdx Symb=optimum | grep enumeration`
  shows `diMinArgmin = 10`, `diMaxArgmax = 190`, `piAtDiMin` and `piAtDiMax`
  strictly positive (large-trade regime).
- **Lean integration gate (permanent series criterion):** GDX
  `theoremStatus = 1`; `theoremProvenance` 3-tuple set pairs each of the 3
  theorem identifiers with its `eta.lean:N` line and Aristotle status
  (`aristotle_proven` for T1 + T3; `inline_corollary` for T2);
  `aristotleProjectSet` = `{88d393e7-ec4e-438f-a5fd-9f34aab1c2e5}`. Each
  `abort` message in the GAMS code cites the theorem it corroborates by
  name. **`make spec-preflight-band` re-runs the sorry/admit grep on the
  3 theorem bodies in eta.lean and aborts on any drift** —
  `theoremStatus = 1` is gated by an automated check, not pure documentation
  discipline.

## 11. Out of scope

- Small-trade upper sub-regime band-max (`Δ^I² + Δ^I·L̄ > L̄²`, interior-hump
  case) — no Lean theorem yet. Flag to Lean4+math peer.
- `sigma_xs_poly_target_exists` (eta.lean:560) — Cycle 4 candidate.
- `pi_trader_half_small_trade_quadratic` (eta.lean:428) — Cycle 5 candidate.
- EVM-side controller that consumes the GDX (owned by other peers).
- gamsdiff peer's pipeline extension for this GDX (owned by PID 299098).

## 12. Workflow

1. **Substrate verification (done at spec-write time AND re-run by spec-preflight-band):**
   - `grep -nE 'theorem pi_trader_half_strictly_increasing|theorem pi_trader_half_band_min_at_left|theorem pi_trader_half_band_max_large_trade' /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/exp/eta.lean`
     → confirmed lines 366, 477, 609.
   - `grep -nE 'sorry|admit' /home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/exp/eta.lean`
     → only line 602 (in a comment about a different theorem, `pi_trader_half_band_max_small_trade`); none in any of the 3 cited theorem bodies. **`spec-preflight-band` re-runs this grep at preflight time and aborts if any of the 3 cited theorems contain `sorry` or `admit` in their body** — automates the rev-4 spec-as-truth discipline for `theoremStatus = 1`.
   - Aristotle UUID `88d393e7-ec4e-438f-a5fd-9f34aab1c2e5` confirmed via Lean-side md companions:
     - `eta_pi_trader_delta_control.md` line 35 — UUID present (T1).
     - `eta_pi_trader_band_max.md` lines 26, 92 — UUID present (T3).
     - `eta_pi_trader_band_min.md` line 32 — UUID **absent**; T2 is "Proved inline, no Aristotle needed." Encoded in GDX as `aristotle_proven` status for T1/T3, `inline_corollary` for T2.
2. **Branch:** `feat/gams-payoff-c2-band` cut off `feat/gams-payoff` (so Cycle 1's
   scaffolding + Makefile targets are available).
3. **Two-step review** of THIS spec (Reality Checker + one specialized agent per
   CLAUDE.md) — BLOCKER and MAJOR findings resolved before spec commit.
4. **Spec-preflight-band** target added to Makefile; verified PASS on the
   spec MD before any implementation.
5. **writing-plans** → **subagent-driven-development** for execution.
6. **After Cycle 1 PR #7 merges to develop:** rebase Cycle 2 onto develop.
7. **Open Cycle 2 PR** against develop.

### Makefile target — `spec-preflight-band`

```makefile
.PHONY: spec-preflight-band
spec-preflight-band:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD)/spec-band
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/payoff $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/test
	@# Lean substrate gate: re-verify no sorry/admit in any of the 3 cited theorem bodies.
	@# Theorem body extends from `theorem <name>` to the next top-level theorem/lemma/def.
	@LEAN=$(LEAN4_SPEC_DIR)/lean/exp/eta.lean; \
	if [ ! -f "$$LEAN" ]; then printf 'spec-preflight-band FAIL: %s not found (set LEAN4_SPEC_DIR)\n' "$$LEAN"; exit 1; fi; \
	for ID in pi_trader_half_strictly_increasing_in_ pi_trader_half_band_min_at_left pi_trader_half_band_max_large_trade; do \
		START=$$(grep -nE "^theorem $$ID" "$$LEAN" | head -1 | cut -d: -f1); \
		if [ -z "$$START" ]; then printf 'spec-preflight-band FAIL: theorem %s not found in %s\n' "$$ID" "$$LEAN"; exit 1; fi; \
		END=$$(awk -v s="$$START" 'NR>s && /^(theorem |lemma |def |noncomputable def |namespace |end )/ {print NR; exit}' "$$LEAN"); \
		if [ -z "$$END" ]; then END=$$(wc -l < "$$LEAN"); fi; \
		if sed -n "$${START},$${END}p" "$$LEAN" | grep -vE '^\s*(--|/-)' | grep -qE '\bsorry\b|\badmit\b'; then \
			printf 'spec-preflight-band FAIL: theorem %s body contains sorry/admit\n' "$$ID"; exit 1; \
		fi; \
	done; \
	printf 'spec-preflight-band: Lean substrate OK (3 theorems sorry/admit-free)\n'
	@SPEC=docs/superpowers/specs/2026-06-28-payoff-band-monotone-large-design.md; \
	ROOT=$(GAMS_DIR)/$(GAMS_BUILD)/spec-band; \
	python3 -c "import re; text = open('$$SPEC').read(); secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M); body6 = next((secs[i+1] for i in range(1,len(secs),2) if secs[i].startswith('## 6.')), None); body7 = next((secs[i+1] for i in range(1,len(secs),2) if secs[i].startswith('## 7.')), None); assert body6 is not None and body7 is not None, 'spec sections missing: ## 6. and/or ## 7.'; m6 = re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', body6, re.S); m7 = re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', body7, re.S); assert m6 is not None and m7 is not None, 'no gams code block in section: ## 6. and/or ## 7.'; open('$$ROOT/payoff/eta_pi_trader_band_monotone_large.gms','w').write(m6.group(1)); open('$$ROOT/PayoffModule.gms','w').write(m7.group(1))"; \
	cp $(GAMS_DIR)/PricingKernel.gms $(GAMS_DIR)/primitives.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/; \
	cp $(GAMS_DIR)/payoff/_PayoffScaffolding.gms $(GAMS_DIR)/payoff/eta_pi_trader_zero_slippage.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/payoff/; \
	cp $(GAMS_DIR)/test/PayoffModuleTest.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/test/; \
	cd $(GAMS_DIR)/$(GAMS_BUILD)/spec-band && \
	$(GAMS) test/PayoffModuleTest.gms action=ce o=run.lst scrdir=. lo=0 >/dev/null 2>&1 ; \
	if grep -qE 'Status: (Compilation|Execution) error' run.lst; then \
		printf 'spec-preflight-band FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/run.lst\n'; \
		grep -A1 '^\*\*\*\*' run.lst | head -10; exit 1; \
	else \
		printf 'spec-preflight-band OK (Lean sorry-grep + GAMS extract+compile+execute via production layout)\n'; \
	fi
```

Where `LEAN4_SPEC_DIR` defaults to the sibling worktree
(`$(GAMS_DIR)/../../lean4-spec` in the cfmm-wt layout). The sorry-grep gate
fires BEFORE the GAMS extraction so a Lean regression aborts preflight without
even attempting the downstream steps.

`payoff-fixtures` is generalized to loop over every `payoff/eta_*.gms`
(it already does in the current Makefile; no change needed beyond the
new file being auto-discovered).

## 13. References

- Cycle 1 spec: `docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md`
- Cycle 1 PR: https://github.com/JMSBPP/cfmm-replicationPlank/pull/7
- Lean source: `lean4-spec/lean/exp/eta.lean` (theorems at lines 366, 477, 609)
- Lean math companions:
  - `lean4-spec/lean/exp/eta_pi_trader_delta_control.md` (monotonicity)
  - `lean4-spec/lean/exp/eta_pi_trader_band_min.md` (band-min)
  - `lean4-spec/lean/exp/eta_pi_trader_band_max.md` (band-max + small-trade companion)
- Aristotle project: https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5
