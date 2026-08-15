# TEST-09 — the negative-control registry

Every "X reddens when Y breaks" sentence written anywhere in `.planning/` **must exist here as a
row**. A claim discharged by a mutation someone performed once by hand is unfalsifiable a day
later; a claim discharged by a row in `model/test/_mutants/registry.tsv` re-runs forever.

Run it:

```sh
make negative-controls                                    # the main registry
make negative-controls REGISTRY=<path>                    # any other registry
```

## The predicate is the process exit code, and nothing else

`model/test/negative_controls.py` decides pass/fail by comparing a subprocess **return code** to
the row's `expect` field. It never scrapes output and never pattern-matches a listing file.

This is not a style preference. It is the defect this phase exists to remove: three Makefile
targets (`payoff-fixtures`, `spec-preflight`, `spec-preflight-band`) decided failure by searching
the `o=` listing for `*** Status: (Compilation|Execution) error`. That string is written **only to
the log stream**, never to the listing, at any `lo` value — so those searches match zero lines and
the targets can never go red. Measured against GAMS 54.1: `gams` returns **rc=2** on a compile
error and **rc=3** on an abort. Exit codes are trustworthy; listing scraping is not.

Reading the registry file itself is *input handling*, not a predicate, and is therefore allowed.

## Schema

TSV, one entry per line, **append-only**. `#` starts a comment. Fields are separated by a literal
tab:

```
id <TAB> kind <TAB> expect <TAB> command <TAB> claim
```

| field     | meaning |
|-----------|---------|
| `id`      | unique slug, `[A-Za-z0-9._-]+`. Duplicates are a hard error. |
| `kind`    | `negative` — the command MUST fail; `positive` — it MUST succeed. |
| `expect`  | `nonzero` (valid only on `negative` rows) or an exact integer return code. |
| `command` | `sh` command, executed with cwd = **repository root**. |
| `claim`   | the "X reddens when Y breaks" sentence this row discharges. |

Prefer an **exact** return code over `nonzero` whenever the code is measured and stable: pinning
`3` for a GAMS abort detects a GAMS behaviour change, whereas `nonzero` would absorb it. Use
`nonzero` only when the value is an implementation detail of a wrapper (see below).

### `make` does not propagate the runner's exit code

GNU make reports **any** recipe failure as its own exit status **2**. So a row whose command is
`make negative-controls REGISTRY=...` observes `2`, never the runner's `1`. Such rows must use
`expect = nonzero`. Rows that invoke the runner or `gams` directly should pin the exact code.

## The runner is refusal-first, never vacuously green

`negative_controls.py` exits non-zero — it does not report a green — when the registry

- does not exist,
- contains no entries (an empty registry is a false pass),
- has a line that is not exactly 5 tab-separated fields,
- has a malformed or duplicated `id`,
- has a `kind` other than `negative`/`positive`,
- has an `expect` that is neither `nonzero` nor an integer, or `nonzero` on a `positive` row,
- has an empty command.

A row whose command times out (`NC_TIMEOUT`, default 900s) counts as a **failure**, never a pass.

## Adding a row

1. Commit the mutant, if the claim needs one, under `model/test/_mutants/`. Which subdirectory
   depends on how the row drives it:

   | directory | contents | driven by |
   |-----------|----------|-----------|
   | `gams/` | GAMS units that are **executed** | `gams … action=ce` directly |
   | `gms/` | GAMS units that are only **linted**, never run | `make lint-gams LINT_PATHS=…` |
   | `fixtures/` | the two real payoff `.gdx` **swapped**, so each reference disagrees with its regeneration | `make check-fixtures FIXTURE_DIR=…` |
   | `lean/` | `SorryFixture.lean`, plus `exp/eta.lean` laid out as a drop-in `LEAN4_SPEC_DIR` | `make lean-sorry-check MODULE=…`, `make spec-preflight[-band] LEAN4_SPEC_DIR=…` |

   They are invisible to the build by construction: `compile-gams` excludes `./test/*`,
   `test-gams` excludes `test/_mutants/*`, `lint-gams` excludes the whole `_mutants/` tree from
   both its default `.gms` file set and its `gdx_producer` scan. Do not remove any of those
   exclusions — the units are broken **by design** and would red the suite. `.gitignore` ignores
   `*.gdx`, so the two fixture mutants are allowlisted by an explicit negation; without it the only
   control proving `check-fixtures` can go red would exist on one machine and nowhere else.
2. Append one line to `model/test/_mutants/registry.tsv`. Never edit or reorder an existing line;
   one entry per line keeps concurrent plans from colliding (M7).
3. Run `make negative-controls` and confirm the entry count grew and `0 failed`.

## Why there is a selftest registry

The runner is itself an assertion, and TEST-08's rule applies to it: *an assertion that has never
been observed to fail is not evidence.* A runner that always reports green would make every row
above worthless while looking perfect.

`model/test/_mutants/registry.selftest.tsv` is its mutation proof. Every expectation in that file
is **deliberately wrong** — a `negative` expectation on `true`, a `positive` expectation on
`false`, and an exact-rc expectation of `42` against a command that exits `7` — so running the
runner against it MUST report `3 entries, 3 failed` and exit non-zero.

That proof is not a one-off: the main registry row `nc-runner-selftest-registry` executes it, so
it re-runs on every `make negative-controls`. If `make negative-controls
REGISTRY=model/test/_mutants/registry.selftest.tsv` ever returns 0, the runner has stopped being
able to fail and nothing else in this directory means anything.

The companion row `nc-runner-empty-registry` covers the other direction — the runner must refuse
an emptied registry rather than report a vacuous green.

### …and why one row was not enough (D1, closed by plan 00-02)

`nc-runner-selftest-registry` expects `nonzero`. A **missing** registry also exits non-zero —
`rc=2`, "registry … does not exist" — so the row passed for the wrong reason. Measured before the
fix: `mv model/test/_mutants/registry.selftest.tsv` away, then `make negative-controls` →
**`16 entries, 0 failed`, rc=0**. Deleting the proof that the runner can fail left the whole suite
green. That is the same shape of defect as the listing scrape GATE-01 removed: a check whose
success is indistinguishable from its own absence.

Two `positive` rows close it, and each was observed to fail:

| row | what it pins | observed when violated |
|-----|--------------|------------------------|
| `nc-selftest-file-present` | the proof **exists** | file moved away → `18 entries, 2 failed`, make rc=2 |
| `nc-selftest-entry-count`  | the proof is **intact** — all 3 kinds of wrongness | gutted to 1 row → `nc-selftest-entry-count` FAIL, make rc=2 |

The existing `nc-runner-selftest-registry` row keeps `expect = nonzero` and must not be changed to
an exact code — `make` never returns the runner's `1`.

**The general rule this establishes:** a `negative` row that accepts `nonzero` accepts *every*
reason for failing, including "the artifact under test is gone". Whenever a negative row's command
reads a committed file, pair it with a `positive` row asserting that file is present and intact.

## A row may be RED on purpose — do not make it green

`nc-ci-selftest-positive` (`make ci-selftest`, GATE-06) **fails until a self-hosted runner is
registered on the GAMS build machine**, and `make negative-controls` therefore exits non-zero on
that one row. That is the correct report, not a defect: the `gams` job cannot start without a
runner, so GATE-06 is not met, and the suite says so every time it runs.

Deleting the row, changing its `expect`, or commenting it out would make the suite green by
weakening the check — the one outcome this entire phase exists to prevent. The state is recorded in
`.planning/ci-evidence.md`; when a runner is registered, the row goes green by itself and nothing
here needs editing.
