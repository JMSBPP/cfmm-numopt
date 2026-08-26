#####################################################################
# GAMS algebraic model (off-chain solver track)                     #
#####################################################################
# GAMS resolves relative `$$include` against the *working directory* of
# the invocation, so every compile runs from $(GAMS_DIR). `action=c`
# does a compile/syntax check only. `action=ce` executes, which the
# payoff units need — they carry real NLP Model/Solve statements and
# therefore require CONOPT. Authoritative reference: model/BUILD.md.
GAMS       ?= gams
GAMS_DIR   := model
GAMS_BUILD := build
# Files to skip (none — every .gms is compile-checked). Add space-separated
# paths relative to $(GAMS_DIR) here if a file should be excluded.
GAMS_SKIP  :=

.PHONY: compile-gams test-gams test-units test-volumepath clean-gams payoff-fixtures spec-preflight spec-preflight-band

# compile-gams: compile-check every .gms file under model/ with action=c.
# Fails (non-zero) if any file does not compile, so broken models redden
# the build instead of hiding.
compile-gams:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; ok=0; fail=0; skip=0; \
	for f in $$(find . -name '*.gms' -not -path './test/*' -not -path '*/build/*' | sed 's|^\./||' | sort); do \
		case " $(GAMS_SKIP) " in \
			*" $$f "*) printf '   SKIP %s  (fragment/stub — BUILD.md)\n' "$$f"; skip=$$((skip+1)); continue;; \
		esac; \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> compiling %s\n' "$$f"; \
		if $(GAMS) "$$f" action=c o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
			printf '   OK   %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			printf '   FAIL %s  (gams rc=%s) -> %s/%s\n' "$$f" "$$?" "$(GAMS_DIR)" "$$out"; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	printf '\ncompile-gams: %s ok, %s failed, %s skipped\n' "$$ok" "$$fail" "$$skip"; \
	exit $$rc

# test-gams: run GAMS assertion tests under model/test/ with action=ce (execute,
# so `abort$$(...)` checks actually fire). A failing assertion returns a non-zero
# GAMS exit code, which fails the build.
#
# Each test/ driver is an INDEPENDENT execution unit including exactly one
# payoff/ theorem file — see model/PayoffModule.gms for why theorem files are
# never aggregated into one compilation unit.
test-units:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; ok=0; fail=0; \
	for f in $$(find test -name '*.gms' 2>/dev/null | sed 's|^\./||' | sort); do \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> testing %s\n' "$$f"; \
		if $(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
			printf '   PASS %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			printf '   FAIL %s  (gams rc=%s) -> %s/%s\n' "$$f" "$$?" "$(GAMS_DIR)" "$$out"; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	printf '\ntest-units: %s passed, %s failed\n' "$$ok" "$$fail"; \
	exit $$rc

# test-gams: the whole suite — the per-theorem/kernel units AND the VolumePath
# prover. Both are exit-code gated (GAMS 54.1: rc=2 compile error, rc=3
# execution abort). Never scrape listings for status: `lo=0` destroys it.
test-gams: test-units test-volumepath

# test-volumepath: the prover aborts non-zero if ANY in-model gate fails
# (solver status, both rate targets, volume, closure, swap-sign, node count,
# JSON line width), so a green run certifies the emitted JSON. `jq` (if
# present) additionally proves the file parses. The double run pins
# determinism: same inputs -> same bytes. Contract: docs/volume-path.md.
VP_DIR   := $(GAMS_DIR)/mev_tax_model_one
test-volumepath:
	@set -e; cd $(VP_DIR); mkdir -p $(GAMS_BUILD); \
	printf '>> run 1: volume_path.gms (self-test fixture)\n'; \
	$(GAMS) volume_path.gms action=ce o=$(GAMS_BUILD)/run1.lst scrdir=$(GAMS_BUILD) lo=0 >/dev/null 2>&1 \
		|| { printf 'test-volumepath FAIL: see %s/$(GAMS_BUILD)/run1.lst\n' "$(VP_DIR)"; \
		     sed -n 's/^\*\*\*\* *//p' $(GAMS_BUILD)/run1.lst | head -8; exit 1; }; \
	if command -v jq >/dev/null 2>&1; then \
		jq -e . volume_path.json >/dev/null || { printf 'test-volumepath FAIL: emitted JSON does not parse\n'; exit 1; }; \
	else printf '   (jq not found — JSON parse check skipped; in-model width guard still applies)\n'; fi; \
	cp volume_path.json $(GAMS_BUILD)/run1.json; \
	printf '>> run 2: determinism\n'; \
	$(GAMS) volume_path.gms action=ce o=$(GAMS_BUILD)/run2.lst scrdir=$(GAMS_BUILD) lo=0 >/dev/null 2>&1; \
	cmp -s volume_path.json $(GAMS_BUILD)/run1.json \
		|| { printf 'test-volumepath FAIL: two identical runs emitted different JSON\n'; exit 1; }; \
	printf '\ntest-volumepath: prover gates PASS, JSON valid, byte-identical across 2 runs\n'

# clean-gams: remove GAMS listings, save/scratch, and build artifacts.
clean-gams:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD) $(GAMS_DIR)/225* \
		$(GAMS_DIR)/*.lst $(GAMS_DIR)/*.g00 $(GAMS_DIR)/*.lxi \
		$(VP_DIR)/$(GAMS_BUILD) $(VP_DIR)/volume_path.json $(VP_DIR)/volume_path.txt $(VP_DIR)/225*

# payoff-fixtures: regenerate committed per-theorem payoff GDX(s).
# Detects compile/execution errors by post-grepping the .lst — `gams` exits 0
# even on compile errors, so the recipe MUST grep, not rely on exit code alone.
payoff-fixtures:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; \
	for f in $$(find payoff -name 'eta_*.gms' 2>/dev/null | sort); do \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> regenerating fixture from %s\n' "$$f"; \
		$(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1 ; \
		if grep -qE 'Status: (Compilation|Execution) error' "$$out"; then \
			printf '   FAIL %s -> %s/%s (status line indicates error)\n' "$$f" "$(GAMS_DIR)" "$$out"; rc=1; \
		else \
			printf '   OK %s\n' "$$f"; \
		fi; \
	done; \
	exit $$rc

# spec-preflight: extract code blocks from the rev-4 spec MD into a mirror of
# the production layout and drive it the way production does. Catches
# divergences in include paths, file boundaries, and driver wiring that a
# flat-concat preflight would miss. Before any spec commit, this must pass.
spec-preflight:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD)/spec
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec/payoff $(GAMS_DIR)/$(GAMS_BUILD)/spec/test
	@SPEC=docs/specs/2026-06-28-payoff-zero-slippage-design.md; \
	ROOT=$(GAMS_DIR)/$(GAMS_BUILD)/spec; \
	python3 -c "import re; text = open('$$SPEC').read(); secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M); body = {n: next((secs[i+1] for i in range(1,len(secs),2) if secs[i].startswith('## %s.' % n)), None) for n in (5,6,7,8)}; missing = [n for n,b in body.items() if b is None]; assert not missing, 'spec sections missing: %s' % missing; blocks = {n: re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', b, re.S) for n,b in body.items()}; missing = [n for n,m in blocks.items() if m is None]; assert not missing, 'no gams code block in sections: %s' % missing; open('$$ROOT/payoff/_PayoffScaffolding.gms','w').write(blocks[5].group(1)); open('$$ROOT/payoff/eta_pi_trader_zero_slippage.gms','w').write(blocks[6].group(1)); open('$$ROOT/PayoffModule.gms','w').write(blocks[7].group(1)); open('$$ROOT/test/PayoffModuleTest.gms','w').write(blocks[8].group(1))"; \
	cp $(GAMS_DIR)/PricingKernel.gms $(GAMS_DIR)/primitives.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec/; \
	cd $(GAMS_DIR)/$(GAMS_BUILD)/spec && \
	$(GAMS) test/PayoffModuleTest.gms action=ce o=run.lst scrdir=. lo=0 >/dev/null 2>&1 ; \
	if grep -qE 'Status: (Compilation|Execution) error' run.lst; then \
		printf 'spec-preflight FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec/run.lst\n'; \
		grep -A1 '^\*\*\*\*' run.lst | head -10; exit 1; \
	else \
		printf 'spec-preflight OK (production layout)\n'; \
	fi

# spec-preflight-band: Cycle 2 spec-as-truth gate. Re-runs the sorry/admit grep
# on the 3 cited theorems in eta.lean BEFORE extracting GAMS code, then mirrors
# the spec MD into the production layout and drives the band unit.
#
# LEAN4_SPEC_DIR defaults to the lean4-spec submodule at the repo root, which
# points at JMSBPP/cfmm-vol-markets-spec — the formalization layer (formerly
# cfmm-lean4-spec, imported there via git-filter-repo, so old SHAs do not
# resolve). Lean sources live under its lean/ directory.
LEAN4_SPEC_DIR ?= lean4-spec
spec-preflight-band:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD)/spec-band
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/payoff $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/test
	@LEAN=$(LEAN4_SPEC_DIR)/lean/exp/eta.lean; \
	if [ ! -f "$$LEAN" ]; then \
		printf 'spec-preflight-band FAIL: %s not found.\n' "$$LEAN"; \
		printf '  The lean4-spec submodule is not initialized. Run:\n'; \
		printf '    git submodule update --init lean4-spec\n'; \
		printf '  or point LEAN4_SPEC_DIR at a checkout of JMSBPP/cfmm-vol-markets-spec.\n'; \
		exit 1; \
	fi; \
	for ID in pi_trader_half_strictly_increasing_in_ pi_trader_half_band_min_at_left pi_trader_half_band_max_large_trade; do \
		START=$$(grep -nE "^theorem $$ID" "$$LEAN" | head -1 | cut -d: -f1); \
		if [ -z "$$START" ]; then printf 'spec-preflight-band FAIL: theorem %s not found in %s\n' "$$ID" "$$LEAN"; exit 1; fi; \
		END=$$(awk -v s="$$START" 'NR>s && /^(theorem |lemma |def |noncomputable def |namespace |end )/ {print NR; exit}' "$$LEAN"); \
		if [ -z "$$END" ]; then END=$$(wc -l < "$$LEAN"); fi; \
		if sed -n "$${START},$${END}p" "$$LEAN" | grep -vE '^\s*(--|/-)' | grep -qE '\bsorry\b|\badmit\b'; then \
			printf 'spec-preflight-band FAIL: theorem %s body contains sorry/admit\n' "$$ID"; exit 1; \
		fi; \
	done; \
	printf 'spec-preflight-band: Lean substrate OK (3 theorems sorry/admit-free)\n'
	@SPEC=docs/specs/2026-06-28-payoff-band-monotone-large-design.md; \
	ROOT=$(GAMS_DIR)/$(GAMS_BUILD)/spec-band; \
	python3 -c "import re; text = open('$$SPEC').read(); secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M); body6 = next((secs[i+1] for i in range(1,len(secs),2) if secs[i].startswith('## 6.')), None); assert body6 is not None, 'spec section missing: ## 6.'; m6 = re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', body6, re.S); assert m6 is not None, 'no gams code block in section: ## 6.'; open('$$ROOT/payoff/eta_pi_trader_band_monotone_large.gms','w').write(m6.group(1))"; \
	cp $(GAMS_DIR)/PricingKernel.gms $(GAMS_DIR)/primitives.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/; \
	cp $(GAMS_DIR)/payoff/_PayoffScaffolding.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/payoff/; \
	cp $(GAMS_DIR)/test/PayoffBandMonotoneLargeTest.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/test/; \
	cd $(GAMS_DIR)/$(GAMS_BUILD)/spec-band && \
	$(GAMS) test/PayoffBandMonotoneLargeTest.gms action=ce o=run.lst scrdir=. lo=0 >/dev/null 2>&1 ; \
	if grep -qE 'Status: (Compilation|Execution) error' run.lst; then \
		printf 'spec-preflight-band FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/run.lst\n'; \
		grep -A1 '^\*\*\*\*' run.lst | head -10; exit 1; \
	else \
		printf 'spec-preflight-band OK (Lean sorry-grep + GAMS extract+compile+execute)\n'; \
	fi
