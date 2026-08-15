# ── GATE-01 criterion 3: the repaired recipes are reviewed by a THIRD tool ──
# lint-make extracts every recipe body from the live Makefile and mk/*.mk via
# `make --print-data-base`, normalises make syntax to sh, applies two structural
# checks (no output-scraping in a predicate position; `set -e` on every compound
# recipe line), then runs shellcheck restricted to the SC2181/SC2015 classes.
#
# shellcheck is NOT installed by default on this machine. lint-make FAILS when
# it is missing — a silent skip is the defect this phase exists to remove.
SHELLCHECK       ?= $(shell command -v shellcheck 2>/dev/null || echo .tools/bin/shellcheck)
SHELLCHECK_CODES ?= SC2181,SC2015
SHELLCHECK_URL   ?= https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz

.PHONY: lint-make tools-shellcheck

tools-shellcheck:
	set -e; \
	if command -v shellcheck >/dev/null 2>&1; then shellcheck --version; exit 0; fi; \
	if [ -x .tools/bin/shellcheck ]; then .tools/bin/shellcheck --version; exit 0; fi; \
	mkdir -p .tools/bin .tools/tmp; \
	curl -sSfL "$(SHELLCHECK_URL)" -o .tools/tmp/shellcheck.tar.xz; \
	tar -xJf .tools/tmp/shellcheck.tar.xz -C .tools/tmp; \
	cp .tools/tmp/shellcheck-stable/shellcheck .tools/bin/shellcheck; \
	chmod +x .tools/bin/shellcheck; \
	.tools/bin/shellcheck --version

lint-make:
	set -e; SHELLCHECK="$(SHELLCHECK)" SHELLCHECK_CODES="$(SHELLCHECK_CODES)" \
		python3 model/lint/lint_make.py
