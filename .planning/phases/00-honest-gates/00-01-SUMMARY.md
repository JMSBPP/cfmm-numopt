---
phase: 00-honest-gates
plan: 01
subsystem: testing
tags: [make, python3, gams, negative-controls, exit-codes, tsv-registry]

# Dependency graph
requires: []
provides:
  - "`make negative-controls` — an exit-code-only runner over a committed TSV registry of 'X reddens when Y breaks' claims"
  - "`model/test/_mutants/` tree, invisible to both `compile-gams` and `test-gams` by construction"
  - "`model/test/_mutants/registry.tsv` — append-only, one entry per line (M7 concurrency substrate)"
  - "`model/test/_mutants/registry.selftest.tsv` — the runner's own mutation proof, re-run by a main-registry row"
  - "The single permanent `-include mk/*.mk` point in the root Makefile"
affects: [00-02, 00-03, 00-04, phase-1-representation, phase-2-registry]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pass/fail predicate is the process exit code only — never a pattern match on a GAMS listing"
    - "A claim is discharged by a committed registry row, never by a hand-run mutation"
    - "Every gate ships with an artifact proving it can go red"
    - "mk/<name>.mk per plan; the root Makefile is never edited again to add a target"

key-files:
  created:
    - mk/negative-controls.mk
    - model/test/negative_controls.py
    - model/test/_mutants/registry.tsv
    - model/test/_mutants/registry.selftest.tsv
    - model/test/_mutants/gams/always_aborts.gms
    - model/test/README-negative-controls.md
  modified:
    - Makefile
    - .gitignore

key-decisions:
  - "`.DEFAULT_GOAL := compile-gams` pinned: `-include mk/*.mk` precedes every rule, so without the pin the first target of the first included mk file silently becomes the default goal of a bare `make`."
  - "Rows whose command is `make …` must use `expect = nonzero`: GNU make reports ANY recipe failure as its own exit status 2, so the runner's exit 1 is never observable through make. Rows invoking `gams` or the runner directly pin the exact code."
  - "The seed GAMS abort row pins the exact rc=3 rather than `nonzero`, so a GAMS behaviour change is detected rather than absorbed."
  - "The word `grep` was removed from the runner docstring and the mk comment: the plan's own acceptance criterion greps those files for that token, and a comment mentioning the banned idiom is indistinguishable from using it."

patterns-established:
  - "Registry schema: id<TAB>kind<TAB>expect<TAB>command<TAB>claim, '#' comments, append-only"
  - "Refusal-first runner: missing/empty/malformed/duplicated registry exits non-zero rather than reporting a vacuous green"
  - "Timeout counts as failure, never as a pass"

requirements-completed: [TEST-09]

# Metrics
duration: 6min
completed: 2026-08-15
---

# Phase 0 Plan 01: Negative-control substrate Summary

**`make negative-controls` — an exit-code-only Python runner over a committed, append-only TSV registry of "X reddens when Y breaks" claims, seeded with 4 rows and proven able to fail by a committed selftest registry that one of those rows executes on every run.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-08-15T19:31:24Z
- **Completed:** 2026-08-15T19:37:00Z
- **Tasks:** 3
- **Files modified:** 8 (6 created, 2 modified)

## Accomplishments

- The root `Makefile` now has its one permanent extension point (`-include mk/*.mk`); plans 00-02/03/04 ship `mk/<name>.mk` and never touch it again.
- `test-gams` excludes `test/_mutants/`, so deliberately-broken units can be committed without reddening the suite. Both baselines re-verified after the mutants landed.
- The pass/fail predicate is the process exit code end-to-end. `grep -rn 'grep' model/test/negative_controls.py mk/negative-controls.mk` returns no matches.
- The runner refuses a vacuous green: a missing, empty, malformed, or duplicated-id registry exits non-zero, and a timeout counts as a failure.
- The runner's own falsifiability is a committed artifact, not a claim: `registry.selftest.tsv` makes it report `3 entries, 3 failed`, and the main-registry row `nc-runner-selftest-registry` re-runs that proof every time.

## Registry schema as shipped

TSV, one entry per line, append-only, `#` starts a comment, fields separated by a literal tab:

```
id <TAB> kind <TAB> expect <TAB> command <TAB> claim
```

| field | meaning |
|-------|---------|
| `id` | unique slug `[A-Za-z0-9._-]+`; duplicates are a hard error |
| `kind` | `negative` (MUST fail) or `positive` (MUST succeed) |
| `expect` | `nonzero` (negative rows only) or an exact integer return code |
| `command` | `sh` command, cwd = repository root |
| `claim` | the "X reddens when Y breaks" sentence the row discharges |

### The four seeded row ids and their measured return codes

| id | kind | expect | observed rc |
|----|------|--------|-------------|
| `nc-runner-positive-testgams` | positive | `0` | 0 |
| `nc-runner-negative-gamsabort` | negative | `3` | **3** |
| `nc-runner-selftest-registry` | negative | `nonzero` | 2 |
| `nc-runner-empty-registry` | negative | `nonzero` | 2 |

**Measured rc of the seed GAMS abort: 3.** `model/test/_mutants/gams/always_aborts.gms` run with
`action=ce` returns 3, confirming the plan's binding fact and the row's exact pin.

### The `find` amendment made to `test-gams`

```diff
-	for f in $$(find test -name '*.gms' 2>/dev/null | sed 's|^\./||' | sort); do \
+	for f in $$(find test -name '*.gms' -not -path 'test/_mutants/*' 2>/dev/null | sed 's|^\./||' | sort); do \
```

with a `NOTE:` comment directly above the `test-gams:` target line recording why. `compile-gams`
needed no amendment — it already excludes `./test/*`.

## Task Commits

1. **Task 1: Root Makefile include point, `_mutants` exclusion, mk/ substrate** — `434062a` (chore)
2. **Task 2: Exit-code-only runner and seeded registry** — `1e5a6ca` (feat)
3. **Task 3: Prove the runner can fail — the selftest registry** — `6df3dbf` (test)

## Files Created/Modified

- `Makefile` — `-include mk/*.mk`, `.DEFAULT_GOAL` pin, `_mutants` exclusion in `test-gams` + rationale comment
- `.gitignore` — `.tools/` for the plan 00-02 shellcheck bootstrap
- `mk/negative-controls.mk` — the `negative-controls` target; `REGISTRY` / `NC_TIMEOUT` contract
- `model/test/negative_controls.py` — the runner; predicate is `subprocess.call(...)`'s return code
- `model/test/_mutants/registry.tsv` — 4 seeded rows
- `model/test/_mutants/registry.selftest.tsv` — 3 deliberately wrong expectations
- `model/test/_mutants/gams/always_aborts.gms` — self-contained seed mutant (no includes)
- `model/test/README-negative-controls.md` — schema, append rule, exit-code doctrine, "Why there is a selftest registry"

## Verification (real output)

| # | Command | Result |
|---|---------|--------|
| 1 | `make compile-gams` | `compile-gams: 12 ok, 0 failed, 0 skipped`, rc=0 |
| 2 | `make test-gams` | `test-gams: 4 passed, 0 failed`, rc=0 |
| 3 | `make negative-controls` | `negative-controls: 4 entries, 0 failed`, rc=0 |
| 4 | `make negative-controls REGISTRY=model/test/_mutants/registry.selftest.tsv` | `negative-controls: 3 entries, 3 failed`; **make rc=2**, runner rc=1 (see deviation 4) |
| 5 | `grep -rn 'grep' model/test/negative_controls.py mk/negative-controls.mk` | no output |
| 6 | `git status --short -- 'model/*.gdx'` | empty — no fixture regenerated |
| — | `grep -c '^-include mk/\*\.mk' Makefile` | `1` |
| — | `grep -c "not -path 'test/_mutants/\*'" Makefile` | `1` |
| — | `grep -c '^\.tools/' .gitignore` | `1` |
| — | `awk -F'\t' '!/^#/ && NF{print NF}' registry.tsv \| sort -u` | `5` |
| — | `python3 -c "ast.parse(...)"` on the runner | rc=0 |
| — | `make -n negative-controls` | rc=0, prints `python3 model/test/negative_controls.py` |
| — | bare `make -n` | still runs `compile-gams` (default goal preserved) |

## Decisions Made

See `key-decisions` in the frontmatter. The load-bearing one for later plans: **a registry row
whose command is `make …` must use `expect = nonzero`**, because make collapses every recipe
failure to its own exit status 2.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's own file contents contradicted its acceptance criterion on the token `grep`**
- **Found during:** Task 2
- **Issue:** The runner docstring supplied verbatim by the plan says "No output scraping, no grep", and `mk/negative-controls.mk` says "`grep` must never appear in a conditional position". Task 2's acceptance criterion requires `grep -c 'grep' model/test/negative_controls.py` to print `0`, and verification step 5 requires `grep -rn 'grep'` over both files to produce no output. As written the plan's artifacts could not satisfy the plan's own checks.
- **Fix:** Reworded both comments to say "no pattern-matching on a listing file" / "output-scraping … must never appear in a conditional position". No executable line changed; the predicate is still the exit code only.
- **Files modified:** `model/test/negative_controls.py`, `mk/negative-controls.mk`
- **Verification:** `grep -c 'grep' model/test/negative_controls.py` → `0`; `grep -rn 'grep' model/test/negative_controls.py mk/negative-controls.mk` → no output
- **Committed in:** `1e5a6ca`

**2. [Rule 2 - Missing critical] `.DEFAULT_GOAL := compile-gams` pinned**
- **Found during:** Task 1
- **Issue:** `-include mk/*.mk` is inserted before every rule in the root Makefile. GNU make takes the default goal from the first target of the first rule after include expansion, so `negative-controls` would have silently become the target of a bare `make`. CI names its targets explicitly (`.github/workflows/gams.yml:44,46`) so CI was not at risk, but any human or future script running bare `make` would have been.
- **Fix:** Added `.DEFAULT_GOAL := compile-gams` immediately after the include, with a comment saying why.
- **Files modified:** `Makefile`
- **Verification:** `make -n` still expands the `compile-gams` recipe
- **Committed in:** `434062a`

**3. [Rule 3 - Blocking] `mkdir -p model/build &&` prefixed to the seed GAMS abort row**
- **Found during:** Task 2
- **Issue:** The row runs `gams … o=build/… scrdir=build`, which requires `model/build/` to exist. The plan added that guard to the `nc-runner-empty-registry` row but not to this one, so on a clean checkout the row would have failed for a reason unrelated to its claim (and its exact `expect=3` pin would not have held).
- **Fix:** Row command is now `mkdir -p model/build && cd model && gams …`. `&&` still propagates the gams return code.
- **Files modified:** `model/test/_mutants/registry.tsv`
- **Verification:** row reports `rc=3` as pinned
- **Committed in:** `1e5a6ca`

**4. [Plan factual correction — acceptance criterion met in substance, not in the stated number]**
- **Found during:** Task 3
- **Issue:** Task 3's criterion states that `make negative-controls REGISTRY=model/test/_mutants/registry.selftest.tsv; echo rc=$?` prints `rc=1`. **Measured: it prints `rc=2`.** GNU make reports any recipe failure as its own exit status 2 (`make: *** [mk/negative-controls.mk:11: negative-controls] Error 1` → `make` exits 2). The runner itself exits **1**.
- **Fix:** Not weakened, not papered over. Both measurements are recorded, and the substantive claim — the runner reddens, non-zero, with exactly `3 entries, 3 failed` — is verified directly: `python3 model/test/negative_controls.py model/test/_mutants/registry.selftest.tsv` → `negative-controls: 3 entries, 3 failed`, rc=**1**; through make → rc=**2**. The registry row that consumes the selftest file therefore uses `expect = nonzero`, which is correct rather than lenient: pinning `1` there would be pinning a number make never returns. The rule is documented in `README-negative-controls.md` ("`make` does not propagate the runner's exit code") so later plans do not repeat the error.
- **Files modified:** `model/test/README-negative-controls.md`
- **Committed in:** `1e5a6ca` (README), `6df3dbf` (selftest registry)

---

**Total deviations:** 3 auto-fixed (1 missing-critical, 2 blocking) + 1 recorded factual correction to the plan.
**Impact on plan:** No scope creep. Nothing in the `must_haves` was relaxed; deviations 1 and 4 exist because the plan contradicted itself, and both were resolved in the direction that keeps the check strict.

## Issues Encountered

- **A false-pass mode survives in `nc-runner-selftest-registry` and is NOT closed by this plan.** The row expects `nonzero` from `make negative-controls REGISTRY=…/registry.selftest.tsv`. If `registry.selftest.tsv` were **deleted**, the runner would exit 2 ("registry does not exist") — still non-zero — and the row would still report PASS. Deleting the falsifiability proof therefore keeps `make negative-controls` green. Closing it requires a 5th row (e.g. a `positive` row asserting `test -f model/test/_mutants/registry.selftest.tsv`), which would break this plan's literal `4 entries` acceptance criterion. Logged to `deferred-items.md` for plan 00-02, which appends rows.

## User Setup Required

None — no external service configuration required. `shellcheck` is deliberately not used here; plan 00-02 bootstraps it into the now-ignored `.tools/`.

## Next Phase Readiness

- Plans 00-02, 00-03 and 00-04 can append registry rows and ship `mk/<name>.mk` files without editing the root Makefile or building any mechanism.
- The `12 ok / 4 passed` baselines are intact with the mutants committed, so the exclusions work.
- Carry forward for anyone writing a row: **`expect = nonzero` whenever the command is `make …`**, exact rc otherwise.
- Carry forward for the phase: the two grep-based targets `payoff-fixtures` (Makefile:78 pre-edit) and `spec-preflight` / `spec-preflight-band` are untouched by this plan and still decide failure by scraping a listing that never contains the status line. That is plans 00-02/03/04's work.

## Self-Check: PASSED

All 8 claimed artifacts exist on disk and are tracked by git; all 3 claimed task commits
(`434062a`, `1e5a6ca`, `6df3dbf`) exist on `gsd/phase-0-honest-gates`. All acceptance criteria
across the 3 tasks were verified by running the stated command, with one criterion met in
substance but not in its stated number (deviation 4: `make` exit status 2, runner exit status 1 —
recorded, not weakened).

---
*Phase: 00-honest-gates*
*Completed: 2026-08-15*
