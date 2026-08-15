# TEST-09 stale-fixture mutants (GATE-05)

These two `.gdx` files are the **two real payoff fixtures, SWAPPED**:

| file here | is byte-for-byte | md5 |
|-----------|------------------|-----|
| `payoff_zero_slippage.gdx` | `model/payoff_band_monotone_large.gdx` | `12869d29c1da30f1ed3e577a33a888f7` |
| `payoff_band_monotone_large.gdx` | `model/payoff_zero_slippage.gdx` | `ec318d2bff86224eb9ced3dd6e0bcfe1` |

So each *reference* disagrees with its own regeneration **by construction** — measured:
`gdxdiff` between the two real fixtures returns **rc=1** (differences found). That is what
makes them a usable stale-fixture control:

```sh
make check-fixtures FIXTURE_DIR=model/test/_mutants/fixtures    # must print two STALE lines and fail
```

`FIXTURE_DIR` supplies only the **reference** copies, so this run never writes into
`model/` — `check-fixtures` snapshots and restores the working-tree fixtures regardless.

**They are not real fixtures and must never be treated as such.** Nothing may copy them
into `model/`, and no producer regenerates them. They are excluded from `make lint-gams`'s
`gdx_producer` scan (LINT-08) along with the rest of `model/test/_mutants/`, so they need
no entry in `model/fixtures/FIXTURES.tsv` or `model/fixtures/UNVERSIONED.md` and must not
be given one.

`.gitignore` ignores `*.gdx` by default; these two are allowlisted by an explicit negation
placed after that rule, exactly like the three real fixtures.

The registry row `nc-checkfixtures-mutants-present` asserts both that these files exist and
that they are still the *swapped* pair — deleting or "repairing" them would otherwise leave
`nc-checkfixtures-stale` passing for the wrong reason (D1's rule: a `negative` row accepts
every reason for failing, including "the artifact under test is gone").
