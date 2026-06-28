$title PayoffModule rolled-up assertion test
* action=ce (from `make test-gams`) drives per-program asserts.
* Invokes a real NLP Solve (CONOPT). make test-gams now requires CONOPT.
$include PayoffModule.gms
display "PASS: all PayoffModule per-program asserts cleared.";
