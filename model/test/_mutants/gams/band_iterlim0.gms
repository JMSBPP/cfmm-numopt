$title TEST-09 mutant -- iterlim=0 forces abnormal solver termination (GATE-03)
* Driven ONLY by `make negative-controls`. Invisible to compile-gams (excludes
* ./test/*) and to test-gams (excludes test/_mutants/*). Run from model/ so the
* $include below resolves the same way the real driver does.
*
* UNVERIFIABLE-LEG: this proves the solveStat/modelStat assertion PAIR fires. It
* does NOT isolate solveStat -- both codes degrade together here. LINT-06 is what
* guarantees coverage.
option iterlim = 0;
$include payoff/eta_pi_trader_band_monotone_large.gms
display "MUTANT DID NOT REDDEN -- the GATE-03 assertions failed to fire.";
