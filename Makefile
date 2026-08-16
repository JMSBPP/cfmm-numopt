#####################################################################
# cfmm-gams — the VolumePath prover                                 #
#####################################################################
# Three targets, all gating on GAMS exit codes (measured on GAMS 54.1:
# rc=2 compile error, rc=3 execution abort — never scrape listings, the
# status line lives on the LOG stream and `lo=0` destroys it).
#
#   compile-gams   action=c  syntax check of every tracked .gms
#   test-gams      action=ce self-test run of the VolumePath prover:
#                  all in-model gates must pass, the JSON must parse,
#                  and TWO runs must emit byte-identical JSON
#   clean-gams     remove listings and scratch
#
# Authoritative usage reference: docs/volume-path.md
GAMS     ?= gams
VP_DIR   := model/mev_tax_model_one
VP_BUILD := build

.DEFAULT_GOAL := compile-gams
.PHONY: compile-gams test-gams clean-gams

compile-gams:
	@set -e; rc=0; ok=0; fail=0; \
	for f in $$(git ls-files '*.gms' | sort); do \
		d=$$(dirname "$$f"); b=$$(basename "$$f"); \
		mkdir -p "$$d/$(VP_BUILD)"; \
		printf '>> compiling %s\n' "$$f"; \
		if (cd "$$d" && $(GAMS) "$$b" action=c o="$(VP_BUILD)/$${b%.gms}.lst" scrdir="$(VP_BUILD)" lo=0 >/dev/null 2>&1); then \
			printf '   OK   %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			printf '   FAIL %s -> %s/$(VP_BUILD)/%s.lst\n' "$$f" "$$d" "$${b%.gms}"; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	if [ $$((ok+fail)) -eq 0 ]; then printf 'compile-gams FAIL: no .gms tracked\n'; exit 1; fi; \
	printf '\ncompile-gams: %s ok, %s failed\n' "$$ok" "$$fail"; exit $$rc

# The prover aborts non-zero if ANY of its gates fails (solver status, both
# rate targets, volume, closure, swap-sign), so a green run certifies the
# emitted JSON. The double run pins determinism: same inputs -> same bytes.
test-gams:
	@set -e; cd $(VP_DIR); mkdir -p $(VP_BUILD); \
	printf '>> run 1: volume_path.gms (self-test fixture)\n'; \
	$(GAMS) volume_path.gms action=ce o=$(VP_BUILD)/run1.lst scrdir=$(VP_BUILD) lo=0 >/dev/null 2>&1 \
		|| { printf 'test-gams FAIL: see %s/$(VP_BUILD)/run1.lst\n' "$(VP_DIR)"; \
		     sed -n 's/^\*\*\*\* *//p' $(VP_BUILD)/run1.lst | head -8; exit 1; }; \
	python3 -c "import json; d=json.load(open('volume_path.json')); \
assert len(d['dQx'])==d['nEvents'], 'dQx length != nEvents'; \
assert all(x*m<0 for x,m in zip(d['dQx'],d['dQM'])), 'a step is not a swap'" \
		|| { printf 'test-gams FAIL: emitted JSON invalid\n'; exit 1; }; \
	cp volume_path.json $(VP_BUILD)/run1.json; \
	printf '>> run 2: determinism\n'; \
	$(GAMS) volume_path.gms action=ce o=$(VP_BUILD)/run2.lst scrdir=$(VP_BUILD) lo=0 >/dev/null 2>&1; \
	cmp -s volume_path.json $(VP_BUILD)/run1.json \
		|| { printf 'test-gams FAIL: two identical runs emitted different JSON\n'; exit 1; }; \
	printf '\ntest-gams: prover gates PASS, JSON valid, byte-identical across 2 runs\n'

clean-gams:
	@rm -rf $(VP_DIR)/$(VP_BUILD) $(VP_DIR)/volume_path.json $(VP_DIR)/volume_path.txt \
		$(VP_DIR)/*.lst model/build model/225* 225*
