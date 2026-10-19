$onText
================================================
	-------> ENDOGENOUS VARIABLES <-----------------
		 \(\iota\) = replicationStripLength
================================================
$offText

$if not declared mGamma $include parameters/LiquidityKernel.gms

* \(\iota \in \mathbb{N}\), \(\iota \ge 1\). ; MAIN_SPEC:L178
Integer Variable replicationStripLength;
replicationStripLength.lo = 1;
replicationStripLength.up = nStrikes;
replicationStripLength.l = nStrikes;
