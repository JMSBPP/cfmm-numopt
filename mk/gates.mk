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
