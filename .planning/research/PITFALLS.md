# Pitfalls Research

**Domain:** Mirroring EVM 256-bit fixed-point arithmetic (Q64.96 / Q128.128 / WAD) inside GAMS IEEE-754 doubles, against a real-valued Lean 4 specification.
**Researched:** 2026-07-27
**Confidence:** HIGH for GAMS behaviour (every claim below was executed on the local GAMS **54.1.0 37378ce0 LEX-LEG x86 64bit/Linux**, the pinned toolchain); HIGH for Uniswap v3 semantics (read from `Uniswap/v3-core` source); MEDIUM where noted inline.

---

## Evidence base

Every GAMS claim in this document is one of:

- **[PROBED]** — executed against `/usr/gams/gams54.1_linux_x64_64_sfx/gams` 54.1.0 and the observed output is quoted.
- **[DOC]** — quoted from GAMS 54.1 documentation.
- **[SRC]** — read from `Uniswap/v3-core` contract source.
- **[INFERRED]** — reasoning from the above; flagged where it matters.

Two facts about the local environment that colour everything:

1. `make test-gams` currently reports **4 passed, 0 failed** [PROBED]. Nothing below is a live red test — these are the failure modes the current green is *not* protecting against.
2. The local GAMS runs under a **Demo license** (`Licensee: GAMS Demo`) [PROBED]. Demo caps NLP at **1000 variables / 1000 constraints** [DOC]. Current models have 1 equation; this ceiling is invisible today and becomes a hard wall in the `(Δᵢ, η)` solve and the `vol_markets` port.

---

## Verdict box (answers to the two ranked questions)

### Which of the three known representation conflicts is most dangerous?

**The η scale conflict (WAD in `TradingRegion.gms` vs Q0.128 in `_PayoffScaffolding.gms`) — by a wide margin.**

Ranking with evidence:

| Rank | Conflict | Failure mode | Detected by | Verdict |
|------|----------|--------------|-------------|---------|
| **1 — MOST DANGEROUS** | **η: WAD (`eta_x_y/unity`, ÷1e18) vs Q0.128 (`etaQ128 = 2^127`, ÷2^128)** | **Silent wrong number.** Both are legal doubles; no error of any kind. Mixing them scales η by `2^128/1e18 ≈ 3.40e20`. | Nothing today. | See below. |
| 2 | Tick bounds (`primitives.maxTick/minTick` vs `PricingKernel.MAX_TICK/MIN_TICK`) | Silent wrong number *and* silent numeric death — see P2. | Nothing today (no code path evaluates the kernel at those bounds). | Latent; becomes rank 1 in moments/ingestion. |
| 3 — LEAST DANGEROUS | `inventory` set (`/assetX, cashY/` vs `/X, Y/`) | **Hard compile error 194, exit code 2** [PROBED: `**** 194 Symbol redefined — a second data statement for the same symbol`]. | The compiler, loudly, always. | Cannot silently produce a wrong number. |

Why η wins:

- **It is silent in both directions, and both silences are plausible-looking.**
  - η_WAD (`5e17`) fed to a Q0.128 consumer → `5e17/2^128 = 1.47e-21 ≈ 0`. The CES cone `X^η·Y^(1−η)` collapses to `L = Y` (pure cash), and `tunablePricingKernel` collapses to `λ^0 = 1` — **a flat, tick-independent price kernel**. Nothing overflows. Nothing errors. Positivity assertions pass. Only a *tick-sensitivity* assertion catches it, and no such assertion exists.
  - η_Q128 (`2^127`) fed to a WAD consumer → `2^127/1e18 = 1.70e20`. The exponent `i·Δᵢ·1.7e20` sends `λ**(…)` straight into GAMS's silent saturation at `1.0e299`, **exit code 0** (see P1). `make test-gams` reports PASS.
- **η is the thing this milestone solves for.** It is on the critical path of the `(Δᵢ,η)` solve, the comparative-statics box, and the whole `vol_markets` port.
- **`etaQ128` is already a fabricated provenance claim.** `_PayoffScaffolding.gms:38` declares `etaQ128 = power(2,127)`, and both payoff units write it into `inputs('etaQ128')` and `execute_unload` it — but **no computation ever reads it**. η = 1/2 is instead hard-coded *structurally*, as the literal `/2` inside `sqrtPX96_at` (`_PayoffScaffolding.gms:30`) and the `sqr`-of-half-payoff macros. Both committed GDX fixtures therefore advertise an η representation with **zero executable binding** to the numbers they contain. A downstream consumer on the gamsdiff track that reads `etaQ128` and applies it as anything is consuming a decoration. This is the exact anti-pattern the project's Core Value exists to prevent.
- The `inventory` conflict, by contrast, is the *safest* of the three precisely because GAMS refuses to compile it. **Its only danger is the tempting fix**: `$onMultiR` makes the redeclaration succeed silently, exit 0, with the *second* definition winning and no warning [PROBED]. That fix must be banned outright.

### Is there a latent off-by-domain bug between `tickSpacingDomain /s1*s60/` (60) and `bandGrid /1*200/` (200)?

**Verdict: NO live numerical bug today — the two domains cannot silently cross-contaminate. But it is a genuine, load-bearing domain contradiction that already caps verification coverage, and both domains are the wrong *shape*.**

Evidence:

- `PricingKernel.gms:19-22` — `Set tickSpacingDomain /s1*s60/; tickSpacingVal(d) = ord(d)`. Probed: `card = 60`, `smax(tickSpacingVal) = 60`.
- `_PayoffScaffolding.gms:15-16` — `diMinInt /1/`, `diMaxInt /200/`. `eta_pi_trader_band_monotone_large.gms:24` — `Set bandGrid /1*200/`. `eta_pi_trader_zero_slippage.gms:99` — `Set diGrid /1*200/`.
- **Why it can't silently break:** the label namespaces are disjoint (`'s1'…'s60'` vs `'1'…'200'`), and GAMS domain-checks parameter indexing **at compile time** — indexing a parameter with a label outside its domain is a compile error, exit 2 [PROBED]. So an accidental cross-index fails loudly. The `Δᵢ` used by the payoff macros is a bare *number*, never a set label, so it never touches `tickSpacingDomain` at all.
- **Why it is still a real defect:**
  1. **Verification coverage is capped at Δᵢ ≤ 60.** The `(B_ext)` external-reference gate (`eta_pi_trader_band_monotone_large.gms:93`, `tunablePricingKernel('s10','k181',1)`) is the *only* check tying the payoff macros back to the `PricingKernel` representation. It can only be written where an `s`-label exists. **130 of the 190 band points (Δᵢ ∈ 61..190) have no cross-representation check of any kind.** The file's own comment claims B_ext "catches PricingKernel set label-to-ordinal drift" — true, but at exactly one point.
  2. **60 is stale; 200 is the real number.** Uniswap's fee tiers use tick spacings **{1, 10, 60, 200}** (1% tier = 200) [SRC/well-known]. Probed against the repo: `tickSpacingDomain` **contains 10 and 60 but not 200** (`has200 = 0`). `diMaxInt = 200` is exactly the missing value. The `todo:` comment at `PricingKernel.gms:18` ("Does this map to a domain of 1 to 200 on 1 step increments") is the author noticing this and never resolving it.
  3. **Both domains are the wrong shape.** A contiguous 1-step range `{1..60}` or `{1..200}` models a continuum of tick spacings; Uniswap has a **discrete menu of four**. The Lean theorem this milestone targets, `MeanVarianceOptimization.exists_mv_optimal_tick_menu`, is stated over a *finite menu*. Optimising `Δᵢ` over `[10,190]` therefore optimises over 188 spacings **no pool can be deployed with**, and T2/T3's "argmin at 10 / argmax at 190" are statements about a fictitious object. The GAMS Set is supposed to be the direct encoding of the Lean menu (per PROJECT.md Context) — right now it is not.
  4. **A separate, nastier trap lives in the same neighbourhood:** `tickVal(tick) = ord(tick) - 121` means **label `k60` has tick value −61, and tick value 60 lives at label `k181`** [PROBED: `tv_k60 = -61`, `tv_k181 = 60`]. The magic constant 121 is unbound to `card(tick)`. `(B_ext)` guards this at one point; nothing else does.
  5. `tick /k1*k241/` covers only **|tick| ≤ 120** [PROBED], versus Uniswap's ±887,272.

**Resolution (representation-unification phase):** delete both, replace with one canonical `Set tickSpacingMenu / ts1, ts10, ts60, ts200 /` carrying data (not `ord`), derive `diMinInt/diMaxInt` from `smin/smax` of it, and re-derive `tickVal` as `ord(tick) - (card(tick)+1)/2` with an `abort$` asserting the grid is symmetric and contains 0. Then state explicitly that the continuous NLP over `di` is a **relaxation** of a discrete menu choice, and either round-to-menu or enumerate.

---

## The precision / tolerance analysis (quantitative)

### What a Q96 or Q128 value actually is inside a GAMS double

A GAMS numeric value is an IEEE-754 binary64: 53-bit significand, ~1.11e-16 relative resolution. Two probed facts anchor everything:

- `power(2,53) + 1 - power(2,53) = 0` and `(power(2,53)+3) - power(2,53) = 4` [PROBED]. Integers above 2^53 are not all representable, and the ones that are not round **to even**.
- `power(2,96)`, `power(2,128)`, `power(2,256)` are computed **exactly** — cross-checked against independently-built products, difference exactly 0 [PROBED].

So for a Q64.96 sqrt price near price = 1, the on-chain `uint160` holds a ~96-bit integer, and the double holds its top 53 bits. Probed on the real fixture: at `sqrtP = 8.803e28`, `ulp = sqrtP·2^-53 = 9.77e12 = 2^43.15` — **the bottom ~43 bits of every Q96 sqrt price are structurally absent from the GAMS value.** For Q128.128 the loss is ~75 bits. Bit-exact equality is impossible, exactly as PROJECT.md's Out-of-Scope says.

**But the loss is harmless, and the reason matters.** Multiplying or dividing by 2^k is *exact* in IEEE-754 (it only shifts the exponent field). Probed: `etaQ128/Q128 = 0.5` exactly; a `Q128`-scale value written to GDX and re-loaded returns bit-identical (`d = 0`) [PROBED]. **All the Q-scale wrappers in this codebase cost literally nothing.** Every unit of error comes from the transcendental kernel `λ**(i·Δᵢ/2)`.

The counterintuitive corollary — and it is load-bearing:

> **Because scaling by 2^k is exact, a *wrong* scale factor produces no precision signal at all.** You cannot detect a missing `/Q96` by watching relative error. It shows up only as a magnitude error of exactly 2^96, 2^128, or `2^128/1e18 = 3.4e20`. Scale bugs must be caught by *magnitude* assertions, never by tolerance assertions.

### Where the error actually comes from: λ base rounding, amplified linearly by the exponent

`lambda = 1000100000000000000` and `unity = 1000000000000000000` are both exactly representable [PROBED]. Their quotient is not: `fl(1.0001) = 1.0000999999999999889865875957184471189975738525390625`, i.e. **relative error −1.101e-17** (only 0.099 ulp — an unusually lucky landing).

`**` is computed as `exp(y·log(x))` [DOC: *"This operation is not defined if x is negative… x**y is calculated as e^(y × log(x))"*]. An absolute error δ in `ln(base)` becomes a **relative** error `n·δ` in the result. Hence:

> **rel_err( λ**n ) ≈ 1.101e-17 · n**, signed (negative for n > 0, positive for n < 0), **systematic — not noise**.

Measured in GAMS 54.1 against exact `Decimal` references:

| exponent n | where it appears | GAMS rel err (measured) | predicted 1.101e-17·n | vs `diffTolerance = 1e-12` |
|---|---|---|---|---|
| 3,600 | `priceKernel` grid corner (tick 120 × spacing 60 ÷ 2) | −3.96e-14 | 3.96e-14 | 25× margin |
| 5,700 | band test, **Plank** coords (i=60, Δᵢ=190, ÷2) | **−6.279e-14** | 6.28e-14 | 16× margin |
| 11,400 | band test, **Lean** coords (i=60, Δᵢ=190) | **−1.2556e-13** | 1.26e-13 | **8.0× margin** |
| 90,800 | — | −1.00e-12 | 1.00e-12 | **exactly exhausted** |
| 443,636 | Uniswap MAX_TICK, sqrt form | −4.886e-12 | 4.88e-12 | **4.9× OVER** |
| 887,272 | Uniswap MAX_TICK, price form | **−9.771e-12** | 9.77e-12 | **9.8× OVER** |
| 4,194,303 | declared `MAX_TICK/2` = 2^23/2 | −4.6e-11 | 4.6e-11 | **46× OVER** |

### Is `diffTolerance = 1e-12` achievable? — the honest answer

**Yes, today. Barely, and for two reasons that are both accidents.**

1. **Accident of the exponent range.** The tightest current path is the Lean-coordinate band evaluation at `i·Δᵢ = 60×190 = 11,400`, measured at **1.2556e-13** — 8.0× inside the tolerance. The budget is exhausted at exponent **≈ 90,800**, i.e. any `(i, Δᵢ)` with `i·Δᵢ > 90,800`. That is *inside* the domain the repo already declares: `diMaxInt = 200` combined with any tick `i > 454` breaks it, and Uniswap's real tick range breaks it by an order of magnitude.

2. **Accident of λ's binary representation.** `fl(1.0001)` lands at 0.099 ulp. That is 10× luckier than a typical value. Measured across plausible alternative λ (WAD-encoded fee-tier bases), holding the *same* fixture (`n = 11,400`):

   | `lambdaWad` | fl(b) rel err | ulp fraction | max exponent for 1e-12 | err @ n=11,400 | current fixture |
   |---|---|---|---|---|---|
   | **1000100000000000000** (repo) | −1.101e-17 | **0.099** | 9.08e+04 | −1.255e-13 | **PASS** |
   | 1000010000000000000 | +6.551e-17 | 0.590 | 1.53e+04 | +7.468e-13 | PASS (1.3× margin) |
   | 1000300000000000000 | −3.303e-17 | 0.298 | 3.03e+04 | −3.765e-13 | PASS |
   | **1000050000000000000** | +1.055e-16 | 0.950 | 9.48e+03 | **+1.203e-12** | **FAIL** |
   | **1005000000000000000** | −1.061e-16 | 0.955 | 9.43e+03 | **−1.209e-12** | **FAIL** |
   | **1001000000000000000** | −1.100e-16 | 0.991 | 9.09e+03 | **−1.254e-12** | **FAIL** |

   **Changing λ alone — with no other edit — flips the existing band test red for 3 of the 6 alternatives tested.** The green in `make test-gams` is partly a property of the number 1.0001, not of the code.

**Therefore: `diffTolerance = 1e-12` must not remain a bare constant.** It should be a *function*:

```gams
* Error budget: base-rounding amplification + ~4 ulp of exp/log round-trip.
$macro kernelTol(nExp) ( 6 * abs(nExp) * 1.11e-16 / 100 + 8 * 1.11e-16 )
* equivalently ~6.7e-18*|n| + 8.9e-16 ; use a documented safety factor of 2-3.
```
…or, more simply and more honestly, keep the constant **and add a compile/run guard** that the fixture's exponent stays inside the budget:

```gams
Scalar tolExponentBudget ; tolExponentBudget = diffTolerance / 1.101e-17;   ! = 9.08e4
abort$( abs(iCfg) * diMaxBand > tolExponentBudget )
    "Fixture exponent i*di exceeds the exponent budget implied by diffTolerance",
    iCfg, diMaxBand, tolExponentBudget;
```

That one assertion is the single highest-value line this document recommends.

### The EVM side is *not* the error source (except at the bottom of the tick range)

I reimplemented Uniswap v3 `TickMath.getSqrtRatioAtTick` exactly (Q128.128 constant chain, `>>128` truncations, `type(uint256).max / ratio` inversion, `>>32` with round-up) and compared against exact `Decimal` values:

| tick | EVM rel err vs exact | GAMS rel err vs exact |
|---|---|---|
| 1 / 60 / 199 | +8.1e-30 / +9.8e-30 / +1.0e-29 | −9.9e-17 / −3.5e-16 / −1.1e-15 |
| 10,000 | +5.5e-30 | −5.5e-14 |
| 100,000 | +3.5e-32 | −5.5e-13 |
| 887,272 (MAX) | +2.9e-20 | −4.9e-12 |
| **−887,272 (MIN)** | **+2.02e-10** | +4.9e-12 |

Two conclusions:

- **Across almost the whole domain the EVM is exact to ~1e-29 and GAMS supplies 100 % of the disagreement.** Any GAMS↔EVM residual larger than the λ-amplification model above is a *bug*, not a representation limit.
- **At the bottom of the tick range the situation inverts.** `MIN_SQRT_RATIO = 4295128739` [SRC] — a 32-bit number in a Q96 slot. One integer unit is `1/4.295e9 = 2.33e-10` relative, i.e. **the EVM's own quantization is 200× coarser than `diffTolerance`.** The crossover (where the EVM's Q96 grid becomes coarser than a double's ulp) is `sqrtPX96 = 2^53`, i.e. **tick ≈ −596,180** [INFERRED, arithmetic shown: `(t/2)·ln(1.0001) = −43·ln2`]. Below that tick, no tolerance tighter than `1/sqrtPX96` is meaningful in *either* direction.

**Tolerance policy that follows:** `tol(i·Δᵢ) = max( 3 · 1.101e-17 · |i·Δᵢ|, 4 / sqrtPX96, 1e-15 )`.

---

## Critical Pitfalls

### Pitfall 1: GAMS silently saturates overflow at `1.0e299` and exits **0**

**What goes wrong:**
The EVM reverts on overflow. GAMS neither reverts nor produces `+INF`: it produces the **finite number `1.0e299`**, with no execution error, no warning, and **exit code 0**.

Probed:
```
ovf1 = 1.0001 ** 8388607   ->  1.0000E+299     (true value ~1e364)
ovf2 = 1.0001 ** 16777215  ->  1.0000E+299     (true value ~1e728)
ovf3 = exp(1000)           ->  1.0000E+299
```
`*** Status: Normal completion`, `EXIT=0`. And critically: `1$(ovf1 = INF)` evaluates to **0** — the saturated value is *not* `INF`, so `x = INF` guards do not fire. It is arithmetically live: `ovf1 / power(2,96) = 1.2622E+270`.

GAMS documentation corroborates: *"Avoid magnitudes >= 1.0e299 or <= -1.0e-299; they may be treated as UNDF or other special values."* [DOC]

Worse, `INF - INF = 0` in GAMS, with **no error at all** [PROBED]. And GAMS's own overflow detection is *inconsistent*: the `**` operator saturates silently while a subsequent `*` raises `Exec Error: overflow in * operation (mulop)` [PROBED, `probe13`]. You cannot rely on either.

**Why it happens:**
`make test-gams` and `make compile-gams` decide pass/fail on the GAMS exit code. Compile errors exit 2 and execution errors exit 3 [PROBED], so the harness is sound for *errors* — but saturation is not an error. A model that silently loses 200 orders of magnitude reports PASS.

**How to avoid:**
Range-guard every quantity that has an on-chain width, immediately after it is computed:

```gams
$macro assertUint160(x, tag) ( abort$((x) > power(2,160) - 1 or (x) < 0) "overflow uint160: " tag, x )
$macro assertUint128(x, tag) ( abort$((x) > power(2,128) - 1 or (x) < 0) "overflow uint128: " tag, x )
$macro assertFinite(x, tag)  ( abort$(abs(x) >= 1e290 or (x) = INF or (x) = -INF) "GAMS saturation: " tag, x )
```
Apply `assertFinite` to every `**` result and `assertUint160` to every sqrt price. Note the threshold must be **well below** 1e299 (use 1e290) — by the time a value *equals* 1e299 the information is already gone.

**Warning signs:**
- A displayed value of exactly `1.0000E+299`. There is no other way to produce that number.
- A result that is finite but whose ratio to a neighbouring grid point is 1.0 (saturation flattens the kernel).
- Automatable one-liner for CI, catching it even without in-model guards:
  `grep -l '1\.0000E+299' model/**/*.lst && exit 1`

**Phase to address:** **Test architecture** (the assertion vocabulary must include `assertFinite`/`assertUintN` from day one), and **representation unification** (bounds live in the canonical constants module).

---

### Pitfall 2: The declared tick bounds are numerically fatal, not merely wrong

**What goes wrong:**
Three of the four declared tick bounds cannot be used at all. Probed:

| symbol | file | value | `λ**(t/2)·2^96` | verdict |
|---|---|---|---|---|
| `MAX_TICK` | `PricingKernel.gms:8` | 8,388,607 | `1.1119E+211` | **163 orders past `uint160` max (1.4615e48)** — unstorable on chain |
| `MIN_TICK` | `PricingKernel.gms:9` | −8,388,607 | — | not the two's-complement int24 floor (−8,388,608) |
| `maxTick` | `primitives.gms:11` | 16,777,215 | **UNDF**, `Exec Error: overflow in * operation` | unusable |
| `minTick` | `primitives.gms:12` | **+8,388,607** | — | **a positive minimum**, and identical to `MAX_TICK` |

And `λ**MAX_TICK` (the price, not the sqrt price) → `1.0000E+299`, silently saturated [PROBED].

Uniswap's real bounds are `MIN_TICK = -887272`, `MAX_TICK = 887272`, chosen precisely so that `sqrtPriceX96 ∈ [4295128739, 1461446703485210103287273052203988822378723970342]` fits a `uint160` [SRC].

**Why it happens:**
The comment at `PricingKernel.gms:3-6` is honest ("these are the int24 *type* bounds, NOT Uniswap's usable tick range… Both are open questions"), but honesty in a comment does not stop a downstream `$include` from using the symbol. `LiquidityKernel.gms:36` already does: `iotaUp("positiveInteger") = maxTick` — the unusable 16,777,215.

**How to avoid:**
One canonical tick module with **four** distinct, differently-named concepts, never conflated:

```gams
* Two's-complement int24 STORAGE bounds — for width assertions only, never for evaluation.
Scalar INT24_MIN /-8388608/;  Scalar INT24_MAX /8388607/;
* Uniswap USABLE tick bounds — the only bounds any kernel may be evaluated at.
Scalar TICK_MIN  /-887272/;   Scalar TICK_MAX  /887272/;
* Derived sqrt-price bounds (uint160 domain).
Scalar SQRT_RATIO_MIN /4295128739/;
Scalar SQRT_RATIO_MAX /1461446703485210103287273052203988822378723970342/;

abort$(INT24_MIN <> -(INT24_MAX + 1)) "int24 bounds are not two's complement";
abort$(TICK_MIN  <> -TICK_MAX)        "usable tick range is not symmetric";
abort$(TICK_MAX  >  INT24_MAX)        "usable tick exceeds its storage width";
```
The `abort$(INT24_MIN <> -(INT24_MAX+1))` line alone would have caught `MIN_TICK = -8388607` at the first run.

**Warning signs:**
- `abort$(minTick >= 0)` — a one-line assertion that fires *today* on `primitives.gms`.
- Any two tick symbols with equal absolute value but different case (`MAX_TICK` vs `maxTick`) — grep-detectable.
- A sqrt price exceeding `power(2,160)`.

Caveat on `SQRT_RATIO_MAX`: as a GAMS literal it is a 49-digit integer that a double cannot hold exactly (it rounds to 1.4614467e48, ~2^160.4). That is fine for a *bound* check but must not be treated as an exact value — see P6.

**Phase to address:** **Representation unification** (blocking; this is the reason that phase exists).

---

### Pitfall 3: `sqr()` on a residual silently halves the strength of every zero-tolerance assertion

**What goes wrong:**
`piTrader_Half_Plank` and `piTrader_Half_Lean` both end in `sqr(A - B)` (`_PayoffScaffolding.gms:27,34`). The zero-slippage unit then asserts `abort$(abs(piAtStarPlankReal) > zeroTolerance)` with `zeroTolerance = 1e-20`.

A tolerance `τ` on a **squared** quantity is a tolerance `√τ` on the underlying residual. Probed inside the real macros at `Δᵢ⋆_Plank = 35.12192787`:

```
traderTerm  tT     = 0.11111111
traderDeltaO tD    = 0.11111111
residual  tT - tD  = -4.1633E-17        (3.4 double ulps — excellent)
relative residual  = 3.747E-16
pi = sqr(residual) = 1.73334E-33
zeroTolerance      = 1.00000E-20
=> implied residual tolerance = sqrt(1e-20) = 1.0E-10
=> implied RELATIVE tolerance on the residual = 9.0E-10
```

So the repo asserts **1e-12 relative** in one place and, in the very same scaffolding, **9e-10 relative** in another — **900× weaker** — and the weakness is invisible because it is hidden behind `sqr`. The actual achieved accuracy is 3.7e-16, so the assertion has **thirteen orders of magnitude of slack**. It is not a precision test; it is a smoke test wearing a precision test's clothes.

**Why it happens:**
`zeroTolerance = 1e-20` *looks* like the strictest number in the file. Nobody square-roots a tolerance in their head.

**How to avoid:**
Assert on the residual, then square only for reporting:

```gams
Scalar residPlank ; residPlank = traderTerm_Half_Plank(sqrtP, DIQ128)
                               - traderDeltaO_Half_Plank(sqrtP, sqrtQ, LQ128);
abort$(abs(residPlank) / abs(traderTerm_Half_Plank(sqrtP, DIQ128)) > diffTolerance)
    "payoff residual exceeds relative tolerance", residPlank;
```
Rule for the tolerance policy: **a tolerance may only be applied at the same algebraic degree as the quantity it was calibrated for.** If a macro squares, the tolerance must be squared too — and stated as such in the symbol name (`zeroToleranceSquared`).

**Warning signs:**
- Any `abort$` whose argument is the output of a macro whose body contains `sqr(`.
- A zero-tolerance assertion whose measured margin exceeds ~4 orders of magnitude — that is the signature of a tolerance applied at the wrong degree.

**Phase to address:** **Test architecture** (tolerance policy), retro-applied to `eta_pi_trader_zero_slippage.gms`.

---

### Pitfall 4: One-sided zero assertions pass on a collapsed computation

**What goes wrong:**
`abort$(abs(pi) > zeroTolerance)` fires only when `pi` is too **big**. It can never fire when `pi` is spuriously **zero** — and a collapsed computation produces exactly zero. Probed:

```gams
resid  = INF - INF;      ->  0.00000000     (no error, no warning)
payoff = sqr(resid);     ->  0.00000000
abort$(abs(payoff) > 1e-20) "would have caught it";
display "PASSED a 1e-20 zero-tolerance assertion on INF-INF";   <-- printed
```
The same shape occurs without `INF`: if both terms saturate to `1.0e299` (P1), or if catastrophic cancellation consumes every bit, the difference is identically 0 and the strictest-looking assertion in the codebase reports PASS.

**Why it happens:**
"Assert it's near zero" is the natural way to encode `pi_trader_half_zero_at_deltaI_star`. The theorem says *the value is zero at the optimum*; the test needs the stronger property *the value is zero at the optimum **and non-zero elsewhere***.

**How to avoid:**
Every zero assertion gets a **non-degeneracy companion** at a nearby off-optimum point, checking both sign and order of magnitude:

```gams
Scalar piOff ; piOff = piTrader_Half_Plank(sqrtPX96_at(lambdaWad, iCfg, diStarPlankReal + 1), LbarQ128, DICfgQ128);
abort$(piOff <= 0)      "degenerate: payoff is not strictly positive off the optimum", piOff;
abort$(piOff < 1e-12)   "degenerate: payoff off-optimum is implausibly small — computation may have collapsed", piOff;
```
Probed value for the current config: `piOff = 9.0e-8`. A guard at `1e-12` has 4 orders of headroom and still catches total collapse.

The zero-slippage unit's `(E)` V-shape checks partly cover this by accident; it should be explicit and it should be part of the standard vocabulary.

**Warning signs:** any `abort$` of the form `abs(x) > tol` with no companion `x <> 0` / `x > floor` assertion on a neighbouring point.

**Phase to address:** **Test architecture.**

---

### Pitfall 5: Rounding-direction mismatch — where it is a real systematic bias, and how to tell it from noise

**What goes wrong:**
Uniswap rounds **up** in `getNextSqrtPriceFromAmount0RoundingUp` (both branches — `FullMath.mulDivRoundingUp` and `UnsafeMath.divRoundingUp`) [SRC], and directionally in `getAmount0Delta`/`getAmount1Delta` (`roundUp = true` for positive liquidity delta, `false` for negative) [SRC]. GAMS arithmetic is IEEE round-to-nearest-even. A directional bias never cancels; it accumulates.

**Where it actually matters — quantified:**

| site | bias magnitude (relative) | vs `1e-12` |
|---|---|---|
| `mulDivRoundingUp` on `sqrtPX96` at price ≈ 1 | `1/2^96 = 1.26e-29` | invisible (7.9e12× below a double ulp) |
| same, at `MAX_SQRT_RATIO` | `6.8e-49` | invisible |
| same, at **`MIN_SQRT_RATIO = 4295128739`** | **`2.33e-10`** | **233× OVER** |
| `numerator1 / sqrtPX96` truncation in the overflow branch, `L ≈ 1e18` | `1e-18` | below |
| same, thin position `L ≈ 1e6` | `1e-6` | **1e6× OVER** |
| 1 wei on a 1-token trade, 18-dec token | `1e-18` | below |
| 1 wei on a 1-token trade, **USDC (6 dec)** | **`1e-6`** | **OVER** |
| 1 wei on a 1-token trade, **WBTC (8 dec)** | **`1e-8`** | **OVER** |
| accumulated `getAmountXDelta` bias over N mint/burn ops, 18-dec | `N · 1e-18` | crosses at **N ≈ 1e6** |

So: **rounding direction is irrelevant in the current fixtures (price ≈ 1, `L = 1e18`, 18-decimal) and dominant in three specific regimes** — the low tick range, thin liquidity, and non-18-decimal tokens.

**Why it happens:**
The current fixtures live in the one regime where the bias is 13 orders below the tolerance, so "rounding doesn't matter" reads as a general truth rather than a local one.

**How to avoid / how a test distinguishes noise from a wrong rounding mode.** Four residual *signatures*, distinguishable by regressing `relErr(GAMS − EVM)` on the grid:

| signature | shape of `relErr` across the grid | diagnosis |
|---|---|---|
| **constant sign, magnitude ≈ `1/value`** | `sign(diff)` identical at every grid point; `|diff| · value ≈ 1` | **wrong rounding direction** (one integer unit, always the same way) |
| **linear in `i·Δᵢ`, slope ≈ −1.101e-17, sign flips with the exponent's sign** | see the table in the precision section | **benign** — λ base rounding. Expected. |
| **`\|relErr\| ≤ k·2^-53`, `k ≲ 10`, no correlation with anything** | scatter | **benign** — genuine floating-point noise |
| **constant *ratio* (2^96, 2^32, `2^128/1e18 = 3.4e20`, `1e18`)** | `GAMS/EVM` is a fixed power of two or a fixed decimal | **scale bug** — see P8 |

The mechanical test, worth writing once and reusing:

```gams
* One-sidedness detector: for pure rounding-direction error, signSum = ±card(grid).
Parameter diffSign(g) ; diffSign(g) = sign(gamsVal(g) - evmVal(g));
Scalar signSum ; signSum = sum(g, diffSign(g));
Scalar signRatio ; signRatio = abs(signSum) / card(g);
abort$(signRatio > 0.9 and maxAbsRel > 4 * 1.11e-16)
   "residual is one-sided AND above noise -> rounding-direction mismatch, not FP noise", signSum, maxAbsRel;
```
Note `signRatio > 0.9` on its own is *not* sufficient: the λ base-rounding bias is also one-sided within a fixed-sign exponent range. The conjunction with a magnitude test is what separates them.

**Warning signs:** `signRatio` near 1.0 in any differential run; any fixture using a token with fewer than 18 decimals; any fixture with `sqrtPX96 < 1e12`.

**Phase to address:** **Test architecture** (the signature taxonomy is part of the assertion vocabulary) and the **gamsdiff hand-off** — the fixture GDX should carry the *expected* residual signature so the Solidity side can assert it.

---

### Pitfall 6: `priceImpactKernel_Add0` is scale-invariant; the EVM function it mirrors is not — and it models only one of two branches

**What goes wrong:**
Two independent gaps in the same macro.

**(a) The GAMS macro is homogeneous of degree 0 in `(L, dx)`.**
`L·P / (L + dx·P/2^96)` is unchanged under `(L, dx) → (cL, cdx)`. So the GAMS tests pass at *any* absolute scale, including physically impossible ones. The two usages differ by 18 orders of magnitude and neither is flagged:
- `PriceImpactKernelFixture.gms:17` / `PriceImpactKernelTest.gms` — `L = Lbar = unity = 1e18` (raw, matching `uint128 liquidity`).
- `_PayoffScaffolding.gms:31` — `priceImpactQ128_Add0` passes `LQ128/Q128 = 1.0` and `dxQ128/Q128 = 0.1`, i.e. **fractional liquidity**, which as a `uint128` is 1 or 0.

The EVM function is *not* scale-invariant: it reverts, changes branch, and quantizes differently as a function of absolute magnitude. **A GAMS test that is green at `L = 0.1` says nothing about the on-chain call.**

Concretely, this has already leaked into a committed artifact: `eta_pi_trader_zero_slippage.gms:8` sets `LbarQ128 = Q128 = 2^128` and exports it as `inputs('LbarQ128')`. **`uint128` max is `2^128 − 1`.** The fixture publishes a liquidity value that is *exactly one greater* than the type it names can hold; a Solidity harness doing `uint128(LbarQ128)` truncates to 0 or reverts on a checked cast. `eta_pi_trader_band_monotone_large.gms:9` does the same for `DICfgQ128 = Q128`.

More fundamentally: **Uniswap v3 has no Q128.128 liquidity.** `liquidity` is a raw `uint128`; `FixedPoint128.Q128` appears only in `feeGrowthGlobal0X128` / `feeGrowthInside`. The `Q128` label on `L̄` and `Δ^I` therefore attaches an EVM-coordinate name to a quantity the EVM never represents that way. [MEDIUM confidence on intent — verify against the Plank `CESLongPayoff.plk` harness before renaming.]

**(b) The macro models only the non-overflow branch.**
[SRC] `getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amount, add=true)`:
```solidity
uint256 numerator1 = uint256(liquidity) << 96;
if ((product = amount * sqrtPX96) / amount == sqrtPX96) {      // no uint256 overflow
    uint256 denominator = numerator1 + product;
    if (denominator >= numerator1)                              // no overflow on the add
        return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
}
return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96).add(amount)));  // FALLBACK
```
The fallback is a **different formula** — it truncates `numerator1 / sqrtPX96` before adding `amount`. The GAMS macro mirrors only the first branch, and there is no GAMS-side check that the EVM would have taken it.

Reachability: the branch flips when `amount · sqrtPX96 ≥ 2^256`. At price ≈ 1 that needs `amount ≥ 2^160 ≈ 1.5e48` (unreachable). At the top of the tick range `sqrtPX96 ≈ 2^160`, so it needs `amount ≥ 2^96 ≈ 7.9e28` wei ≈ **7.9e10 tokens** — entirely reachable for a high-price, 18-decimal, large-supply token. **The branch is reachable and the GAMS mirror is silent about it.**

**How to avoid:**
Add the branch predicate as an executable precondition, and add absolute-magnitude guards that the scale-invariance would otherwise hide:

```gams
$macro assertAdd0Branch(sqrtP, L, dx) (
    abort$( (dx) * (sqrtP) >= power(2,256) )
        "EVM would take the divRoundingUp FALLBACK branch; the GAMS macro models only the mulDivRoundingUp branch"  ;
    abort$( (L) * power(2,96) + (dx) * (sqrtP) >= power(2,256) )
        "EVM denominator overflows uint256; fallback branch"  ;
    abort$( (L) < 1 or (L) > power(2,128) - 1 )
        "liquidity is outside uint128 and cannot be the on-chain `liquidity`"  ;
    abort$( (L) <> round(L) )
        "liquidity is not integral; the EVM liquidity is a uint128, not a fraction" )
```
The `L <> round(L)` line fires today on `priceImpactQ128_Add0`, which is the point.

**Warning signs:**
- A macro whose value is unchanged when every argument is scaled by 1e18 — that is a *guarantee* that it cannot detect an EVM scale error. Automatable: evaluate at `(L,dx)` and at `(1e18·L, 1e18·dx)` and assert the results differ **only** if the EVM would too.
- Any exported `*Q128` or `*X96` symbol whose value exceeds the width its suffix implies.

**Phase to address:** **Representation unification** (the `Q128` labelling and the `uint128` bound), **test architecture** (branch preconditions as a reusable macro), **gamsdiff hand-off** (the fixture must state which branch it exercises).

---

### Pitfall 7: `**` domain and accuracy hazards — verified behaviour

**What goes wrong:**
`PricingKernel.gms:37-38` correctly documents that `**` is required because `tick/2` is half-integer for odd ticks. The consequences of that choice, all probed on 54.1:

| expression | result | error |
|---|---|---|
| `(-2.0) ** 0.5` | `UNDF` | `Exec Error: rPower: FUNC DOMAIN: x**y, x < 0` |
| `(-2.0) ** 3` | `UNDF` | **same error — `**` rejects negative bases even for integer exponents** |
| `power(-2, 3)` | `-8` | none |
| `signPower(-2, 3)` | `-8` | none |
| `vcPower(-2, 3)` | `UNDF` | `Exec Error: vcPower: FUNC DOMAIN: x**c, x < 0` |
| `0 ** 2` | `0` | none |
| `0 ** 0` | `1` | none |
| `0 ** (-1)` | `UNDF` | `Exec Error: rPower: FUNC DOMAIN: x**y, x=0,y<0` |
| `1.0001 ** 8388607` | `1.0000E+299` | **none — silent saturation** (P1) |
| `log(-1)` | `UNDF` | `Exec Error: log: FUNC DOMAIN: x < 0` |

Documentation corroborates: *"This operation is not defined if x is negative; an error will result"*; `power(x,n)` admits negative `x` for integer `n`; `rPower` requires `x ≥ 0` [DOC].

Two further verified properties:

- **`UNDF` propagates and poisons aggregates.** `smax`, `smin`, and `sum` over a set containing one `UNDF` element all return `UNDF` [PROBED]. That is *good news*: `maxRelErr = smax(...)` becomes `UNDF` and any `abort$` on it fires.
- **`UNDF` satisfies *both* sides of a comparison.** `1$(UNDF > 1e-12) = 1` **and** `1$(UNDF <= 1e-12) = 1` [PROBED]. Therefore:

  > **Rule: always count *failures*, never count *successes*.** `monoBreaks = 1$(a <= b)` (the repo's idiom) counts an `UNDF` as a break → abort fires → loud. The mirror idiom `passes = 1$(a > b); abort$(passes < card(g))` would count `UNDF` as a *pass* → silent. The repo happens to use the safe idiom everywhere; codify it before someone doesn't.

**Where a negative or zero base is actually reachable in this codebase:**
- `TradingRegion.gms:51-52` — `inv("assetX") ** (eta_x_y/unity)` with `inv` a `Positive Variable`. Safe *only* because `inv.lo = unity = 1e18`. If any future formulation relaxes that bound to 0, the NLP solver will probe the boundary and every function evaluation becomes `UNDF`.
- The `(Δᵢ, η)` solve, once **η becomes a Variable**: `x ** y` with both variable is legal and CONOPT handles it [PROBED: solved to `Locally Optimal`], but GAMS rewrites it as `exp(y·log(x))` and requires `x > 0` **strictly** at every trial point.
- `tickPerPriceKernel` (`PricingKernel.gms:86`) additionally calls a two-argument `log(base, x)` that GAMS does not provide, and has unbalanced parentheses. Already documented as WIP; keep it uncompiled.

**How to avoid:**
- `**` for real exponents, with a hard `abort$(base <= 0)` immediately before, or a `.lo` bound strictly inside the domain.
- `power()` for integer exponents (exact, negative-base-safe).
- `signPower()` when the base genuinely may be negative and the exponent is real.
- `option solPrint`/`EVALUATION ERRORS` in the solve summary — CONOPT counts function-evaluation errors separately from `execError`; a nonzero count means the solver walked into the `**` domain hole. Assert on it: `abort$(M.numDomErr > 0) "solver hit a function-domain error"`.

**Phase to address:** **(Δᵢ, η) solve** (variable bases and exponents), **test architecture** (the "count failures" rule).

---

### Pitfall 8: Representation drift — and which prevention mechanisms GAMS actually supports

**What goes wrong:**
Three conflicts were found by inspection (η, tick bounds, `inventory`). The mechanism that produced all three is the same: **GAMS has one global symbol namespace, no type system, and no unit system**, so nothing binds a symbol's *name* to its *scale*.

**What GAMS actually supports — probed, with one nasty surprise:**

| mechanism | supported? | verdict |
|---|---|---|
| **Include guard** (`$if set X $exit` / `$setGlobal X 1`) | ✅ works; the repo already uses it in `primitives.gms`, `_PayoffScaffolding.gms`, `_PriceImpactKernelInputs.gms` | Necessary but insufficient — it stops re-inclusion, not redefinition in a *different* file. |
| **Redeclaring a Set with different data** | ✅ **hard compile error 194, exit 2** [PROBED] | This is GAMS's type system. Lean on it: make every scaled quantity Set-indexed. |
| **Domain checking on parameter indexing** | ✅ compile error, exit 2, for a label outside the declared domain [PROBED] | Strongest guarantee available. Prefer `Parameter etaVal(etaScale)` over `Scalar eta_x_y`. |
| **`$onMultiR`** | ⚠️ **silently replaces the earlier data, exit 0, no warning** [PROBED] | **Ban outright.** This is the tempting "fix" for the `inventory` clash and it converts a loud error into a silent one. |
| **Compile-time `$eval` / `$ifThen` / `$abort`** | ✅ available… | **…but see the surprise below.** |
| **Canonical constants in a GDX, `$gdxIn` + `$load`** | ✅ **round-trips binary scale constants EXACTLY** (`Q96`, `Q128`, `2^127` all returned `d = 0`) [PROBED] | **The strongest "generated shared constants" option in GAMS.** One generator writes `scales.gdx`; every module `$load`s it; drift becomes impossible because there is one binary source. |
| **Execution-time `abort$()` consistency assertions** | ✅ | The real enforcement mechanism. |
| **Naming convention encoding scale** | no language support | Enforceable only by a `make lint` grep. Still worth it. |

**The surprise — `$eval` is lossy on binary scale constants.** Probed:

```
$eval E96  2**96   ->  text "7.92281625142643E28"   (15 significant digits)
Scalar a96; a96 = %E96%;
a96 - power(2,96)  =  -3.5184E+13   (= -2^45)   rel = -4.44e-16
$eval E128 2**128  ->  a128 - power(2,128) = -4.5335E+23   rel = -1.33e-15
$eval E256 2**256  ->  a256 - power(2,256) = -1.9283E+62   rel = -1.67e-15
```
Compile-time `$eval` renders through a 15-digit decimal string. **A `Q96` built with `$eval` is wrong by 2^45.** Worse than the size of the error: it destroys the *exactness* of the power-of-two relationships that make every Q-scale bridge in this codebase lossless (`etaQ128/Q128 = 0.5` exactly, `LQ128/Q128 = 1` exactly — see the precision section).

> **Hard rule: binary scale constants must be produced by `power(2,k)` at execution time, or loaded from a GDX. Never by `$eval`, `$set`, or a decimal literal.**

Note this also condemns the existing `Scalar uintMax /1.157920892373162e77/` (`primitives.gms:5`) as a *style* even though the value happens to be right — see P9.

**How to avoid — the concrete design:**

```gams
* ---- model/Scales.gms : THE single source of every scale, bound, and menu ----
$if set SCALES_INCLUDED $exit
$setGlobal SCALES_INCLUDED 1

Set scaleD / WAD, Q96, Q128, Q0_128, RAW /;
Parameter scaleVal(scaleD);
scaleVal('WAD')    = 1e18;
scaleVal('Q96')    = power(2,  96);
scaleVal('Q128')   = power(2, 128);
scaleVal('Q0_128') = power(2, 128);
scaleVal('RAW')    = 1;

* Every scaled quantity declares its scale as DATA, checkable at runtime.
Set    scaledSym / eta, sqrtPrice, liquidity, tickSpacing, lambda /;
Set    symScale(scaledSym, scaleD) /
         eta         . Q0_128,
         sqrtPrice   . Q96,
         liquidity   . RAW,
         tickSpacing . RAW,
         lambda      . WAD /;
abort$(card(symScale) <> card(scaledSym)) "every scaled symbol needs exactly one scale";

* Bridges are DERIVED, never re-typed.
$macro toDimensionless(v, s) ( (v) / sum(scaleD$sameas(scaleD,s), scaleVal(scaleD)) )
$macro etaWadToQ128(vWad)    ( (vWad) / 1e18 * power(2,128) )
```
plus a `make lint-gams` target:
```bash
# fail if any module redefines a canonical symbol outside Scales.gms
grep -rn --include='*.gms' -E '^\s*Scalar\s+(unity|uintMax|Q96|Q128|etaQ128|MAX_TICK|MIN_TICK|maxTick|minTick)\b' model/ \
  | grep -v '^model/Scales.gms' && { echo "canonical constant redefined outside Scales.gms"; exit 1; }
# fail on $onMultiR anywhere
grep -rn --include='*.gms' -i '\$onMulti' model/ && { echo '$onMulti* is banned'; exit 1; }
# fail on execError assignment (see P10)
grep -rn --include='*.gms' -E 'execError\s*=' model/ && { echo 'execError assignment is banned'; exit 1; }
```

**Warning signs:**
- Two `Scalar` declarations of the same *concept* under different capitalisation (`MAX_TICK` / `maxTick`) — grep-detectable, and present today.
- A symbol whose name carries no scale suffix but whose value is ≥ 1e17 or ≤ 1e-17.
- A GDX export containing a symbol (`etaQ128`) that no assignment statement in the file reads.

**Phase to address:** **Representation unification** — this pitfall *is* that phase's success criterion.

---

### Pitfall 9: Signed on-chain integers in a language with no integers and 1-based Sets

**What goes wrong:**
Four distinct hazards, all live.

**(a) The asymmetric two's-complement floor is unrepresentable in a symmetric Set.**
int24 is `−2^23 .. 2^23−1` = `−8388608 .. 8388607`. The repo's `MIN_TICK = −8388607` is off by one from the floor. That is not a rounding nit: `−(−8388608)` is the classic int24 overflow, and Uniswap's own `TickMath` sidesteps it by widening first (`uint256(-int256(tick))`) [SRC]. A differential test that never feeds `−8388608` never exercises the one input where int24 negation is dangerous. A symmetric GAMS Set (`tickVal = ord − 121`) **cannot** represent an asymmetric range; the floor must be added as an explicit extra element or as a separate boundary fixture.

**(b) GAMS has no integer type; a "tick" can silently become fractional.**
The band solve returns `di.l = 35.43505880` [PROBED] and the code rescues it with `round(di.l)`. Nothing prevents a fractional `Δᵢ` or tick from reaching a fixture, a GDX, or the gamsdiff track. Every on-chain-integer quantity needs `abort$(x <> round(x))` before export.

**(c) `round()` is *not* IEEE round-to-nearest-even.** Probed:
```
round(0.5)=1   round(1.5)=2   round(2.5)=3   round(-0.5)=-1   round(-1.5)=-2
```
GAMS `round()` rounds **half away from zero**. (IEEE round-to-nearest-even governs *arithmetic results*, not the `round` function — these are different mechanisms and it is easy to conflate them.) Consequence: `diPlankRound = round(diStarPlankReal)` and `diStarInt = smin(diGrid$(piGrid = piMinInt), diVal)` — a *smallest-under-ties* rule, matching the `tieBreaking /1/` scalar — **disagree at an exact .5**. Today `Δᵢ⋆ = 35.12` so it does not bind; it is one input away from binding. (Note also that `tieBreaking /1/` is declared and exported but, like `etaQ128`, never read by any assignment — a second decorative provenance scalar.)

**(d) `trunc` vs `floor` for negative ticks — the tick-compression trap.** Probed:
```
trunc(-7/3) = -2      floor(-7/3) = -3      mod(-7,3) = -1      mod(7,3) = 1
```
GAMS `trunc` truncates toward zero and GAMS `mod` takes the sign of the dividend — **both match Solidity's `int` `/` and `%` exactly.** Good. But Uniswap's `TickBitmap.position` compresses with *floor* semantics, implemented as truncate-then-adjust:
```solidity
int24 compressed = tick / tickSpacing;
if (tick < 0 && tick % tickSpacing != 0) compressed--;
```
So a GAMS mirror must use `floor(tick/tickSpacing)`, **not** `trunc` and **not** `round`. Using `trunc` is off by one for every negative tick not exactly divisible — a silent, systematic, sign-dependent error that never appears in a positive-tick fixture.

**(e) `ord()` is 1-based and unsigned; the offset is a magic number.** `tickVal(tick) = ord(tick) - 121` (`PricingKernel.gms:26`) hard-codes 121 against `card(tick) = 241`. Any change to the tick Set silently shifts every tick value by the delta. And `tickVal('k60') = -61` [PROBED] — the label is not the value.

**How to avoid:**
```gams
Parameter tickVal(tick);
tickVal(tick) = ord(tick) - (card(tick)+1)/2;                 ! derived, not magic
abort$(mod(card(tick),2) <> 1)               "tick grid must have odd cardinality to contain 0";
abort$(sum(tick$(tickVal(tick)=0), 1) <> 1)  "tick grid must contain exactly one zero tick";
abort$(smin(tick,tickVal(tick)) <> -smax(tick,tickVal(tick))) "tick grid is not symmetric";

$macro compressTick(t, ts) ( floor( (t) / (ts) ) )            ! floor, matching TickBitmap
$macro assertIntegral(x, tag) ( abort$((x) <> round(x)) "non-integral on-chain integer: " tag, x )
$macro assertInt24(x, tag) ( abort$((x) < -8388608 or (x) > 8388607 or (x) <> round(x)) "outside int24: " tag, x )
```

**Warning signs:**
- Any `ord(...) - <literal>`.
- Any `trunc`/`round` applied to a quotient whose numerator can be negative.
- Any exported tick or `Δᵢ` failing `x = round(x)`.
- A `tieBreaking` scalar with no reader (grep: symbol appears only in a declaration and an `execute_unload`).

**Phase to address:** **Representation unification** (tick module, integrality macros), **moments/ingestion** (real ticks are negative roughly half the time — this is where (d) and (a) bite).

---

## Moderate Pitfalls

### M1: `execError = 0` clears the error *and* restores exit code 0

Probed:
```
Scalar junk; junk = log(-1);      **** Exec Error at line 9: log: FUNC DOMAIN: x < 0
execError = 0;                    **** EXECERROR AT LINE 13 CLEARED (EXECERROR=0)
```
`EXIT=0`. A single assignment defeats the entire exit-code-based test harness. `execError` is readable (useful: `Scalar e; e = execError; abort$(e > 0) ...`) but writing it must be banned by lint. **Phase: test architecture.**

### M2: `option decimals` is capped at 8 — you cannot *look at* a 1e-13 discrepancy

`option decimals = 12` is a **compile error**: `**** 258 Option "decimals" must be in range 0..8` [PROBED]. Displayed scientific values carry ~6 significant digits (`3.74700E-16`). Diagnosing "is this 8e-13 or 1.2e-12?" from a `.lst` is not possible. Every tolerance investigation must (a) compute the relative error into a scalar and assert on it, or (b) write a `put` file with explicit formatting, or (c) go through GDX. **Phase: test architecture.**

### M3: Lag/lead off the end of a Set silently yields 0 — and whether that is loud or silent depends on the predicate's direction

`v(big+1)` at the last element produces **no record** (value 0) [PROBED]. Both current sliding-window checks guard it (`ord(bandGrid) < diMaxBand`, `ord(diGrid) < 200`). The subtlety worth codifying:

- an *increasing* check `pi(i) >= pi(i+1)` at the boundary becomes `pi(last) >= 0` = **TRUE** → phantom **failure** (loud, annoying, safe);
- a *decreasing* check `pi(i) <= pi(i+1)` at the boundary becomes `pi(last) <= 0` = **FALSE** → phantom **pass** (silent, dangerous).

The zero-slippage unit's `leftArmBreaks` is the decreasing form. It is correctly guarded today. **Phase: test architecture** (make the guard part of a `$macro slidingWindow(...)` rather than hand-written each time).

### M4: CONOPT can only locate an interior argmin of a squared residual to ~1e-2

Probed on the real zero-slippage model:
```
analytical  diStarPlank = 35.12192787
CONOPT      di.L        = 35.43505880      -> relative arg error 8.9e-3
objective   piVal.L     = 1.0e-8           (locally optimal, modelStat 2)
```
This is the classic square-root-of-tolerance effect: near a minimum of `π ≈ c·(Δᵢ−Δᵢ⋆)²`, an objective tolerance `τ` buys only `√(τ/c)` in the argument. With the measured curvature `c ≈ 9e-8`, a `1e-10` objective tolerance implies `±0.033` in `Δᵢ` — and the observed gap is `0.31`. **You can never assert a solved interior optimum against a closed form at 1e-12.**

Recommendation for the `(Δᵢ, η)` solve: **solve the stationarity condition as a square system (`=e= 0`, CNS), or the un-squared residual, rather than minimising the squared payoff.** Then the 1e-12 assertion becomes meaningful. Enumeration + parabolic interpolation (already used as `(F)`) is the fallback.

Note the *band* model does not suffer this — its optimum is at a bound and CONOPT returns `di.l = 10` exactly [PROBED], with a well-scaled Jacobian (`-0.0089`). The macros divide out `Q96`/`Q128`, so the "Q96-flat objective" comment in `eta_pi_trader_zero_slippage.gms:80` is describing the *flatness of a square*, not a scaling problem. **Phase: (Δᵢ, η) solve.**

### M5: CONOPT assumes a well-scaled model; the current models are fine only by accident

GAMS/CONOPT guidance: choose units so that variable values and individual equation terms are **around unity**, and derivatives are **not much over 1**; matrix coefficients ideally within 0.01..100 with a max/min ratio ≤ 1000–10000. The current `payoffEq` satisfies this (probed Jacobian coefficient `−0.0089`, objective `0.877`) **because `piTrader_Half_Plank` divides by `Q128` and `Q96`**. The moment a raw `sqrtPX96 ≈ 8.8e28` appears directly in an equation, the model spans 1e28 and CONOPT degrades badly. Warning sign: read the **Equation Listing** in the `.lst` — coefficients far from O(1) are the tell. **Phase: (Δᵢ, η) solve, vol_markets port.**

### M6: `uintMax /1.157920892373162e77/` is exactly `2^256`, not `2^256 − 1` — and no double can tell them apart

Probed: `uintMax - power(2,256) = 0.00000000` — the literal rounds to exactly `2^256`. Independently: `float(2**256 - 1) == float(2**256)` is `True`; the two differ by 1 in 1.16e77, which is `1e-77` relative, ~10^61 times finer than a double ulp at that magnitude (`2^203 = 1.29e61`).

So the symbol is **off by one and unfixable** — there is no double that means `2^256 − 1`. Comparing against it is still useful as an *order-of-magnitude* guard (`abort$(x > uintMax)` correctly fires on the `1.0e299` saturation value, probed), but it can never detect a true `uint256` boundary condition. Rename it `uint256Bound` and document it as "≥ this is definitely an overflow; < this is not necessarily safe". The same applies to `MAX_SQRT_RATIO` (49 digits) if it is ever introduced as a literal. **Phase: representation unification.**

### M7: `LiquidityKernel.gms` divides by `(1 − ξ)` with `ξ` set to a value that makes the denominator conditioned but the numerator meaningless

`LiquidityKernel.gms:44-52` computes `ξ^n / ((1−ξ^ι)/(1−ξ))`. `xiNorm = xiVal/unity`, and `xiVal("aboveOne") = unity + precision` → `ξ = 1 + 1e-6`. Then `1 − ξ = −1e-6` and `1 − ξ^ι` with `ι = 1` gives `−1e-6` — the ratio is `1`, so the whole geometric-series normaliser degenerates to 1. With `ι = 1` this is arithmetically fine but *semantically empty*, and at `ξ → 1` exactly it is `0/0` (`Exec Error: division by zero` → `UNDF`). Guard: `abort$(abs(xiNorm - 1) < 1e-12) "geometric normaliser is singular at xi = 1"`. **Phase: vol_markets port** (this is the module the port builds on).

### M8: GDX bytes are non-deterministic; GDX *values* are exact

`PriceImpactKernelFixture.gms:22-27` already documents that GAMS stamps a build timestamp into the GDX header, so `git diff` shows "Binary files differ" on every regeneration. Independently probed: **values round-trip exactly** (`Q96`, `Q128`, `2^127` all returned difference 0). So: never diff GDX bytes; always diff with `gdxdiff` or a value-level comparison. And commit GDX fixtures only with a companion text manifest of the values, or the review of a fixture change is unreviewable. **Phase: test architecture, gamsdiff hand-off.**

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Fixing the `inventory` set clash with `$onMultiR` | `TradingRegion` + `PricingKernel` become co-compilable in one line | Converts GAMS's loudest safety net (compile error 194) into a silent last-writer-wins. Every `inventory`-indexed parameter written against the losing definition becomes wrong or domain-errors. | **Never.** Rename the sets. |
| A single global `diffTolerance = 1e-12` constant | One number to cite in every spec section | Green depends on the exponent range *and* on λ's binary representation (3 of 6 alternative λ values flip the band test red). The tolerance encodes an assumption nobody restated. | Only with the `tolExponentBudget` guard alongside it. |
| Carrying `L̄`/`Δ^I` as `Q128` because it "looks EVM-native" | Symmetry with `Q96` sqrt prices; a tidy provenance field | Uniswap has no Q128.128 liquidity; the exported `LbarQ128 = 2^128` is one greater than `uint128` max. The label is a claim the EVM cannot honour. | Only if the Plank harness genuinely uses a Q128.128 notional — verify first. |
| `etaQ128` / `tieBreaking` as declared-and-exported but never-read provenance scalars | The GDX looks self-describing | A provenance field with no executable binding is a fabricated claim; downstream consumers act on it. Directly violates the project's Core Value. | Never. Every exported scalar must be read by at least one assignment or assertion in the same unit. |
| Asserting on `sqr(residual)` instead of the residual | The macro already returns the square; one fewer symbol | Silently weakens the assertion by a factor of `1/√τ` (here 900× vs `diffTolerance`, and 13 orders vs what is achieved). | Never for a tolerance test; fine for a display. |
| Hand-writing each sliding-window monotonicity check | Reads naturally next to the theorem it corroborates | The `ord < card` boundary guard is silent-on-omission for the decreasing direction (M3). Three copies exist already. | Only until the third copy — then extract a macro. |
| Minimising the squared payoff to find `Δᵢ⋆` | Directly mirrors the objective the theorem is about | Costs half the digits; the argmin is only ~1e-2 accurate (M4), so no 1e-12 assertion against a closed form is possible. | Acceptable as a *corroboration* with a 1-tick bound (what the repo does); never as the precision claim. |
| Building scale constants with `$eval` for "compile-time efficiency" | Constants become macro text, no execution cost | `$eval 2**96` is wrong by `2^45`; destroys the exactness of every power-of-two bridge. | **Never** for binary constants. Fine for cardinalities, exponents, and labels. |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **Uniswap `getNextSqrtPriceFromAmount0RoundingUp`** | Mirroring only the `mulDivRoundingUp` branch and assuming it always applies | Add the branch predicate `dx·sqrtP < 2^256` **and** `L·2^96 + dx·sqrtP < 2^256` as an executable precondition; the fallback `divRoundingUp(numerator1, numerator1/sqrtPX96 + amount)` is a *different formula* (P6) |
| **Uniswap `TickMath.getSqrtRatioAtTick`** | Assuming the EVM is the imprecise side | The EVM is exact to ~1e-29 across the range; GAMS supplies 100 % of the residual — **except below tick ≈ −596,180**, where the EVM's own Q96 grid (2.33e-10 at `MIN_SQRT_RATIO`) dominates |
| **Uniswap `liquidity` (uint128)** | Passing a Q128.128 or fractional value | `liquidity` is a raw integer `uint128`; `Q128.128` in v3 means `feeGrowth*X128` only. Assert `L = round(L)` and `1 ≤ L ≤ 2^128−1` |
| **Uniswap `TickBitmap` tick compression** | Using `trunc(tick/tickSpacing)` or `round(...)` | Use `floor(tick/tickSpacing)` — the EVM does truncate-then-decrement-if-negative, which *is* floor. GAMS `trunc` and `mod` otherwise match Solidity `int` semantics exactly (probed) |
| **Uniswap fee tiers / tick spacing** | Modelling `Δᵢ` as a contiguous range `1..60` or `1..200` | The deployable menu is `{1, 10, 60, 200}`. The Lean theorem (`exists_mv_optimal_tick_menu`) is stated over a finite menu; encode the menu as a GAMS `Set` with data, and treat the continuous NLP as a relaxation |
| **gamsdiff GDX hand-off** | Exporting a Q-suffixed value that exceeds the width its suffix names | Range-assert every exported symbol against the width in its name (`*X96` ⟹ `< 2^160`; `*Q128` used as liquidity ⟹ `< 2^128`) *before* `execute_unload` |
| **gamsdiff GDX hand-off** | Diffing GDX bytes in git | GAMS stamps a timestamp in the header; bytes always differ. Use `gdxdiff` or a text manifest |
| **`lean4-spec` submodule (`spec-preflight*`)** | Gating on `sorry`/`admit` and treating that as "the GAMS unit implements the theorem" | The gate proves the *Lean side* is sound. It says nothing about whether the GAMS macro is the same function. That is what `(B_indep)` / `(B_ext)` are for — and `(B_ext)` currently covers exactly one grid point (Verdict box) |
| **GAMS Demo license** | Assuming a green `compile-gams` means the solve will run | Demo caps NLP at 1000 vars / 1000 constraints [DOC]. A grid-indexed `(Δᵢ,η)` solve over `\|menu\| × \|η\|` blows it, and the failure is at *solve* time, not compile time |

---

## Magnitude & Scale Traps

*(the template's "Performance Traps" slot — for this domain the analogous axis is numeric magnitude, not user count)*

| Trap | Symptoms | Prevention | Where it breaks |
|------|----------|------------|-----------------|
| λ-exponent amplification exhausts `diffTolerance` | A previously-green diff drifts to 1.0–3.0e-12 with no code change | `abort$(abs(i)*diMax > diffTolerance/1.101e-17)` | **`i·Δᵢ > 90,800`**. Current fixture: 11,400 (8× margin). Uniswap MAX_TICK: 887,272 → 9.8e-12 |
| λ value change flips the tolerance | Same fixture, new λ, test goes red | Make the tolerance a function of `\|ln λ\|·n`, not a constant | 3 of 6 alternative WAD λ values fail at the *current* exponent (table above) |
| GAMS silent saturation at 1.0e299 | A value equal to `1.0000E+299`; a kernel that is flat in tick | `assertFinite` after every `**`; `grep '1\.0000E+299' *.lst` in CI | `λ**n` with `n·ln λ > 688`, i.e. `n > 6.9e6` — reachable from the *declared* `MAX_TICK` today |
| EVM Q96 quantization exceeds the double's | Residual ~1e-10 with no GAMS-side explanation | `tol ≥ 4/sqrtPX96` | `sqrtPX96 < 2^53`, i.e. **tick < ≈ −596,180** |
| Directional-rounding accumulation | Slow monotone drift over a simulated path | Track the sign sum; compare against `N·1 ulp` | `N ≈ 1e6` mint/burn ops on an 18-decimal token; `N = 1` on USDC/WBTC |
| Thin-liquidity truncation in the EVM fallback branch | Large residual only for small `L` | Assert `L ≥ 1e12` for any fixture claiming 1e-12 fidelity | `1/L > 1e-12`, i.e. **`L < 1e12`** |
| CONOPT argmin flatness | `di.l` off by ~0.3 while the objective is 1e-8 and `modelStat = 2` | Solve stationarity, not the square | Any interior minimum of a squared residual |
| GAMS Demo license ceiling | `Solve` fails with a license message; `compile-gams` still green | Count `m` and `n` before the solve; assert `< 1000` | 1000 constraints / 1000 variables (NLP) |

---

## Security & Integrity Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| **Fabricated provenance in a GDX** — exporting `etaQ128`, `tieBreaking`, `theoremStatus` that no assignment reads | Downstream (gamsdiff, Plank) acts on a claim with no executable binding. This is the exact failure the project's anti-fabrication review gate exists to catch, committed into a binary artifact where it is hard to review | Assert-before-export: every symbol in an `execute_unload` list must appear on the right-hand side of at least one assignment or inside at least one `abort$` in the same unit. Grep-checkable |
| **`execError = 0`** anywhere in a `.gms` | Turns a failed run into an exit-0 "pass"; silently defeats `make test-gams` | Ban by lint (M1) |
| **`$onMultiR`** | Silently overrides a canonical definition with no warning, exit 0 | Ban by lint (P8) |
| **Self-hosted runner on a public repo** (from PROJECT.md Constraints) | A fork PR executes arbitrary code on the build machine | Keep the `environment: gams-gate` approval job ahead of every self-hosted job — already the stated policy; verify it is still first after any workflow edit |
| **Committing a GAMS license file or license text into the repo** | License leakage; the demo notice already appears in every `.lst` | `.gitignore` `*.lst` (already done) and never commit `gamslice.txt` |
| **Trusting exit code alone as the test verdict** | Silent saturation exits 0 (P1) | Post-grep the `.lst` for `****` *and* for `1.0000E+299` — the Makefile comment at line 69-70 already says "MUST grep, not rely on exit code alone", but `compile-gams`/`test-gams` currently do rely on it. (Note: the comment's stated *reason* is wrong — compile errors exit 2 and execution errors exit 3, probed. The right reason is saturation.) |

---

## Assertion-Design Pitfalls

*(the template's "UX Pitfalls" slot — the "user" of a GAMS unit is the next engineer reading its `abort$` messages)*

| Pitfall | Impact | Better Approach |
|---------|--------|-----------------|
| An `abort$` message that names the theorem but not the numbers | A red test tells you *which theorem* broke, not by how much or where | Every `abort$` lists the offending value, the tolerance, and the grid point: `abort$(...) "FAIL T1 ...", monoBreaksPlankCount, maxRelErr, diffTolerance` |
| Counting *successes* instead of *failures* | `UNDF` satisfies both `>` and `<=` (P7), so a success-counter counts poison as a pass | Always accumulate a break/violation count and `abort$(count > 0)` |
| A tolerance constant with no derivation comment | Nobody can tell whether 1e-12 is a physical limit or a wish. It is currently a wish with an 8× margin | Every tolerance carries its budget in a comment: sources, magnitudes, and the exponent range it is valid for |
| Assertions that only cover the endpoints of a band | `(B_ext)` covers Δᵢ = 10 of the 190-point band; 130 points are outside the representable spacing domain entirely | Assert over the *whole* grid where possible; where not, `abort$` on the coverage gap itself so it cannot be forgotten |
| Relying on `display` to inspect precision | `option decimals` caps at 8 and scientific display shows ~6 digits (M2) | Compute relative errors into scalars and assert; use `put` or GDX for anything finer |

---

## "Looks Done But Isn't" Checklist

- [ ] **A green `make test-gams`:** verify no `.lst` contains `1.0000E+299` and none contains a `****` line. Exit code 0 does not exclude silent saturation (P1).
- [ ] **A committed GDX fixture:** verify every exported symbol is *read* by an assignment or `abort$` in the same unit — `etaQ128` and `tieBreaking` fail this today.
- [ ] **A `Q128`-suffixed exported value:** verify it is `< 2^128` if it names liquidity. `LbarQ128 = 2^128` and `DICfgQ128 = 2^128` are exactly one over `uint128` max.
- [ ] **A `1e-12` tolerance claim:** verify the fixture's `\|i·Δᵢ\|` is below `diffTolerance / 1.101e-17 = 9.08e4`, and record the measured margin.
- [ ] **A zero-tolerance assertion:** verify it is applied at the right algebraic degree (not to a `sqr()` output) and has a non-degeneracy companion at an off-optimum point (P3, P4).
- [ ] **A `**` call:** verify the base is bounded strictly positive at every point the solver can reach, and that the result is `assertFinite`-guarded.
- [ ] **A tick or `Δᵢ` reaching a GDX:** verify `x = round(x)` and `INT24_MIN ≤ x ≤ INT24_MAX` and `TICK_MIN ≤ x ≤ TICK_MAX`.
- [ ] **A sliding-window monotonicity check:** verify the `ord(...) < card(...)` boundary guard is present — the *decreasing* direction fails silently without it (M3).
- [ ] **A "the two representations agree" claim:** verify the agreement is checked at more than one grid point, and that the two evaluators do not share the rounded constant whose error you are trying to bound. `P_Lean_at` and `sqrtPX96_at` share `fl(1.0001)`, so the λ error is **common-mode and cancels between them** — the current Lean↔Plank checks cannot see it. Only a GAMS↔EVM diff can.
- [ ] **An NLP result asserted against a closed form:** verify the assertion is a 1-tick / order-of-magnitude bound, not a 1e-12 claim (M4).
- [ ] **A new module:** verify it `$include`s the canonical scales module and redeclares nothing; verify `make lint-gams` is green.
- [ ] **A `Model`/`Solve` unit:** verify `m` and `n` are under the Demo license's 1000/1000 NLP ceiling, and that `M.numDomErr = 0`.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| η scale conflict (P8/Verdict) | **MEDIUM** — caught now; HIGH once `vol_markets` is ported on top | 1. Pick Q0.128 as canonical (it is the EVM-native one for a dimensionless weight). 2. Rewrite `TradingRegion` to carry `etaQ128` and derive the dimensionless weight as `etaQ128/Q128`. 3. Add `etaWadToQ128` as the *only* bridge. 4. Add a tick-sensitivity assertion (`priceKernel` must change between adjacent ticks) so an η→0 collapse can never pass again. |
| Tick-bound conflict (P2) | **LOW** today (no evaluation path); HIGH after moments/ingestion | Delete both pairs; introduce `INT24_MIN/MAX` + `TICK_MIN/MAX` + `SQRT_RATIO_MIN/MAX` with the three consistency `abort$`s. Repoint `LiquidityKernel.gms:36`. |
| `inventory` set conflict | **LOW** | Rename to `invTR` / `invPK`, or better: one `Set token / token0, token1 /` matching the EVM's own naming, with a documented map to `assetX/cashY`. Never `$onMultiR`. |
| `diffTolerance` proves optimistic at a new λ or exponent | **LOW if the guard exists; HIGH if discovered by a red diff in the gamsdiff track** | Add `tolExponentBudget` guard; convert `diffTolerance` to `kernelTol(n)`; re-baseline the three committed GDX fixtures. |
| `sqr()`-weakened assertions (P3) | **LOW** | Introduce residual-level scalars in both payoff units; keep `sqr` only for display and GDX. |
| Silent saturation already in a committed fixture | **MEDIUM** | Regenerate all three GDX fixtures under the new `assertFinite` guards; `gdxdiff` old vs new; any changed value was poisoned. |
| `tickSpacingDomain` / `bandGrid` domain contradiction | **MEDIUM** — touches every payoff unit's grid and both GDX schemas | Replace with the menu Set; re-run the band and zero-slippage units at menu spacings; note in the spec that T2/T3 change meaning (band endpoints become menu endpoints). |
| Fabricated provenance already in committed GDX | **LOW** | Add the assert-before-export rule; regenerate; the diff *is* the audit. |

---

## Pitfall-to-Phase Mapping

Severity: **S1** = can silently produce a wrong number that a green test reports as correct. **S2** = wrong number, but something loud eventually catches it. **S3** = correctness-adjacent (coverage, ergonomics, capacity).

| # | Pitfall | Severity | Prevention Phase | Verification that prevention worked |
|---|---------|----------|------------------|--------------------------------------|
| **Verdict** | **η WAD vs Q0.128 scale conflict** | **S1** | **Representation unification** | `grep -c 'eta_x_y\s*/\s*unity' model/` returns 0; a tick-sensitivity assertion exists and fails when η is forced to 0 |
| P1 | GAMS silent saturation at 1.0e299, exit 0 | **S1** | **Test architecture** (vocabulary) + representation unification (bounds) | Deliberately inject `λ**8388607` into a scratch unit; `make test-gams` must go RED. CI greps `.lst` for `1.0000E+299` |
| P2 | Tick bounds unusable / contradictory | **S1** (latent) | **Representation unification** | `abort$(minTick >= 0)` and `abort$(INT24_MIN <> -(INT24_MAX+1))` both present and green; `LiquidityKernel` no longer references `maxTick` |
| P3 | `sqr()` halves assertion strength | **S1** | **Test architecture** (tolerance policy) | Every `abort$` whose argument comes from a `sqr`-ending macro is rewritten to the residual; measured margin on the residual is ≤ 100× |
| P4 | One-sided zero assertions pass on collapse | **S1** | **Test architecture** | Every zero assertion has a non-degeneracy companion; forcing `traderTerm = traderDeltaO` makes the unit go RED |
| P5 | Rounding-direction bias (low tick / thin L / non-18-dec) | **S1** in those regimes | **Test architecture** + **gamsdiff hand-off** | The `signRatio` detector runs on every differential grid; fixtures record which regime they exercise |
| P6 | Scale-invariant macro / unmodelled EVM overflow branch / `Q128` liquidity | **S1** | **Representation unification** (labels, `uint128` bound) + **test architecture** (branch preconditions) | `assertAdd0Branch` present at every `priceImpactKernel_Add0` call; no exported `*Q128` liquidity exceeds `2^128−1`; `L = round(L)` holds |
| P7 | `**` domain hazards; `UNDF` comparison semantics | **S2** (loud) / **S1** for success-counting | **(Δᵢ, η) solve** + test architecture | `M.numDomErr = 0` asserted after every `Solve`; lint finds no success-counting idiom |
| P8 | Representation drift as a class; `$eval` lossiness; `$onMultiR` | **S1** | **Representation unification** | `model/Scales.gms` exists and is the sole definer; `make lint-gams` green; a scratch unit proving `$eval`-built `Q96` is rejected |
| P9 | Signed int24 / `ord()` / `round` / `trunc` vs `floor` | **S1** for negative ticks | **Representation unification** + **moments/ingestion** | `tickVal` derived from `card`; symmetry + zero-tick assertions green; `compressTick` uses `floor`; a negative-tick fixture exists |
| M1 | `execError = 0` defeats the harness | **S1** | Test architecture | Lint rejects `execError =` |
| M2 | `option decimals` capped at 8 | S3 | Test architecture | Tolerance investigations go through scalars/GDX, not `display` |
| M3 | Lag/lead boundary silent in the decreasing direction | **S1** (that direction) | Test architecture | Sliding-window logic extracted to one guarded macro; three hand-written copies removed |
| M4 | CONOPT argmin of a square is ~1e-2 | **S2** | **(Δᵢ, η) solve** | Stationarity solved as a square system; closed-form assertion at a real tolerance |
| M5 | CONOPT scaling assumptions | **S2** | (Δᵢ, η) solve, vol_markets port | Equation Listing coefficients within 0.01..100 |
| M6 | `uintMax` is `2^256`, not `2^256−1` | S3 | Representation unification | Renamed `uint256Bound`, documented as one-sided |
| M7 | `LiquidityKernel` geometric normaliser singular at ξ=1 | **S2** | **vol_markets port** | `abort$(abs(xiNorm-1) < 1e-12)` present |
| M8 | GDX bytes non-deterministic | S3 | Test architecture, gamsdiff hand-off | Review process uses `gdxdiff`/manifest, never byte diff |
| — | Demo-license 1000/1000 NLP ceiling | S3 | **(Δᵢ, η) solve**, vol_markets port | Model size asserted before `Solve`; CI documents the license tier |
| — | `tickSpacingDomain(60)` vs `bandGrid(200)` vs the real menu `{1,10,60,200}` | **S2** (coverage, not a wrong number — see Verdict box) | **Representation unification** | One `tickSpacingMenu` Set; `diMinInt/diMaxInt` derived from it; `(B_ext)` extended to every menu point |

### Phase ordering implication

**Representation unification must be Phase 1 and must block everything else.** It owns 5 of the 9 critical pitfalls, including the most dangerous one, and every other phase's assertions are only as trustworthy as the constants they compare against. **Test architecture must be Phase 2** — it owns the remaining 4 criticals and supplies the vocabulary (`assertFinite`, `assertUintN`, `assertIntegral`, `assertAdd0Branch`, the sliding-window macro, the tolerance-budget guard) that Phases 3+ consume. The `(Δᵢ,η)` solve, moments/ingestion, and the `vol_markets` port each inherit specific pitfalls but none of them can be verified before those two phases land.

---

## Sources

**Executed locally (highest confidence — all `[PROBED]` claims):**
- GAMS 54.1.0 `37378ce0` LEX-LEG x86 64bit/Linux, `/usr/gams/gams54.1_linux_x64_64_sfx/gams`, 15 probe programs covering: exactness of `power(2,k)`, the 2^53 integer threshold, `round`/`trunc`/`floor`/`mod` semantics, `**` domain errors, overflow saturation and `INF`/`UNDF`/`NA` behaviour, `execError` read/write, `$eval` precision, `$onMultiR`, GDX round-trip exactness, Set `ord`/lag/lead semantics, `option decimals` limits, exit codes for compile/execution/abort, and CONOPT behaviour on the repo's actual `payoffEq`.
- The repository's own `make test-gams` (4 passed, 0 failed) and the real macros in `model/payoff/_PayoffScaffolding.gms` re-instrumented to expose the pre-square residual.
- Exact-arithmetic references computed with Python `decimal` at 80 digits, and a faithful reimplementation of Uniswap v3 `TickMath.getSqrtRatioAtTick` (Q128.128 constant chain).

**GAMS 54.1 documentation:**
- https://www.gams.com/latest/docs/UG_Parameters.html — extended range arithmetic, special values, *"Avoid magnitudes >= 1.0e299 or <= -1.0e-299"*
- https://www.gams.com/latest/docs/UG_Parameters.html#UG_Parameters_ExpressionsFunctions — `**` = `e^(y·log x)`, domain restrictions; `power`, `rPower`, `signPower`, `vcPower`, `log`
- https://www.gams.com/latest/docs/UG_License.html — Demo license size limits
- https://www.gams.com/blog/2017/08/scaling/ and https://support.gams.com/solver:some_notes_on_scaling — CONOPT scaling guidance (values ≈ unity, derivatives ≲ 1, coefficient range 0.01..100)

**Uniswap v3 source:**
- https://raw.githubusercontent.com/Uniswap/v3-core/main/contracts/libraries/SqrtPriceMath.sol — `getNextSqrtPriceFromAmount0RoundingUp` (both branches), `getAmount0Delta`/`getAmount1Delta` rounding directions
- https://raw.githubusercontent.com/Uniswap/v3-core/main/contracts/libraries/TickMath.sol — `MIN_TICK`/`MAX_TICK` = ∓887272, `MIN_SQRT_RATIO` = 4295128739, `MAX_SQRT_RATIO` = 1461446703485210103287273052203988822378723970342, round-up in the final division

**Repository sources read:**
`.planning/PROJECT.md`, `model/primitives.gms`, `model/PricingKernel.gms`, `model/TradingRegion.gms`, `model/LiquidityKernel.gms`, `model/payoff/_PayoffScaffolding.gms`, `model/payoff/eta_pi_trader_zero_slippage.gms`, `model/payoff/eta_pi_trader_band_monotone_large.gms`, `model/PriceImpactKernelFixture.gms`, `model/_PriceImpactKernelInputs.gms`, `model/test/*.gms`, `model/BUILD.md`, `Makefile`.

**Known-stale sources, used with caution:**
`model/BUILD.md` — claims "No `Model`/`Solve` statement exists yet" (two CONOPT NLPs do) and calls `PayoffModule.gms` an empty stub. Its `inventory` caveat and working-directory requirement were independently re-verified and are correct.

---
*Pitfalls research for: EVM fixed-point ↔ GAMS floating-point ↔ Lean real-valued correspondence*
*Researched: 2026-07-27*
