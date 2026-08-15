# Roadmap: cfmm-gams — Dual-Representation Geometry for CFMM Parameter Solving

**Milestone:** v1.0
**Granularity:** standard (compression guidance; see "Deviation from the granularity band")
**Coverage:** 84 / 84 v1 requirements mapped ✓
**Phases:** 12 (0–11)
**Revision:** rev 5.
*Rev 2* rebuilt this document after the two-step review (Reality Checker + Model QA
Specialist, both NEEDS WORK): rev 1 had asserted roughly a dozen unfalsifiable criteria and
eight factual claims that measurement contradicted.
*Rev 5* maps 17 previously-unmapped requirements and **extends the roadmap with Phases 10–11**
(the volume-path work, filed as continuing phases rather than a new milestone). It also carries
three fixes from the review that has still never passed — including **a tautological guard I
introduced in rev 4** — and re-cites Phase 8's certificates after the Lean submodule refresh,
which moved one program from SOLVE to ASSERT-ONLY.
*Rev 4* was a **reframing of the deliverable, not a delta.** See "What this project is for".
*Rev 3* closed a coverage gap **both reviewers missed**. E4 `FeeConfigurationChanged` is a
**LIVE** producer event with topic0 pinned, and nothing in the plan consumed it — its only
appearance was one external-dependency row. The root cause was structural: VOL-01..09 were
specified purely by Lean module name, theorem count and module dependencies, saying nothing
about **where parameters come from**, while DATA-01..10 covered only the E3/E6
tick-and-window series. VOL-07 `FeeSchedule`'s 24 theorems would have been ported against
Θ_φ — a parameter set with a live producer and no ingestion path. Closed by **DATA-11**
(ingest it) and **VOL-0B** (make the omission structurally impossible to repeat).

## What this project is for

**The GAMS layer solves the convex programs implied by `VOLATILITY_INSTRUMENTS.md`** — the
programs the `lean4-spec` layer formalizes and the Plank layer implements on-chain. Three
layers, one object:

| Layer | Role |
|---|---|
| `cfmm-lean4-spec` | **Formalizes** — the theorems that say an extremum exists and where |
| **`cfmm-gams` (this repo)** | **Solves** — produces the parameter values, and proves they are representable |
| Plank / EVM | **Implements** — consumes the solved parameters on-chain |

Two consequences reshape this roadmap, and rev 3 had neither.

**1. The representation kernel is the substrate, not a parallel track.** Phases 0–2 are not
hygiene preceding the real work — they are **what makes a solved parameter EVM-expressible**.
That is why `PricingKernel` was architected the way it was. **PROG-05** turns this into a
requirement: every solution round-trips through the kernel's declared scales and bounds, and
**a solution outside what Plank can represent FAILS the program — it is not rounded into
range.** The rev-1..3 ordering of Phases 0/1/2 is therefore *validated* by the reframing, not
displaced; what changes is that the roadmap now says **why** those phases exist.

**2. Non-degenerate first.** Every program is scoped to a case where the extremum is
**attained**. Where it is not, the case is asserted as a limit, never solved, and revisited as
the lean4-spec worktree constrains the problem further. The doc already draws the line:

| Program | Extremum attained? | Action |
|---|---|---|
| **M5** — infimum on λ_ARB over a nonempty **compact** box | minimizer exists (doc:579) | **SOLVE** — PROG-01 |
| **M6a level block** `(φ̄, α, u)` | corner attained, bang-bang | **SOLVE** — PROG-02 |
| **M6b** — flat path minimizes λ_ARB among equal-FLAIR paths | **strictness proven, existence NOT** — no compactness fact for the equal-income level set | **ASSERT ONLY** — PROG-04 *(demoted in rev 5)* |
| **M6a shape block** `(β, γ)`, unbounded | **NOT attained** — saturation boundary as β → −∞ | **ASSERT ONLY** — PROG-03, deferred |

**Rev 5 demotes M6b.** PROG-00 was corrected: strict convexity gives **uniqueness given
existence**, not existence. `ptrade_strictConvexOn` and `ptrade_strictAntiOn` are both proven,
but existence over the equal-income level set is uncertified, and PROG-00(a) requires existence
to license a `Solve`. **Phase 8 therefore enters with exactly two solvable programs (M5,
M6a-levels) and two assert-only ones** — a zero-margin position that Phase 8's new phase-level
verdict clause exists to make visible.

**What the verification port becomes.** VOL-01..09 framed the port as theorem verification via
`abort$()`, and only Phase 3 contained a `Solve` at all — Phases 5–7 carried no optimization.
That port is **still the substrate the solve rests on and is not deleted**, but it is **no
longer the endpoint**. The endpoint is Phase 8.

**A scoping error, recorded.** `FlairOptimization` (15 theorems, **0 sorry**) was placed in v2
on the argument that it imports *from* `VolInstrument` and is therefore downstream. That was
topologically right and functionally backwards: **it is where the solved programs live**, cited
by name at `VOLATILITY_INSTRUMENTS.md:459`. It is now **VOL-10**, v1. *Downstream in the import
graph does not mean lower priority when the deliverable is solving.*

**A second deliverable, filed as Phases 10–11 rather than a new milestone.** Given a **volume
shock** and a **fixed** iteration count `N`, GAMS generates a swap path of length `N` —
quantities that, entered as swap calls, realize a desired fee revenue under `δ_trans` and carry
the tick from `i(t)` to `i(t+1)` — emitted as JSON for forge to replay and diff. It is filed
here, not started as `v1.1`, for two reasons: GSD's `new-milestone` presumes a **shipped**
predecessor and v1.0 has shipped nothing (0/54 plans, no `MILESTONES.md`), so it would orphan
v1.0; and the two are **genuinely coupled** — VPATH-13 shares REPR-10's exact tick→sqrtPriceX96
table, VPATH-01 reuses `priceImpactKernel_Add0`, VPATH-11 uses TEST-02's tolerance rule, and
VPATH-09/13 ride on GATE-05's fixture-freshness machinery. Those edges belong in one dependency
graph and one traceability table. **Phases 0–9 keep their numbering and content.**

> **Two degeneracies, relationship UNKNOWN.** M6a's degeneracy — the λ_FLAIR maximizer and the
> λ_ARB minimizer sharing a corner in `(φ̄, α, u)` — and Phase 3's `Δᵢ·η` product degeneracy are
> recorded here as **separate phenomena whose relationship has not been established**. No phase
> asserts they are the same, and none asserts they are different. Establishing a link would be
> new work, not a restatement.

## Overview

This is a verification project wearing a modelling project's clothes. The GAMS work is
implementation and verification rather than discovery — but only for the modules whose
Lean substrate is actually closed. The dominant risk class is **silent wrongness, not
loud failure**.

**Scoped claim about the current green (corrected).** Rev 1 said "the repo's current green
is substantially uninformative" and "no phase's green is evidence of anything". That
overstated the blast radius. `compile-gams` (Makefile:30) and `test-gams` (Makefile:53)
use `if $(GAMS) …; then` — they gate on the **exit code**, correctly. Verified by live
mutation: an injected failing `abort$` makes `test-gams` return rc=2. CI runs *only* those
two targets, so **CI is not blind**. The false-pass defect is confined to the three
grep-based targets — `payoff-fixtures` (Makefile:78), `spec-preflight` (99), and
`spec-preflight-band` (143) — i.e. the fixture-regeneration and proof-gating paths. Still
serious (fixtures go stale silently, proof gates are vacuous), but narrower.

**Scoped claim about the Lean substrate (corrected).** Rev 1 said "the Lean substrate is
fully proven", unqualified. True for `vol_markets`: **12 files, 205 theorems, 0 `sorry`
throughout** — refreshed at submodule `bec4c9c → 19afcdd` (2026-07-30), which added
`MevOptimization.lean` (22 thm) and `EndogenousMaturity.lean` (34 thm). *(Rev 4 said "ten
files, 169 theorems"; the measured figure at the time was 149 and is now 205. Per Phase 7
criterion 1's own rule, this count is **asserted mechanically** against the registry, not
tallied into prose again.)* **Not** true for `exp/` — `eta.lean`, `BondingCurveCurvature.lean` and
`DynamicsOptimization.lean` each carry a `sorry` (v2 item SORRY-01). Only the specific
`eta.lean` theorems already gated sorry-free by `spec-preflight-band` are in scope, and
Phases 3 and 8 lean on `exp/` modules (`ComparativeStatics`, `MeanVarianceOptimization`,
`EnvelopeTheorem`) that *are* closed. The qualification matters because Phase 5's proof
gate must distinguish the two.

**Scoped claim about the data (new in rev 3).** There is **no producer for real data, and
no owner for one.** The component that reads on-chain logs by `topic0` and emits the GDX
this model loads — the indexer — is **UNOWNED AND UNBUILT**. No phase, requirement or
workstream claims it, and `topic0` appears nowhere in this plan. v1 is unblocked only
because DATA-10 proves the interface on a **fabricated** series. **No criterion in this
document may be read as implying that real data has a producer**: every DATA and VOL
criterion below is stated against a fabricated or hand-supplied series, and until an owner
exists the solver is fed by hand.

The roadmap front-loads instrument honesty. Phases 0–2 produce no model results at all:
they make the gates capable of failing, unify the number representation and make the Core
Value executable, and build the assertion vocabulary. Only then do Phases 3, 4 and 5 —
which run in parallel — produce results that mean anything. Phases 6–7 close the
134-theorem `vol_markets` port along its dependency topology, cut at the graph's two
structural articulation points — the substrate the solve rests on. **Phase 8 is the
deliverable**: it ports `FlairOptimization` and solves the three attained programs, refusing
the fourth. Phase 9 exists **if and only if** the Phase 3 identifiability spike says it may.

## The falsifiability rule

Every success criterion below is checkable by a **committed, re-runnable artifact** — a
`make` target plus a fixture in the repository. Where a criterion cannot be stated that
way, it says so explicitly and names what remains unverifiable. Three such admissions
exist in this document (Phase 0 criteria 4 and 6, Phase 5 criterion 1's sample draw);
they are marked **UNVERIFIABLE-LEG** and are not disguised as checks. Phase 8's certificate
census is a fourth: the per-theorem verdict is a human reading of a Lean statement, and only the
record and the gate it feeds are mechanical.

The substrate for this is **TEST-09**: `model/test/_mutants/` plus `make negative-controls`,
which runs every "X reddens when Y breaks" claim as a committed fixture with a declared
expected non-zero exit code. Rev 1 stated ~12 such claims as one-shot manual mutations
verified once and unfalsifiable a day later. Every one of them is now restated against
this registry, or replaced by a static lint that *is* checkable.

## Binding constraints on every phase

These come from executed measurement against GAMS 54.1.0, not from recall.
They are stated once here and are binding on all phases below.

**No phase may claim any of the following:**

| Forbidden claim | The measurement that forbids it |
|---|---|
| Bit-exact GAMS↔EVM equality | IEEE binary64 (53-bit mantissa) vs 256-bit integers. The bottom ~43 bits of every Q96 sqrt price are structurally absent. |
| An unqualified "agreement at 1e-12" | GAMS `**` error is `≈1.101e-17·(i·Δᵢ)` — systematic and **signed**. A flat 1e-12 is exhausted at exponent ≈90,800, *inside* the already-declared domain, and is 9.8× over at Uniswap MAX_TICK. Every tolerance claim ships with (a) its valid exponent range, (b) the λ it was calibrated at, (c) the budget guard as executable code. |
| Any tolerance tighter than `1/sqrtPX96` below tick ≈ −596,180 | There the EVM's own Q96 grid (2.33e-10 at `MIN_SQRT_RATIO`) is coarser than a double's ulp. No tolerance is meaningful in either direction. |
| A uniquely-identified `(Δᵢ*, η*)` away from γ = 0 | The payoff depends on the controls **only through their product**. 62 equally-optimal pairs measured at γ=100 sharing one product; F1 and F2 agree on *value* to 2.2e-16 while disagreeing on *coordinates* at every γ>0; Lean's `g θ` is `Classical.choice` with no uniqueness lemma. |
| An interior NLP argmin asserted against a closed form at 1e-12 | Defensible at ~1e-9 *after* `objScale`; never before. 1e-12 requires solving stationarity as a square CNS system. |
| **That overflow behaves one way.** There are **two regimes** and they differ. | *Operator* overflow is **LOUD**: `a*a` at `a=1e299` yields `UNDF` with `*** Error … overflow in * operation (mulop)` at **rc=3**. *Intrinsic* overflow is **SILENT**: `power(10,300)`, `power(10,400)` and `exp(1000)` all clamp to exactly `1.0000E+299` at **rc=0** with `Normal completion`, collapsing 100 orders of magnitude with no diagnostic. Rev 1's "does not raise, continues at rc=0" was false for the operator regime. |
| That `= INF` is a usable non-finiteness guard | Neither regime produces `INF`. Guards key on **magnitude**. |
| That a per-call-site saturation literal is acceptable — **but exactly one named constant is** | Rev 1 banned the saturation constant outright, which forbade the only working detector for the silent regime. The permitted form is a single `SATURATION_SENTINEL` declared once in the scales module and **re-derived from `exp(1000)` at build time**, never a literal, never duplicated. |
| That a constants module can be built at compile time | `$eval 2**96` is wrong by exactly `2^45`; `power(2,96)` is exact. Independently re-verified twice. |
| That an exported provenance scalar means anything because a lint says it is read | The read-existence lint is **already gamed**: `inputs('etaQ128') = etaQ128;` is a pure copy into the GDX, so `etaQ128` passes "is read by an assignment" while remaining fabricated provenance. The enforcing mechanism is TEST-08's registered mutation proof, not a read check. |
| That `spec-preflight` says anything about the GAMS side — **or, today, about the Lean side either** | It proves the *Lean* module is sorry-free only where it actually greps. Measured: `make spec-preflight` performs **no Lean grep at all** (only `spec-preflight-band` does), its `sorry` scan looks for `sorry`/`admit` occurrences that do not exist repo-wide, and the grep it does run is column-0-anchored so it matches **zero** of the 134 namespaced `vol_markets` theorems. |
| That an MINLP or global-solver cross-check is available | `option minlp = conopt` is compile error `$255`; BARON is capped at 50 variables on this demo license. |
| That the demo license is a "hard wall" that some phase must defend against | Vacuous. A 1200-variable NLP already returns **rc=7** with a named diagnostic (`*** The model exceeds the demo license limits…`) — there is no bare solver failure to improve on. And since units are structurally un-aggregable (`$150 Symbolic equations redefined`, unconditional even under `$onMulti`), no single model grows toward 1000, so a size assert could never fire. No phase carries a license criterion. |
| That `priceImpactKernel_Add0` covers the EVM function | It contains **zero conditional operators** — the `add=false` / `divRoundingUp` branch is simply *absent*, not merely unexercised, and no test can currently detect the gap. |
| That rounding direction is negligible | True only in the current fixture regime (price≈1, L=1e18, 18 decimals). Dominant at low ticks, thin liquidity (`L < 1e12`), and any non-18-decimal token. |
| That a `gdxdiff` non-zero rc identifies *what* went wrong | Return codes are known: **0** identical, **1** different, **2** no args, **3** missing file. `rc != 0` is retained as the conservative predicate, and the note that it **conflates a stale fixture (1) with harness misuse (2)** ships in `model/test/README-gdxdiff.md`. |
| That a `THEOREM`-tier green and an `INFERENCE`-tier green may be summed into one number | VOL-00. `vol_markets` is import-disjoint from `exp/`, so bridge assertions are strictly weaker evidence than ported theorems. Counts are reported per tier and never totalled. |
| That the M6a **shape block** `(β, γ)` has a maximum | It does not. The bound is approached only as `β → −∞`, with a **strict gap at every finite β** — a saturation boundary, not a maximum (`flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`, `Theta_lambda_identification`). A naive NLP will drive β to a bound and report that bound as the optimum. PROG-03 asserts the limit and guards the trap; it does not solve. |
| That **strict convexity establishes existence** | It does not. Strict convexity gives **uniqueness *given* existence** — `exp` on ℝ is strictly convex and attains no infimum. Rev 4's PROG-00 taxonomy listed strict convexity as a fact "that makes its extremum exist": the standing rule written to stop a solver reporting a bound as an optimum contained that exact error in its own definition. Only compactness+continuity, or coercivity+closedness, licenses a `Solve`. |
| That a certified extremum is the point CONOPT returned | Existence licenses *solving*; it does not establish that the returned point **is** the certified extremum. `mevMulti_exists_min_compact` requires only `IsCompact Θ` and `Θ.Nonempty` — **no convexity of Θ** — and CONOPT is a local solver. PROG-00(c): multi-start from committed distinct initial points, all reaching the same value at a declared tolerance. |
| That GAMS floating point can carry a Q64.96 value | Measured: at ~7.9e28 the double spacing is **2^44 ≈ 1.759e13**, so a 97-bit `sqrtPriceX96` retains 53 bits and its **low 44 bits do not exist**. Emission fails two ways above `2^53`: `2^96` prints as `7.922816251426434000E+28` (scientific, not EVM-consumable) and `12345678901234567` prints as `12345678901234568` — **silently off by one**. Any Q96 reference must be a **committed exact table generated outside GAMS**, indexed by `tick`. This binds REPR-10 and VPATH-13 to *one shared artifact*. |
| That the volume path is a *solving* problem, or that residual freedom is a defect | VPATH-05. `N` is a **fixed input**; the program is **generation**. `N+1` quantities against two terminal conditions leaves residual freedom, which is **expected** and must not be closed by an invented objective. If a selection rule is later wanted it is added deliberately and named. |
| That a solved parameter is a deliverable before it is shown EVM-expressible | PROG-05. A solution outside the representation kernel's declared scales and bounds **fails the program and is never rounded into range**. The layering is formalize (Lean) → solve (here) → implement (Plank); a value Plank cannot represent has not been solved for. |
| That M6a's degeneracy and Phase 3's `Δᵢ·η` degeneracy are the same phenomenon — **or that they are different** | The relationship has **not been established**, in either direction. Recorded as two separate phenomena. Asserting a link is new work, not a restatement. |
| That any phase delivers a pipeline over *real* on-chain data | The indexer — the component that reads logs by `topic0` and emits the GDX this model loads — is **UNOWNED AND UNBUILT**, and `topic0` appears nowhere in this plan. Every DATA and VOL criterion is stated against DATA-10's fabricated series. A criterion implying live ingestion is a claim about a component nobody owns. |
| That an assertion which has never been observed to fail is evidence | TEST-08. Four instances measured: the three grep gates; the `spec-preflight` sorry scan (nothing to find); the tautological `Δᵢ⋆` bridge; and the `zeroTolerance` checks, whose measured residual `1.73334e-33` against `1e-20` would still pass under an error **2.4 million times larger**. |

## Known uncertainty — carried, and now instrumented

> **Every degeneracy experiment used a CONSTANT η̃-measure `w`** (matching
> `ComparativeStatics`'s `fun _ => θ.w`). `continuous_J`'s `hw` hypothesis was therefore
> trivially satisfied. **If `w` becomes state-dependent, the `Δᵢ·η`-only dependence — and
> with it the entire 62-tie analysis, the SOLVE-05 scoping, and the IDENT-01 conditional —
> may not survive.**

Rev 1 recorded this as prose, which is decorative. It is now a **tripwire** (M6): Phase 3
ships `make check-wstate`, backed by a committed pin file `model/spec-pins/wstate.pin`
holding (i) the sha256 of `lean4-spec/exp/ComparativeStatics.lean` and (ii) the occurrence
count of `fun _ => θ.w` in it. The target reddens when either moves, and the Phase 3 solve
unit records both values in its provenance GDX. When the premise moves, the build tells us
instead of a comment hoping someone remembers. Tracked as v2 item **WSTATE-01**.

## External dependency posture

The DATA phase consumes a producer contract pinned to `cfmm-replicationPlank@d34846c`,
which lives on `feat/plank` and is **NOT merged to develop**.

| Producer surface | State | Consumed by |
|---|---|---|
| E1 `VolOrderCreated` (σ²_K via `.strike`), E3 `TimepointWritten`, E4 `FeeConfigurationChanged` (Θ_φ), E6 `WindowChanged` | **LIVE, topic0 pinned** | E3/E6 → DATA-02/03/05/07; **E4 + E1.strike → DATA-11** *(new in rev 3 — previously unconsumed)* |
| E2 `PortafolioMinted` (ξ⋆, ι, L̄, tokenId) | **SPEC-ONLY** — plank task #14 | REPR-07's normalizer question; DATA-09's σ²_K↔pool linkage; VOL-05's ξ⋆ if it is consumed |
| E5 `FeeApplied` (σ, φ) | **SPEC-ONLY** — plank task #16 | DATA-09's join rule |
| **The indexer** — reads logs by `topic0`, emits the GDX | **UNOWNED AND UNBUILT** | Any use of *real* data — i.e. nothing in v1 |
| `gams-gate` GitHub environment | **Exists** — auto-created 2026-07-27 by the first workflow run, not created deliberately — with **0 protection rules** and **0 runners** | GATE-06 |

**No phase success criterion depends on E2, E5, or the indexer existing.** DATA-10's
fabricated-series fixture is explicitly designed to prove the interface with no subgraph
present, so Phase 4 is gated on Phases 0/1/2 only — never on the external merge. The pin is
enforced by `make check-datapin`, not by memory.

Two requirements are genuinely **constrained by external state**:

- **REPR-07** is *blocked*: the normalizer question (`E2.liquidityBar` raw `uint128` count vs
  normalized Q128.128) is open on cfmm-gams#1. Phase 1 does not guess; see its criterion 5.
- **DATA-11** ingests from two **LIVE** events whose *emitter nobody has built*. Its
  acceptance is therefore "fabricated E4/E1 rows satisfying the §4 field→symbol→scale table
  load into named symbols and convert correctly" — **never** "we ingested live fee config".
  The events being live means the schema is fixed, not that the data arrives.

## Judgement calls made during roadmapping

**1. VOL-01..09 is split across three phases, not held as one.** Justification is the
dependency graph, verified from the Lean `import` lines:

```
L0:  PosSpec(12)   Main(7)          (both import only Mathlib)
        │            │
L1:  Flow(12) ◄──────┘ (via RiskDesign)     (Flow imports only PosSpec)
      ├──────┬────────┬──────────┐
L2:  RiskDesign(21) GeomProfile(11) Panoptic(8)
        │                              │
L3:  FeeSchedule(24)              Upsilon(3)
        └──────┬───────────┬──────────┘
L4:        VolInstrument(36)
              │
L5:      FlairOptimization(15)   ← VOL-10: where the solved programs live (Phase 8)
```

- The graph has **topological depth 5**. One phase would hide five sequential sub-stages
  behind a single success criterion.
- **`Flow` is the articulation point** — out-degree 4 (RiskDesign, GeomProfile, Panoptic,
  Upsilon), independently verified. Everything below L1 is worthless if the GAMS↔Lean
  bridge pattern is wrong there. Cutting after Flow discovers a bad bridge at 31 theorems
  instead of at 71 or 134.
- **`VolInstrument` is a convergence node with in-degree 4** — likewise verified. It cannot
  begin until four independent branches land. That is a synchronization point in the graph.
  **Rev 1 also justified this cut with the demo-license ceiling; that clause is struck** —
  it is vacuous (see the binding table). The in-degree-4 argument stands alone.
- **`Upsilon` is the cross-phase semantic hook**: it consumes Phase 4's realized variance
  and carries Phase 3's spike result. Its routing must be visible at roadmap level.

Result: 31 / 67 / 36 theorems across Phases 5 / 6 / 7 — **plus 15 at L5 in Phase 8.**
*Rev 4 extends the graph by one level.* `FlairOptimization` sits below `VolInstrument`, and
rev 3 read that as "downstream, therefore v2". It is downstream *and* it is the deliverable.
There are now three cuts: `Flow` (articulation point), `VolInstrument` (convergence node), and
**the port/solve boundary at L5** — below which GAMS stops verifying theorems and starts
solving programs.

**2. M5 — the largest design unknown is pulled forward, and a false blocking edge is cut.**
Rev 1 scheduled the pricing-kernel↔volatility bridge — which its own flag called
"unspecified" and "the phase's real risk" — sixth, behind Phase 4. That was wrong twice.

- *The blocking edge was false.* Verified from imports: `PosSpec` and `Main` import only
  Mathlib; `Flow` imports only `PosSpec`. And no Phase 5 criterion references moments,
  `rv_bar`, or `degeneracyBreaks` — nothing in Phase 5 consumes Phase 4 or Phase 3.
  **Phase 5 now depends on Phase 2 only** and runs in parallel with 3 and 4.
- *The design is pulled forward.* VOL-0A (the B5 split test) and the bridge **design**
  spike are Phase 5's first plan, each with an explicit **INVALIDATED-able outcome** — a
  result that stops the port rather than decorating it. The real join is Phase 6, where
  `Upsilon` consumes Phase 4's moments contract and Phase 3's verdict orders the plans.

*Rev 3 confirms and sharpens the Phase 6 join.* Phase 6 now carries **two independent edges
from Phase 4**, not one: `Upsilon` (VOL-08) consumes the DATA-03/DATA-07 moments layer, and
`FeeSchedule` (VOL-07) consumes DATA-11's Θ_φ and σ²_K. The Phase 4 → Phase 6 dependency
asserted in rev 2 was correct, and is now load-bearing for **two of Phase 6's five modules
rather than one** — if Phase 4 slips, 45 of Phase 6's 67 theorems are blocked, not 3. That
is an argument for Phase 4 holding its schedule, not for re-cutting the phases. Phase 5
remains free of any Phase 4 edge: VOL-01/02/03's provenance is TBD and is resolved *within*
Phase 5 by VOL-0B, with `none (pure theorem, symbolic parameters only)` an allowed answer.

**3. REPR-10 lives in Phase 1, which is why Phase 1 is the largest phase.** REPR-10 is the
Core Value made executable, and rev 1 had it in **no requirement at all**. It belongs with
the representation kernel because it *is* the representation question: today `sqrtPX96_at`
is `P_Lean_at` with the exponent halved, both reading the single `lambda` scalar in
`PricingKernel.gms`, and every source call site passes `lambdaWad` — so the "dual
representation" is common-mode and cannot detect a wrong λ. Its tolerance is retrofitted
onto `kernelTol(n)` in Phase 2 along with the two existing theorem units; that is a
consumer relation, not a second mapping.

**4. REPR-09 (the 53-bit rule) stays in Phase 1, as its first plan.** REPR-01 (`$eval`
forbidden) and REPR-06 (`= INF` guards useless) are its *corollaries*, not its peers.
Its enforcement rides on Phase 0's lint harness, so Phase 0 ships an extensible rule
**table** rather than hard-coded greps.

**5. M7 — 3∥4∥5 contention is designed out, not managed.** Three phases now run in
parallel over three shared mutable files. All three become append-only-by-convention, so
concurrent edits merge line-wise:

| Shared file | Rev 1 shape | Rev 2 shape |
|---|---|---|
| Root `Makefile` | every phase edits it | Phase 0 adds **one** `-include mk/*.mk` line, permanently; each phase ships `mk/phaseN.mk` |
| Lint rules | a "rule table" inside the harness | `model/lint/rules.tsv`, one rule per line (id, severity, pattern, message) |
| Test registry | a registry the phases edit | `model/test/registry.tsv`, one entry per line |

**7. VOL-0B goes to Phase 2 with VOL-00, not to Phase 5 with VOL-0A.** Flagged as a
judgement call; three things decide it.

- *It is registry schema, and Phase 2 owns the registry.* VOL-0B is a `provenance` column in
  `model/test/registry.tsv` plus a `rules.tsv` rule reddening an undeclared parameter —
  structurally identical to VOL-00's `tier` column, in the same file, enforced by the same
  mechanism. Adding a column after the port opens means retrofitting entries, which is
  precisely the failure mode Phase 2 exists to prevent.
- *It has a pre-Phase-5 consumer — the same argument that moved VOL-00.* Phase 4's
  **DATA-11** registers itself as the producer for VOL-07's Θ_φ row and is the **first entry
  to use the column**. If the mechanism does not exist when Phase 4 runs, DATA-11 ingests
  symbols with nowhere to declare who consumes them, and the gap this requirement exists to
  close reopens on the next module.
- *VOL-0A is a different kind of object.* VOL-0A is a one-off investigation with a pass/fail
  verdict that opens or closes the port, so it belongs where the port opens. VOL-0B is a
  **standing lint that must already be running when the first module is written**.

Phase 2 owns the mechanism and the lint. **The declarations themselves are made per-module
in Phases 4–7** — consumer relations, not second mappings. The requirement text is honest
that VOL-01..06's provenance is **TBD**: only VOL-07 (E4 Θ_φ + E1.strike σ²_K), VOL-08 (the
DATA-03 moments layer) and VOL-09 (inherited) have contract-stated provenance today, and
VOL-0B's job in Phases 5–7 is to force every remaining module to resolve TBD to an E-number
and §4 row, or to an explicit `none (pure theorem, symbolic parameters only)`, **before** it
is ported.

**8. VOL-10 and PROG-01..06 collapse into ONE phase (Phase 8), not two.** The alternative —
a phase that ports `FlairOptimization` and a later phase that solves over it — was considered
and rejected:

- **The programs cite the module's theorems by name.** `flairMulti_le_corner`,
  `flairMulti_corner_attained_levels`, `flairMulti_saturation_limit`,
  `flairMulti_strict_below_saturation`, `flairMulti_exists_max_compact` and
  `Theta_lambda_identification` are the certificates PROG-01..04 declare. Nothing can be solved
  before they are ported, and once ported there is nothing else to do with them.
- **A port-only phase would have no deliverable.** Its success criterion would be "15 more
  theorems green" — a horizontal layer, the anti-pattern this roadmap has avoided at every
  other cut.
- **The risk that argued for splitting is preserved inside the phase.** If VOL-10's theorems do
  not say what the PROG requirements assume, we must stop before building programs on them.
  That is Phase 8's **first plan** and its gate: a **census** — not a 10-of-134 sample — of all
  six cited theorems, recorded in `model/spec/PROG_CERTIFICATES.md`. Any theorem whose intended
  use is stronger than its conclusion stops the corresponding program, which then falls under
  PROG-03's assert-only discipline. That is the stopping power of a separate phase without the
  empty phase.

**9. Where the three standing PROG rules live.**

| Requirement | Phase | Why |
|---|---|---|
| **PROG-00** (non-degeneracy certificate) | **2** | It is a **third `registry.tsv` column** beside VOL-00's `tier` and VOL-0B's `provenance`, plus a lint reddening a `Solve` whose cell is blank — same mechanism, same file. And it has a pre-Phase-8 consumer: **Phase 3's SOLVE-04a/04b** are exactly a certificate question (a value the theorem bounds vs coordinates it does not). The argument that moved VOL-00 and VOL-0B moves this. |
| **PROG-06** (monotonicity signs) | **8**, as its *second* plan | The signs are specific to λ_ARB, so no earlier phase can host them — but the instruction is that it must *gate* a solve, so it lands **before** PROG-01/02/04 rather than after. It is also checkable with **no solver at all**, by finite differences on the objective, which is what makes it cheap enough to gate. |
| **PROG-05** (EVM-expressible) | **8** | Its named units — pips for φ̄ and α, Algebra vol units for β and γ — are the *program's* parameters, which do not exist before Phase 8. The **macro** (`assertEvmExpressible`) ships in Phase 2's `_AssertLib` and is applied opportunistically to Phase 3's solve; that is a consumer relation, the same pattern as GATE-03's `assertModelOptimal`. |

**10. Phase 9 (IDENT-01) is NOT promoted, deliberately.** Making solving the deliverable is a
superficial argument for pulling coordinate identification forward. It stays conditional and
stays last, because the instruction behind the reframing was **non-degenerate first** —
degeneracy work waits until the lean4-spec worktree constrains the problems. Promoting it would
invert the principle that produced this revision.

**11. The volume-path work is TWO phases (10 and 11), cut at a measured representational
cliff.** Justified from structure, the way the 31/67/36 VOL split was:

```
  VPATH-06/07/10  shock decode + reference constants
        │
  VPATH-01/02     recursion (reuses priceImpactKernel_Add0) + swap-sign constraint
        │
  VPATH-12/08     closure as ONE LINEAR equality  Σ ΔQ_X(n) = 0   ← the model's articulation point
        │
  VPATH-03/04/05  functionals, terminal targets, fixed-N generation
  ═══════════════ PHASE 10 │ PHASE 11 ═══════════════  ← the representational cliff
  VPATH-13/14     exact tick-indexed Q96 table + exact-integer quantities
        │
  VPATH-09/11     JSON schema + replay/diff
```

- **The cut is a measured cliff, not a stage boundary.** Everything above it lives in GAMS
  doubles and tick space; everything below must be **exact integers**. VPATH-13/14 exist
  *because* that boundary is real: `2^96` emits as scientific notation and
  `12345678901234567` emits off by one. A phase that spanned it would have half its criteria
  stated in a number system the other half cannot represent.
- **VPATH-12 is Phase 10's internal articulation point.** The recursion is *affine in reciprocal
  coordinates* — `1/p(n+1) − 1/p(n) = ΔQ_X(n)/L̄`, measured deviation **0.000** — so
  telescoping gives `p_N = p_0 ⟺ Σ ΔQ_X = 0`. Closure costs **one linear equality** instead of
  a nonlinear boundary condition, and the recursion never needs inverting. Measured both ways:
  `Σ = −1e17 → p_N = 1.1111…` (open); `Σ = 0 → |p_N − p_0| = 0.00000000000000` (closed). The
  whole phase's tractability rests on it, so its plan lands before the functionals.
- **Not split further.** Decode-without-a-model and emit-without-a-replay are both horizontal
  layers whose success criterion would be "a file exists". Three or four phases here would
  reproduce the anti-pattern this roadmap has refused at every other cut.

**12. Where the three requirements added by the Lean refresh go.**

| Requirement | Phase | Why |
|---|---|---|
| **VOL-11** `MevOptimization` (22 thm) | **8**, first plan | It depends on `FlairOptimization` (VOL-10, Phase 8), so it *cannot* precede Phase 8 — and **PROG-01/04/06 rest on it**, so it must precede the programs. Inside Phase 8, ahead of them, is the only topologically consistent placement. |
| **VOL-12** `EndogenousMaturity` (34 thm) | **7**, not 8 | It depends on `VolInstrument` + `Main`/`Flow`/`GeomProfile` — all landed by Phase 7 — and **feeds no PROG requirement**. Putting 34 theorems with no program consumer inside the deliverable phase would dilute it; Phase 7 becomes the post-convergence port (70 theorems) and Phase 8 stays pure. |
| **PROG-07** (MevOptimization's three limitations) | **8**, with VOL-11 | They are *that module's* self-declared limitations, and unlike PROG-00 they have **no pre-Phase-8 consumer** — Phase 3's solve is not λ_ARB. They land with the module whose docstring states them. |

**13. Phases 10–11 are unblocked after Phase 2, but scheduling them there is not recommended.**
The *edges* are real: VPATH depends on Phase 0 (GATE-05), Phase 1 (REPR-10's table, REPR-03/09's
widths, `priceImpactKernel_Add0`) and Phase 2 (TEST-02's tolerance rule) — **and on nothing in
Phases 3–9**. So they could join the 3∥4∥5 parallel set. The recommendation is to run them after
Phase 8 unless the volume path is independently urgent: the parallel set is already three phases
wide, and the M7 machinery (`mk/*.mk`, append-only `rules.tsv`/`registry.tsv`) is what makes
either choice safe rather than a merge-conflict generator. The numbering reflects when the work
was scoped, not a dependency.

**6. Deviation from the granularity band.** `standard` implies 5–8 phases; this roadmap has
12 (0–11). Eleven are committed work; Phase 9 is conditional and may close as INVALIDATED
without a single plan. Both reviewers independently endorsed the 9-phase structure and the two
graph cuts; rev 4 adds exactly one phase, and it is the one that carries the deliverable. The
overage is now substantial and is stated plainly rather than argued away: **this is a
**twelve**-phase project wearing a `standard` granularity setting, carrying two deliverables
(the convex programs, and the volume path) over a 205-theorem substrate. Compressing would mean
merging Phase 8 into 7 — a 70-theorem port and four convex programs behind one success
criterion — or collapsing a measured cut. Granularity is compression guidance, and this project
has outgrown the band it was configured with; that is stated rather than hidden. Several phases also carry 6–7 success criteria rather than the usual 2–5;
that is deliberate, because the review's finding was that rev 1's criteria were too few and
too coarse to be falsifiable.

## Phases

**Phase Numbering:**
- Integer phases (0, 1, 2…): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 0: Honest gates** - Make every build gate capable of failing, and make "capable of failing" a committed, re-running artifact
- [ ] **Phase 1: Representation kernel + the executable dual-representation spine** - One canonical definition of every scale, bound and set; the 53-bit rule; and the Core Value made executable
- [ ] **Phase 2: Test architecture** - The assertion vocabulary, tolerance policy, epistemic tiers, parameter-provenance schema, and the mutation-proof rule — proven before 134 units inherit them
- [ ] **Phase 3: The (Δᵢ, η) solve** - Value, product, ties, and the γ=0 corner split into THEOREM and INFERENCE tiers *(parallel with 4 and 5)*
- [ ] **Phase 4: Moments / ingestion** - Two independent ingestion legs — the E3/E6 moments chain and DATA-11's E4/E1 fee-config-and-strike leg — over a source that compiles absent and *refuses* at execution time *(parallel with 3 and 5)*
- [ ] **Phase 5: Port foundation** - The split test, the bridge design, then PosSpec/Main/Flow (31 theorems) *(parallel with 3 and 4)*
- [ ] **Phase 6: Instrument mechanics** - RiskDesign, GeomProfile, Panoptic, FeeSchedule, Upsilon (67 theorems) — where 3, 4 and 5 join
- [ ] **Phase 7: VolInstrument + EndogenousMaturity** - The in-degree-4 convergence node plus the leaf below it (70 theorems); port reaches 168/168 — the gateway to Phase 8, not the endpoint
- [ ] **Phase 8: The convex programs** - Port `FlairOptimization` + `MevOptimization` and SOLVE the two programs with certified existence (M5, M6a levels); assert-only the other two — **this is the first deliverable**
- [ ] **Phase 9: Coordinate identification (CONDITIONAL)** - Opens iff Phase 3's spike broke the degeneracy; otherwise closed as INVALIDATED
- [ ] **Phase 10: Shock contract + the volume-path model** - Decode the shock and generate a feasible length-`N` swap path; closure is one linear equality
- [ ] **Phase 11: EVM-unit emission and replay** - Cross the representational cliff: exact-integer JSON from a committed Q96 table, then diff the replay — **the second deliverable**

## Phase Details

### Phase 0: Honest gates
**Goal**: Every build gate is capable of failing, and that capability is itself a committed artifact that re-runs forever rather than a mutation someone once performed by hand.
**Depends on**: Nothing (first phase — and it blocks every other phase)
**Requirements**: GATE-01, GATE-02, GATE-03, GATE-04, GATE-05, GATE-06, GATE-07, TEST-09
**Success Criteria** (what must be TRUE):

  1. **TEST-09 — the negative-control substrate exists.** `model/test/_mutants/` holds
     committed deliberately-broken fixtures and `model/test/_mutants/registry.tsv` lists
     one per line with its target and expected non-zero rc. `make negative-controls` runs
     every entry and **exits non-zero if any mutant passes** (or if any registered
     positive control fails). Every "X reddens when Y breaks" claim anywhere in this
     roadmap is an entry in this registry — that is what makes it re-runnable rather than
     one-shot. The registry is append-only, one entry per line (M7).

  2. **GATE-01 — the three false-pass targets gate on exit codes only.** `payoff-fixtures`,
     `spec-preflight` and `spec-preflight-band` use `if $(GAMS) …; then`, the idiom that
     `compile-gams`/`test-gams` already use correctly; the `;` before `if` is gone. **No
     `grep` appears in a pass/fail position in any of the three** — `make lint-make`
     reddens on a grep-derived predicate in a gating position, and grep is retained only
     for extracting the error text into the failure message. This is the resolution of the
     circularity objection (B1a): the repair does not depend on the idiom that produced the
     bug, and exit codes are *proven sufficient* — gams returns rc=2 on compile error and
     rc=3 on abort, measured. Three committed mutants (one per target) redden all three on
     every `make negative-controls` run (B1b). The `Status: (Compilation|Execution) error`
     string is a **log-stream** artifact that `lo=0 >/dev/null` destroys and that never
     appears in the `o=` listing at any `lo` value; it is demoted accordingly.

  3. **The three repaired recipes are shell-reviewed by a third instrument (B1c).**
     `make lint-make` extracts each gating recipe body via `make --print-data-base` and
     runs `shellcheck -s sh` over it, exiting non-zero on the SC2181 (`$?` misuse) and
     SC2015 (`a && b || c`) classes; each recipe declares `set -e` at its head. This is a
     committed target, so the review re-runs — it is not a one-time reading. **This phase
     also lands the concurrency substrate (M7):** the root `Makefile` gains a single
     `-include mk/*.mk` line, permanently, and no later phase edits the root Makefile again.

  4. **GATE-02 + GATE-04 — the lint harness is a data file, not a fork point.**
     `make lint-gams` reads `model/lint/rules.tsv` (one rule per line: id, severity,
     pattern, message) and exits non-zero on any source containing `abort.noError` (halts
     silently at rc=0 with no status line), a bare `execute` without
     `execute.checkErrorLevel`, a `$call` without `$call.checkErrorLevel` or
     `$onCheckErrorLevel` — the two are covered separately because `$onCheckErrorLevel`
     governs `$call` only, **not** `execute` — any `$onMulti*` (silently replaces at rc=0),
     or an assignment to `execError`. It exits 0 on the current tree. Each rule ships a
     mutant in the TEST-09 registry. Later phases add **lines**, never code.

  5. **GATE-03 — every `Solve` asserts `solveStat` in addition to `modelStat`.** Corrected:
     rev 1 claimed `modelStat=19` at rc=0; that is **unreproducible** (baseline modelStat 2
     at rc=0; injected infeasibility modelStat 4 at rc=3), and **both existing `Solve`s
     already assert `modelStat`** (`band.gms:119`, `zero_slippage.gms:90`). The real gap is
     a solver terminating **abnormally** while reporting an acceptable `modelStat` — that
     passes today. Two legs: (a) a committed `option iterlim = 0` mutant on the band unit
     must redden, registered in TEST-09; (b) a `rules.tsv` rule reddens any `Solve` not
     followed by assertions on **both** status codes.
     **UNVERIFIABLE-LEG:** I cannot name a committed input that provably degrades
     `solveStat` while leaving `modelStat` acceptable — that combination is the hypothesis,
     not something I measured. Leg (a) therefore proves the assertion pair fires; leg (b),
     a static rule, is what guarantees coverage. Recorded rather than papered over.

  6. **GATE-05 — fixture freshness, scoped honestly.** `make check-fixtures` regenerates and
     `gdxdiff`-compares the **two** payoff fixtures that `payoff-fixtures` can actually
     produce, keyed on `rc != 0`; `model/test/README-gdxdiff.md` records the return-code
     table (0/1/2/3) and the conflation of stale-fixture with harness-misuse. A hand-edited
     fixture mutant reddens it, registered in TEST-09.
     **UNVERIFIABLE-LEG:** `model/price_impact_kernel.gdx` has **no regeneration path at
     all** — `payoff-fixtures` globs only `payoff/eta_*.gms`. This phase either funds a
     producer in a plan or records it in `model/fixtures/UNVERSIONED.md` as knowingly
     unversioned. Until one of those happens, it is not covered by this criterion, and
     `lint-gams` reddens any *new* committed `.gdx` that has no producer.

  7. **GATE-06 + GATE-07 — the gates are reachable and can fire.**
     *Reachability:* `make ci-selftest` runs `gh api …/environments/gams-gate --jq
     '.protection_rules|length'` and the runner-count probe, exiting non-zero if either is
     0. Measured today: the environment **exists** — auto-created 2026-07-27 by the first
     workflow run, not created deliberately — with **0 protection rules** (the approval job
     completed in 2 s and gates nothing) and **0 runners** (the only run ever was cancelled
     after 24 h). The work is therefore **configuring an environment that already exists**,
     not creating one; a plan that opens by creating it will find it already there and must
     not read that as the criterion being met. **Ordering is load-bearing: protection rules are added BEFORE a runner is
     registered** — a public repo with a self-hosted runner and an inert gate is the fork-PR
     arbitrary-execution scenario. *(The "one workflow run reached the `gams` job and
     completed" leg is one-shot by nature; the run id is recorded in
     `.planning/ci-evidence.md`. The two `gh api` probes are the standing, re-running gate.)*
     *Firing:* `make lean-sorry-check MODULE=<file> THEOREM=<name>` handles arbitrary
     indentation and namespace nesting, with a committed negative control
     (`model/test/_mutants/lean/SorryFixture.lean` — an indented, namespaced theorem with a
     real `sorry`) that must redden, and a positive control over an indented namespaced
     `vol_markets` theorem that must pass. Measured: the existing gate's column-0-anchored
     `grep -nE "^theorem $ID"` matches **zero** of the 134 namespaced `vol_markets` theorems,
     and its column-0 `awk` body extraction would attribute a later `sorry` to the wrong
     theorem. The repaired gate is wired into every target that claims proof gating —
     including `spec-preflight`, which performs **no Lean grep at all** today.

  8. **Baseline preserved, with the count annotated.** `make compile-gams` still reports
     12/12 and `make test-gams` 4/4 after every change above.
     **Annotation:** the 12 includes `model/PricingKernelMoments.gms`, a **known silent
     no-op** — it compiles at rc=0 while computing nothing (`Set TimeWindow` is legally
     closed by EOF; the space before `(` makes GAMS read a zero-argument *text* macro). Its
     being counted OK is the canonical false pass in this repo. This criterion pins
     regression, not correctness, and **must not be read as making 12 a goal** — Phase 4
     replaces that file and the count is expected to change.

**Plans**: 4 plans, serial (waves 1-4; each registers into the substrate the previous one landed)

Plans:
- [ ] 00-01-PLAN.md — TEST-09 `_mutants/` + `make negative-controls` + the permanent `-include mk/*.mk` point *(wave 1, TEST-09)*
- [ ] 00-02-PLAN.md — exit-code-only gating in the three targets + the `lint-make` shellcheck leg *(wave 2, GATE-01)*
- [ ] 00-03-PLAN.md — `rules.tsv` lint harness with the GATE-02/GATE-04 rules; `solveStat` assertions + LINT-06/07 *(wave 3, GATE-02/03/04)*
- [ ] 00-04-PLAN.md — `check-fixtures` + gdxdiff rc table; `ci-selftest` + protection rules; namespaced `lean-sorry-check` *(wave 4, GATE-05/06/07; NOT autonomous — carries the runner checkpoint)*

### Phase 1: Representation kernel + the executable dual-representation spine
**Goal**: Every scale, bound and set has exactly one definition, and the Core Value stops being a comment — an EVM-coordinate evaluator that does not derive from the Lean one, with a real agreement assertion between them.
**Depends on**: Phase 0
**Requirements**: REPR-01, REPR-02, REPR-03, REPR-04, REPR-05, REPR-06, REPR-07, REPR-08, REPR-09, REPR-10, REPR-11
**Success Criteria** (what must be TRUE):

  1. **REPR-09 + REPR-01 — one definer, and the 53-bit rule stated once.**
     `model/Scales.gms` is the **sole definer** of every scale, bound and menu, and states
     the 53-bit mantissa rule once as a named constant — **this is the first plan of the
     phase**, because REPR-01 and REPR-06 are its corollaries and stating it after them
     would be re-deriving a general rule from two of its instances. A `rules.tsv` line
     reddens any scale constant defined elsewhere or via `$eval`/`$set`/decimal literal;
     an executable assertion shows `$eval 2**96` and `power(2,96)` differ by exactly
     `2^45`. Committed mutants for both directions.

  2. **REPR-06 — both overflow regimes, each with its own control.**
     `SATURATION_SENTINEL` is declared once in `Scales.gms` and **re-derived from
     `exp(1000)` at build time**, and checked **against a committed pin**, not against itself.
     **N3 — a regression rev 4 introduced, corrected here.** Rev 4 wrote the guard as
     `abort$(SATURATION_SENTINEL <> exp(1000))`, which is a **tautology**: both sides recompute
     the same expression, measured rc=0, and it can never fire. That is precisely the
     `diStarPlankReal` defect this roadmap catalogues two criteria later — written into a new
     criterion by the same author who catalogued it. The working pattern already exists in this
     document: `model/spec-pins/saturation.pin` records the **measured** value, and
     `make check-saturation` asserts the build-time `exp(1000)` **against the pin**, exactly as
     `check-wstate` asserts against `wstate.pin`. A committed mutant that **edits the pin** must
     redden. The sentinel then cannot go stale across GAMS versions *and* the check can fail. `rules.tsv` reddens any `= INF` guard and any
     per-call-site saturation literal. Two committed mutants: **(a) loud regime** — `a*a`
     at `a=1e299` must redden at rc=3, a positive control on GAMS itself; **(b) silent
     regime** — `power(10,400)` returns `1.0000E+299` at rc=0 with `Normal completion`, and
     the magnitude guard against `SATURATION_SENTINEL` must catch it. Rev 1 banned the only
     working detector for (b); that ban is lifted in the single named form.

  3. **REPR-03 + REPR-05 — four named tick concepts and a two-level spacing domain.**
     int24 storage bounds / Uniswap usable range / derived sqrt-ratio bounds / the
     deployable menu are distinctly named; `abort$(INT24_MIN <> -(INT24_MAX+1))` runs
     green; `minTick` is **negative** (today `primitives.gms` declares `minTick /8388607/`,
     a positive minimum, alongside `maxTick /16777215/`); `LiquidityKernel.gms:36` no
     longer consumes the unusable bound. The spacing domain is parent `/s1*s200/` matching
     Lean's `Finset.Icc 1 200` plus a declared `tickSpacingMenu` subset `{1,10,60,200}`,
     with `tickSpacingVal` data-driven rather than `ord(d)`. `tunablePricingKernel`
     evaluates at **Δᵢ = 200** at rc=0 — today inexpressible (`PricingKernel.gms` declares
     `Set tickSpacingDomain /s1*s60/`), which makes the `riskNeutral_corner` corner
     unreachable. Committed mutant: restoring a positive `minTick` reddens.

  4. **REPR-02 + REPR-04 — one η, one bridge, and co-compilation.**
     `TradingRegion.gms` and `PricingKernel.gms` co-compile in one unit at rc=0 with a
     single reconciled `inventory` set (`/assetX, cashY/` vs `/X, Y/`) and **no `$onMulti*`
     anywhere**, lint-enforced from Phase 0's rule table. η has one canonical representation
     with one named bridge, and a **tick-sensitivity** assertion exits non-zero when η is
     read through the wrong scale — today the WAD-as-Q0.128 collapse to a flat,
     tick-independent `λ^0 = 1` kernel passes every positivity assertion in the repo.
     Committed mutant: the scale swap must redden.

  5. **REPR-08 + REPR-07 — provenance that means something, and the L̄ question settled or
     recorded.** Every symbol in an `execute_unload` list carries a registered mutation
     proof in the TEST-09 registry — **not** a read-existence lint, which is already gamed
     (`inputs('etaQ128') = etaQ128;` is a pure copy, and `sqrtPX96_at` hard-codes its
     exponent divisor as the literal `2`, so the model structurally cannot vary η).
     `etaQ128` either acquires a mutation proof or leaves the fixture; `tieBreaking` — zero
     assignments, zero `abort$` — leaves. TEST-08's *lint* lands in Phase 2; Phase 1 ships
     the same evidence via the registry.
     **REPR-07, corrected:** `LbarQ128` and `DICfgQ128` are **not both `2^128`** — each unit
     sets exactly one to `2^128` and the other to `2^128/10`, swapped between units
     (`zero_slippage` L̄=1/Δ^I=0.1; `band` L̄=0.1/Δ^I=1.0). If these are genuine Q128.128
     encodings then `2^128` correctly encodes `1.0` and **there is no overflow** — the
     earlier "one greater than uint128 max" framing conflated a fixed-point encoding with a
     raw count. **BLOCKED on cfmm-gams#1** (`E2.liquidityBar` normalizer). If unanswered at
     execution time, this leg is met by recording both candidate readings in
     `model/Scales.gms` and shipping an `abort$` that fires when a unit assumes either
     without declaring which — **not** by guessing.

  6. **REPR-11 — the absent branch is made detectable.** `assertAdd0Branch` is restored to
     the assertion vocabulary (it was dropped from a macro list otherwise copied verbatim
     from the research). `priceImpactKernel_Add0` either covers both EVM branches, or its
     single-branch scope is asserted and the other branch's absence is detectable: a
     committed input in the `add=false` / `divRoundingUp` regime — reachable at the top of
     the tick range — must **redden** rather than silently returning the
     `mulDivRoundingUp` value. Measured: the macro contains **zero conditional operators**.

  7. **REPR-10 — the Core Value, made executable.** Three committed legs:
     **(a) Immediate, cheap, and today missing entirely.** `piGridPlank` and `piGridLean` are
     compared across all **181 in-band points** of `bandGrid /1*200/`. Today both are
     computed and **never compared** — the number of band points carrying a
     cross-representation check is **zero**. After this leg it is 181. `B_ext` currently
     caps at Δᵢ=60 while SOLVE-04's corner is at 200, so the only existing
     cross-representation gate **cannot run where the flagship assertion targets**;
     extending the band to 200 is in scope here.
     **(b) The independent reference — DATA, not GAMS code.** *(Corrected in rev 5 by
     VPATH-13's measurement.)* Rev 4 specified `TickMathReplica.gms` as GAMS code implementing
     the EVM's integer/bit sequence. **That is not implementable in GAMS floating point**: at
     Q96 magnitude the double spacing is `2^44`, so a GAMS-computed "replica" would be limited
     by the same 53-bit mantissa it is supposed to check — common-mode again, one level down.
     The reference is therefore a **committed exact `tick → sqrtPriceX96` table**, generated by
     exact integer arithmetic **outside GAMS**, verified against `TickMath`, and regenerated by
     `check-fixtures`. It **does not read `lambda`** — a `rules.tsv` rule reddens any reference
     to `lambda`/`lambdaWad` in its producer — and agreement against `sqrtPX96_at`/`priceKernel`
     is asserted **in a space doubles can represent** (relative comparison, tick-indexed), never
     as exact Q96 equality. **This is the same artifact VPATH-13 requires** (Phase 11): one
     table, built here, consumed there. Without this the "dual representation" is common-mode:
     `sqrtPX96_at` is `P_Lean_at` with the exponent halved and an exact power-of-two
     scaling, both reading the single `lambda` scalar in `PricingKernel.gms`, and every
     source call site passes `lambdaWad` — so a wrong λ is invisible to both sides.
     **(c) The two documented bridges are retired as evidence.**
     `sqrtPX96 = √P_Lean·Q96` exists **only as a comment** (the sole `sqrt(` in the model,
     `_PayoffScaffolding.gms:21`) — it becomes executable or it is deleted.
     `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean` is a **tautology**: `zero_slippage.gms:18` assigns
     `diStarPlankReal = 2*diStarLeanReal`, and line 30 asserts on that same recomputed
     expression, so it cannot fire. It is replaced by an assertion whose two sides have
     independent derivations, with a committed mutant proving it can.

**Plans**: 6 plans

Plans:
- [ ] 01-01: `Scales.gms` + the 53-bit rule + `power(2,k)`-only constants
- [ ] 01-02: `SATURATION_SENTINEL` re-derivation + magnitude guards + both overflow controls
- [ ] 01-03: Four-concept tick bounds + two-level spacing domain + Δᵢ=200 reachability
- [ ] 01-04: η canonicalization, `inventory` reconciliation, tick-sensitivity assertion
- [ ] 01-05: Provenance mutation proofs; REPR-07 settle-or-record; `assertAdd0Branch`
- [ ] 01-06: REPR-10 — 181-point grid comparison; the exact `tick → sqrtPriceX96` **table** (generated outside GAMS, verified against `TickMath`, regenerated by `check-fixtures`, **shared with VPATH-13 in Phase 11 — one artifact**); bridge retirement. **Not** a `TickMathReplica.gms`: criterion (b) establishes that a GAMS-computed replica is common-mode at the same 53-bit mantissa it exists to check.

### Phase 2: Test architecture
**Goal**: The assertion vocabulary, tolerance policy, epistemic tiers, parameter-provenance schema and mutation-proof rule that every one of the 134 downstream units is born using — proven on the existing dozen assertions first, because retrofitting 134 files is the expensive path.
**Depends on**: Phase 1
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07, TEST-08, VOL-00, VOL-0B, PROG-00
**Success Criteria** (what must be TRUE):

  1. **TEST-01 — the macro library, complete.** `model/test/_AssertLib.gms` provides
     `assertApproxEqRel` / `assertApproxEqAbs` / `assertApproxEqClose`, `assertFinite`,
     `assertUintN`, `assertIntegral`, `assertModelOptimal`, **`assertAdd0Branch`**,
     **`assertEvmExpressible`** (the round-trip macro PROG-05 requires in Phase 8, shipped here
     and applied opportunistically to Phase 3's solve), and the sliding-window macro — printing both operands and the computed error on failure.
     (`assertAdd0Branch` is called out because rev 1 dropped it from a list otherwise
     copied verbatim from the research.) Each macro has a self-test committed under
     `_mutants/` and registered in `make negative-controls`: non-zero on a known-bad input,
     0 on a known-good one. Design is forced — `abort` accepts identifiers only, never
     expressions.

  2. **TEST-02 — tolerance is exponent-dependent.** `kernelTol(n) = max(3·1.101e-17·|n|,
     4/sqrtPX96, 1e-15)` ships, and the budget guard
     `abort$(|iCfg|·diMaxBand > diffTolerance/1.101e-17)` reddens a unit declaring a domain
     past exponent ≈90,800. A `rules.tsv` rule reddens any bare `1e-12` literal in a
     tolerance position. Committed mutant: a unit declaring an over-budget domain reddens.

  3. **TEST-03 — zero assertions at residual level, with a control that proves the policy
     changed something.** `absFloor(scale)` replaces the global absolute constant; a
     `rules.tsv` rule reddens any `abort$` whose argument comes from a macro whose body
     contains `sqr(`; a square that genuinely must be asserted uses a symbol *named*
     `zeroToleranceSquared`; every zero assertion has a **non-degeneracy companion**.
     The proof is one committed mutant: the measured residual `1.73334e-33` scaled by
     `1e6` **still passes** under the old `zeroTolerance = 1e-20` and **must redden** under
     `absFloor`. An error 2.4 million times larger passing is the defect; that mutant is
     what shows it closed.

  4. **TEST-08 — every `abort$` ships a registered mutation proof, retroactively.**
     `make test-mutations` runs them, and a `rules.tsv` rule reddens any `abort$` with no
     registered proof. Applied to **every existing `abort$` in the repo in this phase**, so
     the rule is proven on roughly a dozen assertions **before** 134 units inherit it. The
     four measured instances of assertions that cannot fail are each closed or explicitly
     waived with a recorded reason: the three grep gates (closed in Phase 0), the
     `spec-preflight` sorry scan (which scans for `sorry`/`admit` occurrences that do not
     exist repo-wide), the tautological `Δᵢ⋆` bridge (closed in Phase 1), and the
     `zeroTolerance` checks (criterion 3). This subsumes REPR-08's enforcement — a
     read-existence lint is gameable, a mutation proof is not.

  5. **VOL-00 — epistemic tiers are declared, and counts are never summed.** Every registry
     entry carries a tier: `THEOREM` (mirrors a proven Lean statement), `BRIDGE` (a
     GAMS-established link with **no** Lean counterpart), or `INFERENCE` (needs hypotheses
     the theorem does not carry). `make test-gams` prints the three counts separately and a
     `rules.tsv` rule reddens any registry entry lacking a tier, plus any report line that
     totals them. This exists because `vol_markets` is import-disjoint from `exp/`: the
     pricing-kernel↔volatility link does not exist in the formalization and is being
     *established* in GAMS, so those assertions are strictly weaker evidence than ported
     theorems. First consumed in Phase 3 by SOLVE-04a/04b.

  6. **VOL-0B — every ported module declares where its parameters come from.**
     `registry.tsv` gains a `provenance` column alongside `tier`: each entry names the
     producer field feeding each parameter — an **E-number and a §4 row** — or explicitly
     declares `none (pure theorem, symbolic parameters only)`. A `rules.tsv` rule reddens any
     ported module with an undeclared parameter, and a committed mutant that blanks one
     provenance cell must redden. This exists because the port was specified purely by Lean
     module and theorem count, which let a **LIVE** producer event sit unconsumed: E4
     `FeeConfigurationChanged` appeared exactly once in the entire plan, as a
     dependency-table row, with no requirement ingesting it — a gap **both reviewers
     missed**. Phase 2 owns the mechanism and the lint; the declarations are made per-module
     in Phases 4–7, and **Phase 4's DATA-11 is the first entry to use the column**.

  7. **PROG-00 — no program is solved without a non-degeneracy certificate.**
     `registry.tsv` gains a **third** column beside `tier` (VOL-00) and `provenance` (VOL-0B):
     `certificate` — the compactness, strict-convexity or corner-attainment fact that makes the
     extremum **exist**, naming the Lean theorem that supplies it. A `rules.tsv` rule reddens
     any unit containing a `Solve` whose certificate cell is blank, and a committed mutant that
     blanks one must redden. **A program with no certificate is not solved: it is asserted as a
     limit and deferred** (Phase 8's PROG-03 is the worked example). This is the standing rule
     that stops a solver reporting a bound as an optimum. It lands here rather than with the
     programs it governs for the same reason VOL-00 and VOL-0B did — it is registry schema, and
     it has a pre-Phase-8 consumer in Phase 3's SOLVE-04a/04b, which is precisely a
     certificate question.

  8. **TEST-04/05/06/07 — registry, tiers, fixtures, reference.** `model/test/registry.tsv`
     is one entry per line, append-only (M7), one driver per theorem unit, following GAMS
     Development's own `testlib` architecture; aggregation is not attempted (`$150 Symbolic
     equations redefined` is unconditional even under `$onMulti`). `check-fixtures` uses
     `gdxdiff` keyed on `rc != 0` with `execute_unload` as the last statement of every unit,
     so a failed run leaves no new GDX. `model/test/README.md` documents the vocabulary,
     tolerance policy, provenance convention, tier definitions and fixture layout.
     **TEST-05 corrected (M4):** "the suite runs green with CONOPT absent" is **uncheckable**
     — CONOPT ships inside GAMS and `system.solverNames` reports *installed*, not *licensed*.
     Replaced by two static facts: (i) a `rules.tsv` rule proving no `pure`-tier unit
     contains a `Solve`; (ii) a committed fixture requesting a deliberately nonexistent
     solver, which exercises the skip path and its printed reason string. `STRICT=1` turns
     any skip into a failure, and a rule reddens any skipped entry lacking a reason string.

  9. **The existing units are converted, and still pass.** The two existing theorem units and
     Phase 1's REPR-10 unit are converted to `_AssertLib.gms` — their tolerances retrofitted
     onto `kernelTol(n)` — and `make test-gams` still reports its baseline count. This is
     what proves the macros work on real fixtures before 134 more depend on them.

**Plans**: 5 plans

Plans:
- [ ] 02-01: `_AssertLib.gms` incl. `assertAdd0Branch`, with per-macro self-tests
- [ ] 02-02: `kernelTol(n)`, exponent-budget guard, bare-literal rule
- [ ] 02-03: `absFloor`, residual-level zero policy, non-degeneracy companions, the 1e6 mutant
- [ ] 02-04: TEST-08 mutation-proof rule applied retroactively to every existing `abort$`
- [ ] 02-05: `registry.tsv` with VOL-00 tier + VOL-0B provenance + PROG-00 certificate columns and their lints, tiered targets, `STRICT=1`, README, unit conversion

### Phase 3: The (Δᵢ, η) solve — value, product, ties, corner
**Goal**: Deliver what the mathematics actually identifies — the optimal value, the product `Δᵢ·η`, the tie count, and the γ=0 corner — and explicitly refuse to deliver what it does not, with the theorem/inference boundary drawn in the code.
**Depends on**: Phase 2 *(runs in parallel with Phases 4 and 5)*
**Requirements**: SOLVE-01, SOLVE-02, SOLVE-03, SOLVE-04a, SOLVE-04b, SOLVE-05, SOLVE-06, SOLVE-07
**Success Criteria** (what must be TRUE):

  1. **SOLVE-01 — the menu loop runs.** `make solve-eta-di` runs the F1 menu loop — one
     CONOPT NLP in η per `tickSpacingMenu` element — and exits 0. Every `Solve` is followed
     by `assertModelOptimal` (both status codes, per GATE-03). Per-point restart is
     deterministic and **never warm-started** (warm start makes the result path-dependent
     and biases toward the previous tie-set member). An MINLP is not attempted:
     `option minlp = conopt` is compile error `$255`.
     *Two rev-1 claims struck:* the **14× wall-clock speedup** from
     `solveLink=%solveLink.loadLibrary%` + `solPrint=%solPrint.silent%` was measured over
     **200 solves** and does not transfer to a 4-element menu — the options are still used,
     but **no speedup is claimed and none is a success criterion**. The **demo-license size
     assert** is removed: a 1200-variable NLP already returns rc=7 with a named diagnostic,
     and un-aggregable units never grow toward 1000, so the assert could never fire.

  2. **SOLVE-05 + SOLVE-02 + SOLVE-07 — the deliverable is the product, and the traps are
     guarded.** The exported GDX carries `optValue`, `prodMin`, `prodMax`, `prodSpread`,
     `nTies`, `numInfes`, `iterUsd`, each with a registered mutation proof (TEST-08).
     Coordinates `(Δᵢ*, η*)` are exported **only** on the γ=0 record; an `abort$` reddens
     any γ>0 coordinate claim, with a committed mutant that attempts one. A silent
     `nTies = 62` is the difference between "we solved it" and "we picked one of 62
     equally-good answers". `abort$(card(tieSet) = 0)` fires on a synthetic empty tie set
     (`smin`/`smax` on an empty set returns `±INF` silently, straight into a GDX fixture) —
     committed as a mutant. `TIED()` tolerance ties are used for solve-derived values, exact
     `=` retained only for single-`Parameter`-assignment values (exact ties under-count 30
     vs 62). Q96/Q128 magnitudes stay inside `$macro`s and `Parameter`s and **never enter a
     `Variable`** — a `rules.tsv` rule reddens it (measured: `solveStat=10`,
     `modelStat=13`, variables silently left at starting values). `abort$(base <= 0)` and
     `M.numDomErr = 0` cover `**` domain holes at solver trial points.

  3. **SOLVE-03 + SOLVE-04a — the THEOREM-tier assertion.** After `objScale ∈ [1e2, 1e6]`
     is in place (measured: scaling moves argmin error from `8.9e-3` to `1.25e-14`; above
     ~1e8 it over-scales and produces discontinuous-derivative warnings), the γ=0 solved
     **value** is asserted against `riskNeutral_corner` at a stated relative tolerance **no
     tighter than 1e-9**, in a unit tagged `THEOREM`. This is what the Lean theorem
     establishes — it bounds a value. The comment claiming "CONOPT precision is ~1e-2
     relative" states an avoidable bug as a law of nature and is removed. F2 (joint 2-D
     NLP) is retained as a **value** cross-check only; `option nlp = ipopt` corroborates at
     near-zero cost.

  4. **SOLVE-04b — the INFERENCE-tier assertion, hypothesis-guarded and separated.** Any
     assertion on the **coordinates** at γ=0 lives in a **separate unit tagged
     `INFERENCE`**, carrying an explicit `abort$` on the hypothesis `θ.b > 0` that
     `riskNeutral_corner` does **not** provide, and a header naming what Lean does not
     supply: `g θ` is `Classical.choice`, and a sweep found no `∃!`, `StrictConcave` or
     `StrictConvex` anywhere in the spec, so **no uniqueness route exists**. A `rules.tsv`
     rule reddens any unit that cites `riskNeutral_corner` while asserting coordinates
     without the `INFERENCE` tag or without the hypothesis guard; the committed mutant drops
     the guard and must redden. Green counts report the two tiers separately and never sum
     them (VOL-00). Conflating them would encode a **stronger proposition than the theorem
     proves**, in the flagship assertion, in the one place hypothesis-guarding is required.

  5. **SOLVE-06 — a machine-readable verdict, not a recollection.** The identifiability
     spike records `degeneracyBreaks ∈ {0,1}` in GDX alongside `nTies` and `prodSpread`,
     before and after coupling `retVol θ P η = δ·P^(η−1)` into the objective, with a
     registered mutation proof on the exported flag. (`retVol`/`liqShare` are
     `ComparativeStatics` members, so the coupling introduces **no new module dependency**;
     `retVol` depends on η *alone*, which is exactly the structure that could break the
     hyperbolic degeneracy.) That recorded value — not a human recollection — is what opens
     or closes Phase 9 and what orders Phase 6's plans.

  6. **Both Phase 3 solves declare a PROG-00 certificate.** SOLVE-04a's is corner attainment
     at γ=0 (`riskNeutral_corner`); SOLVE-04b's is the *absence* of one — no uniqueness route
     exists — which is why it is `INFERENCE` tier and hypothesis-guarded rather than solved-and-
     asserted. The Phase 2 lint reddens a `Solve` here with a blank certificate cell. This phase
     is where PROG-00 is first exercised, five phases before the programs it was written for.

     > **Relationship to M6a's degeneracy: UNKNOWN.** The `Δᵢ·η` product degeneracy measured
     > here and the M6a degeneracy in Phase 8 (λ_FLAIR maximizer and λ_ARB minimizer sharing a
     > corner in `(φ̄, α, u)`) are recorded as **separate phenomena**. Nothing in this roadmap
     > asserts they are the same, and nothing asserts they are different. Establishing a link
     > is new work.

  7. **M6 — the constant-`w` premise is a tripwire, not a caveat.** `make check-wstate`
     asserts, against the committed pin `model/spec-pins/wstate.pin`, that (i) the sha256 of
     `lean4-spec/exp/ComparativeStatics.lean` and (ii) the occurrence count of
     `fun _ => θ.w` in it are both unchanged. The solve unit records both in its provenance
     GDX. The target reddens the moment the premise behind criteria 2, 4 and 5 moves — at
     which point the γ-sweep is re-run before any of them is believed again (v2 WSTATE-01).

**Plans**: 5 plans
**Research flag**: **NEEDS `/gsd:research-phase`** — three open questions: whether the
`retVol` coupling actually breaks the degeneracy; whether stationarity is formulable as a
square CNS system under CONOPT (`CNS` *is* in its capability list, untested here); and the
`objScale` sweet spot on the real MV objective rather than on the probe.

Plans:
- [ ] 03-01: F1 menu loop, deterministic restart, status asserts, `mk/phase3.mk`
- [ ] 03-02: `objScale` calibration + SOLVE-04a THEOREM-tier value assertion
- [ ] 03-03: SOLVE-04b INFERENCE-tier coordinate unit with hypothesis guard + tag lint
- [ ] 03-04: Tie extraction, `TIED()`, empty-set guard, provenance with mutation proofs
- [ ] 03-05: SOLVE-06 spike + `degeneracyBreaks` record + `check-wstate` tripwire

### Phase 4: Moments / ingestion
**Goal**: An ingestion layer whose data source is genuinely pluggable — proven by compiling with no data source, *refusing* at execution time when none is present, and running end to end on a fabricated one — across **both** producer legs: the E3/E6 moments chain and E4/E1's fee-config and strike parameters.
**Depends on**: Phase 2 *(runs in parallel with Phases 3 and 5)*
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06, DATA-07, DATA-08, DATA-09, DATA-10, DATA-11
**Success Criteria** (what must be TRUE):

  1. **DATA-01 — the pluggability acceptance test, in three legs.** Rev 1's headline
     criterion ("`make compile-gams` exits 0 with `model/data/` absent") **passes on an
     empty file**: measured at `action=c`, the loader, a bare set declaration, and the
     current no-op all return rc=0. It discriminates only "does not use compile-time
     `$gdxIn`". Split:
     **(1)** `action=c` with data absent → rc=0. A **necessary condition only**, and
     labelled as such. A `rules.tsv` rule reddens any compile-time `$gdxIn`/`$load` (a hard
     rc=2 error on a missing file, which would redden `compile-gams` on every machine), and
     bare `execute_load` (which silently drops every off-grid observation — measured: mean
     of 100 instead of 101, rc=0). `execute_loadDC` is the sole ingestion verb.
     **(2)** `action=ce` with data absent → **non-zero, with a named contract diagnostic**
     (`MOMENTS-CONTRACT: no series file at …`), proving the loader is **reached** and
     **refuses**. Committed in the TEST-09 registry.
     **(3)** `action=ce` against DATA-10's fabricated fixture → rc=0 **and**
     `card(tObs) > 0` **and** `rv_bar` asserted non-degenerate (a TEST-03 non-degeneracy
     companion). Committed fixture plus expected-GDX diff.

  2. **DATA-02 + DATA-04 — the no-op is replaced by something that can be empty and say so.**
     `PricingKernelMoments.gms` — today a silent no-op counted OK by `compile-gams` — is
     replaced. `mean_tick`/`realized_variance`/`rv_bar` are `Parameter(winAll)` over a
     **model-owned static capacity grid** (`tAll`, `winAll`) with loaded membership
     `tObs(tAll)` as a subset; a deliberately-emptied load **exits non-zero** rather than
     yielding `card=0` at rc=0 (committed mutant). `ord()` and lag apply only to the parent;
     only linear lag is used and circular `--` is lint-banned (it fabricates a return by
     wrapping first→last). The `hasRet` mask guards on the **predecessor's value**, covering
     both the series head and interior gaps. `make compile-gams`'s file count changes here,
     which is expected — Phase 0 criterion 8's annotation names this as the reason.

  3. **DATA-03 + DATA-05 + DATA-07 — the only independent checks available pre-source.**
     `RV_log = (log λ)²·RV_tick` is asserted and holds inside the declared budget (measured
     `4.01e-13`), with a registered mutation proof. `rv_bar` normalization is asserted
     comparable across windows of **differing cardinality and differing `W`**: `W` is **not
     constant** — it is stored per market and arrives from the E6 `WindowChanged` history,
     so σ² reconstruction is `(volCum(t) − volCum(t−W))/W` looked up per series and per
     time, and the first window structurally owns one fewer return (measured
     `rvCard = 3, 4, 4`). A **position-weighted** `seriesChecksum` is re-derived
     consumer-side — a plain sum cannot detect a reordered series, proven by a mutant that
     reorders one.

  4. **DATA-06 + DATA-10 — the fabricated fixture drives everything, with no subgraph.**
     `seriesIdHash = uint48(keccak256(abi.encode(chainId, emitter, poolId)))` is recomputed
     identically producer- and consumer-side and asserted `< 2^53` against Phase 1's named
     constant — **uint48, not uint256**, because a 256-bit hash silently loses ~200 bits
     through an IEEE-double load. `poolId = 0` round-trips as a **permanent** module-global
     sentinel series, never a placeholder that later mutates. `tObs` loads **E3's emitted
     `timestamp` field**, never the block timestamp. The fixture is committed, so this runs
     forever rather than once.

  5. **DATA-08 + DATA-09 — loader integrity is executable against the fabricated fixture.**
     The E5↔`Swap` join predicate — same-tx **and** same-poolId **and** nearest-preceding
     `logIndex`, with `FeeApplied.fee == Swap.fee` asserted on every joined pair, **never
     poolId alone** — reddens on a committed hand-broken fabricated pair. An `abort$`
     reddens if any σ²_K (E1) row acquires a pool-series linkage while E2 does not exist.
     The consumer symbol/domain table matches the producer's §4 field→symbol→scale table;
     the pin `cfmm-replicationPlank@d34846c` is exported to GDX, read by an assertion, and
     enforced by `make check-datapin`, which reddens when the pin moves. Raw on-chain scales
     arrive; all conversion (Q96→dimensionless ξ, pips, tick²·s) is consumer-side.

  6. **DATA-11 — the second ingestion leg: fee config and strike, on its own path.**
     Θ_φ = {α₁, α₂, β₁, β₂, γ₁, γ₂, φ̄} from E4 `FeeConfigurationChanged` and σ²_K from E1
     `VolOrderCreated`.strike land in **named GAMS symbols per contract §4**, with scales
     left **raw** on arrival (pips for α/φ̄; Algebra vol units tick²·s for β/γ/σ²_K) and
     every conversion performed and asserted **consumer-side**. This is a **separate
     ingestion leg, not a downstream step**: it shares `execute_loadDC`, the
     static-capacity-grid discipline and `check-datapin` with DATA-01/02/08, but it does
     **not** depend on the E3/E6 moments chain (DATA-03/05/07) and is **not sequenced behind
     it** — it is its own plan and can run first. Acceptance mirrors DATA-01's legs on a
     **fabricated E4/E1 fixture**: `action=ce` with the fixture absent fails with a named
     contract diagnostic; present, all seven Θ_φ symbols plus σ²_K load non-degenerate and
     each raw-vs-converted pair is asserted. σ²_K rows stay **unjoined** to any pool series
     until E2 exists (DATA-09). It registers itself in `registry.tsv`'s VOL-0B provenance
     column as the producer for VOL-07 — the first entry to use that column.
     *Why it exists:* both events are **LIVE with topic0 pinned**, and before rev 3 nothing
     in the plan consumed either, so VOL-07's 24 theorems would have been ported against
     parameters that had a producer and no ingestion path. *What it is not:* live ingestion.
     The indexer that would emit these rows is **unowned and unbuilt**.

**Plans**: 5 plans
**Research flag**: **LIGHT** — formulations are executed end to end; open items are grid
sizing (`winMap` is O(|winAll|·|tAll|) worst case, unmeasured — measure before enlarging
`tAll /o1*o4096/` or `winAll /w1*w256/`), the exact §4 row names backing DATA-11's seven
Θ_φ symbols and `FeeSchedule.Params.volStrike`, and the producer choice, blocked on the
Plank schema.

Plans:
- [ ] 04-01: `_MomentsContract.gms` + static capacity grids + `execute_loadDC` + the three-leg acceptance test
- [ ] 04-02: `MomentsKernel.gms` — `hasRet`, `mean_tick`, `realized_variance`, `rv_bar`, `RV_log`
- [ ] 04-03: `seriesIdHash` uint48 + sentinel + position-weighted checksum + `check-datapin`
- [ ] 04-04: DATA-10 fabricated fixture, loader integrity mutants, fixed `tickPerPriceKernel`
- [ ] 04-05: **DATA-11** — E4 Θ_φ + E1.strike σ²_K leg, fabricated fixture, raw/converted assertions, VOL-07 provenance entry *(independent of 04-02; not sequenced behind it)*

### Phase 5: Port foundation — the split test, the bridge design, then PosSpec/Main/Flow
**Goal**: Find out whether the port's green would mean anything *before* writing 134 units — then prove the GAMS↔Lean bridge pattern at the graph's articulation point.
**Depends on**: Phase 2 **only** *(runs in parallel with Phases 3 and 4 — see judgement call 2)*
**Requirements**: VOL-0A, VOL-01 (PosSpec, 12 thm), VOL-02 (Main, 7 thm), VOL-03 (Flow, 12 thm)
**Success Criteria** (what must be TRUE):

  1. **VOL-0A — the B5 split test, and it can stop the port.** Ten theorems of the 134 are
     drawn by a **committed seeded script** (`make split-test SEED=…`) so the sample is
     reproducible; for each, `model/spec/SPLIT_TEST.md` records the Lean statement's
     conclusion, the intended GAMS assertion, and a verdict of `THEOREM` or `INFERENCE`.
     **INVALIDATED-able outcome: if ≥3 of 10 come back `INFERENCE`, the port does not open
     on the current plan** — Phase 5 re-cuts its scope and records that verdict as the
     phase's result. The one theorem examined so far (`riskNeutral_corner`, SOLVE-04)
     **already failed this test**. Half a day of work that determines whether everything
     downstream means anything.
     **UNVERIFIABLE-LEG:** the per-theorem verdict is a human reading of a Lean statement.
     The *sample draw* and the *recorded verdicts* are committed and re-checkable; the
     judgement inside each is not automatable and is not claimed to be.

  2. **The bridge DESIGN exists before 103 theorems depend on it (M5).** `model/spec/BRIDGE.md`
     names every shared symbol linking the pricing kernel to the volatility instruments and
     the `abort$` consistency assertion each carries, every entry tagged `BRIDGE` (no Lean
     counterpart). Verified: `PosSpec` and `Main` import only Mathlib, `Flow` imports only
     `PosSpec` — `vol_markets` is import-disjoint from `exp/`, so this link **does not exist
     in the formalization** and is being *established* in GAMS.
     **INVALIDATED-able outcome:** if the design cannot name at least one shared symbol
     carrying a falsifiable assertion, the bridge is recorded as not-yet-designable and
     Phases 6–7 are re-scoped rather than proceeding on an unstated one. Rev 1 scheduled
     this discovery sixth; it is now first.

  3. **31 theorem units exist and report 31/31 green under `STRICT=1`, counted by tier.**
     One execution unit per theorem, one driver each, each registered in `registry.tsv` with
     its tier. `THEOREM`, `BRIDGE` and `INFERENCE` counts are printed separately and never
     summed (VOL-00). Aggregation is not attempted: `$150 Symbolic equations redefined` is
     unconditional even under `$onMulti`, so any two solver-bearing units are structurally
     un-aggregable — the process boundary *is* the namespace boundary.

  4. **Every ported unit names its Lean theorem, and the gate that checks it actually
     works.** A `rules.tsv` rule reddens a unit with no named theorem, and the **repaired**
     `make lean-sorry-check` (GATE-07, Phase 0) exits non-zero if that theorem's body
     carries `sorry`/`admit`, exercised by Phase 0's committed indented-namespaced fixture.
     Stated explicitly because rev 1 claimed a capability no phase created: today's gate is
     column-0-anchored and matches **zero** of the 134 namespaced `vol_markets` theorems,
     and `make spec-preflight` runs **no Lean grep at all**. This criterion is a claim about
     the Phase-0 artifact, not about the current one.

  5. **Tolerances and singularities are handled by the Phase 2 vocabulary, not by hand.**
     Every unit declares its tolerance via `kernelTol(n)` or `absFloor(scale)` and **never a
     bare literal** — a hard-coded `1e-12` reddens the build — with its valid exponent range
     recorded in the unit's provenance. `LiquidityKernel`'s **ξ→1 singularity and ι→1
     semantic emptiness are guarded before `Flow` builds on them**: committed fixtures
     feeding ξ=1 and ι=1 must redden rather than producing a silent value.

  6. **Every one of the 31 units carries a registered mutation proof (TEST-08), and any unit
     asserting more than its theorem's conclusion is tagged `INFERENCE` with an explicit
     hypothesis guard** — the SOLVE-04a/04b discipline propagated. The lint from Phase 2
     enforces both; a committed mutant that drops a guard must redden.
     **And each of `PosSpec`, `Main` and `Flow` resolves its VOL-0B provenance from TBD
     before it is ported** — to an E-number and §4 row, or to an explicit `none (pure
     theorem, symbolic parameters only)`, which for these three is the expected answer since
     all import only Mathlib or `PosSpec`. The Phase 2 lint reddens a module that stays TBD.
     This is the check that would have caught E4, applied to the first three modules.

**Plans**: 4 plans
**Research flag**: **NEEDS `/gsd:research-phase`** — but the flag now has a home: the
pricing-kernel↔volatility link does not exist in Lean and must be *designed*, which is
criterion 2, this phase's first plan, with a stated failure outcome.

Plans:
- [ ] 05-01: VOL-0A split test + bridge design spike (both INVALIDATED-able) — **gates the rest**
- [ ] 05-02: `PosSpec` (12 theorems)
- [ ] 05-03: `Main` (7 theorems)
- [ ] 05-04: `LiquidityKernel` ξ/ι guards + `Flow` (12 theorems) — the articulation point

### Phase 6: Instrument mechanics — RiskDesign, GeomProfile, Panoptic, FeeSchedule, Upsilon
**Goal**: Port the graph's three L2 branches and their two L3 successors, and close the moments↔volatility link — the point where Phases 3, 4 and 5 actually join.
**Depends on**: Phases 3, 4 and 5 (all three — this is the real join, not Phase 5). **Two independent edges run from Phase 4**: VOL-08 `Upsilon` consumes DATA-03/DATA-07's moments layer, and VOL-07 `FeeSchedule` consumes DATA-11's Θ_φ and σ²_K. 45 of this phase's 67 theorems sit behind Phase 4, not 3.
**Requirements**: VOL-04 (RiskDesign, 21), VOL-05 (GeomProfile, 11), VOL-06 (Panoptic, 8), VOL-07 (FeeSchedule, 24), VOL-08 (Upsilon, 3)
**Success Criteria** (what must be TRUE):

  1. **67 theorem units report 67/67 green under `STRICT=1`, counted by tier**; the registry
     shows zero untiered entries, zero reason-less skips, and `THEOREM`/`BRIDGE`/`INFERENCE`
     printed separately (VOL-00).

  2. **Both Phase 4 edges are proved to be real dependencies, not copied values.**
     `Upsilon` (VOL-08) consumes `realized_variance`/`rv_bar` via the `_MomentsContract.gms`
     symbols — the contract's υ-identification / econometric path. `FeeSchedule` (VOL-07)
     consumes DATA-11's Θ_φ = {α₁,α₂,β₁,β₂,γ₁,γ₂,φ̄} from E4 and σ²_K from E1.strike (§4
     names `FeeSchedule.Params.volStrike` as the analog) through the same contract
     mechanism. **Two committed rename-mutants — one per edge — must redden the consuming
     units.** Rev 2 had only the Upsilon edge; the FeeSchedule edge did not exist, because
     nothing ingested E4.

  3. **The pricing-kernel↔volatility bridge is registered and every shared symbol carries an
     assertion.** Each entry from Phase 5's `BRIDGE.md` is realized as a named shared symbol
     plus an `abort$` consistency assertion, tagged `BRIDGE`; a `rules.tsv` rule reddens a
     shared symbol carrying no assertion, and TEST-08 reddens an assertion carrying no
     mutation proof. These are the weakest-evidence assertions in the project and are
     counted as such.

  4. **Tick-compression semantics are asserted where they actually differ.** `floor`-vs-`trunc`
     is asserted **at negative ticks** — real half the time — in every unit that compresses,
     not only at positive ones, with a committed negative-tick fixture. Lag/lead boundary
     handling goes through the single extracted macro, not hand-written copies: an
     off-the-end lag yields 0, which makes a *decreasing* monotonicity check pass silently,
     and a committed mutant proves that path reddens.

  5. **The Phase 3 spike routes this phase's plan order, mechanically.** The phase reads
     `degeneracyBreaks` from Phase 3's exported GDX. On `1`, `Upsilon` and its closure
     `{PosSpec, Flow, Panoptic}` are ordered first; on `0`, dependency order is used
     unchanged. Either way the routing decision is written to this phase's provenance GDX
     and read by an assertion — it is not a decision someone remembers making.

  6. **Every one of the 67 units carries a registered mutation proof; an `INFERENCE` tag with
     an explicit hypothesis guard wherever it asserts beyond its theorem's conclusion; and a
     resolved VOL-0B provenance.** VOL-07's and VOL-08's are contract-stated (above);
     **VOL-04, VOL-05 and VOL-06 are TBD today and must be resolved before porting**. Two
     carry a live caveat: VOL-05's ξ⋆, if consumed, arrives via E2 `PortafolioMinted`, which
     is **SPEC-ONLY**, so a VOL-05 unit consuming ξ⋆ declares it and runs against a
     fabricated fixture — never live data; and VOL-06's `tokenId` decoding is **subgraph-side
     per contract §6**, so on the GAMS side it is provenance `none` by construction. The
     Phase 2 lint reddens any module still reading TBD.

**Plans**: 5 plans

Plans:
- [ ] 06-01: `RiskDesign` (21 theorems)
- [ ] 06-02: `GeomProfile` (11 theorems)
- [ ] 06-03: `Panoptic` (8 theorems)
- [ ] 06-04: `FeeSchedule` (24 theorems) + the DATA-11 Θ_φ/σ²_K contract link and its rename-mutant
- [ ] 06-05: `Upsilon` (3 theorems) + the moments↔volatility contract link + bridge registry

### Phase 7: VolInstrument + EndogenousMaturity — the post-convergence port
**Goal**: Land the graph's in-degree-4 convergence node and everything downstream of it that is not a program — the **substrate Phase 8's programs are solved over**, not the endpoint.
**Depends on**: Phase 6
**Requirements**: VOL-09 (VolInstrument, 36 thm), VOL-12 (EndogenousMaturity, 34 thm)
**Success Criteria** (what must be TRUE):

  1. **70 theorem units report 70/70 green under `STRICT=1`** — `VolInstrument` (36) plus
     `EndogenousMaturity` (34) — and the registry enumerates **168/168** across Phases 5–7 with
     the count asserted **mechanically** (an `abort$` against the registry line count, not a
     hand tally) and reported per tier, never summed. The full `vol_markets` closure is **205
     theorems across 12 files, 0 `sorry` throughout**; the remaining 37 (`FlairOptimization` 15,
     `MevOptimization` 22) land in Phase 8 because they are what the programs are solved over.
     **No theorem count appears in prose anywhere without a mechanical assertion behind it** —
     rev 4 carried "169 theorems" when the measured figure was 149, which is exactly the class
     of error this rule exists to prevent.

  1b. **`EndogenousMaturity` is ported as a leaf with no program consumer, and that is recorded.**
     It depends on `VolInstrument`, `Main`, `Flow` and `GeomProfile` — all landed by this phase —
     and **feeds no PROG requirement**. Its VOL-0B provenance is TBD and must resolve before
     porting. It is here rather than in Phase 8 so that the deliverable phase does not carry 34
     theorems irrelevant to the deliverable.

  2. **All four upstream dependencies are consumed through declared contract symbols.**
     `Panoptic`, `Upsilon`, `GeomProfile` and `FeeSchedule` each have a committed
     rename-mutant that must redden this phase's units. Four mutants, one per in-edge —
     which is exactly what makes the in-degree-4 cut a real synchronization point rather
     than a narrative one. **Provenance is re-declared, not assumed:** VOL-09's registry
     entry names its four upstream sources and, through them, the E-numbers they resolve to
     (E4/E1 via `FeeSchedule`, E3/E6 via `Upsilon`), and the VOL-0B lint reddens a blank
     cell. σ²_K rows stay **unjoined** to any pool series until E2 exists (DATA-09).

  3. **`FlairOptimization` is verifiably absent.** A `rules.tsv` rule reddens any `$include`
     or symbol reference reaching it; it is v2 (FLAIR-01) because it imports *from*
     `VolInstrument` and sits downstream of this closure. Committed mutant: an added
     reference must redden.

  4. **The whole thing works somewhere else.** `make compile-gams` and the full tiered suite
     are green **from a fresh anonymous recursive clone** with `model/data/` absent —
     proving the submodule-resolved proof-gate path and the no-data-source design both
     survive outside this machine. Driven by a committed `make verify-clean-clone`.

  5. **Every one of the 36 units carries a registered mutation proof and honest tiering.**

     *No license criterion appears in this phase.* Rev 1 claimed the demo-license ceiling
     "becomes a hard wall here". It does not: a 1200-variable NLP already returns rc=7 with
     a named diagnostic (`*** The model exceeds the demo license limits…`), so there is no
     bare solver failure to improve on, and since units are structurally un-aggregable
     (`$150`) no single model grows toward 1000 — the assert could never fire. The
     in-degree-4 argument for cutting here stands on the dependency graph alone, and was
     independently verified. No BARON/global cross-check appears in any plan (50-var cap).

**Plans**: 5 plans

Plans:
- [ ] 07-01: `VolInstrument` theorems 1–12 + the four upstream contract rename-mutants
- [ ] 07-02: `VolInstrument` theorems 13–24
- [ ] 07-03: `VolInstrument` theorems 25–36 + `verify-clean-clone`
- [ ] 07-04: `EndogenousMaturity` theorems 1–17 + VOL-0B provenance resolution
- [ ] 07-05: `EndogenousMaturity` theorems 18–34 + mechanical 168/168 registry assertion

### Phase 8: The convex programs — what GAMS is for
**Goal**: Solve the convex programs the volatility-instrument architecture implies, in the cases where existence is *certified*, refuse the ones where it is not, and let no solution leave that Plank cannot represent.
**Depends on**: Phase 7 (`FlairOptimization` and `MevOptimization` both import from `VolInstrument`) — and, through PROG-05, on Phase 1: a solution the representation kernel cannot express is not a solution.
**Requirements**: VOL-10 (FlairOptimization, 15 thm), VOL-11 (MevOptimization, 22 thm), PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, PROG-06, PROG-07
**Success Criteria** (what must be TRUE):

  1. **Both program-bearing modules are ported, and their 14 cited theorems pass a census — not
     a sample.** `FlairOptimization` (15 thm) and `MevOptimization` (22 thm), **0 `sorry`**
     each, report 37/37 green under `STRICT=1`, tiered (VOL-00), provenance-declared (VOL-0B)
     and mutation-proved (TEST-08). **VOL-11 is ported first**: PROG-01, PROG-04 and PROG-06
     all rest on it, and it depends on VOL-10, so it cannot precede this phase.
     **The census covers all 14 theorems the PROG requirements cite by name**, across both
     modules — `mevMulti_exists_min_compact`, `mevMulti_min_gt_corner`, `mevMulti_anti_phibar`,
     `mevMulti_anti_alpha`, `mevMulti_anti_u`, `mevMulti_mono_beta`, `ptrade_convexOn`,
     `ptrade_strictConvexOn`, `ptrade_strictAntiOn`, `flairMulti_le_corner`,
     `flairMulti_corner_attained_levels`, `flairMulti_saturation_limit`,
     `flairMulti_strict_below_saturation`, `Theta_lambda_identification`. For each,
     `model/spec/PROG_CERTIFICATES.md` records the Lean conclusion, the intended GAMS use, the
     **objective symbol**, the **optimization direction**, and a verdict.
     **INVALIDATED-able at program level:** any theorem whose intended use is stronger than its
     conclusion, or whose objective/direction does not match, stops its program, which falls
     under assert-only discipline.

  1b. **N5 — and the phase itself can be INVALIDATED, not merely degraded.** Rev 4's census
     invalidated programs one at a time, so the phase could silently degrade to
     1-solved / 3-asserted while every criterion still read green. **Phase-level clause: if
     fewer than two programs survive with a certificate matched on both objective symbol and
     optimization direction, Phase 8 records a phase-level INVALIDATED verdict in its
     provenance GDX, and the project's deliverable statement is amended rather than left
     standing.** This is not hypothetical margin: **the phase enters with exactly two solvable
     programs** (PROG-01, PROG-02), because rev 5 demoted PROG-04. Losing either triggers the
     verdict.

  2. **PROG-06 — the monotonicity structure gates every solve, its signs now match exactly, and
     it is checkable without a solver.** λ_ARB is **antitone** in φ̄, in each α_j and in u;
     **isotone** in each β_j; and **convex** in the fee. Certificates, one per sign:
     `mevMulti_anti_phibar`, `mevMulti_anti_alpha`, `mevMulti_anti_u`, `mevMulti_mono_beta`,
     `ptrade_convexOn`. Tier **THEOREM** — rev 4 could not have claimed this, because λ_ARB had
     no Lean counterpart at the old submodule pin. Two committed legs: (a) finite differences on
     the objective at committed sample points, running at `action=ce` with **no solver at all**;
     (b) sign assertions on the solver's **marginals** (`.m`) in every unit that solves. A
     committed mutant flipping one sign must redden. Lands **before** PROG-01/02.

  3. **PROG-01 — the one program whose existence is certified for its own objective.** The M5
     infimum on λ_ARB over a nonempty compact box. Certificates: existence
     `MevOptimization.mevMulti_exists_min_compact`; strict excess `mevMulti_min_gt_corner`.
     Tier **THEOREM**. The solved value is asserted to **strictly exceed** the displayed bound
     at a declared margin.
     *Correction recorded:* rev 4 cited `flairMulti_exists_max_compact` — a **maximum** of
     **λ_FLAIR** over a **different block**. Wrong objective, wrong direction, in the flagship
     program. It passed rev 4 because PROG-00's lint only checked that the cell was non-blank;
     PROG-00 now requires the cited theorem's objective symbol **and** direction to match, and
     that rule is what catches this class.

  4. **PROG-02 — the M6a level block, solved and shown to move.** For a fixed shape block, the
     λ_FLAIR maximizer and the λ_ARB minimizer are the **same corner** in `(φ̄, α, u)`, attained
     bang-bang. Certificate: `flairMulti_corner_attained_levels` + `flairMulti_le_corner`. The
     unit reports **which corner**, and a committed fixture perturbing one bound must **move**
     the reported corner — a bang-bang result that never moves is indistinguishable from a
     hard-coded one.

  5. **PROG-00(c) — every solve proves it converged, not merely that it returned.** Both solving
     units run **multi-start from committed distinct initial points**, assert all starts reach
     the same value at a declared tolerance, and record `modelStat`, `solveStat`, `numInfes` and
     `iterUsd` in provenance. This is a separate obligation from existence:
     `mevMulti_exists_min_compact` requires only `IsCompact Θ` and `Θ.Nonempty` — **no convexity
     of Θ** — and CONOPT is a **local** solver, so a certified global minimum and the point
     CONOPT found are different claims. A committed mutant that seeds one start in a different
     basin must redden the agreement assertion.

  6. **PROG-03 and PROG-04 — both assert-only, both with a guard that has a proof it can fire.**
     **PROG-03 (M6a shape block):** over unbounded `(β, γ)` the bound is approached only as
     `β → −∞`, with a **strict gap at every finite β** — a saturation boundary, not a maximum.
     A limit assertion along a **committed decreasing-β sequence** shows the value approaching
     the bound while the gap stays strictly positive, plus a **guard reddening any solver in
     this phase that returns a shape-block variable at its bound as a solution**. Per TEST-08 the
     guard ships a committed unit that deliberately runs the naive NLP and must be **caught**.
     **PROG-04 (M6b) — demoted from SOLVE in rev 5.** `ptrade_strictConvexOn` and
     `ptrade_strictAntiOn` are both proven, but **existence over the equal-income level set is
     not certified**, and PROG-00(a) requires existence — not convexity — to license a `Solve`.
     Tier **INFERENCE**, assert-only until a compactness fact for that level set exists. It
     ships `abort$` guards on the doc's two stated hypotheses, **`a ≡ w`** and **`σ_t ≡ σ_0`**,
     because the doc records that without `a ≡ w` **the conclusion can reverse**. It also records
     the doc's OPEN note: inside Θ_φ every schedule is a function of σ alone, so **at constant σ
     the strict half may have no bite** — whether the committed non-constant path lies inside or
     outside Θ_φ is **declared, not discovered**.

  7. **PROG-07 — `MevOptimization`'s three limitations are executable guards, not prose.** Its
     docstring records that (i) `ARB ≈ LVR·P_trade` is a **leading-order, fast-block, small-fee
     asymptotic**, not an exact identity at finite Δt; (ii) the formalized λ_ARB has **no demand
     response to the fee**, so a corner is *"a property of the stated objective, not a
     market-equilibrium claim"* — the omitted term being `E[delta-hedged LP P&L] = E[NT_FEE] −
     E[ARB]`; (iii) `P_trade` is a **steady-state** quantity, so stepwise application along a
     varying-σ path is a **quasi-static extension**, legitimate *"only if the parameters move
     slowly relative to mixing of the mispricing process."* Every solve reporting a corner
     **records which of the three it relies on** in provenance, a `rules.tsv` rule reddens a
     corner-reporting unit with a blank reliance cell, and **no output is labelled a
     market-equilibrium result** — a lint reddens the phrase.

  8. **PROG-05 — no solution leaves this phase unless Plank can represent it.** Every solved
     parameter round-trips through the representation kernel's declared scales and bounds
     (REPR-01/03/05/09) **without loss**: pips for φ̄ and α, Algebra vol units (tick²·s) for β
     and γ, the int24 tick range, the 53-bit ceiling. **A solution outside representable range
     FAILS the program — it is never rounded into range.** A committed fixture whose optimum
     sits just outside the pip grid must **redden rather than snap**. Enforced by
     `assertEvmExpressible` from Phase 2's `_AssertLib`. This is the criterion that makes
     Phases 0–2 the substrate rather than a parallel track.

  9. **The phase reports 2 solved / 2 assert-only**, never "4 programs done" — the same rule
     that forbids summing THEOREM and INFERENCE tiers (VOL-00). The split is recorded in
     provenance and read by an assertion.

**Plans**: 6 plans
**Research flag**: **NEEDS `/gsd:research-phase`** — the doc states the programs mathematically;
their **GAMS formulation is unwritten**. Open: the variable/equation structure of each program
and which block is held fixed when; how the bang-bang corner is extracted deterministically (and
how that interacts with SOLVE-02's tie machinery); the multi-start design PROG-00(c) needs on a
non-convex Θ; whether a compactness fact for M6b's equal-income level set is reachable (it would
promote PROG-04 back to SOLVE); and the concrete predicate for "the solver returned a bound as a
solution" that PROG-03's guard keys on.

Plans:
- [ ] 08-01: VOL-11 `MevOptimization` (22 thm) + VOL-10 `FlairOptimization` (15 thm) + the 14-theorem certificate **census** — **gates the phase**
- [ ] 08-02: PROG-07 limitation guards + the market-equilibrium lint — lands with the module whose docstring states them
- [ ] 08-03: PROG-06 monotonicity harness — finite-difference leg + marginal-sign leg — **gates the solves**
- [ ] 08-04: PROG-01 (M5 infimum) + PROG-02 (M6a level corner) + PROG-00(c) multi-start convergence
- [ ] 08-05: PROG-03 saturation limit + bound-as-optimum guard; PROG-04 assert-only with `a ≡ w` / `σ_t ≡ σ_0` guards
- [ ] 08-06: PROG-05 EVM-expressibility round-trip gate + the 2-solved/2-asserted and phase-level verdict records

### Phase 9: Coordinate identification (CONDITIONAL)
**Goal**: Recover `(Δᵢ*, η*)` away from γ=0 — **if and only if** Phase 3's spike showed the degeneracy breaks. This phase may legitimately close as INVALIDATED without a single plan; that is a successful outcome, not a failure.
**Depends on**: Phase 3 (the recorded verdict) and Phase 8 (the programs — the port alone is no longer the precondition)
**Requirements**: IDENT-01

> **Deliberately not promoted.** Rev 4 makes solving the deliverable, which is a superficial
> argument for pulling coordinate identification forward. It stays conditional and stays last:
> the instruction behind the reframing was **non-degenerate first**, and degeneracy work waits
> until the lean4-spec worktree constrains the problems. Its degeneracy is also **not** known to
> be the same phenomenon as Phase 8's M6a degeneracy — see the binding table.
**Success Criteria** (what must be TRUE):

  1. **The entry condition is mechanical, not editorial.** The phase's first check reads
     `degeneracyBreaks` from Phase 3's exported GDX. On `0`, the phase closes as
     **INVALIDATED** with that artifact as the evidence, ROADMAP and REQUIREMENTS record it
     as such, the product `Δᵢ·η` remains the deliverable, and criteria 2–4 do not apply.

  2. **If open:** `(Δᵢ*, η*)` are recovered at γ > 0 with `nTies = 1` and `prodSpread` at
     the declared floor, asserted **across a γ-sweep** rather than at a single point —
     because the measured degeneracy was a property of the whole γ>0 region (62 pairs at
     γ=100), not of one sample. The sweep is a committed fixture.

  3. **The uniqueness claim is stated honestly and tagged.** This unit is `INFERENCE` tier:
     Lean's `g θ` is `Classical.choice` with **no uniqueness lemma anywhere** (no `∃!`,
     `StrictConcave` or `StrictConvex` in the spec), so this is GAMS-side *numerical*
     identification under the coupled objective, not a theorem instance. A unit claiming
     `THEOREM` tier here reddens the Phase 2 tag lint.

  4. **Phase 3's γ>0-coordinate `abort$` is amended, not deleted**, and the amendment names
     the exact condition under which coordinates may be exported. Phase 3's committed mutant
     for that guard is updated in the same commit, so the guard remains falsifiable.

  5. **`make check-wstate` is green at the moment this phase opens or closes.** This phase's
     very existence is downstream of the constant-`w` premise; if the tripwire has fired,
     the verdict this phase gates on is re-derived **before** the phase is opened or closed
     (v2 item WSTATE-01).

**Plans**: TBD (0 if INVALIDATED; scope cannot be determined before Phase 3's result)
**Research flag**: Determined by Phase 3's outcome; cannot be scoped before it.

### Phase 10: Shock contract + the volume-path model
**Goal**: Given a decoded volume shock and a **fixed** `N`, generate a feasible swap path that hits both terminal targets — in tick and reciprocal-quantity space, where GAMS doubles are adequate.
**Depends on**: Phases 0, 1 and 2 — **and nothing in Phases 3–9.** Specifically: `priceImpactKernel_Add0` and REPR-03/09's widths (Phase 1), TEST-02's tolerance rule and the registry (Phase 2), GATE-05's fixture machinery (Phase 0). It may join the 3∥4∥5 parallel set; see judgement call 13 for why that is not recommended.
**Requirements**: VPATH-06, VPATH-07, VPATH-10, VPATH-01, VPATH-02, VPATH-12, VPATH-08, VPATH-03, VPATH-04, VPATH-05
**Success Criteria** (what must be TRUE):

  1. **VPATH-06 + VPATH-07 — the shock is decoded exactly as the reference declares it, and the
     unused field is labelled rather than laundered.** `next(address pool, uint160 sqrtPrice,
     int24 tick, uint24 txlVolumeRate, uint24 txlDecayRate)`, selector `0xd3827b0b`;
     `txlVolumeRate` **is** `δ_trans`. The widths are binding and checked against Phase 1's
     constants — `uint24` rates, `int24` tick, `uint160` sqrtPrice, all subject to REPR-03/09.
     **`txlDecayRate` is DECIDED: not considered in this model.** It is decoded only because its
     position in the 5-argument selector fixes the calldata offsets of the fields after it; it
     enters no equation and no functional, and it is **not exported as provenance**. REPR-08's
     lesson applies literally: `etaQ128` is exported, copied into the GDX, reads as meaningful,
     and is not. A `rules.tsv` rule reddens `txlDecayRate` appearing in any `execute_unload`
     list, and a committed mutant that exports it must redden.

  2. **VPATH-10 — the fixture pins the reference's own constants, not invented ones.**
     `SQRT_PRICE_1_1 = 2^96` (from Phase 1's exact table, never a GAMS float — see criterion 1
     of Phase 11), the liquidity range `tick(SQRT_PRICE_1_4) … tick(SQRT_PRICE_4_1)` **rounded to
     tickSpacing 60**, and `UNIT_LIQUIDITY = 2^64`. A committed mutant altering any one must
     redden, because divergence from these makes every differential result meaningless.

  3. **VPATH-01 + VPATH-02 — one recursion, reused, with the swap condition as a constraint.**
     `p₍₁,Δᵢ₎(i(n+1)) = L̄·p₍₁,Δᵢ₎(i(n)) / (L̄ + p₍₁,Δᵢ₎(i(n))·ΔQ_X(n))` is implemented by
     **reusing `priceImpactKernel_Add0`** — a `rules.tsv` rule reddens a second copy of the same
     algebra, since it is the identical form already restored in `PricingKernel.gms` and the Q96
     scale asymmetry there is load-bearing. `ΔQ_M(n) = −L̄·p₍₂,Δᵢ₎(i(n))·ΔQ_X / (L̄ +
     p₍₁,Δᵢ₎(i(n))·ΔQ_X)`, with the sign condition **`ΔQ_X(n)·ΔQ_M(n) < 0` enforced per step as
     a constraint, never assumed** — the doc's "shock-induced flow is a swap". A committed
     fixture violating it must be infeasible, not silently accepted.

  4. **VPATH-12 + VPATH-08 — closure is ONE LINEAR equality, and the correspondence behind it is
     confirmed rather than inferred.** The recursion is **affine in reciprocal coordinates**:
     `1/p₍₁,Δᵢ₎(i(n+1)) − 1/p₍₁,Δᵢ₎(i(n)) = ΔQ_X(n)/L̄`, measured deviation **0.000** in GAMS
     54.1. Telescoping gives `1/p_N − 1/p_0 = (1/L̄)·Σ ΔQ_X(n)`, so **`p_N = p_0 ⟺ Σ ΔQ_X = 0`**
     — imposed as the linear constraint `Σₙ ΔQ_X(n) = 0`, not as a nonlinear terminal condition,
     and the recursion is never inverted. Measured both directions and committed as fixtures:
     `Σ = −1e17 → p_N = 1.1111…` (open) and `Σ = 0 → |p_N − p_0| = 0.00000000000000` (closed).
     **VPATH-08 is DECIDED: the loop closes, `i(0) = i(N)`**, so `p̄ ≡ p₍₂,Δᵢ₎(i(0))` is well
     defined at both ends and `ν_trans` measures genuine round-trip volume.
     **One obligation is not discharged by the algebra:** this is *very likely* the content of
     the MEV notes' **Theorem 29 (the monoid path is direct)** and **Theorem 30 (path
     decomposition)** — reciprocal price under swap composition as an additive monoid — and that
     correspondence is **confirmed against the Lean/doc statements before the structure is
     relied on**, recorded in `model/spec/VPATH_MONOID.md` with a verdict. Matching algebra is
     not a citation.

  5. **VPATH-03 + VPATH-04 — the functionals are the doc's, and both terminal targets are hit.**
     `π^φ(n)` (fee income), **`ν_trans(n) = Σ√(p̄·|ΔQ_X·ΔQ_M|)` — the GEOMETRIC mean, not the
     arithmetic one**, with a committed fixture where the two differ and the arithmetic form
     must redden — and `π̄(n)` (total notional), with `p̄ ≡ p₍₂,Δᵢ₎(i(0))` and
     `φ̄ = 1 − (1−φ̄_X)(1−φ̄_M)`. The generated path satisfies `δ_trans(N) = δ*_trans` and
     `r_N^φ = φ̄·δ*_trans`, where `r_n^φ = π^φ(n)/π̄(n)` and `δ_trans(n) = ν_trans(n)/π̄(n)`,
     each at a TEST-02 exponent-dependent tolerance with its valid range recorded — never a bare
     literal.

  6. **VPATH-05 — `N` is a fixed input, and the residual freedom is declared rather than closed.**
     This is a **generation** problem: any feasible path of length `N` is an answer. `N+1`
     quantities against two terminal conditions leaves residual freedom, which is **expected and
     is not a defect**. A `rules.tsv` rule reddens any objective function in the path model —
     because the failure mode here is inventing one to make the problem look determinate. If a
     selection rule among feasible paths is later wanted, it is added **deliberately and named**,
     in a plan, with its own criterion. `N` is asserted to be a `Parameter`, never a `Variable`.

**Plans**: 5 plans
**Research flag**: **LIGHT** — the recursion, the reciprocal-affinity finding and both closure
directions are executed and measured. Open: the Theorem 29/30 correspondence (criterion 4, a
reading task, not a measurement), and whether the sign constraint plus linear closure leaves the
feasible set non-empty at the reference constants for small `N`.

Plans:
- [ ] 10-01: Shock decode contract (VPATH-06) + `txlDecayRate` non-export rule (VPATH-07) + reference constants (VPATH-10)
- [ ] 10-02: Recursion by reuse of `priceImpactKernel_Add0` (VPATH-01) + per-step swap-sign constraint (VPATH-02)
- [ ] 10-03: VPATH-12 linear closure + both measured directions + VPATH-08; Theorem 29/30 correspondence verdict
- [ ] 10-04: Path functionals with the geometric mean (VPATH-03) + both terminal targets (VPATH-04)
- [ ] 10-05: Fixed-`N` generation, residual-freedom declaration, no-objective lint (VPATH-05)

### Phase 11: EVM-unit emission and replay
**Goal**: Cross the representational cliff — emit a path in exact EVM units that the chain consumes byte-for-byte, and diff what the chain realizes against what GAMS predicted.
**Depends on**: Phase 10, and on Phase 1 for the exact tick→sqrtPriceX96 table (REPR-10 leg b), Phase 0 for `check-fixtures`, Phase 2 for TEST-02's tolerance rule.
**Requirements**: VPATH-13, VPATH-14, VPATH-09, VPATH-11
**Success Criteria** (what must be TRUE):

  1. **VPATH-13 — every Q96 value in the JSON comes from the committed exact table, and a lint
     proves it.** The design is forced by measurement, not preference: at Q96 magnitude
     (~7.9e28) the double spacing is **2^44 ≈ 1.759e13**, so a 97-bit `sqrtPriceX96` retains 53
     bits and its **low 44 bits do not exist**; and GAMS emission fails two distinct ways above
     `2^53` — `2^96` prints as `7.922816251426434000E+28` (scientific, 19 significant digits, not
     EVM-consumable) and `12345678901234567` prints as `12345678901234568`, **silently off by
     one**. Therefore: **(a)** the `tick → sqrtPriceX96` table is generated by exact integer
     arithmetic **outside GAMS**, verified against `TickMath`, committed as data and regenerated
     by `check-fixtures` — *this leg is delivered in Phase 1 under REPR-10, one table shared by
     both, not two*; **(b)** GAMS operates in **tick space** and in the reciprocal/quantity space
     where VPATH-12 makes the recursion affine; **(c)** the emitter substitutes the exact grid
     **string by tick index**, so no value above `2^53` is ever produced by GAMS floating point;
     **(d)** a `rules.tsv` lint reddens any emitted numeric exceeding `2^53` that was not sourced
     from the table, with a committed mutant emitting a GAMS-computed Q96 that must redden.

  2. **VPATH-14 — inputs carry ZERO conversion error by construction.** Emitted swap quantities
     are **exact integers**, and the EVM consumes exactly what was emitted. Any rounding needed
     to make a quantity exactly representable is applied **before** emission and to a definite
     integer, so the JSON value and the value the chain executes are **the same number**. The
     consequence is stated because it governs criterion 4: only GAMS's *predicted outputs* carry
     floating-point error, so the differential test compares outputs rather than absorbing an
     input discrepancy. A committed fixture with a non-integral quantity must redden at emission.

  3. **VPATH-09 — the JSON is readable by forge's cheatcodes and self-sufficient.** It follows
     the pattern already working for `pricing_kernel.json` (`vm.readFile` +
     `vm.parseJsonUintArray`/`parseJsonIntArray`), and the schema carries the quantity array, the
     realized tick/sqrtPrice path, the input shock, and the realized `δ_trans`/`r^φ` — **enough
     for the replay to verify without recomputation**. Committed schema fixture plus a committed
     malformed variant that the reader must reject. `execute_unload`-style discipline applies:
     the file is written last, so a failed run leaves no new JSON.

  4. **VPATH-11 — the replay diff, split honestly by ownership.**
     *GAMS-side, checkable here and committed:* a **tolerance contract** — per-quantity, per
     TEST-02's exponent-dependent rule with its valid range recorded, never a flat `1e-12` — and
     a **GAMS-side self-replay** that re-runs the recursion from the **emitted integers** (not
     the internal doubles) and reproduces `δ_trans`, `r^φ` and the tick path inside that
     contract. That is a genuine check: it exercises exactly the values the chain will see.
     *Cross-track, and NOT claimed by this phase:* replaying `VolumePath[]` through the pool
     actions on-chain is owned by the **GAMS↔Solidity differential-testing session**, per the
     repository ownership map. This phase's obligation is the artifact and the contract; the
     on-chain leg is recorded as an **external dependency**, with the requirement that it
     **fails loudly** on divergence rather than reporting a rate the chain did not realize.
     **UNVERIFIABLE-LEG (from here):** no target in this repository can execute the on-chain
     replay. Stating otherwise would be a criterion about another session's work.

**Plans**: 4 plans
**Research flag**: **LIGHT** — the emission limits are measured and the table construction is
determined. Open: whether the exact table is generated by a committed script in this repo or
imported from the Plank side (ownership question, not a technical one), and the exact JSON
schema field names, which must be agreed with the differential-testing session before they are
pinned.

Plans:
- [ ] 11-01: Tick-indexed exact-grid substitution (VPATH-13 b/c/d) + the `>2^53` lint and its mutant
- [ ] 11-02: Exact-integer quantity emission with pre-emission rounding (VPATH-14)
- [ ] 11-03: JSON schema + forge cheatcode readability + malformed-variant rejection (VPATH-09)
- [ ] 11-04: Tolerance contract + GAMS-side self-replay from emitted integers; hand off the on-chain leg (VPATH-11)

## Requirement Coverage

Every v1 requirement maps to exactly one phase. No orphans, no duplicates.

| Phase | Requirements | Count |
|-------|--------------|-------|
| 0 — Honest gates | GATE-01, GATE-02, GATE-03, GATE-04, GATE-05, GATE-06, GATE-07, TEST-09 | 8 |
| 1 — Representation kernel + dual-representation spine | REPR-01 … REPR-11 | 11 |
| 2 — Test architecture | TEST-01 … TEST-08, VOL-00, VOL-0B, **PROG-00** | 11 |
| 3 — The (Δᵢ, η) solve | SOLVE-01, 02, 03, 04a, 04b, 05, 06, 07 | 8 |
| 4 — Moments / ingestion | DATA-01 … **DATA-11** | 11 |
| 5 — Port foundation | VOL-0A, VOL-01, VOL-02, VOL-03 | 4 |
| 6 — Instrument mechanics | VOL-04, VOL-05, VOL-06, VOL-07, VOL-08 | 5 |
| 7 — VolInstrument + EndogenousMaturity | VOL-09, **VOL-12** | 2 |
| 8 — **The convex programs** | **VOL-10, VOL-11, PROG-01 … PROG-07** | **9** |
| 9 — Coordinate identification | IDENT-01 | 1 |
| 10 — **Shock contract + path model** | **VPATH-01, 02, 03, 04, 05, 06, 07, 08, 10, 12** | **10** |
| 11 — **EVM-unit emission and replay** | **VPATH-09, 11, 13, 14** | **4** |
| **Total** | | **84 / 84 ✓** |

**Placement decisions for the thirty-six requirements added since rev 1** (nine from the
two-step review, two from the rev-3 coverage gap, eight from rev 4's reframing, three from the
Lean submodule refresh, fourteen from the volume-path scope):

| New requirement | Phase | Why there |
|---|---|---|
| GATE-06 (CI reachability) | 0 | A gate nothing can reach is the limiting case of a gate that cannot fail |
| GATE-07 (namespaced Lean sorry-gate) | 0 | Phase 5 criterion 4 is a claim *about* this artifact; it must exist first |
| REPR-10 (independent EVM replica) | 1 | It *is* the representation question — see judgement call 3 |
| REPR-11 (`Add0` second branch) | 1 | A branch that is absent rather than untested is a representation gap |
| TEST-08 (mutation proof per `abort$`) | 2 | Applied retroactively there so it is proven on ~12 assertions before 134 inherit it |
| TEST-09 (committed negative controls) | **0**, not 2 | Phase 0's own criteria are stated against it; it cannot come later than its first consumer |
| VOL-00 (epistemic tiers) | **2**, not 5 | The registry's tier column is assertion-vocabulary, and Phase 3's SOLVE-04a/04b consume it before the port opens |
| VOL-0A (B5 split test) | 5 | "Before the port opens" — it is Phase 5's first plan and can stop the port |
| SOLVE-04a / 04b | 3 | The split *is* the requirement; both halves belong to the solve |
| **DATA-11** (E4 Θ_φ + E1.strike σ²_K) | **4** | Same contract, same `execute_loadDC`, same `check-datapin` as DATA-01/02/08 — but an *independent leg*, given its own plan (04-05) and explicitly not sequenced behind the E3/E6 moments chain |
| **VOL-0B** (parameter provenance) | **2**, not 5 | It is `registry.tsv` schema plus a standing lint, so it belongs with VOL-00; and it has a pre-Phase-5 consumer — DATA-11 is the first entry to use the column. See judgement call 7 |
| **VOL-10** (`FlairOptimization`) | **8** | Promoted from v2. Downstream in the import graph, but it is *where the solved programs live* — collapsed into one phase with the programs it certifies. See judgement call 8 |
| **PROG-00** (non-degeneracy certificate) | **2**, not 8 | A third `registry.tsv` column beside `tier` and `provenance`, with a pre-Phase-8 consumer in Phase 3's SOLVE-04a/04b. See judgement call 9 |
| **PROG-01, PROG-02, PROG-04** | **8** | The three programs whose extremum is *attained* — the ones that get solved |
| **PROG-03** | **8** | The one that does not: asserted as a limit, with a bound-as-optimum guard carrying its own mutation proof |
| **PROG-05** (EVM-expressible) | **8** | Its named units are the *program's* parameters; the `assertEvmExpressible` macro ships in Phase 2 as a consumer relation |
| **PROG-06** (monotonicity signs) | **8**, third plan | Specific to λ_ARB so no earlier home exists, but placed *ahead of* the solves it gates, and checkable with no solver |
| **VOL-11** `MevOptimization` | **8**, first plan | Depends on VOL-10 so it cannot precede Phase 8; PROG-01/04/06 rest on it so it must precede the programs. See judgement call 12 |
| **VOL-12** `EndogenousMaturity` | **7**, not 8 | A leaf with no PROG consumer — 34 theorems in the deliverable phase would dilute it |
| **PROG-07** (MevOptimization's limitations) | **8**, with VOL-11 | That module's own docstring; unlike PROG-00 it has no pre-Phase-8 consumer |
| **VPATH-01/02/03/04/05/06/07/08/10/12** | **10** | Shock decode + the path model, all above the representational cliff. Judgement call 11 |
| **VPATH-09/11/13/14** | **11** | Below the cliff: exact integers, the committed Q96 table, the JSON, the diff |

**Cross-phase notes (requirements whose home phase is not their only touch point — these
are consumer relations, not second mappings):**

- **REPR-09** (53-bit rule) is enforced in Phase 1 but *used* by DATA-06 in Phase 4 (the
  `uint48` hash width), and its enforcement rides on Phase 0's `rules.tsv`.
- **REPR-10**'s tolerance is retrofitted onto `kernelTol(n)` in Phase 2 alongside the two
  existing theorem units.
- **GATE-05** (fixture freshness) is *built* in Phase 0 and first genuinely *exercised* in
  Phase 1, whose schema change forces a re-baseline.
- **GATE-03** ships its assertions in Phase 0; the reusable `assertModelOptimal` macro is a
  Phase 2 TEST-01 deliverable.
- **GATE-07** is repaired in Phase 0 and is what Phase 5 criterion 4 depends on.
- **TEST-08**'s rule lands in Phase 2, but Phase 1 already ships the same *evidence* through
  Phase 0's TEST-09 registry, because REPR-08 cannot wait for the lint.
- **VOL-00**'s tiers are declared in Phase 2 and first consumed in Phase 3.
- **SOLVE-06**'s recorded verdict is an input to Phase 6's plan ordering and Phase 9's entry
  condition.

## Progress

**Execution Order:** 0 → 1 → 2 → {3 ∥ 4 ∥ 5} → 6 → 7 → **8** → 9 (conditional) → 10 → 11

**Phases 10–11 are edge-unblocked after Phase 2** — they depend on Phase 0 (GATE-05), Phase 1
(`priceImpactKernel_Add0`, REPR-10's exact table, REPR-03/09's widths) and Phase 2 (TEST-02),
and on **nothing in Phases 3–9**. They could therefore join the 3∥4∥5 parallel set. The
recommendation above places them last anyway: the parallel set is already three phases wide, and
widening it to five multiplies contention on the shared files that M7 exists to protect. Run
them earlier only if the volume path is independently urgent — the edges permit it, the
`mk/*.mk` and append-only registry machinery makes it safe, and this note is here so that choice
is made deliberately rather than discovered.

Phases 8 and 9 are strictly serial behind 7 — `FlairOptimization` imports from `VolInstrument`,
and no program can be solved before its certificate is ported.

Phases 3, 4 and 5 are the project's genuine parallelism, and their dependency chains are
disjoint: the solve's is menu → NLP → tie extraction → corner assertion; ingestion's is
static grids → legal `ord`/lag → `hasRet` → `realized_variance`; the port foundation's is
split test → bridge design → PosSpec/Main → Flow, which imports only `PosSpec` and needs
nothing from either. Do not invent further parallelism — Phase 6 is where all three join.

The three-way parallelism is only safe because of M7: the root `Makefile` is edited once in
Phase 0 and never again (`-include mk/*.mk`), and `model/lint/rules.tsv` and
`model/test/registry.tsv` are one-entry-per-line and append-only.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Honest gates | 0/4 | Not started | - |
| 1. Representation kernel + spine | 0/6 | Not started | - |
| 2. Test architecture | 0/5 | Not started | - |
| 3. The (Δᵢ, η) solve | 0/5 | Not started | - |
| 4. Moments / ingestion | 0/5 | Not started | - |
| 5. Port foundation | 0/4 | Not started | - |
| 6. Instrument mechanics | 0/5 | Not started | - |
| 7. VolInstrument + EndogenousMaturity | 0/5 | Not started | - |
| 8. The convex programs | 0/6 | Not started | - |
| 9. Coordinate identification | 0/TBD | Not started (conditional) | - |
| 10. Shock contract + path model | 0/5 | Not started | - |
| 11. EVM-unit emission and replay | 0/4 | Not started | - |

---
*Roadmap created: 2026-07-30*
*Roadmap revised (rev 2): 2026-07-30 — after two-step review; 57/57 coverage rebuilt*
*Roadmap revised (rev 3): 2026-07-30 — E4/E1 ingestion gap closed (DATA-11, VOL-0B); 59/59*
*Roadmap revised (rev 4): 2026-07-30 — reframed: GAMS SOLVES the convex programs. VOL-10 promoted from v2, PROG-00..06 added, Phase 8 created, IDENT-01 renumbered to 9; 67/67*
*Roadmap revised (rev 5): 2026-07-30 — VOL-11/VOL-12/PROG-07 mapped; VPATH-01..14 land as Phases 10–11; N3/N5/n9 fixed; Phase 8 certificates re-cited (PROG-04 demoted to assert-only); 84/84*
