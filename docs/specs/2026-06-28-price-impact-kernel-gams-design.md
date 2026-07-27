# Price-Impact Kernel — GAMS reference (η=½) design

*Spec · 2026-06-28 (rev 2, post two-step review) · owner: GAMS-development agent (`43wxo1px`, worktree `cfmm-wt/gams`, branch `feat/gams`)*

> **Rev 2 changelog.** Reality Checker + Model QA Specialist returned 5 BLOCKERs / 9 MAJORs against rev 1: the macro algebra was off by `2^96` (the math-spec's `P_{1/2}(i)` is in **real units** but the EVM passes Q64.96 `sqrtPX96`, so the scales do **not** cancel); the §7 self-consistency test was a tautology that couldn't detect the bug; tolerance was deferred; `L̄=1e18` was falsely attributed to `InitState`; and the gamsdiff CLI was hard-wired to `priceKernel`, making the §8 handoff heavier than claimed. All fixed in this revision and empirically verified against a GAMS-side EVM mulDiv replica (rel err ≤ 1.22e-16 at machine precision; original macro gave rel err = 1.0).

## 1. Context

A new Plank harness has been added on the plank peer's track:

> `cfmm-wt/plank/test/gamsUtils/PriceImpactKernelHarness.plk` — exposes Uniswap V3's `getNextSqrtPriceFromAmount0RoundingUp(uint160 sqrtPX96, uint128 liquidity, uint256 amount, bool add) → uint256` as a single external entrypoint, selector `0x157f652f` (verified: `keccak256("getNextSqrtPriceFromAmount0RoundingUp(uint160,uint128,uint256,bool)")[0:4]`).

It is a companion to the existing `PriceKernelHarness.plk` (already diff-tested against `priceKernel`). The differential pipeline (gamsdiff peer `0hpyy1t4`) currently ships `model/pricing_kernel.gdx` → `test/gamsDiff/fixtures/pricing_kernel.json` → a Foundry `assertApproxEqRel` diff. This spec extends that pipeline with the **post-trade** sqrt price.

**Formula to mirror.** Reading `lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk` lines 9–32, `getNextSqrtPriceFromAmount0RoundingUp(P, L, dx, add=true)` computes, in *integer* arithmetic:

```
numerator1  = L << 96                       // = L · 2^96
product     = dx * P                        // P is the Q64.96 sqrtPX96 input
denominator = numerator1 + product
result      = mulDivRoundingUp(numerator1, P, denominator)
            = ⌈ (L · 2^96 · P) / (L · 2^96 + dx · P) ⌉      (UP rounding)
```

The math layer (`model/exp/eta.md` on both worktrees) writes the same operation in **real units**: `P_{1/2}(Δ^I) = L̄ · P_{1/2}(i) / (L̄ + Δ^I · P_{1/2}(i))`, where `P_{1/2}(i)` is the **real** sqrt price (not yet `× 2^96`). **The Q64.96 scale enters when the math meets the EVM**; `sqrtPX96 = P_{1/2}(i) · 2^96`. Substituting back to express the EVM operation in terms of the Q64.96 input we actually have:

```
result_Q96  = L · sqrtPX96 / (L + dx · sqrtPX96 / 2^96)
```

This is the algebraic form the GAMS macro mirrors. Rev 1 missed the `/ 2^96`.

**Fallback path (informational).** The EVM has a second branch (lines 18–22) when either `dx · sqrtPX96` overflows uint256 or the denominator wraps below `numerator1`: it computes `result = ⌈ (L · 2^96) / ((L · 2^96) / sqrtPX96 + dx) ⌉`. This is algebraically identical in real arithmetic but rounds differently in integers. The grid in §3-D3 is bounded below `2^256`, so this branch is never hit (see §3-D7).

## 2. Goal

Produce a GAMS reference value for the **Q64.96-scaled post-trade sqrt price** over a fixed grid of `(sqrtP, L̄, Δ^I)` inputs, exported to GDX, so the gamsdiff peer can extend their existing CLI to emit a JSON fixture and write a Foundry diff test against `PriceImpactKernelHarness`.

## 3. Decisions (with rationale)

| # | Decision | Why |
|---|----------|-----|
| D1 | **Macro signature = literal η=½ mirror.** `priceImpactKernel_Add0(sqrtP, L, dx) = L · sqrtP / (L + dx · sqrtP / 2^96)`. Suffix `_Add0` reserves namespace for siblings (`_Add1` for token1-input, etc.). | The EVM harness covers only η=½ + token0-input + `add=true`. A tunable-η GAMS variant has no on-chain counterpart to diff against. The η-CES generalization is *unlockable* via the lean4-proven kernel-split identity (`CFMM.Eta.eta_split_kernel_identity` — claimed proven in `lean4-spec/model/exp/eta.md`; Aristotle reproduce recipe given there but build status not independently confirmed by me) but blocked on the EVM side. |
| D2 | **Implementation = GAMS `$macro`** (not a Parameter). | Takes inputs by argument; composes with anything that produces a Q64.96 sqrtP (`priceKernel`, `tunablePricingKernel`, or a raw scalar). Avoids the `inventory`-set clash that prevents `PricingKernel` from `$include`ing `TradingRegion`. |
| D3 | **Input grid: 1 spacing × 241 ticks × 3 dx × 1 L̄ = 723 rows.** | Matches the existing `pricing_kernel.gdx` footprint exactly. Single L̄ keeps the fixture small; the dx sweep covers three regimes of the formula. **Coverage gap admitted (M5):** the tick range `[k1..k241]` = `[-120..+120]` covers only `sqrtP_real ∈ [0.994, 1.006]`, i.e. ~0.014 % of the EVM tick domain (`±887272`). Extreme-tick coverage is deferred to a stress fixture. |
| D4 | **`L̄ = unity = 1e18`**, fixed in this fixture. | A **fresh design choice** for this fixture — there is no `Lbar`/`L`/`liquidity` symbol in the GAMS model today (rev 1 falsely cited `dynamic/InitState.gms`, which only defines inventory amounts `X=1e20, Y=1e22`). `unity` is the model's canonical WAD scale; exact in IEEE doubles (`5^18 ≈ 3.81e12 < 2^53`, so `10^18 = 5^18 · 2^18` is bit-exact). Reconcile with a model-wide canonical `L` when one is defined. |
| D5 | **dx values = ratio sweep**: `L̄/1000`, `L̄/10`, `L̄` (= `1e15`, `1e17`, `1e18`). | The formula's behavior is governed by `dx · sqrtP_real / L` (the rescaled non-linearity); ratios `{1e-3, 1e-1, 1.0}` exercise the linear, mild-non-linear, and mid-non-linear regimes (≈50 % price impact at `dx=L̄`). All three values fit exactly in 53-bit mantissas (5^k < 2^53 for k ≤ 22). Asymptotic regime `dx · sqrtP / L̄ ≫ 1` is **not covered** here; deferred to stress fixture (M1, M5). |
| D6 | **GDX schema = single 3-D output `Parameter` + input scalars + provenance scalars.** Symbols: `priceImpact(s,t,dxD)` (the canonical output, **values are Q64.96**), `Lbar`, `dxVal(dxD)`, plus provenance: `gamsVersion`, `etaWeight`, `lambdaVal`. | Mirrors `pricing_kernel.gdx`'s shape (one canonical output parameter). Provenance scalars make the GDX **fully self-describing for values *and* version metadata**; semantics of `dxD ∈ {small,medium,large}` still live in this spec (label-to-meaning is documented here, not in the GDX). |
| D7 | **`add = true` only, token0-input only, primary EVM path only.** | The `add = false` branch is **not unconditional revert** as rev 1 mis-claimed — it has its own conditional guards (`product/amount != sqrtPX96` *or* `numerator1 ≤ product`, lines 24–31 of `sqrt_price_math.plk`) and a sometimes-happy-path computation; it deserves its own spec and fixture. The fallback path inside `add=true` (overflow / wraparound, §1) is not hit on this grid: max `dx · sqrtP_q96 ≈ 1e18 · 8e28 = 8e46 ≪ 2^256 ≈ 1.16e77`. |
| D8 | **Rounding model.** EVM uses `mulDivRoundingUp` (always rounds *up*); GAMS uses IEEE doubles (round-to-nearest). The EVM bias is **systematically non-negative** — at most 1 integer ULP per division, i.e. ≤ `1` in Q96 units. On this grid the smallest `priceImpact_Q96` value is bounded below by `~3.9e28` (at `tick=-120, dx=L̄`), so the relative EVM bias is ≤ `2.6e-29` — negligible. The GAMS-side IEEE error is `~eps · (1 + κ) ≈ 2e-16 · 2 ≈ 4e-16` worst-case. **Total error budget ≈ 4e-16; tolerance is set 4 decimal orders above this.** |
| D9 | **Diff tolerance committed: `assertApproxEqRel` relative tolerance `1e-12`.** Derivation in D8. | Pinning the tolerance prevents the gamsdiff peer from ratcheting it to whatever passes. `1e-12` leaves 4 decimal orders of margin over IEEE error + EVM UP bias. If a future input regime breaks this budget, the breaking grid points belong in a **separate** stress fixture, not absorbed by a looser tolerance. |

## 4. Architecture (files affected)

```
model/
├── PricingKernel.gms                    EDIT: add `priceImpactKernel_Add0` $macro (1 line + comment)
├── PriceImpactKernelFixture.gms         NEW : grid driver; computes priceImpact, execute_unload to GDX
├── test/
│   └── PriceImpactKernelTest.gms        NEW : assert-only test for the macro (no EVM diff)
└── price_impact_kernel.gdx              NEW : committed generated fixture
                                                (mirrors the committed pricing_kernel.gdx)
docs/superpowers/specs/
└── 2026-06-28-price-impact-kernel-gams-design.md   THIS spec
```

No `Makefile` change. `make test-gams` auto-discovers `model/test/*.gms`. The fixture driver `PriceImpactKernelFixture.gms` lives at the **model root** (not under `test/`) because it is a generator, not an assertion test — and `compile-gams` will pick it up, so the new green count is **7 ok / 0 failed** (one more than rev 1's mistaken "6").

## 5. The macro (`model/PricingKernel.gms`)

```gams
* priceImpactKernel_Add0(sqrtP, L, dx): post-trade sqrt price (Q64.96) for the
* η = 1/2 kernel, selling token0 for token1 (Uniswap V3 add=true direction).
* Mirrors v3::math::sqrt_price_math::getNextSqrtPriceFromAmount0RoundingUp(P, L, dx, true)
* exposed by PriceImpactKernelHarness.plk.
*
* Scale convention:
*   sqrtP enters in Q64.96 (the on-chain scale produced by `priceKernel`);
*   L and dx enter raw (matching `liquidity` uint128 and `amount` uint256);
*   the macro returns Q64.96 (directly comparable to the EVM output).
* The EVM's `numerator1 = L << 96` introduces an asymmetric scaling: in the
* denominator, L is raw but dx*sqrtP is Q96, so the dx*sqrtP product must be
* divided by 2^96 before being added to L. (Equivalently, multiply L by 2^96
* in both numerator and denominator — same algebra, different surface form.)
* The "scales cancel" intuition is WRONG; the asymmetry is load-bearing.
*
* Rounding: Uniswap rounds the division UP (mulDivRoundingUp); GAMS uses IEEE
* doubles. The diff uses assertApproxEqRel at 1e-12 (see spec §D8/§D9 for the
* bias-bound derivation).
*
* Naming: the `_Add0` suffix marks the token0-input direction; future siblings
* `_Add1` (token1-input) and a potential `_Sub0/_Sub1` (`add=false` branch)
* will share the `priceImpactKernel_` prefix.
*
* TODO(eta-CES): a tunable-η post-trade form is reachable via the lean4-spec
* kernel-split identity (CFMM.Eta.eta_split_kernel_identity, see
* lean4-spec/lean/exp/eta.lean), but blocked on an η-CES post-trade EVM
* function existing to diff against.
$macro priceImpactKernel_Add0(sqrtP, L, dx) ( (L) * (sqrtP) / ( (L) + (dx) * (sqrtP) / power(2, 96) ) )
```

Typical call: `priceImpactKernel_Add0(priceKernel(s, t), Lbar, dxVal('large'))`.

## 6. Fixture driver — `model/PriceImpactKernelFixture.gms`

```gams
$include PricingKernel.gms                  * priceKernel, priceImpactKernel_Add0, lambda, unity, ticks

Scalar Lbar; Lbar = unity;                  * = 1e18 = WAD; fresh design choice (§D4), not InitState
Set    dxD  / small, medium, large /;
Parameter dxVal(dxD);
dxVal('small')  = Lbar / 1000;              * 1e15
dxVal('medium') = Lbar /   10;              * 1e17
dxVal('large')  = Lbar;                     * 1e18

* Literal singleton (avoids GDX domain reporting `tickSpacingDomain` for a
* subset symbol; rev 1 used `Set sFix(tickSpacingDomain) /s1/`, which would
* unload as the parent domain rather than the labeled subset).
Set    s    / s1 /;
Parameter tickSpacingValFix(s);
tickSpacingValFix('s1') = 1;

* Compute the post-trade Q64.96 sqrt price over the full (s × tick × dxD) grid.
* Output is in Q64.96 — directly comparable to PriceImpactKernelHarness output.
Parameter priceImpact(s, tick, dxD);
priceImpact(s, tick, dxD) =
    priceImpactKernel_Add0( priceKernel(s, tick), Lbar, dxVal(dxD) );

* Provenance scalars (§D6) so the GDX is self-describing:
Scalar gamsVersion / 54.1 /;                * matches model/BUILD.md pinned toolchain
Scalar etaWeight   / 0.5  /;                * η = 1/2 — the kernel this fixture is specialised to
Scalar lambdaVal;  lambdaVal = lambda / unity;     * = 1.0001, the pricing-kernel base

execute_unload 'price_impact_kernel.gdx',
    priceImpact, Lbar, dxVal,
    gamsVersion, etaWeight, lambdaVal;
```

**Resulting GDX symbols:**
- `priceImpact(s, t, dxD)` — 1 × 241 × 3 = **723 rows**, post-trade `sqrtPX96` in Q64.96 (decimal value, ~`1e28`–`8e28`).
- `Lbar` scalar — `1e18`.
- `dxVal(dxD)` — three dx values keyed by label.
- `gamsVersion`, `etaWeight`, `lambdaVal` — provenance scalars.

**Determinism.** The GDX binary embeds a timestamp header, so byte-level identity across re-runs is not expected; `gdxdump --no-data` produces an identical *schema* across re-runs (§10 success criterion).

## 7. Test — `model/test/PriceImpactKernelTest.gms`

Runs under `make test-gams` (action=ce so `abort` fires). Three properties, asserted across the full grid. **No EVM diff in this test** — the diff lives in the Solidity diff (gamsdiff track). What changed from rev 1: dropped the tautology, added a *real* cross-check.

1. **Zero-input no-op:** for every `(s, t)`, `priceImpactKernel_Add0(priceKernel(s,t), Lbar, 0) == priceKernel(s,t)` exactly. Called with a literal `0` for `dx` (the grid's `dxD` set does not include zero — its three values stress non-trivial impact).
2. **Monotone in `dx`:** `priceImpact(s,t,'small') > priceImpact(s,t,'medium') > priceImpact(s,t,'large')` for every `(s, t)`. Economic reading: increasing the input amount of token0 sold strictly decreases the post-trade `sqrtPX96` (the price of token0 in token1 falls). Captures the swap-direction sign.
3. **EVM-formula cross-validation (replaces the rev-1 tautology):** at a fixed spot `(t = k121, dx = 'medium')`, reproduce the EVM's `mulDiv`-form computation **independently** in GAMS and assert agreement with `priceImpact`:

   ```gams
   Scalar Q96, evmRef;
   Q96    = power(2, 96);
   evmRef = (Lbar * Q96) * priceKernel('s1','k121')
            / ((Lbar * Q96) + dxVal('medium') * priceKernel('s1','k121'));
   abort$( abs(priceImpact('s1','k121','medium') - evmRef) / evmRef > 1e-12 )
       "EVM-formula cross-validation failed", priceImpact, evmRef;
   ```

   Independence from the macro's surface algebra (different parenthesisation = different floating-point evaluation order) means this catches scale mismatches the macro's RHS cannot self-detect.

## 8. Handoff to the gamsdiff peer (`0hpyy1t4`)

Strictly out of my scope; **but the contract requires real work on their side** that this spec must scope honestly. The current `tools/gamsdiff/` CLI is hard-wired to the pricing-kernel fixture:

- `tools/gamsdiff/gamsdiff/__main__.py` literally hard-codes `model_file="PricingKernel.gms"`, `gdx_name="pricing_kernel.gdx"`, `symbol="priceKernel"`, and the output path.
- `shell.load_grid_records` (`shell.py:18–55`) hard-codes a 2-D `(tickSpacingDomain, tick)` symbol shape; `priceImpact(s, t, dxD)` is 3-D and will not load through it without changes.
- `core.records_to_points` produces a 1-D `KernelPoint(tick, expected_sqrt_price_x96)`; the 3-D fixture needs a richer schema.
- `make gams-fixtures` is one line: `uv run --project tools/gamsdiff gamsdiff` — no sub-command machinery.

**Required gamsdiff-side work (theirs, listed for honesty):**
1. Parameterise the CLI by `(model_file, gdx_name, symbol, output_path, shape)` — e.g. a config file or sub-commands.
2. Generalise `shell.load_grid_records` to handle 3-D records and arbitrary domain names.
3. Generalise `core.records_to_points` (or add a 3-D analogue) to emit a structured-output point that includes `dxD` plus extra metadata.
4. Wire `make gams-fixtures` to drive *both* the existing pricing-kernel fixture and the new price-impact fixture.
5. Add the Foundry diff test (`assertApproxEqRel` at the `1e-12` tolerance from §D9).

**Proposed JSON schema** (so the contract is durable, not implicit):

```json
{
  "kernel": "price_impact_kernel",
  "eta": 0.5,
  "direction": "add0",
  "gamsVersion": "54.1",
  "lambda": "1.0001",
  "Lbar": "1000000000000000000",
  "selector": "0x157f652f",
  "dxValues": {
    "small":  "1000000000000000",
    "medium": "100000000000000000",
    "large":  "1000000000000000000"
  },
  "tickSpacing": 1,
  "points": [
    {
      "tick": -120,
      "expected": {
        "small":  "<decimal-string Q64.96 uint256>",
        "medium": "<decimal-string Q64.96 uint256>",
        "large":  "<decimal-string Q64.96 uint256>"
      }
    },
    "... 240 more ticks ..."
  ]
}
```

All `uint256`-valued fields are **decimal strings** (not JSON numbers) because the values exceed `Number.MAX_SAFE_INTEGER` and forge's JSON parser only reads them as `uint256` when string-encoded — same convention as the existing `pricing_kernel.json`.

**Coordination delivery.** I'll send a `claude-peers send_message` to `0hpyy1t4` after PR-ing, with the GDX path, the schema sketch above, and the `1e-12` tolerance commitment. **Not** listed as a success criterion (it's a post-merge action, not a verifiable artifact in the PR).

## 9. Out of scope (explicit YAGNI)

- **Tunable-η post-trade form.** No EVM counterpart; lean4-spec proves a kernel-split identity that opens a path, but the on-chain function would have to be written first. Captured only as a `TODO(eta-CES)` comment.
- **`add = false` (token0-input).** Conditional revert / sometimes-happy-path inside the EVM, distinct semantics — own spec when its harness lands. The fixture grid is bounded so neither the `add=true` *fallback path* (overflow / wraparound) nor any `add=false` input is exercised here.
- **`getNextSqrtPriceFromAmount1*`** (token1-input direction). Distinct harness; own spec.
- **`getAmount0/1Delta*`** (delta amounts). Distinct harnesses; own specs.
- **Wide-tick coverage / extreme-impact regime.** The fixture lives in tick `[-120..+120]` (~0.014 % of EVM domain) and `dx · sqrtP_real / L̄ ∈ [1e-3, 1.0]`. Asymptotic-impact and near-`MIN/MAX_SQRT_RATIO` regimes belong in a **stress** fixture; this fixture intentionally stays in the well-conditioned regime.
- **Edge cases `sqrtP = 0`, `L = 0`, simultaneous `dx = 0 ∧ sqrtP = 0`.** The EVM caller `getNextSqrtPriceFromInput` reverts on `sqrtP == 0 || L == 0`; the grid never visits these. A `0/0` corner would NaN in IEEE; not a real concern at this grid but flagged if anyone extends.
- **Bit-exact integer match.** The pipeline contracts on `assertApproxEqRel`; emulating `mulDivRoundingUp` in GAMS doubles is the gamsdiff peer's option if they ever need it.

## 10. Success criteria

- `model/PricingKernel.gms` defines `priceImpactKernel_Add0`. `make compile-gams` reports **7 ok / 0 failed** (the new `PriceImpactKernelFixture.gms` is auto-discovered at the model root).
- `make test-gams` discovers and passes `PriceImpactKernelTest.gms`. Final report: **2 test files passed**, **5 asserted properties total** (the existing `PricingKernelTest.gms` has 2: `maxRelErr ≤ 1e-12` for the tunable equivalence + `maxDiffEta > 0` for tunability; the new `PriceImpactKernelTest.gms` adds the 3 in §7).
- `model/PriceImpactKernelFixture.gms` runs under `gams … action=ce` with exit 0 and produces a deterministic `model/price_impact_kernel.gdx` (schema-stable across re-runs).
- `gdxdump model/price_impact_kernel.gdx --no-data` shows symbols `priceImpact, Lbar, dxVal, gamsVersion, etaWeight, lambdaVal` with the documented domains and row count (723 records under `priceImpact`).
- A GAMS-side independent EVM-formula reproduction (§7 property 3) agrees with the macro to relative tolerance `1e-12` (the same tolerance the future Foundry diff will use).
- The harness selector `0x157f652f` in §1 matches `PriceImpactKernelHarness.plk:27` (verified by `keccak256` — recorded here for audit).

## 11. References

- Plank harness: `cfmm-wt/plank/test/gamsUtils/PriceImpactKernelHarness.plk` (selector at line 27, calldata layout at lines 33–43).
- Sister harness (already diff-tested): `cfmm-wt/plank/test/gamsUtils/PriceKernelHarness.plk`.
- Uniswap V3 reference: `lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk` — primary path `add=true` at lines 13–17, fallback at 18–22, `add=false` conditional reverts at 24–31.
- Math layer (real units, no `2^96`): `cfmm-wt/gams/model/exp/eta.md` (brief) and the more developed copy on `cfmm-wt/lean4-spec/model/exp/eta.md` (claims `CFMM.Eta.eta_split_kernel_identity` proven via Aristotle; reproduce recipe inline, build status not independently confirmed in this spec).
- gamsdiff CLI to be extended: `cfmm-wt/gamsdiff/tools/gamsdiff/gamsdiff/{__main__.py, core.py, shell.py}` (currently `priceKernel`-hardcoded — see §8).
- Reference fixture pair (the model to mirror): `cfmm-wt/gamsdiff/model/pricing_kernel.gdx` + `cfmm-wt/gamsdiff/test/gamsDiff/fixtures/pricing_kernel.json`.
- This GAMS track's scope memory: `gams-agent-scope.md`.
- Rev 1 review record: Model QA Specialist + Reality Checker findings (this conversation, two-step CLAUDE.md review).
