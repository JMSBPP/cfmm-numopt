$onText
==========================================================================
------------------> StripLengthFromGammaBudget < -----------------------
  Choose replicationStripLength under the LiquidityKernel gamma budget.
  Model: gammaBudgetFeasibleStripLength
  Spec: MAIN_SPEC (Thm 51 — max ι s.t. G(ι)≥g)
==========================================================================
$offText

$include equations/GammaBudget.gms

* \(g\, > 0\) ; MAIN_SPEC:L416
GlobalGammaTarget = 0.001;

$onText
===============================================================================
--------------------------------> L(i) tables at current ι.l < ---------------
===============================================================================
$offText

liquidityWeight(strikeIdx) = liquidityMassAt(TickSpacing, tickStrikeVal(strikeIdx), replicationStripLength.l);

LiquidityOnStrike(strikeIdx) = no;
liquidityOnStrikeVal(strikeIdx) = 0;
loop(strikeIdx$TickStrikes(strikeIdx),
   LiquidityOnStrike(strikeIdx) = yes;
   liquidityOnStrikeVal(strikeIdx) =
      liquidityOnStrikeAt(TickSpacing, tickStrikeVal(strikeIdx), replicationStripLength.l, VegaNotional);
);

abort$(sum(LiquidityOnStrike$(liquidityOnStrikeVal(LiquidityOnStrike) <= 0), 1))
   'LiquidityOnStrike: need L(i_K) > 0';
abort$(sum(LiquidityOnStrike$(liquidityOnStrikeVal(LiquidityOnStrike) >= liqOnStrikeHi), 1))
   'LiquidityOnStrike: need L(i_K) < 2^128';

liquidityOnGammaVal(strikeIdx) = 0;
liquidityOnGammaVal(strikeIdx)$GammaProfile(strikeIdx) =
   2 * ExposureGlobalGamma(TickSpacing, VegaNotional, replicationStripLength.l)
   * rPower(gamma(strikeIdx), 1/3);

$onText
===============================================================================
--------------------------------> MODEL < ------------------------------------
  \(\max \iota\) s.t. kernel domains
===============================================================================
$offText

Variable maxReplicationStripLength;
Equation defMaxReplicationStripLength;
	 defMaxReplicationStripLength.. maxReplicationStripLength =e= replicationStripLength;

Model gammaBudgetFeasibleStripLength /
	 replicationStripLengthDomain
	 liquidityWeightDomainLo
	 liquidityWeightDomainHi
	 gammaBudget
	 defMaxReplicationStripLength
/;

option minlp = sbb;
option nlp = conopt;
Solve gammaBudgetFeasibleStripLength using minlp maximizing maxReplicationStripLength;

abort$(gammaBudgetFeasibleStripLength.solveStat <> %solveStat.normalCompletion%)
	 'gammaBudgetFeasibleStripLength: solver did not terminate normally';
abort$(gammaBudgetFeasibleStripLength.modelStat > 2
	 and gammaBudgetFeasibleStripLength.modelStat <> %modelStat.integerSolution%)
	 'gammaBudgetFeasibleStripLength: no integer solution for replicationStripLength';

* Refresh L tables at solved ι.
liquidityWeight(strikeIdx) = liquidityMassAt(TickSpacing, tickStrikeVal(strikeIdx), replicationStripLength.l);
loop(strikeIdx$TickStrikes(strikeIdx),
   liquidityOnStrikeVal(strikeIdx) =
      liquidityOnStrikeAt(TickSpacing, tickStrikeVal(strikeIdx), replicationStripLength.l, VegaNotional);
);
liquidityOnGammaVal(strikeIdx)$GammaProfile(strikeIdx) =
   2 * ExposureGlobalGamma(TickSpacing, VegaNotional, replicationStripLength.l)
   * rPower(gamma(strikeIdx), 1/3);

display replicationStripLength.l, GlobalGammaTarget, maxReplicationStripLength.l;
display liquidityWeight, liquidityOnStrikeVal, liquidityOnGammaVal;
