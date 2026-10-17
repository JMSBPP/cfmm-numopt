$onText
===============================================================
----------------------> SCALARS <-----------------------------
==============================================================
$offText

Scalar ZERO_TICK /0/;
Scalar MAX_TICK /8388607/;
Scalar MIN_TICK /-8388607/;
Scalar GRID_RESOLUTION /1.0001/;
* \(\ln(1.0001)\): change-of-base factor for \(i = \log_{1.0001}\sqrt{p}\) (CEV TickDynamics).
Scalar LN_GRID_RESOLUTION;
LN_GRID_RESOLUTION = log(GRID_RESOLUTION);
Scalar PRICING_RESOLUTION;
PRICING_RESOLUTION = power(2, 96);

$onText
	NOTE: From now we fix a tick spacing, although is aimed as a tunable design parameter and needs
	to be modeled as such
$offText

Scalar TickSpacing /10/;

$onText
NOTE: This is a placeholder
$offText

$onText
==================================================================
-----------------------> SETS < ------------------------------
==================================================================
$offText

*Set Ticks;

$onText
==================================================================
-----------------------> MACROS < ------------------------------
==================================================================
$offText

* Scalar expression: args must already be numeric (Scalar or Parameter element).
$macro normTickVal(tickVal,tickSpacingVal) (tickSpacingVal*floor((tickVal)/(tickSpacingVal)))

* Indexed assignment: p is a Parameter over controlling set t; spacing is numeric.
* \(:\texttt{Tick} \mapsto \texttt{Tick}\)
$macro normTickParam(TickParameter,Ticks,spacing) TickParameter(Ticks) = normTickVal(TickParameter(Ticks),spacing);

* Log-price ↔ tick via \(\ln(1.0001)\): \(\Delta i = \Delta\log_{1.0001}(\cdot)\).
$macro toTickSpace(x) ((x)/LN_GRID_RESOLUTION)
$macro fromTickSpace(x) ((x)*LN_GRID_RESOLUTION)

$macro mulX96(val) ((val)*PRICING_RESOLUTION)
$macro sqrtPriceX96Val(tickVal,tickSpacingVal) mulX96(power(GRID_RESOLUTION, ((tickVal)*(tickSpacingVal))/2))


