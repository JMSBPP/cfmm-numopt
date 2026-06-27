$include primitives.gms


Scalar lambda /1000100000000000000/;

Set inventory "pool inventory" / X, Y /;
Set tick "ticks from -120 to 120" / k1*k241 /;


Scalar tickSpacing /1/;
Set tickSpacingDomain /s1*s60/;
Parameter tickSpacingVal(tickSpacingDomain);
tickSpacingVal(tickSpacingDomain) = ord(tickSpacingDomain);


Parameter tickVal(tick);
tickVal(tick) = ord(tick) - 121;


Parameter priceKernel(tickSpacingDomain,tick);
priceKernel(tickSpacingDomain,tick) =
    (lambda / unity) ** (tickVal(tick) * tickSpacingVal(tickSpacingDomain) / 2)
    * power(2, 96);


* priceKernel(x) == getSqrtPriceAtTick(x): EVM Q64.96 sqrt price = 1.0001^(tick/2) * 2^96.
* The /2 is the sqrt; * 2^96 is the Q64.96 fixed-point scaling the EVM uses.
* `**` (real power) is required because tick/2 is half-integer for odd ticks;
* `power()` only accepts integer exponents.


* tunablePricingKernel(s,t,e): generalization of priceKernel where the fixed sqrt
* weight 1/2 is replaced by a tunable weight e. e is the dimensionless elasticity
* eta = eta_x_y/unity from TradingRegion (poolLiquidityCone weights inventory with
* the same eta_x_y/unity). e = 1/2 is the balanced 50/50 pool and recovers
* priceKernel exactly (the EVM getSqrtPriceAtTick); e <> 1/2 gives a weighted,
* asymmetric bonding curve. Implemented as a $macro so it takes eta as an argument
* without PricingKernel depending on TradingRegion (whose `inventory` set clashes).
$macro tunablePricingKernel(s, t, e) ( (lambda / unity) ** (tickVal(t) * tickSpacingVal(s) * (e)) * power(2, 96) )
