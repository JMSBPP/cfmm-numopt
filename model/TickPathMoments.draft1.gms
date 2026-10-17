$include CEV.TickPath.draft1.gms

$onText
==========================================================================
------------------> TickPathMoments < ----------------------------------
  Spec: cfmm-vol-markets-spec/spec/models/sets/TickPathMoments.md
  Generic mean + RV macros; draft1 path source = CEV.TickPath
  Formulas: model/RealizedVolatility.draft1.gms (TickAverage / RV)
==========================================================================
$offText

$onText
==========================================================================
------------------> MACROS < -------------------------------------------
==========================================================================
$offText

* \(\bar i = N^{-1}\sum_t v(t)\)  (cf. TickAverage in RealizedVolatility.draft1.gms)
$macro mean_tickPath(S, v) (sum(S, v(S)) / card(S))

* Sample second moment: \((N-1)^{-1}\sum_t (v(t)-m)^2\)
$macro realized_volatility(S, v, m) (sum(S, power(v(S) - (m), 2)) / (card(S) - 1))

$onText
==========================================================================
------------------> OUTPUTS < ------------------------------------------
==========================================================================
$offText

Scalar nPath, meanTickPath, realizedVolatility;

nPath = card(TickPath);
abort$(nPath < 2) 'TickPathMoments: need card(TickPath) >= 2';

meanTickPath = mean_tickPath(TickPath, pathTickVal);
realizedVolatility = realized_volatility(TickPath, pathTickVal, meanTickPath);

display nPath, meanTickPath, realizedVolatility;
