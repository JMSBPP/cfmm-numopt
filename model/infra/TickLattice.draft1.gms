$onText
===============================================================
----------------------> INPUTS <-----------------------------
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

Scalar TickSpacing /10/;

$onText
==================================================================
-----------------------> MACROS < ------------------------------
==================================================================
$offText

* Snap to spacing, then clip to the legal tick universe.
$macro normTickVal(tickVal,tickSpacingVal) (max(MIN_TICK, min(MAX_TICK, (tickSpacingVal)*floor((tickVal)/(tickSpacingVal)))))

* Indexed assignment: p is a Parameter over controlling set t; spacing is numeric.
* \(:\texttt{Tick} \mapsto \texttt{Tick}\)
$macro normTickParam(TickParameter,Ticks,spacing) TickParameter(Ticks) = normTickVal(TickParameter(Ticks),spacing);

* Log-price ↔ tick via \(\ln(1.0001)\): \(\Delta i = \Delta\log_{1.0001}(\cdot)\).
$macro toTickSpace(x) ((x)/LN_GRID_RESOLUTION)
$macro fromTickSpace(x) ((x)*LN_GRID_RESOLUTION)

* Ordered tick interval endpoints (no temp / no clobber).
$macro tickBoundLo(a,b) (min((a),(b)))
$macro tickBoundHi(a,b) (max((a),(b)))

* Real \(\sqrt{p}\) from \(i = \log_{1.0001}\sqrt{p}\): \(\sqrt{p} = 1.0001^{i}\).
$macro sqrtPriceVal(tick) (power(GRID_RESOLUTION, tick))

$macro mulX96(val) ((val)*PRICING_RESOLUTION)
* Q64.96 sqrt-price on the spaced Uniswap-style grid (not the same as sqrtPriceVal).
$macro sqrtPriceX96Val(tickVal,tickSpacingVal) mulX96(power(GRID_RESOLUTION, ((tickVal)*(tickSpacingVal))/2))


