# `model/lint/rules.tsv` — the GAMS source lint is a data file

`make lint-gams` applies the rules in `model/lint/rules.tsv` to every `*.gms`
under `model/`. **A later phase adds coverage by appending a LINE to that file,
never by editing `model/lint/lint_gams.py`.** That is the M7 append-only
substrate: two concurrent plans adding a rule each touch a different line of one
file, and neither has to reason about the other's control flow.

```sh
make lint-gams                                     # the committed rules, the default file set
make lint-gams LINT_PATHS=path/to/one.gms          # scan exactly these files (how the mutants run)
make lint-gams LINT_RULES=path/to/other.tsv        # apply a different rule table
```

## Column schema

TSV, one rule per line, **seven** TAB-separated fields. `#` in the first
non-space column starts a comment; blank lines are ignored.

```
id <TAB> severity <TAB> kind <TAB> pattern <TAB> partner <TAB> window <TAB> message
```

| field      | meaning |
|------------|---------|
| `id`       | unique rule id, e.g. `LINT-06`. Duplicates are a hard error. |
| `severity` | `error` (the run exits 1) or `warn` (printed, does not fail). |
| `kind`     | `forbid`, `require_within` or `gdx_producer` (below). |
| `pattern`  | Python `re` syntax, matched against each source line with `search`. Use an inline `(?i)` where case folding is wanted — GAMS keywords are case-insensitive. |
| `partner`  | `require_within` only; empty for `forbid`. |
| `window`   | `require_within` only; a positive integer count of FOLLOWING lines. Empty for `forbid`. |
| `message`  | what the violation means and why it matters. |

## The three kinds

**`forbid`** — every line matching `pattern` is a violation. This covers the
silent-failure *tokens*: `abort.noError`, a bare `execute`, an unchecked
`$call`, `$onMulti*`, an assignment to `execError`.

**`require_within`** — a line matching `pattern` must be followed, within
`window` following lines, by a line matching `partner`. This covers a *missing*
construct, which is what GATE-03 actually is: a `Solve` whose status codes are
never tested.

**`gdx_producer`** (added by plan 00-04, GATE-05) — the only kind that does not
scan source lines at all. Every `.gdx` in the tree must be **declared**: either in
column 1 of `model/fixtures/FIXTURES.tsv`, which means it has a **wired**
producer (a `.gms` some make target actually executes), or inside backticks in
`model/fixtures/UNVERSIONED.md`, which means it is knowingly unchecked. Anything
in neither place is a violation, reported at that path, line 0.

`pattern`, `partner` and `window` must all be **empty** for this kind — a
non-empty one is a hard error, because it would mean the rule's author expected
line matching that never happens.

The `.gdx` scan is a **filesystem walk** of the repository (minus `.git`,
`.tools`, `lean4-spec`, `model/build/` and `model/test/_mutants/`), for the same
reason `default_files()` is: `git ls-files` would require `subprocess`, which this
engine deliberately does not import, and a walk is **stricter** — an uncommitted
`.gdx` dropped into the tree cannot escape the declaration requirement by being
untracked. Measured: the walk finds the same three files as
`git ls-files '*.gdx'`.

Both declaration files must exist; a missing one is refused (exit 2) rather than
read as "nothing is declared", which would redden every fixture for the wrong
reason.

### The partner must look inside the condition

`LINT-06`'s partner is `(?i)abort\$\([^()]*\.solveStat\b` — the status symbol
must appear inside the `abort$(...)` **condition**. This is not a stylistic
choice, it is the whole point of the rule, and it is measured:

| partner shape | violations found on the pre-GATE-03 tree |
|---------------|------------------------------------------|
| the token `.solveStat` anywhere in the window | **0** |
| `abort\$\([^()]*\.solveStat\b` | **2** |

Both payoff units already *displayed* `.solveStat` in the failure argument list
of an `abort$` that tested only `modelStat`. A rule keyed on the token alone
would have reported a clean tree against two real gaps — a check whose success
is indistinguishable from its own absence, which is the defect class this phase
exists to remove.

## Every rule ships a mutant

**A new rule is not done until `model/test/_mutants/registry.tsv` carries a row
that reddens it.** A rule that has never been observed to match is not evidence
that the tree is clean; it is equally consistent with a regex that stopped
matching. Add the mutant under `model/test/_mutants/gms/` (lint-only mutants,
never executed by GAMS) and register it:

```
nc-lintgams-<slug>	negative	nonzero	make lint-gams LINT_PATHS=model/test/_mutants/gms/<file>.gms	<what the rule catches>
```

`expect = nonzero`, never an exact code, whenever the command is `make …`: GNU
make collapses every recipe failure to its own exit status 2.

The mutants live under `model/test/_mutants/`, which the default file set
excludes, so committing a deliberately-broken source does not redden
`make lint-gams`.

## Measured facts these rules encode

- `abort.noError$(...)` halts at **rc=0** with no status line.
- A failing `execute 'cmd'` returns **rc=0**, and so does a failing `$call`.
- **`$onCheckErrorLevel` governs `$call` ONLY.** Measured against GAMS 54.1:
  `$onCheckErrorLevel` together with `execute 'false'` gives rc=0 and execution
  continues. `execute` and `$call` therefore need SEPARATE rules — LINT-02 and
  LINT-03 — and one is not a substitute for the other.
- `$onMultiR` silently **replaces** a symbol at rc=0.
- `LINT-02` requires whitespace immediately after `execute`, so `execute_unload`,
  `execute_load`, `execute_loadDC` and `execute.checkErrorLevel` are not matched.
  Measured: the tree has 3 `execute_unload` sites and 0 violations.

## The engine refuses a vacuous green

`lint_gams.py` exits **2** — it does not print a green — when

- the rule table does not exist, is empty, or has a line that is not exactly 7
  TAB-separated fields,
- a rule has a duplicate id, an unknown `kind` or `severity`, an uncompilable
  regex, a `forbid` carrying a partner/window, or a `require_within` missing one,
- an explicitly named path does not exist,
- the file set is empty.

An empty rule table applied to an empty file set would otherwise report
`0 violations` and exit 0 — a perfect score for having checked nothing.
