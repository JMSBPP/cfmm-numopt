$onText
==========================================================================
------------------> NoFeeVarianceClaim (A1) < --------------------------
  Lock: .planning/A1-no-fee-variance-claim.md
  \(\pi^{\sigma}_{\mathrm{no\,fee}} = G(\iota)\,\sigma_{\mathrm{RV}}^{2}\)
==========================================================================
$offText

* \(G(\iota)\) from strip solve; \(\iota\) = replicationStripLength.l
$include models/StripLengthFromGammaBudget.gms

* \(\sigma_{\mathrm{RV}}\) from the tick path (same strike lattice; guarded includes)
$include parameters/TickPathMoments.gms

$onText
===============================================================================
--------------------------------> OUTPUT < -----------------------------------
  \(\pi^{\sigma}_{\mathrm{no\,fee}}\)
===============================================================================
$offText

Scalar positionGammaLevel;
positionGammaLevel = ExposureGlobalGamma(TickSpacing, VegaNotional, replicationStripLength.l);

Scalar noFeeVariancePayoff;
noFeeVariancePayoff = positionGammaLevel * power(realizedVolatility, 2);

put_utility 'log' / 'Iota = ' replicationStripLength.l:0:0;
put_utility 'log' / 'G = ' positionGammaLevel:0:6;
put_utility 'log' / 'sigma_RV = ' realizedVolatility:0:6;
put_utility 'log' / 'noFeeVariancePayoff = ' noFeeVariancePayoff:0:6;

display positionGammaLevel, realizedVolatility, noFeeVariancePayoff;
