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
# GATE-03: solveStat FIRST -- see the band unit for the rationale.
abort$(ZeroSlip.solveStat <> %solveStat.normalCompletion%)
    "FAIL: ZeroSlip solver did not terminate normally (solveStat)",
    ZeroSlip.solveStat, ZeroSlip.modelStat;
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
