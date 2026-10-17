$onText
==========================================================================
------------------> StripLengthFromGammaBudget < -----------------------
  Choose replicationStripLength under the LiquidityKernel gamma budget.
  Model: gammaBudgetFeasibleStripLength
  Spec: cfmm-vol-markets-spec/spec/MAIN_SPEC.md (Thm 51 — max ι s.t. G(ι)≥g)
==========================================================================
$offText

$onText
===============================================================================
--------------------------------> INPUTS < -----------------------------------
  \(\Big(
	g, 
    \big(\Gamma_{\varphi},\; m_{\Gamma}\big),\;
    \ell,\;
    L(i_K),\;
    L(\Gamma_i)
  \Big)\)
===============================================================================
$offText

$include kernel/LiquidityKernel.gms

* \(g\, > 0\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L416
GlobalGammaTarget = 0.001;

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

$onText
===============================================================================
--------------------------------> OUTPUTS < ----------------------------------
  \(\iota^{\star}\) 
===============================================================================
$offText

display replicationStripLength.l, GlobalGammaTarget, maxReplicationStripLength.l;
