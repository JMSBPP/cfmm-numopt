# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-27)

**Core value:** Every geometric primitive carries a Lean-coordinate evaluator, an EVM-coordinate fixed-point evaluator, and an executable assertion that the two agree under a documented coordinate bridge.
**What the project is for (rev 4):** The GAMS layer **solves** the convex programs implied by `VOLATILITY_INSTRUMENTS.md` — programs `cfmm-lean4-spec` formalizes and Plank implements on-chain. The representation kernel is the **substrate that makes a solved parameter EVM-expressible**, not a parallel track. **Non-degenerate first**: three attained programs are solved (M5, M6a levels, M6b), the unattained shape block is asserted only.
**Second deliverable (rev 5):** `Shocks → VolumePath[]` — GAMS generates a length-`N` swap path realizing a target fee revenue and emits it as exact-integer JSON for on-chain replay. Filed as **Phases 10–11**, not a new milestone: v1.0 has shipped nothing, and the two scopes share REPR-10's exact Q96 table, `priceImpactKernel_Add0`, TEST-02's tolerance rule and GATE-05.
**Current focus:** Phase 0 — Honest gates

## Current Position

Phase: 0 of 11 (Honest gates)
Plan: 3 of 4 in current phase (00-01, 00-02, 00-03 complete)
Status: In progress — GATE-01/02/03/04 met and TEST-09 substrate hardened; 00-04 (GATE-05/06/07) pending
Last activity: 2026-08-15 — 00-03 executed on `gsd/phase-0-honest-gates`: `make lint-gams` reading the data-file rule table `model/lint/rules.tsv` (LINT-01..07), `solveStat` assertions inserted at BOTH `Solve` sites, 8 new committed mutants, 11 new registry rows (29 total)

Progress: [█░░░░░░░░░] 6% (3/54 plans; Phase 9 plan count TBD)

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 9.7 min
- Total execution time: 0.5 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| Phase 00 P01 | 1 | 6 min (3 tasks, 8 files) | 6 min |
| Phase 00 P02 | 1 | 11 min (4 tasks, 12 files) | 11 min |
| Phase 00 P03 | 1 | 12 min (3 tasks + 1 doc repair, 16 files) | 12 min |

**Recent Trend:**
- Last 5 plans: 00-01 (6 min), 00-02 (11 min), 00-03 (12 min)
- Trend: flat (~10 min/plan). Each wave carries one unplanned task: 00-02 the D1 closure, 00-03 the D1 *rule* applied to its own rows plus a `_mutants/gams` vs `_mutants/gms` doc repair.

*Updated after each plan completion*

## Accumulated Context

### Decisions

Full log in PROJECT.md Key Decisions. Decisions taken during roadmapping (later revs
supersede earlier ones where they differ):

- [Phase 0, plan 00-03]: **A rule keyed on a MISSING assertion must match inside the assertion's
  CONDITION, not merely find the token nearby.** Measured on the pre-fix tree with the identical
  trigger and 12-line window: partner `(?i)\.solveStat\b` (token anywhere) → **0 violations, rc=0**;
  partner `(?i)abort\$\([^()]*\.solveStat\b` (inside the condition) → **2 violations**, at
  `eta_pi_trader_band_monotone_large.gms:118` and `eta_pi_trader_zero_slippage.gms:89`. Both units
  already *displayed* `.solveStat` in the failure argument list of an `abort$` that tested only
  `modelStat`, so the obvious form of the rule reports a clean tree against two real gaps. **The
  general rule: when linting for an absence, write the mutant so it contains the token in the wrong
  place and confirm the rule still fires.** Phase 2's PROG-00 certificate lint and VOL-0B provenance
  lint are the same shape and inherit this.
- [Phase 0, plan 00-03]: **The GAMS lint is a DATA FILE.** `model/lint/rules.tsv` — seven TAB
  columns (`id`, `severity`, `kind`, `pattern`, `partner`, `window`, `message`), append-only, one
  rule per line (M7). Two kinds: `forbid` (a banned token) and `require_within` (a MISSING
  construct). Later phases add coverage by appending a LINE; `model/lint/lint_gams.py` is not
  edited. **Every new rule must ship a mutant in `_mutants/gms/` and a row in `registry.tsv`** —
  stated in `model/lint/README-rules.md`.
- [Phase 0, plan 00-03]: **`execute` and `$call` need SEPARATE lint rules.** `$onCheckErrorLevel`
  governs `$call` **only** — measured: with it set, `execute 'false'` still returns rc=0 and
  execution continues. LINT-02 and LINT-03 are therefore not substitutes; one rule would have left
  half of GATE-04 uncovered while looking complete.
- [Phase 0, plan 00-03]: **The lint's default file set is a filesystem walk, not `git ls-files`.**
  The plan specified `git ls-files` but its own acceptance criterion bans `subprocess` from the
  engine. The walk over `model/` (minus `build/` and `test/_mutants/`) is stricter — an uncommitted
  source cannot escape the lint by being untracked — and was measured to yield the identical 16
  files.
- [Phase 0, plan 00-02]: **A `negative` row expecting `nonzero` accepts EVERY reason for failing —
  including "the artifact under test is gone".** This was the D1 false pass: deleting
  `registry.selftest.tsv` made the runner exit 2 ("does not exist"), which the row accepted, so
  `make negative-controls` stayed green (measured `16 entries, 0 failed`, rc=0) with the proof of
  its own falsifiability deleted. **Rule: whenever a negative row's command reads a committed
  artifact, pair it with a `positive` row asserting that artifact is present AND intact.** D1 is
  closed by `nc-selftest-file-present` + `nc-selftest-entry-count`; both were observed to fail.
- [Phase 0, plan 00-02]: **A glob matching zero units FAILS.** A second false pass, independent of
  the listing scrape: `payoff-fixtures` over an empty glob printed nothing and exited 0. The guard
  is now in `payoff-fixtures`, `compile-gams` and `test-gams`.
- [Phase 0, plan 00-02]: **`lint-make` enumerates from `make --print-data-base`, not from a list.**
  A new target cannot escape review by not registering itself; `negative-controls` and `lint-make`
  are both inside their own scope, so the circularity does not re-enter one level up. The price:
  every compound recipe line must begin `set -e;` (enforced by LM-SET-E) or `lint-make` reddens.
- [Phase 0, plan 00-02]: **A missing tool is a failure, never a skip.**
  `make lint-make SHELLCHECK=/nonexistent/shellcheck` prints `shellcheck not found` and exits
  non-zero. `make tools-shellcheck` bootstraps shellcheck **0.11.0** (koalaman static tarball) into
  the gitignored `.tools/`; a CI job adding `lint-make` must call it first.
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

- **[Phase 0 — D1 CLOSED by 00-02]** The `nc-runner-selftest-registry` false pass (deleting
  `registry.selftest.tsv` left `make negative-controls` green) was reproduced — `16 entries,
  0 failed`, rc=0 — and closed by two `positive` rows. Re-measured after the fix: proof absent →
  `18 entries, 2 failed`, rc=2; proof restored → `18 entries, 0 failed`, rc=0; proof gutted to one
  row → `nc-selftest-entry-count` FAIL, rc=2. See `deferred-items.md` D1 and
  `model/test/README-negative-controls.md`.
- **[Phase 0 — GATE-01 MET by 00-02]** The false-pass defect in the three listing-scraping targets
  is repaired: `payoff-fixtures`, `spec-preflight` and `spec-preflight-band` now gate on
  `if $(GAMS) …; then`, the token `grep` no longer appears anywhere in the Makefile, and five
  committed mutants redden them on every `make negative-controls`. A second false pass found and
  closed on the way: a glob matching zero units used to print nothing and exit 0. **The scoping
  correction stands** — `compile-gams` and `test-gams` always gated correctly and CI runs only
  those two, so CI was never blind; what was true is that fixtures went stale silently and the
  proof gates were vacuous. Remaining Phase 0 work is GATE-02…07 (plans 00-03, 00-04).
- **[Phase 0 — the repair was not circular, and here is exactly how far that goes]** Three
  mechanisms, all shipped: exit codes as the only predicate; a committed deliberately-broken
  fixture per target so the negative direction re-runs forever; and `make lint-make`, which pulls
  recipe bodies from `make --print-data-base` and reviews them with shellcheck 0.11.0 on
  SC2181/SC2015. **Honest limits:** `LM-GREP-PREDICATE` is token-based, so an `awk`/`case`/`test
  -s` scrape in a predicate position would still pass (logged as D3); and `lint-make`'s first run
  reported 0 findings because the anticipated SC2181 was fixed preemptively — the shellcheck leg
  was therefore proven able to fire on a throwaway probe (SC2181 + SC2015 both reported) before
  that green was accepted.
- **[Phase 0 — a tool that corrupts the artifact it updates]** `gsd-tools roadmap
  update-plan-progress 0` **damaged `.planning/ROADMAP.md`**: there is no per-phase plan-progress
  table in that file, so it overwrote the Requirement Coverage row `| 0 — Honest gates | GATE-01
  … | 8 |` with `| 0 — Honest gates | 2/4 | In Progress|` and swallowed the start of the Phase 1
  row. Repaired by hand and verified by diff. Also `gsd-tools state advance-plan` cannot parse this
  STATE.md ("Cannot parse Current Plan or Total Plans"). **Later plans should update ROADMAP.md and
  STATE.md by hand and diff the result, not trust these two subcommands.**
- **[Phase 0 — `gams-gate` exists already]** Corrected: the environment was **auto-created
  2026-07-27 by the first workflow run**, not deliberately, and has **0 protection rules**
  and **0 runners**. GATE-06's work is *configuring* an environment that is already there.
  Ordering is load-bearing — protection rules before runner registration.
- **[Phase 0 — GATE-02/03/04 MET by 00-03]** `make lint-gams` reads `model/lint/rules.tsv` and
  reports `16 files, 7 rules, 0 violations`, rc=0. Seven rules, each with a committed mutant proven
  to redden it with its own rule id. The real GATE-03 gap was `solveStat`, not `modelStat`, exactly
  as the roadmap's correction said: LINT-06 found **2** violations (band:118, zero-slip:89) and
  LINT-07 found **0**, and both units now assert `solveStat` ahead of `modelStat`.
- **[Phase 0 — two admitted gaps, one now bounded]** (1) **Still true and now measured.** No
  committed input provably degrades `solveStat` while leaving `modelStat` acceptable — the static
  LINT-06 rule is what guarantees GATE-03 coverage, not the mutant. The `option iterlim = 0` mutant
  gives **solveStat 11 (Internal Solver Failure) / modelStat 5 (Locally Infeasible)** at rc=3: the
  two codes degrade *together*, which is the direct evidence that the mutant proves the assertion
  PAIR fires and cannot isolate `solveStat`. The UNVERIFIABLE-LEG text is reproduced verbatim in
  `model/lint/rules.tsv` above LINT-06 and in `registry.tsv` above the mutant row. (2)
  `model/price_impact_kernel.gdx` has **no regeneration path at all**; either a producer is funded
  in a plan or it is recorded in `model/fixtures/UNVERSIONED.md` as knowingly unversioned.
- **[Phase 0 — the D1 rule keeps finding new instances]** 00-03's eight `nonzero` negative rows read
  committed mutants, and a **deleted** mutant also exits non-zero (rc=2, "does not exist"), so each
  would have kept passing with its own proof gone. Reproduced with `gms/onmulti.gms` moved away.
  Closed by `nc-lintgams-mutants-present` (presence: 7 files; integrity: all seven `LINT-0[1-7]` ids
  still named), observed to FAIL when violated. **Expect this to recur in every plan that adds
  negative rows** — it has now occurred in two consecutive waves.
- **[Phase 0 — three plans, three factual errors in their own acceptance criteria]** 00-01 (rc=1 vs
  make's 2), 00-02 (the same, three times, plus a mutant that could not fail), 00-03 (a `grep -c`
  count of 1 against a comment the plan itself mandates, and `26 entries` where 18+10 = 28). None
  were resolved by weakening the check; each was recorded with the measurement that contradicts it
  and a stricter substitute. **Planners: derive counts from the tree, not from memory.**
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
Stopped at: Completed 00-03-PLAN.md on branch `gsd/phase-0-honest-gates` (commits `ea93da7`, `11ccfe5`, `afa597c`, `d15fc48`). GATE-02/03/04 met. Five gates re-verified at the end: `compile-gams: 12 ok, 0 failed, 0 skipped`; `test-gams: 4 passed, 0 failed`; `lint-gams: 16 files, 7 rules, 0 violations`; `lint-make: 10 recipes, 0 findings` (was 9 — `lint-gams` is inside its enumeration); `negative-controls: 29 entries, 0 failed`. `git status --short -- 'model/*.gdx'` empty. Next: 00-04 (GATE-05/06/07; NOT autonomous — carries the runner checkpoint).
Resume file: .planning/phases/00-honest-gates/00-03-SUMMARY.md

**Uncommitted on purpose:** `.planning/ROADMAP.md` carries 3 unrelated pending GATE-07 wording
edits from a prior session, plus 00-02's and 00-03's Phase-0 plan checkmarks and the `3/4` progress
row. 00-02 and 00-03 both deliberately left the file uncommitted so those unrelated edits are not
swept into their history — `git commit -- <path>` commits the whole file, not a hunk. The ROADMAP
updates for both plans are on disk and were diffed; whoever owns the GATE-07 wording should commit
the file as a whole. `.planning/config.json` is likewise modified and untouched.

Prior session (2026-07-30): ROADMAP.md rev 5 and STATE.md written; REQUIREMENTS.md traceability rebuilt (84/84 across 12 phases). **The two-step review gate has still never passed on that artifact** — rev 5 fixes two defects (N3, the PROG-01 mis-citation) that only a review found, in a document revised five times without one.
