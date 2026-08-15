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
| `gams-gate` GitHub environment | **Exists** (auto-created 2026-07-27 by the first workflow run) but with **0 protection rules**; **0 runners** registered | GATE-06. Add the required reviewers *before* registering a runner — a public repo with a self-hosted runner behind an inert gate is the fork-PR execution scenario |

**Cross-cutting note:** DATA-06's `uint48` rule is a *representation* decision, not a data
decision — it exists for exactly the reason REPR-01 forbids `$eval` and REPR-06 forbids
`= INF` guards: GAMS carries a 53-bit mantissa. It is listed under DATA to match the
producer contract's numbering, but it is enforced by the Phase-1 representation kernel.


## Milestone v1.1 — `Shocks → VolumePath[]`

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
- [ ] **VPATH-09**: the emitted JSON is readable by forge's JSON cheatcodes and follows the pattern already working for `pricing_kernel.json` (`vm.readFile` + `vm.parseJsonUintArray`/`parseJsonIntArray`). The schema carries the quantity array, the realized tick/sqrtPrice path, the input shock, and the realized `δ_trans`/`r^φ` — enough for step 4 to verify without recomputation.
- [ ] **VPATH-10**: the fixture pins the reference's own setup constants, not invented ones — `SQRT_PRICE_1_1 = 2^96`, liquidity range `tick(SQRT_PRICE_1_4)…tick(SQRT_PRICE_4_1)` rounded to **tickSpacing 60**, `UNIT_LIQUIDITY = 2^64`. Divergence from these makes any differential result meaningless.
- [ ] **VPATH-11**: the differential test realizes step 4 — replaying `VolumePath[]` through the pool actions reproduces GAMS's `δ_trans`, `r^φ` and tick path within the declared tolerances (TEST-02's exponent-dependent rule, not a flat `1e-12`), and **fails loudly** on divergence rather than reporting a rate the chain did not realize.

- [ ] **VPATH-13**: **the JSON is emitted in EVM units, and the Q64.96 grid is a committed exact table — never GAMS float arithmetic.** The reader parses the file and is done; no consumer-side conversion exists. This is achievable only because the grid is indexed by `tick` (`int24`, trivially exact) and `sqrtPriceX96(tick)` is a pure function of it. Measured limits that force the design: at Q96 magnitude (~7.9e28) the double spacing is **2^44 ≈ 1.759e13**, so a 97-bit `sqrtPriceX96` retains 53 bits and its **low 44 bits do not exist**; and GAMS emission fails in two distinct ways above `2^53` — `2^96` prints as `7.922816251426434000E+28` (scientific, 19 significant digits, not EVM-consumable) and `12345678901234567` prints as `12345678901234568`, **silently off by one**. Therefore: (a) the tick→`sqrtPriceX96` table is generated by **exact integer arithmetic outside GAMS** and verified against `TickMath`, committed as data and regenerated by `check-fixtures`; (b) GAMS operates in **tick space** and in the reciprocal/quantity space where VPATH-12 makes the recursion affine; (c) the emitter substitutes the exact grid string **by tick index**, so no value above `2^53` is ever produced by GAMS floating point; (d) a lint reddens any emitted numeric exceeding `2^53` that was not sourced from the exact table. This is the same construction REPR-10 needs — *the reference is data, not code* — so the two share one table rather than each building their own.
- [ ] **VPATH-14**: **emitted swap quantities are exact integers, and the EVM consumes exactly what was emitted.** Inputs therefore carry **zero** conversion error by construction — only GAMS's *predicted* outputs carry floating-point error, which is what VPATH-11's tolerance governs. Any rounding applied to make a quantity exactly representable is performed **before** emission and to a definite integer, so the JSON value and the value the chain executes are the same number, and the differential test compares outputs rather than absorbing an input discrepancy.

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

Rebuilt during roadmap revision (**rev 4**, 2026-07-30) after the deliverable was reframed:
the GAMS layer **solves** the convex programs, it does not only verify theorems.
Every v1 requirement maps to **exactly one** phase. Notes record cross-phase consumers,
which are not second mappings.

| Requirement | Phase | Status | Note |
|-------------|-------|--------|------|
| GATE-01 | Phase 0 — Honest gates | Pending |  |
| GATE-02 | Phase 0 — Honest gates | Pending |  |
| GATE-03 | Phase 0 — Honest gates | Pending | `solveStat` is the gap; `modelStat` is already asserted by both existing `Solve`s. Reusable `assertModelOptimal` macro is a Phase 2 TEST-01 deliverable |
| GATE-04 | Phase 0 — Honest gates | Pending | `$onCheckErrorLevel` covers `$call` only — `execute` needs its own rule |
| GATE-05 | Phase 0 — Honest gates | Pending | Scoped to the two producible payoff fixtures; `price_impact_kernel.gdx` has no producer (fund one or record as unversioned). First genuinely exercised by Phase 1's re-baseline |
| GATE-06 | Phase 0 — Honest gates | Pending | The environment already EXISTS (auto-created 2026-07-27 by the first workflow run) with 0 rules and 0 runners — the work is configuring, not creating. Protection rules BEFORE runner registration |
| GATE-07 | Phase 0 — Honest gates | Pending | Phase 5 criterion 4 and Phase 8 criterion 1 are both claims about this artifact, so it must exist first. `make spec-preflight` runs no Lean grep at all today |
| TEST-09 | Phase 0 — Honest gates | Pending | Moved to Phase 0 (not Phase 2): Phase 0's own criteria are stated against `make negative-controls` |
| REPR-01 | Phase 1 — Representation kernel + spine | Pending |  |
| REPR-02 | Phase 1 — Representation kernel + spine | Pending |  |
| REPR-03 | Phase 1 — Representation kernel + spine | Pending | Consumed by PROG-05 — the int24 range is one of the bounds a solved parameter must round-trip through |
| REPR-04 | Phase 1 — Representation kernel + spine | Pending |  |
| REPR-05 | Phase 1 — Representation kernel + spine | Pending | Δᵢ=200 reachability is what makes `riskNeutral_corner`'s corner expressible for SOLVE-04a; also a PROG-05 bound |
| REPR-06 | Phase 1 — Representation kernel + spine | Pending | Two regimes, two committed controls: loud (`a*a` at 1e299, rc=3) and silent (`power(10,400)`, rc=0) |
| REPR-07 | Phase 1 — Representation kernel + spine | Pending | **BLOCKED on cfmm-gams#1.** If unanswered, record both candidate readings + an `abort$` on undeclared assumption — do not guess |
| REPR-08 | Phase 1 — Representation kernel + spine | Pending | Enforced by mutation proof (TEST-09 registry in Phase 1, TEST-08 lint from Phase 2) — the read-existence lint is already gamed |
| REPR-09 | Phase 1 — Representation kernel + spine | Pending | First plan of Phase 1 (REPR-01/REPR-06 are its corollaries); consumed by DATA-06 and by PROG-05's 53-bit ceiling; enforced via Phase 0's `rules.tsv` |
| REPR-10 | Phase 1 — Representation kernel + spine | Pending | **The Core Value made executable.** 181-point grid comparison (immediate), `TickMathReplica.gms` (independent of `lambda`), retirement of the comment-only and tautological bridges |
| REPR-11 | Phase 1 — Representation kernel + spine | Pending | `assertAdd0Branch` restored to the TEST-01 macro list |
| TEST-01 | Phase 2 — Test architecture | Pending | Macro list includes `assertAdd0Branch` (REPR-11) and `assertEvmExpressible` (shipped here, first REQUIRED by PROG-05 in Phase 8) |
| TEST-02 | Phase 2 — Test architecture | Pending |  |
| TEST-03 | Phase 2 — Test architecture | Pending | Proof mutant: the measured residual 1.73334e-33 scaled by 1e6 still passes under `zeroTolerance`, must redden under `absFloor` |
| TEST-04 | Phase 2 — Test architecture | Pending | `registry.tsv`, one entry per line, append-only (M7); carries THREE columns — VOL-00 tier, VOL-0B provenance, PROG-00 certificate |
| TEST-05 | Phase 2 — Test architecture | Pending | 'green with CONOPT absent' is uncheckable — replaced by a no-`Solve`-in-pure-tier lint plus a nonexistent-solver fixture exercising the reason string |
| TEST-06 | Phase 2 — Test architecture | Pending | gdxdiff rc table recorded (0/1/2/3); `rc != 0` kept as the conservative predicate, conflation noted |
| TEST-07 | Phase 2 — Test architecture | Pending |  |
| TEST-08 | Phase 2 — Test architecture | Pending | Applied retroactively to every existing `abort$` in this phase. Its most consequential downstream use is PROG-03's bound-as-optimum guard, which must ship a unit that deliberately triggers it |
| VOL-00 | Phase 2 — Test architecture | Pending | Moved to Phase 2 (not Phase 5): the tier column is assertion vocabulary, and SOLVE-04a/04b consume it in Phase 3 |
| VOL-0B | Phase 2 — Test architecture | Pending | Placed with VOL-00, not VOL-0A: `registry.tsv` schema + a standing lint, first consumed by Phase 4's DATA-11. Roadmap judgement call 7 |
| PROG-00 | Phase 2 — Test architecture | Pending | **Placed with VOL-00/VOL-0B, not with the programs it governs** (roadmap judgement call 9): a third `registry.tsv` column (`certificate`) plus a lint reddening a `Solve` with a blank cell, and a pre-Phase-8 consumer in Phase 3's SOLVE-04a/04b, which is exactly a certificate question. A program with no certificate is asserted as a limit, not solved |
| SOLVE-01 | Phase 3 — The (Delta_i, eta) solve | Pending | No speedup claim (the 14× figure was measured over 200 solves, menu is 4). No demo-license size assert — it could never fire |
| SOLVE-02 | Phase 3 — The (Delta_i, eta) solve | Pending | Its tie machinery interacts with PROG-02's bang-bang corner extraction — flagged as a Phase 8 research question |
| SOLVE-03 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| SOLVE-04a | Phase 3 — The (Delta_i, eta) solve | Pending | THEOREM tier — value only, at ≥1e-9 relative, after `objScale`. PROG-00 certificate: corner attainment at γ=0 |
| SOLVE-04b | Phase 3 — The (Delta_i, eta) solve | Pending | INFERENCE tier — separate unit, explicit `θ.b > 0` guard, tag lint + guard-removal mutant. PROG-00 certificate: explicitly ABSENT, which is why it is inference |
| SOLVE-05 | Phase 3 — The (Delta_i, eta) solve | Pending | Scoping PROVISIONAL under the constant-`w` premise, enforced by `make check-wstate` (v2 WSTATE-01) |
| SOLVE-06 | Phase 3 — The (Delta_i, eta) solve | Pending | Exports the machine-readable `degeneracyBreaks` verdict that gates Phase 9 and orders Phase 6. Its degeneracy is NOT known to be the same phenomenon as Phase 8's M6a degeneracy — recorded as separate, relationship unknown |
| SOLVE-07 | Phase 3 — The (Delta_i, eta) solve | Pending |  |
| DATA-01 | Phase 4 — Moments / ingestion | Pending | Three legs: `action=c` rc=0 is a NECESSARY CONDITION ONLY; `action=ce` absent must fail with a named diagnostic; `action=ce` on the fabricated fixture must pass with `card(tObs)>0` and non-degenerate `rv_bar` |
| DATA-02 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-03 | Phase 4 — Moments / ingestion | Pending | `W` is per-market and time-varying, from E6 `WindowChanged`. Consumed by VOL-08 — one of the two Phase 4 -> Phase 6 edges |
| DATA-04 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-05 | Phase 4 — Moments / ingestion | Pending |  |
| DATA-06 | Phase 4 — Moments / ingestion | Pending | Enforced by REPR-09 (Phase 1); listed under DATA to match producer contract numbering |
| DATA-07 | Phase 4 — Moments / ingestion | Pending | Consumed by VOL-08 alongside DATA-03 |
| DATA-08 | Phase 4 — Moments / ingestion | Pending | Pinned to `cfmm-replicationPlank@d34846c`, enforced by `make check-datapin` |
| DATA-09 | Phase 4 — Moments / ingestion | Pending | Exercised against DATA-10's fabricated fixture; must NOT depend on E2/E5 data existing. Its σ²_K-unjoined rule also binds DATA-11 and VOL-09 |
| DATA-10 | Phase 4 — Moments / ingestion | Pending | The fixture that makes legs (2) and (3) of DATA-01 checkable |
| DATA-11 | Phase 4 — Moments / ingestion | Pending | **Independent ingestion leg — own plan (04-05), NOT sequenced behind DATA-03/05/07.** Fabricated E4/E1 fixture; the indexer that would emit real rows is UNOWNED AND UNBUILT. Feeds VOL-07, and through it Phase 8's Θ_φ |
| VOL-0A | Phase 5 — Port foundation | Pending | **Gates the port.** Seeded reproducible sample; ≥3/10 INFERENCE re-cuts the phase's scope. Its census form is re-applied to Phase 8's six cited theorems. Per-theorem verdict is a human reading — UNVERIFIABLE-LEG, declared |
| VOL-01 | Phase 5 — Port foundation | Pending | Imports only Mathlib. Provenance TBD, resolved in-phase (expected `none (pure theorem)`) |
| VOL-02 | Phase 5 — Port foundation | Pending | Imports only Mathlib. Provenance TBD, resolved in-phase |
| VOL-03 | Phase 5 — Port foundation | Pending | Graph articulation point (out-degree 4); imports only PosSpec. Bridge DESIGN precedes it in the same phase |
| VOL-04 | Phase 6 — Instrument mechanics | Pending | Provenance TBD — must resolve before porting (VOL-0B lint) |
| VOL-05 | Phase 6 — Instrument mechanics | Pending | Provenance TBD; if ξ⋆ is consumed it arrives via E2 `PortafolioMinted` (**SPEC-ONLY**) — declare it and run on a fabricated fixture, never live data |
| VOL-06 | Phase 6 — Instrument mechanics | Pending | Provenance TBD; `tokenId` decoding is subgraph-side per contract §6, so GAMS-side provenance is `none` by construction |
| VOL-07 | Phase 6 — Instrument mechanics | Pending | **Consumes DATA-11** — Θ_φ from E4 (LIVE) + σ²_K from E1.strike. Θ_φ is also the parameter set Phase 8's programs range over; a committed rename-mutant must redden its units |
| VOL-08 | Phase 6 — Instrument mechanics | Pending | **Consumes DATA-03 and DATA-07** through `_MomentsContract.gms` (rename-mutant must redden); plan order routed by SOLVE-06's recorded verdict |
| VOL-09 | Phase 7 — VolInstrument | Pending | In-degree-4 convergence node. **No longer the endpoint** — it is the gateway to Phase 8, which imports from it. Provenance inherited and re-declared, not assumed |
| VOL-10 | Phase 8 — The convex programs | Pending | **Promoted from v2 (was FLAIR-01).** 15 theorems, 0 sorry. Downstream in imports but it is WHERE THE SOLVED PROGRAMS LIVE (cited at VOLATILITY_INSTRUMENTS.md:459). Collapsed into one phase with PROG-01..06 — see roadmap judgement call 8. Plan 08-01 gates the phase with a six-theorem certificate CENSUS |
| PROG-01 | Phase 8 — The convex programs | Pending | **SOLVE** — M5 infimum on λ_ARB over a nonempty COMPACT box; extremum attained. Certificate `flairMulti_exists_max_compact`. Value asserted to STRICTLY exceed the displayed bound |
| PROG-02 | Phase 8 — The convex programs | Pending | **SOLVE** — M6a level block `(φ̄, α, u)`, corner attained bang-bang. Certificate `flairMulti_corner_attained_levels` + `flairMulti_le_corner`. Reports WHICH corner; a bound perturbation must move it |
| PROG-03 | Phase 8 — The convex programs | Pending | **ASSERT ONLY, NOT SOLVED** — M6a shape block `(β, γ)` is unbounded; saturation boundary as β → −∞, strict gap at every finite β. Limit assertion + a guard reddening any solver that returns a shape-block bound as a solution, and per TEST-08 the guard ships a committed unit that deliberately triggers it. Deferred until lean4-spec constrains the block |
| PROG-04 | Phase 8 — The convex programs | Pending | **SOLVE** — M6b: the flat fee path minimizes λ_ARB among equal-FLAIR paths. Certificate: M1's STRICT convexity. The strict half is what is asserted — a `>=` assertion would pass on the flat path itself |
| PROG-05 | Phase 8 — The convex programs | Pending | **The reframing made executable.** A solution outside the representation kernel's scales/bounds FAILS — never rounded into range. This is why Phases 0-2 are the substrate. The `assertEvmExpressible` macro ships in Phase 2 (consumer relation, same pattern as GATE-03's `assertModelOptimal`) |
| PROG-06 | Phase 8 — The convex programs | Pending | Phase 8's **second plan** — placed ahead of the solves it gates. Two legs: finite differences with NO solver, and marginal (`.m`) sign assertions in every solving unit |
| IDENT-01 | Phase 9 — Coordinate identification (CONDITIONAL) | Pending | Opens iff SOLVE-06 records `degeneracyBreaks = 1`; otherwise closed as INVALIDATED. INFERENCE tier if opened. **Deliberately NOT promoted by rev 4** — the reframing's instruction was non-degenerate first |

**Coverage:**
- v1 requirements: **70 total** (48 → 57 review → 59 E4 → 67 programs → 70 after refreshing the Lean submodule)
- Mapped to phases: **67 / 67 ✓**
- Unmapped: **0**
- Duplicates: **0** (each requirement appears in exactly one row)
- Phases: **10** (0–9)

| Phase | Count |
|-------|-------|
| Phase 0 — Honest gates | 8 |
| Phase 1 — Representation kernel + spine | 11 |
| Phase 2 — Test architecture | 11 |
| Phase 3 — The (Delta_i, eta) solve | 8 |
| Phase 4 — Moments / ingestion | 11 |
| Phase 5 — Port foundation | 4 |
| Phase 6 — Instrument mechanics | 5 |
| Phase 7 — VolInstrument | 1 |
| Phase 8 — The convex programs | 7 |
| Phase 9 — Coordinate identification (CONDITIONAL) | 1 |
| **Total** | **67** |

**Placement of the eight requirements added by rev 4:**

| Requirement | Phase | Why there |
|---|---|---|
| **VOL-10** `FlairOptimization` | 8 | Promoted from v2 — downstream in imports, but it is where the solved programs live. Collapsed into one phase with PROG-01..06 rather than a port-only phase whose criterion would be "15 more theorems green" (judgement call 8) |
| **PROG-00** certificate | **2**, not 8 | A third `registry.tsv` column beside `tier` and `provenance` — same mechanism, same file — with a pre-Phase-8 consumer in Phase 3's SOLVE-04a/04b (judgement call 9) |
| **PROG-01 / 02 / 04** | 8 | The three programs whose extremum is *attained* — the ones GAMS solves |
| **PROG-03** | 8 | The one whose extremum is *not* attained: asserted as a limit, with a bound-as-optimum guard carrying its own TEST-08 mutation proof |
| **PROG-05** EVM-expressible | 8 | Its units (pips, Algebra vol) are the program's parameters; the `assertEvmExpressible` macro ships in Phase 2 as a consumer relation |
| **PROG-06** monotonicity | 8, **second plan** | λ_ARB-specific so no earlier home exists, but placed *ahead of* the solves it gates and checkable by finite differences with no solver |

**Renumbering:** IDENT-01 moves from Phase 8 to **Phase 9**. It stays conditional and stays
last, deliberately — the instruction behind rev 4 was *non-degenerate first*, so promoting
degeneracy work would invert the principle that produced the revision.

---
*Requirements defined: 2026-07-28*
*Traceability rebuilt: 2026-07-30 (rev 4)*
