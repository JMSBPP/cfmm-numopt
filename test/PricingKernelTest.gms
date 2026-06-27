$title PricingKernel test: tunablePricingKernel(eta=1/2) == priceKernel (fixed 1/2)

* Run from model/ (so `$include PricingKernel.gms` resolves against the working dir).
* Executes assertions, so use action=ce. No Model/Solve -> no solver/license needed.

$include PricingKernel.gms

* eta from TradingRegion: poolLiquidityCone weights inventory with eta_x_y/unity.
* The balanced 50/50 pool has eta_x_y = unity/2, i.e. dimensionless weight eta = 1/2 —
* exactly the sqrt the fixed priceKernel hard-codes as `/2`.
Scalar eta_x_y; eta_x_y = unity / 2;
Scalar eta;     eta     = eta_x_y / unity;
* eta now equals 0.5 (= (unity/2)/unity), the balanced-pool weight.

* Tabulate the tunable kernel at eta = 1/2 over the full (tickSpacing, tick) grid.
Parameter tunable(tickSpacingDomain, tick);
tunable(tickSpacingDomain, tick) = tunablePricingKernel(tickSpacingDomain, tick, eta);

* Relative error vs the fixed-1/2 priceKernel (priceKernel > 0 everywhere).
Parameter relErr(tickSpacingDomain, tick);
relErr(tickSpacingDomain, tick) =
    abs(tunable(tickSpacingDomain, tick) - priceKernel(tickSpacingDomain, tick))
    / priceKernel(tickSpacingDomain, tick);

Scalar maxRelErr; maxRelErr = smax((tickSpacingDomain, tick), relErr(tickSpacingDomain, tick));
display "max relative error, tunable(eta=1/2) vs priceKernel:", maxRelErr;
abort$(maxRelErr > 1e-12)
    "FAIL: tunablePricingKernel(eta=1/2) does not equal priceKernel", maxRelErr;

* Guard: the kernel is genuinely tunable — a different eta must move the price somewhere.
Parameter diffEta(tickSpacingDomain, tick);
diffEta(tickSpacingDomain, tick) =
    abs(tunablePricingKernel(tickSpacingDomain, tick, 0.3) - priceKernel(tickSpacingDomain, tick));
Scalar maxDiffEta; maxDiffEta = smax((tickSpacingDomain, tick), diffEta(tickSpacingDomain, tick));
abort$(maxDiffEta <= 0)
    "FAIL: tunablePricingKernel(eta=0.3) should differ from the fixed kernel", maxDiffEta;

display "PASS: tunablePricingKernel(eta=1/2) == priceKernel; tunable for eta <> 1/2", maxRelErr, maxDiffEta;
