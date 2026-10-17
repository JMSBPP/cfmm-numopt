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
===============================================================================
--------------------------------> INPUTS < -----------------------------------
  Only a tick path: set TickPath and level parameter pathTickVal.
  (Draft1: supplied by $include CEV.TickPath.draft1.gms)
===============================================================================
$offText

* \(\big(\texttt{TickPath},\; \texttt{pathTickVal}\big)\)

$onText
==========================================================================
------------------> MACROS < -------------------------------------------
==========================================================================
$offText

* \(\mu = N^{-1}\sum_t v(t)\)  (cf. TickAverage in RealizedVolatility.draft1.gms)
$macro mean_tickPath(S, v) (sum(S, v(S)) / card(S))

* \(\sigma_{\mathrm{RV}}^{2}\)-style sample second moment: \((N-1)^{-1}\sum_t (v(t)-\mu)^2\)
$macro realized_volatility(S, v, m) (sum(S, power(v(S) - (m), 2)) / (card(S) - 1))

$onText
===============================================================================
--------------------------------> OUTPUTS < ----------------------------------
  \(\big(\mu,\; \sigma_{\mathrm{RV}}\big)
  \equiv \big(\texttt{meanTickPath},\; \texttt{realizedVolatility}\big)\)
===============================================================================
$offText

Scalar nPath, meanTickPath, realizedVolatility;

nPath = card(TickPath);
abort$(nPath < 2) 'TickPathMoments: need card(TickPath) >= 2';

* \(\mu\)
meanTickPath = mean_tickPath(TickPath, pathTickVal);
* \(\sigma_{\mathrm{RV}}\)
realizedVolatility = realized_volatility(TickPath, pathTickVal, meanTickPath);

display nPath, meanTickPath, realizedVolatility;
