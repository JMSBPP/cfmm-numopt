# Requirements: cfmm-gams

**Defined:** 2026-07-28
**Core Value:** Every geometric primitive carries a Lean-coordinate evaluator, an EVM-coordinate fixed-point evaluator, and an executable assertion that the two agree under a documented coordinate bridge.

> Every requirement below traces to a measured finding in `.planning/research/`.
> The dominant risk class in this repo is **silent wrongness**, not loud failure —
> most requirements exist to make a wrong answer *fail* rather than to add capability.

## v1 Requirements

### Build Integrity

The repo's current green is substantially uninformative. Nothing else can be trusted until this is fixed.

- [ ] **GATE-01**: `payoff-fixtures`, `spec-preflight`, and `spec-preflight-band` exit non-zero whenever `gams` exits non-zero, verified by a deliberately-broken source that must redden each target. They currently grep the `o=` listing for `Status: (Compilation|Execution) error`, a string only ever written to the log stream, which `lo=0 >/dev/null` destroys — and the `;` before `if` discards the exit code.
- [ ] **GATE-02**: `abort.noError` appears in no source, enforced by an automated check — it halts execution silently at rc=0 with no status line.
- [ ] **GATE-03**: every `Solve` statement is followed by an assertion on `modelStat` and `solveStat`; a non-optimal or infeasible solve currently returns rc=0 (measured `modelStat=19`).
- [ ] **GATE-04**: `execute` and `$call` failures fail the build, via `execute.checkErrorLevel` and `$call.checkErrorLevel` respectively — noting `$onCheckErrorLevel` governs `$call` only, not `execute`.
- [ ] **GATE-05**: a committed GDX fixture is provably fresh — regenerating from a clean tree either reproduces it or fails loudly. Fixtures can currently go stale while the build stays green.

### Representation Kernel

- [ ] **REPR-01**: exactly one module declares every fixed-point scale constant, constructed with `power(2,k)`. Compile-time `$eval` is forbidden for these — `$eval 2**96` is wrong by exactly 2^45.
- [ ] **REPR-02**: η has one canonical representation; any second representation carries a documented bridge and an executable consistency assertion. The WAD-vs-Q0.128 split is the most dangerous conflict in the repo because it fails silently in both directions.
- [ ] **REPR-03**: tick bounds are declared once, with the int24 storage range and the Uniswap usable range distinguished by name, and `minTick` is negative. `primitives.gms` currently declares `minTick /8388607/` — a positive minimum — alongside `maxTick /16777215/` (2²⁴−1).
- [ ] **REPR-04**: `TradingRegion.gms` and `PricingKernel.gms` co-compile with a reconciled `inventory` set, without `$onMultiR` (which silently replaces at rc=0).
- [ ] **REPR-05**: the tick-spacing domain is two-level — parent `/s1*s200/` matching Lean's `Finset.Icc 1 200`, plus a declared `tickSpacingMenu` subset `{1,10,60,200}` — so Δᵢ=200 is expressible and the deployable menu is named. `tickSpacingVal` becomes data-driven rather than `ord(d)`.
- [ ] **REPR-06**: overflow and non-finite guards key on magnitude, never on `= INF`. Overflow does not produce `INF`, does not raise, and continues at rc=0.
- [ ] **REPR-07**: `LbarQ128` and `DICfgQ128` are reconciled against their intended on-chain width. Two committed fixtures export `2^128` — exactly one greater than `uint128` max.
- [ ] **REPR-08**: every exported provenance scalar is read by the code that claims it, or removed. `etaQ128` and `tieBreaking` are currently exported but no assignment reads them.

### Test Architecture

- [ ] **TEST-01**: a guarded assertion library provides `assertApproxEqRel` / `assertApproxEqAbs` / `assertApproxEqClose`, printing both operands and the computed error on failure. `abort` accepts identifiers only, never expressions, which dictates the macro design.
- [ ] **TEST-02**: relative tolerance is exponent-dependent. GAMS `**` error is `≈1.101e-17·(i·Δᵢ)`, systematic and signed; a flat `1e-12` exhausts at exponent ≈90,800, inside the declared domain.
- [ ] **TEST-03**: zero assertions are made at residual level with a scale-derived `absFloor()`, a degree-matching rule, and a non-degeneracy companion — a one-sided zero assertion cannot fire when the quantity collapses. `zeroTolerance = 1e-20` is currently an artifact of `sqr()`, ~900× weaker than `diffTolerance`.
- [ ] **TEST-04**: one driver per theorem unit plus a registry, following GAMS Development's own `testlib` architecture. Aggregating solver-bearing units is structurally impossible — `$150 Symbolic equations redefined` is unconditional even under `$onMulti`.
- [ ] **TEST-05**: solver-dependent units are partitioned so the suite degrades honestly when CONOPT is absent, using `system.solverNames` (which reports installed, not licensed).
- [ ] **TEST-06**: golden GDX fixtures are diffed with `gdxdiff`, keyed on `rc != 0` rather than `rc == 1`, since its full return-code set is undocumented.
- [ ] **TEST-07**: the test architecture is documented as an in-repo reference that every subsequent unit follows.

### Parameter Solve

- [ ] **SOLVE-01**: `(Δᵢ, η)` is solved by a menu-loop of NLPs over `tickSpacingMenu`. CONOPT cannot do MINLP — `option minlp = conopt` is compile error `$255`.
- [ ] **SOLVE-02**: the argmax is extracted with deterministic tie-breaking honouring `tieBreaking /1/` (smallest index under ties), including the `+INF`-on-empty trap.
- [ ] **SOLVE-03**: an `objScale` constant in the scaffolding lets CONOPT reach its documented `Tol_Optimality = 1e-7`. The objective is ~1e-9 unscaled; scaling by 1e10 moves argmin error from `8.9e-3` to `1.25e-14`.
- [ ] **SOLVE-04**: at γ=0 the solved optimum is asserted against the proven closed form `riskNeutral_corner` (λ>1 ⟹ upper corner).
- [ ] **SOLVE-05**: the solve reports value, the product `Δᵢ·η`, and `nTies` — and reports coordinates **only** at γ=0. The payoff depends on the controls solely through their product; 62 equally-optimal pairs were measured at γ=100, and Lean's `g θ` is `Classical.choice` with no uniqueness lemma.
- [ ] **SOLVE-06**: an identifiability spike couples `ComparativeStatics.retVol` / `liqShare` (which depend on η alone) into the objective and reports whether the degeneracy breaks.
- [ ] **SOLVE-07**: fixed-point magnitudes stay inside macros and never enter a `Variable`. `Lim_Variable = 1e15` against `Q96 = 7.9e28` yields `solveStat=10`, `modelStat=13`, and variables left silently at starting values.

### Data & Moments

- [ ] **DATA-01**: ingestion happens through `execute_loadDC`, and the model compiles at `action=c` with no data file present. `$gdxIn` on a missing file is a hard compile error (rc=2), which would redden `compile-gams` on every machine.
- [ ] **DATA-02**: a model-owned static capacity grid (`tAll`) carries loaded membership (`tObs(tAll)`), with `ord()` and lag applied only to the parent. Execution-time loads cannot introduce new labels — a bare set silently yields `card=0` at rc=0.
- [ ] **DATA-03**: windowed `mean_tick` and `realized_variance` are computed with explicit boundary handling; the first window has one fewer return.
- [ ] **DATA-04**: only linear lag is used; circular `--` is banned — it fabricates a return by wrapping first→last.
- [ ] **DATA-05**: the internal consistency identity `RV_log = (log λ)²·RV_tick` is asserted (measured to hold at `4.01e-13`).
- [ ] **DATA-06**: ingested series carry numeric provenance (a `seriesIdHash`); free-text labels cannot survive an execution-time load.
- [ ] **DATA-07**: `rv_bar` normalization makes realized variance comparable across windows of differing cardinality.
- [ ] **DATA-08**: a documented data contract separates the expected symbol names and domains from the producer, so fabricated, simulated, and API-sourced series all satisfy one interface.

### Volatility Instruments Port

Dependency-ordered over the proven `vol_markets` closure. Each requires its dependencies ported first.

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

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| (pending roadmapper) | — | Pending |

**Coverage:**
- v1 requirements: 45 total
- Mapped to phases: 0 ⚠️
- Unmapped: 45 ⚠️

---
*Requirements defined: 2026-07-28*
