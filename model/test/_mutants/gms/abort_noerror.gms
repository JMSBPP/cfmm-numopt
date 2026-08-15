* TEST-09 mutant for LINT-01. abort.noError halts silently at rc=0.
* Linted only, never executed. Driven by:
*   make lint-gams LINT_PATHS=model/test/_mutants/gms/abort_noerror.gms
Scalar x / 1 / ;
abort.noError$(x = 1) "this halts with no status line", x;
