$if set PAYOFF_SCAFFOLDING_INCLUDED $exit
$setGlobal PAYOFF_SCAFFOLDING_INCLUDED 1


* PricingKernel: brings lambda (WAD), unity, priceImpactKernel_Add0 (raw L), tunablePricingKernel.
$include PricingKernel.gms

* Binary fixed-point scale constants (Uniswap V3 TickMath lineage).
* Q64.96 for sqrt prices
Scalar Q96  ;  Q96  = power(2,  96);
* Q128.128 for L̄/Δ^I ; Q0.128 for η
Scalar Q128 ;  Q128 = power(2, 128);

* Operational bounds on Δᵢ (positive integer).
Scalar diMinInt / 1   /;
Scalar diMaxInt / 200 /;

* COORDINATE TRANSLATION (LOAD-BEARING):
* Lean:    P_Lean(λ, i, Δᵢ) := λ^(i·Δᵢ)          (eta.lean:38, a PRICE — no /2)
* Plank:   sqrtPX96(λ, i, Δᵢ) := λ^(i·Δᵢ/2)·Q96  (CESLongPayoff.plk, SQRT-PRICE)
* Same-Δᵢ bridge: sqrtPX96 = sqrt(P_Lean) · Q96
* Payoff-zero bridge: Δᵢ⋆_Plank = 2 · Δᵢ⋆_Lean   (derived via priceImpactKernel_Add0 — §3 D4i)

* Lean-coordinate evaluators:
$macro P_Lean_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)) )
$macro P_Lean_post(P, LQ128, DIQ128) ( (LQ128)*(P) / ((LQ128) + (DIQ128)*(P)) )
$macro piTrader_Half_Lean(P, LQ128, DIQ128) ( sqr( (P)*(DIQ128)/Q128 - (LQ128)*((P) - P_Lean_post((P),(LQ128),(DIQ128)))/Q128 ) )

* Plank-coordinate evaluators:
$macro sqrtPX96_at(lamWad, iTick, Di) ( ((lamWad)/unity) ** ((iTick)*(Di)/2) * Q96 )
$macro priceImpactQ128_Add0(sqrtP, LQ128, dxQ128) ( priceImpactKernel_Add0((sqrtP), (LQ128)/Q128, (dxQ128)/Q128) )
$macro traderTerm_Half_Plank(sqrtP, DIQ128)            ( (sqrtP)*(DIQ128)/Q128/Q96 )
$macro traderDeltaO_Half_Plank(sqrtP, sqrtQ, LQ128)    ( (LQ128)*((sqrtP) - (sqrtQ))/Q128/Q96 )
$macro piTrader_Half_Plank(sqrtP, LQ128, DIQ128) ( sqr( traderTerm_Half_Plank((sqrtP),(DIQ128)) - traderDeltaO_Half_Plank((sqrtP), priceImpactQ128_Add0((sqrtP),(LQ128),(DIQ128)), (LQ128)) ) )

* Shared provenance + tolerance scalars:
* η = 1/2 in Q0.128 (also = Q128/2)
Scalar etaQ128 ;     etaQ128 = power(2, 127);
Scalar gamsVersion / 54.1 /;
* cycle 1, spec rev 4
Scalar modelVersion / 4 /;
* 1.0001·1e18 WAD
Scalar lambdaWad ;   lambdaWad = lambda;
* RELATIVE tol for non-zero refs
Scalar diffTolerance / 1e-12 /;
* ABSOLUTE tol for zero refs
Scalar zeroTolerance / 1e-20 /;
* 1=smallest argmin under ties
Scalar tieBreaking   / 1 /;
