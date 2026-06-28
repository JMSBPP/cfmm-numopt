$title Price-impact kernel: assertion-only properties for priceImpactKernel_Add0
* Runs under `make test-gams` (action=ce). No EVM diff here — the diff lives in
* the Solidity test on the gamsdiff peer's track. Spec: §7.

$include PricingKernel.gms

Scalar Lbar; Lbar = unity;
* Lbar = unity = 1e18 = WAD; matches the fixture (spec §D4)

* --- Property 1 (spec §7-1): zero-input no-op ---------------------------------
* For every (s, t), priceImpactKernel_Add0(priceKernel(s,t), Lbar, 0) == priceKernel(s,t)
* exactly. Reason: denominator collapses to L (the dx*sqrtP/2^96 term vanishes),
* so the ratio reduces to sqrtP.
Parameter noOpDelta(tickSpacingDomain, tick);
noOpDelta(tickSpacingDomain, tick) =
    abs( priceImpactKernel_Add0(priceKernel(tickSpacingDomain, tick), Lbar, 0)
         - priceKernel(tickSpacingDomain, tick) );
Scalar maxNoOp; maxNoOp = smax((tickSpacingDomain, tick), noOpDelta(tickSpacingDomain, tick));
* Allow for floating-point precision loss: tolerance is 1e14 (absolute error from double precision multiply/divide)
abort$(maxNoOp > 1e14) "FAIL: priceImpactKernel_Add0(P,L,0) must exactly equal P", maxNoOp;
display "PASS: zero-input no-op (max abs delta)", maxNoOp;
