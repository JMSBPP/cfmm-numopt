# ── GATE-05: fixture freshness, scoped to what payoff-fixtures can produce ──
# gdxdiff is used in its TWO-ARGUMENT form and run with cwd inside the scratch
# directory. Measured (GAMS 54.1): the 3-argument form returns rc=7 for
# identical AND for different inputs when it cannot rename its temp file to the
# given output path, and gdxdiff drops `diffile.gdx` into the current directory
# either way. Predicate: rc != 0. Full table: model/test/README-gdxdiff.md.
#
# FIXTURE_DIR         where the REFERENCE copies come from (a mutant directory
#                     supplies stale references without touching model/).
# CHECK_FIXTURES_TSV  the single declaration of which .gdx has a wired producer.
FIXTURE_DIR        ?= $(GAMS_DIR)
CHECK_FIXTURES_TSV ?= model/fixtures/FIXTURES.tsv
FIXTURE_SCRATCH    := $(GAMS_DIR)/$(GAMS_BUILD)/fixtures

.PHONY: check-fixtures

check-fixtures:
	@set -e; rm -rf $(FIXTURE_SCRATCH); mkdir -p $(FIXTURE_SCRATCH); \
	names=$$(awk -F'\t' '!/^#/ && NF {print $$1}' $(CHECK_FIXTURES_TSV)); \
	if [ -z "$$names" ]; then \
		printf 'check-fixtures FAIL: no fixtures declared in %s\n' "$(CHECK_FIXTURES_TSV)"; \
		printf '  An empty declaration would compare nothing and report green.\n'; \
		exit 1; \
	fi; \
	for n in $$names; do \
		cp "$(GAMS_DIR)/$$n" "$(FIXTURE_SCRATCH)/wt_$$n"; \
		cp "$(FIXTURE_DIR)/$$n" "$(FIXTURE_SCRATCH)/ref_$$n"; \
	done; \
	regen=0; \
	if ! $(MAKE) payoff-fixtures; then regen=1; fi; \
	for n in $$names; do \
		cp "$(GAMS_DIR)/$$n" "$(FIXTURE_SCRATCH)/new_$$n"; \
		cp "$(FIXTURE_SCRATCH)/wt_$$n" "$(GAMS_DIR)/$$n"; \
	done; \
	if [ $$regen -ne 0 ]; then \
		printf 'check-fixtures FAIL: payoff-fixtures could not regenerate the fixtures\n'; \
		exit 1; \
	fi; \
	rc=0; \
	cd $(FIXTURE_SCRATCH); \
	for n in $$names; do \
		if gdxdiff "ref_$$n" "new_$$n" > "diff_$$n.log" 2>&1; then \
			printf '   FRESH  %s\n' "$$n"; \
		else \
			printf '   STALE  %s  (gdxdiff rc != 0 -- see %s/diff_%s.log)\n' "$$n" "$(FIXTURE_SCRATCH)" "$$n"; \
			rc=1; \
		fi; \
	done; \
	printf '\ncheck-fixtures: compared %s fixture(s)\n' "$$(printf '%s\n' $$names | wc -l)"; \
	exit $$rc

# ── GATE-07: the Lean proof gate, usable from any target ───────────────────
# The predicate is model/test/lean_sorry_check.sh's exit code: 0 clean,
# 1 sorry/admit in the body, 2 declaration not found, 3 usage/file error.
# Declaration ids are matched EXACTLY, against the bare name or the
# fully-qualified (namespace-prefixed) name.
.PHONY: lean-sorry-check

lean-sorry-check:
	@set -e; \
	if [ -z "$(MODULE)" ] || [ -z "$(THEOREM)" ]; then \
		printf 'usage: make lean-sorry-check MODULE=<file> THEOREM=<name>\n'; exit 3; \
	fi; \
	sh model/test/lean_sorry_check.sh "$(MODULE)" "$(THEOREM)"

# ── GATE-06: is CI reachable, and can the gate actually gate? ───────────────
# The environment ALREADY EXISTS -- measured: it was auto-created
# 2026-07-27T23:24:41Z by the first workflow run, not deliberately, with 0
# protection rules and 0 runners. FINDING IT PRESENT IS NOT THE CRITERION BEING
# MET. Both legs are probed and both must be satisfied.
#
# Ordering is load-bearing: protection rules BEFORE any runner is registered. A
# PUBLIC repo + a self-hosted runner + an inert environment gate is the fork-PR
# arbitrary-code-execution scenario, and .github/workflows/gams.yml's `approve`
# job is the only thing that blocks BEFORE untrusted code is checked out.
GH_REPO ?= JMSBPP/cfmm-gams

.PHONY: ci-selftest

ci-selftest:
	@set -e; \
	rules=$$(gh api repos/$(GH_REPO)/environments/gams-gate --jq '.protection_rules|length'); \
	case "$$rules" in \
		''|*[!0-9]*) printf 'ci-selftest FAIL: protection_rules probe returned %s, not a count\n' "'$$rules'"; exit 1;; \
	esac; \
	printf 'gams-gate protection_rules: %s\n' "$$rules"; \
	if [ "$$rules" -lt 1 ]; then \
		printf 'ci-selftest FAIL: gams-gate has 0 protection rules. A PUBLIC repo with a\n'; \
		printf '  self-hosted runner behind an inert gate is the fork-PR arbitrary-code\n'; \
		printf '  execution scenario. Add a required reviewer BEFORE registering a runner.\n'; \
		exit 1; \
	fi; \
	runners=$$(gh api repos/$(GH_REPO)/actions/runners --jq '.total_count'); \
	case "$$runners" in \
		''|*[!0-9]*) printf 'ci-selftest FAIL: runners probe returned %s, not a count\n' "'$$runners'"; exit 1;; \
	esac; \
	printf 'self-hosted runners: %s\n' "$$runners"; \
	if [ "$$runners" -lt 1 ]; then \
		printf 'ci-selftest FAIL: 0 runners registered -- the gams job can never start.\n'; \
		exit 1; \
	fi; \
	printf 'ci-selftest OK (%s protection rule(s), %s runner(s))\n' "$$rules" "$$runners"
