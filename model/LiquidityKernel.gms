$include primitives.gms
$include PricingKernel.gms


Scalar xi "Current value of xi";
xi = precision ;
Set xiDomain "Admissible xi domains" / belowOne, aboveOne /;

Parameter
    xiLo(xiDomain) "Lower bound"
    xiUp(xiDomain) "Upper bound"
    xiVal(xiDomain) "Representative xi value";

xiLo("belowOne") = precision;
xiUp("belowOne") = unity - precision;
xiLo("aboveOne") = unity + precision;
xiUp("aboveOne") = uintMax;

xiVal("belowOne") = precision;
xiVal("aboveOne") = unity + precision;

Parameter xiNorm(xiDomain);
	  xiNorm(xiDomain) = xiVal(xiDomain) / unity;


Scalar iota "Current value of xi";
iota = unityTick;
Set iotaDomain "Admissible iota domains" /positiveInteger/ ;

Parameter
    iotaLo(iotaDomain) "Lower bound"
    iotaUp(iotaDomain) "Upper bound"
    iotaVal(iotaDomain) "Representative iota value";

iotaLo("positiveInteger") = unityTick;
iotaUp("positiveInteger") = maxTick;
iotaVal("positiveInteger") = unityTick;


Parameter tickOrder(tick);
	  tickOrder(tick) = ord(tick) - 1;


Parameter liquidityKernel(xiDomain, iotaDomain, tick);
liquidityKernel(xiDomain, iotaDomain, tick) =
			  (
			      power(xiNorm(xiDomain) ,tickOrder(tick)) /
			      (
			        (unityTick - power(xiNorm(xiDomain),iotaVal(iotaDomain)))
			         /(unityTick - xiNorm(xiDomain))
			       )
);

