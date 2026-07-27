$title Payoff theorem unit — pi_trader_half band monotonicity (large trade)
* action=ce (from `make test-gams`) drives the per-program asserts.
* Invokes a real NLP Solve (CONOPT). make test-gams requires CONOPT.
*
* Independent execution unit: this driver includes exactly ONE theorem file, so
* its fixture (L̄=0.1, Δ^I=1.0) cannot collide with any other theorem's fixture.
* See PayoffModule.gms for why per-theorem files are not aggregated.
$include payoff/eta_pi_trader_band_monotone_large.gms
display "PASS: eta_pi_trader_band_monotone_large asserts cleared.";
