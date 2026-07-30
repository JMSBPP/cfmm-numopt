# Requirements: cfmm-gams

**Defined:** 2026-07-28
**Core Value:** Every geometric primitive carries a Lean-coordinate evaluator, an EVM-coordinate fixed-point evaluator, and an executable assertion that the two agree under a documented coordinate bridge.

> Every requirement below traces to a measured finding in `.planning/research/`.
> The dominant risk class in this repo is **silent wrongness**, not loud failure —
> most requirements exist to make a wrong answer *fail* rather than to add capability.

## v1 Requirements

### Build Integrity

**Scoped claim (corrected after review).** `compile-gams` and `test-gams` gate **correctly** —
they use `if $(GAMS) …; then`, i.e. the exit code — verified by live mutation: injecting a failing
`abort$` into a test unit makes `test-gams` return rc=2. CI runs only those two, so **CI is not
blind**. The false-pass defect is confined to `payoff-fixtures`, `spec-preflight`, and
`spec-preflight-band` — the fixture-regeneration and proof-gating paths. Still serious (fixtures
go stale silently, proof gates are vacuous), but narrower than "all green is uninformative",
which overstated the blast radius.

- [ ] **GATE-01**: `payoff-fixtures`, `spec-preflight`, and `spec-preflight-band` exit non-zero whenever `gams` exits non-zero, verified by a **committed** deliberately-broken fixture that must redden each target on every run. They currently grep the `o=` listing for `Status: (Compilation|Execution) error`, a string only ever written to the log stream, which `lo=0 >/dev/null` destroys — and the `;` before `if` discards the exit code. The Makefile's stated premise ("gams exits 0 even on compile errors") is false: measured rc=2 on compile error, rc=3 on abort.
- [ ] **GATE-02**: `abort.noError` appears in no source, enforced by an automated check — it halts execution silently at rc=0 with no status line.
- [ ] **GATE-03**: every `Solve` statement asserts **`solveStat`** in addition to `modelStat`. Corrected: both existing `Solve`s already assert `modelStat`, and the claimed `modelStat=19` at rc=0 could not be reproduced (baseline modelStat 2/rc=0; injected infeasibility modelStat 4/rc=3). The real gap is a solver terminating **abnormally** while reporting an acceptable `modelStat` — that passes today.
- [ ] **GATE-04**: `execute` and `$call` failures fail the build, via `execute.checkErrorLevel` and `$call.checkErrorLevel` respectively — noting `$onCheckErrorLevel` governs `$call` only, not `execute`.
- [ ] **GATE-05**: a committed GDX fixture is provably fresh — regenerating from a clean tree either reproduces it or fails loudly. Scope honestly: `model/price_impact_kernel.gdx` currently has **no regeneration path at all** (`payoff-fixtures` globs only `payoff/eta_*.gms`), so either a producer is built or that fixture is recorded as knowingly unversioned.
- [ ] **GATE-06**: CI is reachable — the `gams-gate` environment has ≥1 required reviewer (`gh api …/environments/gams-gate --jq '.protection_rules|length'` ≥ 1) **and** ≥1 self-hosted runner is registered, with one workflow run reaching the `gams` job and completing. Measured today: the environment exists but has **0 protection rules** (the approval job completed in 2 s and gates nothing) and **0 runners** (the only run ever was cancelled after 24 h). Ordering is load-bearing: **add the protection rules before registering a runner**, or a public repo with a self-hosted runner and an inert gate is the fork-PR arbitrary-execution scenario.
- [ ] **GATE-07**: `make lean-sorry-check MODULE=<file> THEOREM=<name>` handles arbitrary indentation and namespace nesting, with a committed negative control (a fixture theorem carrying a real `sorry`) that must redden. The existing gate is hardcoded to three `exp/eta.lean` IDs with a **column-0-anchored** `grep -nE "^theorem $ID"`; all 134 `vol_markets` theorems are indented inside namespaces, so it matches **zero** of them, and its column-0 `awk` body-extraction would attribute a later `sorry` to the wrong theorem.

### Representation Kernel

- [ ] **REPR-01**: exactly one module declares every fixed-point scale constant, constructed with `power(2,k)`. Compile-time `$eval` is forbidden for these — `$eval 2**96` is wrong by exactly 2^45.
- [ ] **REPR-02**: η has one canonical representation; any second representation carries a documented bridge and an executable consistency assertion. The WAD-vs-Q0.128 split is the most dangerous conflict in the repo because it fails silently in both directions.
- [ ] **REPR-03**: tick bounds are declared once, with the int24 storage range and the Uniswap usable range distinguished by name, and `minTick` is negative. `primitives.gms` currently declares `minTick /8388607/` — a positive minimum — alongside `maxTick /16777215/` (2²⁴−1).
- [ ] **REPR-04**: `TradingRegion.gms` and `PricingKernel.gms` co-compile with a reconciled `inventory` set, without `$onMultiR` (which silently replaces at rc=0).
- [ ] **REPR-05**: the tick-spacing domain is two-level — parent `/s1*s200/` matching Lean's `Finset.Icc 1 200`, plus a declared `tickSpacingMenu` subset `{1,10,60,200}` — so Δᵢ=200 is expressible and the deployable menu is named. `tickSpacingVal` becomes data-driven rather than `ord(d)`.
- [ ] **REPR-06**: **two overflow regimes, distinguished.** Corrected: *operator* overflow is **loud** (`a*a` at `a=1e299` → `UNDF`, `*** Error … overflow in * operation (mulop)`, rc=3). *Intrinsic* overflow is **silent** — `power(10,300)`, `power(10,400)` and `exp(1000)` all clamp to exactly `1.0000E+299` at rc=0 with `Normal completion`, collapsing 100 orders of magnitude with no diagnostic. Guards key on magnitude against a single named `SATURATION_SENTINEL` declared once in the scales module and **re-derived from `exp(1000)` at build time** so it cannot go stale across GAMS versions — never on `= INF`, never on a per-call-site literal. The previous blanket ban on the saturation constant forbade the only working detector for the silent regime.
- [ ] **REPR-07**: `LbarQ128` and `DICfgQ128` are reconciled against their intended on-chain width, and the question is settled: is L̄ a raw `uint128` liquidity count or a normalized dimensionless quantity? Corrected: the two are **not both** `2^128` — each unit sets exactly one to `2^128` and the other to `2^128/10`, swapped between units (`zero_slippage` L̄=1/Δ^I=0.1; `band` L̄=0.1/Δ^I=1.0). If these are genuine Q128.128 encodings then `2^128` correctly represents `1.0` and there is no overflow; the earlier "one greater than uint128 max" framing conflated a fixed-point encoding with a raw count. Blocked on the answer to the `E2.liquidityBar` normalizer question raised on cfmm-gams#1.
- [ ] **REPR-08**: exported provenance scalars are **meaningful**, not merely referenced. A read-existence lint is insufficient and is **already gamed**: `inputs('etaQ128') = etaQ128;` is a pure copy into the GDX, so `etaQ128` passes "is read by an assignment" while remaining fabricated provenance — and `sqrtPX96_at` hard-codes its exponent divisor as the literal `2`, so the model structurally cannot vary η. Enforced by TEST-08's mutation rule, not by a read check. (`tieBreaking` is fully dead — zero assignments, zero `abort$`.)
- [ ] **REPR-09**: **the 53-bit rule** — any integer identifier, hash, or exact-valued quantity crossing into a GAMS numeric must fit in `2^53`, and the kernel states this once as a shared constraint rather than re-deriving it per call site. This is the general form of the rule that forces `seriesIdHash` to `uint48` (DATA-06), forbids `$eval` for scale constants (REPR-01), and makes `= INF` guards useless (REPR-06). Anything wider is silently truncated with no diagnostic.
- [ ] **REPR-10**: **the Core Value, made executable — an independent EVM replica.** A `TickMath` replica implementing the EVM's actual `getSqrtRatioAtTick` integer/bit operations, which does **not** derive from the `lambda` scalar, plus a real agreement assertion against `priceKernel`/`sqrtPX96_at`. Without it the "dual representation" is common-mode and cannot detect a wrong λ: `sqrtPX96_at` is `P_Lean_at` with the exponent halved and an exact power-of-two scaling, both reading the single `lambda` at `PricingKernel.gms:11`, and all 33 call sites pass `lambdaWad`. Measured today, the two documented bridges are non-evidence — `sqrtPX96 = √P_Lean·Q96` exists **only as a comment** (the sole `sqrt(` in the model, `_PayoffScaffolding.gms:21`), and `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean` is a **tautology** whose `abort$` recomputes the expression that defined it, so it cannot fire. Includes the cheap immediate leg: compare `piGridPlank` against `piGridLean` across all 181 in-band points — currently both are computed and **never compared**, so the number of band points carrying a cross-representation check is **zero**.
- [ ] **REPR-11**: `priceImpactKernel_Add0` covers both EVM branches, or its single-branch scope is asserted and the other branch's absence is made detectable. It currently contains **zero conditional operators** — the `add=false` branch is simply absent, and no test can detect the gap.

### Test Architecture

- [ ] **TEST-01**: a guarded assertion library provides `assertApproxEqRel` / `assertApproxEqAbs` / `assertApproxEqClose`, printing both operands and the computed error on failure. `abort` accepts identifiers only, never expressions, which dictates the macro design.
- [ ] **TEST-02**: relative tolerance is exponent-dependent. GAMS `**` error is `≈1.101e-17·(i·Δᵢ)`, systematic and signed; a flat `1e-12` exhausts at exponent ≈90,800, inside the declared domain.
- [ ] **TEST-03**: zero assertions are made at residual level with a scale-derived `absFloor()`, a degree-matching rule, and a non-degeneracy companion — a one-sided zero assertion cannot fire when the quantity collapses. `zeroTolerance = 1e-20` is currently an artifact of `sqr()`, ~900× weaker than `diffTolerance`.
- [ ] **TEST-04**: one driver per theorem unit plus a registry, following GAMS Development's own `testlib` architecture. Aggregating solver-bearing units is structurally impossible — `$150 Symbolic equations redefined` is unconditional even under `$onMulti`.
- [ ] **TEST-05**: solver-dependent units are partitioned so the suite degrades honestly when CONOPT is absent, using `system.solverNames` (which reports installed, not licensed).
- [ ] **TEST-06**: golden GDX fixtures are diffed with `gdxdiff`, keyed on `rc != 0` rather than `rc == 1`, since its full return-code set is undocumented.
- [ ] **TEST-07**: the test architecture is documented as an in-repo reference that every subsequent unit follows.
- [ ] **TEST-08**: **every `abort$` ships a registered mutation proof** — a recorded perturbation of one input that makes it fire — run by `make test-mutations` and required by the registry, with a lint reddening any `abort$` that has none. Applied retroactively to the existing units in Phase 2 so the rule is proven before 134 units inherit it. This is the general rule behind four separately-measured instances of assertions that cannot fail: the three grep-based Makefile gates; the `spec-preflight` sorry check (zero real `sorry`/`admit` exist repo-wide, so it scans for nothing); the tautological bridge assertion; and the `zeroTolerance` zero-checks, whose measured residual `1.73334e-33` against `1e-20` would still pass under an error **2.4 million times larger**. It subsumes REPR-08 — a read-existence lint is gameable, a mutation proof is not.
- [ ] **TEST-09**: **negative controls are committed artifacts, not one-shot edits.** A `model/test/_mutants/` directory and a `make negative-controls` target run every "X reddens when Y breaks" check as a committed fixture with an expected non-zero exit code. Roughly a dozen roadmap criteria are currently of that shape, each verified once by hand and unfalsifiable a day later — unacceptable in a project whose thesis is that green must be earned. Where a mutation genuinely cannot be fixtured (symbol renames), it is replaced by a static lint that *is* checkable.

### Parameter Solve

- [ ] **SOLVE-01**: `(Δᵢ, η)` is solved by a menu-loop of NLPs over `tickSpacingMenu`. CONOPT cannot do MINLP — `option minlp = conopt` is compile error `$255`.
- [ ] **SOLVE-02**: the argmax is extracted with deterministic tie-breaking honouring `tieBreaking /1/` (smallest index under ties), including the `+INF`-on-empty trap.
- [ ] **SOLVE-03**: an `objScale` constant in the scaffolding lets CONOPT reach its documented `Tol_Optimality = 1e-7`. The objective is ~1e-9 unscaled; scaling by 1e10 moves argmin error from `8.9e-3` to `1.25e-14`.
- [ ] **SOLVE-04a** *(THEOREM tier)*: at γ=0 the solved **value** is asserted against `riskNeutral_corner`. This is what the Lean theorem actually establishes — it bounds a value.
- [ ] **SOLVE-04b** *(INFERENCE tier)*: any assertion on the **coordinates** at γ=0 is explicitly guarded on the hypotheses it needs and labelled as inference, not as the theorem. Asserting coordinates requires argmax uniqueness — which Lean does not provide (`g θ` is `Classical.choice`; a sweep found no `∃!`, `StrictConcave`, or `StrictConvex` anywhere in the spec, so no uniqueness route exists) — plus a hypothesis `θ.b > 0` that `riskNeutral_corner` does not carry. Conflating the two would encode a **stronger proposition than the theorem proves**, in the flagship assertion, in the one place hypothesis-guarding is required.
- [ ] **SOLVE-05**: the solve reports value, the product `Δᵢ·η`, and `nTies` — and reports coordinates **only** at γ=0. The payoff depends on the controls solely through their product; 62 equally-optimal pairs were measured at γ=100, and Lean's `g θ` is `Classical.choice` with no uniqueness lemma.
- [ ] **SOLVE-06**: an identifiability spike couples `ComparativeStatics.retVol` / `liqShare` (which depend on η alone) into the objective and reports whether the degeneracy breaks.
- [ ] **SOLVE-07**: fixed-point magnitudes stay inside macros and never enter a `Variable`. `Lim_Variable = 1e15` against `Q96 = 7.9e28` yields `solveStat=10`, `modelStat=13`, and variables left silently at starting values.

### Data & Moments

- [ ] **DATA-01**: ingestion happens through `execute_loadDC`, and the model compiles at `action=c` with no data file present. `$gdxIn` on a missing file is a hard compile error (rc=2), which would redden `compile-gams` on every machine.
- [ ] **DATA-02**: a model-owned static capacity grid (`tAll`) carries loaded membership (`tObs(tAll)`), with `ord()` and lag applied only to the parent. Execution-time loads cannot introduce new labels — a bare set silently yields `card=0` at rc=0. `tObs` loads **E3's emitted `timestamp` field** (what the σ² kernel consumed), never the block timestamp (contract §3).
- [ ] **DATA-03**: windowed `mean_tick` and `realized_variance` are computed with explicit boundary handling; the first window has one fewer return. **The window `W` is NOT constant** — it is stored per market and arrives from the E6 `WindowChanged` history, so σ² reconstruction is `(volCum(t) − volCum(t−W)) / W` with `W` looked up per series and per time (contract §4).
- [ ] **DATA-04**: only linear lag is used; circular `--` is banned — it fabricates a return by wrapping first→last.
- [ ] **DATA-05**: the internal consistency identity `RV_log = (log λ)²·RV_tick` is asserted (measured to hold at `4.01e-13`).
- [ ] **DATA-06**: series provenance is `seriesIdHash = uint48(keccak256(abi.encode(chainId, emitter, poolId)))`, computed identically producer- and consumer-side. **uint48, not uint256** — `uint48 < 2^53` survives an IEEE-double load losslessly, where a 256-bit hash silently loses ~200 bits. `poolId = 0` is a **permanent** module-global sentinel series, never a placeholder that later mutates (contract §2).
- [ ] **DATA-07**: `rv_bar` normalization makes realized variance comparable across windows of differing cardinality and differing `W`.
- [ ] **DATA-08**: the consumer half of the data contract — expected symbol names and domains — matching the producer's §4 field→symbol→scale table, **pinned to `cfmm-replicationPlank@d34846c`** and re-verified when `feat/plank` merges to `develop`. Raw on-chain scales arrive; all conversion (Q96→dimensionless ξ, pips, tick²·s vol units) is consumer-side. Enforced by REPR-09 for any identifier crossing the boundary.
- [ ] **DATA-09**: loader integrity rules are enforced, not assumed: E5↔`Swap` joins on same-tx + same-poolId + nearest-preceding `logIndex` with `FeeApplied.fee == Swap.fee` asserted on every joined pair (never poolId alone); σ²_K (E1) rows stay **unjoined** to any pool series until E2 exists — no fabricated linkage.
- [ ] **DATA-10**: a fabricated-series fixture proves the interface **before any subgraph exists**, demonstrating that fabricated, simulated, and API-sourced series all satisfy one contract.

### Volatility Instruments Port

Dependency-ordered over the proven `vol_markets` closure. Each requires its dependencies ported first.

- [ ] **VOL-00**: **epistemic tiers are declared and counted separately.** Every assertion is tagged `THEOREM` (mirrors a proven Lean statement), `BRIDGE` (a GAMS-established link with **no** Lean counterpart), or `INFERENCE` (needs hypotheses the theorem does not carry). Green counts report the tiers separately and never sum them into one number. This exists because `vol_markets` is import-disjoint from `exp/`: the pricing-kernel↔volatility link does not exist in the formalization and is being *established* in GAMS, so those assertions are strictly weaker evidence than the ported theorems and must not be presented as equivalent.
- [ ] **VOL-0A**: before the port opens, the **B5 split test** is run across ten randomly chosen theorems of the 134 — for each, read the Lean statement and determine whether the intended GAMS assertion is the theorem's conclusion or something stronger. The one theorem examined so far (`riskNeutral_corner`, SOLVE-04) failed this test. Half a day, and it determines whether the port's green means anything.

- [ ] **VOL-01**: `PosSpec` (12 theorems) — no dependencies
- [ ] **VOL-02**: `Main` (7) — no dependencies
- [ ] **VOL-03**: `Flow` (12) — depends on PosSpec
- [ ] **VOL-04**: `RiskDesign` (21) — depends on Main, Flow
- [ ] **VOL-05**: `GeomProfile` (11) — depends on Flow
- [ ] **VOL-06**: `Panoptic` (8) — depends on PosSpec, Flow
- [ ] **VOL-07**: `FeeSchedule` (24) — depends on RiskDesign
- [ ] **VOL-08**: `Upsilon` (3) — depends on PosSpec, Flow, Panoptic
- [ ] **VOL-09**: `VolInstrument` (36) — depends on Panoptic, Upsilon, GeomProfile, FeeSchedule

### Coordinate Identification (conditional)

- [ ] **IDENT-01**: if and only if SOLVE-06 shows the degeneracy breaks, `(Δᵢ, η)` coordinates are recovered and asserted away from γ=0. If it does not break, this requirement is closed as invalidated and the product remains the deliverable.

## External Dependencies

Tracked because they gate v1 items and are owned by another workstream.

| Dependency | State | Gates |
|---|---|---|
| Producer data contract `notes/DATA_CONTRACT.md` @ `d34846c` | **Stable but NOT merged to develop** — lives on `feat/plank` only | All DATA items. Pin to the sha; re-verify on merge in case the branch rebases. |
| E1 `VolOrderCreated`, E3 `TimepointWritten`, E4 `FeeConfigurationChanged`, E6 `WindowChanged` | LIVE, topic0 pinned | DATA-02/03/05/07 are buildable now against these |
| E2 `PortafolioMinted` (ξ⋆, ι, L̄, tokenId) | **SPEC-ONLY** — owed by plank task #14 | `Lbar`/`xiVal` symbols; the σ²_K↔pool linkage in DATA-09 |
| E5 `FeeApplied` (σ, φ) | **SPEC-ONLY** — owed by plank task #16 | The fee/σ series and the DATA-09 join rule |
| `gams-gate` GitHub environment | Not created | All CI |

**Cross-cutting note:** DATA-06's `uint48` rule is a *representation* decision, not a data
decision — it exists for exactly the reason REPR-01 forbids `$eval` and REPR-06 forbids
`= INF` guards: GAMS carries a 53-bit mantissa. It is listed under DATA to match the
producer contract's numbering, but it is enforced by the Phase-1 representation kernel.

## v2 Requirements

- **FLAIR-01**: port `vol_markets/FlairOptimization.lean` (15 theorems) — imports *from* `VolInstrument`, so it sits downstream of the v1 closure
- **SORRY-01**: the `exp/` modules carrying a `sorry` (`eta.lean`, `BondingCurveCurvature`, `DynamicsOptimization`) once proven
- **SUBMOD-01**: monorepo submodule wiring at `gams/`, pending gamsdiff and CI session sign-off
- **WSTATE-01**: re-run the degeneracy analysis under a state-dependent η̃-measure `w` — every experiment used a constant `w`

## Out of Scope

| Feature | Reason |
|---------|--------|
| Live on-chain data ingestion | Source is deliberately pluggable and follows the Plank schema, which is not fixed |
| Bit-exact GAMS↔EVM equality | Structurally impossible — IEEE doubles vs 256-bit integers |
| Closed-loop control / deployment | This track produces parameters; consuming them belongs to the Plank and controller tracks |
| Deciding the Q128.128 intent of `L̄`/`Δ^I` | Requires reading the Plank `CESLongPayoff.plk` harness, owned by another session |
| A second-solver cross-check | Flagged as a research gap; CONOPT is the only licensed NLP solver |

## Traceability

Populated during roadmap creation (2026-07-30). Every v1 requirement maps to
**exactly one** phase. Notes record cross-phase consumers, which are not second
mappings.

| Requirement | Phase | Status | Note |
|-------------|-------|--------|------|
| GATE-01 | Phase 0 — Honest gates | Pending |  |
| GATE-02 | Phase 0 — Honest gates | Pending |  |
| GATE-03 | Phase 0 — Honest gates | Pending | Minimal inline form here; reusable `assertModelOptimal` macro is a Phase 2 TEST-01 deliverable |
| GATE-04 | Phase 0 — Honest gates | Pending |  |
| GATE-05 | Phase 0 — Honest gates | Pending | Built in Phase 0; first genuinely exercised by Phase 1's fixture re-baseline |
| REPR-01 | Phase 1 — Representation kernel | Pending |  |
| REPR-02 | Phase 1 — Representation kernel | Pending |  |
| REPR-03 | Phase 1 — Representation kernel | Pending |  |
| REPR-04 | Phase 1 — Representation kernel | Pending |  |
| REPR-05 | Phase 1 — Representation kernel | Pending |  |
| REPR-06 | Phase 1 — Representation kernel | Pending |  |
| REPR-07 | Phase 1 — Representation kernel | Pending |  |
| REPR-08 | Phase 1 — Representation kernel | Pending |  |
| REPR-09 | Phase 1 — Representation kernel | Pending | First plan of Phase 1 (REPR-01/REPR-06 are its corollaries); consumed by DATA-06; enforced via Phase 0's lint harness |
| TEST-01 | Phase 2 — Test architecture | Pending |  |
| TEST-02 | Phase 2 — Test architecture | Pending |  |
| TEST-03 | Phase 2 — Test architecture | Pending |  |
| TEST-04 | Phase 2 — Test architecture | Pending |  |
| TEST-05 | Phase 2 — Test architecture | Pending |  |
| TEST-06 | Phase 2 — Test architecture | Pending |  |
| TEST-07 | Phase 2 — Test architecture | Pending |  |
| SOLVE-01 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| SOLVE-02 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| SOLVE-03 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| SOLVE-04 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| SOLVE-05 | Phase 3 — The (Delta_i, eta) solve | Pending | Scoping PROVISIONAL under the constant-`w` assumption (v2 WSTATE-01) |
| SOLVE-06 | Phase 3 — The (Delta_i, eta) solve | Pending | Exports the machine-readable `degeneracyBreaks` verdict that gates Phase 8 and orders Phase 6 |
| SOLVE-07 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| DATA-01 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-02 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-03 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-04 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-05 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-06 | Phase 4 — Moments / ingestion | Pending | Enforced by REPR-09 (Phase 1); listed under DATA to match producer contract numbering |
| DATA-07 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-08 | Phase 4 — Moments / ingestion | Pending | Pinned to `cfmm-replicationPlank@d34846c`; re-verify on `feat/plank` -> `develop` merge |
| DATA-09 | Phase 4 — Moments / ingestion | Pending | Exercised against DATA-10's fabricated fixture; must NOT depend on E2/E5 data existing |
| DATA-10 | Phase 4 — Moments / ingestion | Pending |  |
| VOL-01 | Phase 5 — Port foundation | Pending |  |
| VOL-02 | Phase 5 — Port foundation | Pending |  |
| VOL-03 | Phase 5 — Port foundation | Pending | Graph articulation point (out-degree 4) - the bridge-design gate |
| VOL-04 | Phase 6 — Instrument mechanics | Pending |  |
| VOL-05 | Phase 6 — Instrument mechanics | Pending |  |
| VOL-06 | Phase 6 — Instrument mechanics | Pending |  |
| VOL-07 | Phase 6 — Instrument mechanics | Pending |  |
| VOL-08 | Phase 6 — Instrument mechanics | Pending | Cross-phase hook: consumes Phase 4 moments; plan order routed by SOLVE-06's verdict |
| VOL-09 | Phase 7 — VolInstrument | Pending | In-degree-4 convergence node; demo-license ceiling becomes a hard wall here |
| IDENT-01 | Phase 8 — Coordinate identification (CONDITIONAL) | Pending | CONDITIONAL - opens iff SOLVE-06 records `degeneracyBreaks = 1`; otherwise closed as INVALIDATED |

**Coverage:**
- v1 requirements: **57 total** (was 48; +9 from the two-step review)
- Mapped to phases: **0 ⚠️ — traceability INVALIDATED by the review, pending roadmap revision**
- Unmapped: **57 ⚠️**

New since review: GATE-06 (CI reachability), GATE-07 (namespaced Lean sorry-gate),
REPR-10 (independent EVM replica — the Core Value made executable), REPR-11
(priceImpactKernel_Add0 second branch), TEST-08 (mutation proof per abort$),
TEST-09 (committed negative controls), VOL-00 (epistemic tiers), VOL-0A (B5 split
test), and SOLVE-04 split into 04a THEOREM / 04b INFERENCE.


---
*Requirements defined: 2026-07-28*
*Traceability populated: 2026-07-30*
