# ── TEST-09: the negative-control registry runner ─────────────────────────
# PASS/FAIL PREDICATE IS THE EXIT CODE ONLY. Output-scraping (pattern matching
# a listing file) must never appear in a conditional position here — that is
# the idiom this phase exists to remove.
REGISTRY   ?= model/test/_mutants/registry.tsv
NC_TIMEOUT ?= 900

.PHONY: negative-controls

negative-controls:
	set -e; NC_TIMEOUT=$(NC_TIMEOUT) python3 model/test/negative_controls.py $(REGISTRY)
