$title TEST-09 mutant -- deliberate compile error, reddens payoff-fixtures
* Driven ONLY by: make payoff-fixtures PAYOFF_SRC_DIR=test/_mutants/payoff
* Invisible to compile-gams (excludes ./test/*) and to test-gams (excludes
* test/_mutants/*). Measured: gams returns rc=2 on a compile error.
*
* NOTE ON THE SEMICOLON: it is load-bearing. Without it GAMS continues the
* `Scalar` declaration across the following line and parses the garbage as
* further scalar identifiers -- measured rc=0, i.e. the mutant would not have
* been a mutant at all. The statement must be TERMINATED so the invalid line
* is a fresh statement. Measured with the semicolon: rc=2.
Scalar broken / 1 / ;
this line is not GAMS syntax )))
