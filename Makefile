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

.PHONY: compile-gams test-gams test-units test-volumepath clean-gams payoff-fixtures

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
# JSON line width), so a green run certifies the emitted JSON — no external
# tool is consulted; this Makefile is GAMS-only. The double run pins
# determinism: same inputs -> same bytes. Contract: docs/volume-path.md.
VP_DIR   := $(GAMS_DIR)/mev_tax_model_one
test-volumepath:
	@set -e; cd $(VP_DIR); mkdir -p $(GAMS_BUILD); \
	printf '>> run 1: volume_path.gms (self-test fixture)\n'; \
	$(GAMS) volume_path.gms action=ce o=$(GAMS_BUILD)/run1.lst scrdir=$(GAMS_BUILD) lo=0 >/dev/null 2>&1 \
		|| { printf 'test-volumepath FAIL: see %s/$(GAMS_BUILD)/run1.lst\n' "$(VP_DIR)"; \
		     sed -n 's/^\*\*\*\* *//p' $(GAMS_BUILD)/run1.lst | head -8; exit 1; }; \
	cp volume_path.json $(GAMS_BUILD)/run1.json; \
	printf '>> run 2: determinism\n'; \
	$(GAMS) volume_path.gms action=ce o=$(GAMS_BUILD)/run2.lst scrdir=$(GAMS_BUILD) lo=0 >/dev/null 2>&1; \
	cmp -s volume_path.json $(GAMS_BUILD)/run1.json \
		|| { printf 'test-volumepath FAIL: two identical runs emitted different JSON\n'; exit 1; }; \
	printf '\ntest-volumepath: prover gates PASS, byte-identical across 2 runs\n'

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
