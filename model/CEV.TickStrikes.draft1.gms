$include infra/TickLattice.draft1.gms
$include kernel/Exposure.gms

$onText
==========================================================================
------------------> CEV.TickStrikes < ----------------------------------
  Spec: cfmm-vol-markets-spec/spec/models/sets/CEV.md
        (GAMS design section at top; source math below)
  Model: model/CEV.TickStrikes.draft1.gms
==========================================================================
$offText

$onText
===============================================================================
-----------------------------------> INPUTS < ---------------------------------
===============================================================================
$offText

*  --------------->  \(\Big (\sigma_F, \mu_F, [\sigma_l, \sigma_u]\Big )\) < ---------------------
* \(\sigma_F\):
Scalar flowDiffusionVol;
flowDiffusionVol = 5.2e13;

* \(\mu_F\) .
Scalar flowDiffusionDrift /0/;

* Central target / striped vol \(\bar\sigma\) and absolute std → band \(\bar\sigma\pm\mathrm{std}\).
* \(\sigma_K\)
Scalar sigmaBar /0.5/;
* \(\sigma_{\sigma_K}\)
Scalar sigmaBarStd /0.1/;

abort$(sigmaBar - sigmaBarStd <= 0)
    'CEV RE lattice: need sigmaBar - sigmaBarStd > 0 for log';

$onText
==========================================================================
------------------------> MACROS < -------------------------------------------
==========================================================================
$offText

* \(\alpha = \ln(\sigma_F / (L_{1/2}\,\ln(1.0001)))\).
$macro cevAlpha(sigmaF, L) (log((sigmaF)/((L)*LN_GRID_RESOLUTION)))

* \(i(\sigma) = (\alpha - \ln\sigma)/ \ln(1.0001)\).
$macro cevTickFromVol(sigmaF, L, sigma) toTickSpace(cevAlpha(sigmaF,L) - log(sigma))

* \(\sigma(i) = e^{\alpha - \beta i}\) 
$macro cevLocalVol(sigmaF, L, tick) (exp(cevAlpha(sigmaF,L) - fromTickSpace(tick)))

* \(\mu(i) = \mu_F/(L\sqrt{p}) - \sigma_F^2/(2 L^2 p)\).
$macro cevLocalDrift(sigmaF, muF, L, tick) ((muF)/((L)*sqrtPriceVal(tick)) - power(sigmaF,2)/(2*power(L,2)*power(sqrtPriceVal(tick),2)))



* \( N_K \, = \, 1 + \frac{\lvert i(\sigma_K- \sigma_{\sigma_K}) - i(\sigma_K+ \sigma_{\sigma_K})\rvert}{\Delta_i} \)
$macro cevNStrikes(sigmaF, L, sigmaBar, std, spacing) (1 + abs(normTickVal(cevTickFromVol(sigmaF,L,(sigmaBar)-(std)),spacing) - normTickVal(cevTickFromVol(sigmaF,L,(sigmaBar)+(std)),spacing))/(spacing))

$onText
==========================================================================
------------------> TICK STRIKE FACTORY < --------------------------------
==========================================================================
$offText


Scalar iLo, iHi, nStrikes;


iLo = normTickVal(cevTickFromVol(flowDiffusionVol, VegaNotional, sigmaBar + sigmaBarStd), TickSpacing);
iHi = normTickVal(cevTickFromVol(flowDiffusionVol, VegaNotional, sigmaBar - sigmaBarStd), TickSpacing);


Scalar iLoRaw, iHiRaw;
iLoRaw = iLo;
iHiRaw = iHi;
iLo = tickBoundLo(iLoRaw, iHiRaw);
iHi = tickBoundHi(iLoRaw, iHiRaw);

nStrikes = cevNStrikes(flowDiffusionVol, VegaNotional, sigmaBar, sigmaBarStd, TickSpacing);

abort$(nStrikes < 1) 'CEV RE lattice: empty strike set';
abort$(nStrikes > 5000)
    'CEV RE lattice: nStrikes exceeds strikeIdx capacity (5000)';

$onText
=============================================================================
--------------------------> OUTPUTS <---------------------------------------
=============================================================================
$offText


* -------------- \(\Big\{ (i_K, \sigma (i_K), \mu (i_K))\Big\}_{j=1}^{N_K}\) ------------------------------------
Set strikeIdx /1*5000/;
Set TickStrikes(strikeIdx);

TickStrikes(strikeIdx) = no;
TickStrikes(strikeIdx)$(ord(strikeIdx) <= nStrikes) = yes;

Parameter tickStrikeVal(strikeIdx);
* ord must stay on the static universe strikeIdx (not dynamic TickStrikes).
tickStrikeVal(strikeIdx) = iLo + (ord(strikeIdx) - 1)*TickSpacing;
tickStrikeVal(strikeIdx)$(not TickStrikes(strikeIdx)) = 0;

Parameter localTickVol(strikeIdx);
localTickVol(strikeIdx) =
    cevLocalVol(flowDiffusionVol, VegaNotional, tickStrikeVal(strikeIdx));
localTickVol(strikeIdx)$(not TickStrikes(strikeIdx)) = 0;

Parameter localTickDrift(strikeIdx);
localTickDrift(strikeIdx) =
    cevLocalDrift(flowDiffusionVol, flowDiffusionDrift, VegaNotional, tickStrikeVal(strikeIdx));
localTickDrift(strikeIdx)$(not TickStrikes(strikeIdx)) = 0;

display nStrikes, iLo, iHi, tickStrikeVal, localTickVol, localTickDrift;
