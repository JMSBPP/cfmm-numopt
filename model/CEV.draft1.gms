$include infra/TickLattice.draft1.gms
$include instruments/position.gms

$onText
==========================================================================
------------------> CEV STATIC RE STRIKE LATTICE < ---------------------
  Spec: docs/superpowers/specs/2026-10-17-cev-re-strike-lattice-design.md
  Math: cfmm-vol-markets-spec/spec/models/sets/CEV.md
==========================================================================
$offText

$onText
==========================================================================
------------------> FLOW / RE INPUTS < ---------------------------------
==========================================================================
$offText

* \(\sigma_F\): numeraire net-flow diffusion vol (demo scale so i(σ̄) sits near mid ticks).
Scalar flowDiffusionVol;
flowDiffusionVol = 5.2e13;

* Flow drift \(\mu_F\) (local drift macro only; not used for set membership).
Scalar flowDiffusionDrift /0/;

* Central target / striped vol \(\bar\sigma\) and absolute std → band \(\bar\sigma\pm\mathrm{std}\).
Scalar sigmaBar /0.5/;
Scalar sigmaBarStd /0.1/;

$onText
==========================================================================
------------------> MACROS < -------------------------------------------
==========================================================================
$offText

* \(\alpha = \ln(\sigma_F / (L_{1/2}\,\beta))\), \(\beta = \ln(1.0001)\).
$macro cevAlpha(sigmaF, L) (log((sigmaF)/((L)*LN_GRID_RESOLUTION)))

* \(i(\sigma) = (\alpha - \ln\sigma)/\beta\).
$macro cevTickFromVol(sigmaF, L, sigma) toTickSpace(cevAlpha(sigmaF,L) - log(sigma))

* \(\sigma(i) = e^{\alpha - \beta i}\) (price-free local tick vol).
$macro cevLocalVol(sigmaF, L, tick) (exp(cevAlpha(sigmaF,L) - LN_GRID_RESOLUTION*(tick)))

* \(\sqrt{p} = 1.0001^{i}\) from \(i = \log_{1.0001}\sqrt{p}\).
$macro cevSqrtP(tick) (power(GRID_RESOLUTION, tick))

* CEVLocalTickDrift: \(\mu(i) = \mu_F/(L\sqrt{p}) - \sigma_F^2/(2 L^2 p)\).
$macro cevLocalDrift(sigmaF, muF, L, tick) ((muF)/((L)*cevSqrtP(tick)) - power(sigmaF,2)/(2*power(L,2)*power(cevSqrtP(tick),2)))

$onText
==========================================================================
------------------> RE STRIKE FACTORY < --------------------------------
  Band [sigmaBar - std, sigmaBar + std] → i_lo, i_hi → TickSpacing lattice.
==========================================================================
$offText

abort$(sigmaBar - sigmaBarStd <= 0)
    'CEV RE lattice: need sigmaBar - sigmaBarStd > 0 for log';

Scalar iLoRaw, iHiRaw, iLo, iHi, nStrikes;

* Higher vol → lower tick.
iLoRaw = cevTickFromVol(flowDiffusionVol, VegaNotional, sigmaBar + sigmaBarStd);
iHiRaw = cevTickFromVol(flowDiffusionVol, VegaNotional, sigmaBar - sigmaBarStd);

iLo = normTickVal(iLoRaw, TickSpacing);
iHi = normTickVal(iHiRaw, TickSpacing);

iLo = max(MIN_TICK, min(MAX_TICK, iLo));
iHi = max(MIN_TICK, min(MAX_TICK, iHi));

* Guard snap / clip inversion on a tiny band.
Scalar iTmp;
if(iLo > iHi,
   iTmp = iLo;
   iLo  = iHi;
   iHi  = iTmp;
);

nStrikes = 1 + (iHi - iLo)/TickSpacing;

abort$(nStrikes < 1) 'CEV RE lattice: empty strike set';
abort$(nStrikes > 5000)
    'CEV RE lattice: nStrikes exceeds strikeIdx capacity (5000)';

* Index universe; Ticks is the dynamic RE support.
Set strikeIdx /1*5000/;
Set Ticks(strikeIdx);
Ticks(strikeIdx) = no;
Ticks(strikeIdx)$(ord(strikeIdx) <= nStrikes) = yes;

Parameter tickVal(strikeIdx);
* ord must stay on the static universe strikeIdx (not dynamic Ticks).
tickVal(strikeIdx) = iLo + (ord(strikeIdx) - 1)*TickSpacing;
tickVal(strikeIdx)$(not Ticks(strikeIdx)) = 0;

Parameter localTickVol(strikeIdx);
localTickVol(strikeIdx) =
    cevLocalVol(flowDiffusionVol, VegaNotional, tickVal(strikeIdx));
localTickVol(strikeIdx)$(not Ticks(strikeIdx)) = 0;

Parameter localTickDrift(strikeIdx);
localTickDrift(strikeIdx) =
    cevLocalDrift(flowDiffusionVol, flowDiffusionDrift, VegaNotional, tickVal(strikeIdx));
localTickDrift(strikeIdx)$(not Ticks(strikeIdx)) = 0;

display nStrikes, iLo, iHi, tickVal, localTickVol;
