$title TEST-09 seed negative control -- unconditional abort
* Deliberately broken. Run ONLY by `make negative-controls`. Never by test-gams
* (Makefile excludes test/_mutants/) and never by compile-gams (excludes test/).
* Measured: gams returns rc=3 on abort. This row proves the runner sees a red.
Scalar one / 1 /;
abort$(one = 1) "TEST-09 seed control: this abort is unconditional by design", one;
