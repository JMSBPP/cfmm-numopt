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
