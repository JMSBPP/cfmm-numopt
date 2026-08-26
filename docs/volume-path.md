# VolumePath — the GAMS prover for `mev_tax_model_one`

**One sentence:** given a shock (pool state + target transactional rate + volume),
`model/mev_tax_model_one/volume_path.gms` either emits a JSON array of `N` swap
quantities in exact EVM units whose execution realizes the target fee revenue and
returns the pool to its starting price, or aborts with a named reason — nothing in
between.

This document is the contract for the two consumers downstream: the **bridge**
(reads Anvil, invokes the prover, hands the JSON back) and the **differential
test** (executes the swaps, asserts closure). Source spec: `model/mev_tax_model_one/notes.md`.

---

## 1. The problem it solves

The model (notes.md) tracks a closed loop of `N` swap events on constant
liquidity `L̄` with the sqrt-price recursion

```
p₁(i(n+1)) = L̄·p₁(i(n)) / (L̄ + p₁(i(n))·ΔQ_X(n)),      p₂ = p₁²  (normal price)
ΔQ_M(n)    = −p₁(n)·p₁(n+1)·ΔQ_X(n)
```

and two terminal ratios over the path: the transactional rate
`δ_trans = ν_trans/π̄` (traded volume normalized by the linear value of the
orders) and the fee rate `r^φ = π^φ/π̄`. The **inverse problem** is: given the
targets `(δ*, r^φ = φ̄·δ*)` and a total volume, produce a path `{ΔQ_X(n)}` that
realizes them.

### The geometry that makes it well-posed

Per step, with `x_n = |ΔQ_M|/(p̄|ΔQ_X|+|ΔQ_M|) ∈ (0,1)`:

- step rate `r_n = φ_X + (φ_M−φ_X)·x_n`
- step delta `d_n = √(x_n(1−x_n))`

so every step lies **on** the half-ellipse centered at `((φ_X+φ_M)/2, 0)` with
semi-axes `((φ_M−φ_X)/2, 1/2)`, and a path — a weighted mean of steps — reaches
exactly the ellipse **disk** (verified on 20,000 random closed paths). Hence:

1. **`δ_trans ≤ 1/2` always** (AM-GM; the ellipse top).
2. **Equal fees are infeasible for every target** (the disk collapses to a
   segment at `r = φ_X`, forcing `δ* = φ/φ̄ > 1/2`).
3. **Rate feasibility is a closed-form quadratic**:
   `(φ̄²+Δφ²)δ² − (φ_X+φ_M)·φ̄·δ + φ_X·φ_M ≤ 0`.
4. **Volume is a third coupled axis, not a gauge.** `x_n` depends on the price
   *levels* the path visits, so the system is NOT homogeneous in `ΔQ_X`:
   κ = volTgt/L̄ too small confines levels near the start, pins every `x_n`
   near ½ and floors δ at the ceiling. Measured at the fixture fees:
   `δ* = 0.49` needs `κ ≥ 1.4980` (volTgt ≥ 2.7632e19 wei at L̄ = 2⁶⁴); at
   κ = 0.6505 the floor is δ = 0.49797.

The prover checks (2) and (3) **before** solving and lets CONOPT report (4) as
`Locally Infeasible` — both paths abort non-zero.

---

## 2. Inputs — the shock, seven values

Every input is a `--key=value` command-line override; the in-file defaults are a
**self-test fixture only** (provenance documented per value in the file header).

| key | type | who supplies it at runtime |
|---|---|---|
| `sqrtPriceX96` | uint160 | pool state — bridge reads from Anvil |
| `liquidityRaw` | uint128 | pool state — bridge reads from Anvil |
| `txlVolumeRate` (= δ\*·1e6) | uint24 pips | the shock (`ShocksWriter.next(...)` argument) |
| `phiXpips` | pips | hook state — `φ_X(σ²(i(t)))` from the DynamicFeeHook (spec `MEV_TAX_MODEL_ONE.md`) |
| `phiMpips` | pips | read from `MevTaxModelOneFees` |
| `volTgtWad` | wei | the volume shock size, `Σ|ΔQ_X|` |
| `nEvents` | constant | fixed N (default 8) — sized by the cost of repeated runs |

```sh
gams volume_path.gms action=ce \
    --sqrtPriceX96=79228162514264337593543950336 \
    --liquidityRaw=18446744073709551616 \
    --txlVolumeRate=490000 --phiXpips=500 --phiMpips=6000 \
    --volTgtWad=28e18
```

`txlDecayRate` is **not** an input by ruling: the closed loop is trusted.

---

## 3. Output — `volume_path.json`

```json
{
  "sqrtPriceX96": "79228162514264337593543950336",
  "liquidity": "18446744073709551616",
  "txlVolumeRate": 490000,
  "phiXpips": 500,
  "phiMpips": 6000,
  "nEvents": 8,
  "deltaRealized": 0.49,
  "rPhiRealized": 0.00318353,
  "dQx": [-2613128317657530400, ...],
  "dQM": [3044390494897843700, ...]
}
```

- `dQx[n]` — the trader's X-leg quantity per event, **wei**, signed.
  `dQx > 0` sells X to the pool (sqrt price falls). Suggested v4 mapping:
  `amountSpecified = −dQx[n]`, `zeroForOne = (dQx[n] > 0)` — one rule covers
  both signs (negative = exact input of X, positive = exact output of X).
- `dQM[n]` — the model's M-leg reference, for differential comparison only;
  the pool computes its own output amounts.
- `sqrtPriceX96`/`liquidity` are echoed as **strings, verbatim from the input**:
  uint160/uint128 exceed the 53-bit double-exact ceiling (the double path
  printed 2⁶⁴ off by 384 wei — never parse these fields as doubles).

### Precision guarantees (measured)

- amounts at the 1e18–1e19 wei scale carry ~128–512 wei granularity (double ulp);
- closure: `Σ dQx = 400 wei` on a 2.8e19 volume (1.4e-17 relative) — **exact in
  the solver's u-space, roundoff only at decimal emission**;
- both rate targets realized to 1e-10;
- **determinism**: single-threaded CONOPT pinned; byte-identical JSON across
  8 measured runs. Same inputs + same toolchain (GAMS 54.1, CONOPT 4.39) →
  same bytes. A different CONOPT version may select a different member of the
  underdetermined path family — still passing every gate — so pin the toolchain.

### ⚠ The tick-closure caveat for the test

The critical downstream assertion is `tickBefore == tickAfter`. The emitted
integers close to ~hundreds of wei, **not** to zero — and the fixture starts at
`sqrtPriceX96 = 2⁹⁶`, exactly on the tick-0 boundary, where a 1-wei undershoot
reads as tick −1. The test should make the **last swap price-limited**
(`sqrtPriceLimitX96 = starting price`, amount slightly over) so the pool stops
exactly at the start price and tick equality is exact by construction.

---

## 4. Failure modes — every abort is named

| abort | meaning |
|---|---|
| `sqrtPrice exceeds uint160` / `liquidity exceeds uint128` | malformed shock |
| `txlVolumeRate must be < 100%` | malformed shock |
| `equal fees: ... infeasible` | structural — see §1.2 |
| `dStar outside the half-ellipse` | rate pair unreachable at these fees (§1.3) |
| `volTgt/Lbar outside a solvable range` | κ out of [1e-12, 1e12] |
| solver `Locally Infeasible` → `no locally optimal solution` | volume too small for δ\* (§1.4) — raise `volTgtWad` |
| `loop did not close` / `delta_trans missed` / `r^phi missed` / `volume missed` / `a step is not a swap` | post-solve certification of the emitted numbers; never observed on a converged solve |

Exit code is non-zero on every abort — gate on it, never on log text.

---

## 5. Build & CI

```sh
make compile-gams   # action=c syntax check of every tracked .gms
make test-gams      # units + prover (= test-units test-volumepath)
make test-volumepath # prover only: in-model gates + determinism double-run
make clean-gams
```

CI (`.github/workflows/gams.yml`) runs both behind the `gams-gate` environment
approval (public repo, self-hosted runner — the gate blocks fork PRs before
checkout; do not remove it).

---

## 6. Open rulings (tracked, not blocking)

1. Production `nEvents` (fixture: 8).
2. The pips denominator (1e6) of `phiXpips`/`phiMpips` against the pool's
   actual fee encoding.
3. Fee mechanics at execution: the model moves price with the **full** `dQx`
   (fees are accounting overlays, charged on both legs) — the executing pool
   must not take the LP fee out of the price-moving amount, or the on-chain
   path diverges from the reference. Recommended test setup: pool LP fee 0,
   fees asserted from the reference accounting.
