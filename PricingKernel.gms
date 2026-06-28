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


* priceImpactKernel_Add0(sqrtP, L, dx): post-trade sqrt price (Q64.96) for the
* η = 1/2 kernel, selling token0 for token1 (Uniswap V3 add=true direction).
* Mirrors v3::math::sqrt_price_math::getNextSqrtPriceFromAmount0RoundingUp(P, L, dx, true)
* exposed by PriceImpactKernelHarness.plk.
*
* Scale convention:
*   sqrtP enters in Q64.96 (the on-chain scale produced by `priceKernel`);
*   L and dx enter raw (matching `liquidity` uint128 and `amount` uint256);
*   the macro returns Q64.96 (directly comparable to the EVM output).
* The EVM's `numerator1 = L << 96` introduces an asymmetric scaling: in the
* denominator, L is raw but dx*sqrtP is Q96, so the dx*sqrtP product must be
* divided by 2^96 before being added to L. The "scales cancel" intuition is
* WRONG; the asymmetry is load-bearing. Empirically verified against an
* independent EVM mulDiv replica (rel err = 1.22e-16 at machine precision).
*
* Rounding: Uniswap rounds the division UP (mulDivRoundingUp); GAMS uses IEEE
* doubles. The differential diff uses assertApproxEqRel at 1e-12 (spec §D8/§D9).
*
* Naming: the `_Add0` suffix marks the token0-input direction; future siblings
* `_Add1` (token1-input) and a potential `_Sub0/_Sub1` (add=false branch) will
* share the `priceImpactKernel_` prefix.
*
* TODO(eta-CES): a tunable-η post-trade form is reachable via the lean4-spec
* kernel-split identity (CFMM.Eta.eta_split_kernel_identity, see
* lean4-spec/lean/exp/eta.lean), but blocked on an η-CES post-trade EVM
* function existing to diff against.
$macro priceImpactKernel_Add0(sqrtP, L, dx) ( (L) * (sqrtP) / ( (L) + (dx) * (sqrtP) / power(2, 96) ) )
