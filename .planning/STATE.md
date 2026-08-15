# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-27)

**Core value:** Every geometric primitive carries a Lean-coordinate evaluator, an EVM-coordinate fixed-point evaluator, and an executable assertion that the two agree under a documented coordinate bridge.
**What the project is for (rev 4):** The GAMS layer **solves** the convex programs implied by `VOLATILITY_INSTRUMENTS.md` — programs `cfmm-lean4-spec` formalizes and Plank implements on-chain. The representation kernel is the **substrate that makes a solved parameter EVM-expressible**, not a parallel track. **Non-degenerate first**: three attained programs are solved (M5, M6a levels, M6b), the unattained shape block is asserted only.
**Second deliverable (rev 5):** `Shocks → VolumePath[]` — GAMS generates a length-`N` swap path realizing a target fee revenue and emits it as exact-integer JSON for on-chain replay. Filed as **Phases 10–11**, not a new milestone: v1.0 has shipped nothing, and the two scopes share REPR-10's exact Q96 table, `priceImpactKernel_Add0`, TEST-02's tolerance rule and GATE-05.
**Current focus:** Phase 0 — Honest gates

## Current Position

Phase: 0 of 11 (Honest gates)
Plan: 1 of 4 in current phase (00-01 complete)
Status: In progress — negative-control substrate landed; 00-02/03/04 pending
Last activity: 2026-08-15 — 00-01 executed on `gsd/phase-0-honest-gates`: `make negative-controls`, the `_mutants/` tree, the append-only registry, and the `-include mk/*.mk` point

Progress: [░░░░░░░░░░] 2% (1/54 plans; Phase 9 plan count TBD)

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 6 min
- Total execution time: 0.1 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| Phase 00 P01 | 1 | 6 min (3 tasks, 8 files) | 6 min |

**Recent Trend:**
- Last 5 plans: 00-01 (6 min)
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Decisions taken during roadmapping (later revs
supersede earlier ones where they differ):

- [Phase 0, plan 00-01]: **A registry row whose command is `make …` must use
  `expect = nonzero`, never an exact code.** Measured: GNU make reports *any* recipe failure as
  its own exit status **2**, so `negative_controls.py`'s exit 1 is never observable through
  `make`. Rows that invoke `gams` or the runner directly pin the exact code (the seed abort row
  pins **rc=3**, re-confirming the binding fact). This corrects plan 00-01's task-3 acceptance
  criterion, which stated `rc=1` for a `make` invocation.
- [Phase 0, plan 00-01]: **`.DEFAULT_GOAL := compile-gams` is pinned in the root Makefile.**
  `-include mk/*.mk` sits before every rule, so without the pin the first target of the first
  included `mk/*.mk` silently becomes the goal of a bare `make`. Any later plan adding an
  `mk/<name>.mk` inherits this protection and must not remove it.
- [Phase 0, plan 00-01]: **`test-gams` excludes `test/_mutants/*`** (`find test -name '*.gms'
  -not -path 'test/_mutants/*'`). `compile-gams` needed no change — it already excludes
  `./test/*`. Removing either exclusion reds the suite by design, since `_mutants/` units are
  deliberately broken.
- [Phase 0, plan 00-01]: **The word `grep` does not appear in `negative_controls.py` or
  `mk/negative-controls.mk` at all, not even in a comment** — the acceptance check for the
  banned idiom is a token search over those files, and a comment naming the idiom is
  indistinguishable from using it.

- [Roadmap rev 5]: **The volume-path work is Phases 10–11, not a new milestone.** GSD's
  `new-milestone` presumes a shipped predecessor and v1.0 has shipped nothing (0/54 plans, no
  `MILESTONES.md`); it would have orphaned v1.0 and overwritten the uncommitted rev-4 file. The
  scopes are also coupled — VPATH-13 shares REPR-10's exact Q96 table, VPATH-01 reuses
  `priceImpactKernel_Add0`, VPATH-11 uses TEST-02's tolerance rule, VPATH-09/13 ride on GATE-05.
- [Roadmap rev 5]: **Two VPATH phases, cut at a measured representational cliff.** Above it
  (Phase 10) everything lives in GAMS doubles and tick space; below it (Phase 11) everything must
  be exact integers, because at Q96 magnitude the double spacing is `2^44`, `2^96` emits as
  `7.922816251426434000E+28` and `12345678901234567` emits as `...568`, silently. One phase would
  state half its criteria in a number system the other half cannot represent; three or four would
  produce "a file exists" criteria.
- [Roadmap rev 5]: **REPR-10's replica is DATA, not GAMS code — corrected by VPATH-13's
  measurement.** Rev 4 specified `TickMathReplica.gms` implementing the EVM's integer/bit
  sequence in GAMS. That is not implementable: a GAMS-computed replica is limited by the same
  53-bit mantissa it is meant to check — common-mode one level down. The reference is a committed
  exact `tick → sqrtPriceX96` table generated outside GAMS. **REPR-10 and VPATH-13 share it:
  built in Phase 1, consumed in Phase 11.**
- [Roadmap rev 5]: **PROG-04 DEMOTED from SOLVE to ASSERT-ONLY.** PROG-00 was corrected — strict
  convexity gives uniqueness *given* existence, not existence (`exp` on ℝ is strictly convex and
  attains no infimum). `ptrade_strictConvexOn`/`ptrade_strictAntiOn` are proven but existence over
  the equal-income level set is uncertified. **Phase 8 therefore enters with exactly TWO solvable
  programs** — a zero-margin position, which is why N5's phase-level INVALIDATED clause exists.
- [Roadmap rev 5]: **VOL-11 → Phase 8's first plan; VOL-12 → Phase 7; PROG-07 → Phase 8 with
  VOL-11.** VOL-11 depends on VOL-10 so it cannot precede Phase 8, and PROG-01/04/06 rest on it so
  it must precede the programs. VOL-12 is a leaf with no PROG consumer — 34 theorems in the
  deliverable phase would dilute it.
- [Roadmap rev 5]: **Phases 10–11 are edge-unblocked after Phase 2** and depend on nothing in
  Phases 3–9. They are scheduled last anyway: the parallel set is already three phases wide.
  Recorded so the choice is deliberate rather than discovered.

- [Roadmap rev 4]: **REFRAMING — GAMS solves the convex programs; it does not only verify
  theorems.** Three layers: `cfmm-lean4-spec` formalizes, **this repo solves**, Plank
  implements on-chain. Two consequences. (a) Phases 0/1/2 are the **substrate that makes a
  solved parameter EVM-expressible** — the ordering is *validated*, but the roadmap now says
  why those phases exist, and **PROG-05** makes it a requirement: a solution outside what Plank
  can represent **FAILS**, it is not rounded into range. (b) **Non-degenerate first** — M5,
  M6a's level block and M6b are solved (extremum attained); M6a's **shape block is asserted
  only** (unbounded, β → −∞ saturation boundary, no maximum) and deferred until lean4-spec
  constrains it.
- [Roadmap rev 4]: **VOL-10 (`FlairOptimization`, 15 thm, 0 sorry) promoted from v2 to v1.**
  The old FLAIR-01 deferral was topologically right and functionally backwards: it imports
  *from* `VolInstrument`, but it is **where the solved programs live** (cited by name at
  VOLATILITY_INSTRUMENTS.md:459). Downstream in the import graph does not mean lower priority
  when the deliverable is solving.
- [Roadmap rev 4]: **VOL-10 and PROG-01..06 collapse into ONE new Phase 8**, not two. The
  programs cite the module's theorems by name, so nothing can be solved before it is ported,
  and a port-only phase would deliver "15 more theorems green" — a horizontal layer. The
  stopping power of a separate phase is preserved *inside* it: plan 08-01 is a **census** of
  all six cited theorems (not a 10-of-134 sample), and any theorem whose intended use is
  stronger than its conclusion stops the corresponding program.
- [Roadmap rev 4]: **PROG-00 → Phase 2**, with VOL-00 and VOL-0B — a third `registry.tsv`
  column (`certificate`) plus a lint reddening a `Solve` with a blank cell. Same mechanism,
  same file, and a pre-Phase-8 consumer in Phase 3's SOLVE-04a/04b, which is precisely a
  certificate question. **PROG-06 → Phase 8's second plan**, ahead of the solves it gates and
  checkable by finite differences with no solver. **PROG-05 → Phase 8**; its
  `assertEvmExpressible` macro ships in Phase 2 as a consumer relation.
- [Roadmap rev 4]: **IDENT-01 renumbered to Phase 9 and deliberately NOT promoted.** Making
  solving the deliverable is a superficial argument for pulling degeneracy work forward;
  the instruction behind the reframing was *non-degenerate first*.
- [Roadmap rev 4]: **The verification port (VOL-01..09) is retained, not deleted** — it is the
  substrate the solve rests on. It is simply no longer the endpoint. Phases 5–7 carried no
  optimization; only Phase 3 contained a `Solve` at all.

- [Roadmap rev 3]: **The port must declare where its parameters come from (VOL-0B), and
  E4/E1 are ingested (DATA-11).** A coverage gap both reviewers missed: E4
  `FeeConfigurationChanged` is a **LIVE** producer event with topic0 pinned that nothing in
  the plan consumed — it appeared once, as an external-dependency row. Structural cause:
  VOL-01..09 were specified purely by Lean module, theorem count and module dependencies,
  saying nothing about parameter sources, while DATA-01..10 covered only the E3/E6
  tick-and-window series. VOL-07 `FeeSchedule`'s 24 theorems would have been ported against
  Θ_φ, a parameter set with a producer and no ingestion path.
- [Roadmap rev 3]: **VOL-0B → Phase 2, with VOL-00 — not Phase 5 with VOL-0A.** It is
  `registry.tsv` schema (a `provenance` column beside `tier`) plus a standing lint, so
  adding it after the port opens means retrofitting entries; and it has a pre-Phase-5
  consumer — Phase 4's DATA-11 is the first entry to use the column. VOL-0A is a different
  object: a one-off investigation whose verdict opens or closes the port. The *declarations*
  are made per-module in Phases 4–7; Phase 2 owns only the mechanism.
- [Roadmap rev 3]: **DATA-11 is an independent ingestion leg, not a downstream step.** It
  gets its own Phase 4 plan (04-05) and is explicitly not sequenced behind the E3/E6 moments
  chain (04-02). It shares `execute_loadDC`, the capacity-grid discipline and
  `check-datapin` with DATA-01/02/08 and nothing else.
- [Roadmap rev 3]: **The Phase 4 → Phase 6 edge is confirmed and doubled.** Rev 2 asserted
  Phase 6 as the real join on the strength of `Upsilon` alone; rev 3 adds `FeeSchedule` via
  DATA-11. Two of Phase 6's five modules — 45 of its 67 theorems — now sit behind Phase 4,
  not 3. That argues for Phase 4 holding its schedule, not for re-cutting phases. Phase 5
  remains free of any Phase 4 edge.

- [Roadmap rev 2]: **Every success criterion must name a committed, re-runnable artifact.**
  Rev 1 stated ~12 criteria as one-shot manual mutations, verified once and unfalsifiable a
  day later. The substrate is **TEST-09** — `model/test/_mutants/` plus
  `make negative-controls` — which is mapped to **Phase 0**, not Phase 2, because Phase 0's
  own criteria are stated against it. Where a criterion cannot be made checkable it is
  labelled **UNVERIFIABLE-LEG** and says what remains unverified. Three such admissions
  exist and are deliberate.
- [Roadmap rev 2]: **REPR-10 — the Core Value made executable — is new and lands in Phase 1.**
  Rev 1 had the Core Value in no requirement at all, and the "dual representation" is
  common-mode today: `sqrtPX96_at` is `P_Lean_at` with the exponent halved, both reading one
  `lambda` scalar. Bridge 1 exists only as a comment; bridge 2 is a tautology; and
  `piGridPlank`/`piGridLean` are both computed across 181 in-band points and **never
  compared**. Phase 1 ships an independent `TickMathReplica.gms` plus the 181-point
  comparison as an immediate leg.
- [Roadmap rev 2]: **M5 — the bridge design is pulled forward and a false blocking edge is
  cut.** `PosSpec`/`Main` import only Mathlib; `Flow` imports only `PosSpec`; no Phase 5
  criterion references moments, `rv_bar` or `degeneracyBreaks`. **Phase 5 now depends on
  Phase 2 only** and runs parallel with 3 and 4; its first plan is VOL-0A's split test plus
  the bridge design spike, each with an explicit INVALIDATED-able outcome. Phase 6 is the
  real join of 3, 4 and 5.
- [Roadmap rev 2]: **B7 — SOLVE-04 split into 04a (THEOREM, value) and 04b (INFERENCE,
  coordinates, hypothesis-guarded).** `riskNeutral_corner` bounds a *value*; asserting
  *coordinates* needs argmax uniqueness (absent — `g θ` is `Classical.choice`, no `∃!` /
  `StrictConcave` / `StrictConvex` in the spec) plus a `θ.b > 0` hypothesis the theorem does
  not carry. **VOL-00** (tiers `THEOREM`/`BRIDGE`/`INFERENCE`, counted separately, never
  summed) moved to **Phase 2** so it exists before Phase 3 needs it.
- [Roadmap rev 2]: **M7 — the 3∥4∥5 contention is designed out.** Root `Makefile` gains one
  `-include mk/*.mk` line in Phase 0 and is never edited again; `model/lint/rules.tsv` and
  `model/test/registry.tsv` are one-entry-per-line and append-only.
- [Roadmap rev 2]: **The demo-license "hard wall" is struck from the Phase 6/7 cut rationale
  and from Phase 3's criteria.** A 1200-var NLP already returns rc=7 with a named
  diagnostic, and un-aggregable units (`$150`) never grow toward 1000, so a size assert
  could never fire. The in-degree-4 argument stands alone and was independently verified.
- [Roadmap rev 1, retained]: **`vol_markets` split across Phases 5/6/7 (31/67/36)** at the
  graph's two structural points — `Flow` (out-degree 4) and `VolInstrument` (in-degree 4).
  Both cuts were independently verified from the Lean imports by the reviewers.
- [Roadmap rev 1, retained]: **REPR-09 (53-bit rule) is Phase 1's first plan** — REPR-01 and
  REPR-06 are its corollaries, not its peers.
- [Roadmap rev 1, retained]: **Phase 8 (IDENT-01) may close as INVALIDATED**, gated on the
  machine-readable `degeneracyBreaks` flag exported by Phase 3.
- [Roadmap rev 1, retained]: **9 phases against a `standard` 5–8 band.** Both reviewers
  endorsed the structure.

### Pending Todos

None yet. (`.planning/todos/pending/` not created)

### Blockers/Concerns

- **[Phase 0 — one false-pass mode survives 00-01, for 00-02 to close]** The registry row
  `nc-runner-selftest-registry` expects `nonzero` from
  `make negative-controls REGISTRY=model/test/_mutants/registry.selftest.tsv`. **If that selftest
  file were deleted**, the runner would exit 2 ("registry does not exist") — still non-zero — and
  the row would still report PASS. Deleting the runner's own falsifiability proof therefore keeps
  `make negative-controls` green. Closing it needs a 5th row (a `positive` row asserting the file
  exists, ideally plus an entry-count pin), which 00-01 could not add without breaking its own
  literal `4 entries` criterion. Recorded in
  `.planning/phases/00-honest-gates/deferred-items.md` (D1).
- **[Phase 0 — blocks everything, but SCOPED]** The false-pass defect is confined to the
  three grep-based targets: `payoff-fixtures` (Makefile:78), `spec-preflight` (99),
  `spec-preflight-band` (143). **`compile-gams` (30) and `test-gams` (53) gate correctly** —
  they use `if $(GAMS) …; then`, verified by live mutation (an injected failing `abort$`
  makes `test-gams` return rc=2). CI runs only those two, so **CI is not blind**. Rev 1's
  "no phase's green is evidence of anything" overstated the blast radius and is withdrawn.
  What *is* true: fixtures go stale silently and the proof gates are vacuous.
- **[Phase 0 — the repair must not be circular]** `gate-selftest`/`negative-controls` will be
  written in the same `make` idiom that produced the bug. Resolved three ways: exit codes
  only as the predicate (never `grep` — proven sufficient, gams returns 2 on compile error
  and 3 on abort); a **committed** deliberately-broken fixture per target so the negative
  direction re-runs forever; and `set -e`-clean recipes reviewed by `shellcheck` via
  `make lint-make`, itself a committed target.
- **[Phase 0 — `gams-gate` exists already]** Corrected: the environment was **auto-created
  2026-07-27 by the first workflow run**, not deliberately, and has **0 protection rules**
  and **0 runners**. GATE-06's work is *configuring* an environment that is already there.
  Ordering is load-bearing — protection rules before runner registration.
- **[Phase 0 — two admitted gaps]** (1) No committed input provably degrades `solveStat`
  while leaving `modelStat` acceptable — the static `rules.tsv` rule is what guarantees
  GATE-03 coverage, not the mutant. (2) `model/price_impact_kernel.gdx` has **no
  regeneration path at all**; either a producer is funded in a plan or it is recorded in
  `model/fixtures/UNVERSIONED.md` as knowingly unversioned.
- **[Phase 1 — genuinely blocked]** REPR-07's `E2.liquidityBar` normalizer question is open
  on **cfmm-gams#1**. Corrected fact: `LbarQ128`/`DICfgQ128` are **not both `2^128`** — each
  unit sets one to `2^128` and the other to `2^128/10`, swapped. If they are genuine
  Q128.128 encodings, `2^128` encodes 1.0 and there is no overflow. If the issue is
  unanswered at execution time, Phase 1 records both candidate readings plus an `abort$` that
  fires on an undeclared assumption — it does not guess.
- **[Phase 3 / Phase 8 — now instrumented, not just carried]** Every degeneracy experiment
  used a **constant η̃-measure `w`**. `make check-wstate` asserts the sha256 of
  `lean4-spec/exp/ComparativeStatics.lean` and the `fun _ => θ.w` occurrence count against
  the committed pin `model/spec-pins/wstate.pin`, and reddens when either moves. Tracked as
  v2 item **WSTATE-01**.
- **[ALL PHASES — real data has no producer and no owner]** The **indexer** — the component
  that reads on-chain logs by `topic0` and emits the GDX this model loads — is **UNOWNED AND
  UNBUILT**. No phase, requirement or workstream claims it, and `topic0` appears nowhere in
  the plan. v1 is unblocked only because DATA-10 proves the interface on a **fabricated**
  series. **No phase criterion may be read as implying live ingestion**, including DATA-11's:
  its acceptance is "fabricated E4/E1 rows satisfying the §4 table load and convert
  correctly", never "we ingested live fee config". The events being LIVE means the schema is
  fixed, not that the data arrives. Worth raising with the producer contract's authors —
  they would know whether the indexer is scoped to their track, a new track, or nobody.
- **[Phase 4 — external, non-blocking by design]** The producer contract is pinned to
  `cfmm-replicationPlank@d34846c` on `feat/plank`, **not merged to develop**. E2 and E5 are
  SPEC-ONLY (plank tasks #14, #16). No Phase 4 criterion depends on E2/E5 data existing;
  `make check-datapin` reddens when the pin moves. Live-but-unconsumed is now covered:
  E4 and E1.strike feed DATA-11 (rev 3).
- **[Phase 6 — provenance still TBD for three modules]** VOL-04, VOL-05 and VOL-06 have no
  contract-stated parameter source. VOL-05's ξ⋆, if consumed, arrives via E2
  `PortafolioMinted` (**SPEC-ONLY**), so such a unit must declare it and run on a fabricated
  fixture. VOL-06's `tokenId` decoding is subgraph-side per contract §6 — provenance `none`
  on the GAMS side by construction. The VOL-0B lint reddens a module that stays TBD.
- **[Phase 8 — ZERO MARGIN]** Only **two** programs are solvable (PROG-01 M5, PROG-02 M6a
  levels); PROG-03 and PROG-04 are both assert-only. The census in plan 08-01 can invalidate a
  program individually, and the phase-level clause fires below two survivors — so a single census
  failure amends the project's deliverable statement. Rev 4 hid this by claiming "3 solved / 1
  asserted".
- **[Phase 8 — a mis-citation that rev 4 shipped]** PROG-01 cited `flairMulti_exists_max_compact`:
  a **maximum** of **λ_FLAIR** over a **different block**, standing in for a minimum of λ_ARB. It
  passed because PROG-00's lint only checked the certificate cell was non-blank. PROG-00 now
  requires objective symbol **and** direction to match.
- **[Phase 1 — a tautology rev 4 introduced, now fixed]** `abort$(SATURATION_SENTINEL <>
  exp(1000))` recomputes the same expression on both sides: measured rc=0, can never fire — the
  identical defect as the `diStarPlankReal` bridge this roadmap catalogues. Replaced by a pin
  check against `model/spec-pins/saturation.pin` with a pin-editing mutant. **The lesson is that
  the author of the catalogue reproduced the catalogued defect; TEST-08's rule is what would have
  caught it, and it must be applied to new criteria, not only to inherited ones.**
- **[Phase 11 — cross-track boundary]** VPATH-11's on-chain replay is owned by the GAMS↔Solidity
  differential-testing session per the repo ownership map. This phase owns the emitted artifact,
  the tolerance contract, and a GAMS-side self-replay from the emitted integers. The on-chain leg
  is an external dependency and is marked UNVERIFIABLE-LEG from this repo — not claimed.
- **[Phase 10 — one obligation the algebra does not discharge]** VPATH-12's reciprocal-affinity
  finding is *very likely* the MEV notes' Theorem 29/30 (additive monoid under swap composition),
  but matching algebra is not a citation. The correspondence is confirmed against the Lean/doc
  statements and recorded with a verdict before the structure is relied on.
- **[Phase 8 — the programs may not all open]** Plan 08-01's certificate **census** over the
  six theorems the PROG requirements cite by name can stop any of them individually. A theorem
  whose intended GAMS use is stronger than its conclusion moves its program from SOLVE to
  PROG-03's assert-only discipline. This is the VOL-0A risk applied where it matters most.
- **[Phase 8 — the shape block is a trap, not a program]** Over unbounded `(β, γ)` the bound is
  approached only as β → −∞ with a strict gap at every finite β. **A naive NLP will drive β to
  a bound and report that bound as the optimum.** PROG-03 guards it, and per TEST-08 the guard
  ships with a committed unit that deliberately runs the naive NLP and must be caught — because
  an unfalsifiable guard here is the most expensive kind.
- **[TWO DEGENERACIES — relationship UNKNOWN]** M6a's degeneracy (λ_FLAIR maximizer and λ_ARB
  minimizer sharing a corner in `(φ̄, α, u)`) and Phase 3's `Δᵢ·η` product degeneracy are
  recorded as **separate phenomena**. Nothing asserts they are the same; nothing asserts they
  are different. Establishing a link would be new work.
- **[Phase 5 — the port may not open]** VOL-0A's split test can stop it: if ≥3 of 10 sampled
  theorems come back `INFERENCE`, the port re-cuts its scope. The one theorem examined so far
  (`riskNeutral_corner`) already failed. The bridge design spike carries the same kind of
  outcome.
- **[Phases 3 and 5 — research]** Both carry **NEEDS `/gsd:research-phase`**. Phase 3: does
  the `retVol` coupling break the degeneracy; is stationarity formulable as a CNS square
  system; `objScale` on the real objective. Phase 5: the pricing-kernel↔volatility bridge has
  no Lean counterpart and must be designed — now Phase 5's first plan rather than a Phase 6
  surprise. Phase 4 is LIGHT (grid sizing / `winMap` density).
- **[All phases]** The "No phase may claim" table in ROADMAP.md is binding and was corrected
  in rev 2. Notably: overflow has **two regimes** — operator overflow is LOUD (rc=3),
  intrinsic overflow is SILENT (rc=0, clamps to `1.0000E+299`) — and exactly one named
  `SATURATION_SENTINEL`, re-derived from `exp(1000)` at build time, is the permitted
  detector for the silent one. Also binding: `THEOREM` and `INFERENCE` greens are never
  summed; an assertion never observed to fail is not evidence.
- **[Baseline count is not a goal]** `make compile-gams` reporting 12/12 includes
  `model/PricingKernelMoments.gms`, a known silent no-op. Phase 0 pins it for regression only;
  Phase 4 replaces it and the count is expected to change.

## Session Continuity

Last session: 2026-08-15
Stopped at: Completed 00-01-PLAN.md on branch `gsd/phase-0-honest-gates` (commits `434062a`, `1e5a6ca`, `6df3dbf`). `make negative-controls` runs 4 seeded rows green; the runner is proven able to fail by `registry.selftest.tsv`; baselines re-verified at `compile-gams: 12 ok, 0 failed, 0 skipped` and `test-gams: 4 passed, 0 failed`. Next: 00-02 (which should also close deferred item D1).
Resume file: .planning/phases/00-honest-gates/00-01-SUMMARY.md

Prior session (2026-07-30): ROADMAP.md rev 5 and STATE.md written; REQUIREMENTS.md traceability rebuilt (84/84 across 12 phases). **The two-step review gate has still never passed on that artifact** — rev 5 fixes two defects (N3, the PROG-01 mis-citation) that only a review found, in a document revised five times without one.
