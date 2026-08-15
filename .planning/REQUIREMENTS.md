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

- [x] **GATE-01**: `payoff-fixtures`, `spec-preflight`, and `spec-preflight-band` exit non-zero whenever `gams` exits non-zero, verified by a **committed** deliberately-broken fixture that must redden each target on every run. They currently grep the `o=` listing for `Status: (Compilation|Execution) error`, a string only ever written to the log stream, which `lo=0 >/dev/null` destroys — and the `;` before `if` discards the exit code. The Makefile's stated premise ("gams exits 0 even on compile errors") is false: measured rc=2 on compile error, rc=3 on abort.
- [x] **GATE-02**: `abort.noError` appears in no source, enforced by an automated check — it halts execution silently at rc=0 with no status line. **[00-03: LINT-01 in the data-file rule table `model/lint/rules.tsv`; `make lint-gams` reports 0 violations on the tree and reddens on the committed mutant `_mutants/gms/abort_noerror.gms`.]**
- [x] **GATE-03**: every `Solve` statement asserts **`solveStat`** in addition to `modelStat`. Corrected: both existing `Solve`s already assert `modelStat`, and the claimed `modelStat=19` at rc=0 could not be reproduced (baseline modelStat 2/rc=0; injected infeasibility modelStat 4/rc=3). The real gap is a solver terminating **abnormally** while reporting an acceptable `modelStat` — that passes today. **[00-03: no longer passes. LINT-06 (`solveStat`) found exactly **2** violations — `eta_pi_trader_band_monotone_large.gms:118` and `eta_pi_trader_zero_slippage.gms:89` — and LINT-07 (`modelStat`) found **0**, confirming the gap was `solveStat` only. Both units now assert `solveStat` ahead of `modelStat`, and LINT-06/07 redden any future `Solve` that does not. **UNVERIFIABLE-LEG stands:** the `option iterlim = 0` mutant gives solveStat 11 / modelStat 5 at rc=3 — the codes degrade together, so it proves the assertion PAIR fires and does not isolate `solveStat`.]**
- [x] **GATE-04**: `execute` and `$call` failures fail the build, via `execute.checkErrorLevel` and `$call.checkErrorLevel` respectively — noting `$onCheckErrorLevel` governs `$call` only, not `execute`. **[00-03: shipped as SEPARATE rules because that distinction is measured — `$onCheckErrorLevel` plus `execute 'false'` still returns rc=0 and continues. LINT-02 (`execute`), LINT-03 (`$call`), LINT-04 (`$onMulti*`), LINT-05 (`execError =`), one committed mutant each.]**
- [x] **GATE-05**: a committed GDX fixture is provably fresh — regenerating from a clean tree either reproduces it or fails loudly. Scope honestly: `model/price_impact_kernel.gdx` currently has **no regeneration path at all** (`payoff-fixtures` globs only `payoff/eta_*.gms`), so either a producer is built or that fixture is recorded as knowingly unversioned.
- [ ] **GATE-06**: CI is reachable — the `gams-gate` environment has ≥1 required reviewer (`gh api …/environments/gams-gate --jq '.protection_rules|length'` ≥ 1) **and** ≥1 self-hosted runner is registered, with one workflow run reaching the `gams` job and completing. Measured today: the environment exists but has **0 protection rules** (the approval job completed in 2 s and gates nothing) and **0 runners** (the only run ever was cancelled after 24 h). Ordering is load-bearing: **add the protection rules before registering a runner**, or a public repo with a self-hosted runner and an inert gate is the fork-PR arbitrary-execution scenario.
- [x] **GATE-07**: `make lean-sorry-check MODULE=<file> THEOREM=<name>` handles arbitrary indentation and namespace nesting, with a committed negative control (a fixture theorem carrying a real `sorry`) that must redden. The existing gate is hardcoded to three `exp/eta.lean` IDs with a **column-0-anchored** `grep -nE "^theorem $ID"`; **six `vol_markets` modules declare `lemma`, not `theorem`** — FeeSchedule (24), VolInstrument (36), RiskDesign (21), Flow (12), PosSpec (12), GeomProfile (11), each with **zero** column-0 `theorem`s — so `^theorem $ID` matches none of them. **Corrected:** the earlier claim that they are *indented inside namespaces* is false (measured: indented-theorem count is **0** across all 12 files); the mechanism is the keyword, not the column, and a fix targeting indentation would not work, and its column-0 `awk` body-extraction would attribute a later `sorry` to the wrong theorem.

### Representation Kernel

- [ ] **REPR-01**: exactly one module declares every fixed-point scale constant, constructed with `power(2,k)`. Compile-time `$eval` is forbidden for these — `$eval 2**96` is wrong by exactly 2^45.
- [ ] **REPR-02**: η has one canonical representation; any second representation carries a documented bridge and an executable consistency assertion. The WAD-vs-Q0.128 split is the most dangerous conflict in the repo because it fails silently in both directions.
- [ ] **REPR-03**: tick bounds are declared once, with the int24 storage range and the Uniswap usable range distinguished by name, and `minTick` is negative. `primitives.gms` currently declares `minTick /8388607/` — a positive minimum — alongside `maxTick /16777215/` (2²⁴−1).
- [ ] **REPR-04**: `TradingRegion.gms` and `PricingKernel.gms` co-compile with a reconciled `inventory` set, without `$onMultiR` (which silently replaces at rc=0).
- [ ] **REPR-05**: the tick-spacing domain is two-level — parent `/s1*s200/` matching Lean's `Finset.Icc 1 200`, plus a declared `tickSpacingMenu` subset `{1,10,60,200}` — so Δᵢ=200 is expressible and the deployable menu is named. `tickSpacingVal` becomes data-driven rather than `ord(d)`.
- [ ] **REPR-06**: **two overflow regimes, distinguished.** Corrected: *operator* overflow is **loud** (`a*a` at `a=1e299` → `UNDF`, `*** Error … overflow in * operation (mulop)`, rc=3). *Intrinsic* overflow is **silent** — `power(10,300)`, `power(10,400)` and `exp(1000)` all clamp to exactly `1.0000E+299` at rc=0 with `Normal completion`, collapsing 100 orders of magnitude with no diagnostic. Guards key on magnitude against a single named `SATURATION_SENTINEL` declared once in the scales module and **re-derived from `exp(1000)` at build time** so it cannot go stale across GAMS versions — never on `= INF`, never on a per-call-site literal. The previous blanket ban on the saturation constant forbade the only working detector for the silent regime.
- [ ] **REPR-07**: **ANSWERED — it is a units mismatch, not an overflow.** Evidence from `plank/notes/UNITS_AND_SCALES.md`: on-chain `L̄` is **raw `u128`-native liquidity** (the `ΔM → L̄ → positionSize` chain *"`> U128_MAX` reverts"*, `[FACT — LiquidityAmounts.plk:42,110]`), and `ΔQ_v★`/`targetVega` is likewise *"RAW LIQUIDITY units — the Uniswap L dimension (u128-native) … NOT X96, NOT WAD, NOT collateral-denominated."* Prices are what carry the collateral dimension: `p_vol` is Q64.96 *"collateral base units per 1 raw L unit"*, the same kind of object as `cost_m`, *"collateral per unit L̄"*.
  Therefore: GAMS's `LbarQ128 = Q128` is **not an encoding of a chain quantity** — it is a Q128.128 representation of the dimensionless value `1.0`, a normalized modelling fixture. The earlier "one greater than `uint128` max" alarm is **confirmed a false alarm** (`2^128` is the correct Q128.128 encoding of 1.0), and my own restatement of it was wrong twice over — the two fixtures are not both `2^128`, and neither is a raw count.
  What remains is the real defect: **GAMS's `L̄` and the chain's `L̄` are in different units with no documented bridge.** This requirement delivers that bridge — the normalizer, stated explicitly, with the chain-side conversion path named (`liquidity_for_collateral`) and an executable assertion that a GAMS `L̄` round-trips to a raw `u128` within the declared bounds. Unblocked; no longer waiting on cfmm-gams#1.
- [ ] **REPR-08**: exported provenance scalars are **meaningful**, not merely referenced. A read-existence lint is insufficient and is **already gamed**: `inputs('etaQ128') = etaQ128;` is a pure copy into the GDX, so `etaQ128` passes "is read by an assignment" while remaining fabricated provenance — and `sqrtPX96_at` hard-codes its exponent divisor as the literal `2`, so the model structurally cannot vary η. Enforced by TEST-08's mutation rule, not by a read check. (`tieBreaking` is fully dead — zero assignments, zero `abort$`.)
- [ ] **REPR-09a**: **`E1.targetVega` (ΔQ_v★) is a 53-bit-rule case, not an ordinary parameter.** Contract amendment V2-05 (plank `feat/plank@e3fd531`) gives it valid range **[1, 2^96−1]** in **raw liquidity units** — up to 96 bits against GAMS's 53. It therefore cannot be carried exactly at its upper range and needs the same treatment as `seriesIdHash`: either a documented precision boundary above which values are rejected rather than silently truncated, or exact carriage outside GAMS floats. Silent truncation here corrupts a *contractual target*, and the delivery identity it anchors — **delivered `Σ L(i_K) ≤ ΔQ_v★`**, one-sided under floors — would then be asserted against a number the producer never sent.
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
- [x] **TEST-09**: **negative controls are committed artifacts, not one-shot edits.** A `model/test/_mutants/` directory and a `make negative-controls` target run every "X reddens when Y breaks" check as a committed fixture with an expected non-zero exit code. Roughly a dozen roadmap criteria are currently of that shape, each verified once by hand and unfalsifiable a day later — unacceptable in a project whose thesis is that green must be earned. Where a mutation genuinely cannot be fixtured (symbol renames), it is replaced by a static lint that *is* checkable. **[00-01: mechanism shipped — `make negative-controls`, the `model/test/_mutants/` tree, the append-only `registry.tsv`, and the runner's own `registry.selftest.tsv` mutation proof. The per-claim rows are appended by 00-02/03/04; the static-lint substitute for un-fixturable mutations is GATE-02/GATE-04's `rules.tsv`.]**

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
- [ ] **DATA-12**: **E1 is consumed at V2, and the v1 topic0 is never indexed.** Amendment V2-05: `VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew, uint96 targetVega)`, topic0 `0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6`. The v1 signature and its topic0 are **RETIRED-NEVER-LIVE** — a reader that indexes them ingests a series that never existed. The new column `E1.targetVega = ΔQ_v★` is the order's contractual vega target in raw liquidity units (pool-specific; aggregate across pools only through a price), and the optimization receives it **as data**, giving both sides of the delivery identity alongside realized position sizing. Carriage is governed by REPR-09a. Two further decided facts to honour rather than re-derive: `t★ = 2·ΔQ_v/N_σ` is in **seconds** (`N_σ` is a liquidity *rate*, L/second, confirmed by `EndogenousMaturity.lean` — VOL-12 here), and the recalibration law is `t★_mult = t★·(1 − σ²_R/σ²_K)⁺`.
- [ ] **DATA-11**: **the fee-config and strike parameters are ingested, not just the tick series.** E4 `FeeConfigurationChanged` → Θ_φ = {α₁, α₂, β₁, β₂, γ₁, γ₂, φ̄} and E1 `VolOrderCreated`.strike → σ²_K land in named GAMS symbols per contract §4, with the scales left raw (pips for α/φ̄, Algebra vol units tick²·s for β/γ/σ²_K) and converted consumer-side. Both events are **LIVE with topic0 pinned**, yet before this requirement nothing in the plan consumed either: `DATA-01…10` covered only the E3/E6 tick-and-window series, so `VOL-07`'s 24 theorems would have been ported against parameters that had a producer and no ingestion path. Feeds VOL-07 via VOL-0B.

### Volatility Instruments Port

Dependency-ordered over the proven `vol_markets` closure. Each requires its dependencies ported first.

- [ ] **VOL-00**: **epistemic tiers are declared and counted separately.** Every assertion is tagged `THEOREM` (mirrors a proven Lean statement), `BRIDGE` (a GAMS-established link with **no** Lean counterpart), or `INFERENCE` (needs hypotheses the theorem does not carry). Green counts report the tiers separately and never sum them into one number. This exists because `vol_markets` is import-disjoint from `exp/`: the pricing-kernel↔volatility link does not exist in the formalization and is being *established* in GAMS, so those assertions are strictly weaker evidence than the ported theorems and must not be presented as equivalent.
- [ ] **VOL-0A**: before the port opens, the **B5 split test** is run across ten randomly chosen theorems of the 134 — for each, read the Lean statement and determine whether the intended GAMS assertion is the theorem's conclusion or something stronger. The one theorem examined so far (`riskNeutral_corner`, SOLVE-04) failed this test. Half a day, and it determines whether the port's green means anything.

- [ ] **VOL-0B**: **every ported module declares its parameter provenance.** Each `VOL-nn` states, before its port begins, which producer field feeds each parameter — an E-number and a §4 row — or explicitly declares `none (pure theorem, symbolic parameters only)`. A lint reddens any ported module with an undeclared parameter. This exists because the port was specified purely by Lean module and theorem count, which let a **LIVE** producer event sit unconsumed: E4 `FeeConfigurationChanged` appeared exactly once in the entire plan, as a dependency-table row, with no requirement ingesting it. Declaring provenance makes that gap impossible to repeat across the remaining modules.

Provenance below is filled in only where the producer contract states it **explicitly**. The rest are TBD and resolved by VOL-0B during phase planning rather than guessed here.

- [ ] **VOL-01**: `PosSpec` (12 theorems) — no module deps. Parameters: TBD (VOL-0B)
- [ ] **VOL-02**: `Main` (7) — no module deps. Parameters: TBD (VOL-0B)
- [ ] **VOL-03**: `Flow` (12) — depends on PosSpec. Parameters: TBD (VOL-0B)
- [ ] **VOL-04**: `RiskDesign` (21) — depends on Main, Flow. Parameters: TBD (VOL-0B)
- [ ] **VOL-05**: `GeomProfile` (11) — depends on Flow. Parameters: TBD (VOL-0B); if ξ⋆ is consumed it arrives via E2 `PortafolioMinted` (**SPEC-ONLY**)
- [ ] **VOL-06**: `Panoptic` (8) — depends on PosSpec, Flow. Parameters: TBD (VOL-0B); `tokenId` decoding is subgraph-side per contract §6
- [ ] **VOL-07**: `FeeSchedule` (24) — depends on RiskDesign. **Parameters: Θ_φ = {α₁,α₂,β₁,β₂,γ₁,γ₂,φ̄} from E4 `FeeConfigurationChanged` (LIVE), plus σ²_K from E1.strike — §4 names `FeeSchedule.Params.volStrike` as the analog.** Consumes DATA-11.
- [ ] **VOL-08**: `Upsilon` (3) — depends on PosSpec, Flow, Panoptic. **Parameters: realized variance from the DATA-03 moments layer** — the contract's υ-identification / econometric path. Consumes DATA-03 and DATA-07.
- [ ] **VOL-11**: `MevOptimization` (22 theorems, **0 sorry**, landed 2026-07-30) — depends on VolInstrument + FlairOptimization. Formalizes M0–M5 of the doc's MEV section: `ptrade`, `mevHazard`, `mevMulti`, the λ_ARB objective, and the **solved infimum program**. This is the module PROG-01/04/06 actually rest on.
- [ ] **VOL-12**: `EndogenousMaturity` (34 theorems, **0 sorry**, landed 2026-07-30) — depends on VolInstrument + Main + Flow + GeomProfile. VolOrder v2 endogenous maturity. Newly in scope; parameters TBD per VOL-0B.
- [ ] **VOL-10**: `FlairOptimization` (15 theorems, **0 sorry**) — depends on VolInstrument. **Promoted from v2**: this is the module carrying the solved programs the PROG-* requirements formulate (`flairMulti_le_corner`, `flairMulti_corner_attained_levels`, `flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`, `flairMulti_exists_max_compact`, `Theta_lambda_identification`), cited by name at VOLATILITY_INSTRUMENTS.md:459. Parameters: Θ_λ = {φ̄, α, u} level block + (β, γ) shape block.
- [ ] **VOL-09**: `VolInstrument` (36) — depends on Panoptic, Upsilon, GeomProfile, FeeSchedule. Parameters inherited from its four dependencies; σ²_K rows stay **unjoined** to any pool series until E2 exists (DATA-09)

### Convex Programs — what GAMS is actually for

The GAMS layer **solves** the convex programs implied by `VOLATILITY_INSTRUMENTS.md`, which the
lean4-spec layer formalizes and the Plank layer implements on-chain. The representation kernel
(REPR-*) is not a parallel track — it is the **substrate that makes a solved parameter
EVM-expressible**, which is why `PricingKernel` was architected the way it was. A solution the
Plank layer cannot represent is not a solution.

**Non-degenerate first.** Every program below is scoped to a case where the extremum is
*attained*. Cases where it is not are asserted as limits, never solved, and revisited as the
lean4-spec worktree constrains the problems further.

- [ ] **PROG-00**: **two separate certificate obligations, and they are not interchangeable.**
  **(a) Existence** — compactness plus continuity, or coercivity plus closedness. Only this licenses a `Solve`.
  **(b) Uniqueness** — strict convexity/concavity. This licenses *reporting a point*; it does **not** establish existence. (Corrected: the earlier text listed strict convexity as a fact "that makes its extremum exist." It does not — `exp` on ℝ is strictly convex and attains no infimum. The standing rule written to stop a solver reporting a bound as an optimum contained, in its own taxonomy, that exact error.)
  **(c) Convergence** — existence licenses *solving*; it does not establish that the solver's returned point *is* the certified extremum. Every solving unit runs multi-start from committed distinct initial points, asserts all reach the same value at a declared tolerance, and records `modelStat`/`solveStat`/`numInfes`/`iterUsd`. `mevMulti_exists_min_compact` requires only `IsCompact Θ` and `Θ.Nonempty` — no convexity of Θ — and CONOPT is a local solver.
  Each certificate cites a **Lean theorem by name**, and the lint checks the cited theorem's **objective symbol and optimization direction match the program's** — not merely that the cell is non-blank. A program with no existence certificate is not solved; it is asserted as a limit and deferred.

- [ ] **PROG-01**: **M5 — the infimum program on λ_ARB**, solved over a nonempty compact parameter box. Certificates: existence `MevOptimization.mevMulti_exists_min_compact`; the strict-excess claim `mevMulti_min_gt_corner`. Tier **THEOREM**. (Corrected: this previously cited `flairMulti_exists_max_compact` — a *maximum* of *λ_FLAIR* over a different block. Wrong objective, wrong direction. λ_ARB had no Lean counterpart at the submodule pin; `MevOptimization.lean` (22 theorems, 0 sorry, 2026-07-30) now supplies one.)
- [ ] **PROG-02**: **M6a level block — solved.** For a fixed shape block, the λ_FLAIR maximizer and the λ_ARB minimizer are the **same corner** in `(φ̄, α, u)`, attained bang-bang. Certificate: `FlairOptimization.flairMulti_corner_attained_levels` + `flairMulti_le_corner`.
- [ ] **PROG-03**: **M6a shape block — asserted, NOT solved.** Over unbounded `(β, γ)` the bound is approached only as `β → −∞`, with a strict gap at every finite β: a **saturation boundary, not a maximum** (`Theta_lambda_identification`, `flairMulti_saturation_limit`, `flairMulti_strict_below_saturation`). A naive NLP will drive β to a bound and report that bound as the optimum, so this block is encoded as a limit assertion plus a guard that **reddens if any solver returns a shape-block bound as a solution**. Deferred for solving until lean4-spec constrains it.
- [ ] **PROG-04**: **M6b — the constrained program.** Among fee paths with equal FLAIR income the **flat** path minimises λ_ARB, strictly for paths non-constant on positive-weight steps. Certificates: `MevOptimization.ptrade_strictConvexOn` (strict convexity in φ) and `ptrade_strictAntiOn` (strictly decreasing in φ) — both now proven. Existence over the equal-income level set is **not** yet certified, so per PROG-00(a) this is **assert-only until a compactness fact for that level set exists**. Ships `abort$` guards on the doc's two stated hypotheses — the aligned-measure `a ≡ w` and `σ_t ≡ σ_0` — because the doc states that without `a ≡ w` **the conclusion can reverse**. Also records the doc's OPEN note: inside Θ_φ every schedule is a function of σ alone, so at constant σ the strict half may have no bite — whether the committed non-constant path lies inside or outside Θ_φ is declared, not discovered. Tier **INFERENCE**.
- [ ] **PROG-05**: **solved parameters are EVM-expressible.** Every solution lands in the representation kernel's declared scales and bounds (REPR-01/03/05/09) and round-trips through them without loss — pips for φ̄ and α, Algebra vol units for β and γ, the int24 tick range, the 53-bit ceiling. A solution outside what Plank can represent **fails** the program; it is not rounded into range.
- [ ] **PROG-06**: **the monotonicity structure is asserted, not assumed** — λ_ARB antitone in φ̄, in each α_j and in u; isotone in each β_j; convex in the fee. Certificates, exact sign match: `mevMulti_anti_phibar`, `mevMulti_anti_alpha`, `mevMulti_anti_u`, `mevMulti_mono_beta`, `ptrade_convexOn`. Tier **THEOREM**. Two legs: finite differences at committed points, which run with **no solver at all**, plus marginal (`.m`) sign assertions in every solving unit. Lands before PROG-01/02/04.

- [ ] **PROG-07**: **`MevOptimization`'s three stated limitations are carried as executable guards, not prose.** Its own docstring records that (i) `ARB ≈ LVR·P_trade` is a leading-order, fast-block, small-fee **asymptotic approximation**, not an exact identity at finite Δt; (ii) the formalized λ_ARB has **no demand response to the fee**, so *"its corner solution is a property of the stated objective, not a market-equilibrium claim"* — the omitted term being `E[delta-hedged LP P&L] = E[NT_FEE] − E[ARB]`; and (iii) `P_trade` is a **steady-state** quantity for constant parameters, so stepwise application along a varying-σ path is a **quasi-static extension** legitimate *"only if the parameters move slowly relative to mixing of the mispricing process."* Any GAMS solve reporting a corner records which of these it relies on, and no output is labelled a market-equilibrium result.

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
| **The indexer** — the component that reads on-chain logs by `topic0` and emits the GDX this model loads | **UNOWNED AND UNBUILT.** No phase, requirement, or workstream claims it; `topic0` appears nowhere in this plan | Any use of *real* data. v1 is unblocked because DATA-10 proves the interface on a fabricated series, but until an owner exists the solver is fed by hand. Raised as an open question — the producer contract's authors would know whether it is scoped to their track, a new track, or nobody. |
| `gams-gate` GitHub environment | **1 protection rule** — required reviewer `JMSBPP`, added 2026-08-15 by plan 00-04 **before** any runner exists (`prevent_self_review: false`, `can_admins_bypass: true`, neither probed); **0 runners** still registered | GATE-06. The ordering constraint is now satisfied, so registering a runner is safe. Until one exists, `make ci-selftest` exits non-zero on the runner leg and `nc-ci-selftest-positive` is RED by design — see `.planning/ci-evidence.md` |

**Cross-cutting note:** DATA-06's `uint48` rule is a *representation* decision, not a data
decision — it exists for exactly the reason REPR-01 forbids `$eval` and REPR-06 forbids
`= INF` guards: GAMS carries a 53-bit mantissa. It is listed under DATA to match the
producer contract's numbering, but it is enforced by the Phase-1 representation kernel.


### Volume Path — `Shocks → VolumePath[]`  *(phases 10+)*

> **Filed as continuing phases, not a separate milestone.** GSD's `new-milestone` presumes a
> shipped predecessor; v1.0 has shipped nothing (0/42 plans) and no `MILESTONES.md` exists, so
> starting a new milestone would orphan it rather than advance past it. More importantly the two
> are not independent: **VPATH-13 shares REPR-10's exact tick→sqrtPriceX96 table**, VPATH-01
> reuses `priceImpactKernel_Add0`, VPATH-11 uses TEST-02's tolerance rule, and VPATH-09/13 ride
> on GATE-05's fixture-freshness machinery. Those edges belong inside one dependency graph and
> one traceability table.

**What it is.** Given a **volume shock** and a **fixed** iteration count `N`, GAMS generates a swap
path of length `N` — an array of quantities that, entered as swap calls on the contract, realizes
the desired **fee revenue** under `δ_trans` and carries the tick from `i(t)` to `i(t+1)`. Output is
a JSON file forge reads with its JSON utils, so the path can be replayed on-chain and diffed.

`N` is **an input fixed during planning, never an unknown.** The program is therefore a
*generation* problem — any feasible path of length `N` is an answer. Having more freedom than
terminal conditions is expected and is not a defect to be designed away.

**Spec:** `model/mev_tax_model_one/notes.md` (GAMS worktree).
**Reference implementation:** `cfmm-wt/plank/src/models/mev_tax_model_one` — *not* the
`evm-controller` `SwapAmtGen`/`BinomialProxy` files, which are unrelated to this milestone.
**Contract, written by the plank side as the `SELECTOR_NEXT` todo:** (1) encode calldata on
`Shocks {price, tick, volume, volumeDecay}`; (2) build **`Shocks → VolumePath[]`** ← *this is the
GAMS deliverable*; (3) send `VolumePath` as a batch with `Shocks` as HookData; (4) verify they
match `Shocks` — *this is the differential test*.

- [ ] **VPATH-01**: the state recursion is implemented as specified — `p₍₁,Δᵢ₎(i(n+1)) = L̄·p₍₁,Δᵢ₎(i(n)) / (L̄ + p₍₁,Δᵢ₎(i(n))·ΔQ_X(n))` — by **reusing** `priceImpactKernel_Add0`, not by writing a second copy of the same algebra. It is the identical form already restored in `PricingKernel.gms`, and the Q96 scale asymmetry there is load-bearing.
- [ ] **VPATH-02**: `ΔQ_M(n) = −L̄·p₍₂,Δᵢ₎(i(n))·ΔQ_X / (L̄ + p₍₁,Δᵢ₎(i(n))·ΔQ_X)`, with the swap sign condition `ΔQ_X(n)·ΔQ_M(n) < 0` **enforced per step as a constraint**, never assumed. It is the doc's "shock-induced flow is a swap".
- [ ] **VPATH-03**: the three path functionals are computed exactly as specified — `π^φ(n)` (fee income), `ν_trans(n) = Σ√(p̄|ΔQ_X·ΔQ_M|)` (note the **geometric** mean, not arithmetic), and `π̄(n)` (total notional) — with `p̄ ≡ p₍₂,Δᵢ₎(i(0))` and `φ̄ = 1 − (1−φ̄_X)(1−φ̄_M)`.
- [ ] **VPATH-04**: the generated path satisfies both terminal targets — `δ_trans(N) = δ*_trans` and `r_N^φ = φ̄·δ*_trans`, where `r_n^φ = π^φ(n)/π̄(n)` and `δ_trans(n) = ν_trans(n)/π̄(n)`.
- [ ] **VPATH-05**: `N` is a **fixed input**. The model generates *a* feasible path, and the residual freedom (`N+1` quantities against two terminal conditions) is declared as expected rather than closed by an invented objective. If a selection rule among feasible paths is later wanted, it is added deliberately and named.
- [ ] **VPATH-06**: the shock is decoded exactly as the reference declares it — `next(address pool, uint160 sqrtPrice, int24 tick, uint24 txlVolumeRate, uint24 txlDecayRate)`, selector `0xd3827b0b`. `txlVolumeRate` is `δ_trans`. Widths are binding: `uint24` rates, `int24` tick, `uint160` sqrtPrice — all subject to REPR-03/09.
- [ ] **VPATH-07**: `txlDecayRate` is **DECIDED: not considered in this model.** It is decoded because its position in the 5-argument selector fixes the calldata offsets of the fields that follow it, but it enters no equation and no functional. It is **not** exported as provenance — REPR-08's lesson applies directly: `etaQ128` is exported, copied into the GDX, reads as meaningful, and is not. A pass-through value that no assignment consumes must be labelled as such or omitted, never shipped looking load-bearing.
- [ ] **VPATH-08**: **DECIDED: the closed loop holds — `i(0) = i(N)`.** The path is a round trip in tick space, so `p̄ ≡ p₍₂,Δᵢ₎(i(0))` is well defined at both ends and `ν_trans` measures genuine round-trip volume.
- [ ] **VPATH-12**: **the closure is imposed as the linear constraint `Σₙ ΔQ_X(n) = 0`, not as a nonlinear terminal condition on the recursion.** Verified exactly in GAMS 54.1: the state recursion is *affine in reciprocal coordinates* — `1/p₍₁,Δᵢ₎(i(n+1)) − 1/p₍₁,Δᵢ₎(i(n)) = ΔQ_X(n)/L̄`, with measured deviation `0.000` — so telescoping gives `1/p_N − 1/p_0 = (1/L̄)·Σ ΔQ_X(n)`, and `p_N = p_0 ⟺ Σ ΔQ_X = 0`. Measured both directions: `Σ = −1e17 → p_N = 1.1111…` (open), `Σ = 0 → |p_N − p_0| = 0.00000000000000` (closed). This is very likely the content of the MEV notes' **Theorem 29 (the monoid path is direct)** and **Theorem 30 (path decomposition)** — reciprocal price under swap composition is an additive monoid — and that correspondence is confirmed against the Lean/doc statements before the structure is relied on, not assumed from the algebra alone. Practical consequence: closure costs one linear equality instead of a nonlinear boundary condition, and the recursion need not be inverted.
- [ ] **VPATH-09**: **the JSON is consumed live, in-test, not only as a committed fixture.** The loop is: the forge test sets the shock state on a running **Anvil**; a bridge reads the live pool state off Anvil (`sqrtPrice`, `tick`, `L̄` — the `x(n)` state vector) together with the desired shock; it invokes the GAMS prover; GAMS emits the VolumePath JSON in EVM units; the bridge returns it to the test, which decodes it into an **array of swap orders** and executes them. State therefore comes from the **chain**, not from a fixture, so GAMS's state and the chain's cannot silently diverge. Verified available: `anvil` and `forge` are on PATH, and **`ffi = true` is already set** in the consuming project's `foundry.toml` (line 7, with `fs_permissions` declared) — the live path needs no config change. A committed fixture remains the *offline* mode (DATA-10 / the `pricing_kernel.json` `vm.readFile` pattern) for runs with no GAMS present; both modes read the same schema.
- [ ] **VPATH-10**: the fixture pins the reference's own setup constants, not invented ones — `SQRT_PRICE_1_1 = 2^96`, liquidity range `tick(SQRT_PRICE_1_4)…tick(SQRT_PRICE_4_1)` rounded to **tickSpacing 60**, `UNIT_LIQUIDITY = 2^64`. Divergence from these makes any differential result meaningless.
- [ ] **VPATH-11**: the differential test realizes step 4 — replaying `VolumePath[]` through the pool actions reproduces GAMS's `δ_trans`, `r^φ` and tick path within the declared tolerances (TEST-02's exponent-dependent rule, not a flat `1e-12`), and **fails loudly** on divergence rather than reporting a rate the chain did not realize.

- [ ] **VPATH-13**: **the JSON is emitted in EVM units, and the Q64.96 grid is a committed exact table — never GAMS float arithmetic.** The reader parses the file and is done; no consumer-side conversion exists. This is achievable only because the grid is indexed by `tick` (`int24`, trivially exact) and `sqrtPriceX96(tick)` is a pure function of it. Measured limits that force the design: at Q96 magnitude (~7.9e28) the double spacing is **2^44 ≈ 1.759e13**, so a 97-bit `sqrtPriceX96` retains 53 bits and its **low 44 bits do not exist**; and GAMS emission fails in two distinct ways above `2^53` — `2^96` prints as `7.922816251426434000E+28` (scientific, 19 significant digits, not EVM-consumable) and `12345678901234567` prints as `12345678901234568`, **silently off by one**. Therefore: (a) the tick→`sqrtPriceX96` table is generated by **exact integer arithmetic outside GAMS** and verified against `TickMath`, committed as data and regenerated by `check-fixtures`; (b) GAMS operates in **tick space** and in the reciprocal/quantity space where VPATH-12 makes the recursion affine; (c) the emitter substitutes the exact grid string **by tick index**, so no value above `2^53` is ever produced by GAMS floating point; (d) a lint reddens any emitted numeric exceeding `2^53` that was not sourced from the exact table. This is the same construction REPR-10 needs — *the reference is data, not code* — so the two share one table rather than each building their own.
- [ ] **VPATH-14**: **emitted swap quantities are exact integers, and the EVM consumes exactly what was emitted.** Inputs therefore carry **zero** conversion error by construction — only GAMS's *predicted* outputs carry floating-point error, which is what VPATH-11's tolerance governs. Any rounding applied to make a quantity exactly representable is performed **before** emission and to a definite integer, so the JSON value and the value the chain executes are the same number, and the differential test compares outputs rather than absorbing an input discrepancy.

- [ ] **VPATH-15**: **the prover is invocable as a CLI from outside this repository.** `cfmm-gams` contains no forge or Anvil surface — it is `model/`, `mk/`, `docs/`, `lean4-spec/` and a Makefile — while the test and the bridge live in the Plank/monorepo tree. So the deliverable at this boundary is a documented, deterministic entry point: given a shock and the live state, it writes the VolumePath JSON to a named path and exits non-zero on any failure to solve. No forge, Anvil or Solidity dependency enters this repo.
- [ ] **VPATH-16**: **the loop is honest about what it proves.** The bridge and the forge-side harness belong to the differential-testing track, not this session — this repo owns the prover and the JSON contract. The differential assertion compares *chain-realized* `δ_trans` / `r^φ` / tick path against *GAMS-predicted*, within TEST-02's exponent-dependent tolerance, and **fails loudly on divergence** rather than reporting a rate the chain did not realize. A run in offline (committed-fixture) mode must be labelled as such in its output, because it proves schema conformance only, not chain agreement.
- [ ] **VPATH-17**: **the live path does not inherit the existing bridge's quantization.** `tools/gamsdiff/core.py` documents its own limit — *"the reference is therefore quantized to ~2^44 and is not exact-integer ground truth"* — which independently corroborates the `2^44` spacing measured for VPATH-13. The VolumePath emitter therefore does **not** round GAMS floats into Q96 integers the way `to_sqrt_price_x96()` does; it substitutes exact values from REPR-10's committed tick-indexed table. A lint reddens any emitted `sqrtPriceX96` produced by rounding rather than lookup.

## v2 Requirements

- ~~**FLAIR-01**~~ — **PROMOTED TO v1 as VOL-10.** The import-graph argument (it imports *from* `VolInstrument`, so it is downstream) was topologically right and functionally backwards: `FlairOptimization` is where the solved programs actually live. Downstream in imports does not mean lower priority when the deliverable is solving.
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

Rebuilt during roadmap revision (**rev 5**, 2026-07-30): 17 previously-unmapped requirements
placed, and the roadmap extended with Phases 10–11 for the volume-path work.
Every v1 requirement maps to **exactly one** phase. Notes record cross-phase consumers,
which are not second mappings.

| Requirement | Phase | Status | Note |
|-------------|-------|--------|------|
| GATE-01 | Phase 0 — Honest gates | Complete |  |
| GATE-02 | Phase 0 — Honest gates | Complete (00-03) | LINT-01 in `model/lint/rules.tsv`; mutant `_mutants/gms/abort_noerror.gms`, row `nc-lintgams-abort-noerror` |
| GATE-03 | Phase 0 — Honest gates | Complete (00-03) | Confirmed by measurement: LINT-06 (`solveStat`) found **2** violations, LINT-07 (`modelStat`) found **0**. Both `Solve`s now assert `solveStat` first. UNVERIFIABLE-LEG stands — the `iterlim=0` mutant gives solveStat 11 / modelStat 5, degrading together. `assertModelOptimal` macro is still a Phase 2 deliverable |
| GATE-04 | Phase 0 — Honest gates | Complete (00-03) | Confirmed by measurement and shipped as SEPARATE rules: LINT-02 (`execute`), LINT-03 (`$call`), plus LINT-04 (`$onMulti*`) and LINT-05 (`execError =`). One mutant each |
| GATE-05 | Phase 0 — Honest gates | **Met (00-04)** | Scoped to the two producible payoff fixtures, both content-identical on regeneration; `price_impact_kernel.gdx` declared knowingly unversioned in `model/fixtures/UNVERSIONED.md` (a producer EXISTS at `PriceImpactKernelFixture.gms:28` but is wired into no target; funding one was declined). LINT-08 reddens any new undeclared `.gdx`. Also carries Phase 11's exact-Q96-table regeneration (VPATH-13a) |
| GATE-06 | Phase 0 — Honest gates | **OPEN — rules leg met (00-04), runner leg not** | Environment already EXISTS (auto-created 2026-07-27) with 0 rules and 0 runners — the work is configuring, not creating. Protection rules BEFORE runner registration |
| GATE-07 | Phase 0 — Honest gates | **Met (00-04)** | Phase 5 c4 and Phase 8 c1 are both claims about this artifact. `make spec-preflight` runs no Lean grep at all today |
| TEST-09 | Phase 0 — Honest gates | Mechanism complete (00-01) | Phase 0's own criteria are stated against `make negative-controls`, so it cannot come later than its first consumer |
| REPR-01 | Phase 1 — Representation kernel + spine | Pending |  |
| REPR-02 | Phase 1 — Representation kernel + spine | Pending |  |
| REPR-03 | Phase 1 — Representation kernel + spine | Pending | Consumed by PROG-05 (Phase 8) and by VPATH-06's int24/uint160 widths (Phase 10) |
| REPR-04 | Phase 1 — Representation kernel + spine | Pending |  |
| REPR-05 | Phase 1 — Representation kernel + spine | Pending | Δᵢ=200 reachability makes `riskNeutral_corner`'s corner expressible for SOLVE-04a; also a PROG-05 bound |
| REPR-06 | Phase 1 — Representation kernel + spine | Pending | **N3 FIXED in rev 5:** the sentinel is checked against a committed `saturation.pin`, NOT against `exp(1000)` recomputed — rev 4's guard was a tautology and could never fire |
| REPR-07 | Phase 1 — Representation kernel + spine | Pending | **ANSWERED — no longer blocked.** `plank/notes/UNITS_AND_SCALES.md` settles it: on-chain L̄ is raw u128-native liquidity, collateral lives in the prices, so `LbarQ128 = Q128` is a normalized fixture and `2^128` is correct. Plan **01-05** delivers the missing units bridge (normalizer named, `liquidity_for_collateral` named, executable round-trip into raw u128 bounds) — it does **not** record both candidate readings |
| REPR-08 | Phase 1 — Representation kernel + spine | Pending | Enforced by mutation proof, not a read-existence lint (already gamed). Its lesson is applied verbatim by VPATH-07's non-export rule |
| REPR-09 | Phase 1 — Representation kernel + spine | Pending | First plan of Phase 1; consumed by DATA-06, PROG-05's 53-bit ceiling, and VPATH-13's `>2^53` emission lint |
| REPR-09a | Phase 1 — Representation kernel + spine | Pending | Planned into **01-01** with REPR-09, whose most consequential instance it is. `E1.targetVega` range [1, 2^96−1] vs GAMS's 53 bits: the policy is **reject, never truncate**, with `assertTargetVegaCarriable` and a control proving the rejection fires. Consumed by DATA-12 (Phase 4) |
| REPR-10 | Phase 1 — Representation kernel + spine | Pending | **The Core Value made executable.** Leg (b) CORRECTED in rev 5: the reference is a committed EXACT TABLE generated outside GAMS, not `TickMathReplica.gms` code — GAMS floats cannot carry Q96 (2^44 spacing). **This is the same table VPATH-13 consumes in Phase 11 — one artifact, built here** |
| REPR-11 | Phase 1 — Representation kernel + spine | Pending | `assertAdd0Branch` restored to the TEST-01 macro list; `priceImpactKernel_Add0` is reused by VPATH-01 |
| TEST-01 | Phase 2 — Test architecture | Pending | Macro list includes `assertAdd0Branch` (REPR-11) and `assertEvmExpressible` (first REQUIRED by PROG-05 in Phase 8) |
| TEST-02 | Phase 2 — Test architecture | Pending | Its exponent-dependent rule governs Phase 10's terminal targets and Phase 11's replay tolerance contract — a flat 1e-12 is banned there too |
| TEST-03 | Phase 2 — Test architecture | Pending | Proof mutant: the measured residual 1.73334e-33 scaled by 1e6 still passes under `zeroTolerance`, must redden under `absFloor` |
| TEST-04 | Phase 2 — Test architecture | Pending | `registry.tsv`, one entry per line, append-only (M7); THREE columns — VOL-00 tier, VOL-0B provenance, PROG-00 certificate |
| TEST-05 | Phase 2 — Test architecture | Pending | 'green with CONOPT absent' is uncheckable — replaced by a no-`Solve`-in-pure-tier lint plus a nonexistent-solver fixture |
| TEST-06 | Phase 2 — Test architecture | Pending | gdxdiff rc table recorded (0/1/2/3); `rc != 0` conservative predicate, conflation noted |
| TEST-07 | Phase 2 — Test architecture | Pending |  |
| TEST-08 | Phase 2 — Test architecture | Pending | Applied retroactively to every existing `abort$`. Its most consequential downstream uses are PROG-03's bound-as-optimum guard and REPR-06's pin check — both must ship units that deliberately trigger them |
| VOL-00 | Phase 2 — Test architecture | Pending | Tier column is assertion vocabulary; SOLVE-04a/04b consume it in Phase 3 |
| VOL-0B | Phase 2 — Test architecture | Pending | `registry.tsv` schema + a standing lint, first consumed by Phase 4's DATA-11. Roadmap judgement call 7 |
| PROG-00 | Phase 2 — Test architecture | Pending | **CORRECTED in rev 5 — three separate obligations.** (a) EXISTENCE (compactness+continuity, or coercivity+closedness) is the ONLY thing licensing a `Solve`; (b) UNIQUENESS (strict convexity) licenses reporting a POINT and does NOT establish existence — `exp` on ℝ is strictly convex and attains no infimum, and rev 4's taxonomy contained that error; (c) CONVERGENCE — multi-start from committed distinct points, since `mevMulti_exists_min_compact` needs only IsCompact+Nonempty (no convexity of Θ) and CONOPT is local. The lint now checks objective symbol AND direction match, which is what catches PROG-01's mis-citation |
| SOLVE-01 | Phase 3 — The (Delta_i, eta) solve | Pending | No speedup claim (14× was over 200 solves, menu is 4). No demo-license size assert — it could never fire |
| SOLVE-02 | Phase 3 — The (Delta_i, eta) solve | Pending | Its tie machinery interacts with PROG-02's bang-bang corner extraction — a Phase 8 research question |
| SOLVE-03 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| SOLVE-04a | Phase 3 — The (Delta_i, eta) solve | Pending | THEOREM tier — value only, ≥1e-9 relative, after `objScale`. PROG-00(a) certificate: corner attainment at γ=0 |
| SOLVE-04b | Phase 3 — The (Delta_i, eta) solve | Pending | INFERENCE tier — separate unit, `θ.b > 0` guard, tag lint + guard-removal mutant. Certificate explicitly ABSENT, which is why it is inference |
| SOLVE-05 | Phase 3 — The (Delta_i, eta) solve | Pending | Scoping PROVISIONAL under the constant-`w` premise, enforced by `make check-wstate` |
| SOLVE-06 | Phase 3 — The (Delta_i, eta) solve | Pending | Exports `degeneracyBreaks`, gating Phase 9 and ordering Phase 6. NOT known to be the same phenomenon as Phase 8's M6a degeneracy — separate, relationship unknown |
| SOLVE-07 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| DATA-01 | Phase 4 — Moments / ingestion | Pending | Three legs; `action=c` rc=0 is a NECESSARY CONDITION ONLY (an empty file passes it) |
| DATA-02 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-03 | Phase 4 — Moments / ingestion | Pending | `W` per-market and time-varying from E6. Consumed by VOL-08 |
| DATA-04 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-05 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-06 | Phase 4 — Moments / ingestion | Pending | Enforced by REPR-09 (Phase 1); listed under DATA to match producer contract numbering |
| DATA-07 | Phase 4 — Moments / ingestion | Pending | Consumed by VOL-08 alongside DATA-03 |
| DATA-08 | Phase 4 — Moments / ingestion | Pending | Pinned to `cfmm-replicationPlank@d34846c`, enforced by `make check-datapin` |
| DATA-09 | Phase 4 — Moments / ingestion | Pending | Exercised against DATA-10's fabricated fixture; must NOT depend on E2/E5 existing |
| DATA-10 | Phase 4 — Moments / ingestion | Pending | The fixture that makes legs (2) and (3) of DATA-01 checkable |
| DATA-11 | Phase 4 — Moments / ingestion | Pending | Independent ingestion leg — own plan (04-05), NOT sequenced behind DATA-03/05/07. Feeds VOL-07 and through it Phase 8's Θ_φ |
| VOL-0A | Phase 5 — Port foundation | Pending | **Gates the port.** Its census form is re-applied to Phase 8's 14 cited theorems. Per-theorem verdict is a human reading — UNVERIFIABLE-LEG, declared |
| VOL-01 | Phase 5 — Port foundation | Pending | Imports only Mathlib. Provenance TBD, resolved in-phase |
| VOL-02 | Phase 5 — Port foundation | Pending | Imports only Mathlib. Provenance TBD, resolved in-phase |
| VOL-03 | Phase 5 — Port foundation | Pending | Graph articulation point (out-degree 4); imports only PosSpec. Bridge DESIGN precedes it in the same phase |
| VOL-04 | Phase 6 — Instrument mechanics | Pending | Provenance TBD — must resolve before porting |
| VOL-05 | Phase 6 — Instrument mechanics | Pending | Provenance TBD; ξ⋆ if consumed arrives via E2 (**SPEC-ONLY**) — fabricated fixture only, never live data |
| VOL-06 | Phase 6 — Instrument mechanics | Pending | Provenance TBD; `tokenId` decoding is subgraph-side per §6, so GAMS-side provenance is `none` by construction |
| VOL-07 | Phase 6 — Instrument mechanics | Pending | **Consumes DATA-11** — Θ_φ from E4 (LIVE) + σ²_K from E1.strike. Θ_φ is also what Phase 8's programs range over |
| VOL-08 | Phase 6 — Instrument mechanics | Pending | **Consumes DATA-03 and DATA-07**; plan order routed by SOLVE-06's recorded verdict |
| VOL-09 | Phase 7 — VolInstrument + EndogenousMaturity | Pending | In-degree-4 convergence node. The gateway to Phase 8, not the endpoint |
| VOL-12 | Phase 7 — VolInstrument + EndogenousMaturity | Pending | **Placed in 7, not 8** (roadmap judgement call 12): depends on VolInstrument+Main+Flow+GeomProfile, all landed by Phase 7, and feeds NO PROG requirement. 34 theorems with no program consumer would dilute the deliverable phase. Provenance TBD |
| VOL-10 | Phase 8 — The convex programs | Pending | Promoted from v2 (was FLAIR-01). 15 thm, 0 sorry. Supplies PROG-02/03's certificates |
| VOL-11 | Phase 8 — The convex programs | Pending | **Phase 8's FIRST plan.** 22 thm, 0 sorry, landed 2026-07-30. Depends on VOL-10 so it cannot precede Phase 8; PROG-01/04/06 rest on it so it must precede the programs. This is the module that supplies λ_ARB, which had NO Lean counterpart at the old pin |
| PROG-01 | Phase 8 — The convex programs | Pending | **SOLVE** — M5 infimum on λ_ARB over a nonempty compact box. Certificates RE-CITED in rev 5: `mevMulti_exists_min_compact` (existence) + `mevMulti_min_gt_corner` (strict excess). Tier THEOREM. *Rev 4 cited `flairMulti_exists_max_compact` — wrong objective (λ_FLAIR), wrong direction (max) — in the flagship program* |
| PROG-02 | Phase 8 — The convex programs | Pending | **SOLVE** — M6a level block, corner attained bang-bang. `flairMulti_corner_attained_levels` + `flairMulti_le_corner`. Reports WHICH corner; a bound perturbation must MOVE it |
| PROG-03 | Phase 8 — The convex programs | Pending | **ASSERT ONLY** — shape block unbounded, saturation boundary as β → −∞, strict gap at every finite β. Limit assertion + bound-as-optimum guard shipping a unit that deliberately triggers it |
| PROG-04 | Phase 8 — The convex programs | Pending | **DEMOTED to ASSERT-ONLY in rev 5.** `ptrade_strictConvexOn` + `ptrade_strictAntiOn` are proven, but existence over the equal-income level set is NOT certified and PROG-00(a) requires existence, not convexity. Tier INFERENCE. Ships `abort$` guards on `a ≡ w` and `σ_t ≡ σ_0` (without `a ≡ w` the doc says the conclusion can REVERSE), and records the OPEN note that at constant σ the strict half may have no bite |
| PROG-05 | Phase 8 — The convex programs | Pending | A solution outside the kernel's scales/bounds FAILS — never rounded into range. This is why Phases 0-2 are the substrate. `assertEvmExpressible` ships in Phase 2 |
| PROG-06 | Phase 8 — The convex programs | Pending | Phase 8's **third plan**, ahead of the solves it gates. Certificates RE-CITED with exact sign match: `mevMulti_anti_phibar/anti_alpha/anti_u`, `mevMulti_mono_beta`, `ptrade_convexOn`. Tier THEOREM. Finite-difference leg runs with NO solver |
| PROG-07 | Phase 8 — The convex programs | Pending | Lands with VOL-11 in plan 08-02 — MevOptimization's own three docstring limitations as guards: the ARB≈LVR·P_trade leading-order asymptotic, NO demand response to the fee (so a corner is a property of the objective, NOT a market-equilibrium claim), and P_trade steady-state ⇒ quasi-static path application. A lint reddens the phrase 'market equilibrium' on any output |
| IDENT-01 | Phase 9 — Coordinate identification (CONDITIONAL) | Pending | Opens iff SOLVE-06 records `degeneracyBreaks = 1`; otherwise INVALIDATED. Deliberately NOT promoted — the reframing's instruction was non-degenerate first |
| VPATH-06 | Phase 10 — Shock contract + path model | Pending | Selector `0xd3827b0b`, 5 args; `txlVolumeRate` IS `δ_trans`. Widths binding via REPR-03/09 |
| VPATH-07 | Phase 10 — Shock contract + path model | Pending | **DECIDED: not considered.** Decoded only because its position fixes downstream calldata offsets. NOT exported as provenance — REPR-08's lesson applied verbatim; a lint reddens it in any `execute_unload` |
| VPATH-10 | Phase 10 — Shock contract + path model | Pending | Reference constants pinned, not invented: `SQRT_PRICE_1_1 = 2^96` (from the exact table, never a GAMS float), range rounded to tickSpacing 60, `UNIT_LIQUIDITY = 2^64` |
| VPATH-01 | Phase 10 — Shock contract + path model | Pending | **Reuses `priceImpactKernel_Add0`** — a lint reddens a second copy of the same algebra. The Q96 scale asymmetry there is load-bearing |
| VPATH-02 | Phase 10 — Shock contract + path model | Pending | Swap sign condition `ΔQ_X·ΔQ_M < 0` enforced per step AS A CONSTRAINT, never assumed |
| VPATH-12 | Phase 10 — Shock contract + path model | Pending | **Phase 10's articulation point.** Recursion is affine in reciprocal coordinates (measured deviation 0.000), so closure is ONE LINEAR equality `Σ ΔQ_X = 0` — no nonlinear terminal condition, no inverting the recursion. Both directions measured. The Theorem 29/30 monoid correspondence is CONFIRMED against the Lean/doc statements, not inferred from matching algebra |
| VPATH-08 | Phase 10 — Shock contract + path model | Pending | **DECIDED: the loop closes, i(0) = i(N)**, so `p̄` is well defined at both ends and `ν_trans` measures genuine round-trip volume |
| VPATH-03 | Phase 10 — Shock contract + path model | Pending | `ν_trans` uses the GEOMETRIC mean — a committed fixture where the arithmetic form differs must redden |
| VPATH-04 | Phase 10 — Shock contract + path model | Pending | Both terminal targets at TEST-02 exponent-dependent tolerances, never a bare literal |
| VPATH-05 | Phase 10 — Shock contract + path model | Pending | `N` is a FIXED INPUT — this is GENERATION, not solving. Residual freedom is EXPECTED, not a defect; a lint reddens any objective function in the path model. `N` must be a `Parameter`, never a `Variable` |
| VPATH-13 | Phase 11 — EVM-unit emission and replay | Pending | **The representational cliff.** GAMS floats provably cannot carry Q96: 2^44 spacing, `2^96` emits as scientific notation, `12345678901234567` emits off by one. Exact tick-indexed table generated OUTSIDE GAMS. **Leg (a) — the table — is delivered in Phase 1 under REPR-10; one shared artifact, not two.** Legs (b)(c)(d) are emission-side here |
| VPATH-14 | Phase 11 — EVM-unit emission and replay | Pending | Emitted quantities are EXACT INTEGERS, so inputs carry ZERO conversion error by construction; rounding happens BEFORE emission to a definite integer. Only predicted OUTPUTS carry float error — which is what VPATH-11's tolerance governs |
| VPATH-09 | Phase 11 — EVM-unit emission and replay | Pending | forge cheatcode pattern already working for `pricing_kernel.json`; schema self-sufficient so the replay verifies without recomputation. Written last, so a failed run leaves no new JSON |
| VPATH-11 | Phase 11 — EVM-unit emission and replay | Pending | **Split by ownership.** GAMS-side and checkable here: the TEST-02 tolerance contract + a self-replay from the EMITTED INTEGERS. The on-chain replay is owned by the GAMS↔Solidity differential-testing session per the repo ownership map — recorded as an external dependency and marked UNVERIFIABLE-LEG from this repo, not claimed |

**Coverage:**
- v1 requirements: **84 total** (48 → 57 review → 59 E4 → 67 programs → 70 Lean refresh → 84 volume path)
- Mapped to phases: **84 / 84 ✓**
- Unmapped: **0**
- Duplicates: **0** (each requirement appears in exactly one row)
- Phases: **12** (0–11)

| Phase | Count |
|-------|-------|
| Phase 0 — Honest gates | 8 |
| Phase 1 — Representation kernel + spine | 11 |
| Phase 2 — Test architecture | 11 |
| Phase 3 — The (Delta_i, eta) solve | 8 |
| Phase 4 — Moments / ingestion | 11 |
| Phase 5 — Port foundation | 4 |
| Phase 6 — Instrument mechanics | 5 |
| Phase 7 — VolInstrument + EndogenousMaturity | 2 |
| Phase 8 — The convex programs | 9 |
| Phase 9 — Coordinate identification (CONDITIONAL) | 1 |
| Phase 10 — Shock contract + path model | 10 |
| Phase 11 — EVM-unit emission and replay | 4 |
| **Total** | **84** |

**Placement of the seventeen requirements mapped by rev 5:**

| Requirement | Phase | Why there |
|---|---|---|
| **VOL-11** `MevOptimization` | 8, first plan | Depends on VOL-10 so it cannot precede Phase 8; PROG-01/04/06 rest on it so it must precede the programs. Only topologically consistent slot |
| **VOL-12** `EndogenousMaturity` | **7**, not 8 | A leaf with no PROG consumer. 34 theorems irrelevant to the deliverable would dilute the deliverable phase |
| **PROG-07** limitations | 8, with VOL-11 | That module's own docstring; unlike PROG-00 it has no pre-Phase-8 consumer |
| **VPATH-01/02/03/04/05/06/07/08/10/12** | **10** | Shock decode + path model — everything above the representational cliff, where GAMS doubles are adequate |
| **VPATH-09/11/13/14** | **11** | Below the cliff: exact integers, the committed Q96 table, the JSON, the diff |

**Why two VPATH phases and not one or four.** The cut between 10 and 11 is a *measured*
representational cliff, not a stage boundary: above it everything lives in GAMS doubles and
tick space, below it everything must be exact integers, because `2^96` emits as scientific
notation and `12345678901234567` emits silently off by one. A single phase would state half its
criteria in a number system the other half cannot represent. Splitting further — decode without
a model, or emit without a replay — would produce phases whose success criterion is "a file
exists", the horizontal-layer anti-pattern refused at every other cut in this roadmap.

**Not a new milestone.** GSD `new-milestone` presumes a shipped predecessor; v1.0 has shipped
nothing (0/54 plans, no `MILESTONES.md`). The two scopes are also coupled — VPATH-13 shares
REPR-10's exact table, VPATH-01 reuses `priceImpactKernel_Add0`, VPATH-11 uses TEST-02's
tolerance rule, VPATH-09/13 ride on GATE-05 — so they belong in one graph and one table.
Phases 0–9 keep their numbering and content.

---
*Requirements defined: 2026-07-28*
*Traceability rebuilt: 2026-07-30 (rev 5)*
