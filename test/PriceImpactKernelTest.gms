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
* IEEE doubles do not preserve (L*P)/L == P exactly when P is not a power of 2
* (the multiplication rounds, the division can't always recover the exact bits).
* The algebraic "exactly" claim in spec §7-1 holds symbolically, not in IEEE.
* So we assert agreement at the spec §D9 committed tolerance (1e-12 relative),
* the same value Property 3 uses — keeps both properties on one rigor.
Parameter noOpRelErr(tickSpacingDomain, tick);
noOpRelErr(tickSpacingDomain, tick) =
    noOpDelta(tickSpacingDomain, tick) / priceKernel(tickSpacingDomain, tick);
Scalar maxNoOpRel;
maxNoOpRel = smax((tickSpacingDomain, tick), noOpRelErr(tickSpacingDomain, tick));
abort$(maxNoOpRel > 1e-12)
    "FAIL: priceImpactKernel_Add0(P,L,0) deviates from P beyond 1e-12 relative", maxNoOpRel;
display "PASS: zero-input no-op (max rel err)", maxNoOpRel;
