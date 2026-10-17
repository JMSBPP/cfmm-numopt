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

$macro ExposureGlobalGamma(tickSpacing, vegaNotional, ladderResolution) (((vegaNotional)/2)*((1-LiqBase(tickSpacing))/(1-power(LiqBase(tickSpacing),(ladderResolution)))))

* \(\ell \, (\xi, \iota; i_K) \, = \, \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)} \); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L147
$macro liquidityMassAt(tickSpacing, tickVal, ladderResolution) (power(LiqBase(tickSpacing), (tickVal))/(1-power(LiqBase(tickSpacing),(ladderResolution))/(1-LiqBase(tickSpacing))))


*\(L \, (i_K) \, = \, \bar L_{(1/2,\,0)} \, \cdot \, \ell \, (\xi, \iota; i_K)\); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L147

$macro liquidityOnStrikeAt(tickSpacing ,tickVal, ladderResolution,vegaNotional) vegaNotional*liquidityMassAt(tickSpacing, tickVal,ladderResolution)

* \(\sum_{i_K} \, \ell \, (\xi, \iota; i_K)\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L155
* tickStrikes = support set; tickLevel = tick level on that set (draft1: TickStrikes, tickStrikeVal).
$macro GlobalLiquidityMass(tickStrikes, tickSpacing, tickLevel, ladderResolution) (sum(tickStrikes, liquidityMassAt(tickSpacing, tickLevel(tickStrikes), ladderResolution)))

$onText
==========================================================================
-------------------------> ENDOGENOUS VARIABLES < ----------------------
==========================================================================
$offText

* \(\iota \in \mathbb{N}\), \(\iota \ge 1\). ;  cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L178

Integer Variable LadderResolution;
LadderResolution.lo = 1;
Equation ladderResolutionDomain;
	 ladderResolutionDomain.. LadderResolution =g= 1;


$onText
==========================================================================
-------------------------> OUTPUTS < ------------------------------
==========================================================================
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


Parameter liquidityDensity(strikeIdx);
liquidityDensity(strikeIdx) = liquidityMassAt(TickSpacing, tickStrikeVal(strikeIdx), LadderResolution.l);

* \(\sum_{i_K} \, \ell \, (\xi, \iota; i_K) \, = \, 1 \) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L155

Equation liquidityDensityDomain;
	liquidityDensityDomain.. GlobalLiquidityMass(TickStrikes, TickSpacing, tickStrikeVal, LadderResolution) =e= 1;

* \(G(\iota) \, \ge \, g\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L416
Equation gammaBudget;
	 gammaBudget.. GlobalGammaTarget =l= ExposureGlobalGamma(TickSpacing, VegaNotional, LadderResolution);


*\(L \, (i_K) \, = \, \bar L_{(1/2,\,0)} \, \cdot \, \ell \, (\xi, \iota; i_K)\); cfmm-vol-markets-spec/spec/MAIN_SPEC.md:L147
Set LiquidityOnStrike(strikeIdx);
* fill the set





display nStrikes, mGamma, gamma;
