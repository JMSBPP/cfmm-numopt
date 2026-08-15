# Knowingly unversioned GDX fixtures (GATE-05's honest scope)

## The decision

**`model/price_impact_kernel.gdx` is recorded as knowingly unversioned. No producer is
funded.** This is a user decision taken during Phase 0 and it is not a finding to be
"fixed" later by whoever next reads `make check-fixtures` and notices the file is not
covered.

## The measured facts behind it

- `model/PriceImpactKernelFixture.gms:28` **does** contain
  `execute_unload 'price_impact_kernel.gdx', priceImpact, Lbar, dxVal, gamsVersion,
  etaWeight, lambdaVal;`. **A producer exists in source form.**
- That file is wired into **no make target**. `payoff-fixtures` globs only
  `payoff/eta_*.gms`; `compile-gams` syntax-checks `PriceImpactKernelFixture.gms` with
  `action=c` (it never executes it) and `test-gams` deliberately never runs it at all
  (the file lives at `model/` root rather than under `model/test/` for exactly that
  reason — see its own header comment).
- So the accurate wording is **"a producer exists but is unwired"**, not "no producer
  exists". Nothing regenerates this file as part of any build.
- Byte- or content-reproduction of the committed `model/price_impact_kernel.gdx` from
  that source has **not** been established. Its own header claims that re-running
  produces different bytes (a GAMS build timestamp in the GDX header); that claim was
  **not reproduced** for the two payoff fixtures, and it has **not been tested** for this
  one.
- Funding a producer — wiring the fixture into a target, establishing content
  reproducibility, and registering it — **was declined**. It is out of scope for Phase 0.

## The consequence

`model/price_impact_kernel.gdx` is **outside GATE-05's scope**. `make check-fixtures`
covers exactly the **two** payoff fixtures that `payoff-fixtures` can actually produce,
as declared in `model/fixtures/FIXTURES.tsv`. Nothing in this repository checks that
`model/price_impact_kernel.gdx` is fresh, and no criterion may be read as claiming
otherwise.

## The standing rule (enforced by LINT-08)

Any **new** committed `.gdx` must either

1. be declared in `model/fixtures/FIXTURES.tsv` **with a wired producer** — a `.gms` that
   a named make target actually executes — or
2. be added to the list below, which is an explicit admission that it is not checked.

`LINT-08` (`model/lint/rules.tsv`, `kind=gdx_producer`) reddens `make lint-gams` for any
`.gdx` that is in neither place. Adding a line here is deliberately cheap and
deliberately loud: the file says, in the repository, that nobody is checking it.

Scope note: the scan excludes `model/build/` (generated) and `model/test/_mutants/`
(deliberately broken by design), so the swapped stale-fixture mutants under
`model/test/_mutants/fixtures/` need no declaration and must never be given one.

## The list

- `price_impact_kernel.gdx` — no regeneration path is wired; producer deliberately not funded (user decision, Phase 0).
