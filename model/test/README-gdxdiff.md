# `gdxdiff` — the measured return-code table, and what `check-fixtures` conflates

`make check-fixtures` (GATE-05) decides *stale vs fresh* with **`gdxdiff`'s exit code
only**, never by reading its output. This file records what those codes actually are,
measured against the `gdxdiff` shipped with **GAMS 54.1**
(`/usr/gams/gams54.1_linux_x64_64_sfx/gdxdiff`), and the two traps found while
measuring them.

## The table

| rc | meaning | measured how |
|----|---------|--------------|
| 0 | no differences | `gdxdiff a.gdx a2.gdx` — two copies of `model/payoff_zero_slippage.gdx` |
| 1 | differences found | `gdxdiff payoff_zero_slippage.gdx payoff_band_monotone_large.gdx` |
| 2 | no arguments | `gdxdiff` with no args |
| 3 | a named input file is missing | `gdxdiff a.gdx nonexistent.gdx` |
| 7 | output rename failed | the **3-argument** form with the output path on another filesystem — see below |

Five rows, not four. The roadmap's four-row table omitted `rc=7`, which is the one that
can make the target lie.

## Trap 1 — the 3-argument form conflates identical with different

`gdxdiff A B out.gdx` writes its diff to a temporary file beside the inputs and then
**renames** it to `out.gdx`. When that rename cannot happen — the classic case being an
output path on a different filesystem — gdxdiff returns **7**, and it returns 7 for
**identical and for different inputs alike**. Measured from `model/` (ext4) with the
output on `/tmp` (tmpfs):

```
$ gdxdiff payoff_zero_slippage.gdx payoff_zero_slippage.gdx      /tmp/out_ident.gdx ; echo $?
7
$ gdxdiff payoff_zero_slippage.gdx payoff_band_monotone_large.gdx /tmp/out_diff.gdx  ; echo $?
7
```

A `check-fixtures` written on the 3-argument form would therefore have reported every
fixture STALE forever (fail-closed, but for the wrong reason) or, with the predicate
written the other way round, every fixture FRESH forever. **`check-fixtures` uses the
2-argument form.**

That failed run also leaves `tmpdifffile1.gdx`, `tmpdifffile2.gdx`, … beside the inputs
— i.e. inside `model/` — which is untracked litter in the working tree.

## Trap 2 — gdxdiff writes into the current directory

In the 2-argument form gdxdiff drops its diff at **`diffile.gdx` in the current working
directory**. `check-fixtures` therefore `cd`s into a scratch directory
(`model/build/fixtures/`, gitignored) before comparing, so nothing lands in `model/`.

## The predicate, and what it conflates

```
gdxdiff ref_<name> new_<name>   →  rc == 0  FRESH
                                →  rc != 0  STALE
```

`rc != 0` is deliberately conservative and it **conflates a genuinely stale fixture
(rc=1) with harness misuse (rc=2 no args, rc=3 a missing input, rc=7 a rename failure)**.
That is a chosen trade: every one of those states is a reason to stop, and none of them
may be reported as FRESH. The cost is that the STALE line does not by itself tell you
which of the four it was — the per-fixture `diff_<name>.log` in the scratch directory
does.

The registry row `nc-checkfixtures-missing`
(`make check-fixtures FIXTURE_DIR=/nonexistent`) exists precisely because a missing
reference must fail loudly rather than be silently skipped.

## Fixture regeneration is content-stable (measured)

Both committed payoff fixtures regenerate **byte-identically** — recorded in
`00-02-SUMMARY.md` by `md5sum` and re-confirmed here by `gdxdiff` rc=0 through
`make check-fixtures`. The determinism note in the header of
`model/PriceImpactKernelFixture.gms` ("re-running produces DIFFERENT bytes — GAMS embeds
a build timestamp") was **not** reproduced for the two payoff units. `check-fixtures`
compares *content* with `gdxdiff` rather than bytes, so the target does not depend on
that either way.
