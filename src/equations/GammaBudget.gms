$onText
================================================
	-------> EQUATIONS <-----------------
	 Strip domains + \(G(\iota) \ge g\)
================================================
$offText

$if not declared replicationStripLength $include variables/ReplicationStrip.gms

Equation replicationStripLengthDomain;
	 replicationStripLengthDomain.. replicationStripLength =g= 1;

* \(\sum_{i_K} \, \ell \, (\xi, \iota; i_K) \, = \, 1 \) ; MAIN_SPEC:L155
* Draft1: TickStrikes proxy for the strip; exact =e=1 is integer-infeasible, so a tight band.
Equation liquidityWeightDomainLo, liquidityWeightDomainHi;
	liquidityWeightDomainLo.. GlobalLiquidityMass(TickStrikes, TickSpacing, tickStrikeVal, replicationStripLength)
	    =g= 1 - liquidityWeightTol;
	liquidityWeightDomainHi.. GlobalLiquidityMass(TickStrikes, TickSpacing, tickStrikeVal, replicationStripLength)
	    =l= 1 + liquidityWeightTol;

* \(G(\iota) \, \ge \, g\) ; MAIN_SPEC:L416
* Draft1: \(g\) and the RHS are in units of \(\bar L\equiv\texttt{VegaNotional}\).
Equation gammaBudget;
	 gammaBudget.. GlobalGammaTarget =l=
	    ExposureGlobalGamma(TickSpacing, VegaNotional, replicationStripLength) / VegaNotional;
