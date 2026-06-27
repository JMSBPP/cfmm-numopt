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
    power(lambda / unity, tickVal(tick/2) * tickSpacingVal(tickSpacingDomain));


// priceKernel (x) == getSqrtPriceAtTick()