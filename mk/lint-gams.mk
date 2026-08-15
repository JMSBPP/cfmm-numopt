# ── GATE-02 / GATE-04: the GAMS source lint is a DATA FILE, not a fork point ──
# Later phases extend coverage by APPENDING A LINE to model/lint/rules.tsv
# (M7 append-only). They never edit lint_gams.py.
#
# LINT_RULES  the rule table to apply (default: the committed one)
# LINT_PATHS  explicit sources to scan; empty means "every .gms under model/
#             except model/build/ and model/test/_mutants/". The TEST-09
#             mutants are driven through this variable.
LINT_RULES ?= model/lint/rules.tsv
LINT_PATHS ?=

.PHONY: lint-gams

lint-gams:
	set -e; python3 model/lint/lint_gams.py --rules $(LINT_RULES) $(LINT_PATHS)
