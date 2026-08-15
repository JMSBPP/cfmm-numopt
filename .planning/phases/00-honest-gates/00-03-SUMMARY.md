---
phase: 00-honest-gates
plan: 03
subsystem: build-gates
tags: [gams, lint, rules-tsv, gate-02, gate-03, gate-04, negative-controls, solvestat]

# Dependency graph
requires:
  - "00-01: `make negative-controls`, the append-only `registry.tsv`, the `-include mk/*.mk` point"
  - "00-02: `make lint-make` (every new recipe is enumerated automatically), the `set -e;` recipe convention, the `expect = nonzero` rule for `make …` rows"
provides:
  - "`make lint-gams` — a DATA-FILE lint over `model/lint/rules.tsv`; a later phase adds coverage by appending a LINE, never by editing code"
  - "`model/lint/lint_gams.py` — the `forbid` / `require_within` engine, refusal-first"
  - "LINT-01..05 (GATE-02 / GATE-04) and LINT-06/07 (GATE-03), each with a committed mutant"
  - "`solveStat` assertions at BOTH `Solve` sites — the real GATE-03 gap, now closed"
  - "`LINT_RULES` / `LINT_PATHS` — the parameterisation that lets a mutant drive the same target"
  - "11 new registry rows (29 total)"
affects: [00-04, phase-1-representation, phase-2-registry, phase-3-degeneracy, phase-8-programs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A lint rule is a ROW in a TSV, not a branch in a script (M7 append-only)"
    - "A `require_within` partner must match inside the assertion's CONDITION — a partner satisfied by a display argument is a false green"
    - "Every rule ships a committed mutant proven to redden it, with its OWN rule id"
    - "A negative row reading a committed artifact is paired with a positive presence+integrity row (D1's rule)"
    - "Prefer an exact rc whenever the command does not go through `make`"

key-files:
  created:
    - mk/lint-gams.mk
    - model/lint/rules.tsv
    - model/lint/lint_gams.py
    - model/lint/README-rules.md
    - model/test/_mutants/gms/abort_noerror.gms
    - model/test/_mutants/gms/bare_execute.gms
    - model/test/_mutants/gms/call_nocheck.gms
    - model/test/_mutants/gms/onmulti.gms
    - model/test/_mutants/gms/execerror_assign.gms
    - model/test/_mutants/gms/solve_no_solvestat.gms
    - model/test/_mutants/gms/solve_no_modelstat.gms
    - model/test/_mutants/gams/band_iterlim0.gms
  modified:
    - model/payoff/eta_pi_trader_band_monotone_large.gms
    - model/payoff/eta_pi_trader_zero_slippage.gms
    - model/test/_mutants/registry.tsv
    - model/test/README-negative-controls.md

key-decisions:
  - "The LINT-06 partner requires `.solveStat` INSIDE the `abort$(...)` condition. Measured both ways on the pre-fix tree: token-anywhere partner → 0 violations, rc=0 (a false green); in-condition partner → 2 violations at band:118 and zero-slip:89. The naive form would have shipped a clean bill of health against two real gaps."
  - "The default file set is a filesystem walk of `model/` (minus `build/` and `test/_mutants/`), not `git ls-files`. The plan specified `git ls-files`, but its own acceptance criterion bans the token `subprocess` from the engine. The walk is strictly stricter — an uncommitted source cannot escape the lint by being untracked — and was verified to yield the identical 16 files."
  - "`nc-gate03-iterlim0-band` pins the exact **rc=3** rather than the plan's `nonzero`: the command invokes `gams` directly and propagates its code, so `nonzero` would absorb an rc=2 (a compile error from a broken `$include` path) — the mutant reddening for the wrong reason."
  - "An 11th row, `nc-lintgams-mutants-present`, was added beyond the plan. D1's rule applies verbatim: the eight `nonzero` rows read COMMITTED mutants, and a deleted mutant also exits non-zero (rc=2, 'does not exist'), so each would have kept passing for the wrong reason. The row was observed to FAIL with a mutant moved away."
  - "LINT-01 is deliberately NOT comment-guarded — it matches `abort.noError` in a comment as well as in code. This is consistent with 00-01's standing decision on the token `grep`: a comment naming the banned idiom is indistinguishable from using it. Disclosed, not hidden: the mutant reports 2 violations, one of them its own header."

patterns-established:
  - "Rule schema: id<TAB>severity<TAB>kind<TAB>pattern<TAB>partner<TAB>window<TAB>message, '#' comments, append-only"
  - "`kind=require_within` is how a MISSING construct is linted; `kind=forbid` is how a banned token is linted"
  - "Lint-only mutants live in `_mutants/gms/`; executed mutants live in `_mutants/gams/`"

requirements-completed: [GATE-02, GATE-03, GATE-04]

# Metrics
duration: 12min
completed: 2026-08-15
---

# Phase 0 Plan 03: The GAMS lint as a data file + the real GATE-03 gap Summary

**`make lint-gams` applies seven rules read from `model/lint/rules.tsv` — a later phase adds
coverage by appending a LINE — and the rule that matters most, LINT-06, was proven to find exactly
the two real `solveStat` gaps before they were closed, where the obvious formulation of the same
rule finds zero.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-08-15T19:59Z
- **Completed:** 2026-08-15T20:11Z
- **Tasks:** 3 (+1 doc repair)
- **Files:** 16 (12 created, 4 modified)

## The rules.tsv column schema as shipped

TSV, one rule per line, append-only, `#` starts a comment, **seven** TAB-separated fields:

```
id <TAB> severity <TAB> kind <TAB> pattern <TAB> partner <TAB> window <TAB> message
```

| field | meaning |
|-------|---------|
| `id` | unique rule id (`LINT-06`); duplicates are a hard error |
| `severity` | `error` (run exits 1) or `warn` (printed, does not fail) |
| `kind` | `forbid` — any line matching `pattern` is a violation; `require_within` — a line matching `pattern` must be followed within `window` FOLLOWING lines by a line matching `partner` |
| `pattern` | Python `re`, `search`ed against each line; inline `(?i)` where case folding is wanted |
| `partner` / `window` | `require_within` only; empty for `forbid` |
| `message` | what the violation means |

`awk -F'\t' '!/^#/ && NF{print NF}' model/lint/rules.tsv | sort -u` → **`7`**.

## The seven rules and the mutant that falsifies each

Every mutant was run individually and observed to redden **with its own rule id**:

| rule | gate | catches | mutant | direct rc | via `make` rc |
|------|------|---------|--------|-----------|---------------|
| LINT-01 | GATE-02 | `abort.noError` — halts silently at rc=0, no status line | `gms/abort_noerror.gms` | 1 | 2 |
| LINT-02 | GATE-04 | a bare `execute` — its failure returns rc=0 | `gms/bare_execute.gms` | 1 | 2 |
| LINT-03 | GATE-04 | `$call` without `$call.checkErrorLevel` | `gms/call_nocheck.gms` | 1 | 2 |
| LINT-04 | GATE-04 | `$onMulti*` — silently REPLACES at rc=0 | `gms/onmulti.gms` | 1 | 2 |
| LINT-05 | GATE-04 | an assignment to `execError` — forges the error state | `gms/execerror_assign.gms` | 1 | 2 |
| LINT-06 | GATE-03 | a `Solve` not asserting `solveStat` in an `abort$()` condition | `gms/solve_no_solvestat.gms` | 1 | 2 |
| LINT-07 | GATE-03 | a `Solve` not asserting `modelStat` in an `abort$()` condition | `gms/solve_no_modelstat.gms` | 1 | 2 |

**`execute` and `$call` are separate rules on purpose.** Measured against GAMS 54.1:
`$onCheckErrorLevel` governs `$call` **only** — with it set, `execute 'false'` still returns rc=0
and execution continues. One rule would have left half of GATE-04 uncovered while looking complete.

`solve_no_solvestat.gms` carries `M.solveStat` in the abort's **display list** and still reddens
LINT-06 — the display-argument trap is proven closed by a committed artifact, not by an argument.

## LINT-06: the measured before/after, and the rule that would have lied

The rule table was appended **before** the sources were fixed, so the violation counts are real
measurements rather than a reconstruction.

### Before the fix — `make lint-gams`, rc=2 (recipe rc=1)

```
model/payoff/eta_pi_trader_band_monotone_large.gms:118: LINT-06 error every Solve must assert solveStat inside an abort$() condition (GATE-03)
    Solve BandMin using nlp minimizing piVal;
model/payoff/eta_pi_trader_zero_slippage.gms:89: LINT-06 error every Solve must assert solveStat inside an abort$() condition (GATE-03)
    Solve ZeroSlip using nlp minimizing piVal;
lint-gams: 16 files, 7 rules, 2 violations
```

### The same rule, written the obvious way — 0 violations, rc=0

Both partners were run against the identical pre-fix tree, each as a one-rule table:

| partner regex | violations | rc |
|---------------|-----------|-----|
| `(?i)\.solveStat\b` — the token anywhere in the 12-line window | **0** | **0** |
| `(?i)abort\$\([^()]*\.solveStat\b` — inside the condition | **2** | **1** |

Both payoff units already *displayed* `.solveStat` in the failure argument list of an `abort$` that
tested only `modelStat`. The token-anywhere rule is satisfied by that display argument: it reports a
clean tree against two real gaps — a check whose success is indistinguishable from its own absence,
which is the exact defect class this phase exists to eliminate, reproduced inside its own remedy.
The contrast is recorded in `model/lint/README-rules.md` so the rule is not "simplified" later.

### Violation counts, before → after

| rule | before | after |
|------|--------|-------|
| LINT-06 (`solveStat`) | **2** | **0** |
| LINT-07 (`modelStat`) | **0** | **0** |

LINT-07 was 0 both times, which is the confirmation that the gap was `solveStat` **only** — both
`Solve`s already asserted `modelStat`, exactly as the plan's GATE-03 correction stated.

## The two assertions inserted

Both go **before** the existing `modelStat` assertion, so the solver-status failure is the one
reported. `#` is the end-of-line comment character in both files (`$eolcom #`).

```gams
Solve BandMin using nlp minimizing piVal;
# GATE-03: solveStat FIRST. modelStat can report an acceptable value while the
# solver terminated abnormally; that combination passes today. Measured:
# %solveStat.normalCompletion% = 1 on GAMS 54.1.
abort$(BandMin.solveStat <> %solveStat.normalCompletion%)
    "FAIL C_min: CONOPT did not terminate normally (solveStat)",
    BandMin.solveStat, BandMin.modelStat;
```

```gams
Solve ZeroSlip using nlp minimizing piVal;
# GATE-03: solveStat FIRST -- see the band unit for the rationale.
abort$(ZeroSlip.solveStat <> %solveStat.normalCompletion%)
    "FAIL: ZeroSlip solver did not terminate normally (solveStat)",
    ZeroSlip.solveStat, ZeroSlip.modelStat;
```

`grep -c 'abort\$(.*\.solveStat <> %solveStat\.normalCompletion%)'` → **1 in each file**.

## Observed `solveStat` / `modelStat` under `option iterlim = 0`

`cd model && gams test/_mutants/gams/band_iterlim0.gms action=ce …` → **rc=3**, and the abort that
fires is the new one:

```
**** SOLVER STATUS     11 Internal Solver Failure
**** MODEL STATUS      5 Locally Infeasible
**** Exec Error at line 279: Execution halted: abort$1 'FAIL C_min: CONOPT did not terminate normally (solveStat)'
```

**solveStat = 11, modelStat = 5.** Both degrade together — which is precisely why this mutant proves
the assertion PAIR is not inert and cannot isolate `solveStat`. `md5sum` of
`model/payoff_band_monotone_large.gdx` is unchanged across the run (the abort halts before
`execute_unload`), and the registry row backs the fixture up and restores it regardless.

## UNVERIFIABLE-LEG (GATE-03) — reproduced verbatim, not upgraded to a claim

> **UNVERIFIABLE-LEG (GATE-03), carried forward, not converted into a check.**
> No committed input is known that provably degrades `solveStat` while leaving `modelStat`
> acceptable — that combination is the hypothesis, not something measured. The `option iterlim = 0`
> mutant proves the assertion PAIR fires; it does not isolate `solveStat`. Coverage is guaranteed by
> the static rule LINT-06, not by the mutant.

It appears as a comment block above LINT-06 in `model/lint/rules.tsv` and above the
`nc-gate03-iterlim0-band` row in `model/test/_mutants/registry.tsv`.
`grep -c UNVERIFIABLE-LEG` → **1** in each file. The measured `solveStat 11 / modelStat 5` above is
the direct evidence for it: the two codes moved together.

## The eleven registry ids added (18 → 29)

| id | kind | expect | observed rc |
|----|------|--------|-------------|
| `nc-lintgams-positive` | positive | 0 | 0 |
| `nc-lintgams-abort-noerror` | negative | nonzero | 2 |
| `nc-lintgams-bare-execute` | negative | nonzero | 2 |
| `nc-lintgams-call-nocheck` | negative | nonzero | 2 |
| `nc-lintgams-onmulti` | negative | nonzero | 2 |
| `nc-lintgams-execerror` | negative | nonzero | 2 |
| `nc-lintgams-solve-no-solvestat` | negative | nonzero | 2 |
| `nc-lintgams-solve-no-modelstat` | negative | nonzero | 2 |
| `nc-lintgams-empty-ruletable` | negative | **2** (exact) | 2 |
| `nc-lintgams-mutants-present` | positive | 0 | 0 |
| `nc-gate03-iterlim0-band` | negative | **3** (exact) | 3 |

`awk -F'\t' '!/^#/ && NF{print NF}' model/test/_mutants/registry.tsv | sort -u` → **`5`** (the
registry schema is unchanged).

## Task Commits

1. **Task 1: the rules.tsv lint harness with the GATE-02/GATE-04 rules** — `ea93da7` (feat)
2. **Task 2: solveStat at both Solve sites + LINT-06/07** — `11ccfe5` (fix)
3. **Task 3: one committed mutant per rule, registered** — `afa597c` (test)
4. **Doc repair: `_mutants/gams` vs `_mutants/gms`** — `d15fc48` (docs)

## Verification (real output)

| # | Command | Result |
|---|---------|--------|
| 1 | `make compile-gams` | `compile-gams: 12 ok, 0 failed, 0 skipped`, rc=0 |
| 2 | `make test-gams` | `test-gams: 4 passed, 0 failed`, rc=0 |
| 3 | `make lint-gams` | `lint-gams: 16 files, 7 rules, 0 violations`, rc=0 |
| 4 | `make lint-make` | `lint-make: 10 recipes, 0 findings`, rc=0 (was 9 — `lint-gams` is inside the enumeration) |
| 5 | `make negative-controls` | `negative-controls: 29 entries, 0 failed`, rc=0 |
| 6 | `grep -c UNVERIFIABLE-LEG model/lint/rules.tsv model/test/_mutants/registry.tsv` | `1` and `1` |
| 7 | `git status --short` | only the two pre-existing unrelated edits (`ROADMAP.md`, `config.json`); no `model/*.gdx` diff |
| — | `awk -F'\t' '!/^#/ && NF{print NF}' model/lint/rules.tsv \| sort -u` | `7` |
| — | `awk -F'\t' '!/^#/ && NF{print NF}' model/test/_mutants/registry.tsv \| sort -u` | `5` |
| — | `make lint-gams LINT_PATHS=model/PricingKernel.gms` | `1 files, 5 rules, 0 violations`, rc=0 |
| — | `python3 model/lint/lint_gams.py --rules /dev/null` | `rule table '/dev/null' is empty - an empty rule table is a false pass, not a pass`, rc=**2** |
| — | `python3 model/lint/lint_gams.py --rules model/lint/nosuch.tsv` | `does not exist`, rc=2 |
| — | `python3 model/lint/lint_gams.py --rules model/lint/rules.tsv model/nosuch.gms` | `'model/nosuch.gms' does not exist`, rc=2 |
| — | `grep -c 'subprocess' model/lint/lint_gams.py` | `0` |
| — | `ls model/test/_mutants/gms/*.gms \| wc -l` | `7` |
| — | each mutant run individually | rc=1, one violation, its own rule id (LINT-01 reports 2 — see disclosure) |
| — | `grep -c 'abort\$(.*\.solveStat <> %solveStat\.normalCompletion%)'` on both units | `1`, `1` |
| — | `cd model && gams test/_mutants/gams/band_iterlim0.gms action=ce …` | rc=**3**, solveStat 11 / modelStat 5, `md5sum` of the band fixture unchanged |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's file-set specification contradicted its own acceptance criterion**

- **Found during:** Task 1
- **Issue:** Step 3 specifies the default file set as `git ls-files 'model/*.gms' 'model/**/*.gms'`.
  The same task's acceptance criterion requires `grep -c 'subprocess' model/lint/lint_gams.py` to
  print `0`. Shelling out to `git` from Python requires exactly that module; the plan could not
  satisfy both.
- **Fix:** `default_files()` is an `os.walk` of `model/` excluding `model/build/` and
  `model/test/_mutants/`. This is **stricter**, not weaker: a `.gms` written but not yet committed
  is still a source and cannot escape the lint by being untracked.
- **Verification:** the walk and `git ls-files` (minus the same two prefixes) yield the **identical
  16 files**, measured. `grep -c 'subprocess' model/lint/lint_gams.py` → `0`.
- **Committed in:** `ea93da7`

**2. [Rule 1 - Bug] The empty-rule-table refusal reported the wrong reason for `/dev/null`**

- **Found during:** Task 1
- **Issue:** the guard used `os.path.isfile`, which is **False** for `/dev/null` (a character
  device). The refusal fired with the right exit code (2) but the message read *"rule table
  '/dev/null' does not exist"* — a correct gate telling the operator a false story, and one that
  would have masked a genuinely missing rule table behind an unrelated diagnosis.
- **Fix:** `os.path.exists`, so the file is opened and parsed and the refusal names the real reason.
- **Verification:** `rule table '/dev/null' is empty - an empty rule table is a false pass, not a
  pass`, rc=2; a genuinely absent path still reports `does not exist`, rc=2.
- **Committed in:** `ea93da7`

**3. [Rule 2 - Missing critical] D1's rule was not applied to this plan's own rows — an 11th row was added**

- **Found during:** Task 3
- **Issue:** eight of the new rows are `negative`/`nonzero` and their commands read **committed
  mutants**. Reproduced: with `gms/onmulti.gms` moved away,
  `make lint-gams LINT_PATHS=model/test/_mutants/gms/onmulti.gms` exits **2** ("does not exist") and
  the row would still have reported PASS. Deleting the mutants would therefore have left
  `make negative-controls` green with every GATE-02/04 proof gone — the identical shape of defect as
  D1, which 00-02 closed for the runner's own selftest and recorded as a general rule.
- **Fix:** `nc-lintgams-mutants-present` (`positive`, expect 0) asserts both **presence** (7 files)
  and **integrity** (all seven `LINT-0[1-7]` ids still named across them).
- **Verification:** observed to **FAIL** (rc=1) with one mutant moved away, and to pass (rc=0) with
  it restored. The row is not accepted on its author's word.
- **Committed in:** `afa597c`

**4. [Rule 2 - Missing critical] `_mutants/gams/` and `_mutants/gms/` were indistinguishable in the registry README**

- **Found during:** Task 3
- **Issue:** `README-negative-controls.md` said "GAMS units go in `model/test/_mutants/gams/`". This
  plan adds `model/test/_mutants/gms/` with a different contract (linted, never executed). The two
  names differ by one character and the README gave no way to choose.
- **Fix:** the "Adding a row" step now distinguishes executed units (`gams/`) from lint-only units
  (`gms/`, driven through `LINT_PATHS`).
- **Committed in:** `d15fc48`

### Plan factual corrections — recorded, not weakened

**5. Task 2's criterion `grep -c 'solveStat.normalCompletion' <both units>` prints `1` for each file. Measured: `2` for the band unit, `1` for the zero-slippage unit.**

- **Cause:** the comment block the plan itself mandates above the band assertion contains the line
  `# %solveStat.normalCompletion% = 1 on GAMS 54.1.`, so the token occurs twice — once in the
  comment that records the measurement, once in the assertion. The zero-slippage comment does not
  quote the macro, hence `1` there.
- **Resolution:** nothing was reworded to make the count come out at 1 — that would be gaming a
  token count and would delete a measured fact from the source. The substantive claim was verified
  directly and more strictly: `grep -c 'abort\$(.*\.solveStat <> %solveStat\.normalCompletion%)'`
  → **`1` in each file**, i.e. exactly one `solveStat` **assertion** per `Solve`. The `must_haves`
  artifact requirement (`contains: solveStat.normalCompletion`) is satisfied by both files.

**6. Task 3's criterion `negative-controls: 26 entries, 0 failed`. Measured: `29 entries, 0 failed`.**

- **Cause:** arithmetic. The registry carried **18** rows at the end of 00-02 (00-02's own summary
  records `18 entries`), and this plan's own action list adds **10**, which is 28 — `26` is not
  reachable from any reading of the plan. The 29th is deviation 3's D1 row.
- **Resolution:** the substantive criterion — every row passes, nothing was skipped, the count grew
  by exactly the rows added — is met: `29 entries, 0 failed`, rc=0, with all 11 new ids listed above
  and their observed return codes recorded.

### Strengthenings beyond the plan

**7. `nc-gate03-iterlim0-band` pins the exact `rc=3` instead of the plan's `nonzero`.** The command
invokes `gams` directly and ends `exit $rc`, so the exact code is observable and stable (measured 3,
matching the seed abort row). `nonzero` would absorb an **rc=2** — a compile error from, say, a
broken `$include` path — and the row would go on passing while proving nothing about the GATE-03
assertions. That is the D1 failure mode in miniature, and the exact pin closes it.

**8. `nc-lintgams-empty-ruletable` pins the exact `rc=2`** (per 00-02 strengthening 6: the command
invokes `lint_gams.py` directly, not through `make`), so a future internal error that also exits
non-zero cannot be absorbed.

---

**Total:** 4 auto-fixed (1 bug, 2 missing-critical, 1 blocking), 2 recorded factual corrections to
the plan, 2 strengthenings.
**Impact on plan:** No scope creep and nothing in `must_haves` relaxed. Every deviation moves in the
strict direction. Both factual corrections exist because the plan restated a number its own
artifacts do not produce — the third and fourth instances of that pattern in this phase.

## Issues Encountered

- **LINT-01 matches its own mutant's header comment**, so `gms/abort_noerror.gms` reports **2**
  violations rather than 1. The pattern `(?i)\babort\.noError\b` is not anchored and carries no
  `[^*#]*` comment guard, unlike LINT-02 and LINT-05. This is deliberate and consistent with 00-01's
  standing decision on the token `grep` — a comment naming the banned idiom is indistinguishable
  from using it — and it is fail-closed. It is disclosed here rather than silently smoothed over,
  because it means a future source cannot *document* `abort.noError` without reddening the lint.
- **`LINT-02`/`LINT-05`'s `^[^*#]*` guard is line-position-based, not lexical.** It relies on `*` in
  column 1 and `#` (the `$eolcom` character in the payoff units) starting a comment. A source using
  a different `$eolcom` character, or `$onText`/`$offText` blocks, would not be guarded the same
  way. No such source exists in the tree today (measured: 0 violations across 16 files).
- **`model/build/lint-make/probe-sc.sh`** still sits in the gitignored build directory from 00-02's
  throwaway probe. It is not in the live enumeration (`lint-make` counts 10 recipes, not 11) and is
  regenerated output, so it is left alone.
- **`gsd-tools state advance-plan` and `roadmap update-plan-progress` were NOT used** — they are
  recorded in STATE.md's Blockers as damaging these files. `STATE.md` and `ROADMAP.md` were edited
  by hand and the diffs inspected before committing.

## User Setup Required

None. `make lint-gams` needs only `python3`. A CI job adding it needs no bootstrap (unlike
`lint-make`, which requires `make tools-shellcheck` first).

## Next Phase Readiness

- **GATE-02 and GATE-04 are met.** Five `forbid` rules cover every measured silent-failure idiom,
  `execute` and `$call` are covered separately because `$onCheckErrorLevel` governs `$call` only,
  and each rule ships a committed mutant that reddens on every `negative-controls` run.
- **GATE-03 is met on both legs.** (a) The `option iterlim = 0` mutant reddens (rc=3, solveStat 11 /
  modelStat 5) and is registered; (b) LINT-06/07 redden any `Solve` that does not assert both status
  codes inside an `abort$()` condition. The UNVERIFIABLE-LEG is recorded in two files, not converted
  into a claim.
- **Later phases extend the lint by appending a LINE to `model/lint/rules.tsv`.** Phase 2's PROG-00
  certificate lint and VOL-0B provenance lint are `require_within` rules over `Solve` — the same
  shape as LINT-06, so they are rows, not code. Each must ship a mutant in `_mutants/gms/` and a row
  in `registry.tsv`; `model/lint/README-rules.md` states that requirement.
- **Carry forward, unchanged:** `expect = nonzero` whenever a row's command is `make …`, exact rc
  otherwise; and whenever a negative row reads a committed artifact, pair it with a positive
  presence+integrity row.
- **Carry forward, new:** when a rule keys on the *absence* of something, verify the partner is not
  satisfied by a cosmetic occurrence of the token. Write the mutant so it contains the token in the
  wrong place (as `solve_no_solvestat.gms` does) and confirm the rule still fires.
- **00-04 is unblocked** — it owns the Lean leg (`lean_sorry_check.sh`, whose 0/1/2/3 contract 00-02
  fixed) and touches none of this plan's files.

## Self-Check: PASSED

All 12 claimed created files and 4 modified files exist on disk and are tracked by git. All 4
claimed commits (`ea93da7`, `11ccfe5`, `afa597c`, `d15fc48`) exist on `gsd/phase-0-honest-gates`.
Every acceptance criterion across the 3 tasks was verified by running the stated command and
recording its real output, with two criteria met in substance but not in their stated number
(deviations 5 and 6, both recorded with the measurement that contradicts them and with a stricter
substitute check). The five gates re-ran green at the end: `12 ok, 0 failed, 0 skipped` /
`4 passed, 0 failed` / `16 files, 7 rules, 0 violations` / `10 recipes, 0 findings` /
`29 entries, 0 failed`, and `git status --short` shows no modification to any `model/*.gdx`.

---
*Phase: 00-honest-gates*
*Completed: 2026-08-15*
