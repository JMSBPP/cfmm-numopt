---
phase: 00-honest-gates
plan: 02
subsystem: build-gates
tags: [make, shellcheck, gams, exit-codes, lint, negative-controls, gate-01]

# Dependency graph
requires:
  - "00-01: `make negative-controls`, the append-only `registry.tsv`, and the `-include mk/*.mk` point"
provides:
  - "`payoff-fixtures`, `spec-preflight`, `spec-preflight-band` gating on the gams EXIT CODE only"
  - "`make lint-make` — recipe bodies pulled from `make --print-data-base`, structurally checked, then shellcheck'd on SC2181/SC2015"
  - "`make tools-shellcheck` — bootstraps shellcheck 0.11.0 into the gitignored `.tools/`"
  - "`model/test/lean_sorry_check.sh` — a stable 0/1/2/3 exit-code contract for the Lean leg (body replaced by 00-04, contract not)"
  - "`PAYOFF_SRC_DIR` / `PAYOFF_GLOB` / `SPEC_ZS` / `SPEC_BAND` — the parameterisation that lets a mutant drive the same recipe"
  - "14 new registry rows (18 total); D1 closed"
affects: [00-03, 00-04, phase-1-representation, phase-2-registry]

# Tech tracking
tech-stack:
  added:
    - "shellcheck 0.11.0 (static x86_64 build, koalaman `stable` release, unpacked into `.tools/bin/`)"
  patterns:
    - "The pass/fail predicate is the process exit code; `sed`/`grep` may only extract error TEXT after the decision"
    - "A glob matching zero units FAILS — a vacuous OK is a false pass, not a pass"
    - "A gate is reviewed by a tool that is not its author (`lint-make`), and that tool is itself inside its own enumeration"
    - "A missing tool is a hard failure, never a skip"
    - "A `negative` row expecting `nonzero` accepts every reason for failing — including 'the artifact is gone' — so pair it with a `positive` presence assertion"

key-files:
  created:
    - mk/lint-make.mk
    - model/lint/lint_make.py
    - model/test/lean_sorry_check.sh
    - model/test/_mutants/payoff/eta_broken_syntax.gms
    - model/test/_mutants/specs/zero_slippage_broken.md
    - model/test/_mutants/specs/band_monotone_large_broken.md
    - model/test/_mutants/make/grep_predicate.mk
    - model/test/_mutants/make/no_set_e.mk
  modified:
    - Makefile
    - model/test/_mutants/registry.tsv
    - model/test/README-negative-controls.md
    - .planning/phases/00-honest-gates/deferred-items.md

key-decisions:
  - "The `rcg=$$?` capture in `compile-gams`/`test-gams` was applied preemptively in task 1, so `lint-make`'s FIRST run reported 0 findings. A green that has never been observed to go red is exactly what this phase bans, so the shellcheck leg was proven able to fire on a throwaway probe recipe: SC2181 and SC2015 both reported, rc=1."
  - "Three plan acceptance criteria state `rc=1` for a `make …` invocation. Measured rc=2 in all three — GNU make collapses every recipe failure to its own exit status 2. This is 00-01 deviation 4 recurring; the criteria are met in substance, and the registry rows pin `nonzero`."
  - "The plan's payoff mutant was not a mutant: without a `;` terminating `Scalar broken / 1 /`, GAMS continues the declaration across the garbage line and returns rc=0. Fixed with the terminator (measured rc=2) and the reason written into the mutant's header."
  - "The two `nc-lintmake-*` structural rows pin the exact rc=1 rather than the plan's `nonzero`: they invoke `lint_make.py` directly, not through make, so per README-negative-controls.md the exact measured code is the stricter and correct choice."
  - "D1 is closed by TWO rows, not one: presence (`nc-selftest-file-present`) and integrity (`nc-selftest-entry-count`). Presence alone would still allow the proof to be gutted to a single always-failing row."

patterns-established:
  - "`mk/<name>.mk` per plan; the root Makefile's target list is only touched to repair existing targets"
  - "Every gating recipe line begins `set -e;` — enforced by LM-SET-E, not by convention"
  - "New gating recipes need no registration with `lint-make`: it enumerates from `make --print-data-base`, so omission is not an escape route"

requirements-completed: [GATE-01]

# Metrics
duration: 11min
completed: 2026-08-15
---

# Phase 0 Plan 02: Honest gates — exit-code gating + `make lint-make` Summary

**The three listing-scraping targets now gate on the gams exit code, five committed mutants redden
them on every `make negative-controls` run, a third tool (`make lint-make`, shellcheck 0.11.0)
reads the repaired shell rather than trusting its author, and D1 — the live false pass where
deleting the runner's own falsifiability proof left the suite green — is closed and proven.**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-08-15T19:41:15Z
- **Completed:** 2026-08-15T19:52:14Z
- **Tasks:** 4 (3 planned + the mandatory D1 closure)
- **Files:** 16 (8 created, 8 modified)

## The recipe shape adopted

Identical in all three repaired targets, and identical to the shape `compile-gams` and `test-gams`
already used:

```make
	@set -e; cd $(GAMS_DIR); rc=0; ok=0; fail=0; \
	for f in $$(find $(PAYOFF_SRC_DIR) -name '$(PAYOFF_GLOB)' 2>/dev/null | sort); do \
		...
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
	...
```

Three properties, each load-bearing:

1. **The predicate is `if $(GAMS) …; then`.** `grep -c 'if \$(GAMS)' Makefile` → `5`.
2. **`sed` runs only in the `else` branch**, after the decision, to extract the `**** …` error text
   into the message. It can never make a failing run pass.
3. **A zero-match glob fails.** This closed a *second* false pass the plan found: a glob matching
   nothing previously printed nothing and exited 0. The same guard was added to `compile-gams`
   (`ok+fail+skip`) and `test-gams` (`ok+fail`).

The false-premise comment — *"gams exits 0 even on compile errors, so the recipe MUST grep"* — was
deleted, not softened. `grep -c 'exits 0 even on compile errors' Makefile` → `0`. **The token
`grep` no longer appears anywhere in the Makefile at all** (`grep -n 'grep' Makefile` → no match).

The Lean leg moved into `model/test/lean_sorry_check.sh` with a documented exit-code contract
(`0` clean / `1` sorry-or-admit / `2` declaration not found / `3` usage). Measured: `rc=0` on
`pi_trader_half_band_min_at_left`, `rc=2` on `no_such_theorem`, `rc=3` on no arguments. Its two
known limitations (column-0 `theorem`-only matching, and body extraction that can misattribute a
later `sorry`) are written into the script header for plan 00-04 to replace behind the same CLI.

## shellcheck: version and install route actually used

- **Version: 0.11.0.** `ShellCheck - shell script analysis tool / version: 0.11.0`
- **Route: the static tarball**, `https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz`,
  unpacked by `make tools-shellcheck` into `.tools/bin/shellcheck` (already gitignored by 00-01).
  The Arch package fallback was **not** needed — the download succeeded on the first attempt.
- `SHELLCHECK ?= $(shell command -v shellcheck 2>/dev/null || echo .tools/bin/shellcheck)`, so a
  system install takes precedence if one ever appears.

**Absence is a failure, not a skip** — measured:

```
$ make lint-make SHELLCHECK=/nonexistent/shellcheck
lint-make FAIL: shellcheck not found at '/nonexistent/shellcheck' - run 'make tools-shellcheck'
make: *** [mk/lint-make.mk:27: lint-make] Error 1
rc=2
```

## Every finding `lint-make` reported on its first run

**Zero.** `lint-make: 9 recipes, 0 findings`, rc=0.

That number is only meaningful with the following disclosure. The plan anticipated SC2181 in the
`else` branches of `compile-gams`/`test-gams`, which printed `"$$?"`. **The remedy — capturing
`rcg=$$?` as the first statement of the branch — was applied preemptively during task 1**, so the
first `lint-make` run had nothing left to find. A gate that has never been observed to go red is
precisely what this phase exists to remove, so the shellcheck leg was proven able to fire before
the green was accepted, on a throwaway probe recipe (`model/test/_probe_sc.mk`, deleted after use):

```
$ printf '.PHONY: probe-sc\nprobe-sc:\n\tset -e; foo bar; if [ $? -ne 0 ]; then exit 1; fi; a && b || c\n' > model/test/_probe_sc.mk
$ python3 model/lint/lint_make.py --file model/test/_probe_sc.mk
…/probe-sc.sh:2:23: note: Check exit code directly with e.g. 'if ! mycmd;', not indirectly with $?. [SC2181]
…/probe-sc.sh:2:54: note: Note that A && B || C is not if-then-else. C may run when A is true. [SC2015]
lint-make: 1 recipes, 2 findings
probe rc=1
```

Both codes fire, both are surfaced as findings, and the exit code is 1. The two structural checks
are proven by *committed* mutants (below), so they re-run forever; the shellcheck leg's proof is
the throwaway above plus the committed `no_set_e.mk`/`grep_predicate.mk` for the structural half.

**No `# shellcheck disable` directive was added anywhere.** `grep -rc 'shellcheck disable'` →
`0` for `Makefile`, `mk/lint-make.mk`, `mk/negative-controls.mk`, `model/lint/lint_make.py`.

**One finding outside the SC2181/SC2015 include set, disclosed rather than hidden:** running
shellcheck unrestricted over the generated scripts reports `SC2194` ("This word is constant") once,
at `compile-gams.sh:5:7`. It is an artifact of normalisation — `case " $(GAMS_SKIP) " in` becomes
`case " MAKEVAR_GAMS_SKIP " in`, which is genuinely constant *after* the substitution but not in
the real recipe. It is not a defect in the Makefile and is not suppressed; it is simply outside the
declared include set.

### What `lint-make` does, and one thing it does not

It asks GNU make itself which recipe bodies are live (`make --print-data-base --question
--no-builtin-rules --no-builtin-variables`), keeps those sourced from `Makefile` or `mk/*.mk`,
normalises make syntax to sh (`$$`→`$` protected first, `$(NAME)`→`MAKEVAR_NAME`, remaining
`$(…)`→`MAKEFUNC`), writes each to `model/build/lint-make/<target>.sh`, and applies:

| check | fires on |
|-------|----------|
| `LM-GREP-PREDICATE` | `if … grep …; then`, `if ! grep`, `while/until … grep`, `grep … &&/||`, `VAR=…grep…` |
| `LM-SET-E` | any logical line containing `;`, `&&`, `||`, or a `for/if/while/until/case` keyword that does not begin `set -e;` |
| shellcheck | `-s sh --include=SC2181,SC2015 -f gcc` |

**Nine recipes reviewed:** `clean-gams`, `compile-gams`, `lint-make`, `negative-controls`,
`payoff-fixtures`, `spec-preflight`, `spec-preflight-band`, `test-gams`, `tools-shellcheck`.
`negative-controls` and `lint-make` are both inside the enumeration, so the circularity does not
re-enter one level up, and a new target needs no registration — omission is not an escape route.
A run that extracts **zero** recipe bodies is refused (`lint-make FAIL: no recipe bodies were
extracted - a review of nothing is not a review`, rc=1), verified against an empty `.mk`.

**Known limitation (logged as D3):** `LM-GREP-PREDICATE` keys on the token `grep`. A listing scrape
written with `awk`, `case`, or `sed -n …; test -s` in a predicate position would not be caught.

## The fourteen registry ids added

Twelve from task 3 (GATE-01 controls):

| id | kind | expect | observed rc |
|----|------|--------|-------------|
| `nc-gate01-payoff-fixtures-mutant` | negative | nonzero | 2 |
| `nc-gate01-payoff-fixtures-empty` | negative | nonzero | 2 |
| `nc-gate01-payoff-fixtures-positive` | positive | 0 | 0 |
| `nc-gate01-spec-preflight-mutant` | negative | nonzero | 2 |
| `nc-gate01-spec-preflight-positive` | positive | 0 | 0 |
| `nc-gate01-spec-band-mutant` | negative | nonzero | 2 |
| `nc-gate01-spec-band-nolean` | negative | nonzero | 2 |
| `nc-gate01-spec-band-positive` | positive | 0 | 0 |
| `nc-lintmake-missing-shellcheck` | negative | nonzero | 2 |
| `nc-lintmake-grep-predicate` | negative | **1** | 1 |
| `nc-lintmake-no-set-e` | negative | **1** | 1 |
| `nc-lintmake-positive` | positive | 0 | 0 |

Two from task 4 (D1 closure): `nc-selftest-file-present`, `nc-selftest-entry-count`.

`awk -F'\t' '!/^#/ && NF{print NF}' model/test/_mutants/registry.tsv | sort -u` → `5`.

The five committed mutants they drive: `payoff/eta_broken_syntax.gms`,
`specs/zero_slippage_broken.md`, `specs/band_monotone_large_broken.md`, `make/grep_predicate.mk`,
`make/no_set_e.mk`.

## D1 — closed, with both required measurements

The false pass was **reproduced first**, on the tree as wave 1 left it plus this plan's 12 rows:

```
$ mv model/test/_mutants/registry.selftest.tsv /tmp/x && make negative-controls; echo rc=$?
negative-controls: 16 entries, 0 failed
rc=0                                      # ← the artifact proving the runner CAN fail was deleted,
                                          #   and the suite stayed GREEN
```

Root cause: `nc-runner-selftest-registry` expects merely `nonzero`, and a *missing* registry also
exits non-zero (rc=2, "registry … does not exist"). Its success was indistinguishable from its own
absence — the same shape of defect as the listing scrape GATE-01 removed.

Closed with two `positive` rows. **Both mandated acceptance measurements, real output:**

```
### 1. proof absent — must redden
$ mv model/test/_mutants/registry.selftest.tsv /tmp/x && make negative-controls; echo rc=$?
FAIL nc-selftest-file-present               kind=positive expect=0        rc=1
FAIL nc-selftest-entry-count                kind=positive expect=0        rc=1
negative-controls: 18 entries, 2 failed
rc=2

### 2. proof restored — must be green
$ mv /tmp/x model/test/_mutants/registry.selftest.tsv && make negative-controls; echo rc=$?
negative-controls: 18 entries, 0 failed
rc=0
```

The second row was proven independently — presence alone would still let the proof be gutted:

```
$ # selftest registry reduced to a single always-failing row
$ make negative-controls
PASS nc-runner-selftest-registry            kind=negative expect=nonzero  rc=2
PASS nc-selftest-file-present               kind=positive expect=0        rc=0
FAIL nc-selftest-entry-count                kind=positive expect=0        rc=1
rc=2                                        # file restored immediately after
```

`nc-runner-selftest-registry` keeps `expect = nonzero` untouched, per D1's own note: make never
returns the runner's `1`. The general rule is now written into `README-negative-controls.md`:
*a `negative` row accepting `nonzero` accepts every reason for failing, including "the artifact is
gone", so pair it with a `positive` presence assertion.*

## Fixture regeneration: byte-identical for BOTH fixtures

| fixture | md5 before | md5 after |
|---------|-----------|-----------|
| `model/payoff_zero_slippage.gdx` | `ec318d2bff86224eb9ced3dd6e0bcfe1` | `ec318d2bff86224eb9ced3dd6e0bcfe1` |
| `model/payoff_band_monotone_large.gdx` | `12869d29c1da30f1ed3e577a33a888f7` | `12869d29c1da30f1ed3e577a33a888f7` |

`git status --short -- 'model/*.gdx'` prints nothing after `make payoff-fixtures` and after
`make negative-controls`. The plan's binding fact is confirmed and extended to the band fixture,
which the plan measured only for zero-slippage.

## Task Commits

1. **Task 1: Exit-code-only gating in the three targets** — `514741f` (fix)
2. **Task 2: `make lint-make` — the third instrument** — `88534fc` (feat)
3. **Task 3: Register the GATE-01 mutants and controls** — `0ffe6b2` (test)
4. **Task 4 (mandatory extra): close D1** — `77e98f6` (test)

## Verification (real output)

| # | Command | Result |
|---|---------|--------|
| 1 | `make compile-gams` | `compile-gams: 12 ok, 0 failed, 0 skipped`, rc=0 |
| 2 | `make test-gams` | `test-gams: 4 passed, 0 failed`, rc=0 |
| 3 | `make lint-make` | `lint-make: 9 recipes, 0 findings`, rc=0 |
| 4 | `make negative-controls` | `negative-controls: 18 entries, 0 failed`, rc=0 |
| 5 | `grep -n 'grep' Makefile` | no match — the token is gone from the Makefile entirely |
| 6 | `git status --short` | only the two pre-existing unrelated edits (`ROADMAP.md`, `config.json`) |
| — | `grep -c 'Status: (Compilation\|Execution) error' Makefile` | `0` |
| — | `grep -c 'exits 0 even on compile errors' Makefile` | `0` |
| — | `grep -c 'if \$(GAMS)' Makefile` | `5` |
| — | `make payoff-fixtures` | `payoff-fixtures: 2 ok, 0 failed`, rc=0 |
| — | `make payoff-fixtures PAYOFF_SRC_DIR=nosuchdir` | `payoff-fixtures FAIL: no units matched nosuchdir/eta_*.gms`, make rc=**2** (recipe rc=1) |
| — | `make payoff-fixtures PAYOFF_SRC_DIR=test/_mutants/payoff` | `FAIL test/_mutants/payoff/eta_broken_syntax.gms`, `0 ok, 1 failed`, make rc=2 |
| — | `make spec-preflight` | `spec-preflight OK (production layout)`, rc=0 |
| — | `make spec-preflight-band` | `spec-preflight-band OK (Lean sorry/admit gate + GAMS extract+compile+execute)`, rc=0 |
| — | `make spec-preflight-band LEAN4_SPEC_DIR=/nonexistent` | FAIL message, make rc=**2** (recipe rc=1) |
| — | `sh model/test/lean_sorry_check.sh lean4-spec/exp/eta.lean pi_trader_half_band_min_at_left` | rc=0 |
| — | `sh model/test/lean_sorry_check.sh lean4-spec/exp/eta.lean no_such_theorem` | rc=2 |
| — | `make tools-shellcheck` | `version: 0.11.0`, rc=0 |
| — | `make lint-make SHELLCHECK=/nonexistent/shellcheck` | `shellcheck not found`, make rc=**2** (recipe rc=1) |
| — | `ls model/build/lint-make/*.sh` | includes all 7 required + `clean-gams.sh`, `tools-shellcheck.sh` |
| — | `grep -rc 'shellcheck disable' …` | `0` in every file |
| — | `grep -c 'SC2181,SC2015' mk/lint-make.mk` | `1` |
| — | `head -3 …/zero_slippage_broken.md \| grep -c 'TEST-09 MUTANT'` | `1` |
| — | `awk -F'\t' '!/^#/ && NF{print NF}' registry.tsv \| sort -u` | `5` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's payoff mutant was not a mutant — GAMS returned rc=0**

- **Found during:** Task 3
- **Issue:** The mutant body specified by the plan is `Scalar broken / 1 /` followed by
  `this line is not GAMS syntax )))`. GAMS continues a `Scalar` declaration until a `;`, so it
  parsed the garbage line as further scalar identifiers. **Measured: `gams … action=ce` → rc=0,
  and `make payoff-fixtures PAYOFF_SRC_DIR=test/_mutants/payoff` → `1 ok, 0 failed`, rc=0.** The
  control that was supposed to prove `payoff-fixtures` can redden would have been green forever —
  the exact defect class this phase exists to remove, reproduced inside its own remedy.
- **Fix:** Terminate the statement: `Scalar broken / 1 / ;`. The reason is written into the
  mutant's own header so it is not silently re-broken.
- **Verification:** `gams` → **rc=2**; `make payoff-fixtures PAYOFF_SRC_DIR=test/_mutants/payoff`
  → `0 ok, 1 failed`, make rc=2, printing the extracted `'=' or '..' or ':=' or '$=' operator
  expected` text.
- **Committed in:** `0ffe6b2`

**2. [Rule 2 - Missing critical] `lint-make`'s shellcheck leg had never been observed to fire**

- **Found during:** Task 2
- **Issue:** Task 1's `rcg=$$?` capture (plan step 7) removed the only anticipated SC2181 source
  before `lint-make` existed, so its first run reported `0 findings`. Accepting that green would
  have shipped a shellcheck integration that has never produced a single finding — unfalsifiable
  by TEST-08's rule.
- **Fix:** Ran a throwaway probe recipe containing both anticipated defects. Both SC2181 and
  SC2015 were reported and the run exited 1 (output quoted above). Probe deleted; the two
  *structural* checks have committed mutants that re-run forever.
- **Files modified:** none (verification only)

**3. [Rule 3 - Blocking] `gsd-tools roadmap update-plan-progress 0` corrupted `ROADMAP.md`**

- **Found during:** state updates
- **Issue:** `.planning/ROADMAP.md` has no per-phase plan-progress table. The subcommand reported
  `{"updated": true, "plan_count": 4, "summary_count": 2}` and instead **overwrote a Requirement
  Coverage row**, turning
  `| 0 — Honest gates | GATE-01 … TEST-09 | 8 |` into
  `| 0 — Honest gates | 2/4 | In Progress|  | 1 — Representation kernel … |` — destroying Phase 0's
  requirement list and swallowing the start of the Phase 1 row. `gsd-tools state advance-plan` also
  refuses this STATE.md (`Cannot parse Current Plan or Total Plans`).
- **Fix:** Row restored by hand, verified by `git diff .planning/ROADMAP.md` showing only the
  pre-existing unrelated GATE-07 wording edit plus 00-02's own Phase-0 checkmarks. ROADMAP.md and
  STATE.md were then updated by hand. Recorded in STATE.md's Blockers so later plans do not repeat
  it.
- **Files modified:** `.planning/ROADMAP.md` (restored), `.planning/STATE.md`

### Plan factual corrections — recorded, not weakened

**4. Three acceptance criteria state `rc=1` for a `make …` invocation. Measured: `rc=2`.**

- **Affected:** `make payoff-fixtures PAYOFF_SRC_DIR=nosuchdir` (task 1),
  `make spec-preflight-band LEAN4_SPEC_DIR=/nonexistent` (task 1),
  `make lint-make SHELLCHECK=/nonexistent/shellcheck` (task 2).
- **Fact:** GNU make collapses every recipe failure to its own exit status **2**. This is 00-01
  deviation 4 recurring, and it is already recorded as a project decision in STATE.md. Each
  recipe genuinely exits **1** — make prints `Error 1` in every case, which is the direct
  evidence — but `1` is not observable through `make`.
- **Resolution:** Nothing was weakened. The substantive claim (the target reddens, with the right
  message) is verified directly in each case, and every registry row whose command is `make …`
  pins `nonzero`, which is correct rather than lenient.

**5. `nc-gate01-spec-band-nolean` pins `nonzero`, not the plan's exact `1`.**

- Same fact as above. Its command is `make spec-preflight-band LEAN4_SPEC_DIR=/nonexistent`, which
  returns 2. Pinning `1` would pin a number make never returns, and the row would have failed on
  its first run. Rationale is recorded in the row's own claim text.

### Strengthenings beyond the plan

**6. `nc-lintmake-grep-predicate` and `nc-lintmake-no-set-e` pin the exact `1` instead of the
plan's `nonzero`.** Both invoke `model/lint/lint_make.py` **directly**, not through make, so
README-negative-controls.md's rule applies in the other direction: prefer an exact code whenever it
is measured and stable. Both measured rc=1. This detects a future internal error (rc=2) that
`nonzero` would absorb.

**7. The zero-match guard was added to four targets, not two.** The plan specified it for
`payoff-fixtures` (step 3) and for `compile-gams`/`test-gams` (step 7); `spec-preflight` and
`spec-preflight-band` do not loop, so they need none. All four looping/gating paths are covered.

**8. D1 closed with two rows, not the one proposed in `deferred-items.md`.** Presence alone leaves
the proof gutable to a single always-failing row, which still exits non-zero. The integrity row was
independently observed to fail for exactly that reason.

---

**Total:** 3 auto-fixed (1 bug, 1 missing-critical, 1 blocking), 2 recorded factual corrections
to the plan, 3 strengthenings, plus the mandatory D1 task.
**Impact on plan:** No scope creep and nothing in `must_haves` relaxed. Every deviation moves in
the strict direction; the two factual corrections exist because the plan restated a number that
GNU make does not produce.

## Issues Encountered

- **`LM-GREP-PREDICATE` is token-based (D3, logged).** It keys on the literal token `grep`. A
  listing scrape written with `awk '/Status:/{exit 1}'`, a `case` pattern, or `sed -n …; test -s`
  in a predicate position would pass `lint-make` today. The idiom that produced GATE-01 is caught;
  its near neighbours are not. Logged to `deferred-items.md` rather than fixed, per the scope
  boundary — broadening the pattern set needs its own mutants.
- **`SC2194` at `compile-gams.sh:5:7`** is reported when shellcheck is run unrestricted over the
  generated scripts. It is a normalisation artifact (`$(GAMS_SKIP)` → the literal
  `MAKEVAR_GAMS_SKIP`), not a Makefile defect, and it is outside the declared SC2181/SC2015 include
  set. Disclosed rather than suppressed — no `# shellcheck disable` was added.
- **`model/build/lint-make/` accumulates scripts from `--file` runs** (`mutant-*.sh`, and the
  deleted probe). The directory is gitignored and is regenerated, not incremental state, but it is
  not pruned between runs.

## User Setup Required

None. `make tools-shellcheck` is idempotent and self-bootstrapping; it prefers a system shellcheck
if one is installed, and otherwise fetches the static build into the gitignored `.tools/`. A CI
job adding `lint-make` must call `tools-shellcheck` first, or the target will (correctly) fail.

## Next Phase Readiness

- **GATE-01 is met.** All three targets gate on exit codes, no `grep` occupies a pass/fail position
  anywhere in the Makefile, and five committed mutants redden them on every `negative-controls` run.
- **Plan 00-04 inherits a stable contract**, not a rewrite: `lean_sorry_check.sh`'s 0/1/2/3 exit
  codes and its CLI stay; only the body (and its two documented limitations) change, plus the
  committed `SorryFixture.lean` control.
- **Plans 00-03/00-04 need no Makefile edit** to be reviewed — `lint-make` enumerates from
  `make --print-data-base`, so any target they add in `mk/*.mk` is in scope automatically. They
  must, however, begin every compound recipe line with `set -e;` or `lint-make` will redden.
- **Carry forward:** `expect = nonzero` whenever a row's command is `make …`; exact rc otherwise.
  And the new rule from D1: a `nonzero` negative row accepts every reason for failing, so pair it
  with a `positive` presence/integrity assertion whenever it reads a committed artifact.

## Self-Check: PASSED

All 8 claimed created files and 4 modified files exist on disk and are tracked by git. All 4
claimed task commits (`514741f`, `88534fc`, `0ffe6b2`, `77e98f6`) exist on
`gsd/phase-0-honest-gates`. Every acceptance criterion across the 4 tasks was verified by running
the stated command and recording its real output, with three criteria met in substance but not in
their stated number (deviation 4: make exit status 2, recipe exit status 1). The three baselines
re-ran green at the end: `12 ok, 0 failed` / `4 passed, 0 failed` / `18 entries, 0 failed`, and
`git status --short` shows no modification to any `model/*.gdx`.

---
*Phase: 00-honest-gates*
*Completed: 2026-08-15*
