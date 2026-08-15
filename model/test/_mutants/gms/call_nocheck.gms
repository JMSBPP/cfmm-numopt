* TEST-09 mutant for LINT-03. A failing $call returns rc=0. Note
* $onCheckErrorLevel governs $call ONLY -- it does not cover `execute`,
* which is why LINT-02 and LINT-03 are separate rules.
$call false
