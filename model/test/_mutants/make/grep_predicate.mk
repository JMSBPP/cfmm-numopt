# TEST-09 mutant: a grep standing in a pass/fail position. Linted only via
# `python3 model/lint/lint_make.py --file <this file>`; never included by the
# root Makefile (it lives under model/, not mk/).
.PHONY: mutant-grep-predicate
mutant-grep-predicate:
	set -e; \
	if grep -qE 'Status: (Compilation|Execution) error' run.lst; then \
		exit 1; \
	fi
