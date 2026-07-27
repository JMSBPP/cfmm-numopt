$title Payoff theorem unit — pi_trader_half_zero_at_deltaI_star
* action=ce (from `make test-gams`) drives the per-program asserts.
* Invokes a real NLP Solve (CONOPT). make test-gams requires CONOPT.
*
* Independent execution unit: this driver includes exactly ONE theorem file, so
* its fixture (L̄=1, Δ^I=0.1) cannot collide with any other theorem's fixture.
* See PayoffModule.gms for why per-theorem files are not aggregated.
$include payoff/eta_pi_trader_zero_slippage.gms
display "PASS: eta_pi_trader_zero_slippage asserts cleared.";
