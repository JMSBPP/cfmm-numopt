* TEST-09 mutant for LINT-02. A failing `execute` returns rc=0.
* Linted only, never executed. $onCheckErrorLevel does NOT cover this form --
* measured: $onCheckErrorLevel + execute 'false' gives rc=0 and continues.
execute 'false';
