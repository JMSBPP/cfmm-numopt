$onText
==========================================================================
------------------> LiquidityKernel (parameters) < ----------------------
  Macros + gamma coordinate tables. Spec: MAIN_SPEC / Theorems 51–52.
  Strike source: parameters/CEV.TickStrikes.gms
==========================================================================
$offText

$onText
==================================================================================
	------------------> INPUTS <-----------------------
==================================================================================
$offText

Scalar GlobalGammaTarget;

$if not declared TickStrikes $include parameters/CEV.TickStrikes.gms

$onText
==================================================================================
	------------------> MACROS <-----------------------
==================================================================================
$offText

*\(\xi^{\star} = \lambda^{-\Delta_i/2}\) ; cfmm-vol-markets-spec/spec/MAIN_SPEC.md::L176
$macro LiqBase(tickSpacing) power(GRID_RESOLUTION,-(tickSpacing)/2)

$onText
 \(m_{\Gamma} \, \leftarrow \, \frac{\Gamma_{\varphi}(i_K+\Delta_i)}{\Gamma_{\varphi}(i_K)} \, = \, \xi^{\,-3\eta\,\Delta_i}\); MAIN_SPEC:L379
$offText
$macro GammaMultiplier(tickSpacing) power(LiqBase(tickSpacing), -3*(tickSpacing))

* \(\Gamma_{\varphi}(i) \, \equiv \, \xi^{\,-3\eta\,(i + \Delta_i/2)}\); MAIN_SPEC::L391
$macro GammaAt(tick, tickSpacing) power(LiqBase(tickSpacing), -3*((tick) + (tickSpacing)/2))

* \(G(\iota) \, = \, \frac{\bar L_{(1/2,\,0)}}{2}\,\frac{1-\xi^{\star}}{1-(\xi^{\star})^{\iota}}\) ; MAIN_SPEC:L402
* rPower: ι may be a Variable inside MODEL equations (power forbids non-constant exponents).
$macro ExposureGlobalGamma(tickSpacing, vegaNotional, replicationStripLength) (((vegaNotional)/2)*((1-LiqBase(tickSpacing))/(1-rPower(LiqBase(tickSpacing),(replicationStripLength)))))

* \(\ell \, (\xi, \iota; i_K) \, = \, \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)} \); MAIN_SPEC:L147
$macro liquidityMassAt(tickSpacing, tickVal, replicationStripLength) (power(LiqBase(tickSpacing), (tickVal))*(1-LiqBase(tickSpacing))/(1-rPower(LiqBase(tickSpacing),(replicationStripLength))))

* \(L \, (i_K) \, = \, \bar L_{(1/2,\,0)} \, \cdot \, \ell \, (\xi, \iota; i_K)\); MAIN_SPEC:L147
$macro liquidityOnStrikeAt(tickSpacing, tickVal, replicationStripLength, vegaNotional) ((vegaNotional)*liquidityMassAt(tickSpacing, tickVal, replicationStripLength))

* \(\sum_{i_K} \, \ell \, (\xi, \iota; i_K)\) ; MAIN_SPEC:L155
$macro GlobalLiquidityMass(tickStrikes, tickSpacing, tickLevel, replicationStripLength) (sum(tickStrikes, liquidityMassAt(tickSpacing, tickLevel(tickStrikes), replicationStripLength)))

$onText
===============================================================================
--------------------------------> OUTPUTS (coordinate tables) < --------------
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

Parameter liquidityWeight(strikeIdx);
Set LiquidityOnStrike(strikeIdx);
Parameter liquidityOnStrikeVal(strikeIdx);
Parameter liquidityOnGammaVal(strikeIdx);
Scalar liquidityWeightTol /1e-2/;
Scalar liqOnStrikeHi;
liqOnStrikeHi = power(2, 128);

display nStrikes, mGamma, gamma;
