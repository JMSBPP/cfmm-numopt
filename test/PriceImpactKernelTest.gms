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


* --- Property 2 (spec §7-2): monotone in dx ----------------------------------
* For every (s, t): priceImpact at small > medium > large. Economically: selling
* more token0 strictly depresses the post-trade sqrtPX96. Counts every (s,t)
* where the strict ordering is violated; abort if any violation exists.
Set       dxD       / small, medium, large /;
Parameter dxVal(dxD);
* dxVal scale: small = 1e15, medium = 1e17, large = 1e18
dxVal('small')  = Lbar / 1000;
dxVal('medium') = Lbar /   10;
dxVal('large')  = Lbar;

Parameter pi(tickSpacingDomain, tick, dxD);
pi(tickSpacingDomain, tick, dxD) =
    priceImpactKernel_Add0(priceKernel(tickSpacingDomain, tick), Lbar, dxVal(dxD));

Parameter monoBreaks(tickSpacingDomain, tick);
monoBreaks(tickSpacingDomain, tick) =
    1$( pi(tickSpacingDomain, tick, 'small')  <= pi(tickSpacingDomain, tick, 'medium') )
  + 1$( pi(tickSpacingDomain, tick, 'medium') <= pi(tickSpacingDomain, tick, 'large')  );
Scalar totalBreaks; totalBreaks = sum((tickSpacingDomain, tick), monoBreaks(tickSpacingDomain, tick));
abort$(totalBreaks > 0)
    "FAIL: dx-monotone (small > medium > large) violated somewhere on the grid",
    totalBreaks;
display "PASS: dx-monotone over full grid (violation count)", totalBreaks;


* --- Property 3 (spec §7-3): EVM-formula cross-validation --------------------
* Reproduce the EVM's mulDiv-form algebra independently (different parenthesisation)
* at one spot (tick=k121, dx=medium) and assert agreement with the macro at the
* committed 1e-12 tolerance (spec §D9). Independence is structural — a typo in
* the macro's surface form cannot also appear in this alternative expression.
Scalar Q96; Q96 = power(2, 96);
Scalar evmRef;
evmRef = (Lbar * Q96) * priceKernel('s1','k121')
       / ((Lbar * Q96) + dxVal('medium') * priceKernel('s1','k121'));
Scalar macroVal; macroVal = pi('s1','k121','medium');
Scalar evmRelErr; evmRelErr = abs(macroVal - evmRef) / evmRef;
abort$(evmRelErr > 1e-12)
    "FAIL: priceImpactKernel_Add0 disagrees with independent EVM-formula reproduction",
    macroVal, evmRef, evmRelErr;
display "PASS: EVM-formula cross-validation at (k121, medium) — relErr:", evmRelErr;
