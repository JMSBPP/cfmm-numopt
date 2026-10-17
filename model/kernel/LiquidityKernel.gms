$onText
==========================================================================
------------------> LiquidityKernel < ----------------------------------
  Spec formulas: cfmm-vol-markets-spec/spec/MAIN_SPEC.md
  Draft1 strike source: $include CEV.TickStrikes.draft1.gms
==========================================================================
$offText

$onText
==================================================================================
	------------------> INPUTS <-----------------------
==================================================================================
$offText

Scalar GlobalGammaTarget;


$include CEV.TickStrikes.draft1.gms

$onText
==================================================================================
	------------------> MACROS <-----------------------
==================================================================================
$offText

*\(\xi^{\star} = \lambda^{-\Delta_i/2}\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md::L176

$macro LiqBase(tickSpacing) power(GRID_RESOLUTION,-(tickSpacing)/2)

$onText
 \(m_{\Gamma} \, \leftarrow \, \frac{\Gamma_{\varphi}(i_K+\Delta_i)}{\Gamma_{\varphi}(i_K)} \, = \, \xi^{\,-3\eta\,\Delta_i}\); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L379
$offText

$macro GammaMultiplier(tickSpacing) power(LiqBase(tickSpacing), -3*(tickSpacing))

* \(\Gamma_{\varphi}(i) \, \equiv \, \xi^{\,-3\eta\,(i + \Delta_i/2)}\); cfmm-vol-markets-spec/spec/MAIN_SPEC.md::L391

$macro GammaAt(tick, tickSpacing) power(LiqBase(tickSpacing), -3*((tick) + (tickSpacing)/2))

* \(G(\iota) \, = \, \frac{\bar L_{(1/2,\,0)}}{2}\,\frac{1-\xi^{\star}}{1-(\xi^{\star})^{\iota}}\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L402

* rPower: ι may be a Variable inside MODEL equations (power forbids non-constant exponents).
$macro ExposureGlobalGamma(tickSpacing, vegaNotional, replicationStripLength) (((vegaNotional)/2)*((1-LiqBase(tickSpacing))/(1-rPower(LiqBase(tickSpacing),(replicationStripLength)))))

* \(\ell \, (\xi, \iota; i_K) \, = \, \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)} \); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L147
$macro liquidityMassAt(tickSpacing, tickVal, replicationStripLength) (power(LiqBase(tickSpacing), (tickVal))*(1-LiqBase(tickSpacing))/(1-rPower(LiqBase(tickSpacing),(replicationStripLength))))

* \(L \, (i_K) \, = \, \bar L_{(1/2,\,0)} \, \cdot \, \ell \, (\xi, \iota; i_K)\); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L147
$macro liquidityOnStrikeAt(tickSpacing, tickVal, replicationStripLength, vegaNotional) ((vegaNotional)*liquidityMassAt(tickSpacing, tickVal, replicationStripLength))

* \(\sum_{i_K} \, \ell \, (\xi, \iota; i_K)\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L155
* tickStrikes = support set; tickLevel = tick level on that set (draft1: TickStrikes, tickStrikeVal).
$macro GlobalLiquidityMass(tickStrikes, tickSpacing, tickLevel, replicationStripLength) (sum(tickStrikes, liquidityMassAt(tickSpacing, tickLevel(tickStrikes), replicationStripLength)))

$onText
==========================================================================
-------------------------> ENDOGENOUS VARIABLES < ----------------------
==========================================================================
$offText

* \(\iota \in \mathbb{N}\), \(\iota \ge 1\). ;  cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L178

Integer Variable replicationStripLength;
replicationStripLength.lo = 1;
replicationStripLength.up = nStrikes;
replicationStripLength.l = nStrikes;
Equation replicationStripLengthDomain;
	 replicationStripLengthDomain.. replicationStripLength =g= 1;


$onText
===============================================================================
--------------------------------> OUTPUTS < ----------------------------------
  \(\Big(
    \big(\Gamma_{\varphi},\; m_{\Gamma}\big),\;
    \ell,\;
    L(i_K),\;
    L(\Gamma_i)
  \Big)
  \equiv \Big(
    \big(\texttt{GammaProfile},\; \texttt{gamma}\big),\;
    \texttt{mGamma},\;
    \texttt{liquidityWeight},\;
    \big(\texttt{LiquidityOnStrike},\; \texttt{liquidityOnStrikeVal}\big),\;
    \texttt{liquidityOnGammaVal}
  \Big)\)
===============================================================================
$offText

Set GammaProfile(strikeIdx);
GammaProfile(strikeIdx) = no;

Parameter gamma(strikeIdx);
gamma(strikeIdx) = 0;

loop(strikeIdx$TickStrikes(strikeIdx),
   GammaProfile(strikeIdx) = yes;
   gamma(strikeIdx) = GammaAt(tickStrikeVal(strikeIdx), TickSpacing);
);

Scalar mGamma;
mGamma = GammaMultiplier(TickSpacing);

* \(\ell\) weight (not absolute \(L\)); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L147
Parameter liquidityWeight(strikeIdx);
liquidityWeight(strikeIdx) = liquidityMassAt(TickSpacing, tickStrikeVal(strikeIdx), replicationStripLength.l);

* \(\sum_{i_K} \, \ell \, (\xi, \iota; i_K) \, = \, 1 \) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L155
* Draft1: TickStrikes proxy for the strip; exact =e=1 is integer-infeasible, so a tight band.
Scalar liquidityWeightTol /1e-2/;
Equation liquidityWeightDomainLo, liquidityWeightDomainHi;
	liquidityWeightDomainLo.. GlobalLiquidityMass(TickStrikes, TickSpacing, tickStrikeVal, replicationStripLength)
	    =g= 1 - liquidityWeightTol;
	liquidityWeightDomainHi.. GlobalLiquidityMass(TickStrikes, TickSpacing, tickStrikeVal, replicationStripLength)
	    =l= 1 + liquidityWeightTol;

* \(G(\iota) \, \ge \, g\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L416
* Draft1: \(g\) and the RHS are in units of \(\bar L\equiv\texttt{VegaNotional}\) (keeps NLP RHS below solver limits).
Equation gammaBudget;
	 gammaBudget.. GlobalGammaTarget =l=
	    ExposureGlobalGamma(TickSpacing, VegaNotional, replicationStripLength) / VegaNotional;

* |LiquidityOnStrike| = |TickStrikes|; level parameter liquidityOnStrikeVal = L(i_K).
* Domain: \(0 < L(i_K) < 2^{128}\) (uint128).
Set LiquidityOnStrike(strikeIdx);
LiquidityOnStrike(strikeIdx) = no;

Parameter liquidityOnStrikeVal(strikeIdx);
liquidityOnStrikeVal(strikeIdx) = 0;

Scalar liqOnStrikeHi;
liqOnStrikeHi = power(2, 128);

loop(strikeIdx$TickStrikes(strikeIdx),
   LiquidityOnStrike(strikeIdx) = yes;
   liquidityOnStrikeVal(strikeIdx) =
      liquidityOnStrikeAt(TickSpacing, tickStrikeVal(strikeIdx), replicationStripLength.l, VegaNotional);
);

abort$(sum(LiquidityOnStrike$(liquidityOnStrikeVal(LiquidityOnStrike) <= 0), 1))
   'LiquidityOnStrike: need L(i_K) > 0';
abort$(sum(LiquidityOnStrike$(liquidityOnStrikeVal(LiquidityOnStrike) >= liqOnStrikeHi), 1))
   'LiquidityOnStrike: need L(i_K) < 2^128';

* \(L(\Gamma_i) = 2\,G(\iota)\,\Gamma_i^{1/3}\); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L422
Parameter liquidityOnGammaVal(strikeIdx);
liquidityOnGammaVal(strikeIdx) = 0;
liquidityOnGammaVal(strikeIdx)$GammaProfile(strikeIdx) =
   2 * ExposureGlobalGamma(TickSpacing, VegaNotional, replicationStripLength.l)
   * rPower(gamma(strikeIdx), 1/3);

display nStrikes, mGamma, gamma, liquidityWeight, liquidityOnStrikeVal, liquidityOnGammaVal;
