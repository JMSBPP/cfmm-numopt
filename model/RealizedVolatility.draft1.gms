$onText
	HUMAN_GUIDE:
		- Use `math-preview-region` over the LaTeX code over `math-preview-all`
$offText


$onText
TODO: Figure out the way to do this
include "TickLattice.draft1.gms"
$offText


$onText
==========================================================================
------------------> PRIMITIVE COORDINATES/INDEXES/SETS < ---------------------
==============================================================================
$offText
Scalar GridResolution;
GridResolution = 1.0001;

Scalar TickSpacing;
TickSpacing = 10;

Set Ticks /200, 400, 600/;

Parameter tickVal(Ticks) /
    200 200
    400 400
    600 600
/;

* \(i = \Delta_i \, \cdot \, \lfloor \, \frac{i}{\Delta_i} \, \rfloor\)TODO: Missing a math reference

tickVal(Ticks) = TickSpacing * floor(tickVal(Ticks) / TickSpacing);


$onText
==================================================================
------------------> REALIZED PARAMETERS < ------------------------
=================================================================
$offText


$onText
https://www.gams.com/54/docs/UG_OrderedSets.html --> card
https://www.gams.com/54/docs/UG_Parameters.html  --> avg
$offText

Parameter TickAverage;
TickAverage = sum(Ticks, tickVal(Ticks))/ card(Ticks);

Scalar volWindow;
volWindow = card(Ticks) -1;
Parameter RealizedVolatility;

RealizedVolatility = sum(Ticks, power(tickVal(Ticks) - TickAverage,2)) / volWindow;


$onText
From cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md, note that
$offText

*\(\xi^{\star} = \lambda^{-\Delta_i/2}\) ; cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md::L176
Scalar Xi;
Xi = power(GridResolution,-TickSpacing/2);



display "Xi", Xi;
put_utility 'log' / 'Xi = ' Xi:0:6;


$onText
=======================================================================
---------------> DERIVED COORDINATES/INDEXES/SETS <-------------------
======================================================================
$offText


$onText
[Dynamic Sets](https://www.gams.com/54/docs/UG_DynamicSets.html)
[Ordered Sets](https://www.gams.com/54/docs/UG_OrderedSets.html)
$offText


Parameter gammaVal(Ticks);

* \(\Gamma_{\varphi}(i) \, \equiv \, \xi^{\,-3\eta\,(i + \Delta_i/2)}\); cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L395
gammaVal(Ticks) = power(Xi, -3 * (tickVal(Ticks) + TickSpacing/2));

Scalar GammaMultiplier;

* \(m_{\Gamma} \, \leftarrow \, \frac{\Gamma_{\varphi}(i_K+\Delta_i)}{\Gamma_{\varphi}(i_K)} \, = \, \xi^{\,-3\eta\,\Delta_i}\); cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L379
GammaMultiplier = floor(power(Xi, -3*TickSpacing));

display "GammaMultiplier", GammaMultiplier;
put_utility 'log' / 'GammaMultiplier = ' GammaMultiplier:0:6;

Set Gamma(Ticks);
Gamma(Ticks)$(ord(Ticks) > 1) =
    yes$(gammaVal(Ticks) = GammaMultiplier * gammaVal(Ticks-1));



$onText
========================================================================
-----------------------> CFMM DERIVATIVE  <--------------------------
========================================================================
$offText

* \(\bar L_{(1/2,0)}\) TODO
Scalar VegaNotional;
VegaNotional = 10;


$onText
=======================================================================================
-----------------------> CFMM DERIVATIVE.GREEKS_EXPOSURE  <--------------------------
=====================================================================================
$offText


* \(g\, > 0\); cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L402
Scalar MoneyLegGammaExposure;
MoneyLegGammaExposure = 2;

* \(\iota \in \mathbb{N}\), \(\iota \ge 1\). ;  cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L178

Integer Variable Iota;
Iota.lo = 1;
Equation iotaDomain;
	 iotaDomain.. Iota =g= 1;

* \(G(\iota) \, = \, \frac{\bar L_{(1/2,\,0)}}{2}\,\frac{1-\xi^{\star}}{1-(\xi^{\star})^{\iota}}\) ; cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L402
* \(G\) is strictly decreasing, so the floor \(G(\iota) \ge g\) is an upper bound on \(\iota\).
* Maximizing \(\iota\) picks that bound. Equality \(G(\iota) = g\) need not hit an integer.
Variable PositionGammaLevel;
Equation defPositionGammaLevel;
	 defPositionGammaLevel.. PositionGammaLevel =e= (VegaNotional/2) * (1-Xi) / (1-(Xi**Iota));

Equation GammaExposureSolvency;
	 GammaExposureSolvency.. MoneyLegGammaExposure =l= PositionGammaLevel;

Variable obj;
Equation pickIota;
	 pickIota.. obj =e= Iota;

Model gammaLevel / iotaDomain, defPositionGammaLevel, GammaExposureSolvency, pickIota /;

option minlp = sbb;
option nlp = conopt;
Iota.l = 1;
Solve gammaLevel using minlp maximizing obj;

abort$(gammaLevel.solveStat <> %solveStat.normalCompletion%)
    "solver did not terminate normally", gammaLevel.solveStat;
abort$(gammaLevel.modelStat > 2 and gammaLevel.modelStat <> %modelStat.integerSolution%)
    "no integer solution for iota", gammaLevel.modelStat;

put_utility 'log' / 'Iota = ' Iota.l:0:0;

* \(\ell \, (\xi, \iota; i_K) \, = \, \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)} \); cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L147
Parameter liquidityMass(Ticks);
	 liquidityMass(Ticks) = power(Xi, tickVal(Ticks))/(1-power(Xi,Iota.l)/(1-Xi));

*\(L \, (i_K) \, = \, \bar L_{(1/2,\,0)} \, \cdot \, \ell \, (\xi, \iota; i_K)\); cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L147
Parameter RungLiquidity(Ticks);
	 RungLiquidity(Ticks) = VegaNotional*liquidityMass(Ticks);

* \(L(\Gamma_i) = 2\,G(\iota)\,\Gamma_i^{1/3}\); cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md:L420
Parameter RungLiquidityOnGamma(Ticks);
	 RungLiquidityOnGamma(Ticks) = 2*PositionGammaLevel.l*gammaVal(Ticks)**(1/3);


$onText
We are now concerned with how to engineer a payoff which scales from volatility and considers the definitions of implied volatility.

Note, that given a fixed fee rate \(\bar \phi \in (0,1)\), implied volatility is defined as:

\[
	\begin{aligned}
		\sigma_{\mathrm{IV}} \, &= \, 2 \, \bar \phi \, \sqrt{\frac{V}{L}}
	\end{aligned}
\]

> TODO: We are missing some dimension precisions on L and V AND there refence which is cfmm8.pdf but we can start connecting some dots

Say we can define:

\[
	\begin{aligned}
		\nu \, (i) \, &:= \, \sqrt{\frac{V}{L (i)}}
	\end{aligned}
\]
Then:

\[
	\begin{aligned}
		\sigma_{\text{IV}} \, (i) = 2 \bar \phi \, \nu\, (i)
	\end{aligned}
\]

Now, over some ordered ticks set can define:

\[
	\begin{aligned}
		\kappa_{\varphi}(i) = \log_{\xi^{2\eta\Delta_i}}\big(L_{(1/2,\,0)}(i+\Delta_i)/L_{(1/2,\,0)}(i)\big)
	\end{aligned}

\] ; cfmm-vol-markets-spec/notes/VOLATILITY_INSTRUMENTS.md::L461

$offText

Set Kappa(Ticks);
Kappa(Ticks)$(ord(Ticks) > 1) =
    yes$(gammaVal(Ticks) = GammaMultiplier * gammaVal(Ticks-1));

