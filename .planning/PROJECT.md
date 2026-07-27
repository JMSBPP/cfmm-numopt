# cfmm-gams — Dual-Representation Geometry for CFMM Parameter Solving

## What This Is

The off-chain GAMS algebraic model for CFMM payoff replication. It builds the
**primitives of the CFMM geometry** so that each primitive exists simultaneously in
two representations that are provably in agreement: the **Lean 4 specification**
coordinates (real-valued, where the theorems are proven) and the **EVM semantics**
coordinates (fixed-point Q64.96 / Q128.128 / WAD, where the on-chain implementation
lives). On that geometry the pricing kernel *solves* for the two control parameters —
tick spacing `Δᵢ` and elasticity `η` — and the volatility-instrument architecture is
built on top.

The audience is this project's own engineering: the Plank/EVM track consumes the
solved parameters, and the Lean track supplies the proofs the GAMS units assert.

## Core Value

**Every geometric primitive carries a Lean-coordinate evaluator, an EVM-coordinate
fixed-point evaluator, and an executable assertion that the two agree under a
documented coordinate bridge.** If everything else is deferred, that dual-representation
spine must hold — it is what makes a GAMS result trustworthy as both a theorem
instance and an on-chain prediction.

## Requirements

### Validated

<!-- Present in the repo and verified green as of 2026-07-27. "Existing" means it
     compiles/asserts today, not that it is complete. -->

- ✓ Pricing kernel with the two-parameter family `tunablePricingKernel(di, i, eta)` —
  existing (`model/PricingKernel.gms`)
- ✓ `priceImpactKernel_Add0` post-trade sqrt-price macro, empirically verified against
  an independent EVM `mulDiv` replica at rel err `1.22e-16` — existing
- ✓ The dual-coordinate pattern itself: `P_Lean_at` / `P_Lean_post` /
  `piTrader_Half_Lean` against `sqrtPX96_at` / `priceImpactQ128_Add0` /
  `piTrader_Half_Plank`, plus the documented bridges `sqrtPX96 = √P_Lean · Q96` and
  `Δᵢ⋆_Plank = 2 · Δᵢ⋆_Lean` — existing (`model/payoff/_PayoffScaffolding.gms`)
- ✓ CES liquidity cone `L = X^η · Y^(1−η)` as the geometry primitive — existing
  (`model/TradingRegion.gms`, `poolLiquidityCone`)
- ✓ One-execution-unit-per-theorem architecture with per-theorem test drivers, after
  the `$include`-aggregator was removed — existing (commit `5dffd79`)
- ✓ Two real NLP `Model`/`Solve` units running under CONOPT and asserting green
  (`eta_pi_trader_zero_slippage`, `eta_pi_trader_band_monotone_large`)
- ✓ Lean `sorry`/`admit` gate wired through the `lean4-spec` submodule, so a GAMS unit
  cannot claim to implement an unproven theorem (`make spec-preflight-band`)
- ✓ Three committed GDX reference fixtures consumed by the differential-testing track

### Active

<!-- v1 scope. Hypotheses until shipped. -->

- [ ] Unify the number-representation kernel so one definition of every scale, bound,
      and set is shared across all modules
- [ ] Resolve the tick-bound contradiction: `primitives.gms` declares
      `maxTick /16777215/` (2²⁴−1, uint24 max) and `minTick /8388607/` — a *positive*
      minimum — while `PricingKernel.gms` declares `MAX_TICK /8388607/` and
      `MIN_TICK /-8388607/`. Neither matches Uniswap's usable `±887272`, and
      `-8388607` is not the two's-complement int24 floor `-8388608`.
- [ ] Resolve the η scale conflict: `TradingRegion` carries η as WAD (`eta_x_y/unity`),
      `_PayoffScaffolding` carries it as Q0.128 (`etaQ128 = 2¹²⁷`). One canonical
      representation plus an explicit bridge.
- [ ] Reconcile the `inventory` set (`/ assetX, cashY /` vs `/ X, Y /`) so
      `TradingRegion` and `PricingKernel` become co-compilable
- [ ] Pricing kernel solves for `(Δᵢ, η)` over the feasible box, grounded in
      `ComparativeStatics.box` / `.g` / `.value` and
      `MeanVarianceOptimization.exists_mv_optimal_tick_menu`
- [ ] Assert the solved optimum against the proven closed form `riskNeutral_corner`
      (γ = 0, λ > 1 ⟹ optimum at the upper corner of the box)
- [ ] A documented GAMS test architecture — the assertion vocabulary, tolerance policy,
      provenance-recording convention, and fixture layout that every future unit follows
- [ ] Port the VOLATILITY_INSTRUMENTS architecture into GAMS over the proven
      `vol_markets` closure, dependency-ordered:
      `PosSpec → Main → Flow → RiskDesign → GeomProfile → Panoptic → FeeSchedule →
      Upsilon → VolInstrument`
- [ ] A moments layer over an ingestible `TimeWindow` domain (`mean_tick`,
      `realized_variance`) whose data source is pluggable

### Out of Scope

- **On-chain data ingestion** — the data may be fabricated, simulated, or pulled from
  an API, and the choice is expected to follow the Plank development schema. Binding v1
  to a live chain source would couple this repo to a decision that has not been made.
- **Bit-exact GAMS↔EVM equality** — structurally impossible: GAMS computes in IEEE
  doubles (53-bit mantissa), the EVM in 256-bit integers. Agreement is asserted within
  the documented tolerances, never as exact integer equality.
- **`vol_markets/FlairOptimization.lean`** — it imports *from* `VolInstrument`, so it
  sits downstream of the closure this milestone ports (15 theorems, deferred).
- **The `exp/` modules carrying a `sorry`** — `eta.lean` (1), `BondingCurveCurvature`
  (1), `DynamicsOptimization` (1). Only the specific `eta.lean` theorems already gated
  sorry-free by `spec-preflight-band` are in scope.
- **Monorepo submodule wiring at `gams/`** — belongs to `cfmm-replicationPlank` and
  requires sign-off from the gamsdiff and CI sessions per the ownership map.
- **Closed-loop control / on-chain deployment** — the GAMS track produces parameters;
  consuming them is the Plank and controller tracks' work.

## Context

- **Repository split.** This repo was extracted from `JMSBPP/cfmm-replicationPlank` on
  2026-07-27 via `git subtree split -P model`, preserving 29 commits of history. The
  monorepo will mount it as a submodule at `gams/`; that wiring is pending.
- **The Lean substrate is unusually solid for this milestone.** Every module this
  project targets is fully proven: `ComparativeStatics` (15 theorems, 0 `sorry`),
  `MeanVarianceOptimization` (10, 0), `EnvelopeTheorem` (6, 0), and all ten
  `vol_markets` files (169, 0). The GAMS work is therefore implementation and
  verification, not discovery.
- **The Lean↔GAMS match is structural, not incidental.**
  `ComparativeStatics.box θ` is the `(Δᵢ, η)` feasible box; `g θ` is the argmax — literally
  "solve for tick spacing and eta"; `exists_mv_optimal_tick_menu` is stated over a
  *finite* tick menu, which is a GAMS `Set` enumeration directly; and `riskNeutral_corner`
  supplies a closed form to assert a numerical solver against.
- **`vol_markets` is import-disjoint from `exp/`.** No `vol_markets` file imports
  anything from `exp/`. The pricing-kernel ↔ volatility-instrument link therefore does
  not exist in Lean and is *established in GAMS*, via shared symbols and `abort$()`
  consistency assertions. The semantic hooks are `ComparativeStatics.retVol` /
  `liqShare` and `vol_markets/Upsilon`.
- **Known debt inherited at split time**, all recorded rather than silently fixed:
  the Cycle-2 spec's §7 still encodes the removed `$include`-aggregator; `model/BUILD.md`
  is stale (claims no `Model`/`Solve` exists — two CONOPT NLPs do — and calls
  `PayoffModule.gms` an empty stub); `PricingKernelMoments.gms` is an invalid stub
  (`Set TimeWindow` with no elements or terminator, two zero-argument macros);
  `tickPerPriceKernel` has unbalanced parentheses and calls a two-argument
  `log(base, x)` that GAMS does not provide.
- **GAMS has one global symbol namespace.** This is the dominant architectural
  constraint. Per-theorem files reuse names deliberately because each theorem is a
  different numerical fixture, so they are never aggregated into one compilation unit.

## Constraints

- **Tech stack**: GAMS 54.1.0, linux x86_64. Units carrying `Model`/`Solve` require the
  **CONOPT** NLP solver; kernel files are compile-checkable without one.
- **Working directory**: GAMS resolves relative `$include` against the *invocation*
  working directory, not the including file's directory — every target `cd`s into
  `model/` first.
- **Numeric fidelity**: agreement between the Lean and EVM representations is asserted
  at `diffTolerance = 1e-12` relative and `zeroTolerance = 1e-20` absolute. Rounding
  direction matters — Uniswap rounds division up (`mulDivRoundingUp`); GAMS does not.
- **Proof gating**: no GAMS unit may claim to implement a Lean theorem whose body
  contains `sorry`/`admit`. Enforced by `spec-preflight*` before code extraction.
- **Scale asymmetry is load-bearing**: in `priceImpactKernel_Add0` the EVM's
  `numerator1 = L << 96` makes `L` raw but `dx·sqrtP` Q96 in the denominator. The
  "scales cancel" intuition is wrong and the asymmetry must be preserved.
- **Public repository on a self-hosted runner**: CI must keep the
  `environment: gams-gate` approval job ahead of any self-hosted job, or a fork PR
  executes arbitrary code on the build machine.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One execution unit per theorem; `PayoffModule.gms` is a registry, not an aggregator | GAMS has a single global namespace; two theorem files already collided on 19 symbols plus `payoffEq`/`piVal`/`di`. Aggregation cannot scale to the closure. | ✓ Good — compile 12/12, tests 4/4 |
| The pricing-kernel ↔ volatility bridge is made in GAMS, not proven in Lean first | `vol_markets` is import-disjoint from `exp/`; proving the link would block GAMS work on an Aristotle round-trip | — Pending |
| `cfmm-lean4-spec` enters as a submodule rather than a vendored copy | Makes `spec-preflight-band` work from a fresh clone; it previously resolved against a sibling worktree path and only worked on one machine | ✓ Good — verified by anonymous recursive clone |
| Data source deferred and pluggable (fabricated / simulated / API) | The choice follows the Plank development schema, which is not yet fixed; binding v1 to it would couple this repo to an unmade decision | — Pending |
| Agreement asserted within tolerance, never as bit-exact equality | IEEE doubles vs 256-bit integers — exactness is not achievable, and promising it would make every test dishonest | — Pending |

---
*Last updated: 2026-07-27 after initialization*
