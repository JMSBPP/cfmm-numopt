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

# Parameterised so TEST-09 mutants can drive the SAME recipe over a broken
# input. Never edit these to point at a mutant; pass them on the command line.
PAYOFF_SRC_DIR ?= payoff
PAYOFF_GLOB    ?= eta_*.gms
SPEC_ZS        ?= docs/specs/2026-06-28-payoff-zero-slippage-design.md
SPEC_BAND      ?= docs/specs/2026-06-28-payoff-band-monotone-large-design.md

# ── M7 concurrency substrate ──────────────────────────────────────────────
# The ONE permanent extension point. Every later plan and phase ships its own
# mk/<name>.mk and NEVER edits this file again. `-include` is silent when the
# directory is empty.
-include mk/*.mk

# The include above precedes every rule in this file, so without this pin the
# first target of the first included mk/*.mk would silently become the default
# goal of a bare `make`. Pin it to the historical default.
.DEFAULT_GOAL := compile-gams

.PHONY: compile-gams test-gams clean-gams payoff-fixtures spec-preflight spec-preflight-band

# compile-gams: compile-check every .gms file under model/ with action=c.
# Fails (non-zero) if any file does not compile, so broken models redden
# the build instead of hiding.
compile-gams:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@set -e; cd $(GAMS_DIR); rc=0; ok=0; fail=0; skip=0; \
	for f in $$(find . -name '*.gms' -not -path './test/*' -not -path './build/*' | sed 's|^\./||' | sort); do \
		case " $(GAMS_SKIP) " in \
			*" $$f "*) printf '   SKIP %s  (fragment/stub — BUILD.md)\n' "$$f"; skip=$$((skip+1)); continue;; \
		esac; \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> compiling %s\n' "$$f"; \
		if $(GAMS) "$$f" action=c o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
			printf '   OK   %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			rcg=$$?; \
			printf '   FAIL %s  (gams rc=%s) -> %s/%s\n' "$$f" "$$rcg" "$(GAMS_DIR)" "$$out"; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	if [ $$((ok+fail+skip)) -eq 0 ]; then \
		printf 'compile-gams FAIL: no .gms matched\n'; \
		exit 1; \
	fi; \
	printf '\ncompile-gams: %s ok, %s failed, %s skipped\n' "$$ok" "$$fail" "$$skip"; \
	exit $$rc

# test-gams: run GAMS assertion tests under model/test/ with action=ce (execute,
# so `abort$$(...)` checks actually fire). A failing assertion returns a non-zero
# GAMS exit code, which fails the build.
#
# Each test/ driver is an INDEPENDENT execution unit including exactly one
# payoff/ theorem file — see model/PayoffModule.gms for why theorem files are
# never aggregated into one compilation unit.
#
# NOTE: test/_mutants/ holds deliberately-broken units (TEST-09). They are run only by
# `make negative-controls`, never by test-gams — otherwise the suite would red by design.
test-gams:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@set -e; cd $(GAMS_DIR); rc=0; ok=0; fail=0; \
	for f in $$(find test -name '*.gms' -not -path 'test/_mutants/*' 2>/dev/null | sed 's|^\./||' | sort); do \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> testing %s\n' "$$f"; \
		if $(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
			printf '   PASS %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			rcg=$$?; \
			printf '   FAIL %s  (gams rc=%s) -> %s/%s\n' "$$f" "$$rcg" "$(GAMS_DIR)" "$$out"; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	if [ $$((ok+fail)) -eq 0 ]; then \
		printf 'test-gams FAIL: no test unit matched test/*.gms\n'; \
		exit 1; \
	fi; \
	printf '\ntest-gams: %s passed, %s failed\n' "$$ok" "$$fail"; \
	exit $$rc

# clean-gams: remove GAMS listings, save/scratch, and build artifacts.
clean-gams:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD) $(GAMS_DIR)/225* \
		$(GAMS_DIR)/*.lst $(GAMS_DIR)/*.g00 $(GAMS_DIR)/*.lxi

# payoff-fixtures: regenerate committed per-theorem payoff GDX(s).
# Gates on the gams EXIT CODE, the same way compile-gams and test-gams do.
# Measured on GAMS 54.1: rc=2 on compile error, rc=3 on abort. The previous
# recipe scraped the o= listing for the compilation/execution status line,
# a string written only to the LOG stream, which `lo=0 >/dev/null` destroys —
# so it matched nothing and every run printed OK. GATE-01.
payoff-fixtures:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@set -e; cd $(GAMS_DIR); rc=0; ok=0; fail=0; \
	for f in $$(find $(PAYOFF_SRC_DIR) -name '$(PAYOFF_GLOB)' 2>/dev/null | sort); do \
		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
		printf '>> regenerating fixture from %s\n' "$$f"; \
		if $(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1; then \
			printf '   OK   %s\n' "$$f"; ok=$$((ok+1)); \
		else \
			printf '   FAIL %s  -> %s/%s\n' "$$f" "$(GAMS_DIR)" "$$out"; \
			sed -n 's/^\*\*\*\* *//p' "$$out" | head -5; \
			fail=$$((fail+1)); rc=1; \
		fi; \
	done; \
	if [ $$((ok+fail)) -eq 0 ]; then \
		printf 'payoff-fixtures FAIL: no units matched %s/%s\n' "$(PAYOFF_SRC_DIR)" "$(PAYOFF_GLOB)"; \
		exit 1; \
	fi; \
	printf '\npayoff-fixtures: %s ok, %s failed\n' "$$ok" "$$fail"; \
	exit $$rc

# spec-preflight: extract code blocks from the rev-4 spec MD into a mirror of
# the production layout and drive it the way production does. Catches
# divergences in include paths, file boundaries, and driver wiring that a
# flat-concat preflight would miss. Before any spec commit, this must pass.
spec-preflight:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD)/spec
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec/payoff $(GAMS_DIR)/$(GAMS_BUILD)/spec/test
	@set -e; SPEC=$(SPEC_ZS); \
	ROOT=$(GAMS_DIR)/$(GAMS_BUILD)/spec; \
	python3 -c "import re; text = open('$$SPEC').read(); secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M); body = {n: next((secs[i+1] for i in range(1,len(secs),2) if secs[i].startswith('## %s.' % n)), None) for n in (5,6,7,8)}; missing = [n for n,b in body.items() if b is None]; assert not missing, 'spec sections missing: %s' % missing; blocks = {n: re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', b, re.S) for n,b in body.items()}; missing = [n for n,m in blocks.items() if m is None]; assert not missing, 'no gams code block in sections: %s' % missing; open('$$ROOT/payoff/_PayoffScaffolding.gms','w').write(blocks[5].group(1)); open('$$ROOT/payoff/eta_pi_trader_zero_slippage.gms','w').write(blocks[6].group(1)); open('$$ROOT/PayoffModule.gms','w').write(blocks[7].group(1)); open('$$ROOT/test/PayoffModuleTest.gms','w').write(blocks[8].group(1))"; \
	cp $(GAMS_DIR)/PricingKernel.gms $(GAMS_DIR)/primitives.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec/; \
	cd $(GAMS_DIR)/$(GAMS_BUILD)/spec; \
	if $(GAMS) test/PayoffModuleTest.gms action=ce o=run.lst scrdir=. lo=0 >/dev/null 2>&1; then \
		printf 'spec-preflight OK (production layout)\n'; \
	else \
		printf 'spec-preflight FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec/run.lst\n'; \
		sed -n 's/^\*\*\*\* *//p' run.lst | head -10; \
		exit 1; \
	fi

# spec-preflight-band: Cycle 2 spec-as-truth gate. Re-runs the sorry/admit check
# on the 3 cited theorems in eta.lean BEFORE extracting GAMS code, then mirrors
# the spec MD into the production layout and drives the band unit. Both legs gate
# on an EXIT CODE: model/test/lean_sorry_check.sh for Lean, gams itself for GAMS.
#
# LEAN4_SPEC_DIR defaults to the lean4-spec submodule at the repo root. Note the
# path has no `lean/` segment: JMSBPP/cfmm-lean4-spec stores exp/ at ITS root
# (it is itself a subtree split of the monorepo's lean/ directory).
LEAN4_SPEC_DIR ?= lean4-spec
spec-preflight-band:
	@rm -rf $(GAMS_DIR)/$(GAMS_BUILD)/spec-band
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/payoff $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/test
	@set -e; LEAN=$(LEAN4_SPEC_DIR)/exp/eta.lean; \
	if [ ! -f "$$LEAN" ]; then \
		printf 'spec-preflight-band FAIL: %s not found.\n' "$$LEAN"; \
		printf '  Run: git submodule update --init lean4-spec\n'; \
		printf '  or point LEAN4_SPEC_DIR at a checkout of JMSBPP/cfmm-lean4-spec.\n'; \
		exit 1; \
	fi; \
	for ID in pi_trader_half_strictly_increasing_in_ pi_trader_half_band_min_at_left pi_trader_half_band_max_large_trade; do \
		if ! sh model/test/lean_sorry_check.sh "$$LEAN" "$$ID"; then \
			printf 'spec-preflight-band FAIL: Lean gate rejected %s\n' "$$ID"; \
			exit 1; \
		fi; \
	done; \
	printf 'spec-preflight-band: Lean substrate OK (3 theorems sorry/admit-free)\n'
	@set -e; SPEC=$(SPEC_BAND); \
	ROOT=$(GAMS_DIR)/$(GAMS_BUILD)/spec-band; \
	python3 -c "import re; text = open('$$SPEC').read(); secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M); body6 = next((secs[i+1] for i in range(1,len(secs),2) if secs[i].startswith('## 6.')), None); assert body6 is not None, 'spec section missing: ## 6.'; m6 = re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', body6, re.S); assert m6 is not None, 'no gams code block in section: ## 6.'; open('$$ROOT/payoff/eta_pi_trader_band_monotone_large.gms','w').write(m6.group(1))"; \
	cp $(GAMS_DIR)/PricingKernel.gms $(GAMS_DIR)/primitives.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/; \
	cp $(GAMS_DIR)/payoff/_PayoffScaffolding.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/payoff/; \
	cp $(GAMS_DIR)/test/PayoffBandMonotoneLargeTest.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/test/; \
	cd $(GAMS_DIR)/$(GAMS_BUILD)/spec-band; \
	if $(GAMS) test/PayoffBandMonotoneLargeTest.gms action=ce o=run.lst scrdir=. lo=0 >/dev/null 2>&1; then \
		printf 'spec-preflight-band OK (Lean sorry/admit gate + GAMS extract+compile+execute)\n'; \
	else \
		printf 'spec-preflight-band FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec-band/run.lst\n'; \
		sed -n 's/^\*\*\*\* *//p' run.lst | head -10; \
		exit 1; \
	fi
